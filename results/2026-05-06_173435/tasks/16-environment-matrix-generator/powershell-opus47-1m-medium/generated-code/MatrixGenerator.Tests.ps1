# Pester tests for MatrixGenerator. Red-green TDD: tests written first.
# Run with: Invoke-Pester ./MatrixGenerator.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/MatrixGenerator.psm1" -Force
}

Describe 'New-BuildMatrix - axis expansion' {
    It 'returns an empty include array when no axes are given' {
        $result = New-BuildMatrix -Config @{ axes = @{} }
        $result.matrix.include | Should -BeNullOrEmpty
    }

    It 'expands a single axis into N entries' {
        $cfg = @{ axes = @{ os = @('ubuntu-latest', 'windows-latest') } }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 2
        $result.matrix.include[0].os | Should -Be 'ubuntu-latest'
        $result.matrix.include[1].os | Should -Be 'windows-latest'
    }

    It 'produces a cartesian product across multiple axes' {
        $cfg = @{ axes = [ordered]@{
            os   = @('ubuntu-latest', 'windows-latest')
            node = @('18', '20')
        } }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 4
        $combos = $result.matrix.include | ForEach-Object { "$($_.os)|$($_.node)" }
        $combos | Should -Contain 'ubuntu-latest|18'
        $combos | Should -Contain 'ubuntu-latest|20'
        $combos | Should -Contain 'windows-latest|18'
        $combos | Should -Contain 'windows-latest|20'
    }
}

Describe 'New-BuildMatrix - exclude rules' {
    It 'removes combinations matching an exclude rule' {
        $cfg = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest'; node = '18' }
            )
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 3
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '18' }) | Should -BeNullOrEmpty
    }

    It 'partial-match exclude rules remove all combos that match the given keys' {
        $cfg = @{
            axes = [ordered]@{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest' }
            )
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 2
        ($result.matrix.include | Where-Object { $_.os -eq 'windows-latest' }) | Should -BeNullOrEmpty
    }
}

Describe 'New-BuildMatrix - include rules' {
    It 'appends additional include entries to the matrix' {
        $cfg = @{
            axes = @{ os = @('ubuntu-latest') }
            include = @(
                @{ os = 'macos-latest'; node = '20'; experimental = $true }
            )
        }
        $result = New-BuildMatrix -Config $cfg
        $result.matrix.include.Count | Should -Be 2
        $result.matrix.include[1].os | Should -Be 'macos-latest'
        $result.matrix.include[1].experimental | Should -Be $true
    }
}

Describe 'New-BuildMatrix - strategy options' {
    It 'passes through max-parallel and fail-fast' {
        $cfg = @{
            axes = @{ os = @('ubuntu-latest') }
            'max-parallel' = 4
            'fail-fast' = $false
        }
        $result = New-BuildMatrix -Config $cfg
        $result.'max-parallel' | Should -Be 4
        $result.'fail-fast' | Should -Be $false
    }

    It 'defaults fail-fast to true and omits max-parallel when not given' {
        $cfg = @{ axes = @{ os = @('ubuntu-latest') } }
        $result = New-BuildMatrix -Config $cfg
        $result.'fail-fast' | Should -Be $true
        $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }
}

Describe 'New-BuildMatrix - validation' {
    It 'throws when matrix size exceeds max-size' {
        $cfg = @{
            axes = [ordered]@{
                a = 1..10
                b = 1..10
            }
            'max-size' = 50
        }
        { New-BuildMatrix -Config $cfg } | Should -Throw -ExpectedMessage '*exceeds*'
    }

    It 'does not throw when matrix size equals max-size' {
        $cfg = @{
            axes = [ordered]@{
                a = 1..5
                b = 1..2
            }
            'max-size' = 10
        }
        { New-BuildMatrix -Config $cfg } | Should -Not -Throw
    }

    It 'throws when axes is missing' {
        { New-BuildMatrix -Config @{} } | Should -Throw -ExpectedMessage "*'axes'*"
    }

    It 'throws when an axis value is not a list' {
        { New-BuildMatrix -Config @{ axes = @{ os = 'ubuntu-latest' } } } | Should -Throw -ExpectedMessage '*array*'
    }
}

Describe 'ConvertTo-MatrixJson' {
    It 'serializes a matrix result to compact JSON' {
        $cfg = @{ axes = @{ os = @('ubuntu-latest') } }
        $result = New-BuildMatrix -Config $cfg
        $json = ConvertTo-MatrixJson -Matrix $result
        $json | Should -BeOfType [string]
        $parsed = $json | ConvertFrom-Json
        $parsed.matrix.include[0].os | Should -Be 'ubuntu-latest'
        $parsed.'fail-fast' | Should -Be $true
    }
}

Describe 'Invoke-MatrixGenerator (entry script driver)' {
    It 'reads a config file and outputs matrix JSON' {
        $tmp = New-TemporaryFile
        try {
            @{
                axes = @{ os = @('ubuntu-latest', 'macos-latest') }
                'fail-fast' = $true
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $tmp.FullName -Encoding UTF8
            $output = Invoke-MatrixGenerator -ConfigPath $tmp.FullName
            $parsed = $output | ConvertFrom-Json
            $parsed.matrix.include.Count | Should -Be 2
        } finally {
            Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws a meaningful error when the config file does not exist' {
        { Invoke-MatrixGenerator -ConfigPath '/nonexistent/path.json' } | Should -Throw -ExpectedMessage '*not found*'
    }
}
