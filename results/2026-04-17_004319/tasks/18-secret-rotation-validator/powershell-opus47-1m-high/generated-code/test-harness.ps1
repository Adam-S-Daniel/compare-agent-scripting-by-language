#!/usr/bin/env pwsh
# Integration test harness.
# For each test case we:
#   1. Build a scratch git repo containing the project files + that case's
#      fixture data copied to secrets.json at the repo root
#   2. Write a case-specific .env consumed by act (freezes the date, picks
#      warning window and format) so each act run produces deterministic output
#   3. Run `act push --rm` and append its stdout/stderr to act-result.txt
#      with clear delimiters
#   4. Assert act exited 0, both jobs succeeded, and the log contains the
#      exact tokens we expect for that fixture
#
# All assertion failures are collected so we can see every failure on one
# harness run instead of bailing at the first mismatch.

param(
    [string] $OutFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = $PSScriptRoot
$cases = @(
    [ordered]@{
        Name          = 'expired'
        Fixture       = 'fixtures/expired.json'
        Env           = @{
            SECRETS_CONFIG       = 'secrets.json'
            SECRETS_NOW          = '2026-04-19'
            SECRETS_WARNING_DAYS = '30'
            SECRETS_FORMAT       = 'markdown'
        }
        ExpectExit    = 0          # workflow swallows validator's exit code
        ExpectTokens  = @(
            'PESTER_OK count=18',
            'VALIDATOR_EXIT=2',
            'VERDICT=expired',
            '## Expired (1)',
            '## Warning (1)',
            '## OK (1)',
            '| db-primary-password | 2026-01-01 | 30 | -78 | api, worker |'
        )
    }
    [ordered]@{
        Name          = 'warning-only'
        Fixture       = 'fixtures/warning-only.json'
        Env           = @{
            SECRETS_CONFIG       = 'secrets.json'
            SECRETS_NOW          = '2026-04-19'
            SECRETS_WARNING_DAYS = '30'
            SECRETS_FORMAT       = 'json'
        }
        ExpectExit    = 0
        ExpectTokens  = @(
            'VALIDATOR_EXIT=1',
            'VERDICT=warning',
            '"expired": 0',
            '"warning": 1',
            '"ok": 1',
            '"name": "api-signing-key"'
        )
    }
    [ordered]@{
        Name          = 'all-ok'
        Fixture       = 'fixtures/all-ok.json'
        Env           = @{
            SECRETS_CONFIG       = 'secrets.json'
            SECRETS_NOW          = '2026-04-19'
            SECRETS_WARNING_DAYS = '14'
            SECRETS_FORMAT       = 'markdown'
        }
        ExpectExit    = 0
        ExpectTokens  = @(
            'VALIDATOR_EXIT=0',
            'VERDICT=ok',
            '## Expired (0)',
            '## Warning (0)',
            '## OK (2)'
        )
    }
)

if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
New-Item -ItemType File -Path $OutFile | Out-Null

$failures = [System.Collections.Generic.List[string]]::new()

function Initialize-Workspace {
    param([string] $Dest, [string] $Fixture)
    # Copy only what the workflow needs; git excludes things like .git.
    $items = @(
        '.github',
        'SecretRotationValidator.psm1',
        'SecretRotationValidator.Tests.ps1',
        'validate-secrets.ps1',
        'fixtures'
    )
    foreach ($i in $items) {
        Copy-Item -Recurse -Force (Join-Path $repoRoot $i) $Dest
    }
    Copy-Item -Force (Join-Path $repoRoot $Fixture) (Join-Path $Dest 'secrets.json')

    Push-Location $Dest
    try {
        git init -q -b main 2>&1 | Out-Null
        git -c user.email=h@l -c user.name=h add . 2>&1 | Out-Null
        git -c user.email=h@l -c user.name=h commit -q -m 'seed' 2>&1 | Out-Null
    } finally { Pop-Location }
}

function Write-EnvFile {
    param([string] $Path, [hashtable] $Env)
    $lines = foreach ($k in $Env.Keys) { "$k=$($Env[$k])" }
    Set-Content -LiteralPath $Path -Value ($lines -join "`n")
}

function Add-Delimiter {
    param([string] $Title, [string] $Body)
    Add-Content -Path $OutFile -Value "`n===== BEGIN $Title =====`n"
    Add-Content -Path $OutFile -Value $Body
    Add-Content -Path $OutFile -Value "`n===== END $Title =====`n"
}

foreach ($case in $cases) {
    $caseName = $case.Name
    Write-Host "`n--- Running case: $caseName ---"

    $work = Join-Path ([IO.Path]::GetTempPath()) "srv-act-$caseName-$(New-Guid)"
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        Initialize-Workspace -Dest $work -Fixture $case.Fixture
        $envFile = Join-Path $work '.act.env'
        Write-EnvFile -Path $envFile -Env $case.Env

        Push-Location $work
        try {
            # --rm cleans up containers; --env-file ferries our test knobs
            # into the workflow; -P is passed explicitly (rather than relying
            # on .actrc) since the scratch workspace has no .actrc file and
            # the default image lacks pwsh.
            # --pull=false because the image is built locally (no registry).
            $actOutput = & act push --rm --pull=false `
                -P ubuntu-latest=act-ubuntu-pwsh:latest `
                --env-file $envFile 2>&1 | Out-String
            $actExit = $LASTEXITCODE
        } finally { Pop-Location }

        Add-Delimiter -Title "CASE $caseName (exit=$actExit)" -Body $actOutput

        if ($actExit -ne $case.ExpectExit) {
            $failures.Add("[$caseName] act exit $actExit, expected $($case.ExpectExit)")
        }

        # Assert each job reached the "Job succeeded" line act prints.
        $succeeded = ([regex]::Matches($actOutput, 'Job succeeded')).Count
        if ($succeeded -lt 2) {
            $failures.Add("[$caseName] expected 2 'Job succeeded' lines, saw $succeeded")
        }

        foreach ($token in $case.ExpectTokens) {
            if ($actOutput -notmatch [regex]::Escape($token)) {
                $failures.Add("[$caseName] missing token: '$token'")
            }
        }
    } finally {
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    }
}

# Workflow structure tests: these don't need act and run against the
# committed YAML to catch schema regressions fast.
Write-Host "`n--- Running workflow structure tests ---"
$wfPath = Join-Path $repoRoot '.github/workflows/secret-rotation-validator.yml'
if (-not (Test-Path $wfPath)) {
    $failures.Add('workflow file missing')
} else {
    $yaml = Get-Content $wfPath -Raw
    foreach ($trigger in 'push:','pull_request:','schedule:','workflow_dispatch:') {
        if ($yaml -notmatch [regex]::Escape($trigger)) {
            $failures.Add("workflow missing trigger: $trigger")
        }
    }
    foreach ($job in 'unit-tests:','validate:') {
        if ($yaml -notmatch [regex]::Escape($job)) {
            $failures.Add("workflow missing job: $job")
        }
    }
    # Scripts the workflow YAML refers to by name must exist on disk, and
    # the validator module used indirectly via the Tests/CLI must also exist.
    $referenced = 'SecretRotationValidator.Tests.ps1','validate-secrets.ps1'
    foreach ($f in $referenced) {
        if ($yaml -notmatch [regex]::Escape($f)) {
            $failures.Add("workflow does not reference $f")
        }
    }
    foreach ($f in $referenced + 'SecretRotationValidator.psm1') {
        if (-not (Test-Path (Join-Path $repoRoot $f))) {
            $failures.Add("referenced script missing from repo: $f")
        }
    }
}

Write-Host "`n--- Running actionlint ---"
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) {
    $failures.Add("actionlint exit $LASTEXITCODE")
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "HARNESS FAILED with $($failures.Count) assertion failure(s):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "HARNESS OK — all $($cases.Count) act runs + structure checks passed." -ForegroundColor Green
exit 0
