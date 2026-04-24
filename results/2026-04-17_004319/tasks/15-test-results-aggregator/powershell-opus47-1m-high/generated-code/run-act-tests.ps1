<#
.SYNOPSIS
End-to-end test harness: run the GitHub Actions workflow under `act` for
each fixture scenario and assert on the exact expected output values.

.DESCRIPTION
Per the benchmark rules: all tests must run through the GitHub Actions
pipeline via `act`. This harness:

  1. Builds the expected-value table per scenario.
  2. For each scenario, creates a temp directory that IS a git repo and
     contains the full project + just that scenario's fixtures under
     tests/fixtures/default (so the workflow's default FIXTURE_DIR
     resolves to exactly those files).
  3. Runs `act push --rm` inside the temp repo, captures all output,
     appends it to act-result.txt in the current working directory
     with clear delimiters.
  4. Asserts:
       * act exit code is 0
       * both jobs show "Job succeeded"
       * actionlint passed at workflow level (enforced separately at top)
       * stdout contains the exact TOTALS line and FLAKY lines for that case.

Running cost: `act` takes ~30-90s per run, so we cap scenarios at 3 to stay
within the "at most 3 act push runs" budget.
#>
[CmdletBinding()]
param(
    [switch]$NoRebuild
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$actResult = Join-Path $here 'act-result.txt'
Remove-Item -Force -ErrorAction SilentlyContinue $actResult

function Write-Delim([string]$title) {
    $bar = '=' * 78
    Add-Content -LiteralPath $actResult -Value @(
        ''
        $bar
        "=== $title"
        $bar
        ''
    )
}

# Scenario definitions. FixtureSource points to the fixture subdir in
# tests/fixtures/; it becomes the *only* content of tests/fixtures/default
# in the temp repo so the workflow's FIXTURE_DIR default matches.
$scenarios = @(
    [pscustomobject]@{
        Name           = 'default'
        FixtureSource  = 'tests/fixtures/default'
        ExpectTotals   = 'TOTALS: TotalTests=8 Passed=4 Failed=3 Skipped=1 Flaky=1 Runs=3'
        ExpectFlaky    = @(
            'FLAKY: UnitTests.Auth::test_logout statuses=[failed|passed] runs=2'
        )
    },
    [pscustomobject]@{
        Name           = 'all-passing'
        FixtureSource  = 'tests/fixtures/all-passing'
        ExpectTotals   = 'TOTALS: TotalTests=2 Passed=2 Failed=0 Skipped=0 Flaky=0 Runs=1'
        ExpectFlaky    = @()
    },
    [pscustomobject]@{
        Name           = 'multi-flaky'
        FixtureSource  = 'tests/fixtures/multi-flaky'
        ExpectTotals   = 'TOTALS: TotalTests=12 Passed=6 Failed=6 Skipped=0 Flaky=2 Runs=3'
        ExpectFlaky    = @(
            'FLAKY: E2E::testA statuses=[failed|passed] runs=3',
            'FLAKY: E2E::testB statuses=[failed|passed] runs=3'
        )
    }
)

# Project files to copy into each temp repo. Keep the list explicit so we
# don't accidentally leak act-result.txt or node_modules-like debris.
$projectItems = @(
    '.actrc',
    'aggregate.ps1',
    'src',
    'tests/TestResultsAggregator.Tests.ps1',
    '.github'
)

$failures = [System.Collections.Generic.List[string]]::new()

# -------------------------------------------------------------------------
# Workflow structure tests (required). Run before any `act` invocations
# so structural problems fail fast without waiting 30-90s per act run.
# -------------------------------------------------------------------------
Write-Host "======== Workflow structure tests ========"
$workflowPath = Join-Path $here '.github/workflows/test-results-aggregator.yml'
Write-Delim 'Workflow structure tests'

# Structure test 1: actionlint passes
$alOut = & actionlint $workflowPath 2>&1
$alExit = $LASTEXITCODE
Add-Content -LiteralPath $actResult -Value "actionlint exit: $alExit"
Add-Content -LiteralPath $actResult -Value ($alOut -join "`n")
if ($alExit -ne 0) {
    $failures.Add("[structure] actionlint exited $alExit (expected 0)")
} else {
    Write-Host "  [+] actionlint: OK"
}

# Structure test 2: workflow YAML parses and has expected shape.
# PowerShell 7 ships ConvertFrom-Yaml only via the powershell-yaml module;
# fall back to a simple regex/text parse to keep the harness dependency-free.
$wf = Get-Content -LiteralPath $workflowPath -Raw

# Triggers present
foreach ($trig in 'push:', 'pull_request:', 'workflow_dispatch:', 'schedule:') {
    if ($wf -notmatch [regex]::Escape($trig)) {
        $failures.Add("[structure] workflow missing trigger: $trig")
    }
}
if ($failures.Count -eq 0) { Write-Host "  [+] triggers present (push/pull_request/workflow_dispatch/schedule)" }

# Jobs present
foreach ($job in 'unit-tests:', 'aggregate:') {
    if ($wf -notmatch [regex]::Escape($job)) {
        $failures.Add("[structure] workflow missing job: $job")
    }
}

# Referenced paths actually exist
foreach ($ref in @(
    @{ Pattern = '-Path tests';                 File = 'tests' },
    @{ Pattern = './aggregate.ps1';             File = 'aggregate.ps1' },
    @{ Pattern = 'src/TestResultsAggregator.psm1'; File = 'src/TestResultsAggregator.psm1' }
)) {
    $matched = $false
    switch ($ref.Pattern) {
        '-Path tests'                      { $matched = $wf -match 'Invoke-Pester\s+-Path\s+tests' }
        './aggregate.ps1'                  { $matched = $wf -match [regex]::Escape('./aggregate.ps1') }
        'src/TestResultsAggregator.psm1'   { $matched = $true }  # referenced indirectly via aggregate.ps1
    }
    if (-not (Test-Path -LiteralPath (Join-Path $here $ref.File))) {
        $failures.Add("[structure] referenced path missing on disk: $($ref.File)")
    }
}
Write-Host "  [+] referenced script paths exist"

# Uses actions/checkout@v4 (containerization requirement)
if ($wf -notmatch 'actions/checkout@v4') {
    $failures.Add("[structure] workflow must use actions/checkout@v4")
} else {
    Write-Host "  [+] uses actions/checkout@v4"
}

# Uses shell: pwsh (per the pwsh-mode instruction)
if ($wf -notmatch 'shell:\s*pwsh') {
    $failures.Add("[structure] workflow must set 'shell: pwsh' on run: steps")
} else {
    Write-Host "  [+] uses shell: pwsh"
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Structure tests failed -- skipping act runs."
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}

foreach ($s in $scenarios) {
    Write-Host ""
    Write-Host "======== Scenario: $($s.Name) ========"
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-tra-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Write-Host "Temp repo: $tmp"

    try {
        # Copy project items into temp repo, preserving structure.
        foreach ($item in $projectItems) {
            $src = Join-Path $here $item
            if (-not (Test-Path -LiteralPath $src)) {
                throw "Missing project item: $src"
            }
            $dst = Join-Path $tmp $item
            New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
            $srcItem = Get-Item -LiteralPath $src -Force
            if ($srcItem.PSIsContainer) {
                Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
            } else {
                Copy-Item -LiteralPath $src -Destination $dst -Force
            }
        }

        # Copy the ENTIRE tests/fixtures tree so the Pester unit tests
        # (which reference default/, all-passing/, and multi-flaky/) keep
        # working regardless of scenario.
        $fixturesDst = Join-Path $tmp 'tests/fixtures'
        New-Item -ItemType Directory -Path $fixturesDst -Force | Out-Null
        Copy-Item -Path (Join-Path $here 'tests/fixtures/*') -Destination $fixturesDst -Recurse -Force

        # Point the aggregate step at the scenario-specific subdir by
        # rewriting the workflow's FIXTURE_DIR default.
        $wfFile = Join-Path $tmp '.github/workflows/test-results-aggregator.yml'
        $wfText = Get-Content -LiteralPath $wfFile -Raw
        $wfText = $wfText -replace "'tests/fixtures/default'", "'$($s.FixtureSource)'"
        Set-Content -LiteralPath $wfFile -Value $wfText -Encoding utf8

        # Initialize as git repo -- act checks HEAD when simulating `push`.
        Push-Location $tmp
        try {
            git init -q -b main 2>&1 | Out-Null
            git -c user.name=test -c user.email=test@example.com add -A 2>&1 | Out-Null
            git -c user.name=test -c user.email=test@example.com commit -q -m "harness: $($s.Name)" 2>&1 | Out-Null

            Write-Delim "Scenario: $($s.Name)  (fixtures=$($s.FixtureSource))"
            Add-Content -LiteralPath $actResult -Value "Temp repo: $tmp`n"

            # Run act. --rm cleans containers; 2>&1 so we capture stderr too.
            $out = & act push --rm 2>&1
            $exit = $LASTEXITCODE

            Add-Content -LiteralPath $actResult -Value $out
            Add-Content -LiteralPath $actResult -Value ""
            Add-Content -LiteralPath $actResult -Value "act exit code: $exit"
            Write-Host "act exit: $exit"

            $joined = ($out -join "`n")

            # ---- Assertion 1: act exited 0 ----
            if ($exit -ne 0) {
                $failures.Add("[$($s.Name)] act exit code was $exit (expected 0)")
            }

            # ---- Assertion 2: both jobs reported "Job succeeded" ----
            $succeededCount = ([regex]::Matches($joined, 'Job succeeded')).Count
            if ($succeededCount -lt 2) {
                $failures.Add("[$($s.Name)] expected 'Job succeeded' at least 2 times (one per job), got $succeededCount")
            }

            # ---- Assertion 3: exact TOTALS line present ----
            if ($joined -notmatch [regex]::Escape($s.ExpectTotals)) {
                $failures.Add("[$($s.Name)] missing exact totals line: '$($s.ExpectTotals)'")
            }

            # ---- Assertion 4: each expected FLAKY line present, none extra ----
            foreach ($expected in $s.ExpectFlaky) {
                if ($joined -notmatch [regex]::Escape($expected)) {
                    $failures.Add("[$($s.Name)] missing expected flaky line: '$expected'")
                }
            }
            $flakyEmitted = [regex]::Matches($joined, '^\|\s*FLAKY:.*$', 'Multiline').Count
            # Also count the generic count via TOTALS Flaky=N:
            if ($joined -match 'TOTALS:.*Flaky=(\d+)') {
                $n = [int]$Matches[1]
                if ($n -ne $s.ExpectFlaky.Count) {
                    $failures.Add("[$($s.Name)] TOTALS Flaky=$n but expected $($s.ExpectFlaky.Count)")
                }
            }

            # ---- Assertion 5: Pester inside the workflow passed ----
            if ($joined -notmatch 'Pester: \d+ test\(s\) passed') {
                $failures.Add("[$($s.Name)] Pester success line not found in workflow output")
            }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
    }
}

Write-Host ""
Write-Host "======== Harness summary ========"
if ($failures.Count -eq 0) {
    Write-Host "PASS: all $($scenarios.Count) scenarios asserted successfully."
    Write-Host "Output captured in: $actResult"
    exit 0
} else {
    Write-Host "FAIL: $($failures.Count) assertion failure(s):"
    foreach ($f in $failures) { Write-Host "  - $f" }
    Write-Host "Output captured in: $actResult"
    exit 1
}
