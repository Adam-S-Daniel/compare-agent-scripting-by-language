<#
.SYNOPSIS
    End-to-end test harness for the PR label assigner.

.DESCRIPTION
    For each fixture in ./fixtures/, this harness:
        1. Builds an isolated temp git repo containing the project files plus
           the fixture's data placed under `current-fixture/`.
        2. Runs `act push --rm` inside that repo, capturing the full output.
        3. Appends the captured output (delimited) to ./act-result.txt.
        4. Asserts:
             - act exited with code 0
             - the output contains "Job succeeded" for both jobs (test + label)
             - the labels printed between BEGIN/END markers exactly match
               the fixture's expected.txt
        5. Tears down the temp repo.

    The harness deliberately verifies behavior by parsing what flowed through
    the GitHub Actions pipeline (via act) rather than by calling Get-PrLabels.ps1
    directly, satisfying the "all tests must run through act" requirement.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string]$ResultFile  = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'

# Reset the act-result file at the start of each harness run so consumers see
# only the latest run's output (otherwise it grows unbounded across runs).
"=== act-result.txt - generated $(Get-Date -Format o) ===" | Set-Content -Path $ResultFile -Encoding utf8

$fixturesDir = Join-Path $ProjectRoot 'fixtures'
if (-not (Test-Path $fixturesDir)) {
    throw "Fixtures directory not found: $fixturesDir"
}

# Files copied verbatim into each ephemeral test repo. Glob-list them so adding
# a new file (e.g. another helper) is a single line change here.
$projectFiles = @(
    'Get-PrLabels.ps1',
    'tests',
    '.github',
    '.actrc'
)

$allCases = Get-ChildItem -Path $fixturesDir -Directory | Sort-Object Name
if ($allCases.Count -eq 0) {
    throw "No fixtures found under $fixturesDir"
}

Write-Host "Running $($allCases.Count) test case(s) through act..." -ForegroundColor Cyan

$failures = New-Object System.Collections.Generic.List[string]

foreach ($case in $allCases) {
    $caseName = $case.Name
    Write-Host "`n=== Test case: $caseName ===" -ForegroundColor Yellow

    # 1. Materialize a temp git repo for this case.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-pr-label-$caseName-" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmp | Out-Null

    try {
        # Copy project files in.
        foreach ($f in $projectFiles) {
            $src = Join-Path $ProjectRoot $f
            if (-not (Test-Path $src)) { continue }
            # Recurse for directories, plain copy for files.
            Copy-Item -Path $src -Destination $tmp -Recurse -Force
        }

        # Copy the fixture's contents into current-fixture/.
        $fixDest = Join-Path $tmp 'current-fixture'
        New-Item -ItemType Directory -Path $fixDest | Out-Null
        Get-ChildItem -Path $case.FullName -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $fixDest -Force
        }

        # Initialize a git repo - act requires one in order to run a push event.
        Push-Location $tmp
        try {
            & git init -q -b main 2>&1 | Out-Null
            & git config user.email 'harness@example.com' 2>&1 | Out-Null
            & git config user.name  'harness' 2>&1 | Out-Null
            & git add -A 2>&1 | Out-Null
            & git commit -q -m "fixture $caseName" 2>&1 | Out-Null

            # 2. Run act. --rm cleans up the container after each job;
            #    --pull=false stops act from trying to pull the locally-built
            #    `act-ubuntu-pwsh:latest` image from Docker Hub (it lives only
            #    in the local daemon).
            $actOutput = & act push --rm --pull=false 2>&1
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # 3. Append delimited output to act-result.txt.
        Add-Content -Path $ResultFile -Value "`n=========================================="
        Add-Content -Path $ResultFile -Value "TEST CASE: $caseName"
        Add-Content -Path $ResultFile -Value "ACT EXIT CODE: $actExit"
        Add-Content -Path $ResultFile -Value "=========================================="
        Add-Content -Path $ResultFile -Value ($actOutput -join "`n")

        # 4. Assertions.
        $caseFailed = $false
        $reason = @()

        if ($actExit -ne 0) {
            $caseFailed = $true
            $reason += "act exited with $actExit (expected 0)"
        }

        # Each job emits "Job succeeded" on success. We expect at least 2
        # (one per job: test + label).
        $jobSucceededCount = ($actOutput | Select-String -SimpleMatch 'Job succeeded').Count
        if ($jobSucceededCount -lt 2) {
            $caseFailed = $true
            $reason += "expected >=2 'Job succeeded' lines, found $jobSucceededCount"
        }

        # Extract labels between BEGIN/END markers.
        $joined = $actOutput -join "`n"
        $beginIdx = $joined.IndexOf('===PR_LABELS_BEGIN===')
        $endIdx   = $joined.IndexOf('===PR_LABELS_END===')
        $actualLabels = @()
        if ($beginIdx -ge 0 -and $endIdx -gt $beginIdx) {
            $section = $joined.Substring($beginIdx + '===PR_LABELS_BEGIN==='.Length, $endIdx - $beginIdx - '===PR_LABELS_BEGIN==='.Length)
            # Each label line in act output looks like "| <label>" - strip the
            # act log prefix ("[Workflow/Job] | ") down to the actual content.
            $actualLabels = $section -split "`n" |
                ForEach-Object {
                    # Remove act's " | " log prefix (everything up to and including "| ").
                    if ($_ -match '\|\s*(.*)$') { $matches[1].Trim() } else { $_.Trim() }
                } |
                Where-Object { $_ -ne '' -and $_ -notmatch '^\[' }
        } else {
            $caseFailed = $true
            $reason += "PR_LABELS markers not found in output"
        }

        $expectedPath = Join-Path $case.FullName 'expected.txt'
        $expectedLabels = @(Get-Content -Path $expectedPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

        # Compare ordered (priority ordering matters).
        $expectedJoined = ($expectedLabels -join ',')
        $actualJoined   = ($actualLabels   -join ',')
        if ($expectedJoined -ne $actualJoined) {
            $caseFailed = $true
            $reason += "label mismatch: expected=[$expectedJoined] actual=[$actualJoined]"
        }

        $verdict = if ($caseFailed) { 'FAIL' } else { 'PASS' }
        $color   = if ($caseFailed) { 'Red'  } else { 'Green' }

        $summary = "[$verdict] $caseName : exit=$actExit succeededJobs=$jobSucceededCount labels=[$actualJoined]"
        Add-Content -Path $ResultFile -Value "`n$summary"
        if ($caseFailed) { Add-Content -Path $ResultFile -Value ("REASON: " + ($reason -join '; ')) }

        Write-Host $summary -ForegroundColor $color
        if ($caseFailed) {
            $failures.Add("${caseName}: " + ($reason -join '; ')) | Out-Null
        }
    } finally {
        # Always clean up the temp repo so a failed run doesn't leave clutter.
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host ("FAILED ({0}/{1} cases):" -f $failures.Count, $allCases.Count) -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    Add-Content -Path $ResultFile -Value "`n=== HARNESS FAILED: $($failures.Count) of $($allCases.Count) cases failed ==="
    exit 1
} else {
    Write-Host ("PASSED all {0} cases." -f $allCases.Count) -ForegroundColor Green
    Add-Content -Path $ResultFile -Value "`n=== HARNESS PASSED: all $($allCases.Count) cases succeeded ==="
    exit 0
}
