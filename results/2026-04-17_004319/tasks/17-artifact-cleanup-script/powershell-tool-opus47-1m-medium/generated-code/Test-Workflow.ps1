#!/usr/bin/env pwsh
# Workflow harness: validates YAML structure, runs actionlint, then runs
# every test case through `act push --rm`, appending results to act-result.txt.
#
# Each case uses a different fixture file; expected output values are derived
# by running the policy math by hand against the same inputs.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$WorkflowPath = Join-Path $ProjectRoot '.github/workflows/artifact-cleanup-script.yml'
$ResultFile   = Join-Path $ProjectRoot 'act-result.txt'
if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }

$failures = 0
function Assert-True([bool]$Cond, [string]$Msg) {
    if ($Cond) { Write-Host "  PASS: $Msg" -ForegroundColor Green }
    else       { Write-Host "  FAIL: $Msg" -ForegroundColor Red; $script:failures++ }
}

# ---- Structural tests on the YAML itself ----------------------------------
Write-Host '== Structure tests =='
Assert-True (Test-Path $WorkflowPath) 'workflow file exists'

# Poor-man's YAML parse (avoids external module dependency in act harness).
$yaml = Get-Content $WorkflowPath -Raw
Assert-True ($yaml -match '(?m)^on:')                  'has on: triggers'
Assert-True ($yaml -match 'push:')                     'triggers on push'
Assert-True ($yaml -match 'pull_request:')             'triggers on pull_request'
Assert-True ($yaml -match 'schedule:')                 'triggers on schedule'
Assert-True ($yaml -match 'workflow_dispatch:')        'triggers on workflow_dispatch'
Assert-True ($yaml -match 'actions/checkout@v4')       'uses checkout@v4'
Assert-True ($yaml -match 'shell:\s*pwsh')             'uses pwsh shell'
Assert-True ($yaml -match 'Invoke-ArtifactCleanup\.ps1') 'references script'
Assert-True ($yaml -match 'ArtifactCleanup\.Tests\.ps1') 'references tests'
Assert-True ($yaml -match 'needs:\s*test')             'cleanup depends on test job'

# Referenced script paths must actually exist on disk.
foreach ($ref in 'Invoke-ArtifactCleanup.ps1','ArtifactCleanup.psm1','ArtifactCleanup.Tests.ps1') {
    Assert-True (Test-Path (Join-Path $ProjectRoot $ref)) "referenced file exists: $ref"
}

Write-Host '== actionlint =='
& actionlint $WorkflowPath
Assert-True ($LASTEXITCODE -eq 0) 'actionlint exit 0'

# ---- Test cases: fixture -> expected plan summary -------------------------
# Policy: MAX_AGE_DAYS=30, KEEP_LATEST_N=2, MAX_TOTAL_SIZE=1000, Now=2026-04-17.
$cases = @(
    @{
        Name     = 'all-fresh'
        Fixture  = @(
            @{ Name='a'; SizeBytes=50; CreatedAt='2026-04-10T00:00:00Z'; WorkflowRunId='w1' }
            @{ Name='b'; SizeBytes=70; CreatedAt='2026-04-15T00:00:00Z'; WorkflowRunId='w2' }
        )
        Retained = 2; Deleted = 0; Reclaimed = 0
    }
    @{
        Name     = 'aged-out'
        Fixture  = @(
            @{ Name='old';   SizeBytes=99; CreatedAt='2025-01-01T00:00:00Z'; WorkflowRunId='w1' }
            @{ Name='fresh'; SizeBytes=10; CreatedAt='2026-04-16T00:00:00Z'; WorkflowRunId='w1' }
        )
        Retained = 1; Deleted = 1; Reclaimed = 99
    }
    @{
        Name     = 'combined'
        # ancient(500) aged out; a1(300) trimmed by keep-latest-2 for wfA;
        # survivors 700B fit under 1000B cap -> no further eviction.
        Fixture  = @(
            @{ Name='ancient'; SizeBytes=500; CreatedAt='2026-01-10T00:00:00Z'; WorkflowRunId='wfA' }
            @{ Name='a1';      SizeBytes=300; CreatedAt='2026-04-07T00:00:00Z'; WorkflowRunId='wfA' }
            @{ Name='a2';      SizeBytes=300; CreatedAt='2026-04-12T00:00:00Z'; WorkflowRunId='wfA' }
            @{ Name='a3';      SizeBytes=300; CreatedAt='2026-04-15T00:00:00Z'; WorkflowRunId='wfA' }
            @{ Name='b1';      SizeBytes=100; CreatedAt='2026-04-16T00:00:00Z'; WorkflowRunId='wfB' }
        )
        Retained = 3; Deleted = 2; Reclaimed = 800
    }
)

foreach ($case in $cases) {
    Write-Host "`n== Case: $($case.Name) ==" -ForegroundColor Cyan
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ac-$($case.Name)-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # Stage the project into a throwaway git repo.
        Copy-Item (Join-Path $ProjectRoot '.github')                   -Destination $tmp -Recurse
        Copy-Item (Join-Path $ProjectRoot 'ArtifactCleanup.psm1')      -Destination $tmp
        Copy-Item (Join-Path $ProjectRoot 'ArtifactCleanup.Tests.ps1') -Destination $tmp
        Copy-Item (Join-Path $ProjectRoot 'Invoke-ArtifactCleanup.ps1') -Destination $tmp
        Copy-Item (Join-Path $ProjectRoot '.actrc')                    -Destination $tmp
        New-Item -ItemType Directory -Path (Join-Path $tmp 'fixtures') | Out-Null
        ($case.Fixture | ConvertTo-Json -Depth 5) |
            Set-Content -LiteralPath (Join-Path $tmp 'fixtures/artifacts.json')

        Push-Location $tmp
        try {
            git init -q
            git config user.email ci@test ; git config user.name ci
            git add -A
            git commit -q -m "case $($case.Name)"

            $log = & act push --rm --pull=false --container-architecture linux/amd64 2>&1 | Out-String
        } finally {
            Pop-Location
        }

        $exit = $LASTEXITCODE
        Add-Content -LiteralPath $ResultFile -Value "===== CASE: $($case.Name) (exit=$exit) ====="
        Add-Content -LiteralPath $ResultFile -Value $log
        Add-Content -LiteralPath $ResultFile -Value ''

        Assert-True ($exit -eq 0) "act exit 0 for $($case.Name)"
        Assert-True ($log -match 'Job succeeded')          'Job succeeded present'
        # Two jobs -> two successes; act prints one per job.
        Assert-True (([regex]::Matches($log,'Job succeeded')).Count -ge 2) 'both jobs succeeded'
        Assert-True ($log -match "Retained:\s*$($case.Retained)\b")   "Retained=$($case.Retained)"
        Assert-True ($log -match "Deleted:\s*$($case.Deleted)\b")     "Deleted=$($case.Deleted)"
        Assert-True ($log -match "Reclaimed:\s*$($case.Reclaimed)\s*bytes") "Reclaimed=$($case.Reclaimed)"
        Assert-True ($log -match 'DRY-RUN')                             'DRY-RUN mode'
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

Write-Host "`n== Summary ==" -ForegroundColor Cyan
if ($failures -gt 0) { Write-Host "$failures assertion(s) failed" -ForegroundColor Red; exit 1 }
Write-Host 'All assertions passed.' -ForegroundColor Green
