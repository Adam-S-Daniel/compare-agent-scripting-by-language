Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test before all tests
BeforeAll {
    . "$PSScriptRoot/MatrixGenerator.ps1"
}

# =============================================================================
# TDD Test Suite for New-BuildMatrix
#
# Each Describe/Context block corresponds to a TDD cycle:
#   RED   -> wrote the test first (it would fail without implementation)
#   GREEN -> wrote the minimum code to pass
#   REFACTOR -> cleaned up while keeping tests green
# =============================================================================

Describe 'New-BuildMatrix' {

    # =========================================================================
    # TDD Cycle 1: Basic cartesian-product matrix generation
    # =========================================================================
    Context 'Basic matrix generation (cartesian product)' {

        It 'Should generate all combinations from OS, language, and feature dimensions' {
            # Arrange: 2 OSes x 2 languages x 2 features = 8 combinations
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                    feature  = @('enabled', 'disabled')
                }
            }

            # Act
            [hashtable]$result = New-BuildMatrix -Config $config

            # Assert
            $result.matrix.Count | Should -Be 8

            foreach ($combo in $result.matrix) {
                $combo.Keys | Should -Contain 'os'
                $combo.Keys | Should -Contain 'language'
                $combo.Keys | Should -Contain 'feature'
            }
        }

        It 'Should produce correct specific combinations for a 2x2 matrix' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                }
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            $result.matrix.Count | Should -Be 4

            # Check that a specific combination exists
            [array]$found = $result.matrix | Where-Object {
                $_.os -eq 'ubuntu-latest' -and $_.language -eq '3.9'
            }
            $found.Count | Should -Be 1

            [array]$found2 = $result.matrix | Where-Object {
                $_.os -eq 'windows-latest' -and $_.language -eq '3.10'
            }
            $found2.Count | Should -Be 1
        }

        It 'Should handle single-value dimensions' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest')
                    language = @('3.9', '3.10', '3.11')
                }
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.matrix.Count | Should -Be 3

            foreach ($combo in $result.matrix) {
                $combo.os | Should -Be 'ubuntu-latest'
            }
        }

        It 'Should handle a single dimension with multiple values' {
            [hashtable]$config = @{
                dimensions = @{
                    os = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                }
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.matrix.Count | Should -Be 3
        }
    }

    # =========================================================================
    # TDD Cycle 2: Include rules
    # =========================================================================
    Context 'Include rules' {

        It 'Should add extra combinations via include rules' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest')
                    language = @('3.9')
                }
                include = @(
                    @{ os = 'macos-latest'; language = '3.9' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            # 1 base combination + 1 included = 2
            $result.matrix.Count | Should -Be 2

            [array]$macEntry = $result.matrix | Where-Object { $_.os -eq 'macos-latest' }
            $macEntry.Count | Should -Be 1
            $macEntry[0].language | Should -Be '3.9'
        }

        It 'Should add extra properties to matching combinations via include' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9')
                }
                include = @(
                    @{ os = 'ubuntu-latest'; language = '3.9'; experimental = 'true' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            # The include matches an existing combo, so it augments it (no new row)
            $result.matrix.Count | Should -Be 2

            [array]$ubuntu = $result.matrix | Where-Object { $_.os -eq 'ubuntu-latest' }
            $ubuntu[0].experimental | Should -Be 'true'

            # windows should not have the extra property
            [array]$windows = $result.matrix | Where-Object { $_.os -eq 'windows-latest' }
            $windows[0].Keys | Should -Not -Contain 'experimental'
        }

        It 'Should handle multiple include rules' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest')
                    language = @('3.9')
                }
                include = @(
                    @{ os = 'macos-latest'; language = '3.10' },
                    @{ os = 'windows-latest'; language = '3.11' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            # 1 base + 2 new includes = 3
            $result.matrix.Count | Should -Be 3
        }
    }

    # =========================================================================
    # TDD Cycle 3: Exclude rules
    # =========================================================================
    Context 'Exclude rules' {

        It 'Should remove matching combinations via exclude rules' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                }
                exclude = @(
                    @{ os = 'windows-latest'; language = '3.9' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            # 2x2=4 minus 1 excluded = 3
            $result.matrix.Count | Should -Be 3

            [array]$excluded = $result.matrix | Where-Object {
                $_.os -eq 'windows-latest' -and $_.language -eq '3.9'
            }
            $excluded.Count | Should -Be 0
        }

        It 'Should handle partial exclude matching (match on subset of keys)' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                    feature  = @('enabled', 'disabled')
                }
                exclude = @(
                    @{ os = 'windows-latest'; language = '3.9' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            # 2x2x2=8, exclude all where os=windows AND language=3.9 (2 combos) = 6
            $result.matrix.Count | Should -Be 6

            [array]$excluded = $result.matrix | Where-Object {
                $_.os -eq 'windows-latest' -and $_.language -eq '3.9'
            }
            $excluded.Count | Should -Be 0
        }

        It 'Should handle multiple exclude rules' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                    language = @('3.9')
                }
                exclude = @(
                    @{ os = 'windows-latest' },
                    @{ os = 'macos-latest' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            $result.matrix.Count | Should -Be 1
            $result.matrix[0].os | Should -Be 'ubuntu-latest'
        }
    }

    # =========================================================================
    # TDD Cycle 4: Include and exclude combined
    # =========================================================================
    Context 'Include and exclude combined' {

        It 'Should apply excludes before includes' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                }
                exclude = @(
                    @{ os = 'windows-latest'; language = '3.10' }
                )
                include = @(
                    @{ os = 'macos-latest'; language = '3.11' }
                )
            }

            [hashtable]$result = New-BuildMatrix -Config $config

            # 2x2=4 minus 1 excluded + 1 included = 4
            $result.matrix.Count | Should -Be 4

            [array]$macEntry = $result.matrix | Where-Object { $_.os -eq 'macos-latest' }
            $macEntry.Count | Should -Be 1
        }
    }

    # =========================================================================
    # TDD Cycle 5: max-parallel and fail-fast configuration
    # =========================================================================
    Context 'Max-parallel and fail-fast configuration' {

        It 'Should set fail-fast to true by default' {
            [hashtable]$config = @{
                dimensions = @{
                    os = @('ubuntu-latest')
                }
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $true
        }

        It 'Should respect explicit fail-fast setting of false' {
            [hashtable]$config = @{
                dimensions = @{
                    os = @('ubuntu-latest')
                }
                'fail-fast' = $false
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $false
        }

        It 'Should set max-parallel when specified' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                }
                'max-parallel' = 2
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.'max-parallel' | Should -Be 2
        }

        It 'Should not include max-parallel when not specified' {
            [hashtable]$config = @{
                dimensions = @{
                    os = @('ubuntu-latest')
                }
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.Keys | Should -Not -Contain 'max-parallel'
        }
    }

    # =========================================================================
    # TDD Cycle 6: Maximum matrix size validation
    # =========================================================================
    Context 'Maximum matrix size validation' {

        It 'Should throw when matrix exceeds default max size of 256' {
            # Build a config that creates > 256 combinations
            [hashtable]$config = @{
                dimensions = @{
                    d1 = 1..17 | ForEach-Object { "v$_" }
                    d2 = 1..16 | ForEach-Object { "v$_" }
                }
            }
            # 17 * 16 = 272 > 256

            { New-BuildMatrix -Config $config } | Should -Throw '*exceeds maximum*'
        }

        It 'Should respect a custom MaxSize parameter' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                }
            }
            # 2x2 = 4, which exceeds custom max of 3

            { New-BuildMatrix -Config $config -MaxSize 3 } | Should -Throw '*exceeds maximum*'
        }

        It 'Should pass when matrix is exactly at max size' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9', '3.10')
                }
            }
            # 2x2 = 4, max of 4 should be fine

            { New-BuildMatrix -Config $config -MaxSize 4 } | Should -Not -Throw
        }

        It 'Should validate size after excludes are applied' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                    language = @('3.9', '3.10')
                }
                exclude = @(
                    @{ os = 'macos-latest' }
                )
            }
            # 3x2=6, minus 2 excluded = 4, which fits in max of 5

            { New-BuildMatrix -Config $config -MaxSize 5 } | Should -Not -Throw

            [hashtable]$result = New-BuildMatrix -Config $config -MaxSize 5
            $result.matrix.Count | Should -Be 4
        }
    }

    # =========================================================================
    # TDD Cycle 7: Error handling and edge cases
    # =========================================================================
    Context 'Error handling and edge cases' {

        It 'Should throw when config is null' {
            { New-BuildMatrix -Config $null } | Should -Throw
        }

        It 'Should throw when dimensions are missing' {
            [hashtable]$config = @{}

            { New-BuildMatrix -Config $config } | Should -Throw '*dimensions*'
        }

        It 'Should throw when a dimension has an empty array' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest')
                    language = @()
                }
            }

            { New-BuildMatrix -Config $config } | Should -Throw '*empty*'
        }

        It 'Should throw when dimensions is not a hashtable' {
            [hashtable]$config = @{
                dimensions = 'not-a-hashtable'
            }

            { New-BuildMatrix -Config $config } | Should -Throw '*hashtable*'
        }

        It 'Should handle string values (not arrays) in dimensions by wrapping them' {
            [hashtable]$config = @{
                dimensions = @{
                    os = 'ubuntu-latest'
                }
            }

            [hashtable]$result = New-BuildMatrix -Config $config
            $result.matrix.Count | Should -Be 1
            $result.matrix[0].os | Should -Be 'ubuntu-latest'
        }
    }

    # =========================================================================
    # TDD Cycle 8: JSON output
    # =========================================================================
    Context 'JSON output via ConvertTo-MatrixJson' {

        It 'Should produce valid JSON output' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest', 'windows-latest')
                    language = @('3.9')
                }
                'fail-fast' = $false
                'max-parallel' = 2
            }

            [hashtable]$matrixResult = New-BuildMatrix -Config $config
            [string]$json = ConvertTo-MatrixJson -Matrix $matrixResult

            # Should be valid JSON
            { $json | ConvertFrom-Json } | Should -Not -Throw

            # Verify structure
            $parsed = $json | ConvertFrom-Json
            $parsed.'fail-fast' | Should -Be $false
            $parsed.'max-parallel' | Should -Be 2
            $parsed.matrix.Count | Should -Be 2
        }

        It 'Should include all dimension values in JSON output' {
            [hashtable]$config = @{
                dimensions = @{
                    os       = @('ubuntu-latest')
                    language = @('3.9')
                }
            }

            [hashtable]$matrixResult = New-BuildMatrix -Config $config
            [string]$json = ConvertTo-MatrixJson -Matrix $matrixResult
            $parsed = $json | ConvertFrom-Json

            $parsed.matrix[0].os | Should -Be 'ubuntu-latest'
            $parsed.matrix[0].language | Should -Be '3.9'
        }
    }

    # =========================================================================
    # TDD Cycle 9: MaxSize applies after includes too
    # =========================================================================
    Context 'MaxSize validation after includes' {

        It 'Should validate size after includes are added' {
            [hashtable]$config = @{
                dimensions = @{
                    os = @('ubuntu-latest')
                }
                include = @(
                    @{ os = 'windows-latest' },
                    @{ os = 'macos-latest' }
                )
            }
            # 1 base + 2 includes = 3, max of 2 should fail

            { New-BuildMatrix -Config $config -MaxSize 2 } | Should -Throw '*exceeds maximum*'
        }
    }
}
