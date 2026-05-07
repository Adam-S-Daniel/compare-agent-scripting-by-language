#!/usr/bin/env pwsh
# Test harness: drives every test case through the GitHub Actions workflow via
# `act`. For each case we:
#   1. Create a temp directory, copy project files + the case's fixture
#   2. `git init` and stage everything (act needs a git repo)
#   3. Run `act push --rm` with --env CONFIG_PATH=<fixture>
#   4. Capture all output, append to act-result.txt
#   5. Assert exit code 0, "Job succeeded" present, and exact matrix shape
[CmdletBinding()]
param(
    [string] $ResultPath = (Join-Path (Get-Location) 'act-result.txt'),
    [string[]] $OnlyCases
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$cases = @(
    @{
        Name = 'basic'
        ConfigPath = 'fixtures/basic.json'
        ExpectedIncludeCount = 4
        ExpectedFailFast = $true
        ExpectedMaxParallel = 4
        ExpectedEntries = @(
            @{ os = 'ubuntu-latest';  node = '18' },
            @{ os = 'ubuntu-latest';  node = '20' },
            @{ os = 'windows-latest'; node = '20' },
            @{ os = 'macos-latest';   node = '20'; experimental = $true }
        )
    },
    @{
        Name = 'single-axis'
        ConfigPath = 'fixtures/single-axis.json'
        ExpectedIncludeCount = 3
        ExpectedFailFast = $false
        ExpectedMaxParallel = $null
        ExpectedEntries = @(
            @{ os = 'ubuntu-latest' },
            @{ os = 'macos-latest' },
            @{ os = 'windows-latest' }
        )
    },
    @{
        Name = 'three-axes-with-exclude'
        ConfigPath = 'fixtures/three-axes.json'
        ExpectedIncludeCount = 6
        ExpectedFailFast = $true
        ExpectedMaxParallel = 6
        ExpectedEntries = @(
            @{ os = 'ubuntu-latest';  python = '3.10'; feature = 'a' },
            @{ os = 'ubuntu-latest';  python = '3.10'; feature = 'b' },
            @{ os = 'ubuntu-latest';  python = '3.11'; feature = 'a' },
            @{ os = 'ubuntu-latest';  python = '3.11'; feature = 'b' },
            @{ os = 'windows-latest'; python = '3.10'; feature = 'a' },
            @{ os = 'windows-latest'; python = '3.11'; feature = 'a' }
        )
    }
)

if ($OnlyCases) {
    $cases = $cases | Where-Object { $OnlyCases -contains $_.Name }
}

Set-Content -LiteralPath $ResultPath -Value "" -Encoding UTF8

function New-CaseRepo {
    param([string] $ProjectDir, [string] $CaseName)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "act-matrix-$CaseName-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    $items = @(
        '.actrc',
        '.github',
        'fixtures',
        'MatrixGenerator.psm1',
        'MatrixGenerator.Tests.ps1',
        'Generate-Matrix.ps1'
    )
    foreach ($i in $items) {
        $src = Join-Path $ProjectDir $i
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $tmp -Recurse -Force
        }
    }

    Push-Location $tmp
    try {
        & git init -q -b main 2>&1 | Out-Null
        & git config user.email 'test@example.com' 2>&1 | Out-Null
        & git config user.name 'test' 2>&1 | Out-Null
        & git add . 2>&1 | Out-Null
        & git commit -q -m 'init' 2>&1 | Out-Null
    } finally { Pop-Location }
    return $tmp
}

function Test-MatrixContains {
    param([object[]] $Actual, [hashtable] $Expected)
    foreach ($a in $Actual) {
        $aKeys = @($a.PSObject.Properties.Name | Sort-Object)
        $eKeys = @($Expected.Keys | Sort-Object)
        if ($aKeys.Count -ne $eKeys.Count) { continue }
        $diffKey = $false
        for ($i = 0; $i -lt $aKeys.Count; $i++) { if ($aKeys[$i] -ne $eKeys[$i]) { $diffKey = $true; break } }
        if ($diffKey) { continue }
        $ok = $true
        foreach ($k in $Expected.Keys) {
            if ($a.$k -ne $Expected[$k]) { $ok = $false; break }
        }
        if ($ok) { return $true }
    }
    return $false
}

function Get-MatrixJson {
    param([string] $Output)
    # The workflow prints between MATRIX_JSON_BEGIN / MATRIX_JSON_END. Act
    # prefixes each log line with `[workflow/job] | `. Strip the prefix from
    # all lines between the markers and look for the first valid JSON object.
    $lines = $Output -split "(`r`n|`n)"
    $inside = $false
    $collected = @()
    foreach ($line in $lines) {
        if ($line -match 'MATRIX_JSON_BEGIN') { $inside = $true; continue }
        if ($line -match 'MATRIX_JSON_END') { $inside = $false; continue }
        if ($inside) { $collected += $line }
    }
    foreach ($l in $collected) {
        # Strip act's "[name] | " prefix if present.
        $stripped = $l -replace '^.*?\|\s+', ''
        $stripped = $stripped.Trim()
        if ($stripped.StartsWith('{')) { return $stripped }
    }
    return $null
}

$failed = 0
foreach ($case in $cases) {
    $name = $case.Name
    Write-Host "=== Running act for case: $name ===" -ForegroundColor Cyan

    $caseRepo = New-CaseRepo -ProjectDir $projectDir -CaseName $name

    Add-Content -LiteralPath $ResultPath -Value "================================================================"
    Add-Content -LiteralPath $ResultPath -Value "TEST CASE: $name"
    Add-Content -LiteralPath $ResultPath -Value "Config: $($case.ConfigPath)"
    Add-Content -LiteralPath $ResultPath -Value "Repo: $caseRepo"
    Add-Content -LiteralPath $ResultPath -Value "================================================================"

    Push-Location $caseRepo
    $actExit = 0
    try {
        $output = & act push --rm --pull=false --env "CONFIG_PATH=$($case.ConfigPath)" 2>&1 | Out-String
        $actExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    Add-Content -LiteralPath $ResultPath -Value $output

    Write-Host "act exit code: $actExit"
    if ($actExit -ne 0) {
        Write-Host "FAIL [$name]: act exited with $actExit" -ForegroundColor Red
        Add-Content -LiteralPath $ResultPath -Value "RESULT: FAIL (exit=$actExit)`n"
        $failed++
        continue
    }

    if ($output -notmatch 'Job succeeded') {
        Write-Host "FAIL [$name]: 'Job succeeded' not found" -ForegroundColor Red
        Add-Content -LiteralPath $ResultPath -Value "RESULT: FAIL (no Job succeeded)`n"
        $failed++
        continue
    }

    $jsonText = Get-MatrixJson -Output $output
    if (-not $jsonText) {
        Write-Host "FAIL [$name]: matrix JSON not found" -ForegroundColor Red
        Add-Content -LiteralPath $ResultPath -Value "RESULT: FAIL (no matrix JSON)`n"
        $failed++
        continue
    }

    try {
        $obj = $jsonText | ConvertFrom-Json
    } catch {
        Write-Host "FAIL [$name]: JSON parse error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Raw: $jsonText"
        $failed++
        continue
    }

    $actualCount = @($obj.matrix.include).Count
    if ($actualCount -ne $case.ExpectedIncludeCount) {
        Write-Host "FAIL [$name]: expected $($case.ExpectedIncludeCount) entries, got $actualCount" -ForegroundColor Red
        Add-Content -LiteralPath $ResultPath -Value "RESULT: FAIL (count mismatch)`n"
        $failed++
        continue
    }

    if ($obj.'fail-fast' -ne $case.ExpectedFailFast) {
        Write-Host "FAIL [$name]: expected fail-fast=$($case.ExpectedFailFast), got $($obj.'fail-fast')" -ForegroundColor Red
        $failed++
        continue
    }

    $hasMP = $obj.PSObject.Properties.Name -contains 'max-parallel'
    if ($null -eq $case.ExpectedMaxParallel) {
        if ($hasMP) {
            Write-Host "FAIL [$name]: expected no max-parallel, got $($obj.'max-parallel')" -ForegroundColor Red
            $failed++; continue
        }
    } else {
        if (-not $hasMP -or $obj.'max-parallel' -ne $case.ExpectedMaxParallel) {
            Write-Host "FAIL [$name]: expected max-parallel=$($case.ExpectedMaxParallel), got $($obj.'max-parallel')" -ForegroundColor Red
            $failed++; continue
        }
    }

    $allFound = $true
    foreach ($expected in $case.ExpectedEntries) {
        if (-not (Test-MatrixContains -Actual @($obj.matrix.include) -Expected $expected)) {
            $exJson = $expected | ConvertTo-Json -Compress
            Write-Host "FAIL [$name]: missing expected entry: $exJson" -ForegroundColor Red
            $allFound = $false
        }
    }
    if (-not $allFound) { $failed++; continue }

    Write-Host "PASS [$name]" -ForegroundColor Green
    Add-Content -LiteralPath $ResultPath -Value "RESULT: PASS`n"

    Remove-Item -LiteralPath $caseRepo -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) {
    Write-Host "`n$failed case(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "`nAll $($cases.Count) act cases passed" -ForegroundColor Green
