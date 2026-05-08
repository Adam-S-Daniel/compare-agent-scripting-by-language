#!/usr/bin/env pwsh
# Test harness: runs the workflow under act for several fixtures, captures
# combined output to act-result.txt, and asserts on exact expected labels.
#
# Limit ourselves to one act run per case (max 3 runs total). Diagnose any
# errors from act-result.txt rather than re-running blindly.

[CmdletBinding()]
param(
    [string]$RepoRoot = $PSScriptRoot,
    [string]$ResultPath = (Join-Path $PSScriptRoot 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Fixture name -> expected ordered label array (priority desc, label asc tiebreak)
$cases = @(
    @{ Name = 'default';   Expected = @('api','tests','documentation') }
    @{ Name = 'docs-only'; Expected = @('documentation') }
    @{ Name = 'empty';     Expected = @() }
)

# Build a clean temp git repo containing just our project files for act.
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("pr-label-act-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Write-Host "Staging project into $work"
    Copy-Item -Path (Join-Path $RepoRoot '.github')        -Destination $work -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'fixtures')       -Destination $work -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot '.actrc')         -Destination $work -Force
    Copy-Item -Path (Join-Path $RepoRoot 'PrLabelAssigner.psm1')   -Destination $work -Force
    Copy-Item -Path (Join-Path $RepoRoot 'PrLabelAssigner.Tests.ps1') -Destination $work -Force
    Copy-Item -Path (Join-Path $RepoRoot 'Invoke-LabelAssigner.ps1') -Destination $work -Force
    Copy-Item -Path (Join-Path $RepoRoot 'labels.config.json')      -Destination $work -Force

    Push-Location $work
    try {
        git init -q -b main 2>&1 | Out-Null
        git -c user.email=ci@local -c user.name=ci add . 2>&1 | Out-Null
        git -c user.email=ci@local -c user.name=ci commit -q -m 'init' 2>&1 | Out-Null
    } finally { Pop-Location }

    if (Test-Path -LiteralPath $ResultPath) { Remove-Item -LiteralPath $ResultPath -Force }
    New-Item -ItemType File -Path $ResultPath | Out-Null

    $allPass = $true
    foreach ($case in $cases) {
        $name = $case.Name
        $expected = @($case.Expected)
        Write-Host "===== act push for fixture '$name' =====" -ForegroundColor Cyan

        $actArgs = @('push', '--rm', '--pull=false', '--env', "FIXTURE=$name")
        Push-Location $work
        try {
            $actOutput = & act @actArgs 2>&1 | Out-String
        } finally { Pop-Location }
        $actExit = $LASTEXITCODE

        Add-Content -LiteralPath $ResultPath -Value "##### CASE: $name (exit=$actExit) #####"
        Add-Content -LiteralPath $ResultPath -Value $actOutput
        Add-Content -LiteralPath $ResultPath -Value "##### END CASE: $name #####`n"

        if ($actExit -ne 0) {
            Write-Host "[FAIL] act exited $actExit for case '$name'" -ForegroundColor Red
            $allPass = $false
            continue
        }

        # Both jobs must succeed
        $successCount = ([regex]::Matches($actOutput, 'Job succeeded')).Count
        if ($successCount -lt 2) {
            Write-Host "[FAIL] expected >= 2 'Job succeeded' lines, got $successCount" -ForegroundColor Red
            $allPass = $false
        }

        # Extract the labels=... line emitted between our delimiters
        $m = [regex]::Match($actOutput, 'labels=(\[[^\]]*\])')
        if (-not $m.Success) {
            Write-Host "[FAIL] could not find labels= line for case '$name'" -ForegroundColor Red
            $allPass = $false
            continue
        }
        $actualJson = $m.Groups[1].Value
        $actual = @($actualJson | ConvertFrom-Json)

        $expectedJson = (@($expected) | ConvertTo-Json -Compress)
        if ($expected.Count -eq 0) { $expectedJson = '[]' }
        $actualNorm = (@($actual) | ConvertTo-Json -Compress)
        if ($actual.Count -eq 0) { $actualNorm = '[]' }

        if ($actualNorm -ne $expectedJson) {
            Write-Host "[FAIL] case '$name' labels mismatch. expected=$expectedJson actual=$actualNorm" -ForegroundColor Red
            $allPass = $false
        } else {
            Write-Host "[PASS] case '$name' labels=$actualNorm" -ForegroundColor Green
        }
    }

    if (-not $allPass) {
        Write-Host "act tests FAILED — see $ResultPath" -ForegroundColor Red
        exit 1
    }
    Write-Host "All act tests PASSED. Output captured to $ResultPath" -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
