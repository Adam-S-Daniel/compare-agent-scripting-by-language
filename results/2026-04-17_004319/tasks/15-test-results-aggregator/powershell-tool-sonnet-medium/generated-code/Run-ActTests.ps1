# Test harness: runs the GitHub Actions workflow via act and validates output.
# All testing goes through the act pipeline — this script does NOT call the
# aggregator script directly.
#
# Expected exact values from the 4 fixture files:
#   TotalPassed   = 23   (6+6+5+6)
#   TotalFailed   = 5    (1+2+1+1)
#   TotalSkipped  = 2    (1+0+1+0)
#   TotalDuration = 40.1 (12.5+10.2+8.3+9.1)
#   FlakyCount    = 4    (TestAPICall, TestDivide, TestLogout, TestSubtract)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ResultFile = Join-Path $PSScriptRoot 'act-result.txt'
$Passed     = 0
$Failed     = 0

function Write-Pass { param([string]$Msg) Write-Host "  PASS: $Msg" -ForegroundColor Green; $script:Passed++ }
function Write-Fail { param([string]$Msg) Write-Host "  FAIL: $Msg" -ForegroundColor Red;   $script:Failed++ }

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -match [regex]::Escape($Pattern)) {
        Write-Pass $Description
    } else {
        # Try as-is (Pattern may already be a regex)
        if ($Text -match $Pattern) {
            Write-Pass $Description
        } else {
            Write-Fail "$Description (pattern: '$Pattern' not found)"
        }
    }
}

function Assert-Regex {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -match $Pattern) {
        Write-Pass $Description
    } else {
        Write-Fail "$Description (regex '$Pattern' not found)"
    }
}

# ─── Test Group 1: Static checks (actionlint, file paths) ────────────────────

Write-Host "`n=== Static Checks ===" -ForegroundColor Cyan

$wfPath = Join-Path $PSScriptRoot '.github/workflows/test-results-aggregator.yml'

if (Test-Path $wfPath) {
    Write-Pass "Workflow file exists at .github/workflows/test-results-aggregator.yml"
} else {
    Write-Fail "Workflow file missing at $wfPath"
}

if (Test-Path (Join-Path $PSScriptRoot 'src/Invoke-TestAggregator.ps1')) {
    Write-Pass "Source script exists at src/Invoke-TestAggregator.ps1"
} else {
    Write-Fail "Source script missing"
}

# Verify workflow YAML structure
$wfContent = Get-Content $wfPath -Raw
Assert-Regex $wfContent 'push:'             "Workflow has push trigger"
Assert-Regex $wfContent 'pull_request:'     "Workflow has pull_request trigger"
Assert-Regex $wfContent 'workflow_dispatch:' "Workflow has workflow_dispatch trigger"
Assert-Regex $wfContent 'shell:\s*pwsh'     "Workflow uses shell: pwsh"
Assert-Regex $wfContent 'Invoke-TestAggregator\.ps1' "Workflow references the aggregator script"
Assert-Regex $wfContent 'actions/checkout@v4' "Workflow uses actions/checkout@v4"

# Run actionlint and assert exit 0
Write-Host "`n  Running actionlint..." -ForegroundColor Gray
$alOutput = & actionlint $wfPath 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Pass "actionlint exits 0 (no errors)"
} else {
    Write-Fail "actionlint found errors: $alOutput"
}

# ─── Test Group 2: act run ────────────────────────────────────────────────────

Write-Host "`n=== Act Pipeline Run ===" -ForegroundColor Cyan
Write-Host "  Running: act push --rm  (this may take 30-90s)" -ForegroundColor Gray

# Delimiter so multiple test case outputs are clearly separated in the file.
$delimiter = "=" * 72
$header    = @"
$delimiter
TEST CASE: Full fixture run  ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$delimiter
"@

Add-Content -Path $ResultFile -Value $header

$actOutput = & act push --rm 2>&1
$actExitCode = $LASTEXITCODE
$actText   = $actOutput -join "`n"

Add-Content -Path $ResultFile -Value $actText
Add-Content -Path $ResultFile -Value ""

# Assert act exit code
if ($actExitCode -eq 0) {
    Write-Pass "act exited with code 0"
} else {
    Write-Fail "act exited with code $actExitCode"
    Write-Host "  Last 40 lines of act output:" -ForegroundColor Yellow
    $actOutput | Select-Object -Last 40 | ForEach-Object { Write-Host "    $_" }
}

# Assert "Job succeeded"
if ($actText -match 'Job succeeded') {
    Write-Pass "Job succeeded message present"
} else {
    Write-Fail "Job succeeded message NOT found in act output"
}

# Assert exact aggregated values in act output
Assert-Regex $actText 'AGGREGATED_PASSED=23'   "Exact: TotalPassed = 23"
Assert-Regex $actText 'AGGREGATED_FAILED=5'    "Exact: TotalFailed = 5"
Assert-Regex $actText 'AGGREGATED_SKIPPED=2'   "Exact: TotalSkipped = 2"
Assert-Regex $actText 'AGGREGATED_DURATION=40\.1' "Exact: TotalDuration = 40.1"
Assert-Regex $actText 'FLAKY_COUNT=4'          "Exact: FlakyCount = 4"
Assert-Regex $actText 'FLAKY_TESTS=TestAPICall,TestDivide,TestLogout,TestSubtract' "Exact: sorted flaky test names"

# Assert Pester results visible in output
Assert-Regex $actText 'Tests Passed: 46'       "Pester: 46 tests passed"
Assert-Regex $actText 'Failed: 0'              "Pester reports 0 failures"

# ─── Summary ──────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
$total = $Passed + $Failed
Write-Host "Results: $Passed/$total assertions passed" -ForegroundColor $(if ($Failed -eq 0) { 'Green' } else { 'Red' })
Write-Host "act-result.txt written to: $ResultFile" -ForegroundColor Gray

if ($Failed -gt 0) {
    Write-Host "HARNESS FAILED: $Failed assertion(s) did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "HARNESS PASSED: all assertions satisfied." -ForegroundColor Green
    exit 0
}
