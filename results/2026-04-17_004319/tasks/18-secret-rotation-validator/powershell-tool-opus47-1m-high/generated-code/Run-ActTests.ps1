#!/usr/bin/env pwsh
# Act-based integration test harness.
#
# For each test case:
#   1. Create a temp git repo, copy project files + the case's fixture data.
#   2. Run `act push --rm` inside that repo.
#   3. Append the output to act-result.txt (clearly delimited).
#   4. Assert act exit code is 0.
#   5. Parse the output and assert EXACT expected values for that input.
#   6. Assert every job shows "Job succeeded".
#
# Also runs structural checks (YAML shape, actionlint, referenced paths exist)
# before firing act, because those diagnose issues in milliseconds vs. 30-90s
# per act run.
[CmdletBinding()]
param(
    [string] $RepoRoot = $PSScriptRoot,
    [string] $ResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:Failures = @()
function Add-Failure([string]$Message) {
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $script:Failures += $Message
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { Add-Failure $Message } else { Write-Host "PASS: $Message" -ForegroundColor Green }
}

# ---------------------------------------------------------------------------
# Phase 1: structural checks (fast, run first)
# ---------------------------------------------------------------------------
Write-Host "`n=== Phase 1: structural checks ===" -ForegroundColor Cyan

$workflowPath = Join-Path $RepoRoot '.github/workflows/secret-rotation-validator.yml'
Assert-True (Test-Path $workflowPath) "workflow file exists at $workflowPath"

# actionlint must pass cleanly — identical precondition to CI.
$actionlintOut = & actionlint $workflowPath 2>&1
$actionlintExit = $LASTEXITCODE
Assert-True ($actionlintExit -eq 0) "actionlint exits 0 (stdout=$actionlintOut)"

# Parse the YAML via ConvertFrom-Yaml if available, otherwise a minimal hand-roll.
# Pester 5 doesn't ship YAML support; we lean on a regex sanity pass instead of
# bringing in a third-party module, since structure here is simple.
$workflowText = Get-Content -LiteralPath $workflowPath -Raw
Assert-True ($workflowText -match '(?m)^on:')        "workflow has 'on:' trigger block"
Assert-True ($workflowText -match 'push:')           "workflow has push trigger"
Assert-True ($workflowText -match 'pull_request:')   "workflow has pull_request trigger"
Assert-True ($workflowText -match 'schedule:')       "workflow has schedule trigger"
Assert-True ($workflowText -match 'workflow_dispatch:') "workflow has workflow_dispatch trigger"
Assert-True ($workflowText -match '(?m)^\s*test:')     "workflow defines 'test' job"
Assert-True ($workflowText -match '(?m)^\s*validate:') "workflow defines 'validate' job"
Assert-True ($workflowText -match 'actions/checkout@v4') "workflow uses actions/checkout@v4"
Assert-True ($workflowText -match 'SecretRotationValidator\.Tests\.ps1') "workflow references Pester test file"
Assert-True ($workflowText -match 'Invoke-Validator\.ps1') "workflow references entry-point script"

# Referenced script paths must actually exist.
Assert-True (Test-Path (Join-Path $RepoRoot 'SecretRotationValidator.psm1')) "module file exists"
Assert-True (Test-Path (Join-Path $RepoRoot 'SecretRotationValidator.Tests.ps1')) "test file exists"
Assert-True (Test-Path (Join-Path $RepoRoot 'Invoke-Validator.ps1')) "entry-point file exists"
Assert-True (Test-Path (Join-Path $RepoRoot 'fixtures/default.json')) "default fixture exists"

# ---------------------------------------------------------------------------
# Phase 2: act runs per test case
# ---------------------------------------------------------------------------
Write-Host "`n=== Phase 2: act integration runs ===" -ForegroundColor Cyan

# Test case definitions. Each case has:
#   Name         — label for log output
#   Fixture      — JSON payload written to fixtures/default.json in the temp repo
#   Expected     — substrings we require in the act output (EXACT summary line)
#   MustNotMatch — substrings we require absent (e.g., error markers)
$cases = @(
    @{
        Name     = 'default-mixed'
        Fixture  = @(
            [ordered]@{ name = 'ok-secret';      lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('api') }
            [ordered]@{ name = 'warning-secret'; lastRotated = '2026-01-25'; rotationPolicyDays = 90; requiredBy = @('gateway') }
            [ordered]@{ name = 'expired-secret'; lastRotated = '2025-12-01'; rotationPolicyDays = 90; requiredBy = @('api','worker') }
        )
        Expected = @(
            'SUMMARY total=3 expired=1 warning=1 ok=1 exit=2'
            '| expired-secret | 2025-12-01 | 90 |'
        )
    }
    @{
        Name     = 'all-ok'
        Fixture  = @(
            [ordered]@{ name = 'fresh-a'; lastRotated = '2026-04-18'; rotationPolicyDays = 90; requiredBy = @('a') }
            [ordered]@{ name = 'fresh-b'; lastRotated = '2026-04-15'; rotationPolicyDays = 30; requiredBy = @('b') }
        )
        Expected = @(
            'SUMMARY total=2 expired=0 warning=0 ok=2 exit=0'
        )
    }
    @{
        Name     = 'empty-config'
        Fixture  = @()
        Expected = @(
            'SUMMARY total=0 expired=0 warning=0 ok=0 exit=0'
        )
    }
)

# Truncate the shared result file at start.
Set-Content -LiteralPath $ResultFile -Value "" -Encoding UTF8

foreach ($case in $cases) {
    $caseName = $case.Name
    Write-Host "`n--- Running act case: $caseName ---" -ForegroundColor Yellow

    # Stage a pristine temp repo for this case so act sees nothing but the
    # files we want under test.
    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-srv-$caseName-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $workDir | Out-Null
    try {
        Copy-Item -Recurse (Join-Path $RepoRoot '.github')                          (Join-Path $workDir '.github')
        Copy-Item         (Join-Path $RepoRoot 'SecretRotationValidator.psm1')    $workDir
        Copy-Item         (Join-Path $RepoRoot 'SecretRotationValidator.Tests.ps1') $workDir
        Copy-Item         (Join-Path $RepoRoot 'Invoke-Validator.ps1')             $workDir
        Copy-Item         (Join-Path $RepoRoot '.actrc')                           $workDir
        New-Item -ItemType Directory -Path (Join-Path $workDir 'fixtures') | Out-Null

        $fixtureJson = if ($case.Fixture.Count -eq 0) { '[]' } else { $case.Fixture | ConvertTo-Json -Depth 6 }
        Set-Content -LiteralPath (Join-Path $workDir 'fixtures/default.json') -Value $fixtureJson -Encoding UTF8

        # act requires the directory to be a git repo.
        Push-Location $workDir
        try {
            & git init --quiet
            & git -c user.email=t@t -c user.name=t add -A
            & git -c user.email=t@t -c user.name=t commit --quiet -m "case $caseName" | Out-Null

            # Capture the output stream for parsing + append to shared result file.
            $logPath = Join-Path $workDir 'act.log'
            & act push --rm *>&1 | Tee-Object -FilePath $logPath
            $actExit = $LASTEXITCODE
            $actOutput = Get-Content -Raw -LiteralPath $logPath
        }
        finally { Pop-Location }

        Add-Content -LiteralPath $ResultFile -Value "===== CASE: $caseName (act exit=$actExit) ====="
        Add-Content -LiteralPath $ResultFile -Value $actOutput
        Add-Content -LiteralPath $ResultFile -Value ""

        Assert-True ($actExit -eq 0) "[$caseName] act exited 0 (was $actExit)"
        # act prints one "Job succeeded" per job that finishes cleanly.
        $succeededCount = ([regex]::Matches($actOutput, 'Job succeeded')).Count
        Assert-True ($succeededCount -ge 2) "[$caseName] both jobs show 'Job succeeded' (found $succeededCount)"

        foreach ($needle in $case.Expected) {
            Assert-True ($actOutput -match [regex]::Escape($needle)) "[$caseName] output contains '$needle'"
        }
    }
    finally {
        Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n=== Results ===" -ForegroundColor Cyan
if ($script:Failures.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host ("{0} CHECK(S) FAILED:" -f $script:Failures.Count) -ForegroundColor Red
    $script:Failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}
