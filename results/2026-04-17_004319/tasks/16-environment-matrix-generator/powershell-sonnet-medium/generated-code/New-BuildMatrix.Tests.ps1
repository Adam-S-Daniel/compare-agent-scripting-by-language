# TDD Tests for New-BuildMatrix.ps1
# Red/Green methodology: write failing test first, then implement minimum code to pass

BeforeAll {
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

Describe "New-BuildMatrix" {

    # --- Test 1: Basic matrix generation from config ---
    Context "Basic matrix generation" {
        It "generates a matrix with all combinations of OS and language versions" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.10", "3.11")
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.include | Should -BeNullOrEmpty
            $matrix.exclude | Should -BeNullOrEmpty
            $combinations = @($matrix.matrix.os) | ForEach-Object { $os = $_; @($matrix.matrix.language) | ForEach-Object { @{ os = $os; language = $_ } } }
            $matrix.matrix.os    | Should -Be @("ubuntu-latest", "windows-latest")
            $matrix.matrix.language | Should -Be @("3.10", "3.11")
        }

        It "includes fail-fast and max-parallel in output" {
            $config = @{
                os          = @("ubuntu-latest")
                language    = @("3.10")
                fail_fast   = $false
                max_parallel = 4
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.'fail-fast'    | Should -Be $false
            $matrix.'max-parallel' | Should -Be 4
        }
    }

    # --- Test 2: Include rules ---
    Context "Include rules" {
        It "passes through include entries to the output matrix" {
            $config = @{
                os      = @("ubuntu-latest")
                language = @("3.10")
                include = @(
                    @{ os = "macos-latest"; language = "3.11"; extra = "value" }
                )
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.include | Should -Not -BeNullOrEmpty
            $matrix.include[0].os | Should -Be "macos-latest"
            $matrix.include[0].language | Should -Be "3.11"
            $matrix.include[0].extra | Should -Be "value"
        }
    }

    # --- Test 3: Exclude rules ---
    Context "Exclude rules" {
        It "passes through exclude entries to the output matrix" {
            $config = @{
                os      = @("ubuntu-latest", "windows-latest")
                language = @("3.10", "3.11")
                exclude = @(
                    @{ os = "windows-latest"; language = "3.10" }
                )
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.exclude | Should -Not -BeNullOrEmpty
            $matrix.exclude[0].os | Should -Be "windows-latest"
            $matrix.exclude[0].language | Should -Be "3.10"
        }
    }

    # --- Test 4: Feature flags dimension ---
    Context "Feature flags" {
        It "includes feature flags as a matrix dimension when provided" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.10")
                features = @("flag-a", "flag-b")
            }

            $result = New-BuildMatrix -Config $config
            $matrix = $result | ConvertFrom-Json

            $matrix.matrix.features | Should -Be @("flag-a", "flag-b")
        }
    }

    # --- Test 5: Max size validation ---
    Context "Max size validation" {
        It "throws when the computed matrix size exceeds the maximum" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest", "macos-latest")
                language = @("3.9", "3.10", "3.11", "3.12")
                features = @("a", "b", "c", "d")
                max_size = 10   # 3*4*4 = 48, should fail
            }

            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds the maximum*"
        }

        It "does not throw when matrix size is within the limit" {
            $config = @{
                os       = @("ubuntu-latest", "windows-latest")
                language = @("3.10", "3.11")
                max_size = 10   # 2*2 = 4, should pass
            }

            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It "uses default max size of 256 when not specified" {
            # Build a matrix with exactly 256 combinations: 16 os x 16 language
            $os = 1..16 | ForEach-Object { "os-$_" }
            $lang = 1..16 | ForEach-Object { "lang-$_" }
            $config = @{
                os       = $os
                language = $lang
            }

            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It "throws for a matrix larger than the default 256 limit" {
            $os = 1..17 | ForEach-Object { "os-$_" }
            $lang = 1..16 | ForEach-Object { "lang-$_" }
            $config = @{
                os       = $os
                language = $lang
            }

            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds the maximum*"
        }
    }

    # --- Test 6: Error handling for missing required dimensions ---
    Context "Input validation" {
        It "throws a meaningful error when config is null" {
            { New-BuildMatrix -Config $null } | Should -Throw "*Config cannot be null*"
        }

        It "throws when no matrix dimensions are provided" {
            { New-BuildMatrix -Config @{} } | Should -Throw "*at least one matrix dimension*"
        }
    }

    # --- Test 7: JSON output is valid and well-structured ---
    Context "Output format" {
        It "returns valid JSON string" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.10")
            }

            $result = New-BuildMatrix -Config $config
            $result | Should -BeOfType [string]
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "wraps dimensions under a 'matrix' key" {
            $config = @{
                os       = @("ubuntu-latest")
                language = @("3.10")
            }

            $result = New-BuildMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix | Should -Not -BeNullOrEmpty
            $parsed.matrix.os | Should -Be @("ubuntu-latest")
        }
    }

    # --- Test 8: ConvertFrom-MatrixConfig helper ---
    Context "ConvertFrom-MatrixConfig" {
        It "converts a JSON string config into a hashtable and generates a matrix" {
            $jsonConfig = '{"os":["ubuntu-latest"],"language":["3.10"]}'
            $result = ConvertFrom-MatrixConfig -JsonConfig $jsonConfig
            $matrix = $result | ConvertFrom-Json
            $matrix.matrix.os | Should -Be @("ubuntu-latest")
        }

        It "throws on invalid JSON" {
            { ConvertFrom-MatrixConfig -JsonConfig "not-json" } | Should -Throw
        }
    }
}
