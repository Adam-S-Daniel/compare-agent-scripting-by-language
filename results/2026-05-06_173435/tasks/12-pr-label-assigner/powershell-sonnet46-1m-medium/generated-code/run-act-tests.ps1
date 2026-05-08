# Test harness: validates workflow structure, runs act, asserts on exact output.
# Generates act-result.txt as a required artifact.
#
# Usage: pwsh run-act-tests.ps1
# Limit: at most 3 act push runs (diagnose from output, don't re-run blindly)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ResultFile = Join-Path $PSScriptRoot "act-result.txt"

function Write-Section {
    param([string]$Title)
    $line = "=" * 60
    $msg  = "$line`n=== $Title`n$line"
    Write-Host $msg
    Add-Content -Path $ResultFile -Value $msg
}

function Assert-True {
    param([string]$Description, [bool]$Condition)
    if (-not $Condition) {
        $msg = "ASSERTION FAILED: $Description"
        Add-Content -Path $ResultFile -Value $msg
        Write-Error $msg
    }
    $msg = "PASS: $Description"
    Write-Host $msg -ForegroundColor Green
    Add-Content -Path $ResultFile -Value $msg
}

# Initialise result file
"PR Label Assigner - ACT Test Results" | Set-Content -Path $ResultFile
"Run date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"    | Add-Content -Path $ResultFile


# ── Step 0: actionlint validation ────────────────────────────────────────────
Write-Section "Step 0: actionlint validation"

$actionlintOut = & actionlint .github/workflows/pr-label-assigner.yml 2>&1
$actionlintExit = $LASTEXITCODE

$actionlintOut | ForEach-Object { Add-Content -Path $ResultFile -Value $_ }
Assert-True "actionlint exits 0" ($actionlintExit -eq 0)


# ── Step 1: Workflow structure checks ────────────────────────────────────────
Write-Section "Step 1: Workflow structure checks"

$workflowPath = ".github/workflows/pr-label-assigner.yml"
Assert-True "workflow file exists"            (Test-Path $workflowPath)
Assert-True "main script exists"              (Test-Path "Invoke-PRLabelAssigner.ps1")
Assert-True "test file exists"                (Test-Path "Invoke-PRLabelAssigner.Tests.ps1")

$wf = Get-Content $workflowPath -Raw
Assert-True "workflow has push trigger"             ($wf -match 'push:')
Assert-True "workflow has pull_request trigger"     ($wf -match 'pull_request:')
Assert-True "workflow has workflow_dispatch trigger" ($wf -match 'workflow_dispatch:')
Assert-True "workflow has jobs section"             ($wf -match 'jobs:')
Assert-True "workflow uses actions/checkout"        ($wf -match 'actions/checkout')
Assert-True "workflow uses shell: pwsh"             ($wf -match 'shell: pwsh')
Assert-True "workflow invokes Invoke-Pester"        ($wf -match 'Invoke-Pester')


# ── Step 2: Run act (attempt 1) ──────────────────────────────────────────────
Write-Section "Step 2: act push run 1"

Write-Host "Running: act push --rm  (this takes 30-90 s)"

$actOutput = & act push --rm 2>&1
$actExit   = $LASTEXITCODE

$actOutput | ForEach-Object { Add-Content -Path $ResultFile -Value $_ }

Write-Section "Step 2: Assertions on act output"

# Exit code
Assert-True "act exits 0" ($actExit -eq 0)

# Job success marker
$fullOutput = $actOutput -join "`n"

# Strip ANSI escape codes for cleaner matching
$ansiPattern   = '\x1B\[[0-9;]*[mK]'
$cleanOutput   = [regex]::Replace($fullOutput, $ansiPattern, '')

Assert-True "job succeeded marker present"  ($cleanOutput -match 'Job succeeded')

# Pester results (ANSI codes stripped so comma-space sequence is intact)
Assert-True "Pester tests passed with 0 failures" ($cleanOutput -match 'Tests Passed: \d+, Failed: 0')

# Scenario 1: exact label string
Assert-True "Scenario 1 exact output: 'Applied labels: api, documentation, tests'" `
    ($cleanOutput -match [regex]::Escape('Applied labels: api, documentation, tests'))

# Scenario 2: docs-only
Assert-True "Scenario 2 exact output: 'Applied labels: documentation'" `
    ($cleanOutput -match [regex]::Escape('Applied labels: documentation'))

# Scenario 3: no match
Assert-True "Scenario 3 exact output: 'No labels matched'" `
    ($cleanOutput -match [regex]::Escape('No labels matched'))

# Scenario 4: overlapping rules produce two labels
Assert-True "Scenario 4 contains 'api-docs'" ($cleanOutput -match [regex]::Escape('api-docs'))
Assert-True "Scenario 4 contains 'backend'"  ($cleanOutput -match [regex]::Escape('backend'))


# ── Final summary ─────────────────────────────────────────────────────────────
Write-Section "All assertions passed"
Write-Host "act-result.txt written to: $ResultFile"
