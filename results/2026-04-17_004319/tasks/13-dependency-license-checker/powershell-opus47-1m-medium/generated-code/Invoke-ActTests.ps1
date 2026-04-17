#!/usr/bin/env pwsh
# Test harness: runs the GitHub Actions workflow through `act` once per fixture case,
# appending output to act-result.txt and asserting on the exact expected summary line.
#
# Strategy to stay within the 3-run limit: we run `act` once per unique fixture triplet
# (manifest + license-config + license-db). We prepare a single temp workspace and
# swap fixtures between runs by overwriting files before each invocation.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here      = Split-Path -Parent $PSCommandPath
$resultLog = Join-Path $here 'act-result.txt'
if (Test-Path $resultLog) { Remove-Item $resultLog -Force }

# Structure/actionlint tests first — these are cheap and required.
Write-Host "=== structural checks ==="

$wfPath = Join-Path $here '.github/workflows/dependency-license-checker.yml'
if (-not (Test-Path $wfPath)) { throw "workflow file missing: $wfPath" }

# actionlint exit code check
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed with exit code $LASTEXITCODE" }
Write-Host "actionlint: OK"

# YAML structure parse
Install-Module powershell-yaml -Scope CurrentUser -Force -ErrorAction SilentlyContinue | Out-Null
Import-Module powershell-yaml -ErrorAction SilentlyContinue
$wfText = Get-Content $wfPath -Raw
if ($wfText -notmatch 'actions/checkout@v4') { throw "missing actions/checkout@v4" }
if ($wfText -notmatch 'Invoke-LicenseChecker\.ps1') { throw "workflow does not reference Invoke-LicenseChecker.ps1" }
foreach ($trigger in @('push:','pull_request:','workflow_dispatch:','schedule:')) {
    if ($wfText -notmatch [regex]::Escape($trigger)) { throw "workflow missing trigger '$trigger'" }
}
foreach ($ref in @('LicenseChecker.psm1','LicenseChecker.Tests.ps1','Invoke-LicenseChecker.ps1','fixtures/licenses.json')) {
    if (-not (Test-Path (Join-Path $here $ref))) { throw "referenced path missing: $ref" }
}
Write-Host "structure: OK"

# Test fixtures — each defines manifest contents, a license DB, and the
# exact expected SUMMARY line we should see in the workflow output.
$cases = @(
    @{
        Name       = 'all-approved-package-json'
        Manifest   = 'package.json'
        ManifestBody = @'
{
  "name": "demo",
  "dependencies": { "alpha": "1.0.0", "beta": "2.0.0" },
  "devDependencies": { "gamma": "3.0.0" }
}
'@
        LicenseDb  = '{"alpha":"MIT","beta":"Apache-2.0","gamma":"ISC"}'
        Expected   = 'SUMMARY total=3 approved=3 denied=0 unknown=0'
    },
    @{
        Name       = 'denied-license-present'
        Manifest   = 'package.json'
        ManifestBody = @'
{
  "name": "demo",
  "dependencies": { "alpha": "1.0.0", "evil": "9.9.9" }
}
'@
        LicenseDb  = '{"alpha":"MIT","evil":"GPL-3.0"}'
        Expected   = 'SUMMARY total=2 approved=1 denied=1 unknown=0'
    },
    @{
        Name       = 'requirements-txt-with-unknowns'
        Manifest   = 'requirements.txt'
        ManifestBody = @'
requests==2.31.0
mystery>=0.1.0
'@
        LicenseDb  = '{"requests":"Apache-2.0"}'
        Expected   = 'SUMMARY total=2 approved=1 denied=0 unknown=1'
    }
)

# For each case: write that case's fixture into a disposable temp git repo,
# run act, capture output, assert. Limit: 3 act runs total.
$allPass = $true
foreach ($c in $cases) {
    Write-Host ""
    Write-Host "=== CASE: $($c.Name) ==="
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("lcact-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy project files
    foreach ($f in 'LicenseChecker.psm1','LicenseChecker.Tests.ps1','Invoke-LicenseChecker.ps1','.actrc') {
        Copy-Item (Join-Path $here $f) (Join-Path $tmp $f)
    }
    New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
    Copy-Item $wfPath (Join-Path $tmp '.github/workflows/dependency-license-checker.yml')
    New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') -Force | Out-Null
    Copy-Item (Join-Path $here 'fixtures/licenses.json') (Join-Path $tmp 'fixtures/licenses.json')

    # Write case-specific manifest + license DB
    Set-Content -LiteralPath (Join-Path $tmp $c.Manifest) -Value $c.ManifestBody
    Set-Content -LiteralPath (Join-Path $tmp 'fixtures/license-db.json') -Value $c.LicenseDb

    # Minimal git repo — act requires one.
    Push-Location $tmp
    try {
        git init -q
        git config user.email bench@example.com
        git config user.name  bench
        git add -A
        git commit -q -m 'case fixture'

        $env:MANIFEST_PATH_INPUT = $c.Manifest
        # Pass the manifest name via an env file so the workflow's default can be overridden.
        $envFile = Join-Path $tmp '.env'
        "MANIFEST_PATH=$($c.Manifest)" | Set-Content -LiteralPath $envFile

        $output = & act push --rm --pull=false --env-file $envFile 2>&1 | Out-String
        $exit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    Add-Content -LiteralPath $resultLog -Value ("`n========== CASE: " + $c.Name + " ==========`n")
    Add-Content -LiteralPath $resultLog -Value $output
    Add-Content -LiteralPath $resultLog -Value ("exit=" + $exit)

    $pass = $true
    if ($exit -ne 0)                                        { Write-Host "FAIL: act exit=$exit"; $pass = $false }
    if ($output -notmatch [regex]::Escape($c.Expected))     { Write-Host "FAIL: expected line not found: $($c.Expected)"; $pass = $false }
    if ($output -notmatch 'Job succeeded')                  { Write-Host "FAIL: no 'Job succeeded' line"; $pass = $false }

    if ($pass) { Write-Host "PASS: $($c.Name)" } else { $allPass = $false }
}

Write-Host ""
if ($allPass) {
    Write-Host "ALL ACT TESTS PASSED"
    exit 0
} else {
    Write-Host "ONE OR MORE ACT TESTS FAILED — see $resultLog"
    exit 1
}
