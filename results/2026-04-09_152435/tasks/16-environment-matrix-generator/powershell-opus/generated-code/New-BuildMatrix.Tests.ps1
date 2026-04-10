# Pester tests for New-BuildMatrix.ps1
# TDD: These tests define the expected behavior of the matrix generator.

BeforeAll {
    # Source the script under test
    . "$PSScriptRoot/New-BuildMatrix.ps1"
}

Describe "New-BuildMatrix" {

    # Test 1: Basic cross-product matrix from dimensions
    Context "Basic matrix generation" {
        It "generates a cross-product from two dimensions" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest", "windows-latest")
                    node = @("18", "20")
                }
            }
            $result = New-BuildMatrix -Config $config
            # 2 os * 2 node = 4 combinations
            $result.matrix | Should -Not -BeNullOrEmpty
            $result.matrix.os | Should -Contain "ubuntu-latest"
            $result.matrix.os | Should -Contain "windows-latest"
            $result.matrix.node | Should -Contain "18"
            $result.matrix.node | Should -Contain "20"
        }

        It "generates a cross-product from three dimensions" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest")
                    python = @("3.10", "3.11")
                    feature = @("enabled", "disabled")
                }
            }
            $result = New-BuildMatrix -Config $config
            # 1 * 2 * 2 = 4 combinations
            $result.matrix.os | Should -Contain "ubuntu-latest"
            $result.matrix.python | Should -Contain "3.10"
            $result.matrix.feature | Should -Contain "enabled"
        }

        It "generates correct matrix JSON output" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest")
                    node = @("20")
                }
            }
            $result = New-BuildMatrix -Config $config
            $json = $result | ConvertTo-Json -Depth 10
            $parsed = $json | ConvertFrom-Json
            $parsed.matrix.os | Should -Contain "ubuntu-latest"
            $parsed.matrix.node | Should -Contain "20"
        }
    }

    # Test 2: Include rules add extra combinations
    Context "Include rules" {
        It "adds include entries to the matrix" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest")
                    node = @("18")
                }
                include = @(
                    @{ os = "macos-latest"; node = "20"; experimental = $true }
                )
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.include | Should -Not -BeNullOrEmpty
            $result.matrix.include.Count | Should -Be 1
            $result.matrix.include[0].os | Should -Be "macos-latest"
            $result.matrix.include[0].experimental | Should -Be $true
        }

        It "supports multiple include entries" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest")
                    node = @("18")
                }
                include = @(
                    @{ os = "macos-latest"; node = "20" },
                    @{ os = "windows-latest"; node = "20" }
                )
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.include.Count | Should -Be 2
        }
    }

    # Test 3: Exclude rules remove combinations
    Context "Exclude rules" {
        It "adds exclude entries to the matrix" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest", "windows-latest")
                    node = @("16", "18")
                }
                exclude = @(
                    @{ os = "windows-latest"; node = "16" }
                )
            }
            $result = New-BuildMatrix -Config $config
            $result.matrix.exclude | Should -Not -BeNullOrEmpty
            $result.matrix.exclude.Count | Should -Be 1
            $result.matrix.exclude[0].os | Should -Be "windows-latest"
            $result.matrix.exclude[0].node | Should -Be "16"
        }
    }

    # Test 4: Fail-fast configuration
    Context "Fail-fast configuration" {
        It "sets fail-fast to true when specified" {
            $config = @{
                dimensions = @{ os = @("ubuntu-latest") }
                'fail-fast' = $true
            }
            $result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $true
        }

        It "sets fail-fast to false when specified" {
            $config = @{
                dimensions = @{ os = @("ubuntu-latest") }
                'fail-fast' = $false
            }
            $result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $false
        }

        It "defaults fail-fast to true when not specified" {
            $config = @{
                dimensions = @{ os = @("ubuntu-latest") }
            }
            $result = New-BuildMatrix -Config $config
            $result.'fail-fast' | Should -Be $true
        }
    }

    # Test 5: Max-parallel configuration
    Context "Max-parallel configuration" {
        It "sets max-parallel when specified" {
            $config = @{
                dimensions = @{ os = @("ubuntu-latest") }
                'max-parallel' = 4
            }
            $result = New-BuildMatrix -Config $config
            $result.'max-parallel' | Should -Be 4
        }

        It "omits max-parallel when not specified" {
            $config = @{
                dimensions = @{ os = @("ubuntu-latest") }
            }
            $result = New-BuildMatrix -Config $config
            $result.PSObject.Properties.Name | Should -Not -Contain 'max-parallel'
        }
    }

    # Test 6: Matrix size validation
    Context "Matrix size validation" {
        It "rejects matrix exceeding default max of 256 combinations" {
            # 10 * 10 * 10 = 1000 combinations (exceeds 256)
            $config = @{
                dimensions = @{
                    a = @("1","2","3","4","5","6","7","8","9","10")
                    b = @("1","2","3","4","5","6","7","8","9","10")
                    c = @("1","2","3","4","5","6","7","8","9","10")
                }
            }
            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
        }

        It "respects custom max-combinations limit" {
            # 3 * 3 = 9, but max is 5
            $config = @{
                dimensions = @{
                    os = @("a","b","c")
                    ver = @("1","2","3")
                }
                'max-combinations' = 5
            }
            { New-BuildMatrix -Config $config } | Should -Throw "*exceeds maximum*"
        }

        It "allows matrix within custom max-combinations limit" {
            $config = @{
                dimensions = @{
                    os = @("a","b")
                    ver = @("1","2")
                }
                'max-combinations' = 10
            }
            { New-BuildMatrix -Config $config } | Should -Not -Throw
        }
    }

    # Test 7: Error handling
    Context "Error handling" {
        It "throws on missing dimensions" {
            $config = @{}
            { New-BuildMatrix -Config $config } | Should -Throw "*dimensions*"
        }

        It "throws on empty dimensions" {
            $config = @{ dimensions = @{} }
            { New-BuildMatrix -Config $config } | Should -Throw "*dimensions*"
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

    # Test 8: JSON config file input
    Context "Config from JSON file" {
        It "loads config from a JSON file" {
            $tmpFile = Join-Path $TestDrive "config.json"
            $jsonConfig = @{
                dimensions = @{
                    os = @("ubuntu-latest", "macos-latest")
                    go = @("1.21", "1.22")
                }
                'fail-fast' = $false
                'max-parallel' = 2
            } | ConvertTo-Json -Depth 5
            $jsonConfig | Set-Content -Path $tmpFile

            $result = New-BuildMatrix -ConfigPath $tmpFile
            $result.matrix.os | Should -Contain "ubuntu-latest"
            $result.matrix.os | Should -Contain "macos-latest"
            $result.matrix.go | Should -Contain "1.21"
            $result.'fail-fast' | Should -Be $false
            $result.'max-parallel' | Should -Be 2
        }
    }

    # Test 9: Full end-to-end JSON output
    Context "End-to-end JSON output" {
        It "produces valid strategy JSON with all features" {
            $config = @{
                dimensions = @{
                    os = @("ubuntu-latest", "windows-latest")
                    python = @("3.10", "3.11")
                }
                include = @(
                    @{ os = "ubuntu-latest"; python = "3.12"; experimental = $true }
                )
                exclude = @(
                    @{ os = "windows-latest"; python = "3.10" }
                )
                'fail-fast' = $false
                'max-parallel' = 3
            }
            $result = New-BuildMatrix -Config $config
            $json = $result | ConvertTo-Json -Depth 10

            # Verify it round-trips through JSON
            $parsed = $json | ConvertFrom-Json

            $parsed.matrix.os | Should -Contain "ubuntu-latest"
            $parsed.matrix.os | Should -Contain "windows-latest"
            $parsed.matrix.python | Should -Contain "3.10"
            $parsed.matrix.python | Should -Contain "3.11"
            $parsed.matrix.include.Count | Should -Be 1
            $parsed.matrix.exclude.Count | Should -Be 1
            $parsed.'fail-fast' | Should -Be $false
            $parsed.'max-parallel' | Should -Be 3
        }
    }
}
