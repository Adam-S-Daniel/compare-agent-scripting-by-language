#Requires -Module Pester

BeforeAll {
    $script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    . (Join-Path $script:RepoRoot 'src/New-BuildMatrix.ps1')
}

Describe 'New-BuildMatrix — basic cartesian product' {
    It 'expands a single dimension into one combination per value' {
        $matrix = New-BuildMatrix -Config @{ os = @('ubuntu-latest', 'macos-latest') }

        $matrix.matrix.include.Count | Should -Be 2
        $matrix.count | Should -Be 2
        # Values within a dimension preserve input order.
        $matrix.matrix.include[0].os | Should -Be 'ubuntu-latest'
        $matrix.matrix.include[1].os | Should -Be 'macos-latest'
    }

    It 'expands two dimensions into the cartesian product' {
        $matrix = New-BuildMatrix -Config @{
            os      = @('ubuntu-latest', 'macos-latest')
            version = @('18', '20')
        }

        $matrix.count | Should -Be 4
        @($matrix.matrix.include | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.version -eq '18' }).Count | Should -Be 1
        @($matrix.matrix.include | Where-Object { $_.os -eq 'macos-latest'  -and $_.version -eq '20' }).Count | Should -Be 1
    }

    It 'expands three dimensions correctly' {
        $matrix = New-BuildMatrix -Config @{
            os       = @('ubuntu-latest')
            version  = @('18', '20')
            features = @('a', 'b', 'c')
        }
        $matrix.count | Should -Be 6
    }
}

Describe 'New-BuildMatrix — validation' {
    It 'throws when config is empty' {
        { New-BuildMatrix -Config @{} } | Should -Throw -ExpectedMessage '*empty*'
    }

    It 'throws when config has only reserved keys (no dimensions)' {
        { New-BuildMatrix -Config @{ 'max-parallel' = 4 } } | Should -Throw -ExpectedMessage '*dimension*'
    }

    It 'throws when a dimension has no values' {
        { New-BuildMatrix -Config @{ os = @() } } | Should -Throw -ExpectedMessage "*'os'*"
    }

    It 'throws when matrix size exceeds max-size' {
        $config = @{
            os         = @('a', 'b', 'c')
            version    = @('1', '2', '3', '4')
            'max-size' = 5
        }
        { New-BuildMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds maximum*'
    }

    It 'accepts matrix at exactly max-size' {
        $config = @{ os = @('a', 'b'); 'max-size' = 2 }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It 'rejects non-positive max-size' {
        { New-BuildMatrix -Config @{ os = @('a'); 'max-size' = 0 } } | Should -Throw -ExpectedMessage '*positive*'
    }

    It 'rejects non-positive max-parallel' {
        { New-BuildMatrix -Config @{ os = @('a'); 'max-parallel' = 0 } } | Should -Throw -ExpectedMessage '*positive*'
    }
}

Describe 'New-BuildMatrix — exclude rules' {
    It 'removes combinations matching an exclude rule' {
        $matrix = New-BuildMatrix -Config @{
            os      = @('ubuntu-latest', 'macos-latest')
            version = @('18', '20')
            exclude = @(@{ os = 'macos-latest'; version = '18' })
        }

        $matrix.count | Should -Be 3
        @($matrix.matrix.include | Where-Object { $_.os -eq 'macos-latest' -and $_.version -eq '18' }).Count | Should -Be 0
    }

    It 'supports partial exclude rules (removes all combinations whose specified keys match)' {
        $matrix = New-BuildMatrix -Config @{
            os      = @('ubuntu-latest', 'macos-latest')
            version = @('18', '20')
            exclude = @(@{ os = 'macos-latest' })
        }

        $matrix.count | Should -Be 2
        @($matrix.matrix.include | Where-Object { $_.os -eq 'macos-latest' }).Count | Should -Be 0
    }

    It 'applies multiple exclude rules with OR semantics' {
        $matrix = New-BuildMatrix -Config @{
            os      = @('a', 'b')
            version = @('1', '2')
            exclude = @(
                @{ os = 'a'; version = '1' }
                @{ os = 'b'; version = '2' }
            )
        }
        $matrix.count | Should -Be 2
    }
}

Describe 'New-BuildMatrix — include rules' {
    It 'adds include entries as extra combinations' {
        $matrix = New-BuildMatrix -Config @{
            os      = @('ubuntu-latest')
            version = @('18')
            include = @(@{ os = 'windows-latest'; version = '20'; experimental = $true })
        }
        $matrix.count | Should -Be 2
        $win = $matrix.matrix.include | Where-Object { $_.os -eq 'windows-latest' } | Select-Object -First 1
        $win.experimental | Should -Be $true
    }

    It 'applies include AFTER exclude (included items are never filtered out)' {
        $matrix = New-BuildMatrix -Config @{
            os      = @('ubuntu-latest', 'macos-latest')
            version = @('18')
            exclude = @(@{ os = 'macos-latest' })
            include = @(@{ os = 'macos-latest'; version = '20' })
        }
        $matrix.count | Should -Be 2
        @($matrix.matrix.include | Where-Object { $_.os -eq 'macos-latest' }).Count | Should -Be 1
    }
}

Describe 'New-BuildMatrix — strategy controls' {
    It 'passes through max-parallel' {
        $matrix = New-BuildMatrix -Config @{ os = @('a'); 'max-parallel' = 4 }
        $matrix['max-parallel'] | Should -Be 4
    }

    It 'passes through fail-fast = false' {
        $matrix = New-BuildMatrix -Config @{ os = @('a'); 'fail-fast' = $false }
        $matrix['fail-fast'] | Should -Be $false
    }

    It 'passes through fail-fast = true' {
        $matrix = New-BuildMatrix -Config @{ os = @('a'); 'fail-fast' = $true }
        $matrix['fail-fast'] | Should -Be $true
    }

    It 'omits max-parallel and fail-fast when unspecified' {
        $matrix = New-BuildMatrix -Config @{ os = @('a') }
        $matrix.Contains('max-parallel') | Should -Be $false
        $matrix.Contains('fail-fast')    | Should -Be $false
    }
}

Describe 'ConvertTo-BuildMatrixJson' {
    It 'produces valid, round-trippable JSON' {
        $json = ConvertTo-BuildMatrixJson -Config @{ os = @('ubuntu-latest'); version = @('18') }
        $parsed = $json | ConvertFrom-Json
        $parsed.count | Should -Be 1
        $parsed.matrix.include[0].os | Should -Be 'ubuntu-latest'
        $parsed.matrix.include[0].version | Should -Be '18'
    }

    It 'produces compact JSON when -Compress is set' {
        $json = ConvertTo-BuildMatrixJson -Config @{ os = @('a') } -Compress
        $json | Should -Not -Match "`n"
    }
}

Describe 'New-BuildMatrixFromFile' {
    BeforeAll {
        $script:FixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("matrix-test-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:FixtureDir -Force | Out-Null
    }
    AfterAll {
        if (Test-Path $script:FixtureDir) { Remove-Item -Recurse -Force $script:FixtureDir }
    }

    It 'loads a JSON config file and generates the matrix' {
        $path = Join-Path $script:FixtureDir 'c.json'
        '{"os":["ubuntu-latest","macos-latest"],"version":["18"]}' | Set-Content -Path $path -Encoding utf8
        $matrix = New-BuildMatrixFromFile -Path $path
        $matrix.count | Should -Be 2
    }

    It 'throws when the file does not exist' {
        { New-BuildMatrixFromFile -Path (Join-Path $script:FixtureDir 'missing.json') } | Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when the JSON is not an object' {
        $path = Join-Path $script:FixtureDir 'bad.json'
        '[1,2,3]' | Set-Content -Path $path -Encoding utf8
        { New-BuildMatrixFromFile -Path $path } | Should -Throw
    }
}
