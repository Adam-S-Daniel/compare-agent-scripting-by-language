#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Drives every fixture under tests/fixtures/ through the GitHub Actions
    workflow via `act push --rm`, asserting on the EXACT expected
    NEW_VERSION + BUMP_KIND printed by the bumper.

.DESCRIPTION
    For each fixture directory, the harness:
      1. Materialises a temporary git repo with our project files plus the
         fixture's version file.
      2. Replays the fixture's commit messages as real git commits so that
         `git log` inside the workflow sees a realistic conventional-commit
         history.
      3. Runs `act push --rm` from that temp repo, capturing all output.
      4. Appends a clearly-delimited block of that output to act-result.txt
         in the harness's invocation directory.
      5. Asserts on:
            - exit code 0
            - 'Job succeeded' present for every job
            - exact NEW_VERSION=<expected> string
            - exact BUMP_KIND=<expected> string

    The test passes only if every assertion holds for every fixture.

    Layout this expects in the project root:
      src/                       - bumper module + cli
      tests/SemverBumper.Tests.ps1
      tests/Workflow.Tests.ps1
      tests/fixtures/<name>/(VERSION|package.json), commits.json, expected.json
      .github/workflows/semantic-version-bumper.yml
      .actrc                     - pins act to the pwsh-equipped image
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ResultFile  = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'act-result.txt'),
    [string[]]$OnlyFixtures
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 78)
    Write-Host $Title
    Write-Host ('=' * 78)
}

function Add-ResultBlock {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Header,
        [Parameter(Mandatory)][string]$Body,
        [Parameter(Mandatory)][int]$ExitCode
    )
    $block = @()
    $block += ''
    $block += ('#' * 78)
    $block += "# $Header"
    $block += ('#' * 78)
    $block += $Body
    $block += "# act exit code: $ExitCode"
    $block += ('#' * 78)
    $block | Add-Content -LiteralPath $Path -Encoding utf8
}

function Initialize-FixtureRepo {
    <#
    Build a fresh git repo in $TempDir that contains the project and the
    fixture's version file, with each fixture commit message replayed as a
    real commit. We make a tiny, distinct file change per commit so the
    objects differ - empty commits work too, but real changes more closely
    match what production looks like.
    #>
    param(
        [Parameter(Mandatory)][string]$TempDir,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$FixturePath,
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][string[]]$CommitMessages
    )

    # 1. Copy project files we need into the temp dir.
    Copy-Item -Recurse -Force -Path (Join-Path $ProjectRoot 'src')             -Destination (Join-Path $TempDir 'src')
    Copy-Item -Recurse -Force -Path (Join-Path $ProjectRoot 'tests')           -Destination (Join-Path $TempDir 'tests')
    Copy-Item -Recurse -Force -Path (Join-Path $ProjectRoot '.github')         -Destination (Join-Path $TempDir '.github')
    Copy-Item -Force         -Path (Join-Path $ProjectRoot '.actrc')           -Destination (Join-Path $TempDir '.actrc')

    # 2. Place the fixture's version file at the project root inside temp.
    $versionFileName = $Expected.versionFileName
    Copy-Item -Force -Path (Join-Path $FixturePath $versionFileName) -Destination (Join-Path $TempDir $versionFileName)

    # 3. Initialise git, set identity, drop initial commit (project state).
    Push-Location -LiteralPath $TempDir
    try {
        & git init -b main --quiet 2>&1 | Out-Null
        & git config user.email 'harness@test.local'  | Out-Null
        & git config user.name  'Test Harness'        | Out-Null
        & git config commit.gpgsign false             | Out-Null

        & git add -A | Out-Null
        & git commit --quiet -m 'chore: initial harness commit' | Out-Null

        # 4. Replay fixture commits as empty commits with the conventional
        # commit message. Empty commits are fine for the bumper (it only
        # cares about the message body), and avoid having to fabricate
        # plausible diffs for each.
        foreach ($msg in $CommitMessages) {
            & git commit --quiet --allow-empty -m $msg
            if ($LASTEXITCODE -ne 0) {
                throw "git commit failed for message: $msg"
            }
        }
    }
    finally { Pop-Location }
}

function Invoke-ActOnFixture {
    param(
        [Parameter(Mandatory)][string]$TempDir
    )
    Push-Location -LiteralPath $TempDir
    try {
        # --rm: clean up containers after the run
        # 2>&1: capture stderr so failures + warnings end up in the same buffer
        $output = & act push --rm 2>&1 | Out-String
        return [pscustomobject]@{
            Output   = $output
            ExitCode = $LASTEXITCODE
        }
    }
    finally { Pop-Location }
}

function Test-Output {
    <#
    Apply the per-fixture assertions and return a list of failure strings.
    Empty list = pass.
    #>
    param(
        [Parameter(Mandatory)][string]$Output,
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][string]$FixtureName
    )
    $failures = New-Object System.Collections.Generic.List[string]

    if ($ExitCode -ne 0) {
        $failures.Add("act exit code was $ExitCode (expected 0)")
    }

    # 'Job succeeded' should appear for every job; require >= 2 occurrences
    # because the workflow defines two jobs (unit-tests + bump-version).
    $jobSucceededHits = ([regex]::Matches($Output, 'Job succeeded')).Count
    if ($jobSucceededHits -lt 2) {
        $failures.Add("Expected at least 2 'Job succeeded' lines (one per job); found $jobSucceededHits")
    }

    # Exact-string assertions on the bumper's output.
    $expectedNewLine  = "NEW_VERSION=$($Expected.new)"
    $expectedKindLine = "BUMP_KIND=$($Expected.kind)"
    $expectedOldLine  = "OLD_VERSION=$($Expected.old)"

    if ($Output -notmatch [regex]::Escape($expectedNewLine)) {
        $failures.Add("Did not find exact line '$expectedNewLine' in output")
    }
    if ($Output -notmatch [regex]::Escape($expectedKindLine)) {
        $failures.Add("Did not find exact line '$expectedKindLine' in output")
    }
    if ($Output -notmatch [regex]::Escape($expectedOldLine)) {
        $failures.Add("Did not find exact line '$expectedOldLine' in output")
    }

    return ,$failures
}

# ----------------------------------------------------------------------------
# Main flow
# ----------------------------------------------------------------------------

# Sanity: required tools
foreach ($tool in @('act', 'git', 'actionlint')) {
    if (-not (Get-Command -Name $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool '$tool' is not available on PATH."
    }
}

Write-Section "STEP 1: actionlint on workflow file"
$workflowPath = Join-Path $ProjectRoot '.github' 'workflows' 'semantic-version-bumper.yml'
$alOutput = & actionlint $workflowPath 2>&1
$alExit   = $LASTEXITCODE
Write-Host ($alOutput | Out-String)
if ($alExit -ne 0) {
    throw "actionlint failed with exit code $alExit"
}
Write-Host "actionlint: OK"

Write-Section "STEP 2: discover fixtures"
$fixtureRoot = Join-Path $ProjectRoot 'tests' 'fixtures'
$fixtures    = @(Get-ChildItem -Path $fixtureRoot -Directory | Sort-Object Name)
if ($OnlyFixtures) {
    $fixtures = @($fixtures | Where-Object { $OnlyFixtures -contains $_.Name })
}
if ($fixtures.Count -eq 0) { throw "No fixtures found under $fixtureRoot (filter: $($OnlyFixtures -join ','))" }
Write-Host ("Found {0} fixture(s): {1}" -f $fixtures.Count, (($fixtures | ForEach-Object Name) -join ', '))

# Reset act-result.txt for a fresh run.
$header = @(
    "# act test harness results"
    "# Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
    "# Project:   $ProjectRoot"
    "# Fixtures:  $($fixtures.Name -join ', ')"
    ''
)
$header | Set-Content -LiteralPath $ResultFile -Encoding utf8

$summary = New-Object System.Collections.Generic.List[object]

foreach ($fixture in $fixtures) {
    Write-Section "STEP 3: $($fixture.Name)"

    $fixturePath  = $fixture.FullName
    $expectedJson = Join-Path $fixturePath 'expected.json'
    $commitsJson  = Join-Path $fixturePath 'commits.json'

    if (-not (Test-Path $expectedJson) -or -not (Test-Path $commitsJson)) {
        throw "Fixture '$($fixture.Name)' is missing commits.json or expected.json"
    }

    $expected = Get-Content -Raw $expectedJson | ConvertFrom-Json
    # ConvertFrom-Json returns a single string for a JSON array of one item;
    # wrap with @() to guarantee an array.
    $commits  = @(Get-Content -Raw $commitsJson | ConvertFrom-Json)

    # Make a unique temp dir per fixture so failures leave artifacts behind.
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("svb-{0}-{1}" -f $fixture.Name, ([guid]::NewGuid().Guid.Substring(0,8)))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        Initialize-FixtureRepo -TempDir $tempDir `
                               -ProjectRoot $ProjectRoot `
                               -FixturePath $fixturePath `
                               -Expected $expected `
                               -CommitMessages $commits

        Write-Host "Temp repo: $tempDir"
        Write-Host "Running act ..."
        $actResult = Invoke-ActOnFixture -TempDir $tempDir

        Add-ResultBlock -Path $ResultFile `
                        -Header "FIXTURE: $($fixture.Name) | expected NEW_VERSION=$($expected.new) | exit=$($actResult.ExitCode)" `
                        -Body  $actResult.Output `
                        -ExitCode $actResult.ExitCode

        $failures = Test-Output -Output   $actResult.Output `
                                -ExitCode $actResult.ExitCode `
                                -Expected $expected `
                                -FixtureName $fixture.Name

        if ($failures.Count -eq 0) {
            Write-Host "[PASS] $($fixture.Name)" -ForegroundColor Green
            $summary.Add([pscustomobject]@{ Fixture = $fixture.Name; Pass = $true; Reason = '' })
        }
        else {
            Write-Host "[FAIL] $($fixture.Name)" -ForegroundColor Red
            foreach ($f in $failures) { Write-Host "    - $f" -ForegroundColor Red }
            $summary.Add([pscustomobject]@{
                Fixture = $fixture.Name
                Pass    = $false
                Reason  = ($failures -join '; ')
            })
        }
    }
    finally {
        # Keep the temp repo on failure for debugging? For now, always tidy.
        if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    }
}

Write-Section "SUMMARY"
$summary | Format-Table -AutoSize | Out-Host

$failedCount = @($summary | Where-Object { -not $_.Pass }).Count
if ($failedCount -gt 0) {
    Write-Host "FAILURES: $failedCount of $($summary.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "ALL FIXTURES PASSED ($($summary.Count) of $($summary.Count))" -ForegroundColor Green
Write-Host "act-result.txt: $ResultFile"
exit 0
