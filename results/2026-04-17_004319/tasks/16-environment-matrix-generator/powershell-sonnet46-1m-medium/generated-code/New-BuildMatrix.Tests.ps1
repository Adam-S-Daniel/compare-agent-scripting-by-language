# TDD tests for New-BuildMatrix.ps1
# Tests are written FIRST (red), then implementation makes them pass (green)

BeforeAll {
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

Describe "New-BuildMatrix" {

    # --- RED: Basic matrix generation ---
    Context "Basic matrix generation" {
        It "generates a matrix with single OS and language version" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
            }
            $result = New-BuildMatrix -Config $config
            $result | Should -Not -BeNullOrEmpty
            $result.matrix | Should -Not -BeNullOrEmpty
            $result.matrix.os | Should -Contain "ubuntu-22.04"
            $result.matrix.language | Should -Contain "3.11"
        }

        It "generates a cross-product matrix for multiple OS and language versions" {
            $config = @{
                os       = @("ubuntu-22.04", "windows-2022")
                language = @("3.10", "3.11")
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.os | Should -HaveCount 2
            $result.matrix.language | Should -HaveCount 2
        }

        It "includes feature flags in matrix when provided" {
            $config = @{
                os           = @("ubuntu-22.04")
                language     = @("3.11")
                feature_flag = @("experimental", "stable")
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.feature_flag | Should -HaveCount 2
            $result.matrix.feature_flag | Should -Contain "experimental"
        }
    }

    # --- RED: Include rules ---
    Context "Include rules" {
        It "adds extra variables via include rules" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
                include  = @(
                    @{ os = "ubuntu-22.04"; language = "3.11"; extra = "value1" }
                )
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.include | Should -HaveCount 1
            $result.matrix.include[0].extra | Should -Be "value1"
        }

        It "supports multiple include entries" {
            $config = @{
                os      = @("ubuntu-22.04")
                language = @("3.11")
                include = @(
                    @{ os = "macos-latest"; language = "3.12"; extra = "mac-only" },
                    @{ os = "ubuntu-22.04"; language = "3.11"; debug = $true }
                )
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.include | Should -HaveCount 2
        }
    }

    # --- RED: Exclude rules ---
    Context "Exclude rules" {
        It "passes exclude rules through to matrix" {
            $config = @{
                os       = @("ubuntu-22.04", "windows-2022")
                language = @("3.10", "3.11")
                exclude  = @(
                    @{ os = "windows-2022"; language = "3.10" }
                )
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.exclude | Should -HaveCount 1
            $result.matrix.exclude[0].os | Should -Be "windows-2022"
            $result.matrix.exclude[0].language | Should -Be "3.10"
        }
    }

    # --- RED: max-parallel and fail-fast ---
    Context "max-parallel and fail-fast configuration" {
        It "sets max-parallel when specified" {
            $config = @{
                os           = @("ubuntu-22.04")
                language     = @("3.11")
                maxParallel  = 4
            }
            $result = New-BuildMatrix -Config $config
            $result.'max-parallel' | Should -Be 4
        }

        It "sets fail-fast to false when specified" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
                failFast = $false
            }
            $result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $false
        }

        It "defaults fail-fast to true when not specified" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
            }
            $result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $true
        }

        It "omits max-parallel when not specified" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
            }
            $result = New-BuildMatrix -Config $config
            $result.Keys | Should -Not -Contain 'max-parallel'
        }
    }

    # --- RED: Matrix size validation ---
    Context "Matrix size validation" {
        It "throws when matrix exceeds maximum size" {
            $config = @{
                os       = @("ubuntu-22.04", "ubuntu-20.04", "windows-2022", "macos-latest", "macos-13")
                language = @("3.8", "3.9", "3.10", "3.11", "3.12")
                # 5 * 5 = 25 combinations, default max is 20
            }
            { New-BuildMatrix -Config $config -MaxMatrixSize 20 } | Should -Throw "*exceeds maximum*"
        }

        It "succeeds when matrix size equals maximum" {
            $config = @{
                os       = @("ubuntu-22.04", "ubuntu-20.04", "windows-2022", "macos-latest")
                language = @("3.10", "3.11", "3.12", "3.13", "3.14")
                # 4 * 5 = 20 combinations
            }
            { New-BuildMatrix -Config $config -MaxMatrixSize 20 } | Should -Not -Throw
        }

        It "uses default max size of 256 when not specified" {
            $os = 1..16 | ForEach-Object { "os-$_" }
            $lang = 1..16 | ForEach-Object { "lang-$_" }
            $config = @{ os = $os; language = $lang } # 256 combinations
            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }

        It "throws when matrix exceeds default max size of 256" {
            $os = 1..17 | ForEach-Object { "os-$_" }
            $lang = 1..16 | ForEach-Object { "lang-$_" }
            $config = @{ os = $os; language = $lang } # 272 combinations
            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
        }
    }

    # --- RED: JSON output ---
    Context "ConvertTo-MatrixJson" {
        It "serializes matrix to valid JSON" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
                failFast = $false
            }
            $result = New-BuildMatrix -Config $config
            $json = $result | ConvertTo-MatrixJson
            $parsed = $json | ConvertFrom-Json
            $parsed.matrix.os | Should -Contain "ubuntu-22.04"
            $parsed.'fail-fast' | Should -Be $false
        }

        It "produces compact single-line JSON by default" {
            $config = @{
                os       = @("ubuntu-22.04")
                language = @("3.11")
            }
            $result = New-BuildMatrix -Config $config
            $json = $result | ConvertTo-MatrixJson
            $json | Should -Not -Match "`n"
        }
    }

    # --- RED: Error handling ---
    Context "Error handling" {
        It "throws when config has no os key" {
            $config = @{ language = @("3.11") }
            { New-BuildMatrix -Config $config } | Should -Throw "*'os'*"
        }

        It "throws when os list is empty" {
            $config = @{ os = @(); language = @("3.11") }
            { New-BuildMatrix -Config $config } | Should -Throw "*empty*"
        }

        It "throws when language list is empty" {
            $config = @{ os = @("ubuntu-22.04"); language = @() }
            { New-BuildMatrix -Config $config } | Should -Throw "*empty*"
        }
    }

    # --- RED: Full integration (JSON in/out) ---
    Context "End-to-end JSON workflow" {
        It "accepts JSON string config and returns JSON output" {
            $jsonConfig = @'
{
    "os": ["ubuntu-22.04", "windows-2022"],
    "language": ["3.10", "3.11"],
    "failFast": false,
    "maxParallel": 2,
    "include": [{"os": "macos-latest", "language": "3.12"}],
    "exclude": [{"os": "windows-2022", "language": "3.10"}]
}
'@
            $result = Invoke-MatrixGenerator -JsonConfig $jsonConfig
            $parsed = $result | ConvertFrom-Json
            $parsed.matrix.os | Should -HaveCount 2
            $parsed.matrix.include | Should -HaveCount 1
            $parsed.matrix.exclude | Should -HaveCount 1
            $parsed.'fail-fast' | Should -Be $false
            $parsed.'max-parallel' | Should -Be 2
        }
    }
}
