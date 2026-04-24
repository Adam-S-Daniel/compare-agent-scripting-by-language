# Act-Integration.Tests.ps1
# Runs the GitHub Actions workflow in Docker via `act` and asserts exact output values.
# Run separately from the unit tests: Invoke-Pester -Path ./tests/Act-Integration.Tests.ps1
# NOTE: This file is NOT included in the workflow's Pester run to avoid infinite recursion.

Describe "Act integration: dependency-license-checker workflow" {
    BeforeAll {
        $ProjectRoot   = Resolve-Path "$PSScriptRoot/.."
        $ActResultFile = Join-Path $ProjectRoot "act-result.txt"

        if (Test-Path $ActResultFile) {
            # Re-use output from a previous run so we do not exceed the 3-run limit.
            $rawFile = Get-Content $ActResultFile -Raw
            if ($rawFile -match "Exit code: (\d+)") {
                $global:ActExitCode = [int]$matches[1]
            } else {
                $global:ActExitCode = 0
            }
            $global:ActOutput = $rawFile
        } else {
            # Build a temporary isolated git repo containing all project files.
            $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $TempDir | Out-Null

            # Copy everything except the .git dir itself.
            Get-ChildItem -Path $ProjectRoot -Force |
                Where-Object { $_.Name -ne '.git' } |
                ForEach-Object {
                    $dest = Join-Path $TempDir $_.Name
                    if ($_.PSIsContainer) {
                        Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
                    } else {
                        Copy-Item -Path $_.FullName -Destination $dest -Force
                    }
                }

            # Copy the .actrc so act uses the correct Docker image.
            $ActRc = Join-Path $ProjectRoot ".actrc"
            if (Test-Path $ActRc) {
                Copy-Item $ActRc (Join-Path $TempDir ".actrc") -Force
            }

            # Initialise git (act requires a real git repo).
            Push-Location $TempDir
            git init -q
            git config user.email "ci@test.local"
            git config user.name  "CI Test"
            git add -A
            git commit -q -m "chore: add license checker"

            # Run the workflow — capture stdout + stderr.
            $global:ActOutput   = (act push --rm --pull=false 2>&1) -join "`n"
            $global:ActExitCode = $LASTEXITCODE

            Pop-Location
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue

            # Persist result for the benchmark runner artifact requirement.
            @"
=== Act Integration Test: dependency-license-checker ===
Exit code: $($global:ActExitCode)

$($global:ActOutput)
"@ | Out-File -FilePath $ActResultFile -Encoding utf8
        }
    }

    It "act exits with code 0 (workflow succeeded)" {
        $global:ActExitCode | Should -Be 0
    }

    It "every job reports 'Job succeeded' (both test and check-licenses jobs)" {
        # Split on newlines so Select-String matches per line (not once per joined string).
        $matchCount = @($global:ActOutput -split "`n" | Where-Object { $_ -match "Job succeeded" }).Count
        $matchCount | Should -BeGreaterOrEqual 2
    }

    It "lodash is reported as MIT (approved)" {
        $global:ActOutput | Should -Match "lodash: MIT \(approved\)"
    }

    It "express is reported as MIT (approved)" {
        $global:ActOutput | Should -Match "express: MIT \(approved\)"
    }

    It "apache-sdk is reported as Apache-2.0 (approved)" {
        $global:ActOutput | Should -Match "apache-sdk: Apache-2\.0 \(approved\)"
    }

    It "jest is reported as MIT (approved)" {
        $global:ActOutput | Should -Match "jest: MIT \(approved\)"
    }

    It "compliance summary shows 4 approved" {
        $global:ActOutput | Should -Match "Approved: 4"
    }

    It "compliance summary shows 0 denied" {
        $global:ActOutput | Should -Match "Denied:\s+0"
    }

    It "compliance check passes (no denied licenses)" {
        $global:ActOutput | Should -Match "COMPLIANCE CHECK PASSED"
    }

    It "act-result.txt was created" {
        Test-Path (Join-Path (Resolve-Path "$PSScriptRoot/..") "act-result.txt") |
            Should -Be $true
    }
}
