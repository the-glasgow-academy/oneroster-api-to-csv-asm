function Initialize-BlacklistUser {
    $pConn = @{
        url   = $env:GOR_API_URL
        token = $env:GOR_API_TOKEN
    }
    $c = Get-ApiContent @pConn -Endpoint 'users' -All
    
    $f = $c.Users |
    Select-Object *,@{ n = 'YearIndex'; e = { convertfrom-k12 -Year $_.grades -ToIndex } } |
    Where-Object {
        ($_.familyName -like '*ACCOUNT*') -or
        ($_.YearIndex -ge 0 -and $_.YearIndex -le 3) -or 
        ($_.YearIndex -ge 10 -and $_.YearIndex -le 16)
    }
    return $f
}
