# Run-ActHarness.ps1
# End-to-end harness: for each test case, build an isolated git repo with the
# project files + a fixture-specific config, run `act push --rm`, capture and
# parse output, and assert exact expected values from the workflow.
#
# Required artifact: act-result.txt in the script directory.

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

$Root       = $PSScriptRoot
$ResultFile = Join-Path $Root 'act-result.txt'
if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }

# Workflow structure tests (do these first — they don't require act)
$workflowPath = Join-Path $Root '.github/workflows/artifact-cleanup-script.yml'
if (-not (Test-Path $workflowPath)) { throw "Workflow file missing: $workflowPath" }
$wf = Get-Content -Raw $workflowPath
foreach ($needle in 'on:', 'push:', 'pull_request:', 'schedule:', 'workflow_dispatch:',
                    'permissions:', 'actions/checkout@v4',
                    'ArtifactCleanup.Tests.ps1', 'ArtifactCleanup.ps1', 'shell: pwsh') {
    if ($wf -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected element: $needle"
    }
}
foreach ($needed in 'ArtifactCleanup.ps1','ArtifactCleanup.Tests.ps1','fixtures/sample.json') {
    if (-not (Test-Path (Join-Path $Root $needed))) {
        throw "Workflow references missing file: $needed"
    }
}

# actionlint
& actionlint $workflowPath
if ($LASTEXITCODE -ne 0) { throw "actionlint failed (exit $LASTEXITCODE)" }
'[harness] actionlint OK' | Tee-Object -FilePath $ResultFile -Append | Write-Host

# Test cases — each case uses a fixture and policy params via env, and asserts
# exact PLAN_* values printed by the workflow's cleanup job.
$cases = @(
    @{
        Name           = 'sample-max-age-30'
        Fixture        = 'fixtures/sample.json'
        Env            = @{ MAX_AGE_DAYS='30'; MAX_TOTAL_BYTES=''; KEEP_LATEST=''; DRY_RUN='true'; NOW_UTC='2026-05-08T00:00:00Z' }
        ExpectDeleted  = 3
        ExpectRetained = 2
        ExpectReclaimed= 700
        ExpectDryRun   = 'True'
    },
    @{
        Name           = 'keep-latest-1-per-workflow'
        Fixture        = 'fixtures/keep-latest.json'
        Env            = @{ MAX_AGE_DAYS=''; MAX_TOTAL_BYTES=''; KEEP_LATEST='1'; DRY_RUN='false'; NOW_UTC='2026-05-08T00:00:00Z' }
        ExpectDeleted  = 2  # wf1: drop wf1-r1, wf1-r2 (keep wf1-r3); wf2: keep only one already
        ExpectRetained = 2
        ExpectReclaimed= 3000  # 1000 + 2000
        ExpectDryRun   = 'False'
    },
    @{
        Name           = 'max-total-bytes-cap'
        Fixture        = 'fixtures/keep-latest.json'
        Env            = @{ MAX_AGE_DAYS=''; MAX_TOTAL_BYTES='5000'; KEEP_LATEST=''; DRY_RUN='true'; NOW_UTC='2026-05-08T00:00:00Z' }
        # newest->oldest: wf1-r3(3000), wf2-r1(4000)→cum=7000>5000 deletes,
        # wf1-r2(2000) deletes, wf1-r1(1000) deletes. Keep only wf1-r3.
        ExpectDeleted  = 3
        ExpectRetained = 1
        ExpectReclaimed= 7000
        ExpectDryRun   = 'True'
    }
)

$caseIdx = 0
foreach ($c in $cases) {
    $caseIdx++
    $tmp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("act-case-$caseIdx-" + [Guid]::NewGuid().ToString('N')))
    try {
        # Copy project into the temp dir
        Copy-Item -Path "$Root/ArtifactCleanup.ps1"        -Destination $tmp.FullName
        Copy-Item -Path "$Root/ArtifactCleanup.Tests.ps1"  -Destination $tmp.FullName
        Copy-Item -Path "$Root/.actrc"                     -Destination $tmp.FullName
        Copy-Item -Path "$Root/.github"                    -Destination $tmp.FullName -Recurse
        Copy-Item -Path "$Root/fixtures"                   -Destination $tmp.FullName -Recurse

        # Override the env defaults in the workflow with this case's settings via
        # an env-file passed to act; also pin the fixture path.
        $envFile = Join-Path $tmp.FullName 'case.env'
        $lines = @("FIXTURE=$($c.Fixture)")
        foreach ($k in $c.Env.Keys) { $lines += "$k=$($c.Env[$k])" }
        Set-Content -Path $envFile -Value $lines

        Push-Location $tmp.FullName
        try {
            & git init -q
            & git -c user.email=t@t -c user.name=t add -A
            & git -c user.email=t@t -c user.name=t commit -q -m init | Out-Null

            $delim = "===== CASE: $($c.Name) ====="
            Add-Content -Path $ResultFile -Value $delim
            Write-Host $delim

            $output = & act push --rm --pull=false --env-file case.env 2>&1 | Out-String
            $exit = $LASTEXITCODE
            Add-Content -Path $ResultFile -Value $output
            Add-Content -Path $ResultFile -Value "[exit=$exit]"
            Write-Host $output

            if ($exit -ne 0) { throw "act exited with $exit for case $($c.Name)" }

            # All jobs must report success
            $jobSuccess = ([regex]::Matches($output, 'Job succeeded')).Count
            if ($jobSuccess -lt 2) {
                throw "Case $($c.Name): expected >=2 'Job succeeded', got $jobSuccess"
            }

            # Parse and assert exact PLAN_* values
            $expected = @{
                PLAN_DELETED   = "$($c.ExpectDeleted)"
                PLAN_RETAINED  = "$($c.ExpectRetained)"
                PLAN_RECLAIMED = "$($c.ExpectReclaimed)"
                PLAN_DRYRUN    = $c.ExpectDryRun
            }
            foreach ($k in $expected.Keys) {
                $needle = "$k=$($expected[$k])"
                if ($output -notmatch [regex]::Escape($needle)) {
                    throw "Case $($c.Name): expected '$needle' in act output"
                }
            }
            Add-Content -Path $ResultFile -Value "[case $($c.Name) PASSED]"
            Write-Host "[case $($c.Name) PASSED]"
        } finally { Pop-Location }
    } finally {
        Remove-Item -Recurse -Force $tmp.FullName -ErrorAction SilentlyContinue
    }
}

Add-Content -Path $ResultFile -Value '[harness ALL PASSED]'
Write-Host '[harness ALL PASSED]'
