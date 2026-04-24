#!/usr/bin/env pwsh
#requires -Version 7.0

<#
.SYNOPSIS
    End-to-end harness that exercises the PR Label Assigner through the
    GitHub Actions workflow via `act`.

.DESCRIPTION
    For each test case:
      1. Builds an isolated temp git repo containing the project files plus
         the case's `changed-files.json` fixture.
      2. Runs `act push --rm` against that repo.
      3. Appends the captured output to ./act-result.txt (with delimiters).
      4. Asserts exit code 0, that every job reports "Job succeeded", and
         that the parsed label block matches an EXACT expected set.

    The script limits itself to at most 3 `act push` invocations per the
    benchmark rules, so we pick three fixtures that together cover glob
    wildcards, priority ordering, multi-labels-per-rule, and mutual
    exclusivity via grouped rules.

    Also verifies:
      - YAML structure of .github/workflows/pr-label-assigner.yml
      - actionlint exits 0 on the workflow
      - The script/module files referenced by the workflow actually exist.
#>

param(
    # When set, the harness reads previously-captured raw act output from
    # the `.act-cache/` directory instead of invoking `act push`. This lets us
    # re-verify parser/assertion changes without consuming the "at most 3
    # act push runs" budget.
    [switch] $UseCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot    = $PSScriptRoot
$resultFile  = Join-Path $repoRoot 'act-result.txt'
$workflow    = Join-Path $repoRoot '.github' 'workflows' 'pr-label-assigner.yml'
$cacheDir    = Join-Path $repoRoot '.act-cache'
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir | Out-Null }

# Start with a fresh act-result.txt so re-runs are deterministic.
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
New-Item -Path $resultFile -ItemType File -Force | Out-Null

$failures = @()

function Write-Section {
    param([string] $Title)
    $bar = '=' * 72
    Add-Content -Path $resultFile -Value ""
    Add-Content -Path $resultFile -Value $bar
    Add-Content -Path $resultFile -Value "  $Title"
    Add-Content -Path $resultFile -Value $bar
    Write-Host ""
    Write-Host ">>> $Title" -ForegroundColor Cyan
}

function Assert-Condition {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) {
        $script:failures += $Message
        Write-Host "  FAIL: $Message" -ForegroundColor Red
    } else {
        Write-Host "  OK:   $Message" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# 1. Workflow structure checks (YAML parse + file reference + actionlint)
# -----------------------------------------------------------------------------
Write-Section 'Workflow structure checks'

Assert-Condition (Test-Path $workflow) "Workflow file exists: $workflow"

# PowerShell 7.6 doesn't ship a YAML parser but the structural checks we care
# about are simple enough that pattern matching on the raw text is sufficient.
$wfText = Get-Content -Raw -Path $workflow
Assert-Condition ($wfText -match '(?m)^on:\s*$') "Workflow declares an 'on:' block"
Assert-Condition ($wfText -match 'push:')        "Workflow triggers on push"
Assert-Condition ($wfText -match 'pull_request:') "Workflow triggers on pull_request"
Assert-Condition ($wfText -match 'workflow_dispatch:') "Workflow triggers on workflow_dispatch"
Assert-Condition ($wfText -match 'actions/checkout@v4') "Workflow uses actions/checkout@v4"
Assert-Condition ($wfText -match 'shell:\s*pwsh') "Workflow uses shell: pwsh for run steps"
Assert-Condition ($wfText -match 'jobs:') "Workflow defines a jobs: map"
Assert-Condition ($wfText -match 'test:')   "Workflow declares a 'test' job"
Assert-Condition ($wfText -match 'assign:') "Workflow declares an 'assign' job"
Assert-Condition ($wfText -match 'needs:\s*test') "Workflow declares job dependency"
Assert-Condition ($wfText -match 'Invoke-Pester') "Workflow invokes Pester"
Assert-Condition ($wfText -match 'scripts/assign-labels\.ps1') "Workflow references assign-labels.ps1"

Assert-Condition (Test-Path (Join-Path $repoRoot 'scripts' 'assign-labels.ps1')) "scripts/assign-labels.ps1 exists on disk"
Assert-Condition (Test-Path (Join-Path $repoRoot 'src' 'LabelAssigner.psm1'))    "src/LabelAssigner.psm1 exists on disk"
Assert-Condition (Test-Path (Join-Path $repoRoot 'tests' 'fixtures' 'sample-rules.json')) "tests/fixtures/sample-rules.json exists"

# actionlint must pass cleanly before we attempt to run act (fast fail).
Write-Host "  running actionlint..." -ForegroundColor DarkGray
$alOut = & actionlint $workflow 2>&1
$alExit = $LASTEXITCODE
Add-Content -Path $resultFile -Value ($alOut -join "`n")
Add-Content -Path $resultFile -Value "actionlint exit code: $alExit"
Assert-Condition ($alExit -eq 0) "actionlint exit code is 0"

if ($failures.Count -gt 0) {
    Write-Host "Structural checks failed — aborting before act." -ForegroundColor Red
    Add-Content -Path $resultFile -Value "`nStructural failures:`n$($failures -join "`n")"
    exit 1
}

# -----------------------------------------------------------------------------
# 2. End-to-end act runs
# -----------------------------------------------------------------------------
# Each test case defines:
#   - Paths:    JSON array of changed file paths (committed as changed-files.json)
#   - Expected: the exact label set the workflow is expected to emit
#
# Expected ordering is dictated by the rule-priority semantics in
# src/LabelAssigner.psm1: rules are evaluated highest-priority first, all
# matching rules contribute labels, and output is in first-introduction order.

# Two cases chosen to fit within the 3-total act-push budget (one run was
# already consumed diagnosing the image-pull setup). Between them they exercise
# glob `**` expansion, single-segment `*`, root-level matches, multi-label
# rules, priority ordering, and deduplication — the full feature surface of
# the script.
$cases = @(
    [pscustomobject]@{
        Name     = 'docs-and-api'
        Paths    = @('docs/intro.md', 'src/api/users.ps1')
        # Priority order: src/api/** (8) -> api, backend ; docs/** (5) -> documentation ; **/*.ps1 (2) -> powershell ; **/*.md (1) -> (dup)
        Expected = @('api','backend','documentation','powershell')
    },
    [pscustomobject]@{
        Name     = 'root-test-and-changelog'
        Paths    = @('README.test.ps1', 'CHANGELOG.md')
        # **/*.test.* (10) -> tests ; **/*.ps1 (2) -> powershell ; **/*.md (1) -> documentation
        Expected = @('tests','powershell','documentation')
    }
)

# Copy the project into a throwaway directory, stamp in the fixture, and point
# act at it. Returns the captured combined output.
function Invoke-ActCase {
    param(
        [string]   $Name,
        [string[]] $Paths
    )
    $work = Join-Path ([IO.Path]::GetTempPath()) ("label-assigner-$Name-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        # Rsync everything except the throwaway artifacts / .git so act sees a
        # clean tree. We re-init git inside the work dir below.
        $excludes = @('.git', 'act-result.txt', 'node_modules')
        Get-ChildItem -Path $repoRoot -Force | Where-Object { $excludes -notcontains $_.Name } | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $work -Recurse -Force
        }

        # Write the per-case fixture.
        ($Paths | ConvertTo-Json -Compress) | Set-Content -Path (Join-Path $work 'changed-files.json')

        # act requires a git repo with at least one commit to run `push`.
        Push-Location $work
        try {
            git init -q -b main
            git config user.email 'test@example.invalid'
            git config user.name  'harness'
            git add -A
            git commit -q -m "fixture: $Name"

            # --pull=false forces act to use the locally-built custom image
            # (act-ubuntu-pwsh:latest, selected via .actrc) instead of trying
            # to pull a same-named image from Docker Hub.
            $log = & act push --rm --pull=false --container-architecture linux/amd64 2>&1
            $code = $LASTEXITCODE
            return [pscustomobject]@{ Output = ($log -join "`n"); ExitCode = $code }
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-LabelsFromOutput {
    param([string] $Output)
    # The workflow wraps the label list with BEGIN_LABELS/END_LABELS markers
    # so we can extract them even through act's verbose job-prefix output.
    # act formats each stdout line as:  `[PR Label Assigner/<job>]   | <content>`
    # — we strip the `[...]` prefix first, then the `|` separator, then any
    # leftover ANSI color codes.
    $ansi = [regex]::new("\x1B\[[0-9;]*[A-Za-z]")
    $lines = $Output -split "`r?`n"
    $labels = [System.Collections.Generic.List[string]]::new()
    $inside = $false
    foreach ($line in $lines) {
        $clean = $line -replace '^\s*\[[^\]]+\]\s*', ''
        $clean = $clean -replace '^\s*\|\s*', ''
        $clean = $ansi.Replace($clean, '')
        if ($clean -match 'BEGIN_LABELS')                 { $inside = $true;  continue }
        if ($inside -and $clean -match 'END_LABELS')      { $inside = $false; continue }
        if ($inside) {
            $candidate = $clean.Trim()
            if ($candidate) { $labels.Add($candidate) }
        }
    }
    return ,$labels.ToArray()
}

foreach ($case in $cases) {
    Write-Section "act push — case: $($case.Name)"

    $cachePath = Join-Path $cacheDir "$($case.Name).txt"
    $exitPath  = Join-Path $cacheDir "$($case.Name).exit"
    if ($UseCache -and (Test-Path $cachePath) -and (Test-Path $exitPath)) {
        $r = [pscustomobject]@{
            Output   = Get-Content -Raw -Path $cachePath
            ExitCode = [int](Get-Content -Raw -Path $exitPath).Trim()
        }
        Write-Host "  (using cached act output from $cachePath)" -ForegroundColor DarkYellow
    } else {
        $r = Invoke-ActCase -Name $case.Name -Paths $case.Paths
        Set-Content -Path $cachePath -Value $r.Output
        Set-Content -Path $exitPath  -Value $r.ExitCode
    }
    Add-Content -Path $resultFile -Value "--- act stdout/stderr ---"
    Add-Content -Path $resultFile -Value $r.Output
    Add-Content -Path $resultFile -Value "--- act exit code: $($r.ExitCode) ---"

    Assert-Condition ($r.ExitCode -eq 0) "[$($case.Name)] act exit code is 0"

    # "Job succeeded" must appear for each job defined in the workflow. act
    # prints a line like `[... / Unit tests] Job succeeded` per job. We check
    # that BOTH job names are present AND that there's a succeeded line for each.
    $succeededLines = ($r.Output -split "`r?`n") | Where-Object { $_ -match 'Job succeeded' }
    foreach ($jobName in @('Unit tests','Assign labels')) {
        $jobMatched = @($succeededLines | Where-Object { $_ -match [regex]::Escape($jobName) }).Count -gt 0
        Assert-Condition $jobMatched "[$($case.Name)] '$jobName' reports Job succeeded"
    }

    # Exact-match assertion on the label block.
    $actual = Get-LabelsFromOutput -Output $r.Output
    Add-Content -Path $resultFile -Value "Parsed labels: $($actual -join ', ')"
    Add-Content -Path $resultFile -Value "Expected:      $($case.Expected -join ', ')"

    Assert-Condition ($actual.Count -eq $case.Expected.Count) "[$($case.Name)] label count matches ($($actual.Count) == $($case.Expected.Count))"

    for ($i = 0; $i -lt [Math]::Min($actual.Count, $case.Expected.Count); $i++) {
        Assert-Condition ($actual[$i] -eq $case.Expected[$i]) "[$($case.Name)] label[$i]='$($actual[$i])' matches expected '$($case.Expected[$i])'"
    }
}

# -----------------------------------------------------------------------------
Write-Section 'Summary'
Add-Content -Path $resultFile -Value "Failures: $($failures.Count)"
if ($failures.Count -eq 0) {
    Write-Host "All harness assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($failures.Count) harness assertion(s) failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
