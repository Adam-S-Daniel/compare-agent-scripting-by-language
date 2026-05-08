<#
.SYNOPSIS
    Test harness that runs the workflow under `act` for each fixture and asserts
    on exact expected output. Also tests workflow structure and actionlint.

    Per task spec:
      - Each test case sets up a temp git repo, writes the fixture as config.json,
        runs `act push --rm`, captures output into act-result.txt (delimited).
      - Asserts act exit code 0, every job shows "Job succeeded", and the matrix
        JSON in the output matches exactly the expected JSON for that fixture.
      - Limited to <=3 act runs.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

# --- Workflow structure tests (no act needed) ---------------------------------

Write-Host "==> Structure tests"
$wfPath = Join-Path $here '.github/workflows/environment-matrix-generator.yml'
if (-not (Test-Path $wfPath)) { throw "Workflow file missing: $wfPath" }

# actionlint must pass cleanly. Exit code 0 is the assertion.
$actionlint = & actionlint $wfPath 2>&1
if ($LASTEXITCODE -ne 0) { throw "actionlint failed: $actionlint" }
Write-Host "  actionlint: OK"

# Parse the YAML and verify expected triggers, jobs, and step references.
# We do a lightweight string-based parse to avoid a YAML module dependency.
$wfText = Get-Content $wfPath -Raw
foreach ($needle in @('on:', 'push:', 'pull_request:', 'workflow_dispatch:', 'schedule:',
                      'jobs:', 'test:', 'generate:',
                      'actions/checkout@v4',
                      'New-EnvironmentMatrix.ps1',
                      'EnvironmentMatrix.Tests.ps1',
                      'shell: pwsh')) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected token: $needle"
    }
}
# Verify referenced files exist.
foreach ($f in @('New-EnvironmentMatrix.ps1', 'EnvironmentMatrix.Tests.ps1')) {
    if (-not (Test-Path (Join-Path $here $f))) { throw "Referenced file missing: $f" }
}
Write-Host "  workflow structure: OK"

# --- Fixtures -----------------------------------------------------------------

# Each fixture has: name, config (written as config.json), and expected substrings
# we will assert appear *exactly* in the matrix JSON output.
$fixtures = @(
    @{
        name = 'simple-2x2'
        config = @{
            axes = [ordered] @{
                os   = @('ubuntu-latest','windows-latest')
                node = @('18','20')
            }
        }
        expectExact = '{"matrix":{"include":[{"os":"ubuntu-latest","node":"18"},{"os":"ubuntu-latest","node":"20"},{"os":"windows-latest","node":"18"},{"os":"windows-latest","node":"20"}]}}'
    },
    @{
        name = 'exclude-and-include'
        config = @{
            axes = [ordered] @{
                os   = @('ubuntu-latest','windows-latest')
                node = @('18','20')
            }
            exclude     = @( @{ os = 'windows-latest'; node = '18' } )
            include     = @( [ordered] @{ os = 'macos-latest'; node = '20'; experimental = $true } )
            'fail-fast'    = $false
            'max-parallel' = 2
        }
        expectExact = '{"matrix":{"include":[{"os":"ubuntu-latest","node":"18"},{"os":"ubuntu-latest","node":"20"},{"os":"windows-latest","node":"20"},{"os":"macos-latest","node":"20","experimental":true}]},"fail-fast":false,"max-parallel":2}'
    },
    @{
        name = 'feature-flags'
        config = @{
            axes = [ordered] @{
                os      = @('ubuntu-latest')
                feature = @('on','off')
            }
            'fail-fast' = $true
        }
        expectExact = '{"matrix":{"include":[{"os":"ubuntu-latest","feature":"on"},{"os":"ubuntu-latest","feature":"off"}]},"fail-fast":true}'
    }
)

# --- Run act once per fixture, in an isolated temp git repo ------------------

$resultsPath = Join-Path $here 'act-result.txt'
if (Test-Path $resultsPath) { Remove-Item $resultsPath }

$failures = @()
foreach ($fx in $fixtures) {
    Write-Host ""
    Write-Host "==> act run: $($fx.name)"

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-emg-" + $fx.name + "-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy project files into the temp repo (tracked files only).
    foreach ($f in @('New-EnvironmentMatrix.ps1','EnvironmentMatrix.Tests.ps1','.actrc')) {
        Copy-Item (Join-Path $here $f) (Join-Path $tmp $f)
    }
    New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force | Out-Null
    Copy-Item $wfPath (Join-Path $tmp '.github/workflows/environment-matrix-generator.yml')

    # Write the fixture as config.json.
    $cfgJson = $fx.config | ConvertTo-Json -Depth 10
    Set-Content -Path (Join-Path $tmp 'config.json') -Value $cfgJson -Encoding utf8

    # Initialise a git repo (act expects one).
    Push-Location $tmp
    try {
        git init -q
        git config user.email 'a@b.c'
        git config user.name  'test'
        git add -A
        git commit -q -m "fixture $($fx.name)"

        # --pull=false: image is preloaded locally; otherwise act force-pulls and fails offline.
        $output = & act push --rm --pull=false 2>&1 | Out-String
        $exit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    # Append delimited output to the cumulative results file.
    Add-Content -Path $resultsPath -Value "===== BEGIN CASE: $($fx.name) (exit=$exit) ====="
    Add-Content -Path $resultsPath -Value $output
    Add-Content -Path $resultsPath -Value "===== END CASE: $($fx.name) ====="
    Add-Content -Path $resultsPath -Value ""

    # --- Assertions per case --------------------------------------------------
    $caseFailures = @()
    if ($exit -ne 0) { $caseFailures += "act exited with $exit" }

    # Every job should show "Job succeeded" — count must match number of jobs (2).
    $succeededCount = ([regex]::Matches($output, 'Job succeeded')).Count
    if ($succeededCount -lt 2) {
        $caseFailures += "expected at least 2 'Job succeeded' lines, found $succeededCount"
    }

    # Extract matrix JSON between markers (line-based to tolerate act prefixes).
    $lines = $output -split "`r?`n"
    $beginIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'MATRIX_BEGIN') { $beginIdx = $i; break }
    }
    if ($beginIdx -lt 0 -or $beginIdx + 1 -ge $lines.Count) {
        $caseFailures += "MATRIX_BEGIN marker not found in output"
    } else {
        # Strip act's "[Workflow/job/step]   | " prefix from the JSON line.
        $jsonLine = ($lines[$beginIdx + 1] -replace '^[^|]*\|\s*','').Trim()
        if ($jsonLine -ne $fx.expectExact) {
            $caseFailures += "matrix JSON mismatch.`n  expected: $($fx.expectExact)`n  actual:   $jsonLine"
        }
    }

    if ($caseFailures.Count -gt 0) {
        $failures += "[$($fx.name)] " + ($caseFailures -join '; ')
        Write-Host "  FAIL: $($caseFailures -join '; ')" -ForegroundColor Red
    } else {
        Write-Host "  PASS"
    }

    Remove-Item -Recurse -Force $tmp
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "FAILED:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All act test cases passed. See $resultsPath" -ForegroundColor Green
