# Pester tests for MatrixGenerator. Tests drove the implementation: each
# describe block here was added before the corresponding code was written.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'MatrixGenerator.psm1') -Force
}

Describe 'New-BuildMatrix - cartesian product' {
    It 'produces the cartesian product of axes' {
        $config = @{
            axes = [ordered]@{
                os               = @('ubuntu-latest', 'windows-latest')
                language_version = @('1.20', '1.21')
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
    }

    It 'preserves all axes as keys on each combination' {
        $config = @{
            axes = [ordered]@{
                os               = @('ubuntu-latest')
                language_version = @('1.21')
                feature_flag     = @('on', 'off')
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include[0].PSObject.Properties.Name | Should -Contain 'os'
        $result.matrix.include[0].PSObject.Properties.Name | Should -Contain 'language_version'
        $result.matrix.include[0].PSObject.Properties.Name | Should -Contain 'feature_flag'
    }
}

Describe 'New-BuildMatrix - exclude rules' {
    It 'removes combinations matching all exclude criteria' {
        $config = @{
            axes = [ordered]@{
                os               = @('ubuntu-latest', 'windows-latest')
                language_version = @('1.20', '1.21')
            }
            exclude = @(
                @{ os = 'windows-latest'; language_version = '1.20' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 3
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.language_version -eq '1.20' }).Count | Should -Be 0
    }
}

Describe 'New-BuildMatrix - include rules' {
    It 'appends extra combinations from include' {
        $config = @{
            axes = [ordered]@{
                os = @('ubuntu-latest')
            }
            include = @(
                @{ os = 'macos-latest'; experimental = $true }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
        $result.matrix.include[1].experimental | Should -Be $true
    }
}

Describe 'New-BuildMatrix - parallelism and fail-fast' {
    It 'passes through max_parallel and fail_fast' {
        $config = @{
            axes        = [ordered]@{ os = @('ubuntu-latest') }
            max_parallel = 4
            fail_fast    = $false
        }
        $result = New-BuildMatrix -Config $config
        $result.'max-parallel' | Should -Be 4
        $result.'fail-fast' | Should -Be $false
    }

    It 'defaults fail_fast to true and omits max_parallel when not set' {
        $config = @{ axes = [ordered]@{ os = @('ubuntu-latest') } }
        $result = New-BuildMatrix -Config $config
        $result.'fail-fast' | Should -Be $true
        $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }
}

Describe 'New-BuildMatrix - max_size validation' {
    It 'throws when generated matrix exceeds max_size' {
        $config = @{
            axes = [ordered]@{
                os               = @('a', 'b', 'c')
                language_version = @('1', '2', '3')
            }
            max_size = 4
        }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds max_size*'
    }

    It 'succeeds at exactly max_size' {
        $config = @{
            axes     = [ordered]@{ os = @('a', 'b') }
            max_size = 2
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }
}

Describe 'New-BuildMatrix - input validation' {
    It 'throws on missing axes' {
        { New-BuildMatrix -Config @{} } | Should -Throw -ExpectedMessage '*axes*'
    }

    It 'throws on empty axis list' {
        { New-BuildMatrix -Config @{ axes = @{ os = @() } } } | Should -Throw -ExpectedMessage '*empty*'
    }
}

Describe 'ConvertTo-MatrixJson' {
    It 'serializes the result with stable key ordering' {
        $config = @{
            axes        = [ordered]@{ os = @('ubuntu-latest') }
            max_parallel = 2
        }
        $json = New-BuildMatrix -Config $config | ConvertTo-MatrixJson
        $json | Should -Match '"matrix"'
        $json | Should -Match '"max-parallel": 2'
    }
}
