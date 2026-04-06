# MatrixGenerator.Tests.ps1
# Pester test suite for the Environment Matrix Generator
# Uses red/green TDD: tests were written before implementation

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot 'MatrixGenerator.psm1'
Import-Module $ModulePath -Force

Describe 'New-BuildMatrix' {

    # -----------------------------------------------------------------------
    # PHASE 1: Basic matrix generation — Cartesian product of dimensions
    # -----------------------------------------------------------------------

    Context 'Basic Cartesian product generation' {

        It 'generates a matrix with a single OS and single language version' {
            # Arrange
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }

            # Act
            $result = New-BuildMatrix -Config $config

            # Assert
            $result.matrix.include | Should -BeNullOrEmpty
            $result.matrix.os      | Should -Be @('ubuntu-latest')
            $result.matrix.language | Should -Be @('3.11')
        }

        It 'generates correct total combination count for multiple dimensions' {
            # 2 OS × 3 language versions = 6 combinations
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                language = @('3.9', '3.10', '3.11')
            }

            $result = New-BuildMatrix -Config $config
            $result.combinationCount | Should -Be 6
        }

        It 'includes feature flags as a matrix dimension when provided' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
                experimental = @($true, $false)
            }

            $result = New-BuildMatrix -Config $config
            $result.matrix.experimental | Should -Contain $true
            $result.matrix.experimental | Should -Contain $false
            $result.combinationCount | Should -Be 2
        }
    }

    # -----------------------------------------------------------------------
    # PHASE 2: include / exclude rules
    # -----------------------------------------------------------------------

    Context 'Include rules' {

        It 'adds extra entries to matrix.include' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }
            $includes = @(
                @{ os = 'macos-latest'; language = '3.12'; experimental = $true }
            )

            $result = New-BuildMatrix -Config $config -Include $includes

            $result.matrix.include | Should -HaveCount 1
            $result.matrix.include[0].os | Should -Be 'macos-latest'
            $result.matrix.include[0].language | Should -Be '3.12'
        }

        It 'multiple include entries are all present' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }
            $includes = @(
                @{ os = 'macos-latest'; language = '3.12' }
                @{ os = 'windows-latest'; language = '3.13'; extra = 'yes' }
            )

            $result = New-BuildMatrix -Config $config -Include $includes
            $result.matrix.include | Should -HaveCount 2
        }
    }

    Context 'Exclude rules' {

        It 'adds entries to matrix.exclude' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                language = @('3.9', '3.11')
            }
            $excludes = @(
                @{ os = 'windows-latest'; language = '3.9' }
            )

            $result = New-BuildMatrix -Config $config -Exclude $excludes

            $result.matrix.exclude | Should -HaveCount 1
            $result.matrix.exclude[0].os | Should -Be 'windows-latest'
            # Combination count reflects the exclusion
            $result.combinationCount | Should -Be 3
        }

        It 'handles multiple exclude entries' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                language = @('3.9', '3.11')
            }
            $excludes = @(
                @{ os = 'windows-latest'; language = '3.9' }
                @{ os = 'macos-latest';   language = '3.9' }
            )

            $result = New-BuildMatrix -Config $config -Exclude $excludes
            $result.matrix.exclude | Should -HaveCount 2
            $result.combinationCount | Should -Be 4
        }
    }

    # -----------------------------------------------------------------------
    # PHASE 3: max-parallel and fail-fast settings
    # -----------------------------------------------------------------------

    Context 'max-parallel configuration' {

        It 'sets max-parallel in the output when specified' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }

            $result = New-BuildMatrix -Config $config -MaxParallel 4

            $result.maxParallel | Should -Be 4
        }

        It 'omits max-parallel from output when not specified' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }

            $result = New-BuildMatrix -Config $config

            $result.PSObject.Properties.Name | Should -Not -Contain 'maxParallel'
        }
    }

    Context 'fail-fast configuration' {

        It 'sets fail-fast to true when specified' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }

            $result = New-BuildMatrix -Config $config -FailFast $true

            $result.failFast | Should -Be $true
        }

        It 'sets fail-fast to false when specified' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }

            $result = New-BuildMatrix -Config $config -FailFast $false

            $result.failFast | Should -Be $false
        }

        It 'omits fail-fast from output when not specified' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }

            $result = New-BuildMatrix -Config $config

            $result.PSObject.Properties.Name | Should -Not -Contain 'failFast'
        }
    }

    # -----------------------------------------------------------------------
    # PHASE 4: Matrix size validation
    # -----------------------------------------------------------------------

    Context 'Matrix size validation' {

        It 'throws when combination count exceeds MaxSize' {
            # 3 × 3 × 3 = 27 combinations, limit set to 10
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                language = @('3.9', '3.10', '3.11')
                arch     = @('x64', 'arm64', 'x86')
            }

            { New-BuildMatrix -Config $config -MaxSize 10 } | Should -Throw '*exceeds*'
        }

        It 'does not throw when combination count equals MaxSize' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                language = @('3.9', '3.10', '3.11')
            }

            # 2 × 3 = 6 combinations, limit is 6
            { New-BuildMatrix -Config $config -MaxSize 6 } | Should -Not -Throw
        }

        It 'uses default MaxSize of 256 when not specified' {
            # Build a config with 256 combos — should pass
            $os   = 1..16 | ForEach-Object { "os-$_" }
            $lang = 1..16 | ForEach-Object { "lang-$_" }
            $config = @{ os = $os; language = $lang }

            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It 'throws when default limit of 256 is exceeded' {
            $os   = 1..17 | ForEach-Object { "os-$_" }
            $lang = 1..16 | ForEach-Object { "lang-$_" }
            $config = @{ os = $os; language = $lang }  # 17×16 = 272

            { New-BuildMatrix -Config $config } | Should -Throw '*exceeds*'
        }
    }

    # -----------------------------------------------------------------------
    # PHASE 5: JSON serialisation via ConvertTo-MatrixJson
    # -----------------------------------------------------------------------

    Context 'ConvertTo-MatrixJson output' {

        It 'produces valid JSON' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.11')
            }
            $matrix = New-BuildMatrix -Config $config

            $json = ConvertTo-MatrixJson -MatrixResult $matrix

            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON contains matrix key with os array' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                language = @('3.11')
            }
            $matrix = New-BuildMatrix -Config $config

            $json   = ConvertTo-MatrixJson -MatrixResult $matrix
            $parsed = $json | ConvertFrom-Json

            $parsed.matrix.os | Should -Contain 'ubuntu-latest'
            $parsed.matrix.os | Should -Contain 'windows-latest'
        }

        It 'JSON contains maxParallel when set' {
            $config = @{ os = @('ubuntu-latest'); language = @('3.11') }
            $matrix = New-BuildMatrix -Config $config -MaxParallel 8

            $json   = ConvertTo-MatrixJson -MatrixResult $matrix
            $parsed = $json | ConvertFrom-Json

            $parsed.maxParallel | Should -Be 8
        }

        It 'JSON contains failFast when set' {
            $config = @{ os = @('ubuntu-latest'); language = @('3.11') }
            $matrix = New-BuildMatrix -Config $config -FailFast $false

            $json   = ConvertTo-MatrixJson -MatrixResult $matrix
            $parsed = $json | ConvertFrom-Json

            $parsed.failFast | Should -Be $false
        }
    }

    # -----------------------------------------------------------------------
    # PHASE 6: Error handling — invalid inputs
    # -----------------------------------------------------------------------

    Context 'Input validation' {

        It 'throws when Config is empty' {
            { New-BuildMatrix -Config @{} } | Should -Throw '*at least one*'
        }

        It 'throws when Config has a dimension with no values' {
            $config = @{ os = @() }
            { New-BuildMatrix -Config $config } | Should -Throw '*empty*'
        }

        It 'throws when MaxParallel is zero or negative' {
            $config = @{ os = @('ubuntu-latest'); language = @('3.11') }
            { New-BuildMatrix -Config $config -MaxParallel 0 }  | Should -Throw '*MaxParallel*'
            { New-BuildMatrix -Config $config -MaxParallel -1 } | Should -Throw '*MaxParallel*'
        }

        It 'throws when MaxSize is zero or negative' {
            $config = @{ os = @('ubuntu-latest'); language = @('3.11') }
            { New-BuildMatrix -Config $config -MaxSize 0 }  | Should -Throw '*MaxSize*'
            { New-BuildMatrix -Config $config -MaxSize -1 } | Should -Throw '*MaxSize*'
        }
    }
}
