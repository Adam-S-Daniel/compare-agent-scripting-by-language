# Pester tests for MatrixGenerator.ps1
# Red/green TDD: each Describe block was written before its implementation.

BeforeAll {
    . "$PSScriptRoot/MatrixGenerator.ps1"
}

Describe 'New-BuildMatrix - cartesian product' {
    It 'produces a matrix with all input axes' {
        $cfg = @{
            os               = @('ubuntu-latest', 'windows-latest')
            language_version = @('3.10', '3.11')
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.os | Should -Be @('ubuntu-latest', 'windows-latest')
        $result.matrix.language_version | Should -Be @('3.10', '3.11')
    }

    It 'computes cartesian size = product of axis lengths' {
        $cfg = @{
            os               = @('ubuntu-latest', 'windows-latest')
            language_version = @('3.10', '3.11', '3.12')
        }
        $result = New-BuildMatrix -Config $cfg
        $result.size | Should -Be 6
    }

    It 'treats a single-value axis as length 1' {
        $cfg = @{ os = @('ubuntu-latest'); language_version = @('3.11') }
        (New-BuildMatrix -Config $cfg).size | Should -Be 1
    }
}

Describe 'New-BuildMatrix - include/exclude' {
    It 'adds include entries to the emitted matrix' {
        $cfg = @{
            os      = @('ubuntu-latest')
            include = @(@{ os = 'macos-latest'; language_version = '3.12' })
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 1
        $result.matrix.include[0].os | Should -Be 'macos-latest'
    }

    It 'subtracts matching cartesian combos for each exclude' {
        $cfg = @{
            os               = @('ubuntu-latest', 'windows-latest')
            language_version = @('3.10', '3.11')
            exclude          = @(@{ os = 'windows-latest'; language_version = '3.10' })
        }
        $result = New-BuildMatrix -Config $cfg
        # 4 cartesian combos - 1 exclude = 3; + 0 includes = 3
        $result.size | Should -Be 3
    }

    It 'adds includes to the final size' {
        $cfg = @{
            os      = @('ubuntu-latest', 'windows-latest')
            include = @(@{ os = 'macos-latest' })
        }
        (New-BuildMatrix -Config $cfg).size | Should -Be 3
    }
}

Describe 'New-BuildMatrix - fail-fast and max-parallel' {
    It 'emits fail-fast when provided' {
        $cfg = @{ os = @('ubuntu-latest'); fail_fast = $false }
        $result = New-BuildMatrix -Config $cfg
        $result.'fail-fast' | Should -Be $false
    }

    It 'emits max-parallel when provided' {
        $cfg = @{ os = @('ubuntu-latest'); max_parallel = 4 }
        $result = New-BuildMatrix -Config $cfg
        $result.'max-parallel' | Should -Be 4
    }

    It 'omits fail-fast and max-parallel when not set' {
        $cfg = @{ os = @('ubuntu-latest') }
        $result = New-BuildMatrix -Config $cfg
        $result.PSObject.Properties.Name | Should -Not -Contain 'fail-fast'
        $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }
}

Describe 'New-BuildMatrix - validation' {
    It 'throws when matrix exceeds max_size' {
        $cfg = @{
            os               = @('a', 'b', 'c', 'd')
            language_version = @('1', '2', '3', '4')
            max_size         = 5
        }
        { New-BuildMatrix -Config $cfg } | Should -Throw '*exceeds max_size*'
    }

    It 'succeeds when size equals max_size' {
        $cfg = @{ os = @('a', 'b'); language_version = @('1', '2'); max_size = 4 }
        { New-BuildMatrix -Config $cfg } | Should -Not -Throw
    }

    It 'throws when no axes provided and no includes' {
        { New-BuildMatrix -Config @{} } | Should -Throw '*at least one*'
    }

    It 'throws when max_parallel is non-positive' {
        $cfg = @{ os = @('a'); max_parallel = 0 }
        { New-BuildMatrix -Config $cfg } | Should -Throw '*max_parallel*'
    }
}

Describe 'ConvertTo-MatrixJson - GitHub Actions shape' {
    It 'produces JSON with strategy matrix keys' {
        $cfg = @{
            os               = @('ubuntu-latest')
            language_version = @('3.11')
            fail_fast        = $true
            max_parallel     = 2
        }
        $json = New-BuildMatrix -Config $cfg | ConvertTo-MatrixJson
        $parsed = $json | ConvertFrom-Json
        $parsed.matrix.os | Should -Be 'ubuntu-latest'
        $parsed.'fail-fast' | Should -Be $true
        $parsed.'max-parallel' | Should -Be 2
    }
}

Describe 'Invoke-MatrixGenerator - CLI entry point' {
    It 'reads a config file and writes JSON to stdout' {
        $tmp = New-TemporaryFile
        @{ os = @('ubuntu-latest'); language_version = @('3.11') } | ConvertTo-Json | Set-Content $tmp
        $out = Invoke-MatrixGenerator -ConfigPath $tmp.FullName
        $parsed = $out | ConvertFrom-Json
        $parsed.matrix.os | Should -Be 'ubuntu-latest'
        Remove-Item $tmp
    }

    It 'throws a meaningful error when config file is missing' {
        { Invoke-MatrixGenerator -ConfigPath '/no/such/file.json' } | Should -Throw '*not found*'
    }
}
