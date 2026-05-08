# Test harness: validates workflow structure, runs act, and asserts on exact expected output.
# All act output is appended to act-result.txt for the benchmark judge.

[CmdletBinding()]
param(
    [string]$OutputFile = "./act-result.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- Helpers ----------------------------------------------------------------

function Assert-Equal($label, $actual, $expected) {
    if ($actual -ne $expected) {
        Write-Error "FAIL [$label]: expected '$expected', got '$actual'"
    }
    else { Write-Host "PASS [$label]" -ForegroundColor Green }
}

function Assert-Contains($label, $text, $pattern) {
    if ($text -notmatch $pattern) {
        Write-Error "FAIL [$label]: output did not contain '$pattern'"
    }
    else { Write-Host "PASS [$label]: found '$pattern'" -ForegroundColor Green }
}

function Append-Section($path, $header, $body) {
    $divider = "=" * 70
    "$divider`n$header`n$divider`n$body`n" | Out-File -FilePath $path -Append -Encoding utf8
}

# ---- 1. Workflow structure tests --------------------------------------------

Write-Host "`n=== Workflow Structure Tests ===" -ForegroundColor Cyan

$wfPath = ".github/workflows/artifact-cleanup-script.yml"
if (-not (Test-Path $wfPath)) { Write-Error "Workflow file not found: $wfPath" }

$wfContent = Get-Content $wfPath -Raw

Assert-Contains "workflow has push trigger"              $wfContent "push"
Assert-Contains "workflow has pull_request trigger"      $wfContent "pull_request"
Assert-Contains "workflow has schedule trigger"          $wfContent "schedule"
Assert-Contains "workflow has workflow_dispatch trigger" $wfContent "workflow_dispatch"
Assert-Contains "workflow references checkout@v4"        $wfContent "actions/checkout@v4"
Assert-Contains "workflow uses shell: pwsh"              $wfContent "shell:\s*pwsh"
Assert-Contains "workflow runs pester tests"             $wfContent "Invoke-Pester"
Assert-Contains "workflow uses ArtifactCleanup.Tests"    $wfContent "ArtifactCleanup\.Tests"
Assert-Contains "workflow has dry-run step"              $wfContent "DryRun"
Assert-Contains "workflow has permissions block"         $wfContent "permissions"

# Verify referenced script files actually exist
$scriptFiles = @("ArtifactCleanup.ps1", "ArtifactCleanup.Tests.ps1")
foreach ($f in $scriptFiles) {
    if (-not (Test-Path $f)) { Write-Error "Referenced script missing: $f" }
    Write-Host "PASS [file exists: $f]" -ForegroundColor Green
}

# ---- 2. Actionlint validation -----------------------------------------------

Write-Host "`n=== Actionlint Validation ===" -ForegroundColor Cyan

$alOutput = & actionlint $wfPath 2>&1
$alExit   = $LASTEXITCODE
Append-Section $OutputFile "ACTIONLINT" ($alOutput -join "`n")

Assert-Equal "actionlint exit code" $alExit 0
Write-Host "PASS [actionlint]: clean" -ForegroundColor Green

# ---- 3. ACT run (single push event) -----------------------------------------

Write-Host "`n=== ACT Run ===" -ForegroundColor Cyan

$actArgs  = @("push", "--rm", "--job", "test")
Write-Host "Running: act $($actArgs -join ' ')"

$actOutput = & act @actArgs 2>&1
$actExit   = $LASTEXITCODE

$actText = $actOutput -join "`n"
Append-Section $OutputFile "ACT RUN (push / job:test)" $actText

# Assert exit code
Assert-Equal "act exit code" $actExit 0

# Assert expected output strings
Assert-Contains "act: job succeeded"      $actText "Job succeeded"
Assert-Contains "act: Pester passes"      $actText "All\s+\d+\s+tests passed|Tests Passed:"
Assert-Contains "act: checkout step ran"  $actText "Checkout"
Assert-Contains "act: pester step ran"    $actText "Run Pester tests|Invoke-Pester"

Write-Host "`nDone. Output appended to: $OutputFile" -ForegroundColor Cyan
