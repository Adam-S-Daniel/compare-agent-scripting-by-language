#!/usr/bin/env pwsh
# Invoke-ActTests.ps1
# End-to-end test harness: for each fixture, spin up an isolated temp git
# repo containing the full project, run the GitHub Actions workflow via
# `act`, and assert the workflow's printed cleanup plan matches the
# fixture's 'expected' block exactly.
#
# Also validates workflow structure (actionlint + YAML parse + expected
# jobs/steps) before invoking act.
#
# Produces act-result.txt in the repo root — one act run per test case,
# each clearly delimited. The file is a required artifact.

[CmdletBinding()]
param(
    # Optional: override which fixtures to run. Defaults to a set of three
    # fixtures covering each individual policy and the full combination.
    [string[]]$Fixtures = @('age-policy.json', 'size-policy.json', 'combined-policies.json')
)

$ErrorActionPreference = 'Stop'

# Paths are resolved relative to the workspace root (parent of tests/).
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ResultFile  = Join-Path $ProjectRoot 'act-result.txt'
$WorkflowFile = Join-Path $ProjectRoot '.github/workflows/artifact-cleanup-script.yml'

if (Test-Path -LiteralPath $ResultFile) { Remove-Item -LiteralPath $ResultFile -Force }

$failures = New-Object System.Collections.Generic.List[string]

function Write-Banner($text) {
    $line = '=' * 70
    Write-Host ""
    Write-Host $line
    Write-Host $text
    Write-Host $line
}

function Append-Result($text) {
    Add-Content -LiteralPath $ResultFile -Value $text
}

# ------------------------------------------------------------------
# 1. WORKFLOW STRUCTURE TESTS
# ------------------------------------------------------------------
Write-Banner 'Structure tests'

if (-not (Test-Path -LiteralPath $WorkflowFile)) {
    throw "Workflow file missing: $WorkflowFile"
}
Write-Host "[OK] workflow file exists: $WorkflowFile"

# Parse the YAML and verify structure. We don't have a YAML parser module
# guaranteed, so do a lightweight text inspection backed by `actionlint`
# for the real syntactic check.
$yaml = Get-Content -LiteralPath $WorkflowFile -Raw
$expectedAnchors = @(
    '(?m)^name:',
    '(?m)^on:',
    '(?m)^\s*push:',
    '(?m)^\s*pull_request:',
    '(?m)^\s*schedule:',
    '(?m)^\s*workflow_dispatch:',
    '(?m)^permissions:',
    '(?m)^jobs:',
    'unit-tests:',
    'cleanup-plan:',
    'actions/checkout@v4',
    'Invoke-Cleanup\.ps1',
    'Invoke-Pester'
)
foreach ($anchor in $expectedAnchors) {
    if ($yaml -notmatch $anchor) {
        $failures.Add("Workflow missing expected anchor: $anchor") | Out-Null
    } else {
        Write-Host "[OK] workflow contains '$anchor'"
    }
}

# Verify referenced files actually exist.
$scriptFiles = @(
    (Join-Path $ProjectRoot 'Invoke-Cleanup.ps1'),
    (Join-Path $ProjectRoot 'ArtifactCleanup.psm1'),
    (Join-Path $ProjectRoot 'tests/ArtifactCleanup.Tests.ps1')
)
foreach ($f in $scriptFiles) {
    if (-not (Test-Path -LiteralPath $f)) {
        $failures.Add("Referenced script missing: $f") | Out-Null
    } else {
        Write-Host "[OK] script file exists: $f"
    }
}

Write-Host ""
Write-Host "Running actionlint..."
$actionlintOut = & actionlint $WorkflowFile 2>&1
$actionlintCode = $LASTEXITCODE
if ($actionlintCode -ne 0) {
    $failures.Add("actionlint failed: $actionlintOut") | Out-Null
    Write-Host "actionlint output: $actionlintOut"
} else {
    Write-Host "[OK] actionlint passed"
}

# Fixture structure sanity — each fixture must have an 'expected' block.
foreach ($fx in $Fixtures) {
    $path = Join-Path $ProjectRoot "fixtures/$fx"
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Fixture missing: $path") | Out-Null
        continue
    }
    $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if (-not $doc.PSObject.Properties.Name.Contains('expected')) {
        $failures.Add("Fixture $fx missing 'expected' block") | Out-Null
    } else {
        Write-Host "[OK] fixture $fx has expected block"
    }
}

# ------------------------------------------------------------------
# 2. ACT RUNS — one per fixture
# ------------------------------------------------------------------
Write-Banner 'Act runs'

function New-TempRepoFrom($source) {
    # Copy the project into a throwaway directory + git init it, so each act
    # run uses a pristine tree. This matches the instruction to "set up a
    # temp git repo with your project files + that case's fixture data".
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-harness-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    $exclude = @('act-result.txt', '.git')
    Get-ChildItem -LiteralPath $source -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $tmp -Recurse -Force
    }

    Push-Location $tmp
    try {
        # Minimal git repo — act needs SHA + branch metadata to run push-event jobs.
        & git init -q
        & git -c user.email=test@example.com -c user.name=test checkout -q -b main 2>$null
        & git -c user.email=test@example.com -c user.name=test add . | Out-Null
        & git -c user.email=test@example.com -c user.name=test commit -q -m 'harness' | Out-Null
    } finally {
        Pop-Location
    }
    return $tmp
}

function Invoke-ActOnce($fixture, $expected) {
    $repo = New-TempRepoFrom $ProjectRoot
    Write-Host "[run] fixture=$fixture in $repo"

    $delim = "=" * 72
    Append-Result ""
    Append-Result $delim
    Append-Result "TEST CASE: $fixture"
    Append-Result "TMP REPO:  $repo"
    Append-Result $delim

    Push-Location $repo
    try {
        # --pull=false: use the locally-built act-ubuntu-pwsh image without
        # attempting a registry fetch (it only lives on this host).
        $actOut = & act push --rm --pull=false --env "FIXTURE=$fixture" --env "DRY_RUN=true" 2>&1 | Out-String
        $actCode = $LASTEXITCODE
        Append-Result $actOut
        Append-Result ""
        Append-Result "ACT EXIT CODE: $actCode"
    } finally {
        Pop-Location
        # Leave the temp repo behind only on failure so it can be inspected.
    }

    # Assertions.
    $errs = New-Object System.Collections.Generic.List[string]

    if ($actCode -ne 0) {
        $errs.Add("act exit code was $actCode (expected 0)") | Out-Null
    }

    # Every job should report 'Job succeeded' (act's line format).
    $jobsSucceeded = ([regex]::Matches($actOut, 'Job succeeded')).Count
    if ($jobsSucceeded -lt 2) {
        $errs.Add("expected 2 'Job succeeded' lines (unit-tests + cleanup-plan), got $jobsSucceeded") | Out-Null
    }

    # Extract the machine-readable plan block and parse the key/value pairs.
    $planMatch = [regex]::Match($actOut, '===CLEANUP-PLAN-BEGIN===(?<body>.*?)===CLEANUP-PLAN-END===', 'Singleline')
    if (-not $planMatch.Success) {
        $errs.Add('CLEANUP-PLAN block not found in act output') | Out-Null
    } else {
        $body = $planMatch.Groups['body'].Value
        $kv = @{}
        foreach ($line in $body -split "`n") {
            # act formats log lines as `[workflow/job] | KEY=VAL` so strip
            # anything up to the first KEY=VAL on the line.
            $m = [regex]::Match($line, '([A-Z_]+)=([^\s]*)\s*$')
            if ($m.Success) { $kv[$m.Groups[1].Value] = $m.Groups[2].Value }
        }

        function Check($key, $want, [ref]$errs) {
            $got = $kv[$key]
            if ($got -ne "$want") {
                $errs.Value.Add("expected ${key}='$want', got '$got'") | Out-Null
            } else {
                Write-Host "  [OK] $key=$got"
            }
        }

        Check 'DELETED'              $expected.deleted              ([ref]$errs)
        Check 'RETAINED'             $expected.retained             ([ref]$errs)
        Check 'RECLAIMED_BYTES'      $expected.reclaimedBytes       ([ref]$errs)
        Check 'RETAINED_BYTES'       $expected.retainedBytes        ([ref]$errs)
        Check 'REASONS_MAXAGE'       $expected.reasonsMaxAge        ([ref]$errs)
        Check 'REASONS_MAXTOTALSIZE' $expected.reasonsMaxTotalSize  ([ref]$errs)
        Check 'REASONS_KEEPLATESTN'  $expected.reasonsKeepLatestN   ([ref]$errs)
        Check 'DELETED_IDS'          $expected.deletedIds           ([ref]$errs)
        Check 'DRY_RUN'              'true'                         ([ref]$errs)
    }

    if ($errs.Count -gt 0) {
        foreach ($e in $errs) { Write-Host "  [FAIL] $e" }
        return [pscustomobject]@{ Fixture = $fixture; Ok = $false; Errors = $errs; Repo = $repo }
    } else {
        # Success: delete the temp repo.
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Fixture = $fixture; Ok = $true; Errors = @(); Repo = $repo }
    }
}

$allResults = New-Object System.Collections.Generic.List[object]

foreach ($fx in $Fixtures) {
    $fixturePath = Join-Path $ProjectRoot "fixtures/$fx"
    $doc = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $result = Invoke-ActOnce $fx $doc.expected
    $allResults.Add($result) | Out-Null
    if (-not $result.Ok) {
        foreach ($e in $result.Errors) { $failures.Add("[$fx] $e") | Out-Null }
    }
}

# ------------------------------------------------------------------
# 3. SUMMARY
# ------------------------------------------------------------------
Write-Banner 'Summary'

$passed = ($allResults | Where-Object { $_.Ok }).Count
$failed = ($allResults | Where-Object { -not $_.Ok }).Count
Write-Host "act cases: $passed passed / $failed failed"
Write-Host "structure failures: $($failures.Count - $failed)"

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}

Write-Host ""
Write-Host "All test cases passed. act-result.txt written to $ResultFile"
exit 0
