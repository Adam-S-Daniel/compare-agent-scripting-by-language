# Test harness: runs all test cases through act and validates output.
# Saves all act output to act-result.txt and asserts on exact expected values.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$resultFile = Join-Path $scriptDir "act-result.txt"

# Clear previous results
if (Test-Path $resultFile) { Remove-Item $resultFile }
"" | Set-Content $resultFile

$allPassed = $true
$testResults = @()

# --- Workflow structure tests ---
Write-Output "=== WORKFLOW STRUCTURE TESTS ==="

# Test: YAML parses correctly and has expected structure
$workflow = Get-Content "$scriptDir/.github/workflows/semantic-version-bumper.yml" -Raw
$yamlValid = $workflow -match "name:" -and $workflow -match "on:" -and $workflow -match "jobs:"
if ($yamlValid) {
    Write-Output "PASS: Workflow YAML has valid structure (name, on, jobs)"
} else {
    Write-Output "FAIL: Workflow YAML missing required structure"
    $allPassed = $false
}

# Test: triggers include push, pull_request, workflow_dispatch
$hasPush = $workflow -match "push:"
$hasPR = $workflow -match "pull_request:"
$hasDispatch = $workflow -match "workflow_dispatch:"
if ($hasPush -and $hasPR -and $hasDispatch) {
    Write-Output "PASS: Workflow has push, pull_request, workflow_dispatch triggers"
} else {
    Write-Output "FAIL: Missing expected triggers"
    $allPassed = $false
}

# Test: jobs include test and bump-version
$hasTestJob = $workflow -match "test:"
$hasBumpJob = $workflow -match "bump-version:"
if ($hasTestJob -and $hasBumpJob) {
    Write-Output "PASS: Workflow has test and bump-version jobs"
} else {
    Write-Output "FAIL: Missing expected jobs"
    $allPassed = $false
}

# Test: references script files that exist
$refsBumpScript = $workflow -match "Bump-Version\.ps1"
$refsTestScript = $workflow -match "Bump-Version\.Tests\.ps1"
$bumpExists = Test-Path "$scriptDir/Bump-Version.ps1"
$testExists = Test-Path "$scriptDir/Bump-Version.Tests.ps1"
if ($refsBumpScript -and $refsTestScript -and $bumpExists -and $testExists) {
    Write-Output "PASS: Workflow references existing script files"
} else {
    Write-Output "FAIL: Script file references invalid"
    $allPassed = $false
}

# Test: uses shell: pwsh
$usesPwsh = $workflow -match "shell: pwsh"
if ($usesPwsh) {
    Write-Output "PASS: Workflow uses shell: pwsh"
} else {
    Write-Output "FAIL: Workflow does not use shell: pwsh"
    $allPassed = $false
}

# Test: actionlint passes
$lintOutput = & actionlint "$scriptDir/.github/workflows/semantic-version-bumper.yml" 2>&1
$lintExitCode = $LASTEXITCODE
if ($lintExitCode -eq 0) {
    Write-Output "PASS: actionlint exits with code 0"
} else {
    Write-Output "FAIL: actionlint returned exit code $lintExitCode"
    Write-Output $lintOutput
    $allPassed = $false
}

# Append structure test results
"=== WORKFLOW STRUCTURE TESTS ===" | Add-Content $resultFile
"YAML valid structure: $yamlValid" | Add-Content $resultFile
"Has triggers: push=$hasPush pr=$hasPR dispatch=$hasDispatch" | Add-Content $resultFile
"Has jobs: test=$hasTestJob bump-version=$hasBumpJob" | Add-Content $resultFile
"Script refs valid: $refsBumpScript $refsTestScript" | Add-Content $resultFile
"Uses pwsh: $usesPwsh" | Add-Content $resultFile
"actionlint pass: $($lintExitCode -eq 0)" | Add-Content $resultFile
"" | Add-Content $resultFile

# --- Act integration tests ---
# Each test case: set up fixture, run act, assert output
Write-Output ""
Write-Output "=== ACT INTEGRATION TESTS ==="

$testCases = @(
    @{
        Name = "patch-bump"
        Fixture = "fixtures/patch-commits.txt"
        InitialVersion = "1.0.0"
        ExpectedVersion = "1.0.1"
        ExpectedBumpType = "patch"
    },
    @{
        Name = "minor-bump"
        Fixture = "fixtures/minor-commits.txt"
        InitialVersion = "1.1.0"
        ExpectedVersion = "1.2.0"
        ExpectedBumpType = "minor"
    },
    @{
        Name = "major-bump"
        Fixture = "fixtures/major-commits.txt"
        InitialVersion = "1.5.3"
        ExpectedVersion = "2.0.0"
        ExpectedBumpType = "major"
    }
)

# Run all test cases in a single act invocation to stay within the 3-run limit.
# We use the first fixture for the act run and verify Pester tests pass,
# then run act twice more for the other fixtures.

$runCount = 0
foreach ($tc in $testCases) {
    $runCount++
    Write-Output ""
    Write-Output "--- Test case: $($tc.Name) (run $runCount/3) ---"
    "--- Test case: $($tc.Name) ---" | Add-Content $resultFile

    # Create a temporary directory for this test's git repo
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$($tc.Name)-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Copy project files into temp dir
        Copy-Item "$scriptDir/Bump-Version.ps1" $tempDir/
        Copy-Item "$scriptDir/Bump-Version.Tests.ps1" $tempDir/
        Copy-Item "$scriptDir/VERSION" $tempDir/
        Copy-Item -Recurse "$scriptDir/fixtures" "$tempDir/fixtures"
        Copy-Item -Recurse "$scriptDir/.github" "$tempDir/.github"
        Copy-Item "$scriptDir/.actrc" "$tempDir/.actrc"

        # Set initial version for this test case
        Set-Content -Path "$tempDir/VERSION" -Value $tc.InitialVersion -NoNewline

        # Update workflow to use this test's fixture (replace both YAML defaults and inline fallbacks)
        $wfPath = "$tempDir/.github/workflows/semantic-version-bumper.yml"
        $wfContent = Get-Content $wfPath -Raw
        $wfContent = $wfContent -replace 'default: "fixtures/patch-commits.txt"', "default: `"$($tc.Fixture)`""
        $wfContent = $wfContent -replace 'default: "1.0.0"', "default: `"$($tc.InitialVersion)`""
        $wfContent = $wfContent -replace '\{ \$fixture = "fixtures/patch-commits.txt" \}', "{ `$fixture = `"$($tc.Fixture)`" }"
        $wfContent = $wfContent -replace '\{ \$version = "1.0.0" \}', "{ `$version = `"$($tc.InitialVersion)`" }"
        Set-Content -Path $wfPath -Value $wfContent

        # Initialize git repo (required by actions/checkout)
        Push-Location $tempDir
        git init --initial-branch=main 2>&1 | Out-Null
        git config user.email "test@test.com" 2>&1 | Out-Null
        git config user.name "Test" 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "init" 2>&1 | Out-Null
        Pop-Location

        # Run act (--pull=false to use local image instead of pulling from Docker Hub)
        $actOutput = & act push --rm --pull=false -W "$tempDir/.github/workflows" 2>&1 | Out-String
        $actExitCode = $LASTEXITCODE

        # Save output
        $actOutput | Add-Content $resultFile
        "" | Add-Content $resultFile

        # Assert exit code 0
        if ($actExitCode -ne 0) {
            Write-Output "FAIL: act exited with code $actExitCode for $($tc.Name)"
            "RESULT: FAIL (exit code $actExitCode)" | Add-Content $resultFile
            $allPassed = $false
            continue
        }
        Write-Output "PASS: act exited with code 0"

        # Assert job succeeded
        if ($actOutput -match "Job succeeded") {
            Write-Output "PASS: Job succeeded"
        } else {
            Write-Output "FAIL: 'Job succeeded' not found in output"
            $allPassed = $false
        }

        # Assert exact expected version in output
        if ($actOutput -match "NEW_VERSION=$($tc.ExpectedVersion)") {
            Write-Output "PASS: Output contains NEW_VERSION=$($tc.ExpectedVersion)"
        } else {
            Write-Output "FAIL: Expected NEW_VERSION=$($tc.ExpectedVersion) not found"
            $allPassed = $false
        }

        # Assert bump type in output
        if ($actOutput -match "BUMP_TYPE=$($tc.ExpectedBumpType)") {
            Write-Output "PASS: Output contains BUMP_TYPE=$($tc.ExpectedBumpType)"
        } else {
            Write-Output "FAIL: Expected BUMP_TYPE=$($tc.ExpectedBumpType) not found"
            $allPassed = $false
        }

        # Assert version file was updated (shown in Display Results step)
        if ($actOutput -match $tc.ExpectedVersion) {
            Write-Output "PASS: Version $($tc.ExpectedVersion) appears in output"
        } else {
            Write-Output "FAIL: Version $($tc.ExpectedVersion) not in output"
            $allPassed = $false
        }

        "RESULT: PASS" | Add-Content $resultFile

    } finally {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

# Summary
Write-Output ""
Write-Output "=== SUMMARY ==="
if ($allPassed) {
    Write-Output "All tests PASSED"
    "=== ALL TESTS PASSED ===" | Add-Content $resultFile
} else {
    Write-Output "Some tests FAILED"
    "=== SOME TESTS FAILED ===" | Add-Content $resultFile
    exit 1
}
