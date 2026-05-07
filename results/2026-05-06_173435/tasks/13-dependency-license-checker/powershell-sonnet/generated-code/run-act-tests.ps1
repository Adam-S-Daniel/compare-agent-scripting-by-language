# Test harness: sets up an isolated git repo with the project files,
# runs the workflow through act, captures output, and asserts expected values.
#
# All act output is appended to act-result.txt in the project root.
# Exit code: 0 = all assertions passed, non-zero = at least one failed.

$projectRoot = $PSScriptRoot
$resultFile  = Join-Path $projectRoot "act-result.txt"

Set-Content -Path $resultFile -Value "" -Force
Add-Content -Path $resultFile -Value "=== ACT TEST HARNESS STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Add-Content -Path $resultFile -Value ""

# ─── Helper: run an assertion and log result ──────────────────────────────────
$failed = $false
function Assert-Contains {
    param([string]$Haystack, [string]$Pattern, [string]$Description)
    if ($Haystack -match [regex]::Escape($Pattern).Replace('\*','.*')) {
        Add-Content -Path $using:resultFile -Value "PASS: $Description"
    } else {
        Add-Content -Path $using:resultFile -Value "FAIL: $Description (pattern not found: '$Pattern')"
        $script:failed = $true
    }
}

function Assert-Regex {
    param([string]$Haystack, [string]$Pattern, [string]$Description)
    if ($Haystack -match $Pattern) {
        Add-Content -Path $resultFile -Value "PASS: $Description"
    } else {
        Add-Content -Path $resultFile -Value "FAIL: $Description (regex not matched: '$Pattern')"
        $script:failed = $true
    }
}

# ─── Workflow structure tests (no act needed) ─────────────────────────────────
Add-Content -Path $resultFile -Value "=== WORKFLOW STRUCTURE TESTS ==="
Add-Content -Path $resultFile -Value ""

$wfPath = Join-Path $projectRoot ".github/workflows/dependency-license-checker.yml"
if (Test-Path $wfPath) {
    Add-Content -Path $resultFile -Value "PASS: workflow file exists at $wfPath"
} else {
    Add-Content -Path $resultFile -Value "FAIL: workflow file not found at $wfPath"
    $script:failed = $true
}

$wfContent = Get-Content $wfPath -Raw
Assert-Regex -Haystack $wfContent -Pattern "on:"                    -Description "workflow has trigger block"
Assert-Regex -Haystack $wfContent -Pattern "push"                   -Description "workflow triggers on push"
Assert-Regex -Haystack $wfContent -Pattern "pull_request"           -Description "workflow triggers on pull_request"
Assert-Regex -Haystack $wfContent -Pattern "schedule"               -Description "workflow has schedule trigger"
Assert-Regex -Haystack $wfContent -Pattern "workflow_dispatch"      -Description "workflow has workflow_dispatch trigger"
Assert-Regex -Haystack $wfContent -Pattern "jobs:"                  -Description "workflow has jobs block"
Assert-Regex -Haystack $wfContent -Pattern "Invoke-Pester"          -Description "workflow references Invoke-Pester"
Assert-Regex -Haystack $wfContent -Pattern "Invoke-LicenseCheck"    -Description "workflow references Invoke-LicenseCheck.ps1"
Assert-Regex -Haystack $wfContent -Pattern "actions/checkout@v4"    -Description "workflow uses actions/checkout@v4"
Assert-Regex -Haystack $wfContent -Pattern "shell:\s*pwsh"          -Description "workflow steps use shell: pwsh"
Assert-Regex -Haystack $wfContent -Pattern "permissions:"           -Description "workflow declares permissions"

# Verify referenced script files exist
foreach ($scriptFile in @("LicenseChecker.ps1", "LicenseChecker.Tests.ps1", "Invoke-LicenseCheck.ps1")) {
    $p = Join-Path $projectRoot $scriptFile
    if (Test-Path $p) {
        Add-Content -Path $resultFile -Value "PASS: referenced script exists: $scriptFile"
    } else {
        Add-Content -Path $resultFile -Value "FAIL: referenced script missing: $scriptFile"
        $script:failed = $true
    }
}

# actionlint check
$lintOut = actionlint $wfPath 2>&1
$lintExit = $LASTEXITCODE
if ($lintExit -eq 0) {
    Add-Content -Path $resultFile -Value "PASS: actionlint reports no errors"
} else {
    Add-Content -Path $resultFile -Value "FAIL: actionlint errors: $lintOut"
    $script:failed = $true
}

Add-Content -Path $resultFile -Value ""

# ─── Test Case 1: Full workflow via act ──────────────────────────────────────
Add-Content -Path $resultFile -Value "=== TEST CASE 1: act push (package.json + requirements.txt compliance) ==="
Add-Content -Path $resultFile -Value ""

# Create an isolated temp git repo containing all project files
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lc-test-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy project files into the temp repo
Copy-Item "$projectRoot/*.ps1"   $tempDir
Copy-Item "$projectRoot/fixtures" "$tempDir/fixtures" -Recurse
New-Item -ItemType Directory -Path "$tempDir/.github/workflows" -Force | Out-Null
Copy-Item "$wfPath" "$tempDir/.github/workflows/"

# .actrc from the project root so act picks up the custom image
if (Test-Path (Join-Path $projectRoot ".actrc")) {
    Copy-Item (Join-Path $projectRoot ".actrc") $tempDir
}

Push-Location $tempDir
try {
    git init --quiet
    git config user.email "ci@test.local"
    git config user.name "CI Test"
    git add .
    git commit -m "ci: test fixture" --quiet

    Add-Content -Path $resultFile -Value "--- act output ---"
    $actOutput = act push --rm --pull=false 2>&1
    $actExitCode = $LASTEXITCODE

    $actOutput | ForEach-Object { Add-Content -Path $resultFile -Value $_ }
    Add-Content -Path $resultFile -Value ""
    Add-Content -Path $resultFile -Value "--- act exit code: $actExitCode ---"
    Add-Content -Path $resultFile -Value ""
}
finally {
    Pop-Location
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ─── Assertions on act output ────────────────────────────────────────────────
Add-Content -Path $resultFile -Value "=== ASSERTIONS ==="
$outputStr = $actOutput -join "`n"

# Exit code
if ($actExitCode -eq 0) {
    Add-Content -Path $resultFile -Value "PASS: act exited with code 0"
} else {
    Add-Content -Path $resultFile -Value "FAIL: act exited with code $actExitCode (expected 0)"
    $script:failed = $true
}

# Job succeeded markers
Assert-Regex -Haystack $outputStr -Pattern "Job succeeded" -Description "at least one job shows 'Job succeeded'"

# Pester summary line: must show 0 failures
Assert-Regex -Haystack $outputStr -Pattern "Tests Passed: \d+, Failed: 0" -Description "Pester reports 0 failures"

# Compliance results for package.json fixture — exact expected status per package
Assert-Regex -Haystack $outputStr -Pattern "express"     -Description "output mentions 'express'"
Assert-Regex -Haystack $outputStr -Pattern "APPROVED"    -Description "output contains 'APPROVED'"
Assert-Regex -Haystack $outputStr -Pattern "gpl-lib"     -Description "output mentions 'gpl-lib'"
Assert-Regex -Haystack $outputStr -Pattern "DENIED"      -Description "output contains 'DENIED'"
Assert-Regex -Haystack $outputStr -Pattern "unknown-lib" -Description "output mentions 'unknown-lib'"
Assert-Regex -Haystack $outputStr -Pattern "UNKNOWN"     -Description "output contains 'UNKNOWN'"

# requirements.txt specific packages
Assert-Regex -Haystack $outputStr -Pattern "requests"      -Description "output mentions 'requests' (requirements.txt)"
Assert-Regex -Haystack $outputStr -Pattern "copyleft-lib"  -Description "output mentions 'copyleft-lib' (requirements.txt)"

# Summary block present
Assert-Regex -Haystack $outputStr -Pattern "COMPLIANCE SCAN COMPLETE" -Description "compliance scan complete marker present"

Add-Content -Path $resultFile -Value ""
Add-Content -Path $resultFile -Value "=== ACT TEST HARNESS FINISHED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="

# ─── Final result ─────────────────────────────────────────────────────────────
if ($script:failed) {
    Write-Error "One or more assertions failed. See $resultFile for details."
    exit 1
}
Write-Output "All assertions passed. See $resultFile for full output."
exit 0
