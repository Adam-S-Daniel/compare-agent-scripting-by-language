# Run-ActTests.ps1
# Test harness: copies project files into a temp git repo and runs all tests through act.
# Saves full act output to act-result.txt. Asserts exact expected values.

$ErrorActionPreference = 'Stop'
$scriptDir  = $PSScriptRoot
$resultFile = Join-Path $scriptDir "act-result.txt"

# ===== Helper: append a delimited block to act-result.txt =====
function Write-ResultBlock {
    param([string]$Label, [string]$Content, [int]$ExitCode)
    $sep = "=" * 70
    Add-Content -Path $resultFile -Value ""
    Add-Content -Path $resultFile -Value $sep
    Add-Content -Path $resultFile -Value "SECTION: $Label"
    Add-Content -Path $resultFile -Value $sep
    Add-Content -Path $resultFile -Value $Content
    Add-Content -Path $resultFile -Value ""
    Add-Content -Path $resultFile -Value "EXIT_CODE: $ExitCode"
    Add-Content -Path $resultFile -Value $sep
}

# ===== Validate actionlint on host (pre-installed in benchmark env) =====
Write-Host "--- Validating workflow with actionlint ---"
$wfFile    = Join-Path $scriptDir ".github" "workflows" "environment-matrix-generator.yml"
$alOutput  = actionlint $wfFile 2>&1
$alExit    = $LASTEXITCODE

"" | Out-File -FilePath $resultFile -Encoding utf8   # initialise/clear file
Write-ResultBlock -Label "actionlint validation" -Content ($alOutput -join "`n") -ExitCode $alExit

if ($alExit -ne 0) {
    Write-Error "actionlint FAILED (exit $alExit):`n$($alOutput -join "`n")"
    exit 1
}
Write-Host "actionlint passed."

# ===== Set up temp git repo with all project files =====
Write-Host "--- Setting up temp git repo ---"
$tmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    # Files to copy into the temp repo
    $items = @(
        "New-BuildMatrix.ps1",
        "New-BuildMatrix.Tests.ps1",
        "Invoke-MatrixGenerator.ps1",
        "test-fixtures",
        ".github",
        ".actrc"
    )

    foreach ($item in $items) {
        $src = Join-Path $scriptDir $item
        if (Test-Path $src -PathType Container) {
            Copy-Item -Recurse $src (Join-Path $tmpDir $item)
        } elseif (Test-Path $src) {
            Copy-Item $src (Join-Path $tmpDir $item)
        }
    }

    # Ensure .actrc has pull=false so act uses local image instead of pulling from registry
    $actrcPath = Join-Path $tmpDir ".actrc"
    "-P ubuntu-latest=act-ubuntu-pwsh:latest`n--pull=false" | Out-File -FilePath $actrcPath -Encoding ascii -NoNewline

    # Initialise git repo required by act
    Push-Location $tmpDir
    git init -q
    git config user.email "test@test.com"
    git config user.name  "TestRunner"
    git add -A
    git commit -q -m "test: run environment matrix generator"

    # ===== Run act =====
    Write-Host "--- Running act push --rm ---"
    $actOutput = act push --rm --pull=false 2>&1
    $actExit   = $LASTEXITCODE

    Write-ResultBlock -Label "act push (all test cases)" -Content ($actOutput -join "`n") -ExitCode $actExit

    $combined = $actOutput -join "`n"

    Write-Host "--- Asserting expected values ---"
    $failed = $false

    # --- Exit code ---
    if ($actExit -ne 0) {
        Write-Host "FAIL: act exited with code $actExit (expected 0)"
        $failed = $true
    } else {
        Write-Host "PASS: act exit code 0"
    }

    # --- Job succeeded ---
    if ($combined -match 'Job succeeded') {
        Write-Host "PASS: 'Job succeeded' found in output"
    } else {
        Write-Host "FAIL: 'Job succeeded' NOT found in output"
        $failed = $true
    }

    # --- Pester results ---
    if ($combined -match 'PESTER_PASSED=(\d+)') {
        $passed = $Matches[1]
        Write-Host "PASS: Pester tests passed count = $passed"
    } else {
        Write-Host "FAIL: PESTER_PASSED marker not found"
        $failed = $true
    }
    if ($combined -match 'PESTER_FAILED=0') {
        Write-Host "PASS: PESTER_FAILED=0"
    } else {
        Write-Host "FAIL: PESTER_FAILED=0 NOT found (some Pester tests failed)"
        $failed = $true
    }

    # --- Test Case 1: basic matrix (os x python-version, 4 combos) ---
    if ($combined -match 'MATRIX_TEST1_START') {
        Write-Host "PASS: MATRIX_TEST1_START marker found"
    } else {
        Write-Host "FAIL: MATRIX_TEST1_START not found"
        $failed = $true
    }

    # matrix-size for test1: 2 OS × 2 python-version = 4
    if ($combined -match '"matrix-size":\s*4') {
        Write-Host "PASS: matrix-size 4 found (test1 os x python-version)"
    } else {
        Write-Host "FAIL: expected matrix-size 4 in test1 output"
        $failed = $true
    }

    if ($combined -match '"max-parallel":\s*4') {
        Write-Host "PASS: max-parallel 4 found (test1)"
    } else {
        Write-Host "FAIL: expected max-parallel 4 in test1 output"
        $failed = $true
    }

    if ($combined -match '"fail-fast":\s*false') {
        Write-Host "PASS: fail-fast false found (test1)"
    } else {
        Write-Host "FAIL: expected fail-fast false in test1 output"
        $failed = $true
    }

    if ($combined -match 'ubuntu-latest') {
        Write-Host "PASS: ubuntu-latest found in output"
    } else {
        Write-Host "FAIL: ubuntu-latest not found in output"
        $failed = $true
    }

    if ($combined -match '3\.10') {
        Write-Host "PASS: python-version 3.10 found in output"
    } else {
        Write-Host "FAIL: python-version 3.10 not found in test1 output"
        $failed = $true
    }

    # --- Test Case 2: include/exclude, max-parallel=2, fail-fast=true ---
    if ($combined -match 'MATRIX_TEST2_START') {
        Write-Host "PASS: MATRIX_TEST2_START marker found"
    } else {
        Write-Host "FAIL: MATRIX_TEST2_START not found"
        $failed = $true
    }

    if ($combined -match '"max-parallel":\s*2') {
        Write-Host "PASS: max-parallel 2 found (test2)"
    } else {
        Write-Host "FAIL: expected max-parallel 2 in test2 output"
        $failed = $true
    }

    if ($combined -match '"fail-fast":\s*true') {
        Write-Host "PASS: fail-fast true found (test2)"
    } else {
        Write-Host "FAIL: expected fail-fast true in test2 output"
        $failed = $true
    }

    if ($combined -match 'macos-latest') {
        Write-Host "PASS: macos-latest (include) found in test2 output"
    } else {
        Write-Host "FAIL: macos-latest not found in test2 output"
        $failed = $true
    }

    if ($combined -match 'coverage') {
        Write-Host "PASS: coverage (include extra field) found in test2 output"
    } else {
        Write-Host "FAIL: coverage not found in test2 output"
        $failed = $true
    }

    if ($failed) {
        Write-Host ""
        Write-Host "=== SOME ASSERTIONS FAILED. See act-result.txt for full output. ==="
        Pop-Location
        exit 1
    } else {
        Write-Host ""
        Write-Host "=== All assertions passed! ==="
    }

} finally {
    if ((Get-Location).Path -eq $tmpDir) { Pop-Location }
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

Write-Host "Results saved to: $resultFile"
