#!/usr/bin/env pwsh
# Test harness: runs the workflow under `act`, then parses the combined output
# and asserts exact expected values per fixture. All fixture test cases execute
# through a single `act push` run to respect the 3-run budget.

[CmdletBinding()]
param(
    [switch]$SkipAct,
    [string]$ResultFile = 'act-result.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
$ResultPath = Join-Path $RepoRoot $ResultFile

if (-not $SkipAct -and (Test-Path $ResultPath)) { Remove-Item $ResultPath -Force }

function Write-Result {
    param([string]$Text)
    Add-Content -Path $ResultPath -Value $Text
}

# Expected per-fixture outcomes. Each entry has concrete assertions so the
# harness validates EXACT values, not just the presence of output.
$expectations = @(
    @{
        Name           = 'basic'
        Status         = 'OK'
        ExpectedCount  = 4
        MustContain    = @('"os": "ubuntu-latest"', '"version": "20"', '"os": "macos-latest"')
        MustNotContain = @()
        ExtraChecks    = @()
    },
    @{
        Name           = 'with-exclude'
        Status         = 'OK'
        ExpectedCount  = 3
        MustContain    = @('"os": "ubuntu-latest"', '"os": "macos-latest"')
        MustNotContain = @()
        ExtraChecks    = @(
            @{
                Name = 'no macos-latest + 18 combination'
                Test = {
                    param($parsed)
                    @($parsed.matrix.include | Where-Object { $_.os -eq 'macos-latest' -and $_.version -eq '18' }).Count -eq 0
                }
            }
        )
    },
    @{
        Name           = 'with-include'
        Status         = 'OK'
        ExpectedCount  = 2
        MustContain    = @('"os": "windows-latest"', '"experimental": true')
        MustNotContain = @()
        ExtraChecks    = @()
    },
    @{
        Name           = 'full-featured'
        Status         = 'OK'
        ExpectedCount  = 6
        MustContain    = @('"max-parallel": 3', '"fail-fast": false', '"features": "experimental"')
        MustNotContain = @()
        ExtraChecks    = @(
            @{
                Name = 'has experimental include for windows'
                Test = {
                    param($parsed)
                    @($parsed.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.features -eq 'experimental' }).Count -eq 1
                }
            },
            @{
                Name = 'macos + 18 excluded'
                Test = {
                    param($parsed)
                    @($parsed.matrix.include | Where-Object { $_.os -eq 'macos-latest' -and $_.version -eq '18' }).Count -eq 0
                }
            }
        )
    },
    @{
        Name           = 'oversized'
        Status         = 'FAILED'
        ExpectedError  = 'Matrix size (12) exceeds maximum allowed size (5)'
    }
)

# ---- Step 1: run act (unless -SkipAct, for dry-run diagnostics) ----
if (-not $SkipAct) {
    Push-Location $RepoRoot
    try {
        # act determines the event payload from the git worktree. We need all
        # fixtures and workflow files committed for act to see them.
        git add -A 2>&1 | Out-Null
        # Allow-empty keeps this idempotent on second invocation.
        git -c user.email=harness@local -c user.name=harness commit -m 'harness snapshot' --allow-empty 2>&1 | Out-Null

        Write-Host "Running act push --rm --pull=false ..."
        # --pull=false is required because our .actrc points at a locally-built
        # custom image (act-ubuntu-pwsh) that does not exist on Docker Hub.
        $actOutput = & act push --rm --pull=false 2>&1 | Out-String
        $actExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    Write-Result "=== ACT PUSH RUN ==="
    Write-Result $actOutput
    Write-Result "=== ACT EXIT CODE: $actExit ==="

    if ($actExit -ne 0) {
        Write-Host "act FAILED with exit code $actExit" -ForegroundColor Red
        Write-Host $actOutput
        throw "act exited with code $actExit"
    }
    Write-Host "act exited 0"
} else {
    Write-Host "SkipAct=true; reading $ResultPath for parsing"
    if (-not (Test-Path $ResultPath)) { throw "Cannot skip act: $ResultPath does not exist" }
    $actOutput = Get-Content -Path $ResultPath -Raw
}

# ---- Step 2: assert "Job succeeded" appears for every job ----
$jobSucceededMatches = [regex]::Matches($actOutput, 'Job succeeded')
Write-Result "=== JOB SUCCEEDED COUNT: $($jobSucceededMatches.Count) ==="
if ($jobSucceededMatches.Count -lt 2) {
    throw "Expected at least 2 'Job succeeded' messages (unit-tests + generate-matrix), got $($jobSucceededMatches.Count)"
}
Write-Host "Found $($jobSucceededMatches.Count) 'Job succeeded' messages"

# ---- Step 3: parse per-fixture blocks and assert expected values ----
$failures = [System.Collections.ArrayList]::new()
$passed = 0

foreach ($exp in $expectations) {
    $name = $exp.Name
    $blockRegex = "===FIXTURE:${name}:START===(?<body>.*?)===FIXTURE:${name}:END==="
    $m = [regex]::Match($actOutput, $blockRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) {
        [void]$failures.Add("[$name] fixture block not found in act output")
        continue
    }
    $body = $m.Groups['body'].Value

    # Check status line
    $expectedStatus = $exp.Status
    if ($body -notmatch "===STATUS:$expectedStatus===") {
        [void]$failures.Add("[$name] expected ===STATUS:$expectedStatus=== in block; body head: $($body.Substring(0, [Math]::Min(200, $body.Length)))")
        continue
    }

    if ($expectedStatus -eq 'FAILED') {
        # Error-path fixture: assert the exact error message appears.
        if ($body -notmatch [regex]::Escape($exp.ExpectedError)) {
            [void]$failures.Add("[$name] expected error '$($exp.ExpectedError)' not found in block")
            continue
        }
        Write-Host "[PASS] $name (error path: $($exp.ExpectedError))"
        $passed++
        continue
    }

    # Success-path fixture: extract and parse JSON.
    $jsonMatch = [regex]::Match($body, '===JSON:START===\s*(?<json>.*?)\s*===JSON:END===', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $jsonMatch.Success) {
        [void]$failures.Add("[$name] JSON block not found")
        continue
    }
    $jsonText = $jsonMatch.Groups['json'].Value.Trim()

    # act prefixes each captured line with "[<job-name>]   | ". Strip that so the
    # remainder parses as plain JSON.
    $jsonText = ($jsonText -split "`n" | ForEach-Object {
        ($_ -replace '^\[[^\]]+\]\s*\|\s?', '' -replace '^\s*\|\s?', '').TrimEnd()
    }) -join "`n"

    try {
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
    } catch {
        [void]$failures.Add("[$name] could not parse JSON: $($_.Exception.Message)")
        continue
    }

    if ($parsed.count -ne $exp.ExpectedCount) {
        [void]$failures.Add("[$name] expected count=$($exp.ExpectedCount), got $($parsed.count)")
        continue
    }

    $localOk = $true
    foreach ($needle in $exp.MustContain) {
        if ($jsonText -notmatch [regex]::Escape($needle)) {
            [void]$failures.Add("[$name] missing required substring: $needle")
            $localOk = $false
        }
    }
    foreach ($needle in $exp.MustNotContain) {
        if ($jsonText -match [regex]::Escape($needle)) {
            [void]$failures.Add("[$name] forbidden substring present: $needle")
            $localOk = $false
        }
    }
    foreach ($check in $exp.ExtraChecks) {
        $ok = & $check.Test $parsed
        if (-not $ok) {
            [void]$failures.Add("[$name] extra check failed: $($check.Name)")
            $localOk = $false
        }
    }
    if ($localOk) {
        Write-Host "[PASS] $name (count=$($parsed.count))"
        $passed++
    }
}

Write-Result "=== ASSERTIONS: passed=$passed, failed=$($failures.Count) ==="
if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f"; Write-Result "  - $f" }
    throw "$($failures.Count) assertion(s) failed"
}

Write-Host ""
Write-Host "All $passed act test cases passed" -ForegroundColor Green
