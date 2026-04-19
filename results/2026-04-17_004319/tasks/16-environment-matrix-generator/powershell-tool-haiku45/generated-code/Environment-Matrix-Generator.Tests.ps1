# Test suite for Environment Matrix Generator
# Uses Pester framework for TDD: write failing test first, then implement

BeforeAll {
    . $PSScriptRoot/Environment-Matrix-Generator.ps1
}

Describe 'Environment Matrix Generator' {
    Context 'Basic Matrix Generation' {
        It 'should generate a matrix from a simple configuration' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                language = @('node-16', 'node-18')
            }

            $matrix = New-EnvironmentMatrix -Config $config

            $matrix | Should -Not -BeNullOrEmpty
            $matrix.include | Should -HaveCount 4
        }

        It 'should generate correct cartesian product' {
            $config = @{
                os = @('linux')
                language = @('python-3.9', 'python-3.10')
            }

            $matrix = New-EnvironmentMatrix -Config $config

            # Should have 2 combinations
            $matrix.include | Should -HaveCount 2
            $matrix.include[0].os | Should -Be 'linux'
            $matrix.include[0].language | Should -Be 'python-3.9'
            $matrix.include[1].language | Should -Be 'python-3.10'
        }
    }

    Context 'Include/Exclude Rules' {
        It 'should support include rules' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('node-16')
                include = @(
                    @{ os = 'macos-latest'; language = 'node-16'; extra_feature = 'arm64' }
                )
            }

            $matrix = New-EnvironmentMatrix -Config $config

            # 1 from include + 1 from base = 2
            $matrix.include | Should -HaveCount 2
            $matrix.include[0].extra_feature | Should -Be 'arm64'
        }

        It 'should support exclude rules' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                language = @('node-16', 'node-18')
                exclude = @(
                    @{ os = 'windows-latest'; language = 'node-16' }
                )
            }

            $matrix = New-EnvironmentMatrix -Config $config

            # 4 base - 1 excluded = 3
            $matrix.include | Should -HaveCount 3

            # Verify the excluded combo is not present
            $excluded = $matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.language -eq 'node-16' }
            $excluded | Should -BeNullOrEmpty
        }
    }

    Context 'Feature Flags' {
        It 'should handle feature flags in matrix' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('go-1.19')
                features = @('debug', 'release')
            }

            $matrix = New-EnvironmentMatrix -Config $config

            # 2 features × 1 os × 1 language = 2
            $matrix.include | Should -HaveCount 2
            $matrix.include[0].features | Should -Be 'debug'
            $matrix.include[1].features | Should -Be 'release'
        }
    }

    Context 'Max Parallel Configuration' {
        It 'should set max-parallel when specified' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                language = @('python-3.9', 'python-3.10')
                maxParallel = 2
            }

            $matrix = New-EnvironmentMatrix -Config $config

            $matrix.'max-parallel' | Should -Be 2
        }

        It 'should not include max-parallel if not specified' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('node-16')
            }

            $matrix = New-EnvironmentMatrix -Config $config

            $matrix.'max-parallel' | Should -BeNullOrEmpty
        }
    }

    Context 'Fail-Fast Configuration' {
        It 'should set fail-fast when specified' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('node-16')
                failFast = $true
            }

            $matrix = New-EnvironmentMatrix -Config $config

            $matrix.'fail-fast' | Should -Be $true
        }

        It 'should set fail-fast to false when specified' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('node-16')
                failFast = $false
            }

            $matrix = New-EnvironmentMatrix -Config $config

            $matrix.'fail-fast' | Should -Be $false
        }
    }

    Context 'Matrix Size Validation' {
        It 'should validate matrix does not exceed max size' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                language = @('node-16', 'node-18', 'node-20')
                features = @('a', 'b', 'c')
                maxSize = 27
            }

            # 3 × 3 × 3 = 27, should not throw
            { New-EnvironmentMatrix -Config $config } | Should -Not -Throw
        }

        It 'should throw when matrix exceeds max size' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                language = @('node-16', 'node-18', 'node-20')
                features = @('a', 'b', 'c')
                maxSize = 10
            }

            # 3 × 3 × 3 = 27 > 10, should throw
            { New-EnvironmentMatrix -Config $config } | Should -Throw
        }

        It 'should use default max size of 256' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('node-16')
            }

            # Should not throw with reasonable config
            { New-EnvironmentMatrix -Config $config } | Should -Not -Throw
        }
    }

    Context 'JSON Output' {
        It 'should output valid JSON' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('node-16')
            }

            $matrix = New-EnvironmentMatrix -Config $config
            $json = $matrix | ConvertTo-Json

            $json | Should -Not -BeNullOrEmpty
            # Should be able to parse it back
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'should output matrix suitable for GitHub Actions' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                language = @('node-18')
                failFast = $true
                maxParallel = 4
            }

            $matrix = New-EnvironmentMatrix -Config $config
            $json = $matrix | ConvertTo-Json
            $parsed = $json | ConvertFrom-Json

            $parsed.include | Should -HaveCount 2
            $parsed.'fail-fast' | Should -Be $true
            $parsed.'max-parallel' | Should -Be 4
        }
    }

    Context 'Configuration Validation' {
        It 'should require at least one dimension' {
            $config = @{}

            { New-EnvironmentMatrix -Config $config } | Should -Throw
        }

        It 'should handle empty arrays gracefully' {
            $config = @{
                os = @()
                language = @('node-16')
            }

            { New-EnvironmentMatrix -Config $config } | Should -Throw
        }
    }

    Context 'Complex Scenarios' {
        It 'should handle include with exclude rules together' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                language = @('node-16', 'node-18')
                include = @(
                    @{ os = 'macos-latest'; language = 'node-18' }
                )
                exclude = @(
                    @{ os = 'windows-latest'; language = 'node-16' }
                )
            }

            $matrix = New-EnvironmentMatrix -Config $config

            # Base: 2×2=4, minus 1 excluded, plus 1 included = 4
            $matrix.include | Should -HaveCount 4

            # Verify the special macos entry exists
            $macos = $matrix.include | Where-Object { $_.os -eq 'macos-latest' }
            $macos | Should -Not -BeNullOrEmpty
        }

        It 'should preserve all properties in matrix entries' {
            $config = @{
                os = @('ubuntu-latest')
                language = @('python-3.9')
                include = @(
                    @{ os = 'ubuntu-latest'; language = 'python-3.9'; debug = 'true'; timeout = '30' }
                )
            }

            $matrix = New-EnvironmentMatrix -Config $config

            $entry = $matrix.include[0]
            $entry.os | Should -Be 'ubuntu-latest'
            $entry.language | Should -Be 'python-3.9'
            $entry.debug | Should -Be 'true'
            $entry.timeout | Should -Be '30'
        }
    }
}
