#!/usr/bin/env pwsh
<#
.SYNOPSIS
    End-to-end test harness that exercises the dependency-license-checker
    workflow via `act` for a set of fixture test cases, then asserts on
    the exact JSON produced for each case.

.DESCRIPTION
    Per benchmark rules:
      * Workflow-structure tests run locally (YAML parsing, path checks,
        actionlint).
      * For each act test case the harness copies the project into a
        temp dir, swaps in the case's manifest fixture, `git init`s,
        runs `act push --rm`, and appends the full log to
        ./act-result.txt.
      * Every case asserts: act exit 0, "Job succeeded" appears twice
        (one per job), the --- LICENSE-REPORT --- block parses as JSON
        and matches the expected values exactly.

    Run:
        pwsh ./test-harness.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipAct
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProjectRoot = $PSScriptRoot
$script:ResultFile  = Join-Path $ProjectRoot 'act-result.txt'
$script:Failures    = [System.Collections.Generic.List[string]]::new()

# --- tiny assertion helpers -------------------------------------------------

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ($Expected -is [bool] -or $Actual -is [bool]) {
        if ([bool]$Expected -ne [bool]$Actual) {
            $script:Failures.Add("[$Label] expected '$Expected' but got '$Actual'")
            Write-Host "  FAIL [$Label] expected '$Expected' got '$Actual'" -ForegroundColor Red
            return
        }
    }
    elseif ($Expected -ne $Actual) {
        $script:Failures.Add("[$Label] expected '$Expected' but got '$Actual'")
        Write-Host "  FAIL [$Label] expected '$Expected' got '$Actual'" -ForegroundColor Red
        return
    }
    Write-Host "  OK   [$Label] = $Actual" -ForegroundColor Green
}

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if (-not $Condition) {
        $script:Failures.Add("[$Label] condition was false")
        Write-Host "  FAIL [$Label]" -ForegroundColor Red
    } else {
        Write-Host "  OK   [$Label]" -ForegroundColor Green
    }
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Label)
    if (-not $Haystack.Contains($Needle)) {
        $script:Failures.Add("[$Label] missing substring '$Needle'")
        Write-Host "  FAIL [$Label] missing '$Needle'" -ForegroundColor Red
    } else {
        Write-Host "  OK   [$Label] contains '$Needle'" -ForegroundColor Green
    }
}

# --- Section 1: Workflow structure tests ------------------------------------

function Invoke-StructureTests {
    Write-Host ""
    Write-Host "=== Workflow structure tests ===" -ForegroundColor Cyan

    $wfPath = Join-Path $ProjectRoot '.github' 'workflows' 'dependency-license-checker.yml'
    Assert-True (Test-Path $wfPath) 'workflow file exists'

    # actionlint exit 0
    $alOut = & actionlint $wfPath 2>&1
    $alExit = $LASTEXITCODE
    if ($alExit -ne 0) { Write-Host $alOut }
    Assert-Equal 0 $alExit 'actionlint exit code'

    # YAML structure: parse via python3 (pyyaml ships with the image).
    # Note: YAML 1.1 translates "on:" to boolean True, so we round-trip
    # through a small python helper that normalises the top-level keys
    # to strings before dumping to JSON. That way the PowerShell side
    # always sees string keys.
    $yaml = Get-Content -LiteralPath $wfPath -Raw
    $pyCheck = Get-Command python3 -ErrorAction SilentlyContinue
    if ($pyCheck) {
        $normaliser = @'
import sys, yaml, json
data = yaml.safe_load(sys.stdin.read())
def fix(o):
    if isinstance(o, dict):
        return {("on" if k is True else ("off" if k is False else str(k))): fix(v) for k, v in o.items()}
    if isinstance(o, list):
        return [fix(x) for x in o]
    return o
print(json.dumps(fix(data)))
'@
        $parsed = $yaml | & python3 -c $normaliser
        $doc = $parsed | ConvertFrom-Json
        Assert-Equal 'dependency-license-checker' $doc.name 'workflow name'

        $triggers = $doc.on
        $triggerNames = $triggers.PSObject.Properties.Name
        Assert-True ($triggerNames -contains 'push')              'push trigger present'
        Assert-True ($triggerNames -contains 'pull_request')      'pull_request trigger present'
        Assert-True ($triggerNames -contains 'workflow_dispatch') 'workflow_dispatch trigger present'
        Assert-True ($triggerNames -contains 'schedule')          'schedule trigger present'

        $jobNames = $doc.jobs.PSObject.Properties.Name
        Assert-True ($jobNames -contains 'test')  'test job defined'
        Assert-True ($jobNames -contains 'check') 'check job defined'
        Assert-Equal 'test' $doc.jobs.check.needs 'check job depends on test'

        # Confirm the check job actually invokes our entry script.
        $runSteps = $doc.jobs.check.steps | Where-Object { $_.PSObject.Properties.Name -contains 'run' }
        $combined = ($runSteps.run -join "`n")
        Assert-Contains $combined 'Invoke-LicenseCheck.ps1' 'check job invokes Invoke-LicenseCheck.ps1'
    } else {
        Assert-Contains $yaml 'workflow_dispatch' 'workflow_dispatch trigger (regex)'
        Assert-Contains $yaml 'pull_request'      'pull_request trigger (regex)'
    }

    # Script/file references in the workflow must actually exist on disk.
    foreach ($p in @('Invoke-LicenseCheck.ps1',
                     'src/LicenseChecker.psm1',
                     'tests/LicenseChecker.Tests.ps1',
                     'config/policy.json',
                     'config/mock-licenses.json',
                     'fixtures/package.json')) {
        Assert-True (Test-Path (Join-Path $ProjectRoot $p)) "file exists: $p"
    }
}

# --- Section 2: act test cases ----------------------------------------------

$script:TestCases = @(
    @{
        Name           = 'compliant-all-mit'
        Description    = 'three MIT deps, all on allow-list, report is compliant=true'
        Manifest       = @{
            name         = 'compliant-app'
            version      = '1.0.0'
            dependencies = [ordered]@{
                lodash  = '4.17.21'
                express = '4.18.0'
                chalk   = '5.3.0'
            }
        }
        Expected = @{
            compliant = $true
            total     = 3
            approved  = 3
            denied    = 0
            unknown   = 0
            deps      = @{
                lodash  = @{ license = 'MIT'; status = 'approved' }
                express = @{ license = 'MIT'; status = 'approved' }
                chalk   = @{ license = 'MIT'; status = 'approved' }
            }
        }
    },
    @{
        Name        = 'non-compliant-mixed'
        Description = 'MIT approved + GPL denied + missing-from-db unknown'
        Manifest    = @{
            name         = 'mixed-app'
            version      = '2.0.0'
            dependencies = [ordered]@{
                lodash         = '4.17.21'
                'copyleft-x'   = '1.2.3'
                'mystery-dep'  = '0.0.1'
            }
        }
        Expected = @{
            compliant = $false
            total     = 3
            approved  = 1
            denied    = 1
            unknown   = 1
            deps      = @{
                lodash        = @{ license = 'MIT';     status = 'approved' }
                'copyleft-x'  = @{ license = 'GPL-3.0'; status = 'denied' }
                'mystery-dep' = @{ license = 'unknown'; status = 'unknown' }
            }
        }
    }
)

function New-TestWorkspace {
    param(
        [Parameter(Mandatory)] [string]$CaseName,
        [Parameter(Mandatory)] [hashtable]$Manifest
    )
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("license-check-$CaseName-" + [guid]::NewGuid().Guid.Substring(0, 8))
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    # Copy project files (skip git, temp, and the act-result.txt itself).
    $skipPatterns = @('.git', '.claude', 'act-result.txt', '*.tmp', 'benchmark-instructions-*.md')
    Get-ChildItem -Path $ProjectRoot -Force | Where-Object {
        $item = $_
        -not ($skipPatterns | Where-Object { $item.Name -like $_ })
    } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $work -Recurse -Force
    }

    # Swap in the case's manifest fixture.
    $manifestPath = Join-Path $work 'fixtures' 'package.json'
    $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath

    # act requires a git repo.
    Push-Location $work
    try {
        git init -q
        git config user.email 'harness@example.com'
        git config user.name  'harness'
        git add -A
        git commit -q -m "fixture: $CaseName"
    } finally {
        Pop-Location
    }
    return $work
}

function Invoke-ActCase {
    param(
        [Parameter(Mandatory)] [hashtable]$Case
    )
    Write-Host ""
    Write-Host "=== act test case: $($Case.Name) ===" -ForegroundColor Cyan
    Write-Host "   $($Case.Description)"

    $workspace = New-TestWorkspace -CaseName $Case.Name -Manifest $Case.Manifest
    $logFile = Join-Path ([System.IO.Path]::GetTempPath()) "act-$($Case.Name).log"

    Push-Location $workspace
    try {
        # --rm removes the container after the run. -P pin is set via .actrc.
        # --pull=false prevents act from trying to pull our locally-built
        # custom image (act-ubuntu-pwsh) from a registry it doesn't exist in.
        $null = & act push --rm --pull=false 2>&1 | Tee-Object -FilePath $logFile
        $actExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $log = Get-Content -LiteralPath $logFile -Raw

    # Append to act-result.txt with a header delimiter.
    $delim = "=" * 80
    $header = @"
$delim
# Test case: $($Case.Name)
# Description: $($Case.Description)
# act exit code: $actExit
$delim
"@
    Add-Content -LiteralPath $script:ResultFile -Value $header
    Add-Content -LiteralPath $script:ResultFile -Value $log
    Add-Content -LiteralPath $script:ResultFile -Value ""

    # --- assertions ---
    Assert-Equal 0 $actExit "act exit code for $($Case.Name)"

    # Each job should print a "Job succeeded" line. There are two jobs (test,
    # check) so we expect exactly two occurrences.
    $succeededCount = ([regex]::Matches($log, '(?m)Job succeeded')).Count
    Assert-True ($succeededCount -ge 2) "Job succeeded appears at least twice (got $succeededCount)"

    # Extract JSON from --- LICENSE-REPORT-BEGIN/END --- markers.
    $beginMarker = '--- LICENSE-REPORT-BEGIN ---'
    $endMarker   = '--- LICENSE-REPORT-END ---'
    $bi = $log.IndexOf($beginMarker)
    $ei = $log.IndexOf($endMarker)
    Assert-True (($bi -ge 0) -and ($ei -gt $bi)) 'LICENSE-REPORT markers present in log'

    if ($bi -ge 0 -and $ei -gt $bi) {
        $raw = $log.Substring($bi + $beginMarker.Length, $ei - $bi - $beginMarker.Length)
        # Strip act's "[dependency-license-checker/...]" and "|" prefixes per line.
        $cleaned = ($raw -split "`n" | ForEach-Object {
            ($_ -replace '^\s*\[[^\]]+\]\s*\|\s?', '').TrimEnd()
        }) -join "`n"

        try {
            $report = $cleaned | ConvertFrom-Json
            Assert-Equal $Case.Expected.compliant $report.compliant "$($Case.Name): compliant"
            Assert-Equal $Case.Expected.total    $report.summary.total    "$($Case.Name): summary.total"
            Assert-Equal $Case.Expected.approved $report.summary.approved "$($Case.Name): summary.approved"
            Assert-Equal $Case.Expected.denied   $report.summary.denied   "$($Case.Name): summary.denied"
            Assert-Equal $Case.Expected.unknown  $report.summary.unknown  "$($Case.Name): summary.unknown"

            foreach ($depName in $Case.Expected.deps.Keys) {
                $expected = $Case.Expected.deps[$depName]
                $actual = $report.dependencies | Where-Object Name -eq $depName
                Assert-True ($null -ne $actual) "$($Case.Name): dep '$depName' present"
                if ($null -ne $actual) {
                    Assert-Equal $expected.license $actual.license "$($Case.Name): $depName.license"
                    Assert-Equal $expected.status  $actual.status  "$($Case.Name): $depName.status"
                }
            }
        } catch {
            $script:Failures.Add("[$($Case.Name)] failed to parse report JSON: $_")
            Write-Host "  FAIL [$($Case.Name)] JSON parse: $_" -ForegroundColor Red
            Write-Host "--- cleaned ---"
            Write-Host $cleaned
        }

        # Also assert on the concise SUMMARY line the script emits.
        $summaryRegex = "SUMMARY total=$($Case.Expected.total) approved=$($Case.Expected.approved) denied=$($Case.Expected.denied) unknown=$($Case.Expected.unknown) compliant=$($Case.Expected.compliant)"
        Assert-Contains $log $summaryRegex "$($Case.Name): SUMMARY line"
    }

    # Clean up the workspace to avoid disk bloat on repeated runs.
    Remove-Item -Recurse -Force -Path $workspace -ErrorAction SilentlyContinue
}

# --- main -------------------------------------------------------------------

# Reset the result file.
Set-Content -LiteralPath $ResultFile -Value "# dependency-license-checker act-result log`n" -Encoding UTF8

Invoke-StructureTests

if (-not $SkipAct) {
    foreach ($tc in $script:TestCases) {
        Invoke-ActCase -Case $tc
    }
} else {
    Write-Host "(act tests skipped via -SkipAct)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($script:Failures.Count -eq 0) {
    Write-Host "All harness assertions passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$($script:Failures.Count) failure(s):" -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
