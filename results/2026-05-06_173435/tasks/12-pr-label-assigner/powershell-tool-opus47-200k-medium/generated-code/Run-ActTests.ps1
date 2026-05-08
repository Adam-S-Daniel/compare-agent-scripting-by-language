# act-based end-to-end test harness.
# For each test case, set up fixture files, run `act push --rm`, capture and parse
# the output, and assert against an exact expected label sequence.
#
# Outputs to act-result.txt (required artifact) and exits non-zero on any failure.

[CmdletBinding()]
param(
    [string] $ActResultFile = "$PSScriptRoot/act-result.txt"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (Test-Path -LiteralPath $ActResultFile) { Remove-Item -LiteralPath $ActResultFile -Force }

# 1) Workflow structure pre-flight checks
Write-Host '== Workflow structure tests ==' -ForegroundColor Cyan

$workflowPath = Join-Path $PSScriptRoot '.github/workflows/pr-label-assigner.yml'
if (-not (Test-Path -LiteralPath $workflowPath)) { throw "Workflow not found at $workflowPath" }

# actionlint must pass cleanly.
& actionlint $workflowPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed with exit code $LASTEXITCODE" }
Write-Host '  [+] actionlint passes' -ForegroundColor Green

# Parse YAML by invoking pwsh's ConvertFrom-Yaml if available; otherwise do a
# string-based structural check (Pester is in the container, ConvertFrom-Yaml
# is not part of stock pwsh on linux, so we keep the check string-based).
$wf = Get-Content -LiteralPath $workflowPath -Raw
foreach ($needle in @('name: PR Label Assigner','on:','push:','pull_request:','workflow_dispatch:','jobs:','test:','assign-labels:','actions/checkout@v4','PrLabelAssigner.Tests.ps1','Invoke-PrLabelAssigner.ps1')) {
    if ($wf -notmatch [regex]::Escape($needle)) { throw "Workflow missing expected element: $needle" }
}
Write-Host '  [+] workflow contains expected triggers, jobs, and script references' -ForegroundColor Green

# Referenced scripts must exist.
foreach ($p in @('PrLabelAssigner.ps1','PrLabelAssigner.Tests.ps1','Invoke-PrLabelAssigner.ps1','rules.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $p))) {
        throw "Workflow-referenced file is missing: $p"
    }
}
Write-Host '  [+] referenced script files exist' -ForegroundColor Green

# 2) Test cases
$cases = @(
    @{
        Name     = 'docs-only'
        Files    = @('docs/intro.md','docs/api/auth.md')
        Expected = @('documentation')
    },
    @{
        Name     = 'mixed-priorities'
        Files    = @('docs/a.md','src/api/users.ts','src/api/users.test.ts','package.json')
        # tests=30, api/backend=20, documentation=10, dependencies=5
        Expected = @('tests','api','backend','documentation','dependencies')
    },
    @{
        Name     = 'no-matches'
        Files    = @('random/path.xyz','another/unmapped.bin')
        Expected = @()
    }
)

$fixturesDir = Join-Path $PSScriptRoot 'fixtures'
New-Item -ItemType Directory -Path $fixturesDir -Force | Out-Null

# Ensure repo is initialized at $PSScriptRoot — act needs a git repo.
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) {
    Push-Location $PSScriptRoot
    try {
        git init -q
        git add -A
        git -c user.email=test@example.com -c user.name=test commit -q -m 'init'
    } finally { Pop-Location }
}

$allFailures = @()

foreach ($c in $cases) {
    Write-Host "`n== Running act for case: $($c.Name) ==" -ForegroundColor Cyan

    # Write the fixture file the workflow will read by default.
    $filesFixture = Join-Path $fixturesDir 'files.txt'
    Set-Content -LiteralPath $filesFixture -Value ($c.Files -join "`n")

    # Stage so act sees it (act uses git index, not the working dir).
    Push-Location $PSScriptRoot
    try {
        git add -A 2>$null | Out-Null
        # Commit if there is anything to commit; act needs HEAD to point at current files.
        $status = git status --porcelain
        if ($status) {
            git -c user.email=test@example.com -c user.name=test commit -q -m "fixture: $($c.Name)"
        }
    } finally { Pop-Location }

    $delim = "===== CASE: $($c.Name) ====="
    Add-Content -LiteralPath $ActResultFile -Value $delim

    # Run act. --rm cleans up containers; -W limits to our workflow file.
    $output = & act push --rm --pull=false -W $workflowPath 2>&1 | Out-String
    $exit = $LASTEXITCODE

    Add-Content -LiteralPath $ActResultFile -Value $output
    Add-Content -LiteralPath $ActResultFile -Value "===== EXIT: $exit ====="

    if ($exit -ne 0) {
        $allFailures += "Case '$($c.Name)': act exited with $exit"
        Write-Host "  [-] act exit=$exit" -ForegroundColor Red
        continue
    }

    # Assert both jobs succeeded.
    $succeededCount = ([regex]::Matches($output, 'Job succeeded')).Count
    if ($succeededCount -lt 2) {
        $allFailures += "Case '$($c.Name)': expected at least 2 'Job succeeded' lines, found $succeededCount"
        Write-Host "  [-] expected >=2 'Job succeeded', got $succeededCount" -ForegroundColor Red
    } else {
        Write-Host "  [+] Both jobs succeeded" -ForegroundColor Green
    }

    # Parse the labels emitted between LABELS_BEGIN / LABELS_END.
    $lines = $output -split "`r?`n"
    $inBlock = $false
    $got = @()
    foreach ($ln in $lines) {
        if ($ln -match 'LABELS_BEGIN') { $inBlock = $true; continue }
        if ($ln -match 'LABELS_END')   { $inBlock = $false; continue }
        if ($inBlock -and $ln -match 'label:\s*(\S+)\s*$') {
            $got += $Matches[1]
        }
    }

    $expected = @($c.Expected)
    $gotJoined = $got -join ','
    $expJoined = $expected -join ','
    if ($gotJoined -ne $expJoined) {
        $allFailures += "Case '$($c.Name)': expected labels [$expJoined] but got [$gotJoined]"
        Write-Host "  [-] expected: [$expJoined]" -ForegroundColor Red
        Write-Host "      got:      [$gotJoined]" -ForegroundColor Red
    } else {
        Write-Host "  [+] labels match: [$gotJoined]" -ForegroundColor Green
    }
}

if ($allFailures.Count -gt 0) {
    Write-Host "`nFAILURES:" -ForegroundColor Red
    $allFailures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Add-Content -LiteralPath $ActResultFile -Value "`nFAILURES: $($allFailures.Count)"
    exit 1
}

Add-Content -LiteralPath $ActResultFile -Value "`nALL CASES PASSED"
Write-Host "`nAll cases passed." -ForegroundColor Green
