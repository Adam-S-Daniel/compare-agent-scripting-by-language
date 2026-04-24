# Test harness: sets up temp git repos, runs act for each test case,
# validates exact expected values in act output, saves results to act-result.txt.

param(
    [string]$ActResultFile = "$PSScriptRoot/act-result.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ActResultPath = $ActResultFile

# Clear previous results
if (Test-Path $ActResultPath) { Remove-Item $ActResultPath }

# Workflow structure tests (no act required)
Write-Host "`n=== WORKFLOW STRUCTURE TESTS ===" -ForegroundColor Cyan

# Test 1: workflow file exists
$workflowPath = Join-Path $ProjectRoot ".github/workflows/semantic-version-bumper.yml"
if (-not (Test-Path $workflowPath)) {
    throw "FAIL: Workflow file not found at $workflowPath"
}
Write-Host "PASS: Workflow file exists at .github/workflows/semantic-version-bumper.yml"

# Test 2: workflow references script files that exist
$requiredFiles = @(
    "SemanticVersionBumper.ps1",
    "SemanticVersionBumper.Tests.ps1",
    "fixtures/commits-patch.txt",
    "fixtures/commits-minor.txt",
    "fixtures/commits-major.txt",
    "fixtures/version.txt",
    "fixtures/package.json"
)
foreach ($f in $requiredFiles) {
    $fullPath = Join-Path $ProjectRoot $f
    if (-not (Test-Path $fullPath)) {
        throw "FAIL: Required file missing: $f"
    }
    Write-Host "PASS: $f exists"
}

# Test 3: actionlint passes
Write-Host "`nRunning actionlint..."
$lintResult = & actionlint $workflowPath 2>&1
$lintExitCode = $LASTEXITCODE
if ($lintExitCode -ne 0) {
    throw "FAIL: actionlint failed with exit code $lintExitCode`n$lintResult"
}
Write-Host "PASS: actionlint passed with exit code 0"

# Test 4: workflow YAML has expected structure
$workflowContent = Get-Content $workflowPath -Raw
$yaml = $workflowContent
if ($yaml -notmatch 'on:') { throw "FAIL: workflow missing 'on:' triggers" }
if ($yaml -notmatch 'push:') { throw "FAIL: workflow missing push trigger" }
if ($yaml -notmatch 'pull_request:') { throw "FAIL: workflow missing pull_request trigger" }
if ($yaml -notmatch 'workflow_dispatch:') { throw "FAIL: workflow missing workflow_dispatch trigger" }
if ($yaml -notmatch 'actions/checkout@v4') { throw "FAIL: workflow missing actions/checkout@v4" }
if ($yaml -notmatch 'shell: pwsh') { throw "FAIL: workflow missing shell: pwsh" }
Write-Host "PASS: Workflow has expected triggers and structure"

Add-Content -Path $ActResultPath -Value "=== WORKFLOW STRUCTURE TESTS ==="
Add-Content -Path $ActResultPath -Value "PASS: workflow file exists"
Add-Content -Path $ActResultPath -Value "PASS: all referenced script files exist"
Add-Content -Path $ActResultPath -Value "PASS: actionlint exit code 0"
Add-Content -Path $ActResultPath -Value "PASS: workflow has expected structure (push, pull_request, workflow_dispatch, checkout@v4, shell:pwsh)"
Add-Content -Path $ActResultPath -Value ""

# Helper: set up a temp git repo with all project files committed
function New-TempActRepo {
    param([string]$Suffix = "")
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "svb-act-$Suffix-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmpDir | Out-Null

    # Copy all project files
    $itemsToCopy = @(
        "SemanticVersionBumper.ps1",
        "SemanticVersionBumper.Tests.ps1",
        "fixtures"
    )
    foreach ($item in $itemsToCopy) {
        $src = Join-Path $ProjectRoot $item
        if (Test-Path $src -PathType Container) {
            Copy-Item -Recurse $src "$tmpDir/$item"
        } else {
            Copy-Item $src "$tmpDir/$item"
        }
    }

    # Copy .github/workflows directory
    $workflowsDir = Join-Path $tmpDir ".github/workflows"
    New-Item -ItemType Directory -Path $workflowsDir | Out-Null
    Copy-Item $workflowPath "$workflowsDir/semantic-version-bumper.yml"

    # Copy .actrc for Docker image configuration
    $actrc = Join-Path $ProjectRoot ".actrc"
    if (Test-Path $actrc) {
        Copy-Item $actrc "$tmpDir/.actrc"
    }

    # Initialize git repo with all files committed (required for actions/checkout@v4 in act)
    & git -C $tmpDir init -q
    & git -C $tmpDir config user.email "test@example.com"
    & git -C $tmpDir config user.name "Test"
    & git -C $tmpDir add .
    & git -C $tmpDir commit -q -m "chore: test setup"

    return $tmpDir
}

# Helper: run act and capture output
function Invoke-Act {
    param(
        [string]$RepoDir,
        [string]$TestCaseName
    )

    Write-Host "`n=== ACT TEST: $TestCaseName ===" -ForegroundColor Cyan
    Write-Host "Repo: $RepoDir"

    Push-Location $RepoDir
    try {
        $output = & act push --rm --pull=false 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    $outputText = $output -join "`n"

    # Append to act-result.txt
    Add-Content -Path $ActResultPath -Value "=== ACT TEST: $TestCaseName ==="
    Add-Content -Path $ActResultPath -Value "Exit code: $exitCode"
    Add-Content -Path $ActResultPath -Value $outputText
    Add-Content -Path $ActResultPath -Value ""

    return @{
        ExitCode = $exitCode
        Output   = $outputText
    }
}

# Helper: assert a condition, writing result to act-result.txt
function Assert-ActOutput {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message
    )
    if ($Condition) {
        Write-Host "  PASS: $TestName" -ForegroundColor Green
        Add-Content -Path $ActResultPath -Value "  PASS: $TestName"
    } else {
        Write-Host "  FAIL: $TestName - $Message" -ForegroundColor Red
        Add-Content -Path $ActResultPath -Value "  FAIL: $TestName - $Message"
        throw "Assertion failed: $TestName - $Message"
    }
}

# Run act once with the full workflow (all test scenarios in one pass)
$tmpRepo = New-TempActRepo -Suffix "all"
$result = Invoke-Act -RepoDir $tmpRepo -TestCaseName "Full workflow (all scenarios)"

Write-Host "`n=== VALIDATING ACT OUTPUT ===" -ForegroundColor Cyan
Add-Content -Path $ActResultPath -Value "=== ASSERTIONS ==="

# Assert exit code
Assert-ActOutput -TestName "act exit code 0" `
    -Condition ($result.ExitCode -eq 0) `
    -Message "act exited with code $($result.ExitCode)"

# Assert job succeeded
Assert-ActOutput -TestName "Job succeeded" `
    -Condition ($result.Output -match 'Job succeeded') `
    -Message "Output does not contain 'Job succeeded'"

# Assert exact version values
Assert-ActOutput -TestName "Patch bump result is exactly 1.1.1" `
    -Condition ($result.Output -match 'PATCH_BUMP_RESULT=1\.1\.1') `
    -Message "Expected PATCH_BUMP_RESULT=1.1.1 not found in output"

Assert-ActOutput -TestName "Minor bump result is exactly 1.2.0" `
    -Condition ($result.Output -match 'MINOR_BUMP_RESULT=1\.2\.0') `
    -Message "Expected MINOR_BUMP_RESULT=1.2.0 not found in output"

Assert-ActOutput -TestName "Major bump result is exactly 2.0.0" `
    -Condition ($result.Output -match 'MAJOR_BUMP_RESULT=2\.0\.0') `
    -Message "Expected MAJOR_BUMP_RESULT=2.0.0 not found in output"

Assert-ActOutput -TestName "JSON bump result is exactly 2.4.0" `
    -Condition ($result.Output -match 'JSON_BUMP_RESULT=2\.4\.0') `
    -Message "Expected JSON_BUMP_RESULT=2.4.0 not found in output"

Assert-ActOutput -TestName "Patch pass confirmation" `
    -Condition ($result.Output -match 'PATCH_BUMP_PASS=true') `
    -Message "PATCH_BUMP_PASS=true not found"

Assert-ActOutput -TestName "Minor pass confirmation" `
    -Condition ($result.Output -match 'MINOR_BUMP_PASS=true') `
    -Message "MINOR_BUMP_PASS=true not found"

Assert-ActOutput -TestName "Major pass confirmation" `
    -Condition ($result.Output -match 'MAJOR_BUMP_PASS=true') `
    -Message "MAJOR_BUMP_PASS=true not found"

Assert-ActOutput -TestName "JSON pass confirmation" `
    -Condition ($result.Output -match 'JSON_BUMP_PASS=true') `
    -Message "JSON_BUMP_PASS=true not found"

Assert-ActOutput -TestName "Changelog pass confirmation" `
    -Condition ($result.Output -match 'CHANGELOG_PASS=true') `
    -Message "CHANGELOG_PASS=true not found"

Assert-ActOutput -TestName "All tests passed summary" `
    -Condition ($result.Output -match 'ALL_TESTS_PASSED=true') `
    -Message "ALL_TESTS_PASSED=true not found"

# Clean up temp repo
Remove-Item $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue

Add-Content -Path $ActResultPath -Value ""
Add-Content -Path $ActResultPath -Value "=== ALL ASSERTIONS PASSED ==="
Write-Host "`nAll assertions passed! Results saved to: $ActResultPath" -ForegroundColor Green
