#requies -modules pwsh-module-api-wrapper, ad-user-provisioning
if (!(test-path ./mscsv)) {
    new-item -itemtype directory -path ./mscsv 
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
export-csv ./mscsv/school.csv

# users
$blacklistUser = (Initialize-BlacklistUser).sourcedid
# staff csv
$usersTeachers = Get-ApiContent @pConn -Endpoint "users?filter=role='teacher' AND status='Y'" -all
$usersTeachers.Users |
Where-Object username -ne $null | 
Where-Object SourcedId -notin $blacklistUser |
Select @{n = 'person_id'; e = { $_.SourcedId } },
@{n = 'location_id'; e = { $_.orgs.SourcedId -join ',' } },
@{n = 'sis_username'; e = { $_.username } } | 
export-csv ./mscsv/teacher.csv

# students csv
$userPupil = Get-ApiContent @pConn -Endpoint "users?filter=role='student' AND status='Y'" -all
$userPupil.Users |
Select *, @{ n = 'YearIndex'; e = { ConvertFrom-K12 -Year $_.grades -ToIndex } } | 
Where-Object YearIndex -ge 4 | 
Where-Object SourcedId -notin $blacklistUser |
Select @{n = 'person_id'; e = { $_.SourcedId } },
@{n = 'location_id'; e = { $_.orgs.SourcedId -join ',' } },
@{n = 'sis_username'; e = { $_.Username } } |
export-csv ./mscsv/student.csv

# courses csv
$courses = Get-ApiContent @pConn -Endpoint "courses" -all
$courses.courses |
select @{n = 'course_id'; e = { $_.sourcedId } },
@{n = 'course_number'; e = { $_.courseCode } },
@{n = 'course_name'; e = { $_.title } },
@{n = 'location_id'; e = { $_.org.sourcedId } } |
export-csv ./csv-asm/courses.csv

# classes csv
$AS = Get-ApiContent @pConn -Endpoint "academicSessions" -all
$blacklist = (Initialize-BlacklistClass).sourcedid

$classes = Get-ApiContent @pConn -Endpoint "classes" -all
$classes.classes |
Where-object sourcedid -notin $blacklist | 
select @{n = 'class_id'; e = { $_.sourcedId } },
@{n = 'location_id'; e = { $_.school.sourcedId -join ',' } },
@{n = 'class_number'; e = { $_.classCode } } |
export-csv ./mscsv/section.csv

# Student enrollment
$senrollments = Get-ApiContent @pConn -Endpoint "enrollments?filter=role='student' AND status='Y'" -all
$senrollments.Enrollments |
Where-Object { $_.class.sourcedid -notin $blacklist } |
Where-Object { $_.user.sourcedid -notin $blacklistUser } |
select @{n = 'class_id'; e = { $_.class.sourcedId } },
@{n = 'student_id'; e = { 
        $id = $_.user.sourcedId
        if ($id.count -gt 1) { $id[0] }
        else { $id }
    } 
} |
export-csv ./mscsv/studentenrollment.csv

# teacher roster
$tenrollments = Get-ApiContent @pConn -Endpoint "enrollments?filter=role='teacher' AND status='Y'" -all
$tenrollments.Enrollments |
where-object { $_.class.sourcedid -notin $blacklist } |
where-object { $_.user.sourcedid -notin $blacklistUser } |
select @{n = 'Section ID'; e = { $_.class.sourcedId } },
@{n = 'ID'; e = { 
        $_.user.sourcedId
    } 
} |
? ID -ne $null |
export-csv ./mscsv/teacherroster.csv

