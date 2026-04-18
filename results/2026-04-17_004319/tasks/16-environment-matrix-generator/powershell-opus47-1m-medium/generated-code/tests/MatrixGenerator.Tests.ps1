# Pester tests for MatrixGenerator.ps1
# TDD-style — each Describe block corresponds to a red/green iteration.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'MatrixGenerator.ps1')
}

Describe 'Expand-Matrix' {
    It 'returns the cartesian product of two dimensions' {
        $r = Expand-Matrix -Dimensions @{ os = @('ubuntu','windows'); node = @('18','20') }
        $r.Count | Should -Be 4
    }

    It 'returns a single combo when every dim has one value' {
        $r = Expand-Matrix -Dimensions @{ os = @('ubuntu') }
        $r.Count | Should -Be 1
        $r[0].os | Should -Be 'ubuntu'
    }

    It 'throws when a dimension has no values' {
        { Expand-Matrix -Dimensions @{ os = @() } } | Should -Throw "*no values*"
    }
}

Describe 'Remove-ExcludedCombos' {
    It 'filters combos matching an exclude filter' {
        $combos = Expand-Matrix -Dimensions @{ os = @('ubuntu','windows'); node = @('18','20') }
        $out = Remove-ExcludedCombos -Combos $combos -Excludes @(@{ os = 'windows'; node = '18' })
        $out.Count | Should -Be 3
        @($out | Where-Object { $_.os -eq 'windows' -and $_.node -eq '18' }).Count | Should -Be 0
    }

    It 'returns all combos when exclude list is empty' {
        $combos = Expand-Matrix -Dimensions @{ os = @('ubuntu'); node = @('18') }
        (Remove-ExcludedCombos -Combos $combos -Excludes @()).Count | Should -Be 1
    }
}

Describe 'Add-IncludedCombos' {
    It 'augments matching existing combos with new keys' {
        $combos = Expand-Matrix -Dimensions @{ os = @('ubuntu','windows') }
        $out = Add-IncludedCombos -Combos $combos -Includes @(@{ os = 'ubuntu'; extra = 'fast' }) -DimensionKeys @('os')
        $ubuntu = $out | Where-Object { $_.os -eq 'ubuntu' } | Select-Object -First 1
        $ubuntu['extra'] | Should -Be 'fast'
        $win = $out | Where-Object { $_.os -eq 'windows' } | Select-Object -First 1
        $win.ContainsKey('extra') | Should -BeFalse
    }

    It 'appends a standalone combo when the include does not match any dimension value' {
        $combos = Expand-Matrix -Dimensions @{ os = @('ubuntu') }
        $out = Add-IncludedCombos -Combos $combos -Includes @(@{ os = 'macos'; experimental = $true }) -DimensionKeys @('os')
        $out.Count | Should -Be 2
        @($out | Where-Object { $_.os -eq 'macos' }).Count | Should -Be 1
    }
}

Describe 'New-BuildMatrix' {
    It 'produces the expected shape for a simple config' {
        $cfg = @{
            dimensions = @{ os = @('ubuntu','windows'); node = @('18','20') }
            fail_fast  = $false
            max_parallel = 4
        }
        $m = New-BuildMatrix -Config $cfg
        $m.'fail-fast' | Should -Be $false
        $m.'max-parallel' | Should -Be 4
        $m.count | Should -Be 4
    }

    It 'applies includes and excludes together' {
        $cfg = @{
            dimensions = @{ os = @('ubuntu','windows'); node = @('18','20') }
            exclude    = @(@{ os = 'windows'; node = '18' })
            include    = @(@{ os = 'macos'; node = '20'; experimental = $true })
        }
        $m = New-BuildMatrix -Config $cfg
        # 4 - 1 excluded + 1 include = 4
        $m.count | Should -Be 4
        ($m.combinations | Where-Object { $_.os -eq 'macos' }).experimental | Should -Be $true
    }

    It 'throws when generated size exceeds max_size' {
        $cfg = @{
            dimensions = @{ a = 1..3; b = 1..3 }  # 9 combos
            max_size   = 5
        }
        { New-BuildMatrix -Config $cfg } | Should -Throw "*exceeds max_size*"
    }

    It 'accepts max_size equal to the combo count' {
        $cfg = @{
            dimensions = @{ a = 1..3; b = 1..3 }
            max_size   = 9
        }
        (New-BuildMatrix -Config $cfg).count | Should -Be 9
    }

    It 'defaults fail-fast to $true' {
        $cfg = @{ dimensions = @{ os = @('ubuntu') } }
        (New-BuildMatrix -Config $cfg).'fail-fast' | Should -Be $true
    }

    It 'throws when config has no dimensions' {
        { New-BuildMatrix -Config @{} } | Should -Throw "*dimensions*"
    }
}

Describe 'ConvertFrom-MatrixConfigFile' {
    It 'reads a JSON config into a hashtable' {
        $tmp = [IO.Path]::Combine([IO.Path]::GetTempPath(), "cfg-$(Get-Random).json")
        @{ dimensions = @{ os = @('ubuntu') } } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tmp
        try {
            $cfg = ConvertFrom-MatrixConfigFile -Path $tmp
            $cfg['dimensions']['os'][0] | Should -Be 'ubuntu'
        } finally {
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        }
    }

    It 'throws for a missing file' {
        { ConvertFrom-MatrixConfigFile -Path '/nonexistent/cfg.json' } | Should -Throw "*not found*"
    }
}
