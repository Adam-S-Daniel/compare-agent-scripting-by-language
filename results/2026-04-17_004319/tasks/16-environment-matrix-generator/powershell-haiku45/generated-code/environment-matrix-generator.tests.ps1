BeforeAll {
    . $PSScriptRoot/environment-matrix-generator.ps1
}

Describe "Environment Matrix Generator" {
    Context "Basic matrix generation" {
        It "should generate a simple OS matrix" {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config
            $matrix = $result.matrix

            $matrix.include.Count | Should -Be 2
            $matrix.include[0].os | Should -Be 'ubuntu-latest'
            $matrix.include[1].os | Should -Be 'windows-latest'
        }
    }

    Context "Multi-dimensional matrix" {
        It "should generate cartesian product of OS and language versions" {
            $config = @{
                os = @('ubuntu-latest')
                language = @('1.0', '1.1')
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config
            $matrix = $result.matrix

            $matrix.include.Count | Should -Be 2
            $matrix.include[0].language | Should -Be '1.0'
            $matrix.include[1].language | Should -Be '1.1'
        }
    }

    Context "Feature flags" {
        It "should include feature flags in matrix" {
            $config = @{
                os = @('ubuntu-latest')
                features = @{
                    enable_debug = @($true, $false)
                }
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config
            $matrix = $result.matrix

            $matrix.include.Count | Should -Be 2
            $matrix.include[0].enable_debug | Should -Be $true
            $matrix.include[1].enable_debug | Should -Be $false
        }
    }

    Context "Include rules" {
        It "should add extra combinations via include rules" {
            $config = @{
                os = @('ubuntu-latest')
                language = @('1.0')
                include = @(
                    @{ os = 'macos-latest'; language = '1.0'; special = 'value' }
                )
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config
            $matrix = $result.matrix

            $matrix.include.Count | Should -Be 2
            $matrix.include[-1].os | Should -Be 'macos-latest'
            $matrix.include[-1].special | Should -Be 'value'
        }
    }

    Context "Exclude rules" {
        It "should remove excluded combinations" {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                language = @('1.0', '1.1')
                exclude = @(
                    @{ os = 'windows-latest'; language = '1.1' }
                )
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config
            $matrix = $result.matrix

            # Should have 3: (ubuntu,1.0), (ubuntu,1.1), (windows,1.0)
            $matrix.include.Count | Should -Be 3
            $doesNotContain = $matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.language -eq '1.1' }
            $doesNotContain | Should -BeNullOrEmpty
        }
    }

    Context "Max parallel" {
        It "should set max-parallel when specified" {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest')
                'max-parallel' = 4
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config

            $result.'max-parallel' | Should -Be 4
        }
    }

    Context "Fail fast configuration" {
        It "should set fail-fast when specified" {
            $config = @{
                os = @('ubuntu-latest')
                'fail-fast' = $false
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config

            $result.'fail-fast' | Should -Be $false
        }
    }

    Context "Matrix size validation" {
        It "should reject matrix exceeding max size" {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                language = @('1.0', '1.1', '1.2')
                features = @{
                    enable_debug = @($true, $false)
                }
                'max-matrix-size' = 10
            }

            { ConvertTo-GitHubActionsMatrix -Configuration $config -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Error handling" {
        It "should provide helpful error message for invalid config" {
            $config = @{ }

            { ConvertTo-GitHubActionsMatrix -Configuration $config -ErrorAction Stop } | Should -Throw
        }
    }

    Context "JSON output" {
        It "should output valid JSON" {
            $config = @{
                os = @('ubuntu-latest')
                language = @('1.0')
            }

            $result = ConvertTo-GitHubActionsMatrix -Configuration $config
            $json = $result | ConvertTo-Json

            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}
