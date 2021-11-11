#Requires -Version 7
#Requires -Modules @{ ModuleName="ps-oneroster"; ModuleVersion="1.0.0" }

# Test/create csv directory
if (!(test-path ./csv-asm)) {
    new-item -itemtype directory -path ./csv-asm
}

$connectP = @{
    Domain = $env:OR_URL
    ClientId = $env:OR_CI
    ClientSecret = $env:OR_CS
    Scope = "roster-core.readonly"
    Provider = "libre-oneroster"
}

Connect-OROneroster @connectP

# locations
$orgsGet = Get-ORData -Endpoint "orgs" -All

$orgs = $orgsGet.orgs |
select-object @{n = 'location_id'; e = { $_.sourcedid } },
@{n = 'location_name'; e = { $_.name } } 

$orgs | export-csv ./csv-asm/locations.csv


# users
$usersGet = Get-ORData -Endpoint "users" -All
# blacklist
$blacklistUsers = $usersGet.Users |
Select-Object *, @{ n = 'YearIndex'; e = { (ConvertFrom-ORK12 -K12 $_.grades[0]).index } } |
Where-Object {
    ($_.status -eq 'tobedeleted') -or
    ($_.email -eq 'NULL') -or
    ($_.familyName -like '*ACCOUNT*') -or
    ($_.YearIndex -ge 0 -and $_.YearIndex -le 3) -or 
    ($_.YearIndex -ge 10 -and $_.YearIndex -le 16)
}

# staff csv
$usersTeachers = $usersGet.users |
Where-Object role -eq 'teacher' |
Where-Object status -eq 'active' |
Where-Object SourcedId -notin $blacklistUsers.sourcedId |
Select-Object @{n = 'person_id'; e = { $_.SourcedId } },
@{n = 'person_number'; e = { $null } },
@{n = 'first_name'; e = { $_.givenName } },
@{n = 'middle_name'; e = { $null } },
@{n = 'last_name'; e = { $_.familyName } },
@{n = 'email_address'; e = { $_.email } },
@{n = 'sis_username'; e = { $null } },
@{n = 'location_id'; e = { $_.orgs.SourcedId -join ',' } } 

$usersTeachers | export-csv ./csv-asm/staff.csv

# students csv
$userPupil = $usersGet.users |
Where-Object role -eq 'student' |
Where-Object status -eq 'active' |
Where-Object SourcedId -notin $blacklistUsers.sourcedId |
Select-Object @{n = 'person_id'; e = { $_.SourcedId } },
@{n = 'person_number'; e = { $null } },
@{n = 'first_name'; e = { $_.givenName } },
@{n = 'middle_name'; e = { $null } },
@{n = 'last_name'; e = { $_.familyName } },
@{n = 'grade_level'; e = { $null } },
@{n = 'email_address'; e = { $_.email } },
@{n = 'sis_username'; e = { $null } },
@{n = 'password_policy'; e = { "4" } },
@{n = 'location_id'; e = { $_.orgs.SourcedId -join ',' } } 

$userPupil | export-csv ./csv-asm/students.csv

# courses csv
$coursesGet = Get-ORData -Endpoint "courses" -Filter "courseCode='TG'" -All
$courses = $coursesGet.courses |
select-object @{n = 'course_id'; e = { $_.sourcedId } },
@{n = 'course_number'; e = { $_.courseCode } },
@{n = 'course_name'; e = { $_.title } },
@{n = 'location_id'; e = { $_.org.sourcedId } } 

$courses | export-csv ./csv-asm/courses.csv


$enrollmentsGet = Get-ORData -Endpoint "enrollments" -Filter "status='active'" -All

# instructors for classes
$enrollmentsInst = $enrollmentsGet.enrollments |
Where-Object role -eq 'teacher' |
Where-Object { $_.user.sourcedid -notin $blacklistUsers.sourcedId } 


# classes csv
$classesGet = Get-ORData -Endpoint "classes" -Filter "status='active'" -All
# blacklist
$blacklistClasses = $classesGet.classes | 
Select-Object *, @{ n = 'YearIndex'; e = { (ConvertFrom-ORK12 -K12 $_.grades[0]).index } } |
Where-Object {
    ($_.classType -ne 'homeroom') -or
    ($_.YearIndex -le 3)
}

#classes
$classes = $classesGet.classes |
Where-object sourcedid -notin $blacklistClasses.sourcedId | 
select-object @{n = 'class_id'; e = { $_.sourcedId } },
@{n = 'class_number'; e = { $_.classCode } },
@{n = 'course_id'; e = { $_.course.sourcedId } },
@{n = 'instructor_id'; e = { $null } },
@{n = 'instructor_id_2'; e = { $null } },
@{n = 'instructor_id_3'; e = { $null } },
@{n = 'location_id'; e = { $_.school.sourcedId -join ',' } } 

# merge instructors
foreach ($c in $classes) {
    $i = $enrollmentsInst | where-object { $_.class.sourcedId -eq $c.class_id }
    if ($i) {
        $c.instructor_id = $i[0].user.sourcedId
    }
    if ($i.count -gt 1) {
        $n = 2
        foreach ($t in $i[1..2]) {
            $c."instructor_id_$n" = $t.user.sourcedId
            $n++
        }
    }
}

$classes | export-csv ./csv-asm/classes.csv

# roster csv 
$enrollmentsStu = $enrollmentsGet.enrollments |
Where-Object role -eq 'student' |
Where-Object { $_.class.sourcedid -notin $blacklistClasses.sourcedId } |
Where-Object { $_.user.sourcedid -notin $blacklistUsers.sourcedId } |
select-object @{n = 'roster_id'; e = { $_.sourcedId } },
@{n = 'class_id'; e = { $_.class.sourcedId } },
@{n = 'student_id'; e = { $_.user.sourcedId } } 

$enrollmentsStu | export-csv ./csv-asm/rosters.csv

# export
$d = Get-Date -Format FileDateTime
Compress-Archive ./csv-asm/*.csv "./csv-asm-$d.zip"
