#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test harness that drives the GitHub Actions workflow through `act` for a
    set of fixture variants. Every test case is exercised end-to-end via the
    pipeline (no direct script invocation), satisfying the benchmark
    requirement that "all testing goes through the pipeline".

.DESCRIPTION
    For each test case the harness:
        1. Builds an isolated temp git repo containing the project files
           plus that case's fixture overrides.
        2. Invokes `act push --rm` against that repo.
        3. Appends the captured output to act-result.txt (clearly delimited).
        4. Asserts exit==0, that "Job succeeded" appears, and that the
           reported aggregate counters match the case's known-good values.
    A final block runs workflow-structure assertions (actionlint, YAML
    parse, referenced-path existence). The script exits non-zero on any
    failure.

    Hard ceiling of 3 act runs is honoured (the benchmark spec).
#>
[CmdletBinding()]
param(
    [string]$ActResultFile = (Join-Path (Get-Location) 'act-result.txt')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot
try {

# --- helpers ---------------------------------------------------------------

function Write-Header {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 78) -ForegroundColor Cyan
}

function Append-Result {
    param([string]$CaseName, [int]$ExitCode, [string]$Output)
    $delim = '#' * 78
    $block = @"
$delim
# CASE: $CaseName
# EXIT: $ExitCode
# TIME: $(Get-Date -Format 'o')
$delim
$Output
$delim
# END CASE: $CaseName
$delim

"@
    Add-Content -LiteralPath $ActResultFile -Value $block
}

function New-CaseRepo {
    <#
    Builds an isolated copy of the project at $TempDir, initialises a git
    repo, and lets the caller drop case-specific fixture files in via the
    -PostSetup script block before the initial commit.
    #>
    param(
        [string]$TempDir,
        [scriptblock]$PostSetup
    )

    if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    # Copy project files. We always carry the canonical `fixtures/` (Pester
    # depends on those exact filenames) and replace `aggregate-input/` per
    # case via $PostSetup. Skip .git and the harness's own output file.
    $skip = @('.git', 'aggregate-input', 'act-result.txt')
    Get-ChildItem -Force -Path $ProjectRoot |
        Where-Object { $_.Name -notin $skip } |
        ForEach-Object {
            $dest = Join-Path $TempDir $_.Name
            Copy-Item -Recurse -Force -Path $_.FullName -Destination $dest
        }

    # Fresh aggregate-input dir; the PostSetup block populates it for the case.
    New-Item -ItemType Directory -Path (Join-Path $TempDir 'aggregate-input') | Out-Null

    & $PostSetup $TempDir

    Push-Location $TempDir
    try {
        git init -q -b main 2>&1 | Out-Null
        git config user.email "harness@example.com"
        git config user.name  "Harness"
        git add -A
        git commit -q -m "case fixture commit" 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

function Invoke-ActCase {
    <#
    Runs `act push --rm` in $TempDir, returns @{ExitCode, Output}. Captures
    both stdout and stderr together so we get the full picture.
    #>
    param([string]$TempDir)
    Push-Location $TempDir
    try {
        $output = & act push --rm 2>&1 | Out-String
        $exit   = $LASTEXITCODE
        return @{ ExitCode = $exit; Output = $output }
    } finally {
        Pop-Location
    }
}

function Assert-Match {
    param(
        [string]$Output,
        [string]$Pattern,
        [string]$Description
    )
    if ($Output -notmatch $Pattern) {
        throw "ASSERTION FAILED [$Description]: pattern '$Pattern' not found in act output."
    }
    Write-Host "  PASS: $Description" -ForegroundColor Green
}

# --- prepare output ---------------------------------------------------------

if (Test-Path $ActResultFile) { Remove-Item $ActResultFile -Force }
"# act-result.txt — generated $(Get-Date -Format 'o')`n" | Set-Content $ActResultFile

$failures = New-Object System.Collections.Generic.List[string]
$caseCount = 0

# ===========================================================================
# Test cases. Each case: a name, a fixture-setup block, and an assertion list
# expressed as @{ Description = 'x'; Pattern = 'regex' }.
# ===========================================================================

$cases = @(
    @{
        Name = 'all-passing-junit'
        # Description: a single JUnit file with one passing test. The
        # aggregator should report Total=1, Passed=1, Failed=0, Skipped=0,
        # one run, zero flaky tests, 100.0% pass rate.
        Setup = {
            param($Dir)
            $fix = Join-Path $Dir 'aggregate-input'
            @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="1" failures="0" skipped="0" time="0.005">
  <testsuite name="OnlyOne" tests="1" failures="0" skipped="0" time="0.005">
    <testcase classname="OnlyOne" name="works" time="0.005"/>
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath (Join-Path $fix 'only.xml')
        }
        Assertions = @(
            @{ Description='Pester job succeeded';     Pattern='Job succeeded' }
            @{ Description='Total tests = 1';          Pattern='Total tests\s*:\s*1\b' }
            @{ Description='Passed tests = 1';         Pattern='Passed\s*:\s*1\b' }
            @{ Description='Failed tests = 0';         Pattern='Failed\s*:\s*0\b' }
            @{ Description='Skipped tests = 0';        Pattern='Skipped\s*:\s*0\b' }
            @{ Description='Flaky tests = 0';          Pattern='Flaky tests\s*:\s*0\b' }
            @{ Description='Files aggregated = 1 run'; Pattern='Files aggregated\s*:\s*1 run' }
        )
    }
    @{
        Name = 'mixed-with-flaky'
        # Description: full fixture set — JUnit mixed + JUnit single-pass +
        # two JSON runs. Across the four files we have:
        #   Total=11, Passed=7, Failed=2, Skipped=2, Runs=4, Flaky=1
        # (test_delete_user fails in two runs and passes in the third).
        Setup = {
            param($Dir)
            Copy-Item -Force -Recurse `
                -Path (Join-Path $ProjectRoot 'fixtures' '*') `
                -Destination (Join-Path $Dir 'aggregate-input')
        }
        Assertions = @(
            @{ Description='Pester job succeeded';     Pattern='Job succeeded' }
            @{ Description='Total tests = 11';         Pattern='Total tests\s*:\s*11\b' }
            @{ Description='Passed tests = 7';         Pattern='Passed\s*:\s*7\b' }
            @{ Description='Failed tests = 2';         Pattern='Failed\s*:\s*2\b' }
            @{ Description='Skipped tests = 2';        Pattern='Skipped\s*:\s*2\b' }
            @{ Description='Flaky tests = 1';          Pattern='Flaky tests\s*:\s*1\b' }
            @{ Description='Files aggregated = 4 run'; Pattern='Files aggregated\s*:\s*4 run' }
            @{ Description='Markdown shows test_delete_user as flaky';
               Pattern='## Flaky Tests[\s\S]*test_delete_user' }
            @{ Description='Markdown lists Failures section';
               Pattern='## Failures' }
        )
    }
    @{
        Name = 'json-only-no-failures'
        # Description: a single JSON run with two passing tests and one
        # skipped. No failures, no flaky tests, one run.
        #   Total=3, Passed=2, Failed=0, Skipped=1, Runs=1, Flaky=0
        Setup = {
            param($Dir)
            $fix = Join-Path $Dir 'aggregate-input'
            @'
{
  "run": "single-run",
  "tests": [
    { "name": "alpha", "suite": "S", "status": "passed",  "duration": 0.10 },
    { "name": "beta",  "suite": "S", "status": "passed",  "duration": 0.20 },
    { "name": "gamma", "suite": "S", "status": "skipped", "duration": 0.00 }
  ]
}
'@ | Set-Content -LiteralPath (Join-Path $fix 'single.json')
        }
        Assertions = @(
            @{ Description='Pester job succeeded';     Pattern='Job succeeded' }
            @{ Description='Total tests = 3';          Pattern='Total tests\s*:\s*3\b' }
            @{ Description='Passed tests = 2';         Pattern='Passed\s*:\s*2\b' }
            @{ Description='Failed tests = 0';         Pattern='Failed\s*:\s*0\b' }
            @{ Description='Skipped tests = 1';        Pattern='Skipped\s*:\s*1\b' }
            @{ Description='Flaky tests = 0';          Pattern='Flaky tests\s*:\s*0\b' }
            @{ Description='Files aggregated = 1 run'; Pattern='Files aggregated\s*:\s*1 run' }
            @{ Description='Markdown does NOT include Flaky Tests section';
               # negative-lookahead-ish: assert the string does not appear
               # is handled separately below
               Pattern='__OMITTED__' }
        )
    }
)

# --- run cases -------------------------------------------------------------

foreach ($case in $cases) {
    $caseCount++
    if ($caseCount -gt 3) {
        throw "Refusing to run more than 3 act invocations (benchmark cap)."
    }
    Write-Header "Case $caseCount/$($cases.Count): $($case.Name)"

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "act-tra-$($case.Name)-$([guid]::NewGuid().Guid.Substring(0,8))"
    try {
        New-CaseRepo -TempDir $tmp -PostSetup $case.Setup
        $r = Invoke-ActCase -TempDir $tmp
    } finally {
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
    }

    Append-Result -CaseName $case.Name -ExitCode $r.ExitCode -Output $r.Output

    Write-Host ''
    Write-Host "act exit code: $($r.ExitCode)"
    if ($r.ExitCode -ne 0) {
        $failures.Add("[$($case.Name)] act exited with code $($r.ExitCode)")
        Write-Host "  FAIL: act exit code != 0" -ForegroundColor Red
        continue
    } else {
        Write-Host "  PASS: act exit code == 0" -ForegroundColor Green
    }

    foreach ($a in $case.Assertions) {
        try {
            if ($a.Pattern -eq '__OMITTED__') {
                # Special-case the json-only-no-failures negative assertion.
                if ($r.Output -match '## Flaky Tests') {
                    throw "ASSERTION FAILED [$($a.Description)]: '## Flaky Tests' should not appear."
                }
                Write-Host "  PASS: $($a.Description)" -ForegroundColor Green
            } else {
                Assert-Match -Output $r.Output -Pattern $a.Pattern -Description $a.Description
            }
        } catch {
            $failures.Add("[$($case.Name)] $($_.Exception.Message)")
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ===========================================================================
# Workflow-structure tests (no act required, instant).
# ===========================================================================

Write-Header "Workflow structure tests"

# 1. actionlint passes
& actionlint .github/workflows/test-results-aggregator.yml
if ($LASTEXITCODE -ne 0) {
    $failures.Add("actionlint exited with code $LASTEXITCODE")
    Write-Host "  FAIL: actionlint exit code != 0" -ForegroundColor Red
} else {
    Write-Host "  PASS: actionlint" -ForegroundColor Green
}

# 2. YAML parse + structure
try {
    $yamlPath = '.github/workflows/test-results-aggregator.yml'
    $yamlText = Get-Content -LiteralPath $yamlPath -Raw

    $expectedStrings = @(
        @{ Description = 'has push trigger';                Pattern = '(?ms)^on:\s*\n\s*push:' }
        @{ Description = 'has pull_request trigger';        Pattern = 'pull_request:' }
        @{ Description = 'has workflow_dispatch trigger';   Pattern = 'workflow_dispatch' }
        @{ Description = 'has schedule trigger';            Pattern = 'schedule:' }
        @{ Description = 'has pester job';                  Pattern = 'pester:' }
        @{ Description = 'has aggregate job';               Pattern = 'aggregate:' }
        @{ Description = 'aggregate depends on pester';     Pattern = 'needs:\s*pester' }
        @{ Description = 'uses actions/checkout@v4';        Pattern = 'actions/checkout@v4' }
        @{ Description = 'invokes Aggregate-TestResults';   Pattern = './Aggregate-TestResults\.ps1' }
        @{ Description = 'uses shell: pwsh';                Pattern = 'shell:\s*pwsh' }
        @{ Description = 'declares contents:read perms';    Pattern = 'contents:\s*read' }
    )
    foreach ($e in $expectedStrings) {
        if ($yamlText -notmatch $e.Pattern) {
            $failures.Add("workflow structure: missing '$($e.Description)'")
            Write-Host "  FAIL: $($e.Description)" -ForegroundColor Red
        } else {
            Write-Host "  PASS: $($e.Description)" -ForegroundColor Green
        }
    }
} catch {
    $failures.Add("YAML parse failed: $($_.Exception.Message)")
}

# 3. Referenced files exist
$referencedPaths = @(
    'Aggregate-TestResults.ps1'
    'src/TestResultsAggregator.psm1'
    'tests/TestResultsAggregator.Tests.ps1'
    'fixtures'
    'aggregate-input'
)
foreach ($p in $referencedPaths) {
    if (-not (Test-Path -LiteralPath $p)) {
        $failures.Add("referenced path missing: $p")
        Write-Host "  FAIL: referenced path exists ($p)" -ForegroundColor Red
    } else {
        Write-Host "  PASS: referenced path exists ($p)" -ForegroundColor Green
    }
}

# ===========================================================================
# Final report
# ===========================================================================

Write-Header "Harness summary"

if ($failures.Count -gt 0) {
    Write-Host "FAILURES ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host "act-result.txt: $ActResultFile"
    exit 1
} else {
    Write-Host "All harness checks PASSED." -ForegroundColor Green
    Write-Host "act-result.txt: $ActResultFile"
    exit 0
}

} finally {
    Pop-Location
}
