# Run-ActTests.ps1
# Test harness: runs the GitHub Actions workflow via `act` for each test case,
# captures output to act-result.txt, and asserts on exact expected values.
#
# All Pester unit tests run inside the workflow — this script only validates
# the act execution and parses verifiable output.

param(
    [string]$ActResultFile = "$PSScriptRoot/act-result.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Clear/create results file
"" | Set-Content $ActResultFile

$projectRoot = $PSScriptRoot
$failed      = $false

function Write-Result {
    param([string]$Text)
    $Text | Add-Content -Path $ActResultFile
    Write-Host $Text
}

function Assert-Contains {
    param([string[]]$Lines, [string]$Pattern, [string]$Reason)
    $hit = $Lines | Where-Object { $_ -match [regex]::Escape($Pattern) -or $_ -match $Pattern }
    if (-not $hit) {
        Write-Result "ASSERTION FAILED: expected '$Pattern' ($Reason)"
        $script:failed = $true
    }
    else {
        Write-Result "OK: found '$Pattern' ($Reason)"
    }
}

# ---------------------------------------------------------------------------
# Test case 1 — Run the full workflow via act (covers all Pester unit tests
# AND the sample-matrix generation job).
# ---------------------------------------------------------------------------

Write-Result "================================================================"
Write-Result "TEST CASE 1: Full workflow run via act push"
Write-Result "================================================================"

# Run act in the project directory; capture combined stdout+stderr
# -p=false: skip pulling images (act-ubuntu-pwsh:latest is pre-loaded locally)
$actOutput = & act push --rm -p=false 2>&1 | ForEach-Object { "$_" }
$actExitCode = $LASTEXITCODE

Write-Result ""
Write-Result "--- act output ---"
$actOutput | ForEach-Object { Write-Result $_ }
Write-Result "--- end act output ---"
Write-Result ""

# Assert exit code 0
if ($actExitCode -ne 0) {
    Write-Result "ASSERTION FAILED: act exited with code $actExitCode (expected 0)"
    $failed = $true
}
else {
    Write-Result "OK: act exited with code 0"
}

# Assert all jobs succeeded
Assert-Contains $actOutput "Job succeeded" "both jobs must report success"

# Assert Pester reported 23 passing tests
Assert-Contains $actOutput "Tests Passed: 23" "all 23 Pester tests passed"

# Assert the sample matrix generation produced expected output
Assert-Contains $actOutput "=== Generated Matrix ===" "matrix generation job ran"
Assert-Contains $actOutput "OS count      : 3" "3 OS values in sample matrix"
Assert-Contains $actOutput "Node versions : 18, 20, 22" "correct node versions in sample"
Assert-Contains $actOutput "Fail-fast     : False" "fail-fast is false in sample"
Assert-Contains $actOutput "Max-parallel  : 6" "max-parallel is 6 in sample"
Assert-Contains $actOutput "Includes      : 1" "1 include entry in sample"
Assert-Contains $actOutput "Excludes      : 1" "1 exclude entry in sample"

# Assert matrix size guard triggered on oversized config
Assert-Contains $actOutput "Matrix size guard correctly rejected oversized config" "size guard rejection validated"

Write-Result ""
Write-Result "================================================================"
Write-Result "WORKFLOW STRUCTURE TESTS"
Write-Result "================================================================"

# --- Verify workflow file exists ---
$wfPath = "$projectRoot/.github/workflows/environment-matrix-generator.yml"
if (-not (Test-Path $wfPath)) {
    Write-Result "ASSERTION FAILED: workflow file not found at $wfPath"
    $failed = $true
}
else {
    Write-Result "OK: workflow file exists"
}

# --- Verify script file exists ---
$scriptPath = "$projectRoot/New-BuildMatrix.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Result "ASSERTION FAILED: script file not found at $scriptPath"
    $failed = $true
}
else {
    Write-Result "OK: script file exists"
}

# --- Verify test file exists ---
$testPath = "$projectRoot/New-BuildMatrix.Tests.ps1"
if (-not (Test-Path $testPath)) {
    Write-Result "ASSERTION FAILED: test file not found at $testPath"
    $failed = $true
}
else {
    Write-Result "OK: test file exists"
}

# --- Parse workflow YAML structure ---
$wfContent = Get-Content $wfPath -Raw

# Expected triggers
foreach ($trigger in @("push", "pull_request", "schedule", "workflow_dispatch")) {
    if ($wfContent -match $trigger) {
        Write-Result "OK: workflow contains trigger '$trigger'"
    }
    else {
        Write-Result "ASSERTION FAILED: workflow missing trigger '$trigger'"
        $failed = $true
    }
}

# Expected jobs
foreach ($job in @("test", "generate-sample")) {
    if ($wfContent -match $job) {
        Write-Result "OK: workflow contains job '$job'"
    }
    else {
        Write-Result "ASSERTION FAILED: workflow missing job '$job'"
        $failed = $true
    }
}

# Workflow references the script
if ($wfContent -match "New-BuildMatrix\.ps1") {
    Write-Result "OK: workflow references New-BuildMatrix.ps1"
}
else {
    Write-Result "ASSERTION FAILED: workflow does not reference New-BuildMatrix.ps1"
    $failed = $true
}

# Workflow references the test file
if ($wfContent -match "New-BuildMatrix\.Tests\.ps1") {
    Write-Result "OK: workflow references New-BuildMatrix.Tests.ps1"
}
else {
    Write-Result "ASSERTION FAILED: workflow does not reference New-BuildMatrix.Tests.ps1"
    $failed = $true
}

# --- actionlint ---
Write-Result ""
Write-Result "--- actionlint ---"
$lintOutput = & actionlint $wfPath 2>&1 | ForEach-Object { "$_" }
$lintExit   = $LASTEXITCODE
$lintOutput | ForEach-Object { Write-Result $_ }
if ($lintExit -eq 0) {
    Write-Result "OK: actionlint passed"
}
else {
    Write-Result "ASSERTION FAILED: actionlint reported errors (exit $lintExit)"
    $failed = $true
}

Write-Result ""
Write-Result "================================================================"
if ($failed) {
    Write-Result "RESULT: SOME ASSERTIONS FAILED — see above"
    exit 1
}
else {
    Write-Result "RESULT: ALL ASSERTIONS PASSED"
    exit 0
}
