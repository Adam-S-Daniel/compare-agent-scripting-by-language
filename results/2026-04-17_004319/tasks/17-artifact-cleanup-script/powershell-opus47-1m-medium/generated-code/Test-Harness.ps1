#!/usr/bin/env pwsh
# Test harness: for each test case, spin up an isolated temp git repo
# containing the project files plus that case's fixture, run `act push --rm`,
# and assert on exact expected output.
#
# All act output is appended (with delimiters) to act-result.txt.

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$resultFile  = Join-Path $projectRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile }

# Workflow structure tests — run locally before invoking act.
& {
    $wf = Get-Content -Raw (Join-Path $projectRoot '.github/workflows/artifact-cleanup-script.yml')
    $checks = @(
        @{ Name='push trigger';              Pattern='(?ms)^on:\s*\n(?:.*\n)*?\s+push:' }
        @{ Name='workflow_dispatch trigger'; Pattern='workflow_dispatch:' }
        @{ Name='unit-tests job';            Pattern='unit-tests:' }
        @{ Name='cleanup-plan job';          Pattern='cleanup-plan:' }
        @{ Name='needs dependency';          Pattern='needs:\s+unit-tests' }
        @{ Name='checkout action';           Pattern='actions/checkout@v4' }
        @{ Name='references Run-Cleanup.ps1';Pattern='Run-Cleanup\.ps1' }
        @{ Name='references test file';      Pattern='ArtifactCleanup\.Tests\.ps1' }
        @{ Name='permissions block';         Pattern='permissions:' }
    )
    foreach ($c in $checks) {
        if ($wf -notmatch $c.Pattern) { throw "Workflow structure check failed: $($c.Name)" }
    }
    Write-Host "[OK] Workflow structure checks: $($checks.Count) passed"

    foreach ($f in 'Run-Cleanup.ps1','ArtifactCleanup.psm1','ArtifactCleanup.Tests.ps1','fixtures/artifacts.json') {
        if (-not (Test-Path (Join-Path $projectRoot $f))) { throw "Referenced file missing: $f" }
    }
    Write-Host "[OK] Referenced files all exist"

    & actionlint (Join-Path $projectRoot '.github/workflows/artifact-cleanup-script.yml')
    if ($LASTEXITCODE -ne 0) { throw "actionlint failed (exit $LASTEXITCODE)" }
    Write-Host "[OK] actionlint passed"
}

# Each test case: fixture payload + workflow_dispatch-style inputs, and exactly
# what the RESULT line should contain.
$cases = @(
    @{
        Name     = 'age-policy'
        Fixture  = (Get-Content -Raw (Join-Path $projectRoot 'fixtures/artifacts.json'))
        Env      = @{ MAX_AGE_DAYS='30'; MAX_TOTAL_SIZE_BYTES='0'; KEEP_LATEST_PER_WORKFLOW='0'; DRY_RUN='true' }
        Expected = 'RESULT deleted=3 retained=3 reclaimed=3500 dryrun=True'
    },
    @{
        Name     = 'keep-latest-rescues'
        Fixture  = (Get-Content -Raw (Join-Path $projectRoot 'fixtures/artifacts.json'))
        Env      = @{ MAX_AGE_DAYS='30'; MAX_TOTAL_SIZE_BYTES='0'; KEEP_LATEST_PER_WORKFLOW='2'; DRY_RUN='true' }
        Expected = 'RESULT deleted=2 retained=4 reclaimed=3000 dryrun=True'
    },
    @{
        Name     = 'total-size-budget'
        Fixture  = (Get-Content -Raw (Join-Path $projectRoot 'fixtures/artifacts.json'))
        Env      = @{ MAX_AGE_DAYS='0'; MAX_TOTAL_SIZE_BYTES='5000'; KEEP_LATEST_PER_WORKFLOW='0'; DRY_RUN='true' }
        Expected = 'RESULT deleted=4 retained=2 reclaimed=6500 dryrun=True'
    }
)

function Run-ActCase {
    param($Case)

    $tmp = New-Item -ItemType Directory -Path ([IO.Path]::Combine([IO.Path]::GetTempPath(), "act-$($Case.Name)-$([guid]::NewGuid().Guid.Substring(0,8))"))
    try {
        Copy-Item -Recurse -Force -Path (Join-Path $projectRoot '*') -Destination $tmp.FullName -Exclude 'act-result.txt','Test-Harness.ps1','.git','.claude'
        # Overwrite fixture with case-specific payload.
        New-Item -ItemType Directory -Force -Path (Join-Path $tmp.FullName 'fixtures') | Out-Null
        Set-Content -Path (Join-Path $tmp.FullName 'fixtures/artifacts.json') -Value $Case.Fixture

        # Overwrite env in workflow for deterministic input without needing workflow_dispatch.
        $wfPath = Join-Path $tmp.FullName '.github/workflows/artifact-cleanup-script.yml'
        $wf = Get-Content -Raw $wfPath
        $wf = $wf -replace "MAX_AGE_DAYS:\s*\`$\{\{[^}]+\}\}",             "MAX_AGE_DAYS: `"$($Case.Env.MAX_AGE_DAYS)`""
        $wf = $wf -replace "MAX_TOTAL_SIZE_BYTES:\s*\`$\{\{[^}]+\}\}",     "MAX_TOTAL_SIZE_BYTES: `"$($Case.Env.MAX_TOTAL_SIZE_BYTES)`""
        $wf = $wf -replace "KEEP_LATEST_PER_WORKFLOW:\s*\`$\{\{[^}]+\}\}", "KEEP_LATEST_PER_WORKFLOW: `"$($Case.Env.KEEP_LATEST_PER_WORKFLOW)`""
        $wf = $wf -replace "DRY_RUN:\s*\`$\{\{[^}]+\}\}",                  "DRY_RUN: `"$($Case.Env.DRY_RUN)`""
        Set-Content -Path $wfPath -Value $wf

        Push-Location $tmp.FullName
        try {
            git init -q
            git -c user.email=t@t -c user.name=t add -A
            git -c user.email=t@t -c user.name=t commit -q -m init
            Write-Host "== Running act for case: $($Case.Name) =="
            # --pull=false: the prebuilt pwsh image lives locally and is not on any registry.
            $output = & act push --rm --pull=false 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        Add-Content -Path $resultFile -Value "===== CASE: $($Case.Name) ====="
        Add-Content -Path $resultFile -Value $output
        Add-Content -Path $resultFile -Value "===== EXIT: $exit ====="
        Add-Content -Path $resultFile -Value ""

        if ($exit -ne 0)                    { throw "act exited $exit for case $($Case.Name)" }
        if ($output -notmatch [regex]::Escape($Case.Expected)) {
            throw "Expected output missing for $($Case.Name): '$($Case.Expected)'"
        }
        # Every job reports success.
        $succeeded = ([regex]::Matches($output, 'Job succeeded')).Count
        if ($succeeded -lt 2) { throw "Expected >=2 'Job succeeded' lines, saw $succeeded in $($Case.Name)" }
        Write-Host "[OK] $($Case.Name): matched '$($Case.Expected)', $succeeded jobs succeeded"
    } finally {
        Remove-Item -Recurse -Force $tmp.FullName -ErrorAction SilentlyContinue
    }
}

foreach ($case in $cases) { Run-ActCase -Case $case }

Write-Host ""
Write-Host "ALL TESTS PASSED. Results in $resultFile"
