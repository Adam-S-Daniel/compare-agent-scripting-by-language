#!/usr/bin/env pwsh
# Test harness: drives the workflow through nektos/act for a series of
# fixture cases and asserts on the act output. Also runs structural checks
# (actionlint, YAML parse, file references) against the workflow file.
#
# All act output is appended to ./act-result.txt — that file is the
# required artifact for this task.

[CmdletBinding()] param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = $PSScriptRoot
$resultFile = Join-Path $repoRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# ---------------------------------------------------------------- helpers

function Assert($cond, [string]$msg) {
    if (-not $cond) { throw "ASSERTION FAILED: $msg" }
    Write-Host "  PASS  $msg" -ForegroundColor Green
}

function Append-ActLog([string]$caseName, [string]$content, [int]$exitCode) {
    $delim = '=' * 70
    Add-Content -LiteralPath $resultFile -Value @"
$delim
TEST CASE: $caseName
EXIT CODE: $exitCode
$delim
$content

"@
}

# ---------------------------------------------------- structural checks

Write-Host "`n--- Structural checks ---" -ForegroundColor Cyan
$workflowPath = Join-Path $repoRoot '.github/workflows/dependency-license-checker.yml'

Assert (Test-Path $workflowPath) "workflow file exists at $workflowPath"
Assert (Test-Path (Join-Path $repoRoot 'LicenseChecker.psm1'))      'module exists'
Assert (Test-Path (Join-Path $repoRoot 'LicenseChecker.Tests.ps1')) 'tests exist'
Assert (Test-Path (Join-Path $repoRoot 'Invoke-LicenseChecker.ps1'))'cli exists'

# actionlint
$alOut = & actionlint $workflowPath 2>&1
$alExit = $LASTEXITCODE
Assert ($alExit -eq 0) "actionlint passes (exit=$alExit). Output: $alOut"

# Parse the workflow YAML using PowerShell-Yaml if available, else regex sanity
$yaml = Get-Content -LiteralPath $workflowPath -Raw
Assert ($yaml -match '(?m)^on:')                           'workflow declares triggers'
Assert ($yaml -match 'push:')                               'has push trigger'
Assert ($yaml -match 'pull_request:')                       'has pull_request trigger'
Assert ($yaml -match 'workflow_dispatch:')                  'has workflow_dispatch trigger'
Assert ($yaml -match 'schedule:')                           'has schedule trigger'
Assert ($yaml -match 'actions/checkout@v4')                 'uses actions/checkout@v4'
Assert ($yaml -match 'LicenseChecker\.Tests\.ps1')          'references the Pester tests'
Assert ($yaml -match 'Invoke-LicenseChecker\.ps1')          'references the CLI script'
Assert ($yaml -match '(?m)permissions:')                    'declares permissions'
Assert ($yaml -match 'shell: pwsh')                         'uses shell: pwsh on run steps'

# ------------------------------------------------------- act invocations

# Each case: name, the package.json content, the mock-licenses.json content,
# whether we expect the workflow to succeed (exit 0), and a regex that must
# appear in the captured act output.
$cases = @(
    @{
        Name       = 'all-approved'
        Package    = (@{
            name = 'demo'; version = '1.0.0'
            dependencies = @{ lodash = '4.17.21'; express = '4.18.0' }
        } | ConvertTo-Json -Depth 5)
        Lookup     = (@{ lodash = 'MIT'; express = 'Apache-2.0' } | ConvertTo-Json)
        ExpectExit = 0
        MustMatch  = @(
            'lodash@4\.17\.21 :: MIT :: APPROVED',
            'express@4\.18\.0 :: Apache-2\.0 :: APPROVED',
            'Total: 2 \| Approved: 2 \| Denied: 0 \| Unknown: 0',
            'PASS: all dependencies approved'
        )
    }
    @{
        Name       = 'denied-dependency'
        Package    = (@{
            name = 'demo'; version = '1.0.0'
            dependencies = @{ lodash = '4.17.21'; 'evil-pkg' = '1.0.0' }
        } | ConvertTo-Json -Depth 5)
        Lookup     = (@{ lodash = 'MIT'; 'evil-pkg' = 'GPL-3.0' } | ConvertTo-Json)
        ExpectExit = 0
        MustMatch  = @(
            'lodash@4\.17\.21 :: MIT :: APPROVED',
            'evil-pkg@1\.0\.0 :: GPL-3\.0 :: DENIED',
            'Total: 2 \| Approved: 1 \| Denied: 1 \| Unknown: 0',
            'FAIL: 1 denied, 0 unknown'
        )
    }
    @{
        Name       = 'unknown-license'
        Package    = (@{
            name = 'demo'; version = '1.0.0'
            dependencies = @{ lodash = '4.17.21'; mystery = '0.0.1' }
        } | ConvertTo-Json -Depth 5)
        Lookup     = (@{ lodash = 'MIT' } | ConvertTo-Json)   # mystery deliberately absent
        ExpectExit = 0
        MustMatch  = @(
            'mystery@0\.0\.1 :: <none> :: UNKNOWN',
            'Total: 2 \| Approved: 1 \| Denied: 0 \| Unknown: 1',
            'FAIL: 0 denied, 1 unknown'
        )
    }
)

# Run all three cases via act in turn. Each case stages its own fixture
# files in a fresh temp git repo, then invokes `act push --rm`.
foreach ($case in $cases) {
    Write-Host "`n--- act case: $($case.Name) ---" -ForegroundColor Cyan

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("lc-act-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        # Copy project files
        Copy-Item (Join-Path $repoRoot 'LicenseChecker.psm1')      $work
        Copy-Item (Join-Path $repoRoot 'LicenseChecker.Tests.ps1') $work
        Copy-Item (Join-Path $repoRoot 'Invoke-LicenseChecker.ps1')$work
        Copy-Item (Join-Path $repoRoot 'license-config.json')      $work
        Copy-Item (Join-Path $repoRoot '.actrc')                   $work
        New-Item -ItemType Directory -Path (Join-Path $work '.github/workflows') -Force | Out-Null
        Copy-Item $workflowPath (Join-Path $work '.github/workflows/dependency-license-checker.yml')

        # Stage per-case fixture
        Set-Content -LiteralPath (Join-Path $work 'package.json')       -Value $case.Package
        Set-Content -LiteralPath (Join-Path $work 'mock-licenses.json') -Value $case.Lookup

        # Init git so act has a repo to read from
        Push-Location $work
        try {
            git init -q
            git config user.email 'test@example.com'
            git config user.name  'test'
            git add -A
            git -c commit.gpgsign=false commit -q -m 'fixture'

            $log = & act push --rm 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Append-ActLog $case.Name $log $exit
        Assert ($exit -eq $case.ExpectExit) "act exit code = $($case.ExpectExit) (got $exit)"
        Assert ($log -match 'Job succeeded') "log shows 'Job succeeded'"
        foreach ($pattern in $case.MustMatch) {
            Assert ($log -match $pattern) "output matches /$pattern/"
        }
    } finally {
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    }
}

Write-Host "`nAll harness checks passed. act-result.txt written." -ForegroundColor Green
