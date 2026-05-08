#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

# Pester tests for MatrixGenerator. Run with `Invoke-Pester`.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'MatrixGenerator.ps1'
    . $script:ModulePath
}

Describe 'New-BuildMatrix - cartesian product expansion' {
    It 'expands two axes into the full cartesian product' {
        $config = @{
            os           = @('ubuntu-latest', 'windows-latest')
            node_version = @('18', '20')
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
    }

    It 'expands three axes into the full cartesian product' {
        $config = @{
            os       = @('a', 'b')
            lang     = @('1', '2')
            features = @('x', 'y')
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 8
    }

    It 'returns each combination as a hashtable with all axis keys' {
        $config = @{
            os   = @('ubuntu')
            lang = @('go')
        }
        $result = New-BuildMatrix -Config $config
        $combo = $result.matrix.include[0]
        $combo.os   | Should -Be 'ubuntu'
        $combo.lang | Should -Be 'go'
    }

    It 'errors when given a config with no axes and no include' {
        { New-BuildMatrix -Config @{} } |
            Should -Throw '*at least one*'
    }
}

Describe 'New-BuildMatrix - exclude rules' {
    It 'removes a single excluded combination' {
        $config = @{
            os           = @('ubuntu-latest', 'windows-latest')
            node_version = @('18', '20')
            exclude      = @(
                @{ os = 'windows-latest'; node_version = '18' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 3
        ($result.matrix.include | Where-Object {
            $_.os -eq 'windows-latest' -and $_.node_version -eq '18'
        }).Count | Should -Be 0
    }

    It 'removes multiple excluded combinations' {
        $config = @{
            os           = @('ubuntu-latest', 'windows-latest', 'macos-latest')
            node_version = @('18', '20')
            exclude      = @(
                @{ os = 'windows-latest'; node_version = '18' },
                @{ os = 'macos-latest';   node_version = '20' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
    }

    It 'treats partial exclude filters as matching all combos that match the named keys' {
        # Excluding just "os: windows-latest" removes ALL windows combos (any node_version)
        $config = @{
            os           = @('ubuntu-latest', 'windows-latest')
            node_version = @('18', '20')
            exclude      = @(
                @{ os = 'windows-latest' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' }).Count |
            Should -Be 0
    }
}

Describe 'New-BuildMatrix - include rules' {
    It 'adds a brand-new combination when include keys do not match any existing axis combo' {
        $config = @{
            os      = @('ubuntu-latest')
            include = @(
                @{ os = 'macos-latest'; experimental = $true }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
        # @() forces array context — Where-Object on a single-match returns one
        # OrderedDictionary, whose .Count reports its KEY count, not 1.
        @($result.matrix.include | Where-Object { $_.os -eq 'macos-latest' }).Count |
            Should -Be 1
    }

    It 'extends matching existing combinations with extra keys (GHA include semantics)' {
        # GitHub Actions: an include with axis-key values that match an existing combo
        # extends that combo with the additional non-axis keys.
        $config = @{
            os           = @('ubuntu-latest', 'windows-latest')
            node_version = @('18', '20')
            include      = @(
                @{ os = 'ubuntu-latest'; node_version = '20'; debug = 'true' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4   # no new combo, just extension
        $extended = $result.matrix.include |
            Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node_version -eq '20' }
        $extended.debug | Should -Be 'true'
    }

    It 'works with only an include list (no axes)' {
        $config = @{
            include = @(
                @{ os = 'ubuntu-latest'; node = '18' },
                @{ os = 'macos-latest';  node = '20' }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
    }
}

Describe 'New-BuildMatrix - strategy options' {
    It 'defaults fail-fast to true' {
        $result = New-BuildMatrix -Config @{ os = @('ubuntu-latest') }
        $result.'fail-fast' | Should -BeTrue
    }

    It 'honors fail_fast = false' {
        $result = New-BuildMatrix -Config @{
            os        = @('ubuntu-latest')
            fail_fast = $false
        }
        $result.'fail-fast' | Should -BeFalse
    }

    It 'sets max-parallel when configured' {
        $result = New-BuildMatrix -Config @{
            os           = @('ubuntu-latest', 'windows-latest')
            max_parallel = 2
        }
        $result.'max-parallel' | Should -Be 2
    }

    It 'omits max-parallel when not configured' {
        $result = New-BuildMatrix -Config @{ os = @('ubuntu-latest') }
        $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }
}

Describe 'New-BuildMatrix - max size validation' {
    It 'allows matrix sizes at or below max_size' {
        $config = @{
            os   = @('a', 'b')
            lang = @('1', '2')
            max_size = 4
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It 'throws a clear error when matrix exceeds max_size' {
        $config = @{
            os   = @('a', 'b', 'c')
            lang = @('1', '2', '3')
            max_size = 5
        }
        { New-BuildMatrix -Config $config } |
            Should -Throw '*exceeds*max*'
    }

    It 'counts combinations after applying excludes and includes' {
        $config = @{
            os   = @('a', 'b', 'c')
            lang = @('1', '2', '3')
            exclude = @(
                @{ os = 'a' },
                @{ os = 'b' }
            )   # leaves 3 combos for c
            max_size = 3
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }
}

Describe 'ConvertTo-MatrixJson' {
    It 'produces JSON parseable as a strategy.matrix object' {
        $matrix = New-BuildMatrix -Config @{
            os           = @('ubuntu-latest')
            node_version = @('18')
        }
        $json = ConvertTo-MatrixJson -Matrix $matrix
        $parsed = $json | ConvertFrom-Json
        $parsed.'fail-fast' | Should -BeTrue
        $parsed.matrix.include.Count | Should -Be 1
    }

    It 'serializes hashtable combos with all expected fields' {
        $matrix = New-BuildMatrix -Config @{
            os = @('ubuntu-latest', 'windows-latest')
            node_version = @('18', '20')
        }
        $json = ConvertTo-MatrixJson -Matrix $matrix
        $parsed = $json | ConvertFrom-Json
        $parsed.matrix.include[0].os | Should -Not -BeNullOrEmpty
        $parsed.matrix.include[0].node_version | Should -Not -BeNullOrEmpty
    }
}

Describe 'Read-MatrixConfig' {
    It 'reads a JSON config file and returns a hashtable' {
        $tmp = New-TemporaryFile
        try {
            @{
                os   = @('ubuntu-latest')
                lang = @('go', 'rust')
                fail_fast = $false
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp.FullName

            $cfg = Read-MatrixConfig -Path $tmp.FullName
            $cfg.os   | Should -Be @('ubuntu-latest')
            $cfg.lang | Should -Be @('go', 'rust')
            $cfg.fail_fast | Should -BeFalse
        } finally {
            Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'errors with a clear message when the file does not exist' {
        { Read-MatrixConfig -Path '/no/such/path.json' } |
            Should -Throw '*not found*'
    }

    It 'errors when the JSON is malformed' {
        $tmp = New-TemporaryFile
        try {
            'this is { not json' | Set-Content -Path $tmp.FullName
            { Read-MatrixConfig -Path $tmp.FullName } |
                Should -Throw '*JSON*'
        } finally {
            Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
