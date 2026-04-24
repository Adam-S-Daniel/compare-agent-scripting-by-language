<#
.SYNOPSIS
    Runs the GitHub Actions workflow through `act` for each of the defined
    test cases, captures the output, and asserts on EXACT expected values.

.DESCRIPTION
    For each test case:
      1. Creates a temp directory and copies the project files into it.
      2. Replaces the fixtures/ directory with the case-specific fixtures
         so the same workflow produces different outputs per case.
      3. Initialises a fresh git repo (act reads HEAD and the working tree).
      4. Runs `act push --rm` and captures stdout+stderr.
      5. Appends the output to act-result.txt in this directory.
      6. Asserts:
           - act exit code == 0
           - every job has "Job succeeded"
           - AGG_RESULT tokens contain the exact expected counts
           - PESTER_RESULT shows the expected pass count

    We deliberately keep to at most 3 `act push` runs (per the task constraint).

    act-result.txt is the required artifact.
#>

[CmdletBinding()]
param(
    [string] $ActResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

# Strict mode is intentionally NOT enabled in the harness: we call the `act`
# CLI as an external process and capture mixed native/PowerShell streams,
# which interacts badly with StrictMode's "property doesn't exist" rule.
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot

# ------------------------------------------------------------------
# Project files that must be copied into every per-case temp repo.
# We copy only what's needed to run the workflow - no .git/, no act
# result files, no per-case fixture folders (those are handled below).
# ------------------------------------------------------------------
$projectFiles = @(
    'TestResultsAggregator.ps1'
    'TestResultsAggregator.Tests.ps1'
    'WorkflowStructure.Tests.ps1'
    'Invoke-Aggregator.ps1'
    '.actrc'
)
# fixtures/ is required for Pester; input/ is the case-specific aggregator input.
$projectDirs = @('.github', 'fixtures')

# ------------------------------------------------------------------
# Test cases. Each case has:
#   Name           - human-readable identifier
#   FixturesSource - directory in this repo whose contents replace fixtures/
#   Expected       - exact totals we expect the aggregator to print
#   ExpectedFlaky  - exact flaky count
#   ExpectedPester - exact Pester passed count
# ------------------------------------------------------------------
$cases = @(
    [pscustomobject]@{
        Name           = 'default-matrix-with-flaky'
        InputSource    = 'input'
        Expected       = @{ total = 11; passed = 7; failed = 2; skipped = 2 }
        ExpectedFlaky  = 1
        ExpectedPester = 22
    }
    [pscustomobject]@{
        Name           = 'single-run-no-flaky'
        InputSource    = 'input-single'
        Expected       = @{ total = 4; passed = 2; failed = 1; skipped = 1 }
        ExpectedFlaky  = 0
        ExpectedPester = 22
    }
    [pscustomobject]@{
        Name           = 'all-pass-no-failures'
        InputSource    = 'input-allpass'
        Expected       = @{ total = 5; passed = 5; failed = 0; skipped = 0 }
        ExpectedFlaky  = 0
        ExpectedPester = 22
    }
)

# Wipe any prior output: act-result.txt is a single fresh artifact per run.
if (Test-Path -LiteralPath $ActResultFile) { Remove-Item -LiteralPath $ActResultFile -Force }
New-Item -ItemType File -Path $ActResultFile -Force | Out-Null

function Copy-ProjectIntoTemp {
    param([string]$TempRepo, [string]$InputDir)

    New-Item -ItemType Directory -Path $TempRepo -Force | Out-Null
    foreach ($f in $projectFiles) {
        Copy-Item -LiteralPath (Join-Path $root $f) -Destination (Join-Path $TempRepo $f) -Force
    }
    foreach ($d in $projectDirs) {
        Copy-Item -LiteralPath (Join-Path $root $d) -Destination $TempRepo -Recurse -Force
    }

    # Copy the case's input content into input/ (creating the folder fresh).
    # This is what the 'aggregate' job consumes; fixtures/ is left alone so the
    # Pester tests keep working.
    $inPath = Join-Path $TempRepo 'input'
    if (Test-Path $inPath) { Remove-Item $inPath -Recurse -Force }
    New-Item -ItemType Directory -Path $inPath -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $root $InputDir) -File |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $inPath -Force }
}

function Initialize-GitRepo {
    param([string]$TempRepo)
    Push-Location $TempRepo
    try {
        & git init -q --initial-branch=main
        & git config user.email 'act-harness@example.com'
        & git config user.name  'act-harness'
        & git add -A
        & git commit -q -m 'harness commit' | Out-Null
    } finally {
        Pop-Location
    }
}

function Invoke-ActForCase {
    param([pscustomobject]$Case)

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("act-case-" + [Guid]::NewGuid().ToString('N'))
    try {
        Copy-ProjectIntoTemp -TempRepo $tmp -InputDir $Case.InputSource
        Initialize-GitRepo -TempRepo $tmp

        $header = "===== CASE: $($Case.Name) =====`n" +
                  "Temp repo: $tmp`n" +
                  "Input source: $($Case.InputSource)`n" +
                  "Expected: total=$($Case.Expected.total) passed=$($Case.Expected.passed) failed=$($Case.Expected.failed) skipped=$($Case.Expected.skipped) flaky=$($Case.ExpectedFlaky)`n" +
                  "---"
        Add-Content -LiteralPath $ActResultFile -Value $header

        Push-Location $tmp
        try {
            # `act push --rm` triggers the push-event path in the workflow; --rm
            # disposes of the container after the run. We merge stderr into stdout
            # so the single file captures everything act reports.
            $actOutput = & act push --rm 2>&1 | Out-String
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Add-Content -LiteralPath $ActResultFile -Value $actOutput
        Add-Content -LiteralPath $ActResultFile -Value "---- act exit: $actExit"
        Add-Content -LiteralPath $ActResultFile -Value ""

        return [pscustomobject]@{
            Case     = $Case
            Output   = $actOutput
            ExitCode = $actExit
            TempRepo = $tmp
        }
    } finally {
        # Clean the temp repo only if the run succeeded; on failure we leave it
        # behind so the human can inspect.
    }
}

function Assert-CaseOutcome {
    param([pscustomobject]$Run)

    $c = $Run.Case
    $out = $Run.Output
    $errors = New-Object System.Collections.Generic.List[string]

    if ($Run.ExitCode -ne 0) {
        $errors.Add("act exited with $($Run.ExitCode) (expected 0)")
    }

    # Each job in the workflow should report "Job succeeded". We expect the
    # pester-unit-tests job and the aggregate job, so at least two occurrences.
    $succeeded = ([regex]::Matches($out, 'Job succeeded')).Count
    if ($succeeded -lt 2) {
        $errors.Add("Expected at least 2 'Job succeeded' occurrences, got $succeeded")
    }

    # Exact aggregator totals. These values are computed by the script at
    # runtime and printed verbatim, so a mismatch means the aggregator is wrong
    # OR the fixtures changed.
    $expectedAgg = "AGG_RESULT total=$($c.Expected.total) passed=$($c.Expected.passed) failed=$($c.Expected.failed) skipped=$($c.Expected.skipped) flaky=$($c.ExpectedFlaky)"
    if ($out -notmatch [regex]::Escape($expectedAgg)) {
        $errors.Add("Missing exact token: '$expectedAgg'")
    }

    # Pester job should report the expected number of passing tests.
    $expectedPester = "PESTER_RESULT passed=$($c.ExpectedPester) failed=0"
    if ($out -notmatch [regex]::Escape($expectedPester)) {
        $errors.Add("Missing exact token: '$expectedPester'")
    }

    return $errors
}

# ------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------
$allErrors = @{}
$runs = foreach ($case in $cases) {
    Write-Host ""
    Write-Host "=== Running case: $($case.Name) ===" -ForegroundColor Cyan
    $run = Invoke-ActForCase -Case $case
    $errs = Assert-CaseOutcome -Run $run
    if ($errs.Count -gt 0) { $allErrors[$case.Name] = $errs }
    Write-Host "  act exit: $($run.ExitCode), assertion errors: $($errs.Count)"
    $run
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($allErrors.Count -eq 0) {
    Write-Host "All $($cases.Count) act cases passed" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Failures:" -ForegroundColor Red
    foreach ($k in $allErrors.Keys) {
        Write-Host "  [$k]" -ForegroundColor Red
        foreach ($e in $allErrors[$k]) { Write-Host "    - $e" -ForegroundColor Red }
    }
    exit 1
}
