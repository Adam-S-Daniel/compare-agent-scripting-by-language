#!/usr/bin/env pwsh
# Test harness: drives every test case through the GitHub Actions workflow via `act`.
# - Each case creates a fresh temp git repo containing the project files and a
#   tailored subset of fixture files, then runs `act push --rm`.
# - All act output is appended to act-result.txt for the run as a required artifact.
# - Exact expected values are asserted from the AGGREGATE_RESULT:: line emitted
#   by Invoke-Aggregator.ps1.
# - Also includes workflow-structure tests (YAML structure + actionlint).

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$ProjectRoot = $PSScriptRoot
$ResultFile  = Join-Path $ProjectRoot 'act-result.txt'
if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }

$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "  PASS: $Message" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: $Message" -ForegroundColor Red
        $script:failures.Add($Message)
    }
}

# ----------------------------------------------------------------------------
# Workflow structure tests (no `act` needed)
# ----------------------------------------------------------------------------
Write-Host "`n=== Workflow structure tests ===" -ForegroundColor Cyan

$wfPath = Join-Path $ProjectRoot '.github/workflows/test-results-aggregator.yml'
Assert-True (Test-Path $wfPath) "workflow file exists at $wfPath"

# Run actionlint and assert exit code 0.
$alOutput = & actionlint $wfPath 2>&1
$alExit = $LASTEXITCODE
Assert-True ($alExit -eq 0) "actionlint exits 0 (got $alExit). Output: $alOutput"

# Parse YAML structure with PowerShell-Yaml-free approach: load via pwsh ConvertFrom-Yaml
# is not built in, so we do simple regex/string checks for required structure.
$wfText = Get-Content -LiteralPath $wfPath -Raw
Assert-True ($wfText -match 'on:\s*\n[\s\S]*push:')           "trigger 'push' present"
Assert-True ($wfText -match 'pull_request:')                  "trigger 'pull_request' present"
Assert-True ($wfText -match 'workflow_dispatch:')             "trigger 'workflow_dispatch' present"
Assert-True ($wfText -match 'schedule:')                      "trigger 'schedule' present"
Assert-True ($wfText -match 'jobs:[\s\S]*pester-tests:')      "job 'pester-tests' defined"
Assert-True ($wfText -match 'jobs:[\s\S]*aggregate:')         "job 'aggregate' defined"
Assert-True ($wfText -match 'needs:\s*pester-tests')          "aggregate depends on pester-tests"
Assert-True ($wfText -match 'actions/checkout@v4')            "uses actions/checkout@v4"
Assert-True ($wfText -match 'shell:\s*pwsh')                  "uses shell: pwsh"
Assert-True ($wfText -match 'Invoke-Aggregator\.ps1')         "references Invoke-Aggregator.ps1"
Assert-True ($wfText -match 'permissions:')                   "permissions block present"

# Verify referenced script files exist.
Assert-True (Test-Path (Join-Path $ProjectRoot 'Invoke-Aggregator.ps1'))         "Invoke-Aggregator.ps1 exists"
Assert-True (Test-Path (Join-Path $ProjectRoot 'TestResultsAggregator.psm1'))    "module exists"
Assert-True (Test-Path (Join-Path $ProjectRoot 'TestResultsAggregator.Tests.ps1')) "Pester tests exist"

# ----------------------------------------------------------------------------
# Test cases driven through act
# ----------------------------------------------------------------------------
$cases = @(
    [pscustomobject]@{
        Name     = 'single-xml-run'
        Fixtures = @('run1.xml')
        Expected = @{ TOTAL=4; PASSED=2; FAILED=1; SKIPPED=1; RUNS=1; FLAKY='none' }
    }
    [pscustomobject]@{
        Name     = 'two-xml-runs-flaky'
        Fixtures = @('run1.xml','run2.xml')
        Expected = @{ TOTAL=8; PASSED=4; FAILED=3; SKIPPED=1; RUNS=2; FLAKY='core::AlphaTest' }
    }
    [pscustomobject]@{
        Name     = 'mixed-xml-and-json'
        Fixtures = @('run1.xml','run2.xml','run3.json')
        Expected = @{ TOTAL=13; PASSED=7; FAILED=4; SKIPPED=2; RUNS=3; FLAKY='core::AlphaTest' }
    }
)

# Files copied into every case's temp repo (everything except fixtures/ and .git/).
$projectFiles = @(
    'TestResultsAggregator.psm1'
    'TestResultsAggregator.Tests.ps1'
    'Invoke-Aggregator.ps1'
    '.actrc'
)

foreach ($case in $cases) {
    Write-Host "`n=== act case: $($case.Name) ===" -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "act-$($case.Name)-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmp | Out-Null

    try {
        # Copy project files
        foreach ($f in $projectFiles) {
            Copy-Item -LiteralPath (Join-Path $ProjectRoot $f) -Destination $tmp -Force
        }
        # Copy workflow tree
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
        Copy-Item -LiteralPath $wfPath -Destination (Join-Path $tmp '.github/workflows/') -Force

        # Copy the canonical test-fixtures (all files) so Pester tests can run.
        New-Item -ItemType Directory -Path (Join-Path $tmp 'test-fixtures') -Force | Out-Null
        Copy-Item -Path (Join-Path $ProjectRoot 'test-fixtures/*') -Destination (Join-Path $tmp 'test-fixtures') -Force

        # Copy this case's fixtures (a subset) for the aggregator job.
        New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') -Force | Out-Null
        foreach ($fx in $case.Fixtures) {
            Copy-Item -LiteralPath (Join-Path $ProjectRoot "test-fixtures/$fx") -Destination (Join-Path $tmp 'fixtures') -Force
        }

        # git init + commit
        Push-Location $tmp
        try {
            git init -q -b main
            git config user.email 'ci@example.com'
            git config user.name  'ci'
            git add . | Out-Null
            git commit -q -m "case $($case.Name)" | Out-Null

            # Run act
            Add-Content -LiteralPath $ResultFile -Value "============================================================"
            Add-Content -LiteralPath $ResultFile -Value "CASE: $($case.Name)"
            Add-Content -LiteralPath $ResultFile -Value "Fixtures: $($case.Fixtures -join ', ')"
            Add-Content -LiteralPath $ResultFile -Value "============================================================"

            $actOutput = & act push --rm 2>&1 | Out-String
            $actExit = $LASTEXITCODE
            Add-Content -LiteralPath $ResultFile -Value $actOutput
            Add-Content -LiteralPath $ResultFile -Value "[exit=$actExit]"

            Assert-True ($actExit -eq 0) "[$($case.Name)] act exited 0 (got $actExit)"
            Assert-True ($actOutput -match 'Job succeeded') "[$($case.Name)] at least one 'Job succeeded' present"

            # In act, both jobs should succeed.
            $succeededCount = ([regex]::Matches($actOutput, 'Job succeeded')).Count
            Assert-True ($succeededCount -ge 2) "[$($case.Name)] both jobs succeeded (got $succeededCount 'Job succeeded' lines)"

            # Parse the AGGREGATE_RESULT line and assert exact values.
            $line = ($actOutput -split "`n") | Where-Object { $_ -match 'AGGREGATE_RESULT::' } | Select-Object -First 1
            Assert-True ($null -ne $line) "[$($case.Name)] AGGREGATE_RESULT line found"

            if ($line) {
                foreach ($key in $case.Expected.Keys) {
                    $expected = $case.Expected[$key]
                    $pattern = "$key=([^\s]+)"
                    if ($line -match $pattern) {
                        $actual = $matches[1]
                        Assert-True ($actual -eq [string]$expected) "[$($case.Name)] $key=$actual (expected $expected)"
                    } else {
                        Assert-True $false "[$($case.Name)] could not parse $key from AGGREGATE_RESULT line"
                    }
                }
            }
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

# ----------------------------------------------------------------------------
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($failures.Count -eq 0) {
    Write-Host "All assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Failures:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
