#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

# Tests for MatrixGenerator. Written TDD-style: red -> green -> refactor.
# Pester 5 syntax throughout.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'MatrixGenerator.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module MatrixGenerator -ErrorAction SilentlyContinue
}

Describe 'Get-MatrixCombinations' {
    It 'produces cartesian product of a single dimension' {
        $combos = Get-MatrixCombinations -Dimensions @{ os = @('linux', 'windows') }
        $combos.Count | Should -Be 2
        # @(...) around Where-Object is required because a single hashtable
        # result would otherwise be unwrapped, and .Count on a hashtable
        # returns the number of keys, not 1.
        @($combos | Where-Object { $_.os -eq 'linux' }).Count  | Should -Be 1
        @($combos | Where-Object { $_.os -eq 'windows' }).Count | Should -Be 1
    }

    It 'produces cartesian product of multiple dimensions' {
        $combos = Get-MatrixCombinations -Dimensions ([ordered]@{
                os      = @('linux', 'windows')
                version = @('1.0', '2.0', '3.0')
            })
        $combos.Count | Should -Be 6
        @($combos | Where-Object { $_.os -eq 'linux'   -and $_.version -eq '2.0' }).Count | Should -Be 1
        @($combos | Where-Object { $_.os -eq 'windows' -and $_.version -eq '3.0' }).Count | Should -Be 1
    }

    It 'returns empty array when dimensions are empty' {
        $combos = @(Get-MatrixCombinations -Dimensions @{})
        $combos.Count | Should -Be 0
    }

    It 'handles a single-value dimension' {
        $combos = Get-MatrixCombinations -Dimensions ([ordered]@{
                os   = @('linux')
                ruby = @('3.0', '3.1')
            })
        $combos.Count | Should -Be 2
    }
}

Describe 'Test-ExcludeMatch' {
    It 'matches when all exclude keys match' {
        $combo   = [ordered]@{ os = 'linux'; version = '1.0' }
        $exclude = @{ os = 'linux'; version = '1.0' }
        Test-ExcludeMatch -Combination $combo -Rule $exclude | Should -BeTrue
    }

    It 'does not match when one key differs' {
        $combo   = [ordered]@{ os = 'linux'; version = '1.0' }
        $exclude = @{ os = 'linux'; version = '2.0' }
        Test-ExcludeMatch -Combination $combo -Rule $exclude | Should -BeFalse
    }

    It 'treats partial rule as subset match (GitHub Actions semantics)' {
        # A rule specifying only "os=linux" excludes ANY combo with os=linux
        $combo   = [ordered]@{ os = 'linux'; version = '3.0' }
        $exclude = @{ os = 'linux' }
        Test-ExcludeMatch -Combination $combo -Rule $exclude | Should -BeTrue
    }

    It 'does not match when rule references an unknown key' {
        $combo   = [ordered]@{ os = 'linux' }
        $exclude = @{ arch = 'arm' }
        Test-ExcludeMatch -Combination $combo -Rule $exclude | Should -BeFalse
    }
}

Describe 'New-BuildMatrix' {
    It 'returns cartesian product wrapped under "matrix" key' {
        $config = @{
            dimensions = [ordered]@{
                os      = @('linux', 'windows')
                version = @('1.0', '2.0')
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
        $result.size | Should -Be 4
    }

    It 'filters out combinations matching any exclude rule' {
        $config = @{
            dimensions = [ordered]@{
                os      = @('linux', 'windows')
                version = @('1.0', '2.0')
            }
            exclude = @(
                @{ os = 'windows'; version = '1.0' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 3
        @($result.matrix.include | Where-Object { $_.os -eq 'windows' -and $_.version -eq '1.0' }).Count | Should -Be 0
    }

    It 'adds entries from the include list' {
        $config = @{
            dimensions = [ordered]@{
                os      = @('linux')
                version = @('1.0')
            }
            include = @(
                @{ os = 'macos';   version = '2.0' }
                @{ os = 'freebsd'; version = '3.0' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 3
        @($result.matrix.include | Where-Object { $_.os -eq 'macos'   }).Count | Should -Be 1
        @($result.matrix.include | Where-Object { $_.os -eq 'freebsd' }).Count | Should -Be 1
    }

    It 'passes through max-parallel and fail-fast settings' {
        $config = @{
            dimensions  = [ordered]@{ os = @('linux') }
            maxParallel = 5
            failFast    = $false
        }
        $result = New-BuildMatrix -Config $config
        $result.'max-parallel' | Should -Be 5
        $result.'fail-fast'    | Should -Be $false
    }

    It 'defaults fail-fast to $true when unspecified' {
        $config = @{ dimensions = [ordered]@{ os = @('linux') } }
        $result = New-BuildMatrix -Config $config
        $result.'fail-fast' | Should -Be $true
    }

    It 'omits max-parallel when not specified' {
        $config = @{ dimensions = [ordered]@{ os = @('linux') } }
        $result = New-BuildMatrix -Config $config
        $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }

    It 'throws when matrix size exceeds maxSize' {
        $config = @{
            dimensions = [ordered]@{
                os      = @('linux', 'windows', 'macos')
                version = @('1.0', '2.0', '3.0', '4.0')
            }
            maxSize = 10
        }
        { New-BuildMatrix -Config $config } | Should -Throw '*exceeds maximum size*'
    }

    It 'respects maxSize when combinations equal the limit' {
        $config = @{
            dimensions = [ordered]@{ os = @('a', 'b') }
            maxSize = 2
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It 'throws when dimensions key is missing' {
        { New-BuildMatrix -Config @{} } | Should -Throw '*dimensions*'
    }

    It 'throws when dimensions is empty (no combinations to build)' {
        { New-BuildMatrix -Config @{ dimensions = @{} } } | Should -Throw '*at least one dimension*'
    }

    It 'counts include additions toward the size' {
        $config = @{
            dimensions = [ordered]@{ os = @('linux') }
            include    = @( @{ os = 'mac' }, @{ os = 'bsd' } )
            maxSize    = 2
        }
        { New-BuildMatrix -Config $config } | Should -Throw '*exceeds maximum size*'
    }

    It 'applies excludes BEFORE counting size' {
        # Start with 4 combos, exclude 2, with maxSize=2. Should not throw.
        $config = @{
            dimensions = [ordered]@{
                os      = @('linux', 'windows')
                version = @('1.0', '2.0')
            }
            exclude = @(
                @{ os = 'windows' }
            )
            maxSize = 2
        }
        $result = New-BuildMatrix -Config $config
        $result.size | Should -Be 2
    }
}

Describe 'Invoke-MatrixGenerator (end-to-end JSON)' {
    It 'reads JSON from string and emits JSON result' {
        $json = @'
{
  "dimensions": {
    "os": ["linux", "windows"],
    "version": ["1.0", "2.0"]
  },
  "exclude": [
    { "os": "windows", "version": "1.0" }
  ],
  "maxParallel": 3,
  "failFast": false
}
'@
        $output  = Invoke-MatrixGenerator -Json $json
        $parsed  = $output | ConvertFrom-Json
        $parsed.size           | Should -Be 3
        $parsed.'max-parallel' | Should -Be 3
        $parsed.'fail-fast'    | Should -Be $false
        $parsed.matrix.include.Count | Should -Be 3
    }

    It 'surfaces validation errors as non-zero exit via exception' {
        $json = '{"dimensions": {"os": ["a","b","c"]}, "maxSize": 2}'
        { Invoke-MatrixGenerator -Json $json } | Should -Throw '*exceeds maximum size*'
    }

    It 'produces stable, deterministic ordering of include entries' {
        # Given identical input, output ordering should be reproducible.
        $json = '{"dimensions":{"os":["linux","windows"],"arch":["x64","arm64"]}}'
        $a = Invoke-MatrixGenerator -Json $json
        $b = Invoke-MatrixGenerator -Json $json
        $a | Should -Be $b
    }
}
