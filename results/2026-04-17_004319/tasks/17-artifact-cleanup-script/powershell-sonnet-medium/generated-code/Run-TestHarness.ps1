# Run-TestHarness.ps1 — Integration test harness
#
# Copies project files into an isolated git repo, runs the GitHub Actions
# workflow via `act push --rm`, captures output to act-result.txt, and
# asserts exact expected values from the verification steps.
#
# Usage: pwsh ./Run-TestHarness.ps1

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$actResultPath = Join-Path $projectRoot "act-result.txt"

# ── Helper ────────────────────────────────────────────────────
function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Label)
    if ($Text -notmatch [regex]::Escape($Expected)) {
        Write-Error "ASSERTION FAILED [$Label]: expected to find '$Expected' in act output"
        exit 1
    }
    Write-Host "  PASS [$Label]: found '$Expected'"
}

# ── Build file list to copy ───────────────────────────────────
$filesToCopy = @(
    "ArtifactCleanup.ps1",
    "ArtifactCleanup.Tests.ps1",
    ".github/workflows/artifact-cleanup-script.yml"
)

# ── Set up temp git repo ──────────────────────────────────────
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ac-harness-$(Get-Random)"
Write-Host "Creating temp repo at: $tempDir"
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    # Copy project files
    foreach ($rel in $filesToCopy) {
        $src  = Join-Path $projectRoot $rel
        $dest = Join-Path $tempDir $rel
        $destParent = Split-Path $dest -Parent
        if (-not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
        Copy-Item -Path $src -Destination $dest
    }

    # Copy .actrc so act uses the custom image
    $actrc = Join-Path $projectRoot ".actrc"
    if (Test-Path $actrc) {
        Copy-Item $actrc (Join-Path $tempDir ".actrc")
    }

    # Initialise git repo (act requires at least one commit)
    Push-Location $tempDir
    try {
        git init -q
        git config user.email "harness@test.local"
        git config user.name  "Harness"
        git add -A
        git commit -q -m "test: artifact cleanup harness"
    } finally {
        Pop-Location
    }

    # ── TEST CASE 1: Normal mode verification ─────────────────
    Write-Host ""
    Write-Host "Running act push --rm (test case 1: all policies + dry-run)..."
    $delimiter = "=" * 70

    Push-Location $tempDir
    $actOutput   = & act push --rm --pull=false 2>&1
    $actExitCode = $LASTEXITCODE
    Pop-Location

    $outputText = $actOutput -join "`n"

    # Persist to act-result.txt
    @"
$delimiter
TEST CASE 1: Artifact Cleanup — all policies + dry-run mode
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$delimiter
$outputText
$delimiter
"@ | Set-Content -Path $actResultPath -Encoding UTF8

    Write-Host ""
    Write-Host "act exit code: $actExitCode"

    # ── Assertions ────────────────────────────────────────────
    Write-Host ""
    Write-Host "Asserting results..."

    if ($actExitCode -ne 0) {
        Write-Error "act exited with code $actExitCode — see act-result.txt for details"
        exit 1
    }

    # Job succeeded
    Assert-Contains $outputText "Job succeeded" "Job succeeded"

    # Pester test summary reported by workflow
    Assert-Contains $outputText "[PESTER] Total=" "Pester output present"

    # Normal-mode verification (3 deleted, 2 retained, 367001600 bytes, DryRun=False)
    Assert-Contains $outputText "[VERIFICATION] ArtifactsDeleted=3"         "ArtifactsDeleted=3"
    Assert-Contains $outputText "[VERIFICATION] ArtifactsRetained=2"        "ArtifactsRetained=2"
    Assert-Contains $outputText "[VERIFICATION] SpaceReclaimedBytes=367001600" "SpaceReclaimedBytes"
    Assert-Contains $outputText "[VERIFICATION] DryRun=False"               "DryRun=False"

    # Dry-run-mode verification (same counts, DryRun=True)
    Assert-Contains $outputText "[VERIFICATION-DRYRUN] ArtifactsDeleted=3"  "DryRun ArtifactsDeleted=3"
    Assert-Contains $outputText "[VERIFICATION-DRYRUN] ArtifactsRetained=2" "DryRun ArtifactsRetained=2"
    Assert-Contains $outputText "[VERIFICATION-DRYRUN] DryRun=True"         "DryRun=True"

    Write-Host ""
    Write-Host "All assertions passed. act-result.txt written to: $actResultPath"

} catch {
    # Append error context to act-result.txt if it was already created
    if (Test-Path $actResultPath) {
        Add-Content -Path $actResultPath -Value "`nHarness error: $_"
    } else {
        "Harness error: $_" | Set-Content -Path $actResultPath -Encoding UTF8
    }
    Write-Error $_
    exit 1
} finally {
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}
