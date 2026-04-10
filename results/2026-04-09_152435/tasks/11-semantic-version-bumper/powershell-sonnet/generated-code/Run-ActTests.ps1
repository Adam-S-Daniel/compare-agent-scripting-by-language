# Run-ActTests.ps1
# Test harness that runs each test case through GitHub Actions via `act`.
# For each case: sets up a temp git repo, runs `act push --rm`, captures output,
# and asserts exact expected values.

param(
    [string]$ActResultPath = "./act-result.txt"
)

# Resolve to absolute path so Add-Content still works after Push-Location changes dir
$ActResultPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ActResultPath)

# Initialize or clear the result file
Set-Content -Path $ActResultPath -Value "# Act Test Results - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $ActResultPath -Value "# Semantic Version Bumper - PowerShell"
Add-Content -Path $ActResultPath -Value ("=" * 60)

$scriptDir = $PSScriptRoot
$allPassed = $true

# Define test cases: each has a starting version, commit fixture file, and expected output version
$testCases = @(
    @{
        Name            = "patch-bump"
        StartVersion    = "1.1.0"
        CommitFixture   = "fixtures/patch-commits.txt"
        ExpectedVersion = "1.1.1"
        Description     = "fix commits should bump patch: 1.1.0 -> 1.1.1"
    },
    @{
        Name            = "minor-bump"
        StartVersion    = "1.1.0"
        CommitFixture   = "fixtures/minor-commits.txt"
        ExpectedVersion = "1.2.0"
        Description     = "feat commits should bump minor: 1.1.0 -> 1.2.0"
    },
    @{
        Name            = "major-bump"
        StartVersion    = "1.1.0"
        CommitFixture   = "fixtures/major-commits.txt"
        ExpectedVersion = "2.0.0"
        Description     = "breaking commits should bump major: 1.1.0 -> 2.0.0"
    }
)

foreach ($case in $testCases) {
    Write-Host "`n=== Test Case: $($case.Name) ===" -ForegroundColor Cyan
    Write-Host "Description: $($case.Description)"

    Add-Content -Path $ActResultPath -Value ""
    Add-Content -Path $ActResultPath -Value "=== TEST CASE: $($case.Name) ==="
    Add-Content -Path $ActResultPath -Value "Description: $($case.Description)"
    Add-Content -Path $ActResultPath -Value "Expected version: $($case.ExpectedVersion)"
    Add-Content -Path $ActResultPath -Value "--- ACT OUTPUT ---"

    # Create a fresh temp dir for this test case
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "vb-test-$($case.Name)-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir | Out-Null

    try {
        # Copy project files into temp dir
        $filesToCopy = @(
            "VersionBumper.ps1",
            "VersionBumper.Tests.ps1"
        )
        foreach ($f in $filesToCopy) {
            Copy-Item -Path (Join-Path $scriptDir $f) -Destination $tmpDir
        }

        # Copy .github directory
        $githubSrc = Join-Path $scriptDir ".github"
        $githubDst = Join-Path $tmpDir ".github"
        Copy-Item -Path $githubSrc -Destination $githubDst -Recurse

        # Copy fixtures directory
        $fixturesSrc = Join-Path $scriptDir "fixtures"
        $fixturesDst = Join-Path $tmpDir "fixtures"
        Copy-Item -Path $fixturesSrc -Destination $fixturesDst -Recurse

        # Copy .actrc
        $actrcSrc = Join-Path $scriptDir ".actrc"
        if (Test-Path $actrcSrc) {
            Copy-Item -Path $actrcSrc -Destination $tmpDir
        }

        # Write the starting version.txt
        Set-Content -Path (Join-Path $tmpDir "version.txt") -Value $case.StartVersion

        # Initialize git repo
        Push-Location $tmpDir
        git init -q 2>&1 | Out-Null
        git config user.email "test@example.com" 2>&1 | Out-Null
        git config user.name "Test Runner" 2>&1 | Out-Null

        # Initial commit with all project files
        git add . 2>&1 | Out-Null
        git commit -q -m "chore: initial project setup" 2>&1 | Out-Null

        # Add fixture commits (empty commits with the fixture message subjects)
        $fixturePath = Join-Path $scriptDir $case.CommitFixture
        $fixtureCommits = Get-Content -Path $fixturePath | Where-Object { $_.Trim() -ne "" }
        foreach ($commitMsg in $fixtureCommits) {
            git commit -q --allow-empty -m $commitMsg 2>&1 | Out-Null
            Write-Host "  Added commit: $commitMsg"
        }

        # Run act push with 5 min timeout
        Write-Host "Running act push --rm ..."
        $actOutput = act push --rm 2>&1
        $actExitCode = $LASTEXITCODE

        # Write output to result file
        $actOutput | Add-Content -Path $ActResultPath
        Add-Content -Path $ActResultPath -Value "--- END ACT OUTPUT ---"
        Add-Content -Path $ActResultPath -Value "Exit code: $actExitCode"

        # Assertions
        $casePassed = $true

        # Assert 1: act exited with 0
        if ($actExitCode -ne 0) {
            Write-Host "FAIL: act exited with code $actExitCode (expected 0)" -ForegroundColor Red
            Add-Content -Path $ActResultPath -Value "ASSERTION FAILED: act exit code was $actExitCode (expected 0)"
            $casePassed = $false
        }
        else {
            Write-Host "PASS: act exited with code 0" -ForegroundColor Green
        }

        # Assert 2: exact expected version appears in output
        $outputStr = $actOutput -join "`n"
        if ($outputStr -match [regex]::Escape("NEW_VERSION=$($case.ExpectedVersion)")) {
            Write-Host "PASS: output contains 'NEW_VERSION=$($case.ExpectedVersion)'" -ForegroundColor Green
            Add-Content -Path $ActResultPath -Value "ASSERTION PASSED: found NEW_VERSION=$($case.ExpectedVersion)"
        }
        else {
            Write-Host "FAIL: output does not contain 'NEW_VERSION=$($case.ExpectedVersion)'" -ForegroundColor Red
            Add-Content -Path $ActResultPath -Value "ASSERTION FAILED: did not find NEW_VERSION=$($case.ExpectedVersion)"
            $casePassed = $false
        }

        # Assert 3: Job succeeded markers
        if ($outputStr -match "Job succeeded") {
            Write-Host "PASS: found 'Job succeeded' in output" -ForegroundColor Green
            Add-Content -Path $ActResultPath -Value "ASSERTION PASSED: Job succeeded found"
        }
        else {
            Write-Host "FAIL: 'Job succeeded' not found in output" -ForegroundColor Red
            Add-Content -Path $ActResultPath -Value "ASSERTION FAILED: Job succeeded not found"
            $casePassed = $false
        }

        if ($casePassed) {
            Add-Content -Path $ActResultPath -Value "RESULT: PASSED"
            Write-Host "Test case '$($case.Name)': PASSED" -ForegroundColor Green
        }
        else {
            Add-Content -Path $ActResultPath -Value "RESULT: FAILED"
            Write-Host "Test case '$($case.Name)': FAILED" -ForegroundColor Red
            $allPassed = $false
        }
    }
    finally {
        Pop-Location
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Add-Content -Path $ActResultPath -Value ""
Add-Content -Path $ActResultPath -Value ("=" * 60)
if ($allPassed) {
    Add-Content -Path $ActResultPath -Value "OVERALL RESULT: ALL TESTS PASSED"
    Write-Host "`nALL TEST CASES PASSED" -ForegroundColor Green
}
else {
    Add-Content -Path $ActResultPath -Value "OVERALL RESULT: SOME TESTS FAILED"
    Write-Host "`nSOME TEST CASES FAILED" -ForegroundColor Red
    exit 1
}
