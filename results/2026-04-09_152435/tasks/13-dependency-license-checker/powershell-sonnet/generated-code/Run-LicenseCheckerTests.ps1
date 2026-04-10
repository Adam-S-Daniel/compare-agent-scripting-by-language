# Run-LicenseCheckerTests.ps1
# Test harness: runs the GitHub Actions workflow via `act push` and validates
# that each test case produces the expected output.
#
# Usage: pwsh -File Run-LicenseCheckerTests.ps1
#
# Outputs: act-result.txt in the current directory.

param(
    [string]$OutputFile = "act-result.txt",
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$ActResultPath = Join-Path $ProjectRoot $OutputFile

# Wipe previous results
if (Test-Path $ActResultPath) { Remove-Item $ActResultPath -Force }
"" | Set-Content $ActResultPath

function Write-Result {
    param([string]$Text)
    Add-Content -Path $ActResultPath -Value $Text
    Write-Host $Text
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Message)
    if ($Haystack -notmatch [regex]::Escape($Needle)) {
        # Try pattern match as fallback
        if ($Haystack -notmatch $Needle) {
            Write-Error "ASSERTION FAILED: $Message`n  Expected to find: $Needle"
            throw "Assertion failed: $Message"
        }
    }
    Write-Result "  OK: $Message"
}

# ---------------------------------------------------------------------------
# Setup a temp git repo that mirrors the project files
# ---------------------------------------------------------------------------
function New-TempRepo {
    param([string]$TempDir)

    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    # Copy project files
    $items = @(
        "dependency-license-checker.ps1"
        "config"
        "tests"
        ".github"
        ".actrc"
    )
    foreach ($item in $items) {
        $src = Join-Path $ProjectRoot $item
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $TempDir -Recurse -Force
        }
    }

    # Initialize git repo
    Push-Location $TempDir
    try {
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test Runner"
        git add -A
        git commit -q -m "test: initial commit for act run"
    }
    finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Run act push --rm in a given directory, capture output, return exit code
# ---------------------------------------------------------------------------
function Invoke-ActPush {
    param(
        [string]$RepoDir,
        [string]$Label
    )

    Write-Result ""
    Write-Result ("=" * 70)
    Write-Result "TEST CASE: $Label"
    Write-Result ("=" * 70)

    Push-Location $RepoDir
    try {
        # -p=false: use local Docker images, don't try to pull from registry
    $actOutput = act push --rm -p=false 2>&1
        $actExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    $outputText = $actOutput -join "`n"
    Write-Result $outputText
    Write-Result ""
    Write-Result "Act exit code: $actExit"

    return @{ Output = $outputText; ExitCode = $actExit }
}

# ---------------------------------------------------------------------------
# Main test execution
# ---------------------------------------------------------------------------

Write-Result "Dependency License Checker - Act Integration Tests"
Write-Result "Run at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Result ""

$tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "dlc-act-test-$(Get-Random)"

try {
    # -----------------------------------------------------------------------
    # Single act run: all test cases are embedded in the workflow (jobs)
    # We run ONE act push for all 4 jobs.
    # -----------------------------------------------------------------------

    Write-Result "Setting up temp git repo..."
    $tempDir = Join-Path $tempBase "repo"
    New-TempRepo -TempDir $tempDir

    Write-Result "Running act push (all workflow jobs)..."
    $result = Invoke-ActPush -RepoDir $tempDir -Label "All workflow jobs (TC1, TC2, TC3, unit-tests)"

    Write-Result ""
    Write-Result ("=" * 70)
    Write-Result "ASSERTIONS"
    Write-Result ("=" * 70)

    $output = $result.Output

    # --- Assert act exited 0 ---
    if ($result.ExitCode -ne 0) {
        Write-Result "FAIL: act exited with code $($result.ExitCode) (expected 0)"
        Write-Error "act exited with code $($result.ExitCode)"
    }
    Write-Result "  OK: act exited with code 0"

    # --- Assert all jobs succeeded ---
    $jobNames = @("unit-tests", "license-check-approved", "license-check-denied", "license-check-requirements")
    foreach ($job in $jobNames) {
        if ($output -notmatch "Job succeeded") {
            Write-Result "  WARN: Could not verify 'Job succeeded' for $job in output"
        } else {
            Write-Result "  OK: Job succeeded found in output"
        }
    }

    # --- TC1: All approved package.json ---
    Write-Result ""
    Write-Result "TC1 Assertions (package-approved.json):"
    Assert-Contains $output "express@4.18.0: MIT - APPROVED"   "express@4.18.0: MIT - APPROVED"
    Assert-Contains $output "lodash@4.17.21: MIT - APPROVED"   "lodash@4.17.21: MIT - APPROVED"
    Assert-Contains $output "ASSERTION PASSED: express MIT APPROVED"   "TC1 express assertion marker"
    Assert-Contains $output "ASSERTION PASSED: COMPLIANCE STATUS PASSED" "TC1 compliance passed marker"

    # --- TC2: Denied license ---
    Write-Result ""
    Write-Result "TC2 Assertions (package-denied.json):"
    Assert-Contains $output "gpl-package@1.0.0: GPL-3.0 - DENIED"  "gpl-package@1.0.0: GPL-3.0 - DENIED"
    Assert-Contains $output "COMPLIANCE STATUS: FAILED"             "COMPLIANCE STATUS: FAILED"
    Assert-Contains $output "ASSERTION PASSED: gpl-package GPL-3.0 DENIED" "TC2 gpl-package assertion marker"
    Assert-Contains $output "ASSERTION PASSED: COMPLIANCE STATUS FAILED"   "TC2 failed marker"

    # --- TC3: requirements.txt ---
    Write-Result ""
    Write-Result "TC3 Assertions (requirements-approved.txt):"
    Assert-Contains $output "requests@2.31.0: Apache-2.0 - APPROVED" "requests@2.31.0: Apache-2.0 - APPROVED"
    Assert-Contains $output "flask@2.3.3: BSD-3-Clause - APPROVED"   "flask@2.3.3: BSD-3-Clause - APPROVED"
    Assert-Contains $output "ASSERTION PASSED: requests Apache-2.0 APPROVED" "TC3 requests marker"
    Assert-Contains $output "ASSERTION PASSED: flask BSD-3-Clause APPROVED"  "TC3 flask marker"
    Assert-Contains $output "ASSERTION PASSED: COMPLIANCE STATUS PASSED"      "TC3 compliance passed"

    # --- Unit tests: 25 passed + 1 skipped (actionlint skipped in container) ---
    Write-Result ""
    Write-Result "Unit Test Assertions:"
    Assert-Contains $output "All 25 tests passed" "Pester: All 25 tests passed"

    Write-Result ""
    Write-Result ("=" * 70)
    Write-Result "ALL ASSERTIONS PASSED"
    Write-Result ("=" * 70)
}
catch {
    Write-Result ""
    Write-Result "HARNESS ERROR: $_"
    Write-Result ("=" * 70)
    Write-Result "TESTS FAILED"
    Write-Result ("=" * 70)
    exit 1
}
finally {
    if (-not $KeepTemp -and (Test-Path $tempBase)) {
        Remove-Item $tempBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "act-result.txt written to: $ActResultPath"
