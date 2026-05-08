Describe "Dependency License Checker" {
    BeforeAll {
        # Import the script being tested
        $scriptPath = Join-Path $PSScriptRoot "Check-DependencyLicenses.ps1"
        . $scriptPath

        # Test fixtures directory
        $script:TestFixturesDir = Join-Path $PSScriptRoot "test-fixtures"

        # Helper function for test file creation
        function script:Create-TestFile {
            param(
                [string]$Path,
                [string]$Content
            )
            $Content | Set-Content -Path $Path -Encoding UTF8
        }
    }

    Context "Basic License Configuration" {
        It "should parse a license config with allowed and denied licenses" {
            # Arrange
            $config = @{
                allowed = @("MIT", "Apache-2.0", "BSD-3-Clause")
                denied = @("GPL-3.0")
            }

            # Act
            $result = Invoke-LicenseCheck -Config $config

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.allowed | Should -Contain "MIT"
            $result.denied | Should -Contain "GPL-3.0"
        }
    }

    Context "Parse package.json Manifest" {
        It "should extract dependencies from package.json" {
            # Arrange
            $manifestPath = Join-Path $script:TestFixturesDir "simple-package.json"

            # Act
            $deps = Get-Dependencies -ManifestPath $manifestPath

            # Assert
            $deps | Should -Not -BeNullOrEmpty
            $deps.Count | Should -BeGreaterThan 0
            $deps[0].name | Should -Not -BeNullOrEmpty
            $deps[0].version | Should -Not -BeNullOrEmpty
        }
    }

    Context "License Lookup Mock" {
        It "should lookup license for a dependency using mock provider" {
            # Arrange
            $mockLicenses = @{
                "lodash" = "MIT"
                "express" = "MIT"
                "react" = "MIT"
                "unknown-package" = $null
            }

            # Act
            $license = Get-LicenseForDependency -PackageName "lodash" -MockLicenses $mockLicenses

            # Assert
            $license | Should -Be "MIT"
        }
    }

    Context "License Compliance Report" {
        It "should generate a report with approved, denied, and unknown licenses" {
            # Arrange
            $config = @{
                allowed = @("MIT", "Apache-2.0")
                denied = @("GPL-3.0")
            }

            $dependencies = @(
                @{ name = "lodash"; version = "4.17.21" }
                @{ name = "react"; version = "18.0.0" }
                @{ name = "gpl-package"; version = "1.0.0" }
            )

            $mockLicenses = @{
                "lodash" = "MIT"
                "react" = "MIT"
                "gpl-package" = "GPL-3.0"
            }

            # Act
            $report = New-ComplianceReport -Dependencies $dependencies -Config $config -MockLicenses $mockLicenses

            # Assert
            $report | Should -Not -BeNullOrEmpty
            $report.approved | Should -Not -BeNullOrEmpty
            $report.denied | Should -Not -BeNullOrEmpty
            $report.approved.Count | Should -Be 2
            $report.denied.Count | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "should handle missing manifest file gracefully" {
            # Arrange
            $nonexistentPath = Join-Path $script:TestFixturesDir "nonexistent.json"

            # Act & Assert
            { Get-Dependencies -ManifestPath $nonexistentPath -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Parse requirements.txt Manifest" {
        It "should extract dependencies from requirements.txt" {
            # Arrange
            $manifestPath = Join-Path $script:TestFixturesDir "requirements.txt"

            # Act
            $deps = Get-Dependencies -ManifestPath $manifestPath

            # Assert
            $deps | Should -Not -BeNullOrEmpty
            $deps.Count | Should -Be 3
            $deps[0].name | Should -Be "requests"
            $deps[0].version | Should -Be "2.28.1"
        }
    }

    Context "Multiple License Categories" {
        It "should correctly categorize multiple dependencies across categories" {
            # Arrange
            $config = @{
                allowed = @("MIT", "Apache-2.0", "ISC")
                denied = @("AGPL-3.0", "GPL-3.0")
            }

            $dependencies = @(
                @{ name = "safe1"; version = "1.0.0" }
                @{ name = "safe2"; version = "2.0.0" }
                @{ name = "unsafe"; version = "1.0.0" }
                @{ name = "unknown-pkg"; version = "1.0.0" }
            )

            $mockLicenses = @{
                "safe1" = "MIT"
                "safe2" = "Apache-2.0"
                "unsafe" = "AGPL-3.0"
                "unknown-pkg" = $null
            }

            # Act
            $report = New-ComplianceReport -Dependencies $dependencies -Config $config -MockLicenses $mockLicenses

            # Assert
            $report.approved | Should -HaveCount 2
            $report.denied | Should -HaveCount 1
            $report.unknown | Should -HaveCount 1
            $report.denied[0].name | Should -Be "unsafe"
            $report.denied[0].license | Should -Be "AGPL-3.0"
        }
    }

    Context "Version Extraction Accuracy" {
        It "should extract exact versions from package.json" {
            # Arrange
            $manifestPath = Join-Path $script:TestFixturesDir "simple-package.json"

            # Act
            $deps = Get-Dependencies -ManifestPath $manifestPath

            # Assert
            $lodash = $deps | Where-Object { $_.name -eq "lodash" }
            $lodash.version | Should -Be "4.17.21"

            $express = $deps | Where-Object { $_.name -eq "express" }
            $express.version | Should -Be "4.18.2"
        }
    }

    Context "Unsupported Manifest Format" {
        It "should throw error for unsupported file format" {
            # Arrange
            $testPath = Join-Path $script:TestFixturesDir "test.xyz"
            Create-TestFile -Path $testPath -Content "some content"

            # Act & Assert
            try {
                { Get-Dependencies -ManifestPath $testPath -ErrorAction Stop } | Should -Throw
            }
            finally {
                Remove-Item $testPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "License Configuration Validation" {
        It "should reject invalid config missing required keys" {
            # Arrange
            $invalidConfig = @{ allowed = @("MIT") }

            # Act & Assert
            { Invoke-LicenseCheck -Config $invalidConfig -ErrorAction Stop } | Should -Throw
        }

        It "should accept valid config with both allowed and denied keys" {
            # Arrange
            $validConfig = @{
                allowed = @("MIT", "Apache-2.0")
                denied = @("GPL-3.0")
            }

            # Act & Assert
            $result = Invoke-LicenseCheck -Config $validConfig
            $result.allowed.Count | Should -Be 2
            $result.denied.Count | Should -Be 1
        }
    }

    Context "Format Report Output" {
        It "should format compliance report without errors" {
            # Arrange
            $report = @{
                total   = 3
                approved = @(
                    @{ name = "lodash"; version = "4.17.21"; license = "MIT" }
                )
                denied = @(
                    @{ name = "gpl-pkg"; version = "1.0.0"; license = "GPL-3.0" }
                )
                unknown = @(
                    @{ name = "unknown"; version = "1.0.0"; license = $null }
                )
            }

            # Act - format should not throw
            { Format-ComplianceReport -Report $report } | Should -Not -Throw
        }
    }
}
