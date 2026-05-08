# Run-ActTests.ps1
# Act integration test harness.
# For each test case:
#   1. Creates a temp git repo containing all project files + the case's fixture
#   2. Runs: act push --rm
#   3. Appends output to act-result.txt (clearly delimited)
#   4. Asserts act exited 0 and that expected output strings appear
#
# Usage: pwsh -File ./Run-ActTests.ps1
# Produces: act-result.txt in the current working directory

$ErrorActionPreference = 'Stop'
$scriptRoot   = $PSScriptRoot
$actResultPath = Join-Path $scriptRoot "act-result.txt"

# Start fresh
if (Test-Path $actResultPath) { Remove-Item $actResultPath }

# Helper — append a labelled block to act-result.txt
function Append-ActResult {
    param([string]$Label, [string]$Content, [int]$ExitCode)
    $block  = @"

================================================================================
TEST CASE: $Label
EXIT CODE: $ExitCode
================================================================================
$Content
================================================================================
END: $Label
================================================================================

"@
    Add-Content -Path $actResultPath -Value $block -Encoding UTF8
}

# Helper — copy the project into a temp git repo and run act push --rm
function Invoke-ActTestCase {
    param(
        [string]$Label,
        [hashtable]$ExpectedStrings   # strings that MUST appear in act output
    )

    Write-Host "=== Running test case: $Label ===" -ForegroundColor Cyan

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-test-" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Copy project files into the temp dir (preserving directory structure)
        $filesToCopy = @(
            "DependencyLicenseChecker.ps1"
            "DependencyLicenseChecker.Tests.ps1"
            ".actrc"
        )
        foreach ($f in $filesToCopy) {
            $src = Join-Path $scriptRoot $f
            if (Test-Path $src) {
                Copy-Item $src (Join-Path $tempDir $f)
            }
        }

        # Copy fixtures/
        $fixturesSrc = Join-Path $scriptRoot "fixtures"
        $fixturesDst = Join-Path $tempDir "fixtures"
        Copy-Item -Recurse $fixturesSrc $fixturesDst

        # Copy .github/workflows/
        $workflowSrc = Join-Path $scriptRoot ".github"
        $workflowDst = Join-Path $tempDir ".github"
        Copy-Item -Recurse $workflowSrc $workflowDst

        # Initialise git repo
        $gitCmds = @(
            "git -C `"$tempDir`" init -q",
            "git -C `"$tempDir`" config user.email `"test@example.com`"",
            "git -C `"$tempDir`" config user.name `"Test`"",
            "git -C `"$tempDir`" add -A",
            "git -C `"$tempDir`" commit -q -m `"test: add project files`""
        )
        foreach ($cmd in $gitCmds) {
            Invoke-Expression $cmd | Out-Null
        }

        # Run act (--pull=false: use local image, don't attempt Docker Hub pull)
        Write-Host "  Running act push --rm --pull=false in $tempDir ..." -ForegroundColor Yellow
        Push-Location $tempDir
        try {
            $actOutput = & act push --rm --pull=false 2>&1 | Out-String
            $exitCode  = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        # Save result
        Append-ActResult -Label $Label -Content $actOutput -ExitCode $exitCode

        # Assertions
        $allPassed = $true

        if ($exitCode -ne 0) {
            Write-Host "  FAIL: act exited with code $exitCode" -ForegroundColor Red
            $allPassed = $false
        }

        foreach ($expected in $ExpectedStrings.GetEnumerator()) {
            if ($actOutput -match [regex]::Escape($expected.Key)) {
                Write-Host "  PASS: found '$($expected.Key)'" -ForegroundColor Green
            }
            else {
                Write-Host "  FAIL: expected '$($expected.Key)' — $($expected.Value)" -ForegroundColor Red
                $allPassed = $false
            }
        }

        # Check for "Job succeeded"
        if ($actOutput -match "Job succeeded") {
            Write-Host "  PASS: 'Job succeeded' found" -ForegroundColor Green
        }
        else {
            Write-Host "  FAIL: 'Job succeeded' not found in output" -ForegroundColor Red
            $allPassed = $false
        }

        return $allPassed
    }
    finally {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Test Case 1: Full workflow — Pester tests pass + license reports produced
# ============================================================
$tc1Passed = Invoke-ActTestCase `
    -Label "Full workflow: Pester tests + license compliance reports" `
    -ExpectedStrings @{
        # Pester output: 48 pass, 1 skipped (actionlint not in container)
        "Tests Passed: 48"   = "48 unit tests should pass (actionlint test is skipped in container)"
        # Report for package-mixed.json: 2 approved, 1 denied, 1 unknown
        "APPROVED (2):"      = "package-mixed.json has 2 approved deps"
        "DENIED (1):"        = "package-mixed.json has 1 denied dep"
        "UNKNOWN (1):"       = "package-mixed.json has 1 unknown dep"
        "bad-lib"            = "bad-lib should appear in denied section"
        "GPL-3.0"            = "GPL-3.0 license should be reported"
        "Status: FAIL"       = "overall status should be FAIL (denied deps exist)"
        # Report for requirements-basic.txt: 3 approved
        "APPROVED (3):"      = "requirements-basic.txt has 3 approved deps"
        "numpy"              = "numpy should appear in approved section"
    }

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "=== Act Test Results ===" -ForegroundColor Cyan
if ($tc1Passed) {
    Write-Host "  Test Case 1: PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "ALL ACT TESTS PASSED" -ForegroundColor Green
    Write-Host "Results saved to: $actResultPath"
    exit 0
}
else {
    Write-Host "  Test Case 1: FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "ACT TESTS FAILED — see $actResultPath for full output" -ForegroundColor Red
    exit 1
}
