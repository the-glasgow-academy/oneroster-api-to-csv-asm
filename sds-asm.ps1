#requies -modules pwsh-module-api-wrapper, ad-user-provisioning
if (!(test-path ./csv-asm)) {
    new-item -itemtype directory -path ./csv-asm
}

$pConn = @{
    URL   = $env:GOR_API_URL
    Token = $env:GOR_API_TOKEN
}

# locations csv
$orgs = Get-ApiContent @pConn -Endpoint "orgs" -all
$orgs.orgs |
select @{n = 'location_id'; e = { $_.sourcedid } },
@{n = 'location_name'; e = { $_.name } } |
export-csv ./csv-asm/locations.csv

# users
$blacklistUser = (Initialize-BlacklistUser).sourcedid
# staff csv
$usersTeachers = Get-ApiContent @pConn -Endpoint "users?filter=role='teacher' AND status='Y'" -all
$usersTeachers.Users |
Where-Object username -ne $null | 
Where-Object SourcedId -notin $blacklistUser |
Select @{n = 'person_id'; e = { $_.SourcedId } },
@{n = 'person_number'; e = { $null } },
@{n = 'first_name'; e = { $_.givenName } },
@{n = 'middle_name'; e = { $null } },
@{n = 'last_name'; e = { $_.familyName } },
@{n = 'email_address'; e = { $_.email } },
@{n = 'sis_username'; e = { $null } },
@{n = 'location_id'; e = { $_.orgs.SourcedId -join ',' } } |
export-csv ./csv-asm/staff.csv

# students csv
$userPupil = Get-ApiContent @pConn -Endpoint "users?filter=role='student' AND status='Y'" -all
$userPupil.Users |
Select *, @{ n = 'YearIndex'; e = { ConvertFrom-K12 -Year $_.grades -ToIndex } } | 
Where-Object YearIndex -ge 4 | 
Where-Object SourcedId -notin $blacklistUser |
Select @{n = 'person_id'; e = { $_.SourcedId } },
@{n = 'person_number'; e = { $null } },
@{n = 'first_name'; e = { $_.givenName } },
@{n = 'middle_name'; e = { $null } },
@{n = 'last_name'; e = { $_.familyName } },
@{n = 'grade_level'; e = { $null } },
@{n = 'email_address'; e = { $_.email } },
@{n = 'sis_username'; e = { $null } },
@{n = 'password_policy'; e = { "4" } },
@{n = 'location_id'; e = { $_.orgs.SourcedId -join ',' } } |
export-csv ./csv-asm/students.csv

# courses csv
$courses = Get-ApiContent @pConn -Endpoint "courses" -all
$courses.courses |
select @{n = 'course_id'; e = { $_.sourcedId } },
@{n = 'course_number'; e = { $_.courseCode } },
@{n = 'course_name'; e = { $_.title } },
@{n = 'location_id'; e = { $_.org.sourcedId } } |
export-csv ./csv-asm/courses.csv

# classes csv
$blacklist = (Initialize-BlacklistClass).sourcedid
$instructors = Get-ApiContent @pConn -Endpoint "enrollments?filter=role='teacher'" -all

$classes = Get-ApiContent @pConn -Endpoint "classes" -all
$classesfmt = $classes.classes |
Where-object sourcedid -notin $blacklist | 
select @{n = 'class_id'; e = { $_.sourcedId } },
@{n = 'class_number'; e = { $null } },
@{n = 'course_id'; e = { $_.course.sourcedId } },
@{n = 'instructor_id'; e = { $null } },
@{n = 'instructor_id_2'; e = { $null } },
@{n = 'instructor_id_3'; e = { $null } },
@{n = 'location_id'; e = { $_.school.sourcedId -join ',' } } 

foreach ($c in $classesfmt) {
    $i = $instructors.enrollments | where-object { $_.class.sourcedId -eq $c.class_id }
    if ($i) {$c.instructor_id = $i.user.sourcedId}
    if ($i.count -gt 1) {
        $n = 2
        foreach ($t in $i[2..3]) {
            $c.instructor_id_$n = $t.user.sourcedId
            $n++
        }
    }
}
$classesfmt | export-csv ./csv-asm/classes.csv

# roster csv 
$senrollments = Get-ApiContent @pConn -Endpoint "enrollments?filter=role='student' AND status='Y'" -all
$senrollments.Enrollments |
Where-Object { $_.class.sourcedid -notin $blacklist } |
Where-Object { $_.user.sourcedid -notin $blacklistUser } |
select @{n = 'roster_id'; e = { $_.sourcedId } },
@{n = 'class_id'; e = { $_.class.sourcedId } },
@{n = 'student_id'; e = { 
        $id = $_.user.sourcedId
        if ($id.count -gt 1) { $id[0] }
        else { $id }
    } 
} |
export-csv ./csv-asm/rosters.csv
