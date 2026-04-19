param(
    [int]$MaxActRuns = 3
)

$ErrorActionPreference = "Stop"

# Get the script directory
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

. (Join-Path $scriptDir 'test-fixtures.ps1')

$resultsFile = Join-Path (Get-Location) "act-result.txt"
$actRunCount = 0

# Initialize results file
"=== Semantic Version Bumper - Integration Tests via Act ===" | Set-Content $resultsFile
"Start time: $(Get-Date)" | Add-Content $resultsFile
"" | Add-Content $resultsFile

Write-Host "Running integration tests through act..."
Write-Host "Results will be saved to: $resultsFile"
Write-Host ""

try {
    foreach ($testName in $fixtures.Keys) {
        if ($actRunCount -ge $MaxActRuns) {
            Write-Warning "Reached maximum act runs ($MaxActRuns). Stopping."
            break
        }

        $fixture = $fixtures[$testName]
        Write-Host "Testing: $testName"
        Write-Host "  Initial version: $($fixture.initialVersion)"
        Write-Host "  Expected version: $($fixture.expectedVersion)"

        # Create temp test directory
        $tempBase = if ([System.IO.Path]::PathSeparator -eq '\') { $env:TEMP } else { '/tmp' }
        $testDir = Join-Path $tempBase "svb-act-$testName-$(Get-Random)"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        try {
            # Copy workspace files from script directory
            Copy-Item -Path (Join-Path $scriptDir "*.ps1") -Destination $testDir -Exclude "run-integration-tests.ps1"
            Copy-Item -Path (Join-Path $scriptDir ".github") -Destination $testDir -Recurse -Force

            # Initialize git repo
            Push-Location $testDir
            & git init | Out-Null
            & git config user.email "test@example.com"
            & git config user.name "Test User"

            # Create package.json
            New-TestPackageJson -Path "package.json" -Version $fixture.initialVersion

            # Create commits file
            $fixture.commits | Set-Content -Path "commits.txt"

            # Add and commit files
            & git add . | Out-Null
            & git commit -m "Initial commit" | Out-Null

            Pop-Location

            # Run act
            Write-Host "  Running act..." -NoNewline
            $actOutput = & act push --rm -C $testDir 2>&1
            $actExitCode = $LASTEXITCODE
            Write-Host " (exit code: $actExitCode)"

            # Record results
            "--- Test: $testName ---" | Add-Content $resultsFile
            "Initial Version: $($fixture.initialVersion)" | Add-Content $resultsFile
            "Expected Version: $($fixture.expectedVersion)" | Add-Content $resultsFile
            "Act Exit Code: $actExitCode" | Add-Content $resultsFile
            "" | Add-Content $resultsFile
            "Act Output:" | Add-Content $resultsFile
            $actOutput | Add-Content $resultsFile
            "" | Add-Content $resultsFile

            # Check results
            if ($actExitCode -eq 0) {
                Write-Host "  ✓ Act succeeded"

                # Verify version was updated correctly by parsing the act output
                if ($actOutput -match "Version updated:.*→\s*($($fixture.expectedVersion))") {
                    Write-Host "  ✓ Version correctly updated to $($fixture.expectedVersion)"
                    "Result: PASS - Version correctly bumped to $($fixture.expectedVersion)" | Add-Content $resultsFile
                } else {
                    # Also check for the version in job output
                    if ($actOutput -match "package\.json version:\s*($($fixture.expectedVersion))") {
                        Write-Host "  ✓ Version verified as $($fixture.expectedVersion)"
                        "Result: PASS - Version verified as $($fixture.expectedVersion)" | Add-Content $resultsFile
                    } else {
                        Write-Warning "  ✗ Version bump not verified in output"
                        "Result: FAIL - Version bump verification failed" | Add-Content $resultsFile
                    }
                }
            } else {
                Write-Warning "  ✗ Act failed with exit code $actExitCode"
                "Result: FAIL - Act exited with code $actExitCode" | Add-Content $resultsFile
            }

            $actRunCount++

        } finally {
            # Cleanup
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        "=" * 80 | Add-Content $resultsFile
        "" | Add-Content $resultsFile
    }

    Write-Host ""
    Write-Host "Tests complete. Results saved to: $resultsFile"
    Write-Host "Total act runs: $actRunCount / $MaxActRuns"
    Write-Host ""
    Write-Host "Summary from results file:"
    Get-Content $resultsFile | Select-Object -First 30 | Write-Host

} catch {
    Write-Error "Test execution failed: $_"
    exit 1
}
