# Run-ActTests.ps1
# Act integration test harness.
# Sets up a temp git repo with all project files, runs the GitHub Actions workflow
# via `act push --rm`, captures the output, and asserts on exact expected values.
# Saves all output to act-result.txt in the current working directory.
# Limit: at most 3 `act push` invocations total.

param(
    [string]$ActResultFile = "$PSScriptRoot/act-result.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:PassCount = 0
$Script:FailCount = 0
$Script:AllOutput = [System.Collections.Generic.List[string]]::new()

function Write-Result {
    param([string]$Message)
    Write-Host $Message
    $Script:AllOutput.Add($Message)
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Expected,
        [string]$Label
    )
    if ($Text -match [regex]::Escape($Expected)) {
        Write-Result "  [PASS] $Label"
        $Script:PassCount++
    } else {
        Write-Result "  [FAIL] $Label"
        Write-Result "         Expected to find: '$Expected'"
        $Script:FailCount++
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$NotExpected,
        [string]$Label
    )
    if ($Text -notmatch [regex]::Escape($NotExpected)) {
        Write-Result "  [PASS] $Label"
        $Script:PassCount++
    } else {
        Write-Result "  [FAIL] $Label"
        Write-Result "         Expected NOT to find: '$NotExpected'"
        $Script:FailCount++
    }
}

# ---------------------------------------------------------------------------
# Setup: create a temp git repo with all project files
# ---------------------------------------------------------------------------
Write-Result "=== Setting up temp git repo ==="

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "docker-tag-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir | Out-Null
Write-Result "Temp dir: $tempDir"

# Copy project files into temp repo
$filesToCopy = @(
    "New-DockerImageTag.ps1",
    "New-DockerImageTag.Tests.ps1"
)

foreach ($file in $filesToCopy) {
    Copy-Item -Path "$PSScriptRoot/$file" -Destination "$tempDir/$file"
}

# Copy the workflow file
$workflowDir = "$tempDir/.github/workflows"
New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
Copy-Item -Path "$PSScriptRoot/.github/workflows/docker-image-tag-generator.yml" `
          -Destination "$workflowDir/docker-image-tag-generator.yml"

# Copy .actrc so act uses the correct Docker image
if (Test-Path "$PSScriptRoot/.actrc") {
    Copy-Item -Path "$PSScriptRoot/.actrc" -Destination "$tempDir/.actrc"
}

# Initialize git repo and create a commit (act's checkout action needs this)
Push-Location $tempDir
try {
    git init -b main 2>&1 | Out-Null
    git config user.email "test@example.com" 2>&1 | Out-Null
    git config user.name "Test" 2>&1 | Out-Null
    git add -A 2>&1 | Out-Null
    git commit -m "test: add docker image tag generator" 2>&1 | Out-Null
    Write-Result "Git repo initialized with commit."
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# Run act push --rm (single invocation covers all test scenarios)
# The workflow runs Pester and also emits DEMO_* markers for each scenario.
# ---------------------------------------------------------------------------
Write-Result ""
Write-Result "=== Running act push --rm (invocation 1 of 3 max) ==="
Write-Result "Working dir: $tempDir"

Push-Location $tempDir
try {
    $actOutput = & act push --rm --pull=false 2>&1 | Out-String
    $actExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Result "act exit code: $actExitCode"

# ---------------------------------------------------------------------------
# Save all act output to act-result.txt
# ---------------------------------------------------------------------------
$delimiter = "=" * 60
$header = @"
$delimiter
ACT RUN: docker-image-tag-generator workflow
DATE   : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
DIR    : $tempDir
EXIT   : $actExitCode
$delimiter
$actOutput
$delimiter
"@

$Script:AllOutput.Add($header)
$header | Out-File -FilePath $ActResultFile -Append -Encoding utf8
Write-Result "Act output saved to: $ActResultFile"

# ---------------------------------------------------------------------------
# Assertions on act exit code and output
# ---------------------------------------------------------------------------
Write-Result ""
Write-Result "=== Assertions ==="

# 1. Act must exit with code 0
if ($actExitCode -eq 0) {
    Write-Result "  [PASS] act exited with code 0"
    $Script:PassCount++
} else {
    Write-Result "  [FAIL] act exited with code $actExitCode (expected 0)"
    $Script:FailCount++
}

# 2. Job succeeded message
Assert-Contains -Text $actOutput -Expected "Job succeeded" -Label "Job succeeded"

# 3. Pester result: parse counts and assert no failures
if ($actOutput -match "PESTER_RESULT: Passed=(\d+) Failed=(\d+)") {
    $pesterPassed = [int]$Matches[1]
    $pesterFailed = [int]$Matches[2]
    Write-Result "  [PASS] Pester result line parsed: Passed=$pesterPassed Failed=$pesterFailed"
    $Script:PassCount++

    if ($pesterPassed -gt 0) {
        Write-Result "  [PASS] Pester ran $pesterPassed test(s)"
        $Script:PassCount++
    } else {
        Write-Result "  [FAIL] Pester ran 0 tests — expected at least 1"
        $Script:FailCount++
    }

    if ($pesterFailed -eq 0) {
        Write-Result "  [PASS] Pester: 0 failures"
        $Script:PassCount++
    } else {
        Write-Result "  [FAIL] Pester: $pesterFailed failure(s) (expected 0)"
        $Script:FailCount++
    }
} else {
    Write-Result "  [FAIL] Could not parse PESTER_RESULT line from act output"
    $Script:FailCount++
}

# 4. Demo scenario: main branch -> latest,main-abc1234
Assert-Contains -Text $actOutput -Expected "DEMO_MAIN_TAGS: latest,main-abc1234" `
    -Label "Scenario 1 (main branch): tags = latest,main-abc1234"

# 5. Demo scenario: PR -> pr-42
Assert-Contains -Text $actOutput -Expected "DEMO_PR_TAGS: pr-42" `
    -Label "Scenario 2 (PR #42): tag = pr-42"

# 6. Demo scenario: semver tag on main -> v1.2.3,latest
Assert-Contains -Text $actOutput -Expected "DEMO_TAG_TAGS: v1.2.3,latest" `
    -Label "Scenario 3 (semver tag on main): tags include v1.2.3,latest"

# 7. Demo scenario: feature branch -> feature-my-feature-abc1234
Assert-Contains -Text $actOutput -Expected "DEMO_FEATURE_TAGS: feature-my-feature-abc1234" `
    -Label "Scenario 4 (feature branch): tag = feature-my-feature-abc1234"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Result ""
Write-Result "=== Summary ==="
Write-Result "Passed: $($Script:PassCount)"
Write-Result "Failed: $($Script:FailCount)"

# Write final summary to act-result.txt
$summary = @"

=== HARNESS SUMMARY ===
Passed: $($Script:PassCount)
Failed: $($Script:FailCount)
"@
$summary | Out-File -FilePath $ActResultFile -Append -Encoding utf8

# Clean up temp dir
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Result "Cleaned up temp dir."

if ($Script:FailCount -gt 0) {
    Write-Error "Act integration tests FAILED: $($Script:FailCount) assertion(s) failed"
    exit 1
}

Write-Result "All act integration tests PASSED."
