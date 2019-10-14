function Initialize-BlacklistClass {
    $pConn = @{
        url   = $env:GOR_API_URL
        token = $env:GOR_API_TOKEN
    }
    $c = Get-ApiContent @pConn -Endpoint 'classes' -All

    $f = $c.Classes | Where-Object {
        {$_.classType -ne 'homeroom'}
    } |
    Select-Object *,@{ n = 'YearIndex'; e = { convertfrom-k12 -Year $_.grades -ToIndex } } |
    Where-Object { $_.YearIndex -le 3 }
    return $f
}
