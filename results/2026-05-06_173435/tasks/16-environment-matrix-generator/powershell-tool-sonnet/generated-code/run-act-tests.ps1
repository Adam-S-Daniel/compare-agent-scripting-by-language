<#
.SYNOPSIS
    Outer test harness: runs act for each test case and verifies output.

.DESCRIPTION
    For each of 3 test cases the harness:
      1. Creates a temp git repository with the project files and the case's fixture
      2. Runs `act push --rm` inside that repo
      3. Appends all output (with delimiters) to act-result.txt in the original directory
      4. Asserts that act exited 0
      5. Asserts on EXACT EXPECTED VALUES extracted from act stdout

    Limited to 3 act runs as required by benchmark constraints.

.NOTES
    Run from the workspace directory:
        pwsh -File run-act-tests.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceDir = $PSScriptRoot
$ActResultFile = Join-Path $WorkspaceDir "act-result.txt"

# Wipe any previous run
if (Test-Path $ActResultFile) { Remove-Item $ActResultFile }

# Files to copy into every temp repo (relative to workspace)
$ProjectFiles = @(
    "New-BuildMatrix.ps1",
    "New-BuildMatrix.Tests.ps1",
    ".actrc"
)
$WorkflowSrc = ".github/workflows/environment-matrix-generator.yml"
$FixtureSrcDir = "fixtures"

# ---------------------------------------------------------------------------
# Helper: write a timestamped delimiter to act-result.txt
# ---------------------------------------------------------------------------
function Write-Delimiter {
    param([string]$Label)
    $line = "=" * 72
    $header = @"

$line
TEST CASE: $Label
RUN AT   : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$line
"@
    Add-Content -Path $ActResultFile -Value $header
}

# ---------------------------------------------------------------------------
# Helper: run act push in a temp repo, capture output, return it
# ---------------------------------------------------------------------------
function Invoke-ActRun {
    param(
        [string]$TempDir,
        [string]$FixtureSource,  # full path to fixture file
        [string]$CaseName
    )

    Write-Host "`n>>> Setting up temp repo for: $CaseName"

    # Create temp dir and initialise a git repo
    $null = New-Item -ItemType Directory -Path $TempDir -Force
    Push-Location $TempDir

    try {
        & git init --quiet
        & git config user.email "test@example.com"
        & git config user.name "Test"

        # Copy .actrc (tells act to use act-ubuntu-pwsh:latest for ubuntu-latest)
        $actrcSrc = Join-Path $WorkspaceDir ".actrc"
        if (Test-Path $actrcSrc) { Copy-Item $actrcSrc ".actrc" }

        # Copy project PowerShell files
        foreach ($file in $ProjectFiles) {
            $src = Join-Path $WorkspaceDir $file
            if (Test-Path $src) {
                Copy-Item $src (Split-Path $file -Leaf)
            }
        }

        # Copy fixtures directory (all fixture files; workflow uses them)
        $fixturesDst = "fixtures"
        $null = New-Item -ItemType Directory -Path $fixturesDst -Force
        $fixturesDir = Join-Path $WorkspaceDir $FixtureSrcDir
        if (Test-Path $fixturesDir) {
            Get-ChildItem $fixturesDir -Filter "*.json" | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $fixturesDst $_.Name)
            }
        }

        # Copy the workflow file
        $null = New-Item -ItemType Directory -Path ".github/workflows" -Force
        $wfSrc = Join-Path $WorkspaceDir $WorkflowSrc
        Copy-Item $wfSrc ".github/workflows/environment-matrix-generator.yml"

        # Overwrite fixture.json with the case-specific fixture for the CLI step
        Copy-Item $FixtureSource "fixture.json"

        # Stage and commit everything so act sees a real push event
        & git add -A
        & git commit --quiet -m "test: $CaseName"

        # Run act — capture combined stdout+stderr
        Write-Host ">>> Running act push --rm for: $CaseName"
        $actOutput = & act push --rm 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        return @{
            Output   = $actOutput
            ExitCode = $exitCode
        }
    }
    finally {
        Pop-Location
        # Clean up temp dir
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Helper: assert a condition or throw with a clear message
# ---------------------------------------------------------------------------
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
    Write-Host "  [PASS] $Message"
}

# ---------------------------------------------------------------------------
# Define the 3 test cases
# ---------------------------------------------------------------------------
$testCases = @(
    @{
        Name        = "basic-matrix"
        Fixture     = Join-Path $WorkspaceDir "fixtures/basic-matrix.json"
        Assertions  = {
            param($output)
            Assert-True ($output -match "PESTER_PASSED: 31") `
                "Pester reports exactly 31 tests passed"
            Assert-True ($output -match "Job succeeded") `
                "All jobs report success"
            Assert-True ($output -match "VALIDATE_OS_COUNT: 2") `
                "OS count is 2 (ubuntu-latest, windows-latest)"
            Assert-True ($output -match "VALIDATE_PY_COUNT: 3") `
                "Python version count is 3"
            Assert-True ($output -match "VALIDATE_HAS_UBUNTU: True") `
                "Matrix contains ubuntu-latest"
            Assert-True ($output -match "VALIDATE_HAS_311: True") `
                "Matrix contains python 3.11"
        }
    },
    @{
        Name       = "advanced-matrix"
        Fixture    = Join-Path $WorkspaceDir "fixtures/advanced-matrix.json"
        Assertions = {
            param($output)
            Assert-True ($output -match "PESTER_PASSED: 31") `
                "Pester reports exactly 31 tests passed"
            Assert-True ($output -match "Job succeeded") `
                "All jobs report success"
            Assert-True ($output -match "VALIDATE_MAX_PARALLEL: 4") `
                "max-parallel is 4"
            Assert-True ($output -match "VALIDATE_FAIL_FAST: False") `
                "fail-fast is false"
            Assert-True ($output -match "VALIDATE_INCLUDE_COUNT: 1") `
                "include has 1 entry"
            Assert-True ($output -match "VALIDATE_EXCLUDE_COUNT: 1") `
                "exclude has 1 entry"
        }
    },
    @{
        Name       = "feature-flags"
        Fixture    = Join-Path $WorkspaceDir "fixtures/feature-flags.json"
        Assertions = {
            param($output)
            Assert-True ($output -match "PESTER_PASSED: 31") `
                "Pester reports exactly 31 tests passed"
            Assert-True ($output -match "Job succeeded") `
                "All jobs report success"
            Assert-True ($output -match "VALIDATE_FEATURES_COUNT: 2") `
                "features array has 2 entries"
            Assert-True ($output -match "VALIDATE_HAS_FEATURE_A: True") `
                "features contains feature-a"
            Assert-True ($output -match "VALIDATE_MAX_PARALLEL: 3") `
                "max-parallel is 3"
            Assert-True ($output -match "VALIDATE_FAIL_FAST: True") `
                "fail-fast is true"
        }
    }
)

# ---------------------------------------------------------------------------
# Run each test case
# ---------------------------------------------------------------------------
$allPassed = $true
$caseNum = 0

foreach ($tc in $testCases) {
    $caseNum++
    Write-Host "`n========================================`n  Test Case $caseNum/$($testCases.Count): $($tc.Name)`n========================================"

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$($tc.Name)-$(Get-Random)"

    try {
        $run = Invoke-ActRun -TempDir $tmpDir -FixtureSource $tc.Fixture -CaseName $tc.Name

        # Save to act-result.txt
        Write-Delimiter -Label $tc.Name
        Add-Content -Path $ActResultFile -Value "EXIT CODE: $($run.ExitCode)"
        Add-Content -Path $ActResultFile -Value ""
        Add-Content -Path $ActResultFile -Value $run.Output

        Write-Host "`n--- Assertions for $($tc.Name) ---"

        # 1. Assert act exited 0
        Assert-True ($run.ExitCode -eq 0) `
            "act exited with code 0 (got $($run.ExitCode))"

        # 2. Assert case-specific expected values
        & $tc.Assertions $run.Output
    }
    catch {
        $errorMsg = "FAILED: $($tc.Name) — $_"
        Write-Host $errorMsg
        Add-Content -Path $ActResultFile -Value "`nERROR: $_"
        $allPassed = $false
    }
}

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
$summary = @"

========================================
  FINAL SUMMARY
  Passed all $($testCases.Count) test cases: $allPassed
========================================
"@
Write-Host $summary
Add-Content -Path $ActResultFile -Value $summary

Write-Host "`nact-result.txt written to: $ActResultFile"

if (-not $allPassed) {
    Write-Error "One or more test cases failed. See act-result.txt for details."
    exit 1
}

Write-Host "All test cases PASSED."
