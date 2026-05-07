BeforeAll {
    # Import the script being tested
    . $PSScriptRoot/MatrixGenerator.ps1
}

Describe "MatrixGenerator - Basic Matrix Generation" {
    Context "Simple OS and Language Matrix" {
        It "should generate a matrix with OS and language versions" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
            }

            $result = New-EnvironmentMatrix -Configuration $config

            # Should have 4 combinations: 2 OS × 2 languages
            $result.include | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 4

            # Check that all combinations exist
            $result.include | Where-Object { $_.os -eq "ubuntu-latest" -and $_.language -eq "3.9" } | Should -Not -BeNullOrEmpty
            $result.include | Where-Object { $_.os -eq "ubuntu-latest" -and $_.language -eq "3.10" } | Should -Not -BeNullOrEmpty
            $result.include | Where-Object { $_.os -eq "windows-latest" -and $_.language -eq "3.9" } | Should -Not -BeNullOrEmpty
            $result.include | Where-Object { $_.os -eq "windows-latest" -and $_.language -eq "3.10" } | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "MatrixGenerator - Exclude Rules" {
    Context "Excluding specific combinations" {
        It "should exclude specified combinations from the matrix" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
                exclude = @(
                    @{ os = "windows-latest"; language = "3.9" }
                )
            }

            $result = New-EnvironmentMatrix -Configuration $config

            # Should have 3 combinations (4 - 1 excluded)
            $result.include | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 3

            # The excluded combination should not exist
            $result.include | Where-Object { $_.os -eq "windows-latest" -and $_.language -eq "3.9" } | Should -BeNullOrEmpty
        }
    }
}

Describe "MatrixGenerator - Include Rules" {
    Context "Adding extra combinations" {
        It "should add explicitly included combinations" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("3.9")
                include = @(
                    @{ os = "macos-latest"; language = "3.9"; extra_flag = "special" }
                )
            }

            $result = New-EnvironmentMatrix -Configuration $config

            # Should have 2 combinations (1 base + 1 included)
            $result.include | Measure-Object | Select-Object -ExpandProperty Count | Should -Be 2

            # The extra combination should exist with the extra field
            $result.include | Where-Object { $_.os -eq "macos-latest" -and $_.language -eq "3.9" } | Should -Not -BeNullOrEmpty
            $result.include | Where-Object { $_.os -eq "macos-latest" -and $_.language -eq "3.9" } | Select-Object -ExpandProperty extra_flag | Should -Be "special"
        }
    }
}

Describe "MatrixGenerator - Max Parallel Limit" {
    Context "Enforcing max-parallel configuration" {
        It "should include max-parallel in output when specified" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language = @("3.9", "3.10")
                max_parallel = 2
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result."max-parallel" | Should -Be 2
        }
    }
}

Describe "MatrixGenerator - Fail Fast Configuration" {
    Context "Fail-fast setting" {
        It "should include fail-fast in output when specified" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("3.9")
                fail_fast = $false
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result."fail-fast" | Should -Be $false
        }
    }
}

Describe "MatrixGenerator - Matrix Size Validation" {
    Context "Validating matrix doesn't exceed max size" {
        It "should raise error when matrix exceeds max size" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest", "macos-latest")
                language = @("3.8", "3.9", "3.10", "3.11")
                features = @("feature1", "feature2")
                max_size = 5  # Will have 3×4×2=24 combinations
            }

            { New-EnvironmentMatrix -Configuration $config } | Should -Throw
        }
    }

    It "should accept matrix when within max size limit" {
        $config = @{
            os = @("ubuntu-latest", "windows-latest")
            language = @("3.9", "3.10")
            max_size = 10  # Will have 2×2=4 combinations
        }

        $result = New-EnvironmentMatrix -Configuration $config
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe "MatrixGenerator - JSON Output" {
    Context "Output format validation" {
        It "should produce valid JSON output" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("3.9")
            }

            $result = New-EnvironmentMatrix -Configuration $config
            $json = $result | ConvertTo-Json

            # Should be valid JSON (no error on parsing)
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}
