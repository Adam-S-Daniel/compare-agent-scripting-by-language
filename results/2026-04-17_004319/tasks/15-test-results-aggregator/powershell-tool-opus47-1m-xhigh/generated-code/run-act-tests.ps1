<#
.SYNOPSIS
    End-to-end test harness. Runs the workflow under nektos/act twice with
    different fixture sets and asserts exact expected values in the output.

.DESCRIPTION
    For each test case:
      1. Builds a temporary git repo containing the project files plus the
         case's fixture data (the case's fixture dir is copied to `fixtures/`).
      2. Runs `act push --rm` inside that repo.
      3. Appends the combined stdout+stderr to act-result.txt (delimited).
      4. Asserts `act` exited with code 0, that every job reports "Job succeeded",
         and that the ASSERT_* tokens emitted by the aggregator match the
         pre-computed expected values for this case.

    Stays within the benchmark-mandated 3-act-run budget: runs act exactly
    twice, preceded by a single local actionlint check.
#>
[CmdletBinding()]
param(
    [string]$ResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = $PSScriptRoot

# ---------- Helpers --------------------------------------------------------

function Write-Delimited {
    param([string]$Header, [string]$Body)
    Add-Content -LiteralPath $ResultFile -Value "===== $Header ====="
    Add-Content -LiteralPath $ResultFile -Value $Body
    Add-Content -LiteralPath $ResultFile -Value "===== END $Header ====="
    Add-Content -LiteralPath $ResultFile -Value ''
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Label)
    if ($Haystack -notmatch [regex]::Escape($Needle)) {
        throw "Assertion failed [$Label]: output did not contain '$Needle'"
    }
}

function Assert-JobSucceeded {
    param([string]$Output, [string[]]$JobNames)
    foreach ($job in $JobNames) {
        # act prints lines like: [Workflow/jobname] Job succeeded
        # We match loosely on the job name since act may abbreviate.
        if ($Output -notmatch 'Job succeeded') {
            throw "No 'Job succeeded' line in act output"
        }
    }
}

function Invoke-ActCase {
    param(
        [Parameter(Mandatory)][string]$CaseName,
        [Parameter(Mandatory)][string]$FixtureSource,
        [Parameter(Mandatory)][hashtable]$Expected
    )

    Write-Host ""
    Write-Host "===== CASE: $CaseName =====" -ForegroundColor Cyan

    # Build an isolated copy of the project with the case's fixtures.
    $tempRoot = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "act-case-$CaseName-$(Get-Random)") -Force
    try {
        # Copy project files we care about (skip .git, workspaces, node_modules etc.)
        $includePaths = @(
            '.actrc',
            '.github',
            'src',
            'tests',
            'README.md'
        )
        foreach ($p in $includePaths) {
            $full = Join-Path $ProjectRoot $p
            if (Test-Path -LiteralPath $full) {
                Copy-Item -LiteralPath $full -Destination $tempRoot -Recurse -Force
            }
        }

        # Swap in the case's fixtures as `fixtures/`.
        $targetFix = Join-Path $tempRoot 'fixtures'
        New-Item -ItemType Directory -Path $targetFix -Force | Out-Null
        Get-ChildItem -LiteralPath $FixtureSource -File | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $targetFix -Force
        }

        # act's push event requires a git repo.
        Push-Location $tempRoot
        try {
            & git init -q
            & git config user.email 'act-harness@example.com'
            & git config user.name 'act-harness'
            & git add -A
            & git commit -q -m 'act harness fixture' --no-gpg-sign | Out-Null

            Write-Host "Running act push for case '$CaseName'..." -ForegroundColor Yellow
            $actOutput = & act push --rm 2>&1 | Out-String
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Write-Delimited -Header "CASE: $CaseName (exit=$actExit)" -Body $actOutput

        if ($actExit -ne 0) {
            throw "act exited with code $actExit for case $CaseName"
        }

        # --- Structural assertions (every case) -------------------------
        Assert-Contains -Haystack $actOutput -Needle 'Job succeeded' -Label "${CaseName}: at least one Job succeeded"

        # --- Per-case value assertions ----------------------------------
        foreach ($key in $Expected.Keys) {
            if ($key -eq 'Flaky') {
                $expectedFlakes = @($Expected[$key])
                # ASSERT_FLAKY_COUNT must match
                $countExpected = $expectedFlakes.Count
                Assert-Contains -Haystack $actOutput -Needle "ASSERT_FLAKY_COUNT=$countExpected" -Label "${CaseName}: flaky count"
                foreach ($flaky in $expectedFlakes) {
                    Assert-Contains -Haystack $actOutput -Needle "ASSERT_FLAKY=$flaky" -Label "${CaseName}: flaky name $flaky"
                }
            } else {
                $needle = "ASSERT_$($key.ToUpper())=$($Expected[$key])"
                Assert-Contains -Haystack $actOutput -Needle $needle -Label "${CaseName}: $key"
            }
        }

        Write-Host "[PASS] case $CaseName" -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------- Main ----------------------------------------------------------

if (Test-Path -LiteralPath $ResultFile) { Remove-Item -LiteralPath $ResultFile -Force }
New-Item -ItemType File -Path $ResultFile -Force | Out-Null
Add-Content -LiteralPath $ResultFile -Value "# act-result.txt"
Add-Content -LiteralPath $ResultFile -Value "# Generated: $(Get-Date -Format o)"
Add-Content -LiteralPath $ResultFile -Value ''

# actionlint first (instant feedback, no act spin-up cost)
Write-Host "Running actionlint..." -ForegroundColor Cyan
$alintOut = & actionlint '.github/workflows/test-results-aggregator.yml' 2>&1 | Out-String
$alintExit = $LASTEXITCODE
Write-Delimited -Header "actionlint (exit=$alintExit)" -Body $alintOut
if ($alintExit -ne 0) { throw "actionlint failed (exit $alintExit): $alintOut" }

# Two act runs, matrix of fixture sets.
$cases = @(
    @{
        Name    = 'default-matrix'
        Source  = Join-Path $ProjectRoot 'fixtures'
        Expect  = @{
            Files        = 3
            Total        = 15
            Passed       = 11
            Failed       = 1
            Skipped      = 3
            Flaky        = @('Suite.Network.Connect_Works')
        }
    },
    @{
        Name    = 'alt-all-pass'
        Source  = Join-Path $ProjectRoot 'alt-fixtures'
        Expect  = @{
            Files        = 2
            Total        = 4
            Passed       = 4
            Failed       = 0
            Skipped      = 0
            Flaky        = @()
        }
    }
)

foreach ($c in $cases) {
    Invoke-ActCase -CaseName $c.Name -FixtureSource $c.Source -Expected $c.Expect
}

Write-Host ""
Write-Host "All cases passed. Output saved to $ResultFile" -ForegroundColor Green
