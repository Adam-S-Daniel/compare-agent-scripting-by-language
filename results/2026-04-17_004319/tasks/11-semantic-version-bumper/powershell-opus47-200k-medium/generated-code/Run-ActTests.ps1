#!/usr/bin/env pwsh
# Test harness: runs the workflow via `act` for each test case by setting
# env vars through act --env, captures output, asserts on known-good values.
[CmdletBinding()]
param(
    [string]$ActResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cases = @(
    @{
        Name = 'feat-bumps-minor'
        Fixture = 'fixtures/feat-only-commits.txt'
        StartVersion = '1.1.0'
        ExpectedVersion = '1.2.0'
    },
    @{
        Name = 'fix-bumps-patch'
        Fixture = 'fixtures/fix-only-commits.txt'
        StartVersion = '1.1.0'
        ExpectedVersion = '1.1.1'
    },
    @{
        Name = 'breaking-bumps-major'
        Fixture = 'fixtures/breaking-commits.txt'
        StartVersion = '1.1.0'
        ExpectedVersion = '2.0.0'
    }
)

# Ensure file exists & is empty at start.
Set-Content -LiteralPath $ActResultFile -Value '' -NoNewline

$failures = @()
foreach ($case in $cases) {
    $header = "===== BEGIN CASE: $($case.Name) | fixture=$($case.Fixture) | start=$($case.StartVersion) | expected=$($case.ExpectedVersion) ====="
    Write-Host $header
    Add-Content -LiteralPath $ActResultFile -Value $header

    $actArgs = @(
        'push', '--rm', '--pull=false',
        '--env', "COMMITS_FIXTURE=$($case.Fixture)",
        '--env', "STARTING_VERSION=$($case.StartVersion)"
    )

    $output = & act @actArgs 2>&1 | Out-String
    $exit = $LASTEXITCODE

    Add-Content -LiteralPath $ActResultFile -Value $output
    $footer = "===== END CASE: $($case.Name) | exit=$exit ====="
    Add-Content -LiteralPath $ActResultFile -Value $footer

    $ok = $true

    if ($exit -ne 0) {
        $failures += "[$($case.Name)] act exit code = $exit"
        $ok = $false
    }

    if ($output -notmatch [regex]::Escape("RESULT_VERSION=$($case.ExpectedVersion)")) {
        $failures += "[$($case.Name)] expected RESULT_VERSION=$($case.ExpectedVersion) not found in act output"
        $ok = $false
    }

    # Assert every job succeeded.
    $jobSuccessCount = ([regex]::Matches($output, 'Job succeeded')).Count
    if ($jobSuccessCount -lt 2) {
        $failures += "[$($case.Name)] expected >=2 'Job succeeded' lines, got $jobSuccessCount"
        $ok = $false
    }

    if ($ok) { Write-Host "PASS: $($case.Name)" -ForegroundColor Green }
    else     { Write-Host "FAIL: $($case.Name)" -ForegroundColor Red }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host ""
Write-Host "All $($cases.Count) act cases passed." -ForegroundColor Green
