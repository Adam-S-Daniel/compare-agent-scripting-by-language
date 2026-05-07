BeforeAll {
    # Load the module we're testing
    $modulePath = Join-Path $PSScriptRoot "EnvironmentMatrixGenerator.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}

Describe "EnvironmentMatrixGenerator" {

    Context "Basic Matrix Generation" {
        It "should generate a matrix with a single OS and language" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("powershell-7")
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result | Should -Not -BeNullOrEmpty
            $result.include | Should -HaveCount 1
            $result.include[0].os | Should -Be "ubuntu-latest"
            $result.include[0].language | Should -Be "powershell-7"
        }
    }

    Context "Multiple Values" {
        It "should create cartesian product of OS and language versions" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language = @("powershell-7", "powershell-5.1")
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.include | Should -HaveCount 4
        }
    }

    Context "Feature Flags" {
        It "should include feature flags in matrix combinations" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("powershell-7")
                features = @("logging", "caching")
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.include | Should -HaveCount 2
            $result.include[0].features | Should -Be "logging"
            $result.include[1].features | Should -Be "caching"
        }
    }

    Context "Include Rules" {
        It "should add specific include rules to the matrix" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("powershell-7")
                include = @(
                    @{os = "macos-latest"; language = "powershell-7"; experimental = $true}
                )
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.include | Should -HaveCount 2
            $result.include[1].os | Should -Be "macos-latest"
            $result.include[1].experimental | Should -Be $true
        }
    }

    Context "Exclude Rules" {
        It "should remove combinations matching exclude rules" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language = @("powershell-7")
                exclude = @(
                    @{os = "windows-latest"}
                )
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.include | Should -HaveCount 1
            $result.include[0].os | Should -Be "ubuntu-latest"
            $result.exclude | Should -HaveCount 1
        }
    }

    Context "Max Parallel Limit" {
        It "should set max-parallel when specified" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("powershell-7")
                maxParallel = 5
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.'max-parallel' | Should -Be 5
        }
    }

    Context "Fail Fast Configuration" {
        It "should set fail-fast to false when specified" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("powershell-7")
                failFast = $false
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.'fail-fast' | Should -Be $false
        }
    }

    Context "Matrix Size Validation" {
        It "should throw error if matrix exceeds maximum size" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest", "macos-latest", "macos-13")
                language = @("powershell-7", "powershell-5.1", "powershell-6", "pwsh")
                features = @("f1", "f2", "f3", "f4", "f5")
                maxSize = 10
            }

            { New-EnvironmentMatrix -Configuration $config } | Should -Throw
        }
    }

    Context "Complex Configuration" {
        It "should generate correct matrix with all options" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
                language = @("powershell-7", "powershell-5.1")
                features = @("logging")
                include = @(
                    @{os = "macos-latest"; language = "powershell-7"; experimental = $true}
                )
                exclude = @(
                    @{os = "windows-latest"; language = "powershell-5.1"}
                )
                maxParallel = 4
                failFast = $false
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.include | Should -Not -BeNullOrEmpty
            $result.'max-parallel' | Should -Be 4
            $result.'fail-fast' | Should -Be $false
            $result.exclude | Should -HaveCount 1
        }
    }

    Context "JSON Output" {
        It "should output valid JSON format" {
            $config = @{
                os = @("ubuntu-latest")
                language = @("powershell-7")
            }

            $result = New-EnvironmentMatrix -Configuration $config
            $json = $result | ConvertTo-Json

            $json | Should -Not -BeNullOrEmpty
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "should handle empty arrays gracefully" {
            $config = @{
                os = @("ubuntu-latest")
                language = @()
            }

            { New-EnvironmentMatrix -Configuration $config } | Should -Throw
        }

        It "should handle configuration with only os values" {
            $config = @{
                os = @("ubuntu-latest", "windows-latest")
            }

            $result = New-EnvironmentMatrix -Configuration $config

            $result.include | Should -HaveCount 2
        }
    }
}
