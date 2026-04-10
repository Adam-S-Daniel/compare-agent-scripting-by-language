#!/usr/bin/env pwsh
# Run-TestHarness.ps1
#
# Outer test harness that:
#   1. Validates workflow structure (YAML, actionlint, file references)
#   2. Sets up the repo and runs `act push --rm`
#   3. Saves all output to act-result.txt
#   4. Asserts on EXACT EXPECTED VALUES from the aggregated results
#
# Expected fixture totals (computed from fixtures at design time):
#   junit-run1.xml: 5 tests  (3 passed, 1 failed [FlakeTest], 1 skipped)
#   junit-run2.xml: 5 tests  (4 passed, 0 failed, 1 skipped)
#   json-run1.json: 3 tests  (2 passed, 1 failed [JsonFailTest], 0 skipped)
#   -----------------------------------------------------------------------
#   TOTAL:         13 tests  (9 passed, 2 failed, 2 skipped)
#   FLAKY:          1 test   (AppTests.UnitTests::FlakeTest)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir   = $PSScriptRoot
$actResultFile = Join-Path $scriptDir "act-result.txt"
$workflowFile  = Join-Path $scriptDir ".github/workflows/test-results-aggregator.yml"

# Clear / create the act-result.txt artifact
"" | Set-Content -Path $actResultFile -Encoding utf8

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = (Get-Date).ToString("HH:mm:ss")
    $line = "[$ts][$Level] $Message"
    Write-Host $line
    $line | Add-Content -Path $actResultFile -Encoding utf8
}

function Add-Separator {
    param([string]$Label)
    $sep = "=" * 70
    $block = @"
$sep
TEST CASE: $Label
$sep
"@
    Write-Host $block
    $block | Add-Content -Path $actResultFile -Encoding utf8
}

function Assert-Equal {
    param([string]$Name, $Actual, $Expected)
    if ($Actual -eq $Expected) {
        Write-Log "PASS: $Name = $Actual" "PASS"
    } else {
        Write-Log "FAIL: $Name expected '$Expected' but got '$Actual'" "FAIL"
        throw "Assertion failed: $Name"
    }
}

function Assert-Contains {
    param([string]$Name, [string]$Haystack, [string]$Needle)
    if ($Haystack -match [regex]::Escape($Needle)) {
        Write-Log "PASS: $Name contains '$Needle'" "PASS"
    } else {
        Write-Log "FAIL: $Name does not contain '$Needle'" "FAIL"
        throw "Assertion failed: $Name"
    }
}

function Assert-Matches {
    param([string]$Name, [string]$Haystack, [string]$Pattern)
    if ($Haystack -match $Pattern) {
        Write-Log "PASS: $Name matches pattern '$Pattern'" "PASS"
    } else {
        Write-Log "FAIL: $Name does not match pattern '$Pattern'" "FAIL"
        throw "Assertion failed: $Name"
    }
}

# ============================================================
# SECTION 1: Workflow structure tests (no act needed)
# ============================================================
Add-Separator "Workflow Structure Validation"

Write-Log "Checking workflow file exists..."
if (-not (Test-Path $workflowFile)) {
    throw "Workflow file not found: $workflowFile"
}
Write-Log "PASS: Workflow file exists" "PASS"

$workflowContent = Get-Content $workflowFile -Raw

# Check triggers
Assert-Matches "trigger:push"            $workflowContent "on:"
Assert-Matches "trigger:push-event"      $workflowContent "push:"
Assert-Matches "trigger:pull_request"    $workflowContent "pull_request:"
Assert-Matches "trigger:workflow_dispatch" $workflowContent "workflow_dispatch:"
Assert-Matches "trigger:schedule"        $workflowContent "schedule:"

# Check required steps
Assert-Matches "step:checkout"           $workflowContent "actions/checkout"
Assert-Matches "step:pwsh-shell"         $workflowContent "shell: pwsh"
Assert-Matches "step:script-ref"         $workflowContent "Aggregate-TestResults"
Assert-Matches "step:pester"             $workflowContent "Invoke-Pester"

# Check script file exists
$srcPath = Join-Path $scriptDir "src/Aggregate-TestResults.ps1"
if (-not (Test-Path $srcPath)) { throw "Script file not found: $srcPath" }
Write-Log "PASS: src/Aggregate-TestResults.ps1 exists" "PASS"

# Check fixture files
$fixtures = Get-ChildItem (Join-Path $scriptDir "fixtures") -File
Assert-Equal "fixture-count" $fixtures.Count 3
Write-Log "PASS: All 3 fixture files present" "PASS"

# Actionlint validation
Write-Log "Running actionlint..."
$actionlintOut = & actionlint $workflowFile 2>&1
$actionlintExit = $LASTEXITCODE
$actionlintOut | Add-Content -Path $actResultFile -Encoding utf8
if ($actionlintExit -ne 0) {
    throw "actionlint failed with exit code $actionlintExit: $actionlintOut"
}
Write-Log "PASS: actionlint exit code 0" "PASS"

# ============================================================
# SECTION 2: Run act - single comprehensive run
# Exercises both jobs: run-pester-tests + aggregate-and-summarize
# ============================================================
Add-Separator "act push --rm (Full Pipeline)"

Write-Log "Starting act push --rm ..."
Write-Log "This runs all Pester tests and the aggregator inside Docker..."

# Capture act output; tee to act-result.txt and keep in memory for assertions
$actOutput = ""
$actLines  = [System.Collections.Generic.List[string]]::new()

try {
    $proc = Start-Process -FilePath "act" `
        -ArgumentList "push", "--rm" `
        -WorkingDirectory $scriptDir `
        -RedirectStandardOutput "$env:TEMP/act-stdout.txt" `
        -RedirectStandardError  "$env:TEMP/act-stderr.txt" `
        -NoNewWindow -PassThru -Wait

    $stdout = Get-Content "$env:TEMP/act-stdout.txt" -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content "$env:TEMP/act-stderr.txt" -Raw -ErrorAction SilentlyContinue
    $actOutput = "$stdout`n$stderr"
    $actExit   = $proc.ExitCode
} catch {
    $actOutput = "ERROR starting act: $_"
    $actExit   = 1
}

# Append full act output to act-result.txt
$actOutput | Add-Content -Path $actResultFile -Encoding utf8

Write-Log "act exit code: $actExit"

# ============================================================
# SECTION 3: Assert on exact values from act output
# ============================================================
Add-Separator "Assertions on act Output"

# Assert act exit code 0
Assert-Equal "act-exit-code" $actExit 0

# Assert both jobs succeeded
Assert-Matches "job:run-pester-tests-succeeded" $actOutput "Job succeeded"

# Assert exact metric values from the aggregator output
# These match the fixture totals computed at design time
Assert-Matches "metric:TotalTests=13"    $actOutput "METRIC:TotalTests=13"
Assert-Matches "metric:TotalPassed=9"    $actOutput "METRIC:TotalPassed=9"
Assert-Matches "metric:TotalFailed=2"    $actOutput "METRIC:TotalFailed=2"
Assert-Matches "metric:TotalSkipped=2"   $actOutput "METRIC:TotalSkipped=2"
Assert-Matches "metric:FlakyCount=1"     $actOutput "METRIC:FlakyCount=1"
Assert-Matches "metric:FlakyTest"        $actOutput "METRIC:FlakyTest=AppTests.UnitTests::FlakeTest"

# Assert markdown summary contains expected content
Assert-Matches "summary:header"          $actOutput "Test Results Summary"
Assert-Matches "summary:total-13"        $actOutput "Total Tests.*13"
Assert-Matches "summary:passed-9"        $actOutput "Passed.*9"
Assert-Matches "summary:flaky-section"   $actOutput "(?i)flaky"
Assert-Matches "summary:FlakeTest-name"  $actOutput "FlakeTest"

# Assert Pester passed all tests
Assert-Matches "pester:all-passed"       $actOutput "(?i)passed"

# ============================================================
# Summary
# ============================================================
Add-Separator "Test Harness Complete"
Write-Log "All assertions passed. Full output saved to: $actResultFile" "PASS"
Write-Host ""
Write-Host "act-result.txt written to: $actResultFile"
