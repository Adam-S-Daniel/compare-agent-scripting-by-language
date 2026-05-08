#requires -Version 7.0
<#
.SYNOPSIS
    End-to-end test harness: runs the workflow under `act` for each fixture
    and asserts on exact expected output values.

.DESCRIPTION
    For each test case:
      1. Build a clean temp directory containing the project files plus the
         fixture's secrets.json + today.txt (pinning "now" so expectations
         stay deterministic).
      2. `git init` and commit so `act push` has something to drive.
      3. Run `act push --rm`, append output to act-result.txt.
      4. Assert exit code 0, both jobs reported "Job succeeded", and the
         workflow's machine-readable SUMMARY/EXPIRED_NAMES lines match
         the known-good values for that case.

    Aborts the whole run on the first failed assertion so we don't waste
    `act push` invocations chasing a regression.

.PARAMETER ResultFile
    Path to the appended act-output log. Default: ./act-result.txt
#>
[CmdletBinding()]
param(
    [string] $ResultFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$FixturesRoot = Join-Path $PSScriptRoot 'fixtures'

# Fresh log file each invocation.
if (Test-Path $ResultFile) { Remove-Item -Force $ResultFile }
New-Item -ItemType File -Path $ResultFile | Out-Null

# Test cases: each pins a "today" so the expected values never drift.
# All expectations were computed by hand against the fixture data.
$cases = @(
    [pscustomobject]@{
        Name              = 'mixed'
        Today             = '2026-05-07'
        ExpectedSummary   = 'SUMMARY total=4 expired=2 warning=1 ok=1'
        ExpectedExpired   = 'EXPIRED_NAMES=ANCIENT_TOKEN,DB_PASSWORD'
        ExpectedWarning   = 'WARNING_NAMES=API_KEY'
        ExpectedOk        = 'OK_NAMES=TLS_CERT'
        ExpectedMarkdown  = @('# Secret Rotation Report', '## Expired (2)', '## Warning (1)', '## OK (1)', 'DB_PASSWORD', 'API_KEY', 'TLS_CERT')
    },
    [pscustomobject]@{
        Name              = 'all-ok'
        Today             = '2026-05-07'
        ExpectedSummary   = 'SUMMARY total=2 expired=0 warning=0 ok=2'
        ExpectedExpired   = 'EXPIRED_NAMES='
        ExpectedWarning   = 'WARNING_NAMES='
        ExpectedOk        = 'OK_NAMES=ROTATED_TODAY,TLS_CERT'
        ExpectedMarkdown  = @('# Secret Rotation Report', '## Expired (0)', '## Warning (0)', '## OK (2)', 'ROTATED_TODAY', 'TLS_CERT')
    },
    [pscustomobject]@{
        Name              = 'empty'
        Today             = '2026-05-07'
        ExpectedSummary   = 'SUMMARY total=0 expired=0 warning=0 ok=0'
        ExpectedExpired   = 'EXPIRED_NAMES='
        ExpectedWarning   = 'WARNING_NAMES='
        ExpectedOk        = 'OK_NAMES='
        ExpectedMarkdown  = @('# Secret Rotation Report', '## Expired (0)', '## Warning (0)', '## OK (0)', '_No secrets in this category._')
    }
)

function Invoke-ActForCase {
    param(
        [Parameter(Mandatory)] [pscustomobject] $Case
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-act-{0}-{1}" -f $Case.Name, [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    try {
        # Copy the project minus the local act log.
        Copy-Item -Path "$RepoRoot/.github" -Destination $tempRoot -Recurse
        Copy-Item -Path "$RepoRoot/src"     -Destination $tempRoot -Recurse
        Copy-Item -Path "$RepoRoot/tests"   -Destination $tempRoot -Recurse
        Copy-Item -Path "$RepoRoot/Invoke-SecretRotationValidator.ps1" -Destination $tempRoot
        Copy-Item -Path "$RepoRoot/.actrc" -Destination $tempRoot -ErrorAction SilentlyContinue

        # Stage the fixture as the active config + pin today.
        Copy-Item -Path (Join-Path $FixturesRoot "$($Case.Name)/secrets.json") -Destination (Join-Path $tempRoot 'secrets.json')
        Set-Content -LiteralPath (Join-Path $tempRoot 'today.txt') -Value $Case.Today

        # act push needs a git repo with a commit on the default branch.
        Push-Location $tempRoot
        try {
            git init -q -b main 2>&1 | Out-Null
            git -c user.email='harness@example.com' -c user.name='harness' add -A 2>&1 | Out-Null
            git -c user.email='harness@example.com' -c user.name='harness' commit -q -m "fixture $($Case.Name)" 2>&1 | Out-Null

            Write-Host "==> Running act for case '$($Case.Name)'..." -ForegroundColor Cyan
            # Capture both streams. act exits non-zero on workflow failure.
            # --pull=false: the act container image is built locally; don't try
            # to pull it from a registry where it doesn't exist.
            $output = & act push --rm --pull=false --workflows .github/workflows/secret-rotation-validator.yml 2>&1 | Out-String
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
        }
    } finally {
        # Tidy up temp repo
        if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
    }

    return [pscustomobject]@{ Output = $output; ExitCode = $code }
}

function Append-Section {
    param([string] $Title, [string] $Body)
    $delim = ('=' * 80)
    Add-Content -LiteralPath $ResultFile -Value $delim
    Add-Content -LiteralPath $ResultFile -Value "=== $Title ==="
    Add-Content -LiteralPath $ResultFile -Value $delim
    Add-Content -LiteralPath $ResultFile -Value $Body
}

function Assert-Contains {
    param(
        [string] $Haystack, [string] $Needle, [string] $Case, [string] $Label
    )
    if ($Haystack -notmatch [regex]::Escape($Needle)) {
        throw "[$Case] Assertion failed: expected output to contain '$Needle' ($Label)."
    }
    Write-Host "  PASS  [$Case] $Label : '$Needle'" -ForegroundColor Green
}

function Test-WorkflowStructure {
    Write-Host "==> Validating workflow structure..." -ForegroundColor Cyan

    $wf = Join-Path $RepoRoot '.github/workflows/secret-rotation-validator.yml'
    if (-not (Test-Path $wf)) { throw "Workflow file missing: $wf" }

    # actionlint must be clean.
    $alOut = & actionlint $wf 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "actionlint failed:`n$alOut"
    }
    Write-Host "  PASS  actionlint clean" -ForegroundColor Green

    $raw = Get-Content -Raw $wf

    # Trigger sanity checks (name-only, no full YAML parser dependency).
    foreach ($trigger in 'push:', 'pull_request:', 'schedule:', 'workflow_dispatch:') {
        if ($raw -notmatch [regex]::Escape($trigger)) {
            throw "Workflow missing expected trigger '$trigger'"
        }
    }
    Write-Host "  PASS  all expected triggers present" -ForegroundColor Green

    # Required jobs/steps.
    foreach ($needle in 'jobs:', 'test:', 'validate:', 'actions/checkout@v4', 'shell: pwsh', 'Invoke-Pester', './Invoke-SecretRotationValidator.ps1') {
        if ($raw -notmatch [regex]::Escape($needle)) {
            throw "Workflow missing expected token '$needle'"
        }
    }
    Write-Host "  PASS  all expected workflow tokens present" -ForegroundColor Green

    # Script files referenced by the workflow must exist.
    foreach ($f in 'Invoke-SecretRotationValidator.ps1', 'src/SecretRotationValidator.psm1', 'tests/SecretRotationValidator.Tests.ps1') {
        if (-not (Test-Path (Join-Path $RepoRoot $f))) {
            throw "Workflow references missing file: $f"
        }
    }
    Write-Host "  PASS  all referenced script files exist" -ForegroundColor Green
}

# ---------------- Run ----------------

Test-WorkflowStructure

$failures = @()
foreach ($case in $cases) {
    try {
        $result = Invoke-ActForCase -Case $case
    } catch {
        $failures += "[$($case.Name)] harness error: $($_.Exception.Message)"
        Append-Section "case $($case.Name) - HARNESS ERROR" $_.Exception.Message
        continue
    }

    Append-Section "case $($case.Name) (exit=$($result.ExitCode))" $result.Output

    try {
        if ($result.ExitCode -ne 0) {
            throw "act exited with code $($result.ExitCode)"
        }
        Write-Host "  PASS  [$($case.Name)] act exit=0" -ForegroundColor Green

        # Two jobs in the workflow -> two "Job succeeded" lines minimum.
        $jobSuccessCount = ([regex]::Matches($result.Output, 'Job succeeded')).Count
        if ($jobSuccessCount -lt 2) {
            throw "Expected >= 2 'Job succeeded' lines, saw $jobSuccessCount"
        }
        Write-Host "  PASS  [$($case.Name)] both jobs succeeded ($jobSuccessCount)" -ForegroundColor Green

        Assert-Contains -Haystack $result.Output -Needle $case.ExpectedSummary -Case $case.Name -Label 'summary'
        Assert-Contains -Haystack $result.Output -Needle $case.ExpectedExpired -Case $case.Name -Label 'expired-names'
        Assert-Contains -Haystack $result.Output -Needle $case.ExpectedWarning -Case $case.Name -Label 'warning-names'
        Assert-Contains -Haystack $result.Output -Needle $case.ExpectedOk      -Case $case.Name -Label 'ok-names'
        foreach ($needle in $case.ExpectedMarkdown) {
            Assert-Contains -Haystack $result.Output -Needle $needle -Case $case.Name -Label "markdown:$needle"
        }
    } catch {
        $failures += "[$($case.Name)] $($_.Exception.Message)"
        Write-Host "  FAIL  [$($case.Name)] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Summary
Write-Host ''
Write-Host '======================================================================'
if ($failures.Count -eq 0) {
    Write-Host "All $($cases.Count) act-driven test cases passed." -ForegroundColor Green
    Write-Host "act-result.txt: $ResultFile"
    exit 0
} else {
    Write-Host "$($failures.Count) failure(s):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "act-result.txt: $ResultFile"
    exit 1
}
