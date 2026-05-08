#!/usr/bin/env pwsh
# Test harness: validates workflow structure, runs act, asserts on output
$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$actResultFile = Join-Path $projectDir "act-result.txt"
$failures = [System.Collections.Generic.List[string]]::new()

if (Test-Path $actResultFile) { Remove-Item $actResultFile }

# --- Phase 1: Workflow structure checks (pre-act) ---
Write-Host "=== Phase 1: Workflow structure validation ==="

$workflowPath = Join-Path $projectDir ".github/workflows/pr-label-assigner.yml"
$yaml = Get-Content $workflowPath -Raw

if ($yaml -notmatch 'on:')              { $failures.Add("Workflow missing 'on:' trigger") }
if ($yaml -notmatch 'push')             { $failures.Add("Workflow missing push trigger") }
if ($yaml -notmatch 'jobs:')            { $failures.Add("Workflow missing 'jobs:'") }
if ($yaml -notmatch 'steps:')           { $failures.Add("Workflow missing 'steps:'") }
if ($yaml -notmatch 'actions/checkout') { $failures.Add("Workflow missing checkout action") }
if ($yaml -notmatch 'shell:\s*pwsh')    { $failures.Add("Workflow not using shell: pwsh") }
if ($yaml -notmatch 'Invoke-PRLabelAssigner\.ps1')       { $failures.Add("Workflow not referencing script") }
if ($yaml -notmatch 'Invoke-PRLabelAssigner\.Tests\.ps1') { $failures.Add("Workflow not referencing tests") }

if (-not (Test-Path (Join-Path $projectDir "Invoke-PRLabelAssigner.ps1")))       { $failures.Add("Script file missing") }
if (-not (Test-Path (Join-Path $projectDir "Invoke-PRLabelAssigner.Tests.ps1"))) { $failures.Add("Test file missing") }
if (-not (Test-Path (Join-Path $projectDir "label-config.json")))               { $failures.Add("Config file missing") }

Write-Host "  Structure checks: OK"

# Actionlint validation
Write-Host "  Running actionlint..."
$lintOutput = & actionlint $workflowPath 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    $failures.Add("actionlint failed: $lintOutput")
    Write-Host "  actionlint: FAILED"
} else {
    Write-Host "  actionlint: PASSED"
}

# --- Phase 2: Run act ---
Write-Host "`n=== Phase 2: Running act push ==="

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pr-label-assigner-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Copy-Item "$projectDir/Invoke-PRLabelAssigner.ps1" $tempDir
    Copy-Item "$projectDir/Invoke-PRLabelAssigner.Tests.ps1" $tempDir
    Copy-Item "$projectDir/label-config.json" $tempDir

    $ghDir = Join-Path $tempDir ".github/workflows"
    New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
    Copy-Item "$projectDir/.github/workflows/pr-label-assigner.yml" $ghDir

    if (Test-Path "$projectDir/.actrc") {
        Copy-Item "$projectDir/.actrc" $tempDir
    }

    Push-Location $tempDir
    & git init --quiet
    & git add -A
    & git commit -m "test" --quiet

    Write-Host "  Running: act push --rm --pull=false"
    $actOutput = & act push --rm --pull=false 2>&1 | Out-String
    $actExitCode = $LASTEXITCODE
    Pop-Location

    # Save full output
    @"
=== ACT RUN: All test cases ===
Exit Code: $actExitCode

$actOutput

=== END ACT RUN ===
"@ | Set-Content $actResultFile

    Write-Host "  Act exit code: $actExitCode"

    # --- Phase 3: Assert on act output ---
    Write-Host "`n=== Phase 3: Output assertions ==="

    if ($actExitCode -ne 0) {
        $failures.Add("Act exited with code $actExitCode (expected 0)")
    }

    if ($actOutput -notmatch 'Job succeeded') {
        $failures.Add("Expected 'Job succeeded' in output")
    } else {
        Write-Host "  Job succeeded: FOUND"
    }

    # Pester results
    if ($actOutput -match 'PESTER_RESULT:\s*(\d+)\s*passed,\s*(\d+)\s*failed') {
        $passed = [int]$Matches[1]
        $failed = [int]$Matches[2]
        if ($failed -gt 0) { $failures.Add("Pester: $failed test(s) failed") }
        if ($passed -eq 0) { $failures.Add("Pester: no tests passed") }
        Write-Host "  Pester: $passed passed, $failed failed"
    } else {
        $failures.Add("Could not find PESTER_RESULT in act output")
    }

    # Demo output exact-value assertions
    $expected = @{
        DEMO_BASIC    = "source,documentation"
        DEMO_MULTI    = "api,source"
        DEMO_PRIORITY = "tests,api,source"
        DEMO_CONFIG   = "tests,documentation,markdown"
    }

    foreach ($key in $expected.Keys) {
        if ($actOutput -match "$key`:\s*(.+)") {
            $actual = $Matches[1].Trim()
            if ($actual -ne $expected[$key]) {
                $failures.Add("$key`: expected '$($expected[$key])' but got '$actual'")
            } else {
                Write-Host "  $key`: PASS ($actual)"
            }
        } else {
            $failures.Add("Could not find $key in act output")
        }
    }
} finally {
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
}

# --- Summary ---
Write-Host "`n=== Summary ==="
if ($failures.Count -gt 0) {
    Write-Host "FAILURES ($($failures.Count)):"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}

Write-Host "All assertions passed!"
