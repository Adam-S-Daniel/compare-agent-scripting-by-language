BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot "DependencyLicenseChecker.ps1"
    $script:TestFixturesDir = Join-Path $PSScriptRoot "test-fixtures"

    # Source the main module
    . $ModulePath
}

Describe "DependencyLicenseChecker" {
    Context "Parsing package.json" {
        It "Should parse package.json and extract dependencies" {
            # GREEN: Parse package.json and extract dependencies
            $packageJson = @{
                name = "test-app"
                dependencies = @{
                    lodash = "4.17.21"
                    axios = "1.4.0"
                }
            } | ConvertTo-Json

            $result = Parse-PackageJson -Content $packageJson

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2

            # Check that both dependencies are present (order-independent)
            $lodashDep = $result | Where-Object { $_.Name -eq "lodash" }
            $axioDep = $result | Where-Object { $_.Name -eq "axios" }

            $lodashDep | Should -Not -BeNullOrEmpty
            $lodashDep.Version | Should -Be "4.17.21"
            $axioDep | Should -Not -BeNullOrEmpty
            $axioDep.Version | Should -Be "1.4.0"
        }
    }

    Context "Mocking license lookup" {
        It "Should look up license from mocked provider" {
            # RED: Mock license lookup function
            $license = Get-MockLicense -DependencyName "lodash" -Version "4.17.21"

            $license | Should -Not -BeNullOrEmpty
            $license.Name | Should -Be "lodash"
            $license.Version | Should -Be "4.17.21"
            $license.LicenseType | Should -Be "MIT"
        }
    }

    Context "License compliance checking" {
        It "Should approve licenses in allow-list" {
            # RED: Test against allow-list
            $allowList = @("MIT", "Apache-2.0", "BSD-2-Clause")
            $denyList = @("GPL-3.0")

            $status = Check-LicenseCompliance -LicenseType "MIT" -AllowList $allowList -DenyList $denyList

            $status | Should -Be "approved"
        }

        It "Should deny licenses in deny-list" {
            $allowList = @("MIT", "Apache-2.0")
            $denyList = @("GPL-3.0")

            $status = Check-LicenseCompliance -LicenseType "GPL-3.0" -AllowList $allowList -DenyList $denyList

            $status | Should -Be "denied"
        }

        It "Should mark unknown licenses as unknown" {
            $allowList = @("MIT")
            $denyList = @("GPL-3.0")

            $status = Check-LicenseCompliance -LicenseType "Custom-License" -AllowList $allowList -DenyList $denyList

            $status | Should -Be "unknown"
        }
    }

    Context "Generating compliance report" {
        It "Should generate report with dependencies and status" {
            # RED: Test report generation
            $dependencies = @(
                @{ Name = "lodash"; Version = "4.17.21"; License = "MIT" }
                @{ Name = "axios"; Version = "1.4.0"; License = "Apache-2.0" }
                @{ Name = "gpl-lib"; Version = "1.0.0"; License = "GPL-3.0" }
            )

            $allowList = @("MIT", "Apache-2.0")
            $denyList = @("GPL-3.0")

            $report = Generate-ComplianceReport -Dependencies $dependencies -AllowList $allowList -DenyList $denyList

            $report | Should -Not -BeNullOrEmpty
            $report.Count | Should -Be 3

            # Check each entry has status
            $report[0].Status | Should -Be "approved"
            $report[1].Status | Should -Be "approved"
            $report[2].Status | Should -Be "denied"
        }
    }

    Context "Error handling" {
        It "Should handle invalid JSON gracefully" {
            $invalidJson = "{ invalid json"

            { Parse-PackageJson -Content $invalidJson } | Should -Throw
        }

        It "Should handle missing manifest file" {
            $nonExistentPath = "/tmp/nonexistent-manifest.json"

            { Parse-ManifestFile -Path $nonExistentPath } | Should -Throw
        }
    }

    Context "Integration: Full compliance workflow" {
        It "Should process real package.json and generate report" {
            $packageJsonPath = Join-Path $TestFixturesDir "package.json"
            $configPath = Join-Path $TestFixturesDir "license-config.json"

            # Verify fixtures exist
            $packageJsonPath | Should -Exist
            $configPath | Should -Exist

            # Parse manifest
            $dependencies = Parse-ManifestFile -Path $packageJsonPath
            $dependencies | Should -Not -BeNullOrEmpty
            $dependencies.Count | Should -Be 4

            # Load config
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            $allowList = $config.allowedLicenses
            $denyList = $config.deniedLicenses

            # Generate report
            $report = @()
            foreach ($dep in $dependencies) {
                $license = Get-MockLicense -DependencyName $dep.Name -Version $dep.Version
                $licenseType = if ($null -eq $license) { "UNKNOWN" } else { $license.LicenseType }
                $status = Check-LicenseCompliance -LicenseType $licenseType -AllowList $allowList -DenyList $denyList

                $report += @{
                    Name    = $dep.Name
                    Version = $dep.Version
                    License = $licenseType
                    Status  = $status
                }
            }

            # Verify report
            $report.Count | Should -Be 4
            $report | Where-Object { $_.Status -eq "approved" } | Should -HaveCount 4
        }

        It "Should export compliance report to JSON and text" {
            $tempDir = [System.IO.Path]::GetTempPath()
            $reportPath = Join-Path $tempDir "test-report-$(Get-Random).json"

            $dependencies = @(
                @{ Name = "lodash"; Version = "4.17.21"; License = "MIT" }
                @{ Name = "axios"; Version = "1.4.0"; License = "Apache-2.0" }
            )

            $allowList = @("MIT", "Apache-2.0")
            $denyList = @("GPL-3.0")

            $report = Generate-ComplianceReport -Dependencies $dependencies -AllowList $allowList -DenyList $denyList
            Export-ComplianceReport -Report $report -OutputPath $reportPath

            # Verify JSON export
            $reportPath | Should -Exist
            $jsonContent = Get-Content -Path $reportPath -Raw | ConvertFrom-Json
            $jsonContent.Count | Should -Be 2

            # Verify text export
            $textPath = $reportPath -replace '\.json$', '.txt'
            $textPath | Should -Exist
            $textContent = Get-Content -Path $textPath -Raw
            $textContent | Should -Match "DEPENDENCY LICENSE COMPLIANCE REPORT"
            $textContent | Should -Match "Total Dependencies: 2"

            # Cleanup
            Remove-Item -Path $reportPath, $textPath -Force
        }
    }
}
