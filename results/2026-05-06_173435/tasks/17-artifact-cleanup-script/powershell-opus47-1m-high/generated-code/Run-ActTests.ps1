<#
.SYNOPSIS
    End-to-end test harness: runs the workflow under `act` once per fixture
    case in an isolated temp git repo, captures output, and asserts the
    planner produced exactly the known-good values for each case's input.

.DESCRIPTION
    For each case under fixtures-cases/, the harness:
      1. Materializes a temp git repo containing only the project files plus
         that case's fixture data (copied to fixtures-cases/<chosen> and
         pinned via the FIXTURE_CASE env var passed to act).
      2. Runs `act push --rm` with the project's .actrc-selected pwsh image.
      3. Appends stdout+stderr (and exit code) to act-result.txt with a
         delimiter that identifies the case.
      4. Asserts: exit code 0, every job ends with "Job succeeded", Pester
         reports the expected pass count, and the planner output contains
         the exact reclaimed-bytes / deleted-count / retained-count values
         for that case.

.NOTES
    Per the task brief: testing must go through the workflow, not directly
    against the script. So this harness is the canonical test entry point.
#>

[CmdletBinding()]
param(
    [string] $OutputFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
# Reset the result file at the start of each harness run so consumers see
# only this run's output.
Set-Content -LiteralPath $OutputFile -Value ''

# Each case is paired with the exact assertions we expect from its fixture.
# These are the "known good" results - hand-computed when the fixtures were
# authored and locked in here so a regression in the planner trips a test.
$cases = @(
    @{
        Name             = 'case-max-age'
        Description      = 'Max-age policy: deletes only the one stale artifact (>30d).'
        ExpectedReclaim  = 400
        ExpectedDeleted  = 1
        ExpectedRetained = 2
        ExpectedTotal    = 3
        ExpectedDryRun   = $false
        ExpectedReasons  = @('max-age: 1')
        ForbiddenReasons = @('keep-latest-n', 'max-total-size')
    }
    @{
        Name             = 'case-keep-n'
        Description      = 'Keep-latest-N-per-workflow=2 with two workflows.'
        ExpectedReclaim  = 200
        ExpectedDeleted  = 2
        ExpectedRetained = 4
        ExpectedTotal    = 6
        ExpectedDryRun   = $false
        ExpectedReasons  = @('keep-latest-n: 2')
        ForbiddenReasons = @('max-age', 'max-total-size')
    }
    @{
        Name             = 'case-combined'
        Description      = 'All three policies + dry-run: max-age, keep-N, max-total-size.'
        ExpectedReclaim  = 1299
        ExpectedDeleted  = 4
        ExpectedRetained = 2
        ExpectedTotal    = 6
        ExpectedDryRun   = $true
        ExpectedReasons  = @('max-age: 1', 'keep-latest-n: 2', 'max-total-size: 1')
        ForbiddenReasons = @()
    }
)

function Append-Result {
    param([string] $Text)
    Add-Content -LiteralPath $OutputFile -Value $Text
}

function New-TempRepo {
    param([Parameter(Mandatory)] [string] $CaseName)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("acleanup-act-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy only the project files act needs (script, tests, workflow, fixtures, .actrc).
    Copy-Item -Path (Join-Path $projectRoot 'Invoke-ArtifactCleanup.ps1')       -Destination $tmp
    Copy-Item -Path (Join-Path $projectRoot 'Invoke-ArtifactCleanup.Tests.ps1') -Destination $tmp
    Copy-Item -Path (Join-Path $projectRoot '.actrc')                           -Destination $tmp -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $projectRoot '.github')                          -Destination $tmp -Recurse
    Copy-Item -Path (Join-Path $projectRoot 'fixtures-cases')                   -Destination $tmp -Recurse

    # act expects a git repo so it can find the worktree root.
    Push-Location $tmp
    try {
        git init -q | Out-Null
        git config user.email 'harness@example.com' | Out-Null
        git config user.name  'harness'             | Out-Null
        git add . | Out-Null
        git -c commit.gpgsign=false commit -q -m "fixture: $CaseName" | Out-Null
    } finally {
        Pop-Location
    }
    return $tmp
}

$failures = @()

# ----- Workflow structure tests (pre-flight, host-side) ---------------------
# These verify the YAML is structurally correct and references real files
# before we spend ~30s/case on act. actionlint is the source of truth for
# YAML/Action validity; we layer custom checks on top of it.
Append-Result '=============== WORKFLOW STRUCTURE TESTS ==============='

$workflowPath = Join-Path $projectRoot '.github/workflows/artifact-cleanup-script.yml'
if (-not (Test-Path $workflowPath)) {
    $failures += "structure: workflow file missing at $workflowPath"
}

# 1. actionlint must pass (exit code 0).
$alOutput = & actionlint $workflowPath 2>&1 | Out-String
$alExit = $LASTEXITCODE
Append-Result "actionlint exit: $alExit"
if ($alOutput.Trim()) { Append-Result $alOutput }
if ($alExit -ne 0) { $failures += "structure: actionlint exit $alExit" }

# 2. YAML must parse and contain the expected top-level shape.
# We treat the YAML as text since pwsh has no built-in YAML parser - that's
# fine because we only need to assert presence of expected keys.
$workflowText = Get-Content -LiteralPath $workflowPath -Raw

foreach ($needed in 'on:', 'push:', 'pull_request:', 'schedule:', 'workflow_dispatch:',
                    'permissions:', 'jobs:', 'unit-tests:', 'end-to-end:',
                    'actions/checkout@v4', 'shell: pwsh', 'Invoke-ArtifactCleanup.ps1',
                    'Invoke-ArtifactCleanup.Tests.ps1', 'fixtures-cases',
                    'ARTIFACT_CLEANUP_NOW') {
    if ($workflowText -notmatch [regex]::Escape($needed)) {
        $failures += "structure: workflow missing expected token '$needed'"
    }
}

# 3. Every script path the workflow references must exist on disk.
$referencedFiles = @(
    'Invoke-ArtifactCleanup.ps1',
    'Invoke-ArtifactCleanup.Tests.ps1'
)
foreach ($f in $referencedFiles) {
    $p = Join-Path $projectRoot $f
    if (-not (Test-Path $p)) {
        $failures += "structure: referenced file missing on disk: $f"
    }
}

Append-Result "structure pre-flight failures so far: $($failures.Count)"
Append-Result ''

foreach ($case in $cases) {
    $name = $case.Name
    $banner = "=================================================================="
    $hdr    = "===== CASE: $name ($($case.Description)) ====="
    Append-Result $banner
    Append-Result $hdr
    Append-Result $banner
    Write-Host $hdr -ForegroundColor Cyan

    $repo = New-TempRepo -CaseName $name
    try {
        Push-Location $repo
        try {
            # Pass the fixture case via env so the workflow picks it up.
            # `act push --rm` triggers the push event using the .actrc image
            # mapping. -q quiets a bit of noise but still leaves all step
            # output intact.
            # --pull=false: the act-ubuntu-pwsh image is built locally and
            # is not on Docker Hub, so a force-pull would fail.
            $actOutput = & act push --rm --pull=false `
                --env "FIXTURE_CASE=$name" `
                --env 'ARTIFACT_CLEANUP_NOW=2026-05-07T12:00:00Z' 2>&1 | Out-String
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Append-Result $actOutput
        Append-Result "----- act exit code: $actExit -----"

        # Strip ANSI escape codes before regex assertions; Pester output
        # under act includes color codes that split apart literal phrases
        # like "11, Failed: 0".
        $clean = [regex]::Replace($actOutput, "\x1B\[[0-9;]*[A-Za-z]", '')

        # Assertion 1: exit code 0
        if ($actExit -ne 0) {
            $failures += "$name`: act exit code was $actExit (expected 0)"
            continue
        }

        # Assertion 2: every job succeeded.
        # act prints "Job succeeded" once per job at the end.
        $jobSucceededCount = ([regex]::Matches($clean, 'Job succeeded')).Count
        if ($jobSucceededCount -lt 2) {
            $failures += "$name`: expected 2 'Job succeeded' lines (unit-tests + end-to-end), got $jobSucceededCount"
        }

        # Assertion 3: Pester ran cleanly. Output line ends with the count.
        if ($clean -notmatch 'Tests Passed: 11,\s*Failed: 0') {
            $failures += "$name`: Pester pass-count line not found or wrong"
        }

        # Assertion 4: planner produced the exact expected values.
        if ($clean -notmatch "Total artifacts:\s*$($case.ExpectedTotal)\b") {
            $failures += "$name`: expected 'Total artifacts: $($case.ExpectedTotal)'"
        }
        if ($clean -notmatch "Retained:\s*$($case.ExpectedRetained)\b") {
            $failures += "$name`: expected 'Retained: $($case.ExpectedRetained)'"
        }
        if ($clean -notmatch "Deleted:\s*$($case.ExpectedDeleted)\b") {
            $failures += "$name`: expected 'Deleted: $($case.ExpectedDeleted)'"
        }
        if ($clean -notmatch "Reclaimed:\s*$($case.ExpectedReclaim) bytes") {
            $failures += "$name`: expected 'Reclaimed: $($case.ExpectedReclaim) bytes'"
        }
        if ($case.ExpectedDryRun) {
            if ($clean -notmatch 'DRY-RUN') {
                $failures += "$name`: expected DRY-RUN tag in summary"
            }
        }
        foreach ($reason in $case.ExpectedReasons) {
            $escaped = [regex]::Escape($reason)
            if ($clean -notmatch $escaped) {
                $failures += "$name`: expected reason line '$reason'"
            }
        }
        foreach ($forbidden in $case.ForbiddenReasons) {
            if ($clean -match "(?m)^\s*${forbidden}:\s*\d") {
                $failures += "$name`: unexpected reason '$forbidden' appeared"
            }
        }
    } finally {
        if (Test-Path $repo) { Remove-Item -Recurse -Force $repo }
    }
}

Append-Result ''
Append-Result '=============== HARNESS SUMMARY ==============='
if ($failures.Count -eq 0) {
    Append-Result "All $($cases.Count) cases PASSED"
    Write-Host "`nAll $($cases.Count) cases PASSED" -ForegroundColor Green
    exit 0
} else {
    Append-Result "FAILURES ($($failures.Count)):"
    foreach ($f in $failures) { Append-Result "  - $f" }
    Write-Host "`nFAILURES ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
