#!/usr/bin/env pwsh
# Test harness: builds an isolated temp git repo per fixture, runs `act push --rm`,
# captures stdout+stderr, asserts the workflow emitted exactly the expected
# LABELS= line, and verifies every job ended with "Job succeeded".
#
# Required artifact: act-result.txt (one delimited section per fixture).

[CmdletBinding()]
param(
    [string] $ResultFile = 'act-result.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Each case = (fixture filename, expected exact LABELS= line)
$cases = @(
    @{ Name = 'docs';    Fixture = 'fixtures/case-docs.txt';    Expected = 'LABELS=documentation' }
    @{ Name = 'mixed';   Fixture = 'fixtures/case-mixed.txt';   Expected = 'LABELS=documentation,api,backend,frontend,tests' }
    @{ Name = 'nomatch'; Fixture = 'fixtures/case-nomatch.txt'; Expected = 'LABELS=' }
)

$projectRoot = $PSScriptRoot
$resultPath  = Join-Path $projectRoot $ResultFile
if (Test-Path $resultPath) { Remove-Item -Force $resultPath }

function Describe-Header([string] $msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# 1. Workflow structure tests (parse YAML, assert required shape).
Describe-Header 'Workflow structure tests'

$wfPath = Join-Path $projectRoot '.github/workflows/pr-label-assigner.yml'
if (-not (Test-Path $wfPath)) { throw "Workflow not found: $wfPath" }

$wfText = Get-Content -Raw $wfPath
foreach ($must in @('on:', 'push:', 'pull_request:', 'workflow_dispatch:',
                    'actions/checkout@v4', 'Invoke-LabelAssigner.ps1',
                    'Invoke-Pester')) {
    if ($wfText -notmatch [regex]::Escape($must)) {
        throw "Workflow missing required token: $must"
    }
}
Write-Host "Workflow structure OK."

# Required script paths referenced by the workflow really exist.
foreach ($p in 'LabelAssigner.psm1','Invoke-LabelAssigner.ps1','rules.json') {
    if (-not (Test-Path (Join-Path $projectRoot $p))) {
        throw "Workflow references missing file: $p"
    }
}

# actionlint must pass cleanly.
Describe-Header 'actionlint'
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed with exit code $LASTEXITCODE" }
Write-Host "actionlint passed."

# 2. Per-fixture act runs.
$projectFiles = @(
    'LabelAssigner.psm1',
    'LabelAssigner.Tests.ps1',
    'Invoke-LabelAssigner.ps1',
    'rules.json',
    '.actrc'
)
$failures = @()

foreach ($case in $cases) {
    Describe-Header "act run: $($case.Name)"
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) "act-lblasg-$($case.Name)-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $sandbox | Out-Null
    try {
        # Copy project files into the sandbox.
        foreach ($f in $projectFiles) {
            Copy-Item -Path (Join-Path $projectRoot $f) -Destination $sandbox -Force
        }
        New-Item -ItemType Directory -Path (Join-Path $sandbox '.github/workflows') -Force | Out-Null
        Copy-Item -Path $wfPath -Destination (Join-Path $sandbox '.github/workflows/pr-label-assigner.yml') -Force

        # Stage this case's fixture as the "PR-changed-files" the workflow reads.
        Copy-Item -Path (Join-Path $projectRoot $case.Fixture) -Destination (Join-Path $sandbox 'changed-files.txt') -Force

        # Init a git repo so checkout has a refs database to act on.
        Push-Location $sandbox
        try {
            git init -q -b main
            git config user.email "test@example.com"
            git config user.name  "Test"
            git add . | Out-Null
            git commit -q -m "fixture: $($case.Name)" | Out-Null

            $logHeader = "===== CASE: $($case.Name) (fixture=$($case.Fixture)) ====="
            Add-Content -Path $resultPath -Value $logHeader

            $stdoutFile = New-TemporaryFile
            $stderrFile = New-TemporaryFile
            $proc = Start-Process -FilePath 'act' `
                -ArgumentList @('push','--rm','--pull=false') `
                -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput $stdoutFile.FullName `
                -RedirectStandardError  $stderrFile.FullName
            $stdout = Get-Content -Raw $stdoutFile.FullName
            $stderr = Get-Content -Raw $stderrFile.FullName
            Remove-Item $stdoutFile, $stderrFile -Force

            Add-Content -Path $resultPath -Value $stdout
            if ($stderr) {
                Add-Content -Path $resultPath -Value "----- stderr -----"
                Add-Content -Path $resultPath -Value $stderr
            }
            Add-Content -Path $resultPath -Value "===== END CASE: $($case.Name) (exit=$($proc.ExitCode)) =====`n"

            Write-Host "act exit code: $($proc.ExitCode)"

            if ($proc.ExitCode -ne 0) {
                $failures += "[$($case.Name)] act exited $($proc.ExitCode)"
                continue
            }

            $combined = "$stdout`n$stderr"

            # Each job must succeed.
            if ($combined -notmatch 'Job succeeded') {
                $failures += "[$($case.Name)] no 'Job succeeded' marker found"
            }

            # Must contain the exact expected LABELS= line.
            if ($combined -notmatch [regex]::Escape($case.Expected)) {
                $failures += "[$($case.Name)] expected '$($case.Expected)' not found in act output"
            } else {
                Write-Host "Asserted: $($case.Expected)" -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
}

Describe-Header 'Summary'
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "FAIL: $f" -ForegroundColor Red }
    throw "$($failures.Count) act test case(s) failed."
}
Write-Host "All act test cases passed; results captured in $ResultFile" -ForegroundColor Green
