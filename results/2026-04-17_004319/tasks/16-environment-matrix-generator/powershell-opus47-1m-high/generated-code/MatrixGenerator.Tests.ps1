# Pester tests for MatrixGenerator.psm1
# Red-green-refactor TDD: each Describe block walks through one piece of behaviour.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'MatrixGenerator.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module MatrixGenerator -ErrorAction SilentlyContinue
}

Describe 'New-EnvironmentMatrix - basic cartesian product' {

    It 'expands a single dimension into the matrix axis' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest', 'windows-latest') }
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.matrix.os | Should -Be @('ubuntu-latest', 'windows-latest')
        $result.combinations.Count | Should -Be 2
    }

    It 'expands multiple dimensions and produces the cartesian product' {
        $config = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.combinations.Count | Should -Be 4
        # Spot-check one combination present
        @($result.combinations | Where-Object { $_.os -eq 'ubuntu-latest' -and $_.node -eq '20' }).Count | Should -Be 1
    }

    It 'handles three dimensions correctly' {
        $config = @{
            dimensions = @{
                os      = @('linux', 'mac')
                runtime = @('node18', 'node20')
                feature = @('on', 'off')
            }
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.combinations.Count | Should -Be 8
    }
}

Describe 'New-EnvironmentMatrix - exclude rules' {

    It 'removes combinations matching an exclude rule' {
        $config = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest'; node = '18' }
            )
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.combinations.Count | Should -Be 3
        ($result.combinations | Where-Object { $_.os -eq 'windows-latest' -and $_.node -eq '18' }).Count | Should -Be 0
    }

    It 'supports partial exclude rules that match many combinations' {
        $config = @{
            dimensions = @{
                os   = @('ubuntu-latest', 'windows-latest')
                node = @('18', '20')
            }
            exclude = @(
                @{ os = 'windows-latest' }   # excludes both windows rows
            )
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.combinations.Count | Should -Be 2
        ($result.combinations | Where-Object { $_.os -eq 'windows-latest' }).Count | Should -Be 0
    }
}

Describe 'New-EnvironmentMatrix - include rules' {

    It 'adds extra combinations from include rules' {
        $config = @{
            dimensions = @{
                os   = @('ubuntu-latest')
                node = @('20')
            }
            include = @(
                @{ os = 'macos-latest'; node = '20'; experimental = $true }
            )
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.combinations.Count | Should -Be 2
        $extra = $result.combinations | Where-Object { $_.os -eq 'macos-latest' }
        $extra.experimental | Should -BeTrue
    }
}

Describe 'New-EnvironmentMatrix - strategy options' {

    It 'passes through fail-fast when provided' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest') }
            'fail-fast' = $false
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.'fail-fast' | Should -Be $false
    }

    It 'passes through max-parallel when provided' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest', 'windows-latest') }
            'max-parallel' = 1
        }
        $result = New-EnvironmentMatrix -Config $config
        $result.'max-parallel' | Should -Be 1
    }

    It 'omits fail-fast and max-parallel when not provided' {
        $config = @{ dimensions = @{ os = @('ubuntu-latest') } }
        $result = New-EnvironmentMatrix -Config $config
        $result.PSObject.Properties.Name | Should -Not -Contain 'fail-fast'
        $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
    }
}

Describe 'New-EnvironmentMatrix - validation' {

    It 'throws when matrix exceeds max-size' {
        $config = @{
            dimensions = @{
                os   = @('a','b','c','d')
                node = @('1','2','3','4')
            }
            'max-size' = 10
        }
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ExpectedMessage '*exceeds*'
    }

    It 'accepts a matrix exactly at max-size' {
        $config = @{
            dimensions = @{ os = @('a','b'); node = @('1','2') }
            'max-size' = 4
        }
        { New-EnvironmentMatrix -Config $config } | Should -Not -Throw
    }

    It 'throws when no dimensions are provided' {
        $config = @{ dimensions = @{} }
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ExpectedMessage '*dimension*'
    }

    It 'throws when a dimension has zero values' {
        $config = @{ dimensions = @{ os = @() } }
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ExpectedMessage '*empty*'
    }

    It 'throws when fail-fast is not a boolean' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest') }
            'fail-fast' = 'yes'
        }
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ExpectedMessage '*fail-fast*'
    }

    It 'throws when max-parallel is not a positive integer' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest') }
            'max-parallel' = 0
        }
        { New-EnvironmentMatrix -Config $config } | Should -Throw -ExpectedMessage '*max-parallel*'
    }
}

Describe 'ConvertTo-MatrixJson - JSON output shape' {

    It 'emits a strategy object containing matrix axes' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest','windows-latest'); node = @('20') }
            'fail-fast' = $true
            'max-parallel' = 2
        }
        $result = New-EnvironmentMatrix -Config $config
        $json = ConvertTo-MatrixJson -Matrix $result
        $obj = $json | ConvertFrom-Json
        $obj.strategy.matrix.os | Should -Be @('ubuntu-latest','windows-latest')
        $obj.strategy.matrix.node | Should -Be @('20')
        $obj.strategy.'fail-fast' | Should -Be $true
        $obj.strategy.'max-parallel' | Should -Be 2
    }

    It 'includes include and exclude arrays in strategy.matrix when present' {
        $config = @{
            dimensions = @{ os = @('ubuntu-latest','windows-latest'); node = @('18','20') }
            exclude = @( @{ os = 'windows-latest'; node = '18' } )
            include = @( @{ os = 'macos-latest'; node = '20'; experimental = $true } )
        }
        $result = New-EnvironmentMatrix -Config $config
        $json = ConvertTo-MatrixJson -Matrix $result
        $obj = $json | ConvertFrom-Json
        $obj.strategy.matrix.exclude.Count | Should -Be 1
        $obj.strategy.matrix.include.Count | Should -Be 1
        $obj.strategy.matrix.include[0].experimental | Should -BeTrue
    }
}

Describe 'Invoke-MatrixGeneration - end-to-end from JSON config file' {

    BeforeEach {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempDir | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:tempDir -ErrorAction SilentlyContinue
    }

    It 'reads a JSON config file and outputs valid matrix JSON' {
        $configPath = Join-Path $script:tempDir 'config.json'
        $configJson = @'
{
  "dimensions": {
    "os":   ["ubuntu-latest", "windows-latest"],
    "node": ["18", "20"]
  },
  "exclude": [ { "os": "windows-latest", "node": "18" } ],
  "fail-fast": false,
  "max-parallel": 3,
  "max-size": 10
}
'@
        Set-Content -Path $configPath -Value $configJson
        $output = Invoke-MatrixGeneration -ConfigPath $configPath
        $obj = $output | ConvertFrom-Json
        $obj.strategy.matrix.os.Count | Should -Be 2
        $obj.strategy.'fail-fast' | Should -Be $false
        $obj.strategy.'max-parallel' | Should -Be 3
        $obj.strategy.matrix.exclude.Count | Should -Be 1
    }

    It 'errors with a useful message when config file is missing' {
        $missing = Join-Path $script:tempDir 'nope.json'
        { Invoke-MatrixGeneration -ConfigPath $missing } | Should -Throw -ExpectedMessage '*not found*'
    }

    It 'errors with a useful message when config file is invalid JSON' {
        $configPath = Join-Path $script:tempDir 'bad.json'
        Set-Content -Path $configPath -Value '{ this is not json'
        { Invoke-MatrixGeneration -ConfigPath $configPath } | Should -Throw -ExpectedMessage '*JSON*'
    }
}
