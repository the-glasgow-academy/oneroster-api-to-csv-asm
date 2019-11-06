#requires -psedition core
$uri = $env:GOORS_URL # "https://or.localhost/ims/oneroster/v1p1"
$ci = $env:GOORS_CI # API clientid
$cs = $env:GOORS_CS # API clientsecret

# check for CEDS conversion commandlet
try {ConvertFrom-K12}
catch {
    write-error "Missing cmdlet: ConvertFrom-K12"
    break   
}

# Test/create csv directory
if (!(test-path ./csv-asm)) {
    new-item -itemtype directory -path ./csv-asm
}

if (!$env:GOORS_TOKEN) {
    $loginP = @{
        uri = "$uri/login"
        method = "POST"
        body = "clientid=$ci&clientsecret=$cs"
        SkipCertificateCheck = $true
    }
    $env:GOORS_TOKEN = Invoke-RestMethod @loginP
}

$getP = @{
    method               = "GET"
    headers              = @{"Authorization" = "bearer $ENV:GOORS_TOKEN" }
    FollowRelLink        = $true
    SkipCertificateCheck = $true
}

# locations csv
$orgsGet = invoke-restmethod @getP -uri "$uri/orgs"

$orgs = $orgsGet.orgs |
    select-object @{n = 'location_id'; e = { $_.sourcedid } },
    @{n = 'location_name'; e = { $_.name } } 

$orgs | export-csv ./csv-asm/locations.csv


# users
$usersGet = invoke-restmethod @getP -uri "$uri/users"
# blacklist
$blacklistUsers = $usersGet.Users |
    Select-Object *, @{ n = 'YearIndex'; e = { convertfrom-k12 -Year $_.grades -ToIndex } } |
    Where-Object {
        ($_.status -eq 'inactive') -or
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
$coursesGet = invoke-restmethod @getP -uri "$uri/courses?filter=courseCode='TG'"
$courses = $coursesGet.courses |
    select-object @{n = 'course_id'; e = { $_.sourcedId } },
    @{n = 'course_number'; e = { $_.courseCode } },
    @{n = 'course_name'; e = { $_.title } },
    @{n = 'location_id'; e = { $_.org.sourcedId } } 

$courses | export-csv ./csv-asm/courses.csv

# classes csv
$classesGet = invoke-restmethod @getP -uri "$uri/classes?filter=status='active'"
# blacklist
$blacklistClasses = $classesGet.classes | 
    Where-Object {
        { $_.classType -ne 'homeroom' }
    } |
    Select-Object *, @{ n = 'YearIndex'; e = { convertfrom-k12 -Year $_.grades -ToIndex } } |
    Where-Object { $_.YearIndex -le 3 }

#classes
$classes = $classesGet.classes |
    Where-Object classType -eq 'homeroom' |
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
$enrollmentsGet = invoke-restmethod @getP -uri "$uri/enrollments?filter=status='active'"

$enrollmentsStu = $enrollmentsGet.enrollments |
    Where-Object role -eq 'student' |
    Where-Object { $_.class.sourcedid -notin $blacklistClasses.sourcedId } |
    Where-Object { $_.user.sourcedid -notin $blacklistUsers.sourcedId } |
    select-object @{n = 'roster_id'; e = { $_.sourcedId } },
    @{n = 'class_id'; e = { $_.class.sourcedId } },
    @{n = 'student_id'; e = { $_.user.sourcedId } } 

$enrollmentsStu | export-csv ./csv-asm/rosters.csv

$enrollmentsInst = $enrollmentsGet.enrollments |
    Where-Object role -eq 'teacher'

$d = Get-Date -Format o
Compress-Archive ./csv-asm/*.csv "./csv-asm-$d.zip"
