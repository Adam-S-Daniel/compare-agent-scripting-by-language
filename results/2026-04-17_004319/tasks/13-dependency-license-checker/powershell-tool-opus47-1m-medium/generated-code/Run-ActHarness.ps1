# Harness: for each test case, build a throwaway git repo containing our
# project files + the case's fixture data, run `act push --rm`, capture
# output, and assert on exact expected values.
# Limit: at most 3 act invocations total (one per case).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ResultFile  = Join-Path $ProjectRoot 'act-result.txt'
Remove-Item -LiteralPath $ResultFile -ErrorAction Ignore
New-Item -ItemType File -Path $ResultFile | Out-Null

$cases = @(
    @{
        Name     = 'all-approved'
        Package  = '{ "dependencies": { "lodash": "1.0.0", "express": "4.0.0" } }'
        Data     = '{ "lodash": "MIT", "express": "Apache-2.0" }'
        Expect   = @{
            ExpectedStatuses = @{ lodash = 'approved'; express = 'approved' }
            DeniedCount      = 0
            ApprovedCount    = 2
            UnknownCount     = 0
        }
    },
    @{
        Name     = 'has-denied'
        Package  = '{ "dependencies": { "lodash": "1.0.0", "evil": "0.1.0" } }'
        Data     = '{ "lodash": "MIT", "evil": "GPL-3.0" }'
        Expect   = @{
            ExpectedStatuses = @{ lodash = 'approved'; evil = 'denied' }
            DeniedCount      = 1
            ApprovedCount    = 1
            UnknownCount     = 0
        }
    },
    @{
        Name     = 'has-unknown'
        Package  = '{ "dependencies": { "mystery": "9.9.9" } }'
        Data     = '{}'
        Expect   = @{
            ExpectedStatuses = @{ mystery = 'unknown' }
            DeniedCount      = 0
            ApprovedCount    = 0
            UnknownCount     = 1
        }
    }
)

$config = '{ "allow": ["MIT","Apache-2.0","BSD-3-Clause","ISC"], "deny": ["GPL-3.0","AGPL-3.0"] }'

function Invoke-Case {
    param([hashtable]$Case)

    $work = Join-Path ([IO.Path]::GetTempPath()) ("lic-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        Copy-Item (Join-Path $ProjectRoot 'LicenseChecker.ps1')       $work
        Copy-Item (Join-Path $ProjectRoot 'LicenseChecker.Tests.ps1') $work
        Copy-Item (Join-Path $ProjectRoot '.github') $work -Recurse
        Copy-Item (Join-Path $ProjectRoot '.actrc') $work

        $fix = Join-Path $work 'fixtures'
        New-Item -ItemType Directory -Path $fix | Out-Null
        Set-Content (Join-Path $fix 'package.json')        $Case.Package
        Set-Content (Join-Path $fix 'license-config.json') $config
        Set-Content (Join-Path $fix 'license-data.json')   $Case.Data

        Push-Location $work
        try {
            git init -q
            git -c user.email=t@t -c user.name=t add .
            git -c user.email=t@t -c user.name=t commit -q -m "case $($Case.Name)"
            $out = & act push --rm --pull=false 2>&1
            $exit = $LASTEXITCODE
        } finally { Pop-Location }

        Add-Content $ResultFile ("=" * 72)
        Add-Content $ResultFile "CASE: $($Case.Name)   exit=$exit"
        Add-Content $ResultFile ("=" * 72)
        Add-Content $ResultFile ($out -join [Environment]::NewLine)
        return [pscustomobject]@{ Case = $Case; Output = ($out -join "`n"); Exit = $exit }
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Ignore
    }
}

$failures = @()
foreach ($c in $cases) {
    Write-Host "`n===> Running case: $($c.Name)" -ForegroundColor Cyan
    $r = Invoke-Case -Case $c

    if ($r.Exit -ne 0) { $failures += "[$($c.Name)] act exit=$($r.Exit)" }

    # Both jobs must succeed — act prints "Job succeeded" per job on success.
    $jobSucceededCount = ([regex]::Matches($r.Output, 'Job succeeded')).Count
    if ($jobSucceededCount -lt 2) {
        $failures += "[$($c.Name)] expected >=2 'Job succeeded', got $jobSucceededCount"
    }

    # Assert each dep appears with its exact expected status.
    foreach ($dep in $c.Expect.ExpectedStatuses.Keys) {
        $want = $c.Expect.ExpectedStatuses[$dep]
        $pattern = "$dep\s+\S+\s+\S+\s+$want"
        if ($r.Output -notmatch $pattern) {
            $failures += "[$($c.Name)] expected '$dep ... $want' in output"
        }
    }

    # Assert exact summary counts.
    $want = "Summary . approved: $($c.Expect.ApprovedCount), denied: $($c.Expect.DeniedCount), unknown: $($c.Expect.UnknownCount)"
    if ($r.Output -notmatch $want) {
        $failures += "[$($c.Name)] expected summary matching '$want'"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "`nFAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nAll $($cases.Count) act cases passed with exact-value assertions." -ForegroundColor Green
Write-Host "Output saved to: $ResultFile"
