# Environment Matrix Generator - Pester Tests
# TDD approach: tests written first, then implementation added incrementally

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}
Import-Module Pester -MinimumVersion 5.0

# Import the module under test (will fail until we create it)
$scriptPath = Join-Path $PSScriptRoot "MatrixGenerator.ps1"
. $scriptPath

Describe "MatrixGenerator" {

    # =========================================================
    # RED: Test 1 - Basic matrix generation from OS + language
    # =========================================================
    Context "Basic matrix generation" {

        It "generates all OS x language combinations" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("python-3.10", "python-3.11")
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.include | Should -HaveCount 0
            $matrix.exclude | Should -HaveCount 0
            # The main axes: os x language = 4 combinations
            $matrix.os       | Should -BeExactly @("ubuntu-latest", "windows-latest")
            $matrix.language | Should -BeExactly @("python-3.10", "python-3.11")
        }

        It "returns valid JSON" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("node-18")
            }

            $result = New-BuildMatrix -Config $config
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "includes all config axes in the matrix" {
            $config = @{
                os            = @("ubuntu-latest", "windows-latest", "macos-latest")
                language      = @("python-3.10", "python-3.11")
                feature_flags = @("experimental", "stable")
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.os            | Should -BeExactly @("ubuntu-latest", "windows-latest", "macos-latest")
            $matrix.language      | Should -BeExactly @("python-3.10", "python-3.11")
            $matrix.feature_flags | Should -BeExactly @("experimental", "stable")
        }
    }

    # =========================================================
    # RED: Test 2 - fail-fast and max-parallel settings
    # =========================================================
    Context "Matrix settings" {

        It "includes fail-fast setting when provided" {
            $config = @{
                os        = @("ubuntu-latest")
                language  = @("node-18")
                fail_fast = $false
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.fail_fast | Should -Be $false
        }

        It "includes max-parallel setting when provided" {
            $config = @{
                os           = @("ubuntu-latest")
                language     = @("node-18")
                max_parallel = 4
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.max_parallel | Should -Be 4
        }

        It "defaults fail-fast to true when not specified" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("node-18")
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.fail_fast | Should -Be $true
        }
    }

    # =========================================================
    # RED: Test 3 - include rules (additional combinations)
    # =========================================================
    Context "Include rules" {

        It "adds include entries to the matrix" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("python-3.10")
                include  = @(
                    @{ os = "windows-latest"; language = "python-3.9"; experimental = $true }
                )
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.include | Should -HaveCount 1
            $matrix.include[0].os           | Should -Be "windows-latest"
            $matrix.include[0].language     | Should -Be "python-3.9"
            $matrix.include[0].experimental | Should -Be $true
        }

        It "adds multiple include entries" {
            $config = @{
                os      = @("ubuntu-latest")
                language = @("python-3.10")
                include = @(
                    @{ os = "windows-latest"; language = "python-3.9" }
                    @{ os = "macos-latest";   language = "python-3.8" }
                )
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.include | Should -HaveCount 2
        }
    }

    # =========================================================
    # RED: Test 4 - exclude rules (remove combinations)
    # =========================================================
    Context "Exclude rules" {

        It "adds exclude entries to the matrix" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("python-3.10", "python-3.11")
                exclude  = @(
                    @{ os = "windows-latest"; language = "python-3.10" }
                )
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.exclude | Should -HaveCount 1
            $matrix.exclude[0].os       | Should -Be "windows-latest"
            $matrix.exclude[0].language | Should -Be "python-3.10"
        }
    }

    # =========================================================
    # RED: Test 5 - matrix size validation
    # =========================================================
    Context "Matrix size validation" {

        It "throws when matrix exceeds max size (256 by default)" {
            # 17 x 16 = 272 combinations > 256
            $config = @{
                os       = 1..17 | ForEach-Object { "os-$_" }
                language = 1..16 | ForEach-Object { "lang-$_" }
            }

            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
        }

        It "succeeds when matrix is exactly at max size" {
            # 16 x 16 = 256 combinations == 256
            $config = @{
                os       = 1..16 | ForEach-Object { "os-$_" }
                language = 1..16 | ForEach-Object { "lang-$_" }
            }

            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It "respects a custom max size" {
            # 3 x 3 = 9 > 5 (custom max)
            $config = @{
                os       = @("ubuntu-latest", "windows-latest", "macos-latest")
                language = @("python-3.10", "python-3.11", "python-3.12")
                max_size = 5
            }

            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
        }

        It "throws with a meaningful error message showing sizes" {
            $config = @{
                os       = 1..17 | ForEach-Object { "os-$_" }
                language = 1..16 | ForEach-Object { "lang-$_" }
            }

            $err = ""
            try { New-BuildMatrix -Config $config } catch { $err = $_.Exception.Message }
            $err | Should -Match "272"
            $err | Should -Match "256"
        }
    }

    # =========================================================
    # RED: Test 6 - error handling for invalid config
    # =========================================================
    Context "Input validation" {

        It "throws when config is null" {
            { New-BuildMatrix -Config $null } | Should -Throw "*config*"
        }

        It "throws when no axes are defined" {
            $config = @{}
            { New-BuildMatrix -Config $config } | Should -Throw "*at least one axis*"
        }

        It "throws when an axis value list is empty" {
            $config = @{
                os       = @()
                language = @("python-3.10")
            }
            { New-BuildMatrix -Config $config } | Should -Throw "*empty*"
        }

        It "throws when max_parallel is non-positive" {
            $config = @{
                os           = @("ubuntu-latest")
                language     = @("node-18")
                max_parallel = 0
            }
            { New-BuildMatrix -Config $config } | Should -Throw "*max_parallel*"
        }
    }

    # =========================================================
    # RED: Test 7 - full integration / output shape
    # =========================================================
    Context "Full integration" {

        It "produces a complete GitHub Actions strategy.matrix object" {
            $config = @{
                os            = @("ubuntu-latest", "windows-latest")
                language      = @("python-3.10", "python-3.11")
                feature_flags = @("stable")
                fail_fast     = $false
                max_parallel  = 3
                include       = @(
                    @{ os = "macos-latest"; language = "python-3.10"; feature_flags = "stable" }
                )
                exclude       = @(
                    @{ os = "windows-latest"; language = "python-3.10" }
                )
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.os            | Should -Not -BeNullOrEmpty
            $matrix.language      | Should -Not -BeNullOrEmpty
            $matrix.feature_flags | Should -Not -BeNullOrEmpty
            $matrix.fail_fast     | Should -Be $false
            $matrix.max_parallel  | Should -Be 3
            $matrix.include       | Should -HaveCount 1
            $matrix.exclude       | Should -HaveCount 1
        }

        It "computes the correct cartesian product size" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest", "macos-latest")
                language = @("python-3.10", "python-3.11")
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json
            $matrix.matrix_size | Should -Be 6
        }
    }
}
