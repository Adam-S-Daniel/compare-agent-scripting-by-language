# Pester tests for New-BuildMatrix. Built TDD-style: each Describe/It below
# was written first as a failing scenario, then the implementation in
# New-BuildMatrix.ps1 was extended until it passed.

BeforeAll {
    . $PSScriptRoot/New-BuildMatrix.ps1
}

Describe 'Cartesian product expansion' {
    It 'produces the cross-product of two axes' {
        $cfg = @{ os = @('ubuntu','windows'); version = @(16,18) }
        $r = New-BuildMatrix -Config $cfg
        $r.size | Should -Be 4
        $r.matrix.os | Should -Be @('ubuntu','windows')
        $r.matrix.version | Should -Be @(16,18)
    }

    It 'handles a single axis' {
        $cfg = @{ os = @('linux') }
        (New-BuildMatrix $cfg).size | Should -Be 1
    }

    It 'multiplies three axes correctly' {
        $cfg = @{ os = @('a','b'); v = @(1,2,3); flag = @($true,$false) }
        (New-BuildMatrix $cfg).size | Should -Be 12
    }
}

Describe 'Exclude rules' {
    It 'subtracts excluded combinations from size' {
        $cfg = @{
            os = @('ubuntu','windows')
            version = @(16,18)
            exclude = @(@{ os='windows'; version=16 })
        }
        $r = New-BuildMatrix $cfg
        $r.size | Should -Be 3
        $r.matrix.exclude.Count | Should -Be 1
    }

    It 'partial-key excludes drop everything matching' {
        $cfg = @{
            os = @('ubuntu','windows','macos')
            version = @(16,18)
            exclude = @(@{ os='windows' })
        }
        (New-BuildMatrix $cfg).size | Should -Be 4
    }
}

Describe 'Include rules' {
    It 'adds new combinations when no overlap' {
        $cfg = @{
            os = @('ubuntu')
            version = @(16)
            include = @(@{ os='windows'; version=20; experimental=$true })
        }
        $r = New-BuildMatrix $cfg
        $r.size | Should -Be 2
    }

    It 'merges extra keys onto matching combination without growing size' {
        $cfg = @{
            os = @('ubuntu','windows')
            version = @(16,18)
            include = @(@{ os='ubuntu'; version=18; npm='9' })
        }
        (New-BuildMatrix $cfg).size | Should -Be 4
    }
}

Describe 'max-parallel and fail-fast' {
    It 'preserves both settings on the strategy object' {
        $cfg = @{ os = @('a','b'); 'max-parallel' = 2; 'fail-fast' = $false }
        $r = New-BuildMatrix $cfg
        $r.'max-parallel' | Should -Be 2
        $r.'fail-fast'    | Should -Be $false
    }

    It 'omits fail-fast / max-parallel when not provided' {
        $r = New-BuildMatrix @{ os = @('a') }
        $r.Contains('max-parallel') | Should -BeFalse
        $r.Contains('fail-fast')    | Should -BeFalse
    }
}

Describe 'Maximum-size validation' {
    It 'throws when matrix exceeds max-size from config' {
        $cfg = @{ os=@('a','b','c'); v=@(1,2,3); 'max-size'=4 }
        { New-BuildMatrix $cfg } | Should -Throw '*exceeds maximum*'
    }

    It 'honours the -MaxSize parameter override' {
        { New-BuildMatrix @{ os=@('a','b'); v=@(1,2) } -MaxSize 3 } |
            Should -Throw '*exceeds maximum*'
    }

    It 'uses default of 256 when nothing is supplied' {
        { New-BuildMatrix @{ os=@('a','b') } } | Should -Not -Throw
    }
}

Describe 'JSON I/O' {
    It 'accepts a JSON string as Config' {
        $json = '{"os":["a","b"],"version":[1]}'
        (New-BuildMatrix $json).size | Should -Be 2
    }

    It 'roundtrips to valid JSON output' {
        $r = New-BuildMatrix @{ os = @('linux','windows'); version = @(16,18) }
        $j = $r | ConvertTo-Json -Depth 20
        $back = $j | ConvertFrom-Json
        $back.size | Should -Be 4
        $back.matrix.os.Count | Should -Be 2
    }
}

Describe 'Error handling' {
    It 'throws on empty config' {
        { New-BuildMatrix @{} } | Should -Throw '*at least one axis*'
    }

    It 'throws when an axis has no values' {
        { New-BuildMatrix @{ os = @() } } | Should -Throw '*at least one value*'
    }

    It 'throws on invalid JSON string' {
        { New-BuildMatrix '{not json' } | Should -Throw '*not valid JSON*'
    }

    It 'throws when all combos are excluded' {
        $cfg = @{ os=@('a'); v=@(1); exclude=@(@{ os='a'; v=1 }) }
        { New-BuildMatrix $cfg } | Should -Throw '*empty*'
    }
}
