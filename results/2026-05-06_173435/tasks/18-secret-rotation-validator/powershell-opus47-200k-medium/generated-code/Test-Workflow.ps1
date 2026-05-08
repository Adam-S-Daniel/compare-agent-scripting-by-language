# Test-Workflow.ps1
#
# End-to-end harness: runs the workflow in `act` against three fixture files
# (all-ok, warning-only, contains-expired). For each case it stages a temp git
# repo with the project files + that fixture, runs `act push --rm`, captures
# output to act-result.txt, and asserts on exact expected values in the output.
#
# Limited to 3 `act push` runs total (one per case), as required.

[CmdletBinding()]
param(
    [string] $ResultFile = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'

# Wipe previous results so this run is the source of truth.
if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }
New-Item -ItemType File -Path $ResultFile | Out-Null

# Each case provides:
#   name    - label used in delimiters / failure messages
#   secrets - array of secret records to write into fixtures/secrets.json
#   expect  - hashtable of strings that MUST appear in the act output
#   reject  - hashtable of strings that MUST NOT appear
#   expectedExit - validator exit code expected (0 ok, 1 warning, 2 expired)
$cases = @(
    @{
        name    = 'all-ok'
        secrets = @(
            @{ name='ok-1'; lastRotated='2026-05-01'; rotationDays=90; requiredBy=@('api') }
            @{ name='ok-2'; lastRotated='2026-04-15'; rotationDays=180; requiredBy=@('worker') }
        )
        expect       = @('All secrets are within policy.', '## Expired (0)', '## Warning (0)', '## OK (2)', 'ok-1', 'ok-2')
        reject       = @('## Expired (1)', '## Expired (2)')
        expectedExit = 0
    },
    @{
        name    = 'warning-only'
        secrets = @(
            @{ name='warn-1'; lastRotated='2026-02-15'; rotationDays=90; requiredBy=@('web') }
            @{ name='ok-1';   lastRotated='2026-05-01'; rotationDays=90; requiredBy=@('api') }
        )
        expect       = @('Warnings present (no expired).', '## Warning (1)', '## Expired (0)', 'warn-1')
        reject       = @('## Expired (1)')
        expectedExit = 1
    },
    @{
        name    = 'contains-expired'
        secrets = @(
            @{ name='expired-old';   lastRotated='2025-01-01'; rotationDays=30;  requiredBy=@('cron') }
            @{ name='expired-newer'; lastRotated='2025-10-01'; rotationDays=90;  requiredBy=@('worker','api') }
            @{ name='ok-1';          lastRotated='2026-05-01'; rotationDays=90;  requiredBy=@('api') }
        )
        expect       = @('Expired secrets detected.', '## Expired (2)', '## OK (1)', 'expired-old', 'expired-newer', 'worker, api')
        reject       = @('## Expired (0)')
        expectedExit = 2
    }
)

$projectRoot = $PSScriptRoot
$failures    = New-Object System.Collections.Generic.List[string]

foreach ($case in $cases) {
    $caseName = $case.name
    Write-Host "=== Running case: $caseName ===" -ForegroundColor Cyan

    # Stage a fresh temp dir, copy project files, replace the fixture.
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-act-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        Copy-Item -Path (Join-Path $projectRoot '*') -Destination $temp -Recurse -Force `
            -Exclude @('act-result.txt','Test-Workflow.ps1')
        # `*` in PowerShell does not pick up dotfiles like .actrc / .github;
        # copy them explicitly so act sees the local-image -P mapping.
        foreach ($dot in @('.actrc','.github')) {
            $src = Join-Path $projectRoot $dot
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $temp -Recurse -Force
            }
        }
        # Rewrite the fixture for this case.
        $fixturePath = Join-Path $temp 'fixtures/secrets.json'
        $case.secrets | ConvertTo-Json -Depth 6 | Set-Content -Path $fixturePath -Encoding UTF8

        # act needs a git repo; init one so push events resolve.
        Push-Location $temp
        try {
            git init -q 2>&1 | Out-Null
            git -c user.email=test@local -c user.name=test add -A 2>&1 | Out-Null
            git -c user.email=test@local -c user.name=test commit -q -m "case $caseName" 2>&1 | Out-Null

            # Run act. --rm tears down container after; -W targets our workflow.
            # --pull=false: our act image is built locally and not in a registry.
            $actOut = & act push --rm --pull=false `
                -W .github/workflows/secret-rotation-validator.yml `
                --container-architecture linux/amd64 2>&1
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append to act-result.txt with clear delimiters.
        $delim = '=' * 78
        Add-Content -Path $ResultFile -Value $delim
        Add-Content -Path $ResultFile -Value "CASE: $caseName"
        Add-Content -Path $ResultFile -Value "ACT EXIT: $actExit"
        Add-Content -Path $ResultFile -Value $delim
        $actOut | ForEach-Object { Add-Content -Path $ResultFile -Value ([string]$_) }
        Add-Content -Path $ResultFile -Value ''

        $joined = ($actOut | ForEach-Object { [string]$_ }) -join "`n"

        # ----- Assertions -----
        if ($actExit -ne 0) {
            $failures.Add("[$caseName] act exited with $actExit (expected 0)")
        }

        # Both jobs must report success.
        $jobSuccessCount = ([regex]::Matches($joined, '(?m)Job succeeded')).Count
        if ($jobSuccessCount -lt 2) {
            $failures.Add("[$caseName] expected at least 2 'Job succeeded' lines (unit-tests + validate-secrets), got $jobSuccessCount")
        }

        # Validator exit code surfaced via summarize step.
        if ($joined -notmatch "validator exit code: $($case.expectedExit)") {
            $failures.Add("[$caseName] expected 'validator exit code: $($case.expectedExit)' in act output")
        }

        foreach ($needle in $case.expect) {
            if ($joined -notmatch [regex]::Escape($needle)) {
                $failures.Add("[$caseName] expected substring not found: '$needle'")
            }
        }
        foreach ($bad in $case.reject) {
            if ($joined -match [regex]::Escape($bad)) {
                $failures.Add("[$caseName] forbidden substring present: '$bad'")
            }
        }

        # Pester run inside the workflow: 20 passing, 1 skipped (actionlint
        # is host-only, the rest run in-container). Assert 0 failures and 20
        # passes — exact known-good values for this fixture.
        if ($joined -notmatch 'Tests Passed:\s*20') {
            $failures.Add("[$caseName] expected 'Tests Passed: 20' from Pester job (in-container)")
        }
        if ($joined -notmatch 'Failed:\s*0') {
            $failures.Add("[$caseName] expected 'Failed: 0' from Pester job")
        }

        Write-Host "Case '$caseName' assertions complete." -ForegroundColor Green
    }
    finally {
        Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "FAIL: $($failures.Count) assertion(s) failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "All workflow integration cases passed. Output saved to $ResultFile" -ForegroundColor Green
exit 0
