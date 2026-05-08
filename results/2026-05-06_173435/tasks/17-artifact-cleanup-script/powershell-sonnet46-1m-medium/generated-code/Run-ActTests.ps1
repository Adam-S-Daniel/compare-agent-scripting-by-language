# Run-ActTests.ps1
# Test harness: runs the GitHub Actions workflow via act for each test case,
# captures output to act-result.txt, and asserts on exact expected values.

param(
    [switch]$KeepTemp  # keep temp dirs for debugging
)

$ErrorActionPreference = "Stop"
$WorkspaceRoot  = $PSScriptRoot
$ActResultFile  = Join-Path $WorkspaceRoot "act-result.txt"

# Clear (or create) the result file
"" | Set-Content $ActResultFile

# ─── Helpers ─────────────────────────────────────────────────────────────────

function Write-Result {
    param([string]$Text)
    $Text | Add-Content $ActResultFile
    Write-Host $Text
}

function Assert-Contains {
    param([string]$Output, [string]$Pattern, [string]$CaseName)
    # Strip ANSI escape codes before matching
    $clean = $Output -replace '\x1B\[[0-9;]*[mKHF]', ''
    if ($clean -notmatch [regex]::Escape($Pattern)) {
        throw "ASSERTION FAILED in '$CaseName': expected pattern not found`n  Pattern: $Pattern"
    }
}

function Run-ActTestCase {
    param(
        [string]$CaseName,
        # Extra files to write into the temp repo: hashtable of relPath -> content
        [hashtable]$ExtraFiles = @{},
        # Exact strings that must appear in act output
        [string[]]$ExpectedPatterns
    )

    Write-Result ""
    Write-Result "============================================================"
    Write-Result "TEST CASE: $CaseName"
    Write-Result "============================================================"

    # Create an isolated temp directory outside the workspace
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Copy all project files (including hidden files like .actrc and .github/)
        Get-ChildItem -Path $WorkspaceRoot -Force |
            Where-Object { $_.Name -notin @("act-result.txt") } |
            ForEach-Object {
                $dest = Join-Path $tempDir $_.Name
                if ($_.PSIsContainer) {
                    Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
                } else {
                    Copy-Item -Path $_.FullName -Destination $dest -Force
                }
            }

        # Write any case-specific overrides
        foreach ($relPath in $ExtraFiles.Keys) {
            $fullPath = Join-Path $tempDir $relPath
            $dir = Split-Path $fullPath -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
            $ExtraFiles[$relPath] | Set-Content $fullPath
        }

        # Initialise a git repo so act can simulate a push event
        Push-Location $tempDir
        & git init -q
        & git config user.email "ci@example.com"
        & git config user.name "CI"
        & git add -A
        & git commit -q -m "ci: test commit"

        # Run act - --pull=false uses the local image without trying to pull from a registry
        Write-Result "[act] Starting: act push --rm --pull=false"
        $actOutput = & act push --rm --pull=false 2>&1 | Out-String
        $actExitCode = $LASTEXITCODE

        Write-Result $actOutput
        Write-Result "[act] Exit code: $actExitCode"

        if ($actExitCode -ne 0) {
            throw "act exited with non-zero code $actExitCode for test case: $CaseName"
        }

        # Assert "Job succeeded" appears for every job
        Assert-Contains $actOutput "Job succeeded" $CaseName

        # Assert case-specific expected patterns
        foreach ($pattern in $ExpectedPatterns) {
            Assert-Contains $actOutput $pattern $CaseName
            Write-Result "[ASSERT PASS] Pattern found: $pattern"
        }

        Write-Result "[PASS] $CaseName"
    }
    finally {
        Pop-Location
        if (-not $KeepTemp) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "[DEBUG] Temp dir kept at: $tempDir"
        }
    }
}

# ─── Test Cases ──────────────────────────────────────────────────────────────

# Test Case 1: Integration scenario with fixture data.
# Reference date 2026-05-01, maxAge=90 days:
#   artifact-old-1 (151 days) -> deleted
#   artifact-old-2 (106 days) -> deleted
#   artifact-b-old (181 days) -> deleted
#   artifact-new-1 / artifact-new-2 -> retained
# Expected: 3 deleted, 2 retained, 35.00 MB reclaimed
Run-ActTestCase `
    -CaseName "Integration: fixture data with all three policies" `
    -ExpectedPatterns @(
        "Failed: 0",           # all Pester tests passed (actionlint test skips in container)
        "Artifacts to delete: 3",
        "Artifacts to retain: 2",
        "Space to reclaim: 35.00 MB"
    )

Write-Result ""
Write-Result "============================================================"
Write-Result "ALL TEST CASES PASSED"
Write-Result "============================================================"
Write-Host "act-result.txt written to: $ActResultFile"
