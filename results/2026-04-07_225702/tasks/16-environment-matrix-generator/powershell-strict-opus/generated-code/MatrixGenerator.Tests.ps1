BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/MatrixGenerator.ps1"
}

Describe 'New-BuildMatrix' {

    Context 'Basic cartesian product' {
        It 'generates all OS x version combinations' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                version  = @('3.9', '3.10')
            }
            $result = New-BuildMatrix -Configuration $config
            $matrix = $result.matrix
            $matrix.include.Count | Should -Be 4
            $matrix.include[0].os | Should -Be 'ubuntu-latest'
            $matrix.include[0].version | Should -Be '3.9'
        }
    }

    Context 'Exclude rules' {
        It 'removes combinations matching an exclude rule' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest')
                version = @('3.9', '3.10')
                exclude = @(
                    @{ os = 'windows-latest'; version = '3.9' }
                )
            }
            $result = New-BuildMatrix -Configuration $config
            $combos = $result.matrix.include
            $combos.Count | Should -Be 3
            # The excluded combo should not be present
            $excluded = $combos | Where-Object {
                $_.os -eq 'windows-latest' -and $_.version -eq '3.9'
            }
            $excluded | Should -BeNullOrEmpty
        }

        It 'excludes based on partial key match' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                version = @('3.9', '3.10')
                exclude = @(
                    @{ os = 'macos-latest' }
                )
            }
            $result = New-BuildMatrix -Configuration $config
            $combos = $result.matrix.include
            $combos.Count | Should -Be 4
            $macos = $combos | Where-Object { $_.os -eq 'macos-latest' }
            $macos | Should -BeNullOrEmpty
        }
    }

    Context 'Include rules' {
        It 'adds new combinations via include' {
            $config = @{
                os      = @('ubuntu-latest')
                version = @('3.9')
                include = @(
                    @{ os = 'macos-latest'; version = '3.11' }
                )
            }
            $result = New-BuildMatrix -Configuration $config
            $combos = $result.matrix.include
            $combos.Count | Should -Be 2
            $added = $combos | Where-Object { $_.os -eq 'macos-latest' -and $_.version -eq '3.11' }
            $added | Should -Not -BeNullOrEmpty
        }

        It 'augments existing combinations with extra properties via include' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest')
                version = @('3.10')
                include = @(
                    @{ os = 'ubuntu-latest'; version = '3.10'; experimental = $true }
                )
            }
            $result = New-BuildMatrix -Configuration $config
            $combos = $result.matrix.include
            $augmented = $combos | Where-Object {
                $_.os -eq 'ubuntu-latest' -and $_.version -eq '3.10'
            }
            $augmented.experimental | Should -Be $true
        }
    }

    Context 'Max-parallel and fail-fast' {
        It 'includes max-parallel in the result' {
            $config = @{
                os             = @('ubuntu-latest')
                version        = @('3.9')
                'max-parallel' = 2
            }
            $result = New-BuildMatrix -Configuration $config
            $result['max-parallel'] | Should -Be 2
        }

        It 'includes fail-fast in the result' {
            $config = @{
                os          = @('ubuntu-latest')
                version     = @('3.9')
                'fail-fast' = $false
            }
            $result = New-BuildMatrix -Configuration $config
            $result['fail-fast'] | Should -Be $false
        }
    }

    Context 'Matrix size validation' {
        It 'throws when matrix exceeds max combinations' {
            $config = @{
                os      = @('a', 'b', 'c')
                version = @('1', '2', '3', '4')
            }
            { New-BuildMatrix -Configuration $config -MaxCombinations 5 } |
                Should -Throw '*exceeds maximum of 5*'
        }

        It 'allows config-level max-combinations override' {
            $config = @{
                os                 = @('a', 'b')
                version            = @('1', '2')
                'max-combinations' = 3
            }
            { New-BuildMatrix -Configuration $config } |
                Should -Throw '*exceeds maximum of 3*'
        }
    }

    Context 'Three dimensions' {
        It 'generates correct cartesian product with 3 dimensions' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest')
                version = @('3.9', '3.10')
                arch    = @('x64', 'arm64')
            }
            $result = New-BuildMatrix -Configuration $config
            $result.matrix.include.Count | Should -Be 8
        }
    }

    Context 'Single dimension' {
        It 'handles single dimension correctly' {
            $config = @{
                os = @('ubuntu-latest', 'windows-latest', 'macos-latest')
            }
            $result = New-BuildMatrix -Configuration $config
            $result.matrix.include.Count | Should -Be 3
        }
    }

    Context 'Feature flags as a dimension' {
        It 'includes feature flags in combinations' {
            $config = @{
                os      = @('ubuntu-latest')
                feature = @('debug', 'release')
            }
            $result = New-BuildMatrix -Configuration $config
            $combos = $result.matrix.include
            $combos.Count | Should -Be 2
            ($combos | Where-Object { $_.feature -eq 'debug' }).os | Should -Be 'ubuntu-latest'
        }
    }

    Context 'Empty dimensions' {
        It 'throws for empty configuration' {
            $config = @{}
            $result = New-BuildMatrix -Configuration $config
            $result.matrix.include.Count | Should -Be 1
            $result.matrix.include[0].Keys.Count | Should -Be 0
        }
    }

    Context 'JSON output' {
        It 'produces valid JSON via ConvertTo-MatrixJson' {
            $config = @{
                os      = @('ubuntu-latest')
                version = @('3.10')
            }
            $result = New-BuildMatrix -Configuration $config
            [string]$json = ConvertTo-MatrixJson -MatrixResult $result
            $parsed = $json | ConvertFrom-Json
            $parsed.matrix | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Multiple exclude rules' {
        It 'applies all exclude rules' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest', 'macos-latest')
                version = @('3.9', '3.10')
                exclude = @(
                    @{ os = 'windows-latest'; version = '3.9' },
                    @{ os = 'macos-latest'; version = '3.10' }
                )
            }
            $result = New-BuildMatrix -Configuration $config
            $result.matrix.include.Count | Should -Be 4
        }
    }

    Context 'Error handling' {
        It 'provides a meaningful error message for invalid dimension type' {
            $config = @{
                os      = 'not-an-array'
                version = @('3.10')
            }
            # Should still work — wrapping scalar in @() makes it an array
            $result = New-BuildMatrix -Configuration $config
            $result.matrix.include.Count | Should -Be 1
            $result.matrix.include[0].os | Should -Be 'not-an-array'
        }
    }

    Context 'JSON output structure' {
        It 'JSON includes fail-fast and max-parallel when set' {
            $config = @{
                os             = @('ubuntu-latest')
                version        = @('3.10')
                'fail-fast'    = $false
                'max-parallel' = 3
            }
            $result = New-BuildMatrix -Configuration $config
            [string]$json = ConvertTo-MatrixJson -MatrixResult $result
            $parsed = $json | ConvertFrom-Json
            $parsed.'fail-fast' | Should -Be $false
            $parsed.'max-parallel' | Should -Be 3
            $parsed.matrix.include.Count | Should -Be 1
        }

        It 'JSON round-trips correctly for complex matrix' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest')
                version = @('3.9', '3.10')
                arch    = @('x64')
                exclude = @(
                    @{ os = 'windows-latest'; version = '3.9' }
                )
                include = @(
                    @{ os = 'macos-latest'; version = '3.11'; arch = 'arm64' }
                )
                'fail-fast'    = $true
                'max-parallel' = 4
            }
            $result = New-BuildMatrix -Configuration $config
            [string]$json = ConvertTo-MatrixJson -MatrixResult $result
            $parsed = $json | ConvertFrom-Json
            $parsed.'fail-fast' | Should -Be $true
            $parsed.'max-parallel' | Should -Be 4
            # 2x2x1 = 4, minus 1 exclude = 3, plus 1 include = 4
            $parsed.matrix.include.Count | Should -Be 4
        }
    }

    Context 'CLI runner with fixtures' {
        It 'generates correct output from basic-config.json fixture' {
            [string]$output = pwsh -File "$PSScriptRoot/Generate-Matrix.ps1" -ConfigPath "$PSScriptRoot/fixtures/basic-config.json" 2>&1
            $parsed = $output | ConvertFrom-Json
            $parsed.'fail-fast' | Should -Be $false
            $parsed.'max-parallel' | Should -Be 4
            # 3 os x 3 version = 9, minus 1 exclude (macos+3.9) = 8, plus 1 include (ubuntu+3.12) = 9
            $parsed.matrix.include.Count | Should -Be 9
        }

        It 'fails gracefully for oversized matrix from large-config.json fixture' {
            $proc = Start-Process -FilePath 'pwsh' -ArgumentList @(
                '-File', "$PSScriptRoot/Generate-Matrix.ps1",
                '-ConfigPath', "$PSScriptRoot/fixtures/large-config.json"
            ) -Wait -PassThru -RedirectStandardError "$PSScriptRoot/fixtures/stderr.tmp" -NoNewWindow
            $proc.ExitCode | Should -Be 1
            [string]$stderr = Get-Content "$PSScriptRoot/fixtures/stderr.tmp" -Raw
            $stderr | Should -Match 'exceeds maximum'
            Remove-Item "$PSScriptRoot/fixtures/stderr.tmp" -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Include and exclude combined' {
        It 'applies exclude first, then include can re-add' {
            $config = @{
                os      = @('ubuntu-latest', 'windows-latest')
                version = @('3.9', '3.10')
                exclude = @(
                    @{ os = 'windows-latest'; version = '3.9' }
                )
                include = @(
                    @{ os = 'windows-latest'; version = '3.9'; note = 'special' }
                )
            }
            $result = New-BuildMatrix -Configuration $config
            $combos = $result.matrix.include
            # Exclude removed win+3.9, include re-adds it with extra key
            $special = $combos | Where-Object {
                $_.os -eq 'windows-latest' -and $_.version -eq '3.9'
            }
            $special | Should -Not -BeNullOrEmpty
            $special.note | Should -Be 'special'
        }
    }
}
