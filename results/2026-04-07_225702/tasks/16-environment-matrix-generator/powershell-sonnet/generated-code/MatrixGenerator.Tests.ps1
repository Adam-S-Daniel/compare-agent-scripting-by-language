# MatrixGenerator.Tests.ps1
# TDD tests for GitHub Actions environment matrix generator.
# Red/green cycle: write failing test, then implement, then refactor.

# Pester 5 requires functions to be imported inside BeforeAll so they are
# available in the test-execution scope (not just the discovery scope).

Describe "New-BuildMatrix" {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "MatrixGenerator.ps1"
        . $scriptPath
    }

    # -------------------------------------------------------------------------
    # Cycle 1: Basic matrix generation — cartesian product of axes
    # -------------------------------------------------------------------------
    Context "Basic matrix generation" {

        It "generates the cartesian product of os, language-version, and feature flags" {
            $config = @{
                os               = @("ubuntu-latest", "windows-latest")
                language_version = @("3.10", "3.11")
                feature_flags    = @("flag-a")
            }

            $result = New-BuildMatrix -Config $config

            # 2 OS × 2 versions × 1 flag = 4 combinations
            $result.matrix.include | Should -HaveCount 4
        }

        It "each entry contains every axis key" {
            $config = @{
                os               = @("ubuntu-latest")
                language_version = @("3.10")
                feature_flags    = @("flag-a")
            }

            $result = New-BuildMatrix -Config $config
            $entry  = $result.matrix.include[0]

            $entry.os               | Should -Be "ubuntu-latest"
            $entry.language_version | Should -Be "3.10"
            $entry.feature_flags    | Should -Be "flag-a"
        }

        It "handles a single-axis config (os only)" {
            $config = @{
                os = @("ubuntu-latest", "macos-latest", "windows-latest")
            }

            $result = New-BuildMatrix -Config $config
            $result.matrix.include | Should -HaveCount 3
        }
    }

    # -------------------------------------------------------------------------
    # Cycle 2: fail-fast and max-parallel pass-through
    # -------------------------------------------------------------------------
    Context "Strategy settings" {

        It "sets fail-fast to true when specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config -FailFast $true

            $result.strategy.'fail-fast' | Should -Be $true
        }

        It "sets fail-fast to false by default" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config

            $result.strategy.'fail-fast' | Should -Be $false
        }

        It "sets max-parallel when specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config -MaxParallel 4

            $result.strategy.'max-parallel' | Should -Be 4
        }

        It "omits max-parallel when not specified" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config

            $result.strategy.ContainsKey('max-parallel') | Should -Be $false
        }
    }

    # -------------------------------------------------------------------------
    # Cycle 3: Exclude rules — remove matching combinations
    # -------------------------------------------------------------------------
    Context "Exclude rules" {

        It "removes combinations that match an exclude rule" {
            $config = @{
                os               = @("ubuntu-latest", "windows-latest")
                language_version = @("3.10", "3.11")
            }
            # Exclude windows + 3.10
            $excludes = @(
                @{ os = "windows-latest"; language_version = "3.10" }
            )

            $result = New-BuildMatrix -Config $config -Excludes $excludes

            # 4 total - 1 excluded = 3
            $result.matrix.include | Should -HaveCount 3
            $result.matrix.include | Where-Object {
                $_.os -eq "windows-latest" -and $_.language_version -eq "3.10"
            } | Should -BeNullOrEmpty
        }

        It "supports partial exclude rules (matching any superset)" {
            $config = @{
                os               = @("ubuntu-latest", "windows-latest")
                language_version = @("3.10", "3.11")
            }
            # Exclude everything on windows — partial match on os only
            $excludes = @(
                @{ os = "windows-latest" }
            )

            $result = New-BuildMatrix -Config $config -Excludes $excludes

            # 2 windows entries removed → 2 remain
            $result.matrix.include | Should -HaveCount 2
            $result.matrix.include | Where-Object { $_.os -eq "windows-latest" } | Should -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # Cycle 4: Include rules — add extra combinations
    # -------------------------------------------------------------------------
    Context "Include rules (extra entries)" {

        It "appends extra combinations that are not already present" {
            $config = @{
                os               = @("ubuntu-latest")
                language_version = @("3.10")
            }
            $extras = @(
                @{ os = "macos-latest"; language_version = "3.12"; experimental = $true }
            )

            $result = New-BuildMatrix -Config $config -Includes $extras

            $result.matrix.include | Should -HaveCount 2
            $result.matrix.include[-1].os           | Should -Be "macos-latest"
            $result.matrix.include[-1].experimental | Should -Be $true
        }

        It "does not duplicate an entry that already exists" {
            $config = @{
                os               = @("ubuntu-latest")
                language_version = @("3.10")
            }
            # Exactly the same as what the cartesian product already produces
            $extras = @(
                @{ os = "ubuntu-latest"; language_version = "3.10" }
            )

            $result = New-BuildMatrix -Config $config -Includes $extras

            $result.matrix.include | Should -HaveCount 1
        }
    }

    # -------------------------------------------------------------------------
    # Cycle 5: Maximum-size validation
    # -------------------------------------------------------------------------
    Context "Maximum size validation" {

        It "throws when the matrix exceeds the maximum allowed size" {
            $config = @{
                os               = @("ubuntu-latest", "windows-latest", "macos-latest")
                language_version = @("3.9", "3.10", "3.11", "3.12")
                feature_flags    = @("none", "experimental")
            }
            # 3 × 4 × 2 = 24 combinations; cap at 10
            { New-BuildMatrix -Config $config -MaxSize 10 } | Should -Throw
        }

        It "does not throw when the matrix is within the allowed size" {
            $config = @{
                os               = @("ubuntu-latest", "windows-latest")
                language_version = @("3.10", "3.11")
            }
            # 2 × 2 = 4 combinations
            { New-BuildMatrix -Config $config -MaxSize 10 } | Should -Not -Throw
        }

        It "defaults to a maximum of 256 entries (GitHub Actions limit)" {
            # Build a config that produces exactly 256 entries — should succeed
            # 16 × 16 = 256
            $config = @{
                a = 1..16 | ForEach-Object { "a$_" }
                b = 1..16 | ForEach-Object { "b$_" }
            }
            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It "throws by default when the matrix exceeds 256 entries" {
            # 17 × 16 = 272 > 256
            $config = @{
                a = 1..17 | ForEach-Object { "a$_" }
                b = 1..16 | ForEach-Object { "b$_" }
            }
            { New-BuildMatrix -Config $config } | Should -Throw
        }
    }

    # -------------------------------------------------------------------------
    # Cycle 6: JSON output
    # -------------------------------------------------------------------------
    Context "JSON output" {

        It "ConvertTo-MatrixJson produces valid JSON from a matrix result" {
            $config = @{
                os               = @("ubuntu-latest")
                language_version = @("3.10")
            }
            $result = New-BuildMatrix -Config $config
            $json   = ConvertTo-MatrixJson -MatrixResult $result

            $parsed = $json | ConvertFrom-Json
            $parsed.strategy.'fail-fast' | Should -Be $false
            $parsed.matrix.include       | Should -HaveCount 1
        }

        It "JSON output includes max-parallel when set" {
            $config = @{ os = @("ubuntu-latest") }
            $result = New-BuildMatrix -Config $config -MaxParallel 2
            $json   = ConvertTo-MatrixJson -MatrixResult $result

            $parsed = $json | ConvertFrom-Json
            $parsed.strategy.'max-parallel' | Should -Be 2
        }
    }
}
