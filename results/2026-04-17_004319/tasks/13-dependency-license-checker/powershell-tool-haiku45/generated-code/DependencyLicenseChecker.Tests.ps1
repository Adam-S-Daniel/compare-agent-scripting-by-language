BeforeAll {
    $script:ModuleRoot = $PSScriptRoot
    $script:ScriptPath = Join-Path $PSScriptRoot "DependencyLicenseChecker.ps1"
}

Describe "DependencyLicenseChecker" {
    BeforeEach {
        # Clean up any test artifacts
        $script:MockLicenses = @{}
    }

    Context "Parse package.json" {
        It "should parse a simple package.json and extract dependencies" {
            # Arrange
            $packageJsonContent = @{
                dependencies = @{
                    "lodash" = "^4.17.21"
                    "express" = "~4.18.2"
                }
            } | ConvertTo-Json

            $tempDir = [System.IO.Path]::GetTempPath()
            $tempFile = Join-Path $tempDir "test-package-$(Get-Random).json"
            $packageJsonContent | Set-Content $tempFile

            # Act
            $result = & $ScriptPath -ManifestPath $tempFile -WarningAction SilentlyContinue

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2

            $lodash = $result | Where-Object { $_.Name -eq "lodash" }
            $lodash | Should -Not -BeNullOrEmpty
            $lodash.Version | Should -Be "^4.17.21"

            $express = $result | Where-Object { $_.Name -eq "express" }
            $express | Should -Not -BeNullOrEmpty
            $express.Version | Should -Be "~4.18.2"

            Remove-Item -Path $tempFile -Force
        }
    }

    Context "Parse requirements.txt" {
        It "should parse requirements.txt and extract dependencies" {
            # Arrange
            $requirementsContent = @"
requests==2.28.1
flask>=2.0.0,<3.0.0
django
"@
            $tempDir = [System.IO.Path]::GetTempPath()
            $tempFile = Join-Path $tempDir "test-requirements-$(Get-Random).txt"
            $requirementsContent | Set-Content $tempFile

            # Act
            $result = & $ScriptPath -ManifestPath $tempFile -WarningAction SilentlyContinue

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3

            $requests = $result | Where-Object { $_.Name -eq "requests" }
            $requests | Should -Not -BeNullOrEmpty
            $requests.Version | Should -Be "2.28.1"

            $flask = $result | Where-Object { $_.Name -eq "flask" }
            $flask | Should -Not -BeNullOrEmpty

            Remove-Item -Path $tempFile -Force
        }
    }

    Context "Check licenses against allow/deny lists" {
        It "should generate compliance report with mock license lookup" {
            # Arrange
            $packageJsonContent = @{
                dependencies = @{
                    "lodash" = "^4.17.21"
                    "express" = "~4.18.2"
                }
            } | ConvertTo-Json

            $tempDir = [System.IO.Path]::GetTempPath()
            $tempFile = Join-Path $tempDir "test-package-$(Get-Random).json"
            $packageJsonContent | Set-Content $tempFile

            $mockLicenseLookup = {
                param($packageName)
                @{
                    "lodash" = "MIT"
                    "express" = "MIT"
                }[$packageName]
            }

            $allowedLicenses = @{ "MIT" = $true }
            $deniedLicenses = @{ "GPL" = $true }

            # Act
            $result = & $ScriptPath -ManifestPath $tempFile `
                -AllowedLicenses $allowedLicenses `
                -DeniedLicenses $deniedLicenses `
                -LicenseLookup $mockLicenseLookup `
                -WarningAction SilentlyContinue

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $report = $result | Where-Object { $_.Name -eq "lodash" }
            $report | Should -Not -BeNullOrEmpty
            $report.License | Should -Be "MIT"
            $report.Status | Should -Be "approved"

            Remove-Item -Path $tempFile -Force
        }
    }

    Context "Handle denied licenses" {
        It "should mark denied licenses with denied status" {
            # Arrange
            $packageJsonContent = @{
                dependencies = @{
                    "viral-lib" = "1.0.0"
                }
            } | ConvertTo-Json

            $tempDir = [System.IO.Path]::GetTempPath()
            $tempFile = Join-Path $tempDir "test-package-$(Get-Random).json"
            $packageJsonContent | Set-Content $tempFile

            $mockLicenseLookup = {
                param($packageName)
                "GPL"
            }

            $allowedLicenses = @{ "MIT" = $true }
            $deniedLicenses = @{ "GPL" = $true }

            # Act
            $result = & $ScriptPath -ManifestPath $tempFile `
                -AllowedLicenses $allowedLicenses `
                -DeniedLicenses $deniedLicenses `
                -LicenseLookup $mockLicenseLookup `
                -WarningAction SilentlyContinue

            # Assert
            $result.Status | Should -Be "denied"
            $result.License | Should -Be "GPL"

            Remove-Item -Path $tempFile -Force
        }
    }

    Context "Handle unknown licenses" {
        It "should mark unknown licenses with unknown status" {
            # Arrange
            $packageJsonContent = @{
                dependencies = @{
                    "mysterious-lib" = "1.0.0"
                }
            } | ConvertTo-Json

            $tempDir = [System.IO.Path]::GetTempPath()
            $tempFile = Join-Path $tempDir "test-package-$(Get-Random).json"
            $packageJsonContent | Set-Content $tempFile

            $mockLicenseLookup = {
                param($packageName)
                $null
            }

            $allowedLicenses = @{ "MIT" = $true }
            $deniedLicenses = @{}

            # Act
            $result = & $ScriptPath -ManifestPath $tempFile `
                -AllowedLicenses $allowedLicenses `
                -DeniedLicenses $deniedLicenses `
                -LicenseLookup $mockLicenseLookup `
                -WarningAction SilentlyContinue

            # Assert
            $result.Status | Should -Be "unknown"

            Remove-Item -Path $tempFile -Force
        }
    }
}
