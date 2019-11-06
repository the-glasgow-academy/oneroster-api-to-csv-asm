# Oneroster API to CSV for ASM

A powershell script to create Apple School Manager compatible csv files
from a Oneroster compliant API.

## Usage

Requires: Powershell Core

```
$VerbosePreference = 'continue'
$env:GOORS_URL = 'https://my-oneroster-api/ims/oneroster/v1p1'
$env:GOORS_CI = read-host #clientid
$env:GOORS_CS = read-host #clientsecret

. ConvertFrom-K12.ps1
./sds-asm.ps1
```

Use sftp to drop the `csv-asm-$(unix-date).zip` file to your ASM sftp instance.
