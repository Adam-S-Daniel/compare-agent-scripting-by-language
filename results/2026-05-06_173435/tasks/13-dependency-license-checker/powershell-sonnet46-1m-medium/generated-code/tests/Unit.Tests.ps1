# Unit tests for DependencyLicenseChecker
# These tests run inside Docker via the GitHub Actions workflow.
# TDD approach: each Describe block follows red-green-refactor.

# In Pester 5.x, dot-sourcing must happen inside BeforeAll so functions are
# available during the Run phase (not just Discovery).
BeforeAll {
    . (Join-Path $PSScriptRoot ".." "LicenseCheckerLib.ps1")
}

Describe "Get-Dependencies" {
    # RED: This test fails until Get-Dependencies is implemented.
    It "parses package.json and returns a list of dependencies" {
        $manifestPath = Join-Path $PSScriptRoot ".." "fixtures" "package.json"
        $deps = Get-Dependencies -ManifestPath $manifestPath
        $deps.Count | Should -Be 4
    }

    It "extracts correct dependency names" {
        $manifestPath = Join-Path $PSScriptRoot ".." "fixtures" "package.json"
        $deps = Get-Dependencies -ManifestPath $manifestPath
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain "lodash"
        $names | Should -Contain "left-pad"
        $names | Should -Contain "my-custom-lib"
        $names | Should -Contain "express"
    }

    It "extracts correct dependency versions" {
        $manifestPath = Join-Path $PSScriptRoot ".." "fixtures" "package.json"
        $deps = Get-Dependencies -ManifestPath $manifestPath
        $lodash = $deps | Where-Object { $_.Name -eq "lodash" }
        $lodash.Version | Should -Be "4.17.21"
    }

    It "throws a meaningful error for missing manifest" {
        { Get-Dependencies -ManifestPath "./nonexistent.json" } | Should -Throw "*not found*"
    }
}

Describe "Get-LicenseFromMockData" {
    # RED: Fails until Get-LicenseFromMockData is implemented.
    It "returns the license for a known package" {
        $mockLicenses = @{ "lodash" = "MIT"; "left-pad" = "GPL-3.0" }
        $license = Get-LicenseFromMockData -PackageName "lodash" -MockLicenses $mockLicenses
        $license | Should -Be "MIT"
    }

    It "returns null for an unknown package" {
        $mockLicenses = @{ "lodash" = "MIT" }
        $license = Get-LicenseFromMockData -PackageName "unknown-pkg" -MockLicenses $mockLicenses
        $license | Should -BeNullOrEmpty
    }
}

Describe "Get-ComplianceStatus" {
    # RED: Fails until Get-ComplianceStatus is implemented.
    Context "with standard license config" {
        BeforeAll {
            $script:config = [PSCustomObject]@{
                allowedLicenses = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
                deniedLicenses  = @("GPL-2.0", "GPL-3.0", "LGPL-2.0", "LGPL-3.0", "AGPL-3.0")
            }
        }

        It "returns APPROVED for an allowed license" {
            $status = Get-ComplianceStatus -License "MIT" -Config $script:config
            $status | Should -Be "APPROVED"
        }

        It "returns APPROVED for Apache-2.0" {
            $status = Get-ComplianceStatus -License "Apache-2.0" -Config $script:config
            $status | Should -Be "APPROVED"
        }

        It "returns DENIED for a denied license" {
            $status = Get-ComplianceStatus -License "GPL-3.0" -Config $script:config
            $status | Should -Be "DENIED"
        }

        It "returns UNKNOWN for a license not in either list" {
            $status = Get-ComplianceStatus -License "CUSTOM-LIC" -Config $script:config
            $status | Should -Be "UNKNOWN"
        }

        It "returns UNKNOWN for a null/empty license" {
            $status = Get-ComplianceStatus -License $null -Config $script:config
            $status | Should -Be "UNKNOWN"
        }
    }
}

Describe "Get-ComplianceReport" {
    # RED: Fails until Get-ComplianceReport is implemented.
    BeforeAll {
        $script:manifestPath   = Join-Path $PSScriptRoot ".." "fixtures" "package.json"
        $script:configPath     = Join-Path $PSScriptRoot ".." "config" "license-config.json"
        $script:mockLicensePath = Join-Path $PSScriptRoot ".." "fixtures" "mock-licenses.json"
    }

    It "returns one report entry per dependency" {
        $report = Get-ComplianceReport -ManifestPath $script:manifestPath `
            -ConfigPath $script:configPath -MockLicensesPath $script:mockLicensePath
        $report.Count | Should -Be 4
    }

    It "marks MIT-licensed packages as APPROVED" {
        $report = Get-ComplianceReport -ManifestPath $script:manifestPath `
            -ConfigPath $script:configPath -MockLicensesPath $script:mockLicensePath
        $lodash = $report | Where-Object { $_.Name -eq "lodash" }
        $lodash.Status | Should -Be "APPROVED"
        $lodash.License | Should -Be "MIT"
    }

    It "marks GPL-licensed packages as DENIED" {
        $report = Get-ComplianceReport -ManifestPath $script:manifestPath `
            -ConfigPath $script:configPath -MockLicensesPath $script:mockLicensePath
        $leftPad = $report | Where-Object { $_.Name -eq "left-pad" }
        $leftPad.Status | Should -Be "DENIED"
        $leftPad.License | Should -Be "GPL-3.0"
    }

    It "marks packages with unknown licenses as UNKNOWN" {
        $report = Get-ComplianceReport -ManifestPath $script:manifestPath `
            -ConfigPath $script:configPath -MockLicensesPath $script:mockLicensePath
        $custom = $report | Where-Object { $_.Name -eq "my-custom-lib" }
        $custom.Status | Should -Be "UNKNOWN"
        $custom.License | Should -Be "CUSTOM-LIC"
    }

    It "report entries include Name, Version, License, and Status fields" {
        $report = Get-ComplianceReport -ManifestPath $script:manifestPath `
            -ConfigPath $script:configPath -MockLicensesPath $script:mockLicensePath
        $entry = $report[0]
        $entry.PSObject.Properties.Name | Should -Contain "Name"
        $entry.PSObject.Properties.Name | Should -Contain "Version"
        $entry.PSObject.Properties.Name | Should -Contain "License"
        $entry.PSObject.Properties.Name | Should -Contain "Status"
    }
}

Describe "Format-ComplianceReport" {
    # RED: Fails until Format-ComplianceReport is implemented.
    BeforeAll {
        $script:sampleReport = @(
            [PSCustomObject]@{ Name = "lodash"; Version = "4.17.21"; License = "MIT";        Status = "APPROVED" }
            [PSCustomObject]@{ Name = "left-pad"; Version = "1.3.0";  License = "GPL-3.0";   Status = "DENIED" }
            [PSCustomObject]@{ Name = "my-custom-lib"; Version = "2.0.0"; License = "CUSTOM-LIC"; Status = "UNKNOWN" }
            [PSCustomObject]@{ Name = "express"; Version = "4.18.2"; License = "MIT";        Status = "APPROVED" }
        )
    }

    It "produces output containing each package with its status" {
        $output = Format-ComplianceReport -Report $script:sampleReport
        $output | Should -Match "lodash@4\.17\.21: MIT \[APPROVED\]"
        $output | Should -Match "left-pad@1\.3\.0: GPL-3\.0 \[DENIED\]"
        $output | Should -Match "my-custom-lib@2\.0\.0: CUSTOM-LIC \[UNKNOWN\]"
        $output | Should -Match "express@4\.18\.2: MIT \[APPROVED\]"
    }

    It "includes a summary line with correct counts" {
        $output = Format-ComplianceReport -Report $script:sampleReport
        $output | Should -Match "Summary: 4 total, 2 approved, 1 denied, 1 unknown"
    }

    It "includes a FAILED status when there are denied licenses" {
        $output = Format-ComplianceReport -Report $script:sampleReport
        $output | Should -Match "Status: FAILED"
    }

    It "includes a PASSED status when there are no denied licenses" {
        $cleanReport = @(
            [PSCustomObject]@{ Name = "lodash"; Version = "4.17.21"; License = "MIT"; Status = "APPROVED" }
        )
        $output = Format-ComplianceReport -Report $cleanReport
        $output | Should -Match "Status: PASSED"
    }
}
