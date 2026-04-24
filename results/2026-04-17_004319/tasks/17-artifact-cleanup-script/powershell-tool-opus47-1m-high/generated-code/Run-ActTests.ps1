# Integration test harness.
#
# Every assertion here runs the workflow end-to-end through `act` so we exercise
# the real CI/CD path, not just the module. For each test case we:
#   1. Copy the project + that case's fixture into a fresh temp git repo.
#   2. Run `act push --rm` against it.
#   3. Append the captured stdout+stderr to act-result.txt.
#   4. Assert exit code 0, "Job succeeded" for every job, and exact expected
#      values parsed out of the plan JSON that the workflow prints.
#
# Budget: at most 3 `act push` invocations total. If assertions fail, diagnose
# from the captured output — do not re-run blindly.

[CmdletBinding()]
param(
    [string] $ResultFile = 'act-result.txt'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = $PSScriptRoot
$resultPath  = Join-Path $projectRoot $ResultFile

# Files that must be present inside each per-case temp repo for the workflow
# to execute. .actrc pins the runner image to act-ubuntu-pwsh:latest.
$projectFiles = @(
    'ArtifactCleanup.psm1',
    'ArtifactCleanup.Tests.ps1',
    'Invoke-Cleanup.ps1',
    '.actrc'
)

# --- Test cases --------------------------------------------------------------
# Each case supplies a fixture and the exact summary numbers the workflow is
# expected to print under the workflow's baked-in defaults:
#   MaxAgeDays=30, MaxTotalSizeBytes=0, KeepLatestPerWorkflow=5, DryRun=true,
#   NowUtc=2026-04-19T00:00:00Z.
$cases = @(
    [pscustomobject]@{
        Name     = 'empty'
        Fixture  = @()
        Expected = @{
            TotalArtifacts = 0
            DeletedCount   = 0
            RetainedCount  = 0
            BytesReclaimed = 0
            Mode           = 'DRY-RUN'
        }
    }
    [pscustomobject]@{
        Name    = 'mixed-ages'
        Fixture = @(
            @{ Name='old-a';   SizeBytes=100; CreatedAt='2026-03-10T00:00:00Z'; WorkflowRunId='wf-a' }
            @{ Name='old-b';   SizeBytes=200; CreatedAt='2026-02-19T00:00:00Z'; WorkflowRunId='wf-b' }
            @{ Name='new-c';   SizeBytes=300; CreatedAt='2026-04-18T00:00:00Z'; WorkflowRunId='wf-c' }
        )
        Expected = @{
            TotalArtifacts = 3
            DeletedCount   = 2
            RetainedCount  = 1
            BytesReclaimed = 300  # old-a (100) + old-b (200)
            Mode           = 'DRY-RUN'
        }
    }
    [pscustomobject]@{
        Name    = 'keep-latest-per-workflow'
        Fixture = @(
            # Seven recent artifacts (all within 30d) in one workflow. Defaults
            # keep the 5 newest, so the two oldest (a1, a2) must be deleted.
            @{ Name='a1'; SizeBytes=100; CreatedAt='2026-03-30T00:00:00Z'; WorkflowRunId='ci' }
            @{ Name='a2'; SizeBytes=100; CreatedAt='2026-04-01T00:00:00Z'; WorkflowRunId='ci' }
            @{ Name='a3'; SizeBytes=100; CreatedAt='2026-04-03T00:00:00Z'; WorkflowRunId='ci' }
            @{ Name='a4'; SizeBytes=100; CreatedAt='2026-04-05T00:00:00Z'; WorkflowRunId='ci' }
            @{ Name='a5'; SizeBytes=100; CreatedAt='2026-04-07T00:00:00Z'; WorkflowRunId='ci' }
            @{ Name='a6'; SizeBytes=100; CreatedAt='2026-04-09T00:00:00Z'; WorkflowRunId='ci' }
            @{ Name='a7'; SizeBytes=100; CreatedAt='2026-04-14T00:00:00Z'; WorkflowRunId='ci' }
        )
        Expected = @{
            TotalArtifacts = 7
            DeletedCount   = 2
            RetainedCount  = 5
            BytesReclaimed = 200
            Mode           = 'DRY-RUN'
        }
    }
)

# --- Helpers -----------------------------------------------------------------
function New-CaseRepo {
    param([string] $CaseName, [object[]] $Fixture)

    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-case-$CaseName-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $dir | Out-Null

    # Copy the project source tree the workflow needs.
    foreach ($file in $projectFiles) {
        Copy-Item -Path (Join-Path $projectRoot $file) -Destination (Join-Path $dir $file) -Force
    }
    $wfSrc = Join-Path $projectRoot '.github/workflows/artifact-cleanup-script.yml'
    $wfDst = Join-Path $dir '.github/workflows'
    New-Item -ItemType Directory -Path $wfDst -Force | Out-Null
    Copy-Item -Path $wfSrc -Destination (Join-Path $wfDst 'artifact-cleanup-script.yml') -Force

    # Drop the fixture in the path baked into the workflow's FIXTURE_PATH env.
    $fxDir = Join-Path $dir 'fixtures'
    New-Item -ItemType Directory -Path $fxDir -Force | Out-Null
    $fxPath = Join-Path $fxDir 'default.json'
    if ($Fixture.Count -eq 0) {
        '[]' | Set-Content -LiteralPath $fxPath -Encoding UTF8
    } else {
        ($Fixture | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $fxPath -Encoding UTF8
    }

    # act requires a git repo to pick up a push event.
    Push-Location $dir
    try {
        git init --quiet
        git -c user.email=test@example.com -c user.name=test add -A
        git -c user.email=test@example.com -c user.name=test commit --quiet -m "case: $CaseName"
    } finally {
        Pop-Location
    }

    return $dir
}

function Invoke-ActCase {
    param([string] $CaseName, [string] $RepoDir)

    Push-Location $RepoDir
    try {
        $stdoutPath = Join-Path $RepoDir 'act.stdout'
        $stderrPath = Join-Path $RepoDir 'act.stderr'
        # Route stderr into stdout so we get one chronologically-ordered stream.
        $proc = Start-Process -FilePath 'act' `
                              -ArgumentList @('push', '--rm') `
                              -NoNewWindow -Wait -PassThru `
                              -RedirectStandardOutput $stdoutPath `
                              -RedirectStandardError  $stderrPath

        $stdout = Get-Content $stdoutPath -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $stderrPath -Raw -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            Output   = ($stdout + "`n" + $stderr)
        }
    } finally {
        Pop-Location
    }
}

function Get-PlanFromOutput {
    param([string] $Output)
    # Workflow prints the plan wrapped in BEGIN/END markers. act decorates every
    # stdout line with a "[Job name]   | " prefix, so we strip that before
    # feeding the body to ConvertFrom-Json. ANSI color escapes from PowerShell's
    # error formatter also need to go.
    if ($Output -notmatch '===BEGIN-PLAN-JSON===\s*(?<body>[\s\S]*?)\s*===END-PLAN-JSON===') {
        throw "Plan JSON block not found in act output"
    }
    $body = $Matches['body']
    $lines = $body -split "`n" | ForEach-Object {
        # Strip the "[...]  | " act per-line prefix if present.
        ($_ -replace '^\[[^\]]+\]\s*\|?\s?', '')
    }
    $clean = ($lines -join "`n") -replace "`e\[[0-9;]*m", ''
    $clean | ConvertFrom-Json
}

function Assert-Case {
    param(
        [string] $CaseName,
        [int]    $ExitCode,
        [string] $Output,
        [hashtable] $Expected
    )
    $errors = @()

    if ($ExitCode -ne 0) {
        $errors += "exit code was $ExitCode, expected 0"
    }

    # Every job in this workflow must report success. act emits one
    # "Job succeeded" per job, so we count — two jobs = at least two lines.
    $succeededCount = ([regex]::Matches($Output, 'Job succeeded')).Count
    if ($succeededCount -lt 2) {
        $errors += "expected at least 2 'Job succeeded' markers, saw $succeededCount"
    }

    # Summary lines emitted by Invoke-Cleanup.ps1.
    foreach ($key in 'TotalArtifacts','DeletedCount','RetainedCount','BytesReclaimed') {
        $want = $Expected[$key]
        $pattern = "${key}:\s*$want\b"
        if ($Output -notmatch $pattern) {
            $errors += "summary line '${key}: $want' not found"
        }
    }

    # Mode banner (DRY-RUN or EXECUTE).
    $mode = $Expected['Mode']
    if ($Output -notmatch "Artifact Cleanup Plan \($mode\)") {
        $errors += "mode banner '($mode)' not found"
    }

    # Cross-check by parsing the plan JSON itself.
    try {
        $plan = Get-PlanFromOutput -Output $Output
        if ($plan.Summary.TotalArtifacts -ne $Expected['TotalArtifacts']) {
            $errors += "plan.Summary.TotalArtifacts = $($plan.Summary.TotalArtifacts), expected $($Expected['TotalArtifacts'])"
        }
        if ($plan.Summary.DeletedCount -ne $Expected['DeletedCount']) {
            $errors += "plan.Summary.DeletedCount = $($plan.Summary.DeletedCount), expected $($Expected['DeletedCount'])"
        }
        if ($plan.Summary.BytesReclaimed -ne $Expected['BytesReclaimed']) {
            $errors += "plan.Summary.BytesReclaimed = $($plan.Summary.BytesReclaimed), expected $($Expected['BytesReclaimed'])"
        }
    } catch {
        $errors += "failed to parse plan JSON: $_"
    }

    if ($errors.Count -gt 0) {
        Write-Host "[$CaseName] FAIL"
        foreach ($e in $errors) { Write-Host "  - $e" }
        return $false
    }
    Write-Host "[$CaseName] PASS"
    return $true
}

# --- Main --------------------------------------------------------------------
if (Test-Path $resultPath) { Remove-Item $resultPath -Force }
New-Item -ItemType File -Path $resultPath | Out-Null

$overallPass = $true
foreach ($case in $cases) {
    Write-Host "=== Running case: $($case.Name) ==="
    $repo = New-CaseRepo -CaseName $case.Name -Fixture $case.Fixture
    try {
        $r = Invoke-ActCase -CaseName $case.Name -RepoDir $repo

        # Append a clearly delimited block per case for post-mortem.
        Add-Content -LiteralPath $resultPath -Value "========== CASE: $($case.Name) =========="
        Add-Content -LiteralPath $resultPath -Value "exit=$($r.ExitCode)"
        Add-Content -LiteralPath $resultPath -Value $r.Output
        Add-Content -LiteralPath $resultPath -Value ""

        $ok = Assert-Case -CaseName $case.Name -ExitCode $r.ExitCode `
                          -Output $r.Output -Expected $case.Expected
        if (-not $ok) { $overallPass = $false }
    } finally {
        Remove-Item -Recurse -Force -Path $repo -ErrorAction SilentlyContinue
    }
}

if ($overallPass) {
    Write-Host "`nAll act cases passed. See $resultPath for full output."
    exit 0
} else {
    Write-Host "`nOne or more act cases failed. See $resultPath for full output."
    exit 1
}
