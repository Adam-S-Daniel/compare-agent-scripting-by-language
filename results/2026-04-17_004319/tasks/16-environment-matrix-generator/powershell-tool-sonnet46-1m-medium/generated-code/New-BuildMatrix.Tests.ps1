# New-BuildMatrix.Tests.ps1
# TDD-driven Pester tests for the GitHub Actions build matrix generator.
# Tests are written first; the implementation in New-BuildMatrix.ps1 makes them pass.

BeforeAll {
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

Describe "New-BuildMatrix - Basic Matrix Generation" {

    It "generates a matrix with a single OS dimension" {
        $config = @{
            dimensions = @{
                os = @("ubuntu-latest", "windows-latest")
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.os | Should -Be @("ubuntu-latest", "windows-latest")
    }

    It "generates a matrix combining OS and language-version dimensions" {
        $config = @{
            dimensions = @{
                os             = @("ubuntu-latest", "windows-latest")
                "node-version" = @("18", "20")
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.os             | Should -Be @("ubuntu-latest", "windows-latest")
        $result.matrix."node-version" | Should -Be @("18", "20")
    }

    It "generates a matrix with OS, language-version, and feature-flag dimensions" {
        $config = @{
            dimensions = @{
                os             = @("ubuntu-latest", "windows-latest", "macos-latest")
                "node-version" = @("16", "18", "20")
                experimental   = @($true, $false)
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.os             | Should -HaveCount 3
        $result.matrix."node-version" | Should -HaveCount 3
        $result.matrix.experimental   | Should -HaveCount 2
    }

    It "returns valid JSON via ConvertTo-Json roundtrip" {
        $config = @{
            dimensions = @{
                os = @("ubuntu-latest")
            }
        }
        $result = New-BuildMatrix -Config $config
        $json   = $result | ConvertTo-Json -Depth 10
        $parsed = $json  | ConvertFrom-Json
        $parsed.matrix.os | Should -Be "ubuntu-latest"
    }
}

Describe "New-BuildMatrix - Include Rules" {

    It "passes include entries through to the matrix unchanged" {
        $config = @{
            dimensions = @{
                os = @("ubuntu-latest", "windows-latest")
            }
            include = @(
                @{ os = "ubuntu-latest"; experimental = $true }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 1
        $result.matrix.include[0].os           | Should -Be "ubuntu-latest"
        $result.matrix.include[0].experimental | Should -Be $true
    }

    It "supports multiple include entries" {
        $config = @{
            dimensions = @{
                os             = @("ubuntu-latest", "windows-latest")
                "node-version" = @("18", "20")
            }
            include = @(
                @{ os = "ubuntu-latest"; extra = "alpha" }
                @{ os = "windows-latest"; extra = "beta" }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.include | Should -HaveCount 2
        $result.matrix.include[0].extra | Should -Be "alpha"
        $result.matrix.include[1].extra | Should -Be "beta"
    }

    It "omits include key when no include rules provided" {
        $config = @{
            dimensions = @{
                os = @("ubuntu-latest")
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.PSObject.Properties.Name | Should -Not -Contain "include"
    }
}

Describe "New-BuildMatrix - Exclude Rules" {

    It "passes exclude entries through to the matrix unchanged" {
        $config = @{
            dimensions = @{
                os             = @("ubuntu-latest", "windows-latest")
                "node-version" = @("16", "18")
            }
            exclude = @(
                @{ os = "windows-latest"; "node-version" = "16" }
            )
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.exclude | Should -HaveCount 1
        $result.matrix.exclude[0].os             | Should -Be "windows-latest"
        $result.matrix.exclude[0]."node-version" | Should -Be "16"
    }

    It "omits exclude key when no exclude rules provided" {
        $config = @{
            dimensions = @{
                os = @("ubuntu-latest")
            }
        }
        $result = New-BuildMatrix -Config $config
        $result.matrix.PSObject.Properties.Name | Should -Not -Contain "exclude"
    }
}

Describe "New-BuildMatrix - Max-Parallel" {

    It "includes max-parallel when specified in config" {
        $config = @{
            dimensions    = @{ os = @("ubuntu-latest", "windows-latest") }
            "max-parallel" = 4
        }
        $result = New-BuildMatrix -Config $config
        $result."max-parallel" | Should -Be 4
    }

    It "omits max-parallel when not specified" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
        }
        $result = New-BuildMatrix -Config $config
        $result.PSObject.Properties.Name | Should -Not -Contain "max-parallel"
    }
}

Describe "New-BuildMatrix - Fail-Fast" {

    It "defaults fail-fast to true when not specified" {
        $config = @{
            dimensions = @{ os = @("ubuntu-latest") }
        }
        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $true
    }

    It "honours fail-fast = false when set in config" {
        $config = @{
            dimensions  = @{ os = @("ubuntu-latest") }
            "fail-fast" = $false
        }
        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $false
    }

    It "honours fail-fast = true when explicitly set in config" {
        $config = @{
            dimensions  = @{ os = @("ubuntu-latest") }
            "fail-fast" = $true
        }
        $result = New-BuildMatrix -Config $config
        $result."fail-fast" | Should -Be $true
    }
}

Describe "New-BuildMatrix - Matrix Size Validation" {

    It "succeeds when total combinations are within the default limit of 256" {
        # 2 x 3 x 4 = 24 combinations
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest")
                python  = @("3.9", "3.10", "3.11")
                feature = @("a", "b", "c", "d")
            }
        }
        { New-BuildMatrix -Config $config } | Should -Not -Throw
    }

    It "throws when total combinations exceed the default limit of 256" {
        # 10 x 10 x 10 = 1000 combinations
        $config = @{
            dimensions = @{
                os      = 1..10 | ForEach-Object { "os-$_" }
                version = 1..10 | ForEach-Object { "v$_" }
                feature = 1..10 | ForEach-Object { "f$_" }
            }
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
    }

    It "throws with custom MaxMatrixSize limit" {
        # 3 x 3 = 9 combinations, limit = 5
        $config = @{
            dimensions = @{
                os      = @("a", "b", "c")
                version = @("1", "2", "3")
            }
        }
        { New-BuildMatrix -Config $config -MaxMatrixSize 5 } | Should -Throw "*exceeds maximum*"
    }

    It "succeeds at exactly the maximum size" {
        # 2 x 2 = 4 combinations, limit = 4
        $config = @{
            dimensions = @{
                os      = @("ubuntu-latest", "windows-latest")
                version = @("18", "20")
            }
        }
        { New-BuildMatrix -Config $config -MaxMatrixSize 4 } | Should -Not -Throw
    }
}

Describe "New-BuildMatrix - Error Handling" {

    It "throws when Config is null" {
        { New-BuildMatrix -Config $null } | Should -Throw "*Config*"
    }

    It "throws when dimensions are missing" {
        { New-BuildMatrix -Config @{} } | Should -Throw "*dimensions*"
    }

    It "throws when a dimension has no values" {
        $config = @{
            dimensions = @{
                os = @()
            }
        }
        { New-BuildMatrix -Config $config } | Should -Throw "*empty*"
    }
}

Describe "New-BuildMatrix - File-Based Interface" {

    It "reads config from a JSON file and writes matrix JSON to stdout" {
        $tmpDir = [System.IO.Path]::GetTempPath()
        $cfgFile = Join-Path $tmpDir "test-config.json"
        $cfg = @{
            dimensions    = @{
                os            = @("ubuntu-latest", "windows-latest")
                "node-version" = @("18", "20")
            }
            "max-parallel" = 2
            "fail-fast"    = $false
        }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $cfgFile

        $output = & "$PSScriptRoot/New-BuildMatrix.ps1" -ConfigPath $cfgFile
        $parsed = $output | ConvertFrom-Json

        $parsed.matrix.os             | Should -HaveCount 2
        $parsed.matrix."node-version" | Should -HaveCount 2
        $parsed."max-parallel"        | Should -Be 2
        $parsed."fail-fast"           | Should -Be $false

        Remove-Item $cfgFile -Force
    }

    It "exits with code 1 and prints an error when config file is missing" {
        # Use pwsh -File to isolate from Pester's $ErrorActionPreference = "Stop"
        $result = pwsh -File "$PSScriptRoot/New-BuildMatrix.ps1" -ConfigPath "non-existent.json" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($result | Out-String) | Should -Match "not found|does not exist|Cannot find"
    }
}
