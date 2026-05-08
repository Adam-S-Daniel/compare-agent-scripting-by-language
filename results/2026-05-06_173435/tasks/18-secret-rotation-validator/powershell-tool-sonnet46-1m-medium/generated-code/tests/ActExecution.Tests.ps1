# ActExecution.Tests.ps1
# Runs the workflow through act (nektos/act) in a temporary git repo,
# captures output, and asserts on exact expected values.
#
# Expected fixture results with ReferenceDate=2026-05-08 and WarningWindowDays=14:
#   SECRET_ALPHA: lastRotated=2026-01-01, policy=90d -> expired 2026-04-01 -> Expired(37)
#   SECRET_BETA:  lastRotated=2026-04-17, policy=30d -> expires 2026-05-17 -> Warning(9)
#   SECRET_GAMMA: lastRotated=2026-04-24, policy=30d -> expires 2026-05-24 -> OK(16)

Describe "Act workflow execution" {
    BeforeAll {
        $script:projectRoot  = (Resolve-Path "$PSScriptRoot/..").Path
        $script:actResultFile = "$script:projectRoot/act-result.txt"

        # Create isolated temp git repo with all project files
        $script:tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "act-test-$([System.Guid]::NewGuid().ToString('N'))")
        New-Item -ItemType Directory -Path $script:tempDir | Out-Null

        # Copy project files into temp repo
        $copyItems = @(
            "Invoke-SecretRotationValidator.ps1",
            "SecretRotationFunctions.ps1",
            "fixtures",
            "tests",
            ".github"
        )
        foreach ($item in $copyItems) {
            $src = Join-Path $script:projectRoot $item
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $script:tempDir -Recurse -Force
            }
        }

        # Copy .actrc so act uses the pre-built pwsh image
        $actrc = Join-Path $script:projectRoot ".actrc"
        if (Test-Path $actrc) {
            Copy-Item -Path $actrc -Destination $script:tempDir
        }

        # Initialise git repo and commit everything
        Push-Location $script:tempDir
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test Runner"
        git add -A
        git commit -q -m "ci: test fixtures for act run"
        Pop-Location

        # Run act and capture full output (stdout + stderr merged).
        # --no-pull avoids trying to pull the local-only image from Docker Hub.
        Push-Location $script:tempDir
        $script:actOutput = & act push --rm --pull=false 2>&1 | Out-String
        $script:actExitCode = $LASTEXITCODE
        Pop-Location

        # Append run output to act-result.txt (required artifact)
        $sep = "=" * 70
        @"
$sep
TEST CASE: default fixtures with ReferenceDate=2026-05-08 WarningWindowDays=14
Exit code: $($script:actExitCode)
$sep
$($script:actOutput)
"@ | Out-File -FilePath $script:actResultFile -Append -Encoding UTF8
    }

    AfterAll {
        # Clean up temp dir; keep act-result.txt
        if ($script:tempDir -and (Test-Path $script:tempDir)) {
            Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "act exits with code 0" {
        $actExitCode | Should -Be 0
    }

    It "all jobs report Job succeeded" {
        $actOutput | Should -Match "Job succeeded"
    }

    It "Pester tests pass inside the workflow (no failures)" {
        $actOutput | Should -Match "PESTER-RESULT: Passed=\d+ Failed=0"
    }

    It "SECRET_ALPHA is reported as Expired with 37 days overdue" {
        $actOutput | Should -Match "ROTATION-STATUS: SECRET_ALPHA=Expired\(37\)"
    }

    It "SECRET_BETA is reported as Warning with 9 days remaining" {
        $actOutput | Should -Match "ROTATION-STATUS: SECRET_BETA=Warning\(9\)"
    }

    It "SECRET_GAMMA is reported as OK with 16 days remaining" {
        $actOutput | Should -Match "ROTATION-STATUS: SECRET_GAMMA=OK\(16\)"
    }
}
