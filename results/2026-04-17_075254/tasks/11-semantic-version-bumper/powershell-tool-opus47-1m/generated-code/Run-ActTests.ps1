# End-to-end test harness: runs every fixture case through `act push`,
# captures output to act-result.txt, and asserts on exact expected values.
#
# Constraint: <= 3 `act push` runs. We loop over cases by rewriting the
# workflow's default env to point at the relevant fixture before each run.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workflowPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
$resultFile   = Join-Path $PSScriptRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# Workflow structure tests (read fast, no act needed).
Write-Host '=== Workflow structure tests ==='
if (-not (Test-Path $workflowPath)) { throw "Workflow not found: $workflowPath" }
$wfText = Get-Content $workflowPath -Raw
if ($wfText -notmatch 'actions/checkout@v4') { throw 'Workflow missing actions/checkout@v4' }
if ($wfText -notmatch 'shell:\s*pwsh')       { throw 'Workflow missing shell: pwsh' }
if ($wfText -notmatch 'bump-version\.ps1')   { throw 'Workflow does not reference bump-version.ps1' }
if ($wfText -notmatch 'Invoke-Pester')       { throw 'Workflow does not run Pester' }
foreach ($p in @(
    'bump-version.ps1',
    'SemanticVersionBumper.psm1',
    'SemanticVersionBumper.Tests.ps1',
    'fixtures/package.json'
)) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $p))) { throw "Referenced path missing: $p" }
}
Write-Host '  Workflow structure: OK'

Write-Host '=== actionlint ==='
& actionlint $workflowPath
if ($LASTEXITCODE -ne 0) { throw 'actionlint failed' }
Write-Host '  actionlint: OK'

# Test cases: each case mutates the workflow's env defaults, runs `act push`,
# and asserts on captured stdout. Three cases = three act runs (the cap).
$cases = @(
    @{
        Name           = 'feat-and-fix-bumps-minor'
        VersionFile    = 'fixtures/package.json'   # version 1.1.0
        CommitsFile    = 'fixtures/commits-feat.txt'
        ExpectedNew    = '1.2.0'
        ExpectedBump   = 'minor'
        ExpectedPrev   = '1.1.0'
        ChangelogMatch = 'add user login flow'
    },
    @{
        Name           = 'fix-only-bumps-patch'
        VersionFile    = 'fixtures/package.json'
        CommitsFile    = 'fixtures/commits-fix.txt'
        ExpectedNew    = '1.1.1'
        ExpectedBump   = 'patch'
        ExpectedPrev   = '1.1.0'
        ChangelogMatch = 'prevent crash on empty input'
    },
    @{
        Name           = 'breaking-bumps-major'
        VersionFile    = 'fixtures/package.json'
        CommitsFile    = 'fixtures/commits-breaking.txt'
        ExpectedNew    = '2.0.0'
        ExpectedBump   = 'major'
        ExpectedPrev   = '1.1.0'
        ChangelogMatch = 'rewrite public API'
    }
)

$failures = @()

foreach ($c in $cases) {
    Write-Host ""
    Write-Host "=== Running case: $($c.Name) ==="

    $delim = "`n========== CASE: $($c.Name) ==========`n"
    Add-Content -LiteralPath $resultFile -Value $delim

    $actLog = Join-Path ([System.IO.Path]::GetTempPath()) "act-$($c.Name).log"
    # Pass fixture selection via --env so we don't have to mutate the workflow
    # for each case (the workflow reads $env:VERSION_FILE / $env:COMMITS_FILE).
    $actArgs = @(
        'push','--rm',
        '--env', "VERSION_FILE=$($c.VersionFile)",
        '--env', "COMMITS_FILE=$($c.CommitsFile)"
    )
    $proc = Start-Process -FilePath act -ArgumentList $actArgs `
        -WorkingDirectory $PSScriptRoot `
        -RedirectStandardOutput $actLog `
        -RedirectStandardError "$actLog.err" `
        -NoNewWindow -PassThru -Wait
    $stdout = if (Test-Path $actLog) { Get-Content $actLog -Raw } else { '' }
    $stderr = if (Test-Path "$actLog.err") { Get-Content "$actLog.err" -Raw } else { '' }
    $combined = "$stdout`n--- STDERR ---`n$stderr"
    Add-Content -LiteralPath $resultFile -Value $combined

    # Assertions
    if ($proc.ExitCode -ne 0) {
        $failures += "[$($c.Name)] act exit code $($proc.ExitCode)"
        continue
    }
    if ($combined -notmatch 'Job succeeded') {
        $failures += "[$($c.Name)] missing 'Job succeeded' marker"
    }
    # Assert on the script's stdout lines AND the GITHUB_OUTPUT-derived RESULT_* lines.
    if ($combined -notmatch [regex]::Escape("NEW_VERSION=$($c.ExpectedNew)")) {
        $failures += "[$($c.Name)] expected NEW_VERSION=$($c.ExpectedNew) not found"
    }
    if ($combined -notmatch [regex]::Escape("BUMP_TYPE=$($c.ExpectedBump)")) {
        $failures += "[$($c.Name)] expected BUMP_TYPE=$($c.ExpectedBump) not found"
    }
    if ($combined -notmatch [regex]::Escape("PREVIOUS_VERSION=$($c.ExpectedPrev)")) {
        $failures += "[$($c.Name)] expected PREVIOUS_VERSION=$($c.ExpectedPrev) not found"
    }
    if ($combined -notmatch [regex]::Escape("RESULT_NEW=$($c.ExpectedNew)")) {
        $failures += "[$($c.Name)] expected RESULT_NEW=$($c.ExpectedNew) not found"
    }
    if ($combined -notmatch [regex]::Escape($c.ChangelogMatch)) {
        $failures += "[$($c.Name)] changelog content '$($c.ChangelogMatch)' not found"
    }
    Write-Host "  exit=$($proc.ExitCode) -- assertions checked"
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host '=== FAILURES ===' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host '=== ALL ACT TESTS PASSED ===' -ForegroundColor Green
