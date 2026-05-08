#!/usr/bin/env pwsh
<#
.SYNOPSIS
End-to-end test harness: runs the artifact-cleanup-script workflow under
`act` for each fixture, captures output to act-result.txt, and asserts on
exact expected values from each fixture's `expected` block.

This script must be invoked from the project root. It expects:
  * act + Docker installed
  * actionlint installed
  * .actrc pointing at the act-ubuntu-pwsh:latest image (Pester pre-installed)

Usage:
  pwsh -File ./Test-Workflow.ps1

Behavior:
  * Removes any pre-existing act-result.txt
  * For each fixture, runs `act push --rm --env FIXTURE_PATH=<fixture>`
  * Appends the captured output (stdout + stderr) to act-result.txt with a
    clear delimiter
  * Parses the captured output and asserts on `ASSERT key=value` lines
  * Verifies act exited with code 0
  * Verifies "Job succeeded" appears for every job in the run
  * Exits non-zero if any case fails so CI / the agent harness sees red
#>
[CmdletBinding()]
param(
    [switch]$SkipPester
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot       = (Resolve-Path $PSScriptRoot).Path
$ActResultPath  = Join-Path $RepoRoot 'act-result.txt'
# act renders the job's `name:` (display name), not its YAML key, when
# logging. We assert on the display names so the regex actually matches
# against captured act output.
$ExpectedJobNames = @('Pester unit tests', 'Run cleanup script against fixture')

# ------------------------------------------------------------------------
# Pre-flight: structural tests (cheap, run before we burn an act invocation)
# ------------------------------------------------------------------------
if (-not $SkipPester) {
    Write-Host '== Pre-flight: workflow structure tests =='
    $cfg = New-PesterConfiguration
    $cfg.Run.Path = './tests/Workflow.Tests.ps1'
    $cfg.Run.Exit = $true
    $cfg.Output.Verbosity = 'Normal'
    Invoke-Pester -Configuration $cfg
}

# Reset result file at the start of a clean harness run.
if (Test-Path -LiteralPath $ActResultPath) {
    Remove-Item -LiteralPath $ActResultPath -Force
}

# ------------------------------------------------------------------------
# Each test case: one fixture, one act run, one set of assertions.
# Each fixture's `expected` block is the contract the act output must
# satisfy. Cases must be < 4 because the benchmark caps act runs at 3.
# ------------------------------------------------------------------------
$cases = @(
    @{ Name = 'case1-age';                Fixture = 'fixtures/case1-age.json' },
    @{ Name = 'case2-combined';           Fixture = 'fixtures/case2-combined.json' },
    @{ Name = 'case3-keeplatest-dryrun';  Fixture = 'fixtures/case3-keeplatest-dryrun.json' }
)

$failures = New-Object System.Collections.Generic.List[string]

foreach ($case in $cases) {
    $caseName = $case.Name
    $fixture  = $case.Fixture
    Write-Host ""
    Write-Host "==================== ACT RUN: $caseName ===================="
    Write-Host "Fixture: $fixture"

    $expected = (Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json).expected

    # --- Run act --------------------------------------------------------
    # We capture combined stdout+stderr to a per-case temp file so we can
    # both append to act-result.txt AND parse it for assertions.
    $tempLog = New-TemporaryFile
    $actArgs = @(
        'push',
        '--rm',
        '--env', "FIXTURE_PATH=$fixture",
        '--workflows', '.github/workflows/artifact-cleanup-script.yml'
    )
    Write-Host "Running: act $($actArgs -join ' ')"
    & act @actArgs *>&1 | Tee-Object -FilePath $tempLog.FullName | Out-Host
    $actExit = $LASTEXITCODE

    $log = Get-Content -Raw -LiteralPath $tempLog.FullName

    # --- Append to the consolidated result file -------------------------
    $delim = "=" * 78
    $header = @"
$delim
TEST CASE: $caseName
FIXTURE:   $fixture
ACT EXIT:  $actExit
$delim
"@
    Add-Content -LiteralPath $ActResultPath -Value $header
    Add-Content -LiteralPath $ActResultPath -Value $log
    Add-Content -LiteralPath $ActResultPath -Value ""

    Remove-Item -LiteralPath $tempLog.FullName -Force

    # --- Assertions -----------------------------------------------------
    if ($actExit -ne 0) {
        $failures.Add("[$caseName] act exited with code $actExit")
        continue
    }

    # The script emits one ASSERT line per metric; parse them into a hash.
    $actuals = @{}
    foreach ($line in ($log -split "`n")) {
        if ($line -match 'ASSERT\s+(\w+)=(.+)$') {
            $actuals[$Matches[1]] = $Matches[2].Trim()
        }
    }

    foreach ($key in @('deletedCount', 'retainedCount', 'totalReclaimedBytes', 'totalRetainedBytes', 'dryRun', 'mockDeletedActually')) {
        $expectedValRaw = $expected.$key
        if ($null -eq $expectedValRaw) {
            $failures.Add("[$caseName] fixture.expected.$key is missing")
            continue
        }
        # Normalize bool values: PowerShell prints True/False with caps;
        # JSON boolean from PowerShell ConvertFrom-Json is $true/$false.
        $expectedStr = "$expectedValRaw"
        if (-not $actuals.ContainsKey($key)) {
            $failures.Add("[$caseName] missing ASSERT line for '$key' in act output")
            continue
        }
        $actualStr = "$($actuals[$key])"
        if ($actualStr -ne $expectedStr) {
            $failures.Add("[$caseName] $key expected='$expectedStr' actual='$actualStr'")
        } else {
            Write-Host "  ASSERT $key = $actualStr (matches expected)"
        }
    }

    # Verify both jobs reported success — act prints "Job succeeded" or
    # "Job failed" for each job, and decorates each line with the job's
    # display name (the `name:` field).
    foreach ($jobName in $ExpectedJobNames) {
        if ($log -notmatch [regex]::Escape($jobName)) {
            $failures.Add("[$caseName] act output never mentions job '$jobName'")
        }
    }

    $succeededCount = ([regex]::Matches($log, 'Job succeeded')).Count
    if ($succeededCount -lt $ExpectedJobNames.Count) {
        $failures.Add("[$caseName] expected at least $($ExpectedJobNames.Count) 'Job succeeded' lines, found $succeededCount")
    }
    if ($log -match 'Job failed') {
        $failures.Add("[$caseName] act output contains 'Job failed'")
    }
}

# ------------------------------------------------------------------------
# Final report
# ------------------------------------------------------------------------
Write-Host ""
Write-Host "==================== HARNESS SUMMARY ===================="
Write-Host "Result file: $ActResultPath"
if ($failures.Count -gt 0) {
    Write-Host "FAILURES ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host "All cases passed." -ForegroundColor Green
exit 0
