BeforeAll {
    . "$PSScriptRoot/New-EnvironmentMatrix.ps1"
}

Describe 'New-EnvironmentMatrix' {

    Describe 'Basic matrix generation' {
        It 'generates a Cartesian product from OS and language version arrays' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                language = @('3.9', '3.10')
            }
            $result = New-EnvironmentMatrix -Config $config
            $result | Should -Not -BeNullOrEmpty
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.os | Should -HaveCount 2
            $parsed.matrix.language | Should -HaveCount 2
            $parsed.matrix.os | Should -Contain 'ubuntu-latest'
            $parsed.matrix.language | Should -Contain '3.10'
        }

        It 'supports a single dimension' {
            $config = @{ os = @('ubuntu-latest') }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.os | Should -HaveCount 1
        }

        It 'supports three dimensions including feature flags' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('18', '20')
                feature  = @('sse', 'avx')
            }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.os | Should -HaveCount 1
            $parsed.matrix.language | Should -HaveCount 2
            $parsed.matrix.feature | Should -HaveCount 2
        }
    }

    Describe 'Include rules' {
        It 'adds include entries to the matrix output' {
            $config = @{
                os      = @('ubuntu-latest')
                language = @('3.9')
                include = @(
                    @{ os = 'macos-latest'; language = '3.11' }
                )
            }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.include | Should -HaveCount 1
            $parsed.matrix.include[0].os | Should -BeExactly 'macos-latest'
            $parsed.matrix.include[0].language | Should -BeExactly '3.11'
        }
    }

    Describe 'Exclude rules' {
        It 'adds exclude entries to the matrix output' {
            $config = @{
                os       = @('ubuntu-latest', 'windows-latest')
                language = @('3.9', '3.10')
                exclude  = @(
                    @{ os = 'windows-latest'; language = '3.9' }
                )
            }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.exclude | Should -HaveCount 1
            $parsed.matrix.exclude[0].os | Should -BeExactly 'windows-latest'
        }
    }

    Describe 'Strategy settings' {
        It 'sets max-parallel when specified' {
            $config = @{
                os             = @('ubuntu-latest')
                language       = @('3.9')
                'max-parallel' = 2
            }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.'max-parallel' | Should -Be 2
        }

        It 'sets fail-fast when specified' {
            $config = @{
                os          = @('ubuntu-latest')
                language    = @('3.9')
                'fail-fast' = $false
            }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.'fail-fast' | Should -BeFalse
        }

        It 'defaults fail-fast to true when not specified' {
            $config = @{
                os       = @('ubuntu-latest')
                language = @('3.9')
            }
            $result = New-EnvironmentMatrix -Config $config
            $parsed = $result | ConvertFrom-Json
            $parsed.'fail-fast' | Should -BeTrue
        }
    }

    Describe 'Matrix size validation' {
        It 'throws when the Cartesian product exceeds max-combinations' {
            $config = @{
                os                 = @('a', 'b', 'c', 'd', 'e')
                language           = @('1', '2', '3', '4', '5')
                feature            = @('x', 'y', 'z')
                'max-combinations' = 10
            }
            { New-EnvironmentMatrix -Config $config } | Should -Throw '*exceeds*'
        }

        It 'defaults max-combinations to 256' {
            $oses = 1..20 | ForEach-Object { "os-$_" }
            $langs = 1..20 | ForEach-Object { "lang-$_" }
            $config = @{
                os       = $oses
                language = $langs
            }
            { New-EnvironmentMatrix -Config $config } | Should -Throw '*exceeds*'
        }

        It 'passes when product is within limit' {
            $config = @{
                os                 = @('a', 'b')
                language           = @('1', '2')
                'max-combinations' = 10
            }
            { New-EnvironmentMatrix -Config $config } | Should -Not -Throw
        }
    }

    Describe 'Input validation' {
        It 'throws on empty config' {
            { New-EnvironmentMatrix -Config @{} } | Should -Throw '*at least one*'
        }

        It 'throws when a dimension array is empty' {
            $config = @{ os = @() }
            { New-EnvironmentMatrix -Config $config } | Should -Throw '*empty*'
        }
    }

    Describe 'JSON file input' {
        It 'accepts a JSON file path and produces valid output' {
            $tmp = Join-Path $TestDrive 'config.json'
            @{
                os       = @('ubuntu-latest')
                language = @('3.9', '3.10')
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp
            $result = New-EnvironmentMatrix -ConfigPath $tmp
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.os | Should -Contain 'ubuntu-latest'
            $parsed.matrix.language | Should -HaveCount 2
        }
    }
}
