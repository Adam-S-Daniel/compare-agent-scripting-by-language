<#
.SYNOPSIS
    End-to-end test harness: drives every test case through the GitHub Actions
    workflow via `act`, captures the output to act-result.txt, and asserts on
    EXACT expected values (not just "something appeared").
.NOTES
    All testing of the script happens through the pipeline, per task spec.
    Limited to <=3 act invocations.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resultFile = Join-Path $PSScriptRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
'' | Set-Content -Path $resultFile -Encoding utf8

# Each test case = an input fixture and the EXACT counters/verdict we expect to
# observe in the workflow's stdout.
$cases = @(
    [pscustomobject]@{
        Name     = 'clean-package-json'
        Manifest = 'fixtures/case-clean/package.json'
        Expect   = 'RESULT approved=3 denied=0 unknown=0'
        Verdict  = 'RESULT verdict=PASS'
    }
    [pscustomobject]@{
        Name     = 'denied-gpl'
        Manifest = 'fixtures/case-denied/package.json'
        Expect   = 'RESULT approved=1 denied=1 unknown=0'
        Verdict  = 'RESULT verdict=FAIL'
    }
    [pscustomobject]@{
        Name     = 'mixed-requirements'
        Manifest = 'fixtures/case-mixed/requirements.txt'
        Expect   = 'RESULT approved=3 denied=0 unknown=1'
        Verdict  = 'RESULT verdict=PASS'
    }
)

# Build a single "matrix" run by appending all three manifest paths into one
# act invocation via three sequential MANIFEST values would normally need three
# `act push` calls — but the spec caps us at 3 runs total, so we do one run per
# case (3 runs). We set MANIFEST through the act `--env` flag.

function Invoke-ActForCase {
    param(
        [string] $Manifest,
        [string] $WorkDir
    )
    Push-Location $WorkDir
    try {
        # Capture combined stdout+stderr.
        $output = & act push --rm --pull=false --env "MANIFEST=$Manifest" 2>&1 | Out-String
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Output = $output; ExitCode = $code }
    }
    finally {
        Pop-Location
    }
}

# Set up an isolated git repo containing the project + fixtures and run act
# against it. We do this once and reuse the dir; only MANIFEST changes per run.
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("license-check-act-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $tempDir | Out-Null
Write-Host "Staging act repo at $tempDir"

# Copy project files into the temp dir.
$copyTargets = @(
    'LicenseChecker.psm1',
    'LicenseChecker.Tests.ps1',
    'Invoke-LicenseChecker.ps1',
    'licenses.config.json',
    'fixtures',
    '.github',
    '.actrc'
)
foreach ($t in $copyTargets) {
    $src = Join-Path $PSScriptRoot $t
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $tempDir -Recurse -Force
    }
}

Push-Location $tempDir
try {
    git init -q
    git add -A
    git -c user.name=ci -c user.email=ci@ci commit -q -m "test fixture" | Out-Null
}
finally {
    Pop-Location
}

$failures = New-Object System.Collections.Generic.List[string]

foreach ($case in $cases) {
    Write-Host "===== Running case: $($case.Name) (manifest=$($case.Manifest)) ====="
    $delim = "================ CASE: $($case.Name) ================"
    Add-Content -Path $resultFile -Value $delim
    Add-Content -Path $resultFile -Value "manifest=$($case.Manifest)"

    $r = Invoke-ActForCase -Manifest $case.Manifest -WorkDir $tempDir
    Add-Content -Path $resultFile -Value $r.Output
    Add-Content -Path $resultFile -Value "ACT_EXIT_CODE=$($r.ExitCode)"

    # Assertion 1: act exit code == 0.
    if ($r.ExitCode -ne 0) {
        $failures.Add("[$($case.Name)] act exit code $($r.ExitCode) (expected 0)")
    }

    # Assertion 2: every job shows "Job succeeded".
    $jobSucceeded = ([regex]::Matches($r.Output, 'Job succeeded')).Count
    if ($jobSucceeded -lt 2) {
        $failures.Add("[$($case.Name)] expected >=2 'Job succeeded' lines, found $jobSucceeded")
    }

    # Assertion 3: exact counter match for this case.
    if ($r.Output -notmatch [regex]::Escape($case.Expect)) {
        $failures.Add("[$($case.Name)] missing expected counters: $($case.Expect)")
    }

    # Assertion 4: exact verdict for this case.
    if ($r.Output -notmatch [regex]::Escape($case.Verdict)) {
        $failures.Add("[$($case.Name)] missing expected verdict: $($case.Verdict)")
    }
}

Write-Host ""
Write-Host "===== Test summary ====="
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "FAIL: $f" }
    Add-Content -Path $resultFile -Value "HARNESS_RESULT=FAIL"
    exit 1
}
Write-Host "All $($cases.Count) cases passed end-to-end through act."
Add-Content -Path $resultFile -Value "HARNESS_RESULT=PASS"
exit 0
