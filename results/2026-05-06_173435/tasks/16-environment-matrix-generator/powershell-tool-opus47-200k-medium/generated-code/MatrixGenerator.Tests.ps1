# Pester tests for the build matrix generator (red/green TDD).
# Each describe block was written before the corresponding code in MatrixGenerator.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'MatrixGenerator.ps1')
}

Describe 'New-BuildMatrix - axis expansion' {
    It 'returns an empty include list when no axes are defined' {
        $config = @{}
        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -BeNullOrEmpty
    }

    It 'expands a single axis into one entry per value' {
        $config = @{ axes = @{ os = @('ubuntu-latest', 'windows-latest') } }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
        ($result.matrix.include | ForEach-Object { $_.os }) | Should -Be @('ubuntu-latest','windows-latest')
    }

    It 'computes the cartesian product of multiple axes' {
        $config = @{ axes = @{ os = @('linux','windows'); node = @('18','20') } }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
    }
}

Describe 'New-BuildMatrix - exclude rules' {
    It 'removes a combination that matches all keys in an exclude entry' {
        $config = @{
            axes    = @{ os = @('linux','windows'); node = @('18','20') }
            exclude = @(@{ os = 'windows'; node = '18' })
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 3
        ($result.matrix.include | Where-Object { $_.os -eq 'windows' -and $_.node -eq '18' }) | Should -BeNullOrEmpty
    }

    It 'leaves combinations untouched when exclude has no match' {
        $config = @{
            axes    = @{ os = @('linux','windows') }
            exclude = @(@{ os = 'macos' })
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
    }
}

Describe 'New-BuildMatrix - include rules' {
    It 'adds a brand-new entry when include does not overlap any existing axis values' {
        $config = @{
            axes    = @{ os = @('linux') }
            include = @(@{ os = 'macos'; experimental = $true })
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 2
        ($result.matrix.include | Where-Object { $_.os -eq 'macos' }).experimental | Should -Be $true
    }

    It 'extends an existing combination when every include key matching an axis equals that axis value' {
        # GHA semantics: include entries whose axis-keys all match an existing combination
        # add the *extra* keys to that combination rather than adding a new entry.
        $config = @{
            axes    = @{ os = @('linux','windows'); node = @('18','20') }
            include = @(@{ os = 'linux'; node = '20'; debug = $true })
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include.Count | Should -Be 4
        $extended = $result.matrix.include | Where-Object { $_.os -eq 'linux' -and $_.node -eq '20' }
        $extended.debug | Should -Be $true
    }
}

Describe 'New-BuildMatrix - strategy options' {
    It 'passes max-parallel and fail-fast through to the result' {
        $config = @{
            axes         = @{ os = @('linux') }
            'max-parallel' = 2
            'fail-fast'   = $false
        }
        $result = New-BuildMatrix -Config $config
        $result.'max-parallel' | Should -Be 2
        $result.'fail-fast'   | Should -Be $false
    }

    It 'defaults fail-fast to true when not specified' {
        $config = @{ axes = @{ os = @('linux') } }
        $result = New-BuildMatrix -Config $config
        $result.'fail-fast' | Should -Be $true
    }
}

Describe 'New-BuildMatrix - validation' {
    It 'throws when the matrix exceeds max-size' {
        $config = @{
            axes      = @{ a = @(1,2,3); b = @(1,2,3) }
            'max-size' = 5
        }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds*'
    }

    It 'does not throw when matrix size equals max-size exactly' {
        $config = @{
            axes      = @{ a = @(1,2) }
            'max-size' = 2
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It 'throws a meaningful error when an axis value is null' {
        $config = @{ axes = @{ os = @($null) } }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*null*'
    }
}

Describe 'Invoke-MatrixGeneration - CLI surface' {
    It 'reads a JSON config file and emits valid JSON for GHA strategy.matrix' {
        $tmp = New-TemporaryFile
        $config = @{
            axes    = @{ os = @('linux','windows') }
            'fail-fast' = $false
        } | ConvertTo-Json -Depth 5
        Set-Content -Path $tmp -Value $config

        $output = Invoke-MatrixGeneration -ConfigPath $tmp
        $parsed = $output | ConvertFrom-Json
        $parsed.matrix.include.Count | Should -Be 2
        $parsed.'fail-fast' | Should -Be $false
        Remove-Item $tmp
    }
}
