# Pester tests for New-EnvironmentMatrix.ps1
# TDD: These tests were written BEFORE the implementation script.

Describe 'New-EnvironmentMatrix' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot 'New-EnvironmentMatrix.ps1'
        $script:FixturePath = Join-Path $PSScriptRoot 'fixtures'

        function script:Invoke-MatrixGenerator {
            param([string]$ConfigFile)
            $fullPath = Join-Path $script:FixturePath $ConfigFile
            $output = (& $script:ScriptPath -ConfigPath $fullPath) -join "`n"
            return ($output | ConvertFrom-Json)
        }
    }

    Context 'Basic matrix generation' {
        BeforeAll {
            $script:basicResult = Invoke-MatrixGenerator 'basic-config.json'
        }

        It 'includes OS dimension with correct values' {
            $script:basicResult.matrix.os | Should -Be @('ubuntu-latest', 'windows-latest')
        }

        It 'includes node dimension with correct values' {
            $script:basicResult.matrix.node | Should -Be @('18', '20')
        }

        It 'sets fail-fast from config' {
            $script:basicResult.'fail-fast' | Should -BeFalse
        }

        It 'sets max-parallel from config' {
            $script:basicResult.'max-parallel' | Should -Be 2
        }

        It 'calculates effective size as Cartesian product' {
            $script:basicResult.'effective-size' | Should -Be 4
        }

        It 'produces valid JSON with a matrix key' {
            $script:basicResult.PSObject.Properties.Name | Should -Contain 'matrix'
        }
    }

    Context 'Include and exclude rules' {
        BeforeAll {
            $script:ieResult = Invoke-MatrixGenerator 'include-exclude-config.json'
        }

        It 'passes include rules into the matrix' {
            $script:ieResult.matrix.include | Should -HaveCount 1
        }

        It 'include entry has the experimental flag' {
            $script:ieResult.matrix.include[0].experimental | Should -BeTrue
        }

        It 'include entry targets ubuntu-latest and python 3.12' {
            $script:ieResult.matrix.include[0].os | Should -Be 'ubuntu-latest'
            $script:ieResult.matrix.include[0].python | Should -Be '3.12'
        }

        It 'passes exclude rules into the matrix' {
            $script:ieResult.matrix.exclude | Should -HaveCount 1
        }

        It 'exclude entry targets macos-latest and python 3.10' {
            $script:ieResult.matrix.exclude[0].os | Should -Be 'macos-latest'
            $script:ieResult.matrix.exclude[0].python | Should -Be '3.10'
        }

        It 'sets fail-fast to true when configured' {
            $script:ieResult.'fail-fast' | Should -BeTrue
        }

        It 'sets max-parallel to 4' {
            $script:ieResult.'max-parallel' | Should -Be 4
        }

        It 'calculates effective size accounting for exclude (9-1=8)' {
            $script:ieResult.'effective-size' | Should -Be 8
        }
    }

    Context 'Feature flags as a dimension' {
        BeforeAll {
            $script:ffResult = Invoke-MatrixGenerator 'feature-flags-config.json'
        }

        It 'includes the features dimension' {
            $script:ffResult.matrix.features | Should -Be @('default', 'experimental', 'legacy')
        }

        It 'includes the os dimension' {
            $script:ffResult.matrix.os | Should -Be @('ubuntu-latest')
        }

        It 'includes the node dimension' {
            $script:ffResult.matrix.node | Should -Be @('18', '20')
        }

        It 'has an include rule adding windows-latest' {
            $script:ffResult.matrix.include[0].os | Should -Be 'windows-latest'
            $script:ffResult.matrix.include[0].node | Should -Be '20'
        }

        It 'calculates effective size with new include (6+1=7)' {
            $script:ffResult.'effective-size' | Should -Be 7
        }
    }

    Context 'Matrix size validation' {
        It 'rejects matrix exceeding max-combinations with correct error' {
            $configPath = Join-Path $script:FixturePath 'oversized-config.json'
            { & $script:ScriptPath -ConfigPath $configPath } |
                Should -Throw '*96*exceeds maximum*10*'
        }
    }

    Context 'Default values' {
        BeforeAll {
            $script:defaultResult = Invoke-MatrixGenerator 'defaults-config.json'
        }

        It 'defaults fail-fast to false' {
            $script:defaultResult.'fail-fast' | Should -BeFalse
        }

        It 'omits max-parallel when not specified' {
            $script:defaultResult.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
        }

        It 'does not throw for single-element dimension (under default 256 limit)' {
            $configPath = Join-Path $script:FixturePath 'defaults-config.json'
            { & $script:ScriptPath -ConfigPath $configPath } | Should -Not -Throw
        }

        It 'effective size is 1 for single OS' {
            $script:defaultResult.'effective-size' | Should -Be 1
        }
    }

    Context 'Single dimension' {
        BeforeAll {
            $script:singleResult = Invoke-MatrixGenerator 'single-dimension-config.json'
        }

        It 'handles a single dimension with multiple values' {
            $script:singleResult.matrix.go | Should -Be @('1.20', '1.21', '1.22')
        }

        It 'sets fail-fast from config' {
            $script:singleResult.'fail-fast' | Should -BeTrue
        }

        It 'effective size equals dimension count' {
            $script:singleResult.'effective-size' | Should -Be 3
        }
    }

    Context 'Error handling' {
        It 'throws on missing config file' {
            { & $script:ScriptPath -ConfigPath './nonexistent-file.json' } |
                Should -Throw '*not found*'
        }

        It 'throws when config has no dimensions field' {
            $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "no-dims-$(Get-Random).json"
            '{"fail-fast": true}' | Set-Content -Path $tmpFile
            try {
                { & $script:ScriptPath -ConfigPath $tmpFile } |
                    Should -Throw '*dimensions*'
            } finally {
                Remove-Item -Path $tmpFile -ErrorAction SilentlyContinue
            }
        }

        It 'throws when dimensions is empty' {
            $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "empty-dims-$(Get-Random).json"
            '{"dimensions": {}}' | Set-Content -Path $tmpFile
            try {
                { & $script:ScriptPath -ConfigPath $tmpFile } |
                    Should -Throw '*at least one dimension*'
            } finally {
                Remove-Item -Path $tmpFile -ErrorAction SilentlyContinue
            }
        }
    }
}
