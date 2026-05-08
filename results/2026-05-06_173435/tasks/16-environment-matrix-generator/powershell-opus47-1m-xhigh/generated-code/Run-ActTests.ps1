<#
.SYNOPSIS
    End-to-end test harness that exercises the GitHub Actions workflow under
    `act` for every fixture in fixtures/.

.DESCRIPTION
    For each test case the harness:
        1. Builds a clean temp git repo containing the project files plus the
           case's fixture renamed to `matrix-config.json` (so the workflow's
           resolver picks it up automatically).
        2. Runs `act push --rm` against that repo.
        3. Captures stdout+stderr to `act-result.txt` (appended, with a clear
           per-case delimiter so failures are easy to read).
        4. Asserts:
             * act exit code matches expectation (0 for valid cases, non-zero
               for the oversized case).
             * Each job line contains 'Job succeeded' for valid cases.
             * The workflow printed the EXACT expected matrix size for valid
               cases (parsed from the `===MATRIX_SIZE===N===` marker).

    The harness fails fast on the first test case that doesn't meet
    expectations and prints a summary at the end.
#>
[CmdletBinding()]
param(
    # Optional: limit to specific case names (comma-separated).
    [string[]]$Only
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResultsFile = Join-Path $ScriptDir 'act-result.txt'

# Wipe the results file at the start so the artifact reflects the current run.
Set-Content -LiteralPath $ResultsFile -Value "act-based test run: $(Get-Date -Format o)`n"

# Project files we need to copy into each test repo. (Anything else under the
# project root is excluded to keep the temp dir minimal and reproducible.)
$ProjectFiles = @(
    'Generate-Matrix.ps1'
    'Generate-Matrix.Tests.ps1'
    '.actrc'
    '.github'
    'fixtures'
)

# Test cases. Each case names a fixture and the exact expected matrix size
# (or, for the oversized case, the failing-step error string we expect to see).
$Cases = @(
    @{ Name = 'basic';         Fixture = 'fixtures/basic.json';         ExpectedSize = 4; ShouldFail = $false }
    @{ Name = 'with-includes'; Fixture = 'fixtures/with-includes.json'; ExpectedSize = 3; ShouldFail = $false }
    @{ Name = 'with-excludes'; Fixture = 'fixtures/with-excludes.json'; ExpectedSize = 7; ShouldFail = $false }
    @{ Name = 'oversized';     Fixture = 'fixtures/oversized.json';     ExpectedSize = $null; ShouldFail = $true; ExpectedErrorPattern = 'Generated matrix size \(36\) exceeds maximum allowed \(5\)' }
)

if ($Only) { $Cases = $Cases | Where-Object { $Only -contains $_.Name } }

function Write-Section {
    param([string]$Header, [string]$Body)
    $banner = '=' * 78
    Add-Content -LiteralPath $ResultsFile -Value "`n$banner"
    Add-Content -LiteralPath $ResultsFile -Value $Header
    Add-Content -LiteralPath $ResultsFile -Value $banner
    Add-Content -LiteralPath $ResultsFile -Value $Body
}

function Invoke-ActCase {
    param([hashtable]$Case)

    Write-Host "==> Running case '$($Case.Name)' (fixture: $($Case.Fixture))" -ForegroundColor Cyan

    # Build a clean temp git repo populated with project files + the chosen
    # fixture as matrix-config.json (the workflow auto-detects it).
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("emg-act-{0}-{1}" -f $Case.Name, [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        foreach ($f in $ProjectFiles) {
            $src = Join-Path $ScriptDir $f
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination $tmp -Recurse -Force
            }
        }
        $fixtureSrc = Join-Path $ScriptDir $Case.Fixture
        Copy-Item -LiteralPath $fixtureSrc -Destination (Join-Path $tmp 'matrix-config.json') -Force

        # `act` expects the directory to be a git repo; otherwise checkout fails.
        Push-Location $tmp
        try {
            git init --quiet --initial-branch=main 2>&1 | Out-Null
            git config user.email 'harness@example.test' | Out-Null
            git config user.name  'harness'              | Out-Null
            git add . | Out-Null
            git commit --quiet -m "harness: prep $($Case.Name)" 2>&1 | Out-Null

            # Run act with --rm so the container is cleaned up regardless. Limit
            # to our workflow file. Use ubuntu-latest mapping that the .actrc
            # already provides.
            $actLog = & act push --rm -W .github/workflows/environment-matrix-generator.yml 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $body = ($actLog | Out-String)
    Write-Section -Header "CASE: $($Case.Name)  (fixture=$($Case.Fixture); expectedSize=$($Case.ExpectedSize); shouldFail=$($Case.ShouldFail); actExit=$exitCode)" -Body $body

    # --- assertions ---------------------------------------------------------
    $failures = New-Object System.Collections.Generic.List[string]

    if ($Case.ShouldFail) {
        if ($exitCode -eq 0) {
            $failures.Add("Expected act to fail (non-zero exit) but it exited 0")
        }
        if ($Case.ExpectedErrorPattern) {
            if ($body -notmatch $Case.ExpectedErrorPattern) {
                $failures.Add("Expected error pattern '$($Case.ExpectedErrorPattern)' not found in act output")
            }
        }
    } else {
        if ($exitCode -ne 0) {
            $failures.Add("Expected act exit 0, got $exitCode")
        }

        # Expect at least one 'Job succeeded' for the unit-tests job AND for
        # the generate-matrix job (act prints one per job). Wrap in @() so
        # zero/one-element results behave like arrays under StrictMode.
        $jobSucceededLines = @(($body -split "`n") | Where-Object { $_ -match 'Job succeeded' })
        if ($jobSucceededLines.Count -lt 2) {
            $failures.Add("Expected >= 2 'Job succeeded' lines, got $($jobSucceededLines.Count)")
        }

        # Pull out and assert exact matrix size.
        $sizeMatch = [regex]::Match($body, '===MATRIX_SIZE===(\d+)===')
        if (-not $sizeMatch.Success) {
            $failures.Add("MATRIX_SIZE marker not found in act output")
        } else {
            $observed = [int]$sizeMatch.Groups[1].Value
            if ($observed -ne $Case.ExpectedSize) {
                $failures.Add("Expected matrix size $($Case.ExpectedSize), observed $observed")
            }
        }
    }

    if ($failures.Count -gt 0) {
        Write-Host "  FAIL: $($Case.Name)" -ForegroundColor Red
        $failures | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        return @{ Case = $Case.Name; Pass = $false; Failures = $failures }
    }

    Write-Host "  PASS: $($Case.Name)" -ForegroundColor Green
    return @{ Case = $Case.Name; Pass = $true; Failures = @() }
}

# --- run all cases sequentially --------------------------------------------
$results = @()
foreach ($case in $Cases) {
    $results += , (Invoke-ActCase -Case $case)
}

# --- summary ---------------------------------------------------------------
$passCount = @($results | Where-Object { $_.Pass }).Count
$failCount = @($results | Where-Object { -not $_.Pass }).Count

Write-Host ""
Write-Host "==================== act test summary ====================" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
$failColor = if ($failCount -gt 0) { 'Red' } else { 'Green' }
Write-Host "Failed: $failCount" -ForegroundColor $failColor
Write-Host "Results captured in: $ResultsFile" -ForegroundColor Cyan

if ($failCount -gt 0) {
    foreach ($r in ($results | Where-Object { -not $_.Pass })) {
        Write-Host "  $($r.Case):" -ForegroundColor Red
        $r.Failures | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
    exit 1
}
exit 0
