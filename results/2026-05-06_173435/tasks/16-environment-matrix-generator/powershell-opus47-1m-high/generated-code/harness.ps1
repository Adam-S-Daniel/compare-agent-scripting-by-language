#!/usr/bin/env pwsh
# harness.ps1 — End-to-end test harness for the Environment Matrix Generator.
#
# For each test case in $TestCases:
#   1. Builds an isolated git working copy of the project + that case's fixture.
#   2. Runs `act push --rm`, capturing the full output.
#   3. Appends the output to ./act-result.txt (delimited per case).
#   4. Asserts:
#        - act exit code is 0
#        - every job in the run shows "Job succeeded"
#        - the printed markers match the case's exact expected values
#
# Run:  pwsh -File harness.ps1
# Exits non-zero if any assertion fails.

param([switch] $KeepWorkdirs)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$resultLog = Join-Path $root 'act-result.txt'

# --- test cases -------------------------------------------------------------
# Each case names a fixture and the EXACT marker values its run should print.
# Expected sizes were computed by hand from the fixtures:
#   basic                  : 2 OS x 2 node = 4 combos
#   with-excludes-includes : 3 x 2 x 2 = 12 base; exclude 2 (windows,*,off)
#                            and 2 (macos,3.11,*); + 1 include = 9
#   oversized              : 3 x 7 = 21 combos but max-size=10 -> validation
#                            error (MATRIX_FAIL)
$TestCases = @(
    @{
        Name              = 'basic'
        Fixture           = 'fixtures/basic.json'
        ExpectMarker      = 'MATRIX_OK'
        ExpectSize        = 4
        ExpectFailFast    = 'True'
        ExpectMaxParallel = '4'
        ExpectJsonContains = @('"os":"ubuntu-latest"', '"os":"macos-latest"', '"node":"18"', '"node":"20"')
    },
    @{
        Name              = 'with-excludes-includes'
        Fixture           = 'fixtures/with-excludes-includes.json'
        ExpectMarker      = 'MATRIX_OK'
        ExpectSize        = 9
        ExpectFailFast    = 'False'
        ExpectMaxParallel = '6'
        ExpectJsonContains = @('"experimental":true', '"python":"3.13"')
        # The exclude rules must remove every windows+off and every macos+3.11
        # combination; assert their absence from the JSON.
        ExpectJsonAbsent  = @(
            '"os":"windows-latest","python":"3.11","feature":"off"',
            '"os":"windows-latest","python":"3.12","feature":"off"',
            '"os":"macos-latest","python":"3.11","feature":"on"',
            '"os":"macos-latest","python":"3.11","feature":"off"'
        )
    },
    @{
        Name           = 'oversized'
        Fixture        = 'fixtures/oversized.json'
        ExpectMarker   = 'MATRIX_FAIL'
        ExpectErrorRegex = 'exceeds max-size \(10\)'
    }
)

# --- helpers ----------------------------------------------------------------

function New-IsolatedWorkdir {
    param([string] $Source, [string] $FixturePath)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("matrix-gen-act-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    # Copy the project files (skip ephemeral output and any prior workdir).
    Copy-Item -Path (Join-Path $Source '*') -Destination $tmp -Recurse -Force `
        -Exclude @('act-result.txt', 'matrix-out.json', '.git')
    # Place the fixture as ./fixture.json (workflow's first lookup path).
    $fix = Join-Path $Source $FixturePath
    Copy-Item -LiteralPath $fix -Destination (Join-Path $tmp 'fixture.json') -Force
    # act needs a git repo to determine the push event payload.
    Push-Location $tmp
    try {
        git init --quiet --initial-branch=main 2>$null
        git -c user.email=ci@example.com -c user.name=ci add -A 2>$null
        git -c user.email=ci@example.com -c user.name=ci commit --quiet -m "harness: $FixturePath" 2>$null
    } finally { Pop-Location }
    return $tmp
}

function Invoke-ActPush {
    param([string] $Workdir)
    Push-Location $Workdir
    try {
        # --rm removes containers after the run; --pull=false uses the
        # local act-ubuntu-pwsh:latest image (already built); -W targets
        # just our workflow file.
        $output = & act push --rm --pull=false -W .github/workflows/environment-matrix-generator.yml 2>&1
        $code = $LASTEXITCODE
        return @{ Output = ($output -join "`n"); ExitCode = $code }
    } finally { Pop-Location }
}

function Test-CaseAssertions {
    param([hashtable] $Case, [hashtable] $Run)

    $errors = New-Object System.Collections.Generic.List[string]

    if ($Run.ExitCode -ne 0) {
        $errors.Add("act exited $($Run.ExitCode), expected 0")
    }

    # "Job succeeded" must appear for every job that ran.
    $succeeded = ([regex]::Matches($Run.Output, 'Job succeeded')).Count
    if ($succeeded -lt 2) {
        $errors.Add("expected at least 2 'Job succeeded' lines (unit-tests + generate); saw $succeeded")
    }

    # Marker assertions.
    if ($Case.ExpectMarker -eq 'MATRIX_OK') {
        if ($Run.Output -notmatch '\bMATRIX_OK\b') { $errors.Add("missing MATRIX_OK marker") }
        if ($Run.Output -match '\bMATRIX_FAIL\b') { $errors.Add("unexpected MATRIX_FAIL marker") }

        if ($Run.Output -match 'MATRIX_SIZE=(\d+)') {
            $actual = [int]$Matches[1]
            if ($actual -ne $Case.ExpectSize) {
                $errors.Add("MATRIX_SIZE: expected $($Case.ExpectSize), got $actual")
            }
        } else { $errors.Add("missing MATRIX_SIZE marker") }

        if ($Run.Output -match 'MATRIX_FAIL_FAST=(\S+)') {
            if ($Matches[1] -ne $Case.ExpectFailFast) {
                $errors.Add("MATRIX_FAIL_FAST: expected $($Case.ExpectFailFast), got $($Matches[1])")
            }
        } else { $errors.Add("missing MATRIX_FAIL_FAST marker") }

        if ($Run.Output -match 'MATRIX_MAX_PARALLEL=(\S+)') {
            if ($Matches[1] -ne $Case.ExpectMaxParallel) {
                $errors.Add("MATRIX_MAX_PARALLEL: expected $($Case.ExpectMaxParallel), got $($Matches[1])")
            }
        } else { $errors.Add("missing MATRIX_MAX_PARALLEL marker") }

        # JSON content checks: extract the block between BEGIN and END.
        if ($Run.Output -match '(?s)MATRIX_JSON_BEGIN\s+(.+?)\s+MATRIX_JSON_END') {
            $jsonBody = $Matches[1] -replace '\s+', ''
            foreach ($needle in @($Case.ExpectJsonContains)) {
                if ($jsonBody -notmatch [regex]::Escape($needle)) {
                    $errors.Add("matrix JSON missing expected substring: $needle")
                }
            }
            if ($Case.ContainsKey('ExpectJsonAbsent')) {
                foreach ($needle in @($Case.ExpectJsonAbsent)) {
                    if ($jsonBody -match [regex]::Escape($needle)) {
                        $errors.Add("matrix JSON contains forbidden substring: $needle")
                    }
                }
            }
        } else { $errors.Add("could not extract MATRIX_JSON_BEGIN..END block") }
    }
    else {  # MATRIX_FAIL case
        if ($Run.Output -notmatch '\bMATRIX_FAIL\b') { $errors.Add("missing MATRIX_FAIL marker") }
        if ($Run.Output -match '\bMATRIX_OK\b') { $errors.Add("unexpected MATRIX_OK marker for failure case") }
        if ($Run.Output -match 'MATRIX_ERROR=(.+)') {
            if ($Matches[1] -notmatch $Case.ExpectErrorRegex) {
                $errors.Add("MATRIX_ERROR did not match /$($Case.ExpectErrorRegex)/; got: $($Matches[1])")
            }
        } else { $errors.Add("missing MATRIX_ERROR marker") }
    }

    return ,$errors.ToArray()
}

# --- main loop --------------------------------------------------------------

# Truncate the result log at the start of each harness run.
Set-Content -Path $resultLog -Value "Environment Matrix Generator — act test harness`n" -Encoding utf8

$totalFails = 0
foreach ($case in $TestCases) {
    Write-Host "===== running case: $($case.Name) ====="

    $workdir = New-IsolatedWorkdir -Source $root -FixturePath $case.Fixture
    Write-Host "  workdir: $workdir"

    $run = Invoke-ActPush -Workdir $workdir
    $delimiter = "`n========== CASE: $($case.Name) | exit=$($run.ExitCode) ==========`n"
    Add-Content -Path $resultLog -Value $delimiter
    Add-Content -Path $resultLog -Value $run.Output

    $errors = Test-CaseAssertions -Case $case -Run $run
    if ($errors.Count -eq 0) {
        Write-Host "  PASS"
        Add-Content -Path $resultLog -Value "`n>>> RESULT: PASS"
    } else {
        $totalFails++
        Write-Host "  FAIL ($($errors.Count) errors):"
        foreach ($e in $errors) { Write-Host "    - $e" }
        Add-Content -Path $resultLog -Value "`n>>> RESULT: FAIL"
        foreach ($e in $errors) { Add-Content -Path $resultLog -Value "    - $e" }
    }

    if (-not $KeepWorkdirs) {
        Remove-Item -Path $workdir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  (kept workdir for inspection)"
    }
}

# --- workflow structure tests ----------------------------------------------
# These run after act-based tests because they're cheap; they confirm the
# YAML parses, references valid actions, and points at files that exist.

Write-Host "===== workflow structure assertions ====="
$structureFails = 0

$wfPath = Join-Path $root '.github/workflows/environment-matrix-generator.yml'
if (-not (Test-Path $wfPath)) { Write-Host "  FAIL: workflow file missing"; $structureFails++ }

# actionlint exit code 0
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { Write-Host "  FAIL: actionlint exit $LASTEXITCODE"; $structureFails++ }
else { Write-Host "  PASS: actionlint clean" }

# Parse YAML to confirm shape.
$wfText = Get-Content $wfPath -Raw
foreach ($trigger in @('push:', 'pull_request:', 'workflow_dispatch:', 'schedule:')) {
    if ($wfText -notmatch [regex]::Escape($trigger)) {
        Write-Host "  FAIL: workflow missing trigger '$trigger'"
        $structureFails++
    }
}
foreach ($jobId in @('unit-tests:', 'generate:')) {
    if ($wfText -notmatch [regex]::Escape($jobId)) {
        Write-Host "  FAIL: workflow missing job '$jobId'"
        $structureFails++
    }
}
foreach ($file in @('MatrixGenerator.psm1', 'tests', 'fixture.json')) {
    if ($wfText -notmatch [regex]::Escape($file)) {
        Write-Host "  FAIL: workflow does not reference '$file'"
        $structureFails++
    }
}
foreach ($pathRef in @('MatrixGenerator.psm1', 'tests', 'fixtures/basic.json')) {
    if (-not (Test-Path (Join-Path $root $pathRef))) {
        Write-Host "  FAIL: referenced path missing: $pathRef"
        $structureFails++
    }
}
if ($structureFails -eq 0) { Write-Host "  PASS: workflow structure" }

# --- summary ---------------------------------------------------------------
$total = $TestCases.Count
$pass = $total - $totalFails
Write-Host ""
Write-Host "===== HARNESS SUMMARY ====="
Write-Host "  act cases: $pass / $total passed"
Write-Host "  workflow-structure failures: $structureFails"
Add-Content -Path $resultLog -Value "`n========== SUMMARY ==========`nact cases: $pass / $total passed`nworkflow-structure failures: $structureFails"

if (($totalFails -gt 0) -or ($structureFails -gt 0)) { exit 1 }
exit 0
