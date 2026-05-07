#!/usr/bin/env pwsh
# Test harness: runs all tests through act and asserts on exact expected values.

$ErrorActionPreference = 'Stop'
$workDir = $PSScriptRoot
$actResultFile = Join-Path $workDir 'act-result.txt'

'' | Set-Content -Path $actResultFile -NoNewline

$failures = [System.Collections.ArrayList]::new()

# === WORKFLOW STRUCTURE TESTS (local) ===

$workflowPath = Join-Path $workDir '.github' 'workflows' 'test-results-aggregator.yml'

if (-not (Test-Path $workflowPath)) {
    [void]$failures.Add('FAIL: Workflow file does not exist')
} else {
    $wfContent = Get-Content -Path $workflowPath -Raw

    if ($wfContent -notmatch 'push:')              { [void]$failures.Add('FAIL: Workflow missing push trigger') }
    if ($wfContent -notmatch 'pull_request:')       { [void]$failures.Add('FAIL: Workflow missing pull_request trigger') }
    if ($wfContent -notmatch 'workflow_dispatch:')   { [void]$failures.Add('FAIL: Workflow missing workflow_dispatch trigger') }
    if ($wfContent -notmatch 'jobs:')               { [void]$failures.Add('FAIL: Workflow missing jobs section') }
    if ($wfContent -notmatch 'actions/checkout@v4') { [void]$failures.Add('FAIL: Workflow missing actions/checkout@v4') }
    if ($wfContent -notmatch 'Aggregate-TestResults\.ps1') {
        [void]$failures.Add('FAIL: Workflow does not reference Aggregate-TestResults.ps1')
    }

    $scriptPath = Join-Path $workDir 'src' 'Aggregate-TestResults.ps1'
    if (-not (Test-Path $scriptPath)) { [void]$failures.Add('FAIL: Script file does not exist') }

    $testsDir = Join-Path $workDir 'tests'
    if (-not (Test-Path $testsDir -PathType Container)) { [void]$failures.Add('FAIL: Tests directory does not exist') }
}

# Actionlint check (local)
$alOutput = actionlint $workflowPath 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    [void]$failures.Add("FAIL: actionlint failed: $alOutput")
}

Write-Host "Workflow structure tests done: $($failures.Count) failure(s) so far"

# === ACT EXECUTION TEST ===

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "test-results-agg-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    foreach ($item in @('src', 'tests', 'fixtures', '.github', '.actrc')) {
        $source = Join-Path $workDir $item
        $dest = Join-Path $tempDir $item
        if (Test-Path $source -PathType Container) {
            Copy-Item -Path $source -Destination $dest -Recurse
        } elseif (Test-Path $source) {
            Copy-Item -Path $source -Destination $dest
        }
    }

    Push-Location $tempDir
    git init 2>&1 | Out-Null
    git config user.email 'test@test.com' 2>&1 | Out-Null
    git config user.name 'test' 2>&1 | Out-Null
    git add -A 2>&1 | Out-Null
    git commit -m 'test' 2>&1 | Out-Null

    Write-Host 'Running act push --rm ...'
    $actOutput = & act push --rm 2>&1 | Out-String
    $actExitCode = $LASTEXITCODE
    Pop-Location

    # Save output to act-result.txt
    @"
=== ACT RUN: test-and-aggregate ===
$actOutput
=== EXIT CODE: $actExitCode ===
"@ | Out-File -FilePath $actResultFile -Encoding utf8

    # Strip ANSI escape codes for reliable regex matching
    $esc = [char]27
    $actOutput = $actOutput -replace "$esc\[[0-9;]*m", ''

    # --- Assertions on act output ---

    if ($actExitCode -ne 0) {
        [void]$failures.Add("FAIL: act exited with code $actExitCode, expected 0")
    }

    if ($actOutput -notmatch 'Job succeeded') {
        [void]$failures.Add("FAIL: Output missing 'Job succeeded'")
    }

    # Pester results
    if ($actOutput -match 'Tests Passed:\s*(\d+),\s*Failed:\s*(\d+)') {
        $passedCount = [int]$Matches[1]
        $failedCount = [int]$Matches[2]
        if ($failedCount -ne 0) {
            [void]$failures.Add("FAIL: Pester reported $failedCount test failure(s)")
        }
        if ($passedCount -lt 30) {
            [void]$failures.Add("FAIL: Expected 30+ Pester tests, got $passedCount")
        }
    } else {
        [void]$failures.Add('FAIL: Could not find Pester test results in output')
    }

    # Exact expected markdown values from aggregation step
    if ($actOutput -notmatch '\|\s*Passed\s*\|\s*7\s*\|') {
        [void]$failures.Add("FAIL: Missing '| Passed | 7 |' in markdown output")
    }
    if ($actOutput -notmatch '\|\s*Failed\s*\|\s*7\s*\|') {
        [void]$failures.Add("FAIL: Missing '| Failed | 7 |' in markdown output")
    }
    if ($actOutput -notmatch '\|\s*Skipped\s*\|\s*2\s*\|') {
        [void]$failures.Add("FAIL: Missing '| Skipped | 2 |' in markdown output")
    }
    if ($actOutput -notmatch '\|\s*Duration\s*\|\s*32\.30s\s*\|') {
        [void]$failures.Add("FAIL: Missing '| Duration | 32.30s |' in markdown output")
    }
    if ($actOutput -notmatch '\|\s*Total\s*\|\s*16\s*\|') {
        [void]$failures.Add("FAIL: Missing '| Total | 16 |' in markdown output")
    }

    # Flaky test names in output
    if ($actOutput -notmatch 'test_database_connection') {
        [void]$failures.Add("FAIL: Missing 'test_database_connection' in output")
    }
    if ($actOutput -notmatch 'test_cache_invalidation') {
        [void]$failures.Add("FAIL: Missing 'test_cache_invalidation' in output")
    }
    if ($actOutput -notmatch 'test_data_sync') {
        [void]$failures.Add("FAIL: Missing 'test_data_sync' in output")
    }

    # Failed test details
    if ($actOutput -notmatch 'test_api_response') {
        [void]$failures.Add("FAIL: Missing 'test_api_response' in failed tests")
    }
    if ($actOutput -notmatch 'test_endpoint_auth') {
        [void]$failures.Add("FAIL: Missing 'test_endpoint_auth' in failed tests")
    }

} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# === REPORT ===

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) ASSERTION(S) FAILED:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  $f" -ForegroundColor Red
    }
    exit 1
}
