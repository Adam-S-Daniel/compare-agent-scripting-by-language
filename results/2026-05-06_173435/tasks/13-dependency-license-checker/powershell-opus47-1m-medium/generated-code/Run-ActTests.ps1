#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Drive the dependency-license-checker workflow through `act` for every
    fixture and assert the act output matches known-good values exactly.

.DESCRIPTION
    For each fixture case we:
      1. Build a temp directory, copy the project sources + that case's
         fixtures into it, and `git init` it.
      2. Run `act push --rm` once, capturing stdout+stderr.
      3. Append the output to ./act-result.txt (in the original cwd) with a
         clear delimiter.
      4. Assert that act exited 0 (i.e. the workflow succeeded), every job
         shows "Job succeeded", and the parsed summary line matches the
         exact expected counts for that fixture.
#>
[CmdletBinding()]
param(
    [string] $ResultFile = (Join-Path (Get-Location) 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSCommandPath
Set-Location $repoRoot

# Fresh result file so reruns don't accumulate stale output.
Set-Content -LiteralPath $ResultFile -Value ''

# ---------------- Workflow structure preflight ----------------
# These assertions cost nothing and catch bad workflow edits before we burn
# act runs.
Write-Host '==> workflow structure checks' -ForegroundColor Cyan
$wfPath = Join-Path $repoRoot '.github/workflows/dependency-license-checker.yml'
if (-not (Test-Path $wfPath)) { throw "workflow file missing: $wfPath" }

# 1) actionlint must exit 0.
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed with exit $LASTEXITCODE" }

# 2) YAML structure: triggers, jobs, and step refs to our scripts.
$wfText = Get-Content -LiteralPath $wfPath -Raw
foreach ($needle in @(
    'on:', 'push:', 'pull_request:', 'schedule:', 'workflow_dispatch:',
    'jobs:', 'unit-tests:', 'license-check:',
    'actions/checkout@v4',
    'LicenseChecker.Tests.ps1',
    'Invoke-LicenseCheck.ps1'
)) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        throw "workflow missing expected fragment: '$needle'"
    }
}

# 3) Referenced script files exist at the paths the workflow expects.
foreach ($f in 'LicenseChecker.psm1','LicenseChecker.Tests.ps1','Invoke-LicenseCheck.ps1') {
    if (-not (Test-Path (Join-Path $repoRoot $f))) {
        throw "workflow references missing file: $f"
    }
}
Write-Host '    OK' -ForegroundColor Green


# Each case carries its own fixtures + expected exact summary counts. We pick
# inputs that exercise approved-only, mixed-with-unknown, and a Python
# requirements.txt so the parser path gets coverage too. The "denied" case is
# omitted because the workflow's enforce step is designed to fail the job on
# denied deps and we need every act run to exit 0.
$cases = @(
    [pscustomobject]@{
        Name     = 'all-approved-package-json'
        Manifest = @{ Path = 'fixtures/package.json'; Content = @'
{
  "name": "demo",
  "dependencies": { "left-pad": "1.3.0", "lodash": "4.17.21" },
  "devDependencies": { "jest": "29.0.0" }
}
'@ }
        Policy   = '{ "allow": ["MIT","Apache-2.0"], "deny": ["GPL-3.0"] }'
        MockDb   = '{ "left-pad": "MIT", "lodash": "MIT", "jest": "MIT" }'
        Expected = 'license-check summary: total=3 approved=3 denied=0 unknown=0'
    },
    [pscustomobject]@{
        Name     = 'mixed-with-unknown-package-json'
        Manifest = @{ Path = 'fixtures/package.json'; Content = @'
{
  "name": "demo",
  "dependencies": { "lodash": "4.17.21", "mystery-lib": "0.0.1" }
}
'@ }
        Policy   = '{ "allow": ["MIT","Apache-2.0"], "deny": ["GPL-3.0"] }'
        MockDb   = '{ "lodash": "MIT" }'
        Expected = 'license-check summary: total=2 approved=1 denied=0 unknown=1'
    },
    [pscustomobject]@{
        Name     = 'requirements-txt'
        Manifest = @{ Path = 'fixtures/package.json'; Content = '{}' }   # placeholder
        AltManifest = @{ Path = 'fixtures/requirements.txt'; Content = "requests==2.31.0`nflask==2.3.0`n# comment`nnumpy`n" }
        Policy   = '{ "allow": ["Apache-2.0","BSD-3-Clause"], "deny": ["GPL-3.0"] }'
        MockDb   = '{ "requests": "Apache-2.0", "flask": "BSD-3-Clause", "numpy": "BSD-3-Clause" }'
        Expected = 'license-check summary: total=3 approved=3 denied=0 unknown=0'
        ManifestEnv = 'fixtures/requirements.txt'
    }
)

# Files copied verbatim into each scratch repo. Keep this minimal — just the
# project bits the workflow needs to run.
$projectFiles = @(
    'LicenseChecker.psm1'
    'LicenseChecker.Tests.ps1'
    'Invoke-LicenseCheck.ps1'
    '.actrc'
)

function New-ScratchRepo {
    param([pscustomobject]$Case)

    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null

    foreach ($f in $projectFiles) {
        Copy-Item -Path (Join-Path $repoRoot $f) -Destination (Join-Path $dir $f) -Force
    }

    # Workflow tree.
    New-Item -ItemType Directory -Path (Join-Path $dir '.github/workflows') -Force | Out-Null
    Copy-Item `
        -Path (Join-Path $repoRoot '.github/workflows/dependency-license-checker.yml') `
        -Destination (Join-Path $dir '.github/workflows/dependency-license-checker.yml')

    # Fixture files.
    New-Item -ItemType Directory -Path (Join-Path $dir 'fixtures') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir $Case.Manifest.Path) -Value $Case.Manifest.Content
    if ($Case.PSObject.Properties.Name -contains 'AltManifest' -and $Case.AltManifest) {
        Set-Content -LiteralPath (Join-Path $dir $Case.AltManifest.Path) -Value $Case.AltManifest.Content
    }
    Set-Content -LiteralPath (Join-Path $dir 'fixtures/license-policy.json') -Value $Case.Policy
    Set-Content -LiteralPath (Join-Path $dir 'fixtures/mock-licenses.json')  -Value $Case.MockDb

    # act needs a real git repo to evaluate the push event.
    Push-Location $dir
    try {
        git init -q -b main | Out-Null
        git config user.email 'ci@example.com'
        git config user.name  'ci'
        git add -A
        git commit -q -m 'fixture' | Out-Null
    } finally {
        Pop-Location
    }
    return $dir
}

$failures = @()

foreach ($case in $cases) {
    Write-Host "==> case: $($case.Name)" -ForegroundColor Cyan
    $dir = New-ScratchRepo -Case $case

    # The third case uses workflow_dispatch so we can override the manifest
    # input (push events ignore inputs and use the env default).
    $useDispatch = $case.PSObject.Properties.Name -contains 'ManifestEnv' -and $case.ManifestEnv

    $logPath = Join-Path $dir 'act.log'
    Push-Location $dir
    try {
        if ($useDispatch) {
            & act workflow_dispatch --rm --pull=false --input "manifest=$($case.ManifestEnv)" *> $logPath
        } else {
            & act push --rm --pull=false *> $logPath
        }
        $exit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    $log = Get-Content -LiteralPath $logPath -Raw

    # Append to top-level act-result.txt with a clear delimiter.
    Add-Content -LiteralPath $ResultFile -Value ("`n===== CASE: {0} (act exit={1}) =====`n{2}" -f $case.Name, $exit, $log)

    # ---- Assertions ----
    $caseFailures = @()
    if ($exit -ne 0) {
        $caseFailures += "act exited $exit (expected 0)"
    }

    # Both jobs (unit-tests and license-check) must report success.
    $jobMatches = [regex]::Matches($log, 'Job succeeded')
    if ($jobMatches.Count -lt 2) {
        $caseFailures += "expected at least 2 'Job succeeded' lines, found $($jobMatches.Count)"
    }

    if ($log -notmatch [regex]::Escape($case.Expected)) {
        $caseFailures += "summary line did not match exactly. expected: '$($case.Expected)'"
    }

    if ($caseFailures.Count -gt 0) {
        $failures += [pscustomobject]@{ Case = $case.Name; Reasons = $caseFailures }
        Write-Host "    FAIL: $($caseFailures -join '; ')" -ForegroundColor Red
    } else {
        Write-Host "    OK"   -ForegroundColor Green
    }

    Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "FAILED cases:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host " - $($f.Case): $($f.Reasons -join '; ')" }
    exit 1
}
Write-Host "All act-driven cases passed." -ForegroundColor Green
exit 0
