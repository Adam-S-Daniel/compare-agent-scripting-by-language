BeforeAll {
    . $PSScriptRoot/DependencyLicenseChecker.ps1
}

Describe "DependencyLicenseChecker" {
    Context "Parse package.json" {
        It "Should extract dependencies from package.json" {
            $packageJson = @{
                dependencies = @{
                    express = "4.18.0"
                    lodash = "4.17.21"
                }
            } | ConvertTo-Json

            $tempFile = New-TemporaryFile
            Set-Content -Path $tempFile.FullName -Value $packageJson

            $dependencies = Get-Dependencies -ManifestPath $tempFile.FullName

            $dependencies.Count | Should -Be 2

            $depsByName = @{}
            foreach ($dep in $dependencies) {
                $depsByName[$dep.name] = $dep.version
            }

            $depsByName["express"] | Should -Be "4.18.0"
            $depsByName["lodash"] | Should -Be "4.17.21"

            Remove-Item $tempFile.FullName
        }
    }

    Context "Get License Information" {
        It "Should get license for a dependency using mock lookup" {
            $license = Get-DependencyLicense -Name "express" -Version "4.18.0"

            $license | Should -Not -BeNullOrEmpty
            $license | Should -BeOfType [string]
        }
    }

    Context "Check License Compliance" {
        It "Should approve dependency with allowed license" {
            $allowedLicenses = @("MIT", "Apache-2.0")
            $deniedLicenses = @("GPL-3.0")

            $status = Check-LicenseCompliance -License "MIT" -AllowedLicenses $allowedLicenses -DeniedLicenses $deniedLicenses

            $status | Should -Be "approved"
        }

        It "Should deny dependency with denied license" {
            $allowedLicenses = @("MIT", "Apache-2.0")
            $deniedLicenses = @("GPL-3.0")

            $status = Check-LicenseCompliance -License "GPL-3.0" -AllowedLicenses $allowedLicenses -DeniedLicenses $deniedLicenses

            $status | Should -Be "denied"
        }

        It "Should mark as unknown if license is not in allow or deny list" {
            $allowedLicenses = @("MIT")
            $deniedLicenses = @("GPL-3.0")

            $status = Check-LicenseCompliance -License "MPL-2.0" -AllowedLicenses $allowedLicenses -DeniedLicenses $deniedLicenses

            $status | Should -Be "unknown"
        }
    }

    Context "Generate Compliance Report" {
        It "Should generate compliance report for dependencies" {
            $dependencies = @(
                @{ name = "express"; version = "4.18.0" }
                @{ name = "lodash"; version = "4.17.21" }
                @{ name = "redis"; version = "4.0.0" }
            )

            $allowedLicenses = @("MIT", "Apache-2.0", "BSD")
            $deniedLicenses = @("GPL-3.0", "AGPL-3.0")

            $report = Generate-ComplianceReport -Dependencies $dependencies `
                -AllowedLicenses $allowedLicenses -DeniedLicenses $deniedLicenses

            $report.Count | Should -Be 3

            $reportByName = @{}
            foreach ($item in $report) {
                $reportByName[$item.name] = $item
            }

            $reportByName["express"].status | Should -Be "approved"
            $reportByName["express"].license | Should -Be "MIT"

            $reportByName["lodash"].status | Should -Be "approved"
            $reportByName["lodash"].license | Should -Be "MIT"

            $reportByName["redis"].status | Should -Be "denied"
            $reportByName["redis"].license | Should -Be "GPL-3.0"
        }

        It "Should handle missing manifest gracefully" {
            { Get-Dependencies -ManifestPath "/nonexistent/path/manifest.json" } | Should -Throw
        }
    }

    Context "Save Report to File" {
        It "Should save compliance report to JSON file" {
            $report = @(
                @{ name = "express"; version = "4.18.0"; license = "MIT"; status = "approved" }
                @{ name = "redis"; version = "4.0.0"; license = "GPL-3.0"; status = "denied" }
            )

            $tempFile = New-TemporaryFile
            Save-ComplianceReport -Report $report -OutputPath $tempFile.FullName -Format "json"

            $content = Get-Content -Path $tempFile.FullName -Raw | ConvertFrom-Json
            $content.Count | Should -Be 2
            $content[0].name | Should -Be "express"
            $content[0].status | Should -Be "approved"

            Remove-Item $tempFile.FullName
        }

        It "Should save compliance report to CSV file" {
            $report = @(
                @{ name = "express"; version = "4.18.0"; license = "MIT"; status = "approved" }
                @{ name = "redis"; version = "4.0.0"; license = "GPL-3.0"; status = "denied" }
            )

            $tempFile = New-TemporaryFile
            Save-ComplianceReport -Report $report -OutputPath $tempFile.FullName -Format "csv"

            $content = @(Get-Content -Path $tempFile.FullName)
            $content.Count | Should -BeGreaterThan 1
            $content[0] | Should -Match '"name"'
            $content[0] | Should -Match '"license"'
            $content[0] | Should -Match '"status"'

            Remove-Item $tempFile.FullName
        }
    }
}
