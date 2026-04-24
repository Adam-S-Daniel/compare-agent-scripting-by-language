# Invoke-TestHarness.ps1
# Drives the GitHub Actions pipeline via `act`, captures output, and asserts on
# exact expected values from the test aggregator summary.
#
# Expected values (derived from fixtures):
#   Total Tests : 12
#   Passed      : 6
#   Failed      : 4
#   Skipped     : 2
#   Duration    : 6.00s
#   Flaky tests : TestB, TestD, TestE, TestF
#   Job result  : Job succeeded

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ResultFile = Join-Path $PSScriptRoot 'act-result.txt'

# ── Helper: assert a condition and print pass/fail ───────────────────────────
function Assert-That {
    param([string]$Description, [scriptblock]$Condition)
    if (& $Condition) {
        Write-Host "[PASS] $Description"
    } else {
        Write-Error "[FAIL] $Description"
        $script:FailCount++
    }
}

$script:FailCount = 0

# ── Test case 1: Full fixture run ─────────────────────────────────────────────
Write-Host ""
Write-Host "=== TEST CASE 1: Full fixture run (all 4 result files) ==="
Write-Host "Running: act push --rm"
Write-Host ""

$delimiter = "`n" + ("=" * 60) + "`nTEST CASE 1: act push --rm`n" + ("=" * 60) + "`n"
Add-Content -Path $ResultFile -Value $delimiter -ErrorAction SilentlyContinue

$actOutput = & act push --rm 2>&1
$actExitCode = $LASTEXITCODE

$actOutput | ForEach-Object { $_ } | Out-File -FilePath $ResultFile -Append -Encoding UTF8
$outputStr = $actOutput -join "`n"

# ── Assertions ────────────────────────────────────────────────────────────────
Assert-That "act exited with code 0" { $actExitCode -eq 0 }
Assert-That "Job succeeded" { $outputStr -match "Job succeeded" }
Assert-That "Total Tests = 12" { $outputStr -match "Total Tests \| 12" }
Assert-That "Passed = 6" { $outputStr -match "Passed \| 6" }
Assert-That "Failed = 4" { $outputStr -match "Failed \| 4" }
Assert-That "Skipped = 2" { $outputStr -match "Skipped \| 2" }
Assert-That "Duration = 6.00s" { $outputStr -match "Total Duration \| 6\.00s" }
Assert-That "Flaky: TestB detected" { $outputStr -match "TestB" }
Assert-That "Flaky: TestD detected" { $outputStr -match "TestD" }
Assert-That "Flaky: TestE detected" { $outputStr -match "TestE" }
Assert-That "Flaky: TestF detected" { $outputStr -match "TestF" }
Assert-That "Pester step completed" { $outputStr -match "Run Pester Tests" }
Assert-That "Aggregator step completed" { $outputStr -match "Run Test Aggregator" }

# ── Final summary ─────────────────────────────────────────────────────────────
Write-Host ""
if ($script:FailCount -eq 0) {
    Write-Host "All harness assertions passed."
} else {
    Write-Error "$($script:FailCount) harness assertion(s) failed."
    exit 1
}
