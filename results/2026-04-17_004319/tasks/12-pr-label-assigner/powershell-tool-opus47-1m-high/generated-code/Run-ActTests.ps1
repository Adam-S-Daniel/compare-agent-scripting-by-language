#!/usr/bin/env pwsh
# End-to-end test harness: runs every test case through the real GitHub Actions
# workflow using `act`, asserts exact label output, and produces act-result.txt.
#
# For each case we:
#   1. Copy the project into a temp git repo.
#   2. Overwrite rules.json / changed-files.txt with the case's fixture.
#   3. Run `act push --rm` and capture stdout+stderr.
#   4. Append the raw output (clearly delimited) to act-result.txt.
#   5. Assert act exited 0, the assigner block is present, every job reports
#      success, and the label list matches EXACTLY.
#
# Budget: 3 `act push` invocations total, one per case.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ActResultPath = Join-Path $ProjectRoot 'act-result.txt'
if (Test-Path $ActResultPath) { Remove-Item $ActResultPath -Force }

# Test-case fixtures.  Expected labels are exact, in order, matching what the
# assigner should emit given those rules and files.
$cases = @(
    @{
        Name     = 'api-and-tests'
        Rules    = @'
{
  "rules": [
    { "pattern": "docs/**",     "labels": ["documentation"], "priority": 5 },
    { "pattern": "src/api/**",  "labels": ["api"],           "priority": 1 },
    { "pattern": "**/*.test.*", "labels": ["tests"],         "priority": 2 },
    { "pattern": "**/*.ps1",    "labels": ["powershell"],    "priority": 10 }
  ]
}
'@
        Files    = @(
            'src/api/users.ps1',
            'src/api/users.test.ps1',
            'docs/guide.md'
        )
        Expected = @('api', 'tests', 'documentation', 'powershell')
    },
    @{
        Name     = 'docs-only'
        Rules    = @'
{
  "rules": [
    { "pattern": "docs/**",   "labels": ["documentation"], "priority": 5 },
    { "pattern": "**/*.md",   "labels": ["documentation"], "priority": 6 },
    { "pattern": "src/**",    "labels": ["code"],          "priority": 3 }
  ]
}
'@
        Files    = @('docs/intro.md', 'README.md')
        Expected = @('documentation')
    },
    @{
        Name     = 'priority-conflict'
        Rules    = @'
{
  "rules": [
    { "pattern": "**/*",        "labels": ["generic"],   "priority": 100 },
    { "pattern": "security/**", "labels": ["security"],  "priority": 1   },
    { "pattern": "**/*.ps1",    "labels": ["powershell"], "priority": 20 }
  ]
}
'@
        Files    = @('security/keys.ps1', 'lib/helper.ps1')
        Expected = @('security', 'powershell', 'generic')
    }
)

function Invoke-OneActCase {
    param($Case)

    $tempDir = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ("pr-label-act-" + [Guid]::NewGuid().ToString('N'))) -Force

    try {
        # Stage project files (exclude .git and transient artifacts).
        $itemsToCopy = Get-ChildItem -LiteralPath $ProjectRoot -Force |
            Where-Object { $_.Name -notin @('.git', 'act-result.txt') }
        foreach ($item in $itemsToCopy) {
            Copy-Item -Path $item.FullName -Destination $tempDir.FullName -Recurse -Force
        }

        # Overwrite fixture files with this case's data.
        Set-Content -Path (Join-Path $tempDir.FullName 'rules.json') -Value $Case.Rules
        Set-Content -Path (Join-Path $tempDir.FullName 'changed-files.txt') -Value ($Case.Files -join "`n")

        # act requires a git repo.
        Push-Location $tempDir.FullName
        try {
            git init --quiet 2>&1 | Out-Null
            git config user.email 'harness@example.com'
            git config user.name 'harness'
            git add -A
            git commit --quiet -m 'fixture' 2>&1 | Out-Null

            Write-Host ""
            Write-Host "=== Running act for case: $($Case.Name) ==="
            # act outputs to stdout; capture both streams together.
            $out = & act push --rm --pull=false 2>&1
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $block = @()
        $block += ""
        $block += "################################################################"
        $block += "# CASE: $($Case.Name)"
        $block += "# exit: $exit"
        $block += "################################################################"
        $block += ($out | Out-String).TrimEnd()
        Add-Content -Path $ActResultPath -Value ($block -join "`n")

        return @{ Exit = $exit; Output = ($out | Out-String); Case = $Case }
    } finally {
        Remove-Item -LiteralPath $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Case {
    param($Result)

    $case = $Result.Case
    $out = $Result.Output

    if ($Result.Exit -ne 0) {
        throw "[$($case.Name)] act exited $($Result.Exit) (expected 0)"
    }

    # Every job must report success. act prints "Job succeeded" per job.
    $succ = [regex]::Matches($out, 'Job succeeded').Count
    if ($succ -lt 2) {
        throw "[$($case.Name)] expected 2 'Job succeeded' lines (unit-tests, assign-labels); found $succ"
    }

    # Extract labels between the markers.
    $startIdx = $out.IndexOf('=== PR Labels ===')
    $endIdx = $out.IndexOf('=== End PR Labels ===')
    if ($startIdx -lt 0 -or $endIdx -lt 0) {
        throw "[$($case.Name)] label markers not found in act output"
    }

    $mid = $out.Substring($startIdx, $endIdx - $startIdx)
    $lines = $mid -split "`r?`n"
    # Strip the opening marker and any act log prefixes like "| " or
    # "[PR Label Assigner/Compute PR labels]".
    $labels = New-Object System.Collections.Generic.List[string]
    $seenStart = $false
    foreach ($raw in $lines) {
        $line = $raw
        # Remove leading "[<workflow>/<job>]" prefix if present.
        $line = $line -replace '^\[[^\]]+\]\s*', ''
        $line = $line.TrimStart('|').TrimStart()
        if ($line.StartsWith('=== PR Labels ===')) { $seenStart = $true; continue }
        if (-not $seenStart) { continue }
        if ($line -eq '') { continue }
        $labels.Add($line)
    }

    # Compare exact sequence.
    $actual = @($labels)
    $expected = @($case.Expected)
    if ($actual.Count -ne $expected.Count) {
        throw "[$($case.Name)] label count mismatch. Expected $($expected.Count) [$($expected -join ', ')], got $($actual.Count) [$($actual -join ', ')]"
    }
    for ($i = 0; $i -lt $expected.Count; $i++) {
        if ($actual[$i] -ne $expected[$i]) {
            throw "[$($case.Name)] label[$i] mismatch. Expected '$($expected[$i])', got '$($actual[$i])'. Full actual: [$($actual -join ', ')]"
        }
    }

    Write-Host "[PASS] $($case.Name): [$($actual -join ', ')]"
}

# -- workflow structure tests (fast; run before burning act time) --
Write-Host "### Workflow structure tests ###"

$workflowPath = Join-Path $ProjectRoot '.github/workflows/pr-label-assigner.yml'
if (-not (Test-Path $workflowPath)) { throw "Workflow missing: $workflowPath" }

# actionlint must pass cleanly.
$alOut = & actionlint $workflowPath 2>&1
$alExit = $LASTEXITCODE
if ($alExit -ne 0) { throw "actionlint failed (exit $alExit): $alOut" }
Write-Host "[PASS] actionlint exit=0"

# Parse the YAML structurally by introspecting via powershell-yaml-free regex
# (we don't want an extra dep). Check for the key shapes.
$wf = Get-Content -Raw $workflowPath
foreach ($needle in @(
    'name: PR Label Assigner',
    'on:',
    '  push:',
    '  pull_request:',
    '  workflow_dispatch:',
    'permissions:',
    'jobs:',
    '  unit-tests:',
    '  assign-labels:',
    'actions/checkout@v4',
    'Invoke-PRLabelAssigner.ps1',
    'shell: pwsh'
)) {
    if ($wf -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected element: '$needle'"
    }
}
Write-Host "[PASS] workflow contains required triggers, jobs, and steps"

# Verify referenced script paths exist.
foreach ($p in @('Invoke-PRLabelAssigner.ps1', 'PRLabelAssigner.psm1', 'PRLabelAssigner.Tests.ps1')) {
    if (-not (Test-Path (Join-Path $ProjectRoot $p))) {
        throw "Referenced script file missing: $p"
    }
}
Write-Host "[PASS] referenced scripts exist"

# -- act run cases --
$results = @()
foreach ($case in $cases) {
    $results += Invoke-OneActCase -Case $case
}

foreach ($r in $results) { Assert-Case -Result $r }

Write-Host ""
Write-Host "All $($cases.Count) act test cases passed. act-result.txt at: $ActResultPath"
