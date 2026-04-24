# Run-ActTests.ps1
# Test harness: copies project into a temp git repo, runs act push --rm,
# saves output to act-result.txt, and asserts exact expected values.

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$ResultFile  = Join-Path $ProjectRoot "act-result.txt"

# Remove stale result file
if (Test-Path $ResultFile) { Remove-Item $ResultFile -Force }

# Validate actionlint passes on the host before spending time on act
Write-Host "=== Validating workflow with actionlint ==="
$alOut = & actionlint (Join-Path $ProjectRoot ".github/workflows/environment-matrix-generator.yml") 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "actionlint failed:`n$alOut"
    exit 1
}
Write-Host "actionlint: PASS"

# Set up a temporary git repository containing all project files
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "matrix-gen-test-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir | Out-Null
Write-Host "Temp repo: $TempDir"

try {
    # Copy project files into the temp repo
    foreach ($item in @("New-EnvironmentMatrix.ps1", "New-EnvironmentMatrix.Tests.ps1", "fixtures", ".github")) {
        $src = Join-Path $ProjectRoot $item
        if (Test-Path -PathType Container $src) {
            Copy-Item -Recurse $src (Join-Path $TempDir $item)
        } else {
            Copy-Item $src $TempDir
        }
    }

    # Copy .actrc so act uses the custom image
    $actrc = Join-Path $ProjectRoot ".actrc"
    if (Test-Path $actrc) {
        Copy-Item $actrc $TempDir
    }

    Push-Location $TempDir
    try {
        & git init --quiet
        & git config user.email "test@test.com"
        & git config user.name "Test"
        & git add -A
        & git commit --quiet -m "test: run environment matrix generator"

        Write-Host "=== Running act push --rm ==="
        $actOutput = & act push --rm --pull=false 2>&1
        $actExitCode = $LASTEXITCODE

        # Persist output regardless of pass/fail
        "=== ACT RUN: push ===" | Set-Content $ResultFile
        $actOutput | Add-Content $ResultFile
        "=== END ACT RUN ===" | Add-Content $ResultFile

        # Show output for debugging
        $actOutput | ForEach-Object { Write-Host $_ }

        # Assert act succeeded
        if ($actExitCode -ne 0) {
            Write-Error "act push exited with code $actExitCode"
            exit 1
        }

        $outputStr = $actOutput -join "`n"

        # Assert job succeeded
        if ($outputStr -notmatch "Job succeeded") {
            Write-Error "Expected 'Job succeeded' in act output"
            exit 1
        }

        # Assert exact values from the basic matrix step
        $exactChecks = @(
            "BASIC_COMPUTED_COUNT=4",
            "BASIC_MAX_PARALLEL=4",
            "BASIC_FAIL_FAST=False",
            "BASIC_OS_COUNT=2",
            "BASIC_NODE_COUNT=2",
            "RULES_COMPUTED_COUNT=6",
            "RULES_MAX_PARALLEL=2",
            "RULES_FAIL_FAST=True",
            "RULES_INCLUDE_COUNT=1",
            "RULES_EXCLUDE_COUNT=1",
            "TOO_LARGE_VALIDATION=PASS"
        )

        foreach ($check in $exactChecks) {
            if (-not $outputStr.Contains($check)) {
                Write-Error "Expected '$check' not found in act output"
                exit 1
            }
            Write-Host "ASSERT OK: $check"
        }

        Write-Host ""
        Write-Host "=== All act assertions passed ==="

    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}
