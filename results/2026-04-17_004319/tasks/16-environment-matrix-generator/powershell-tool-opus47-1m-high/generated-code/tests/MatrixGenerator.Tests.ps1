# Pester tests for the environment matrix generator.
#
# TDD journey:
#   1. Started by writing the "cartesian product" test first; confirmed the
#      module wasn't loaded (red), then added Get-CartesianProduct (green).
#   2. Added exclude tests; implemented Test-MatchesAnyRule and rule filter.
#   3. Added include tests; implemented append semantics for include rules.
#   4. Added max_size / fail_fast / max_parallel / validation cases last.
# Run with: Invoke-Pester -Path ./tests -Output Detailed

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'MatrixGenerator.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module MatrixGenerator -ErrorAction SilentlyContinue
}

Describe 'New-BuildMatrix: cartesian product' {
    It 'generates all combinations of a 2x2 matrix' {
        $cfg = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
        }
        $m = New-BuildMatrix -Config $cfg
        $m.total                  | Should -Be 4
        $m.matrix.include.Count   | Should -Be 4
    }

    It 'generates a single entry for a 1x1 matrix' {
        $cfg = @{ dimensions = @{ os = @('ubuntu-latest') } }
        $m = New-BuildMatrix -Config $cfg
        $m.total                | Should -Be 1
        $m.matrix.include[0].os | Should -Be 'ubuntu-latest'
    }

    It 'expands a 3-axis matrix to the full product' {
        $cfg = @{
            dimensions = @{
                os      = @('ubuntu-latest', 'windows-latest')
                node    = @('18', '20')
                feature = @('on', 'off')
            }
        }
        $m = New-BuildMatrix -Config $cfg
        $m.total | Should -Be 8
    }
}

Describe 'New-BuildMatrix: exclude rules' {
    It 'removes combinations matching a fully-specified exclude rule' {
        $cfg = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(@{ os = 'windows-latest'; node = '18' })
        }
        $m = New-BuildMatrix -Config $cfg
        $m.total | Should -Be 3
        ($m.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '18' }) | Should -BeNullOrEmpty
    }

    It 'removes every combination matching a partial exclude rule' {
        $cfg = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(@{ os = 'windows-latest' })
        }
        $m = New-BuildMatrix -Config $cfg
        $m.total | Should -Be 2
        ($m.matrix.include | Where-Object { $_.os -eq 'windows-latest' }).Count | Should -Be 0
    }

    It 'supports multiple exclude rules' {
        $cfg = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest'; node = '18' },
                @{ os = 'macos-latest';   node = '18' }
            )
        }
        $m = New-BuildMatrix -Config $cfg
        $m.total | Should -Be 4
    }
}

Describe 'New-BuildMatrix: include rules' {
    It 'appends an extra combination from include' {
        $cfg = @{
            dimensions = @{ os = @('ubuntu-latest'); node = @('20') }
            include    = @(@{ os = 'macos-latest'; node = '20'; experimental = $true })
        }
        $m = New-BuildMatrix -Config $cfg
        $m.total | Should -Be 2
        ($m.matrix.include | Where-Object { $_.os -eq 'macos-latest' }).experimental | Should -Be $true
    }
}

Describe 'New-BuildMatrix: strategy options' {
    It 'defaults fail-fast to true' {
        $m = New-BuildMatrix -Config @{ dimensions = @{ os = @('ubuntu-latest') } }
        $m['fail-fast'] | Should -Be $true
    }

    It 'honors fail_fast = false' {
        $m = New-BuildMatrix -Config @{
            dimensions = @{ os = @('ubuntu-latest') }
            fail_fast  = $false
        }
        $m['fail-fast'] | Should -Be $false
    }

    It 'emits max-parallel when > 0' {
        $m = New-BuildMatrix -Config @{
            dimensions   = @{ os = @('ubuntu-latest', 'windows-latest') }
            max_parallel = 4
        }
        $m['max-parallel'] | Should -Be 4
    }

    It 'omits max-parallel when zero or unspecified' {
        $m = New-BuildMatrix -Config @{ dimensions = @{ os = @('ubuntu-latest') } }
        $m.Contains('max-parallel') | Should -Be $false
    }
}

Describe 'New-BuildMatrix: max_size validation' {
    It 'throws when the generated matrix exceeds max_size' {
        $cfg = @{
            dimensions = @{ a = @('1','2','3'); b = @('x','y','z') }
            max_size   = 5
        }
        { New-BuildMatrix -Config $cfg } | Should -Throw '*exceeds maximum*'
    }

    It 'accepts a matrix at exactly max_size' {
        $cfg = @{
            dimensions = @{ a = @('1','2','3'); b = @('x','y','z') }
            max_size   = 9
        }
        (New-BuildMatrix -Config $cfg).total | Should -Be 9
    }
}

Describe 'New-BuildMatrix: input validation' {
    It 'throws a meaningful error when dimensions are missing' {
        { New-BuildMatrix -Config @{} } | Should -Throw '*dimensions*'
    }

    It 'throws a meaningful error when a dimension is empty' {
        { New-BuildMatrix -Config @{ dimensions = @{ os = @() } } } | Should -Throw '*no values*'
    }
}

Describe 'New-BuildMatrix: JSON round-trip' {
    It 'works when the config is loaded from a JSON string' {
        $json = '{"dimensions":{"os":["ubuntu-latest","windows-latest"],"node":["20"]},"fail_fast":false,"max_parallel":2,"max_size":10}'
        $cfg  = $json | ConvertFrom-Json -AsHashtable
        $m    = New-BuildMatrix -Config $cfg
        $m.total            | Should -Be 2
        $m['fail-fast']     | Should -Be $false
        $m['max-parallel']  | Should -Be 2
    }

    It 'produces a JSON document that round-trips cleanly' {
        $cfg = @{
            dimensions = @{ os = @('ubuntu-latest','windows-latest'); node = @('18','20') }
            exclude    = @(@{ os = 'windows-latest'; node = '18' })
            fail_fast  = $false
            max_size   = 10
        }
        $m       = New-BuildMatrix -Config $cfg
        $json    = $m | ConvertTo-Json -Depth 10
        $parsed  = $json | ConvertFrom-Json
        $parsed.total              | Should -Be 3
        $parsed.'fail-fast'        | Should -Be $false
        $parsed.matrix.include.Count | Should -Be 3
    }
}
