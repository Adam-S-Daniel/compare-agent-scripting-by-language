# Run-ActTests.ps1
# Test harness that drives 'act push' for each test case, captures output to
# act-result.txt, and asserts exact expected values from the aggregator output.
#
# Designed for PowerShell 7+. Requires act, Docker, and git on PATH.
# Must be run from the project root directory.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot  = $PSScriptRoot
$ActResultFile = Join-Path $ProjectRoot "act-result.txt"

# Clear previous results
if (Test-Path $ActResultFile) { Remove-Item $ActResultFile }
New-Item -ItemType File -Path $ActResultFile | Out-Null

# ---------------------------------------------------------------------------
# Helper: strip ANSI escape sequences from act output so pattern matching works
# ---------------------------------------------------------------------------
function Remove-AnsiCodes {
    param([string]$Text)
    return $Text -replace '\x1B\[[0-9;]*[mGKHF]', '' -replace '\x1B\][^\x07]*\x07', ''
}

# ---------------------------------------------------------------------------
# Helper: set up a temp git repo, run act push --rm, capture and save output
# Returns: @{ ExitCode=int; Output=string }
# ---------------------------------------------------------------------------
function Invoke-ActRun {
    param(
        [string]$Label,              # test case label written to act-result.txt
        [hashtable]$Fixtures         # filename -> content for ./fixtures/
    )

    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    try {
        # Copy all project files into the temp repo
        $ItemsToCopy = @(
            'Invoke-TestResultsAggregator.ps1',
            'tests',
            '.github',
            '.actrc'
        )
        foreach ($item in $ItemsToCopy) {
            $src = Join-Path $ProjectRoot $item
            if (Test-Path $src -PathType Leaf) {
                Copy-Item $src (Join-Path $TempDir $item) -Force
            }
            elseif (Test-Path $src -PathType Container) {
                Copy-Item $src (Join-Path $TempDir $item) -Recurse -Force
            }
        }

        # Write test-case-specific fixture files
        $fixtureDir = Join-Path $TempDir "fixtures"
        New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
        foreach ($name in $Fixtures.Keys) {
            Set-Content -Path (Join-Path $fixtureDir $name) -Value $Fixtures[$name]
        }

        # Initialize git repo and commit
        Push-Location $TempDir
        & git init --quiet
        & git config user.email "test@example.com"
        & git config user.name "Test Runner"
        & git add -A
        & git commit -m "test: fixture set for $Label" --quiet

        Write-Host "Running act for: $Label ..."
        $rawOutput = & act push --rm --pull=false 2>&1
        $exitCode  = $LASTEXITCODE
        $output    = ($rawOutput | ForEach-Object { Remove-AnsiCodes ($_ | Out-String).TrimEnd() }) -join "`n"

        return @{ ExitCode = $exitCode; Output = $output }
    }
    finally {
        Pop-Location
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Helper: assert that a string contains an expected pattern
# ---------------------------------------------------------------------------
function Assert-Contains {
    param([string]$Output, [string]$Pattern, [string]$Description)
    if ($Output -notmatch [regex]::Escape($Pattern)) {
        Write-Error "FAIL [$Description]: expected pattern '$Pattern' not found in output."
        return $false
    }
    Write-Host "  PASS: $Description"
    return $true
}

# ===========================================================================
# Test Case 1: Full matrix (4 fixture files — JUnit x2 + JSON x2)
# Expected: Total=12, Passed=6, Failed=4, Skipped=2, Duration=3.25s
#           Flaky tests: TestC, TestF
# ===========================================================================

$Fixtures1 = @{
    'junit-run1.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Suite.UnitTests" tests="4" failures="1" skipped="1" time="0.60">
    <testcase name="TestA" classname="Suite.UnitTests" time="0.10"/>
    <testcase name="TestB" classname="Suite.UnitTests" time="0.20">
      <failure message="Expected 1 but got 2">AssertionError</failure>
    </testcase>
    <testcase name="TestC" classname="Suite.UnitTests" time="0.30"/>
    <testcase name="TestD" classname="Suite.UnitTests" time="0.00">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
'@
    'junit-run2.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Suite.UnitTests" tests="4" failures="2" skipped="1" time="0.75">
    <testcase name="TestA" classname="Suite.UnitTests" time="0.15"/>
    <testcase name="TestB" classname="Suite.UnitTests" time="0.25">
      <failure message="Expected 1 but got 2">AssertionError</failure>
    </testcase>
    <testcase name="TestC" classname="Suite.UnitTests" time="0.35">
      <failure message="Timeout exceeded">TimeoutError</failure>
    </testcase>
    <testcase name="TestD" classname="Suite.UnitTests" time="0.00">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
'@
    'json-run1.json' = @'
{
  "suiteName": "Suite.IntegrationTests",
  "tests": [
    { "name": "TestE", "status": "passed", "duration": 0.40 },
    { "name": "TestF", "status": "passed", "duration": 0.50 }
  ]
}
'@
    'json-run2.json' = @'
{
  "suiteName": "Suite.IntegrationTests",
  "tests": [
    { "name": "TestE", "status": "passed", "duration": 0.45 },
    { "name": "TestF", "status": "failed", "duration": 0.55, "error": "Connection refused" }
  ]
}
'@
}

$result1 = Invoke-ActRun -Label "Full-Matrix" -Fixtures $Fixtures1

Add-Content -Path $ActResultFile -Value "=== Test Case 1: Full Matrix (JUnit x2 + JSON x2) ==="
Add-Content -Path $ActResultFile -Value $result1.Output
Add-Content -Path $ActResultFile -Value ""

Write-Host ""
Write-Host "--- Asserting Test Case 1: Full Matrix ---"
$tc1Pass = $true

if ($result1.ExitCode -ne 0) {
    Write-Error "FAIL: act exited with code $($result1.ExitCode) for Test Case 1"
    $tc1Pass = $false
}
else {
    Write-Host "  PASS: act exited 0"
}

$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "Job succeeded"         "Job succeeded")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "| Total | 12 |"         "Total = 12")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "| Passed | 6 |"         "Passed = 6")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "| Failed | 4 |"         "Failed = 4")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "| Skipped | 2 |"        "Skipped = 2")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "3.25s"                  "Duration = 3.25s")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "| TestC |"              "Flaky: TestC")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "| TestF |"              "Flaky: TestF")
$tc1Pass = $tc1Pass -and (Assert-Contains $result1.Output "Tests Passed: 3"        "Pester: 30+ tests passed")

# ===========================================================================
# Test Case 2: JUnit only (1 file — single run, no flaky tests possible)
# Expected: Total=4, Passed=2, Failed=1, Skipped=1, Duration=0.60s, Flaky=0
# ===========================================================================

$Fixtures2 = @{
    'junit-run1.xml' = $Fixtures1['junit-run1.xml']
}

$result2 = Invoke-ActRun -Label "JUnit-Only" -Fixtures $Fixtures2

Add-Content -Path $ActResultFile -Value "=== Test Case 2: JUnit Only (single run) ==="
Add-Content -Path $ActResultFile -Value $result2.Output
Add-Content -Path $ActResultFile -Value ""

Write-Host ""
Write-Host "--- Asserting Test Case 2: JUnit Only ---"
$tc2Pass = $true

if ($result2.ExitCode -ne 0) {
    Write-Error "FAIL: act exited with code $($result2.ExitCode) for Test Case 2"
    $tc2Pass = $false
}
else {
    Write-Host "  PASS: act exited 0"
}

$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "Job succeeded"         "Job succeeded")
$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "| Total | 4 |"          "Total = 4")
$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "| Passed | 2 |"         "Passed = 2")
$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "| Failed | 1 |"         "Failed = 1")
$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "| Skipped | 1 |"        "Skipped = 1")
$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "0.6s"                   "Duration = 0.6s")
$tc2Pass = $tc2Pass -and (Assert-Contains $result2.Output "No flaky tests"         "No flaky tests")

# ===========================================================================
# Final summary
# ===========================================================================

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Test Case 1 (Full Matrix): $(if ($tc1Pass) { 'PASS' } else { 'FAIL' })"
Write-Host "Test Case 2 (JUnit Only):  $(if ($tc2Pass) { 'PASS' } else { 'FAIL' })"
Write-Host "act-result.txt written to: $ActResultFile"

if (-not ($tc1Pass -and $tc2Pass)) {
    Write-Error "One or more test cases FAILED. See act-result.txt for details."
    exit 1
}

Write-Host "All act test cases PASSED."
