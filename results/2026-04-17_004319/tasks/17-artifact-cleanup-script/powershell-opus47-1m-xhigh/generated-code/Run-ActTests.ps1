# Run-ActTests.ps1
#
# End-to-end harness: drives the artifact-cleanup workflow under `act` with
# multiple fixture scenarios and asserts the exact RESULT line produced.
#
# Per the task spec:
#   * Each test case sets up an isolated temp git repo with project files +
#     a case-specific fixture, runs `act push --rm`, and captures output.
#   * All output is appended to act-result.txt in the current directory,
#     clearly delimited between cases.
#   * We assert act exited 0, that the parsed RESULT matches expected
#     values exactly, and that every job shows "Job succeeded".
#   * We also validate workflow structure (actionlint, YAML parse).
#
# The RESULT format emitted by Invoke-Cleanup.ps1 is:
#   RESULT: deleted=<n> retained=<n> reclaimed=<bytes> total=<bytes>

[CmdletBinding()]
param(
    # If set, skip the act runs and only do structure validation.
    [switch]$StructureOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repoRoot     = $PSScriptRoot
$workflowPath = Join-Path $repoRoot '.github/workflows/artifact-cleanup-script.yml'
$resultFile   = Join-Path (Get-Location) 'act-result.txt'

# Start fresh so stale output from a prior run can't confuse assertions.
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
New-Item -ItemType File -Path $resultFile -Force | Out-Null

$failures = New-Object System.Collections.Generic.List[string]

function Write-Section {
    param([string]$Title)
    $banner = "`n======================================================================`n$Title`n======================================================================`n"
    Write-Host $banner
    Add-Content -Path $resultFile -Value $banner
}

function Assert-Condition {
    param(
        [string]$Label,
        [bool]$Condition,
        [string]$Detail = ''
    )
    if ($Condition) {
        Write-Host "  PASS: $Label"
        Add-Content -Path $resultFile -Value "  PASS: $Label"
    } else {
        Write-Host "  FAIL: $Label  $Detail" -ForegroundColor Red
        Add-Content -Path $resultFile -Value "  FAIL: $Label  $Detail"
        $failures.Add("$Label $Detail")
    }
}

# -------------------------------------------------------------------------
# Part 1 — workflow structure tests (fast, no act).
# -------------------------------------------------------------------------
Write-Section 'Structure tests'

# actionlint exit code 0 is a precondition for anything else.
Write-Host 'Running actionlint...'
$alOut = & actionlint $workflowPath 2>&1 | Out-String
Add-Content -Path $resultFile -Value $alOut
Assert-Condition -Label 'actionlint exits 0' -Condition ($LASTEXITCODE -eq 0) -Detail $alOut

# Parse the YAML. pwsh 7 has no built-in YAML parser, so we use a minimal
# string-level check against the known structure. ConvertFrom-Yaml is not
# available without the powershell-yaml module, so we assert expected tokens.
$yaml = Get-Content -LiteralPath $workflowPath -Raw
Assert-Condition -Label 'workflow has push trigger'              -Condition ($yaml -match '(?m)^\s*push:')
Assert-Condition -Label 'workflow has pull_request trigger'      -Condition ($yaml -match '(?m)^\s*pull_request:')
Assert-Condition -Label 'workflow has schedule trigger'          -Condition ($yaml -match '(?m)^\s*schedule:')
Assert-Condition -Label 'workflow has workflow_dispatch trigger' -Condition ($yaml -match '(?m)^\s*workflow_dispatch:')
Assert-Condition -Label 'workflow has tests job'                 -Condition ($yaml -match '(?m)^\s*tests:')
Assert-Condition -Label 'workflow has cleanup job'               -Condition ($yaml -match '(?m)^\s*cleanup:')
Assert-Condition -Label 'cleanup needs tests'                    -Condition ($yaml -match 'needs:\s*tests')
Assert-Condition -Label 'uses actions/checkout@v4'               -Condition ($yaml -match 'actions/checkout@v4')
Assert-Condition -Label 'uses shell: pwsh'                       -Condition ($yaml -match 'shell:\s*pwsh')

# Referenced script files must exist on disk.
Assert-Condition -Label 'Invoke-Cleanup.ps1 referenced and present' `
    -Condition (($yaml -match 'Invoke-Cleanup\.ps1') -and (Test-Path (Join-Path $repoRoot 'Invoke-Cleanup.ps1')))
Assert-Condition -Label 'ArtifactCleanup.Tests.ps1 referenced and present' `
    -Condition (($yaml -match 'ArtifactCleanup\.Tests\.ps1') -and (Test-Path (Join-Path $repoRoot 'ArtifactCleanup.Tests.ps1')))
Assert-Condition -Label 'ArtifactCleanup.psm1 present' `
    -Condition (Test-Path (Join-Path $repoRoot 'ArtifactCleanup.psm1'))

if ($StructureOnly) {
    if ($failures.Count -gt 0) {
        Write-Host "`n$($failures.Count) structure failure(s)." -ForegroundColor Red
        exit 1
    }
    Write-Host "`nStructure-only run complete."
    exit 0
}

# -------------------------------------------------------------------------
# Part 2 — functional tests via `act`.
# -------------------------------------------------------------------------

# Each test case is self-contained: its own artifacts + policy + expected
# RESULT values. Expected values were computed by hand from the policy
# semantics documented in ArtifactCleanup.psm1.
$testCases = @(
    @{
        Name   = 'age-only'
        Policy = @{ maxAgeDays = 30; maxTotalSizeBytes = 0; keepLatestNPerWorkflow = 0; now = '2026-04-17T00:00:00Z' }
        Artifacts = @(
            @{ id = 1; name = 'build-w1-old';     sizeBytes = 1048576; createdAt = '2026-01-15T10:00:00Z'; workflowId = 'build' },
            @{ id = 2; name = 'build-w1-older';   sizeBytes = 2097152; createdAt = '2025-12-20T10:00:00Z'; workflowId = 'build' },
            @{ id = 3; name = 'build-w1-ancient'; sizeBytes = 5242880; createdAt = '2025-10-01T10:00:00Z'; workflowId = 'build' },
            @{ id = 4; name = 'build-w1-newest';  sizeBytes = 524288;  createdAt = '2026-04-10T10:00:00Z'; workflowId = 'build' },
            @{ id = 5; name = 'test-latest';      sizeBytes = 1048576; createdAt = '2026-04-15T10:00:00Z'; workflowId = 'test'  },
            @{ id = 6; name = 'test-old';         sizeBytes = 3145728; createdAt = '2026-01-01T10:00:00Z'; workflowId = 'test'  }
        )
        # Age cutoff = 2026-03-18. Ids 1,2,3,6 older => 4 deleted, 2 retained.
        # Reclaimed = 1048576 + 2097152 + 5242880 + 3145728 = 11534336.
        Expected = @{ deleted = 4; retained = 2; reclaimed = 11534336; total = 13107200 }
    },
    @{
        Name   = 'keep-latest-n'
        Policy = @{ maxAgeDays = 30; maxTotalSizeBytes = 0; keepLatestNPerWorkflow = 2; now = '2026-04-17T00:00:00Z' }
        Artifacts = @(
            @{ id = 1; name = 'build-w1-old';     sizeBytes = 1048576; createdAt = '2026-01-15T10:00:00Z'; workflowId = 'build' },
            @{ id = 2; name = 'build-w1-older';   sizeBytes = 2097152; createdAt = '2025-12-20T10:00:00Z'; workflowId = 'build' },
            @{ id = 3; name = 'build-w1-ancient'; sizeBytes = 5242880; createdAt = '2025-10-01T10:00:00Z'; workflowId = 'build' },
            @{ id = 4; name = 'build-w1-newest';  sizeBytes = 524288;  createdAt = '2026-04-10T10:00:00Z'; workflowId = 'build' },
            @{ id = 5; name = 'test-latest';      sizeBytes = 1048576; createdAt = '2026-04-15T10:00:00Z'; workflowId = 'test'  },
            @{ id = 6; name = 'test-old';         sizeBytes = 3145728; createdAt = '2026-01-01T10:00:00Z'; workflowId = 'test'  }
        )
        # build: newest-2 = {id=4, id=1}. test: newest-2 = {id=5, id=6} (both).
        # Only ids 2 and 3 can still be deleted by age. 2 deleted, 4 retained.
        # Reclaimed = 2097152 + 5242880 = 7340032.
        Expected = @{ deleted = 2; retained = 4; reclaimed = 7340032; total = 13107200 }
    },
    @{
        Name   = 'size-cap'
        # MaxAge 365 blocks age-based deletions; size cap forces deletion of
        # oldest artifacts until retained <= 5000000 bytes.
        Policy = @{ maxAgeDays = 365; maxTotalSizeBytes = 5000000; keepLatestNPerWorkflow = 0; now = '2026-04-17T00:00:00Z' }
        Artifacts = @(
            @{ id = 1; name = 'build-w1-old';     sizeBytes = 1048576; createdAt = '2026-01-15T10:00:00Z'; workflowId = 'build' },
            @{ id = 2; name = 'build-w1-older';   sizeBytes = 2097152; createdAt = '2025-12-20T10:00:00Z'; workflowId = 'build' },
            @{ id = 3; name = 'build-w1-ancient'; sizeBytes = 5242880; createdAt = '2025-10-01T10:00:00Z'; workflowId = 'build' },
            @{ id = 4; name = 'build-w1-newest';  sizeBytes = 524288;  createdAt = '2026-04-10T10:00:00Z'; workflowId = 'build' },
            @{ id = 5; name = 'test-latest';      sizeBytes = 1048576; createdAt = '2026-04-15T10:00:00Z'; workflowId = 'test'  },
            @{ id = 6; name = 'test-old';         sizeBytes = 3145728; createdAt = '2026-01-01T10:00:00Z'; workflowId = 'test'  }
        )
        # Total = 13107200. Remove oldest-first until <= 5M:
        #   id=3 (5242880, 2025-10-01) => 7864320 still > 5M
        #   id=2 (2097152, 2025-12-20) => 5767168 still > 5M
        #   id=6 (3145728, 2026-01-01) => 2621440 <= 5M stop
        # Deleted: id=2,3,6. Reclaimed = 5242880+2097152+3145728 = 10485760.
        Expected = @{ deleted = 3; retained = 3; reclaimed = 10485760; total = 13107200 }
    }
)

foreach ($tc in $testCases) {
    Write-Section "act test case: $($tc.Name)"

    # Build an isolated temp directory so the test case's fixture cannot
    # leak into subsequent cases or the working tree.
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-" + [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        # Copy project files (but not the workspace .git or host act-result.txt).
        $itemsToCopy = @(
            'ArtifactCleanup.psm1',
            'ArtifactCleanup.Tests.ps1',
            'Invoke-Cleanup.ps1',
            '.github',
            '.actrc'
        )
        foreach ($item in $itemsToCopy) {
            $src = Join-Path $repoRoot $item
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $tmp -Recurse
            }
        }

        # Write the case-specific fixtures.
        $fixtureDir = Join-Path $tmp 'fixtures'
        New-Item -ItemType Directory -Path $fixtureDir | Out-Null
        # ConvertTo-Json treats a single-hash in an array as a nested array, so
        # force array shape with @() and Depth 5 to keep nested objects.
        $artifactsJson = ConvertTo-Json -InputObject @($tc.Artifacts) -Depth 5
        if ($tc.Artifacts.Count -eq 0) { $artifactsJson = '[]' }
        Set-Content -Path (Join-Path $fixtureDir 'artifacts.json') -Value $artifactsJson -Encoding UTF8
        ConvertTo-Json -InputObject $tc.Policy -Depth 5 |
            Set-Content -Path (Join-Path $fixtureDir 'policy.json') -Encoding UTF8

        # act requires a git repo to run `push`. Initialize one and commit.
        Push-Location $tmp
        try {
            git init --quiet --initial-branch=main
            git config user.email 'ci@example.com'
            git config user.name  'ci'
            git add -A
            git commit --quiet -m 'test fixture'

            Write-Host "Running act in $tmp ..."
            # Capture combined stdout+stderr. --rm cleans up containers.
            # --pull=false: the custom act-ubuntu-pwsh image is local only,
            # so let act use the pre-built layer instead of fetching from
            # Docker Hub (which would 404).
            $actOutput = & act push --rm --pull=false 2>&1 | Out-String
            $actExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append raw act output for audit.
        Add-Content -Path $resultFile -Value "--- act exit: $actExit ---"
        Add-Content -Path $resultFile -Value $actOutput

        Assert-Condition -Label "[$($tc.Name)] act exited 0" -Condition ($actExit -eq 0) `
            -Detail "(exit=$actExit; see $resultFile)"

        # Both jobs must report success.
        $testsJobOk   = $actOutput -match 'Job succeeded' -and $actOutput -match 'Pester unit tests'
        $cleanupJobOk = $actOutput -match 'Job succeeded' -and $actOutput -match 'Run cleanup plan'
        Assert-Condition -Label "[$($tc.Name)] tests job succeeded"   -Condition $testsJobOk
        Assert-Condition -Label "[$($tc.Name)] cleanup job succeeded" -Condition $cleanupJobOk

        # Parse the RESULT: line. Its format is stable, so a regex match is
        # sufficient.
        $resultMatch = [regex]::Match($actOutput, 'RESULT:\s+deleted=(\d+)\s+retained=(\d+)\s+reclaimed=(\d+)\s+total=(\d+)')
        Assert-Condition -Label "[$($tc.Name)] RESULT line present" -Condition $resultMatch.Success

        if ($resultMatch.Success) {
            $got = @{
                deleted   = [int]$resultMatch.Groups[1].Value
                retained  = [int]$resultMatch.Groups[2].Value
                reclaimed = [long]$resultMatch.Groups[3].Value
                total     = [long]$resultMatch.Groups[4].Value
            }
            foreach ($key in 'deleted','retained','reclaimed','total') {
                $expected = $tc.Expected[$key]
                $actual   = $got[$key]
                Assert-Condition `
                    -Label "[$($tc.Name)] $key == $expected" `
                    -Condition ($actual -eq $expected) `
                    -Detail "(got $actual)"
            }
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# -------------------------------------------------------------------------
# Summary.
# -------------------------------------------------------------------------
Write-Section 'Summary'
if ($failures.Count -eq 0) {
    Write-Host 'All act test cases PASSED.'
    Add-Content -Path $resultFile -Value 'All act test cases PASSED.'
    exit 0
} else {
    Write-Host "$($failures.Count) assertion(s) FAILED." -ForegroundColor Red
    Add-Content -Path $resultFile -Value "$($failures.Count) assertion(s) FAILED."
    $failures | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
        Add-Content -Path $resultFile -Value "  - $_"
    }
    exit 1
}
