# Pester tests for DependencyLicenseChecker
# TDD approach: each Describe block represents a feature built test-first

BeforeAll {
    . $PSScriptRoot/DependencyLicenseChecker.Functions.ps1
}

Describe "Parse-PackageJson" {
    It "parses production dependencies from package.json" {
        $result = Parse-PackageJson -Path "$PSScriptRoot/fixtures/package.json"
        $prodDeps = $result | Where-Object { $_.Type -eq "production" }
        $prodDeps.Count | Should -Be 3
    }

    It "extracts dependency names correctly" {
        $result = Parse-PackageJson -Path "$PSScriptRoot/fixtures/package.json"
        $names = $result | ForEach-Object { $_.Name }
        $names | Should -Contain "express"
        $names | Should -Contain "lodash"
        $names | Should -Contain "axios"
    }

    It "parses devDependencies" {
        $result = Parse-PackageJson -Path "$PSScriptRoot/fixtures/package.json"
        $devDeps = @($result | Where-Object { $_.Type -eq "development" })
        $devDeps.Count | Should -Be 1
        $devDeps[0].Name | Should -Be "jest"
    }

    It "strips version prefixes" {
        $result = Parse-PackageJson -Path "$PSScriptRoot/fixtures/package.json"
        $express = $result | Where-Object { $_.Name -eq "express" }
        $express.Version | Should -Be "4.18.2"
    }

    It "throws on missing file" {
        { Parse-PackageJson -Path "/nonexistent/package.json" } | Should -Throw "*not found*"
    }
}

Describe "Parse-RequirementsTxt" {
    It "parses pinned dependencies" {
        $result = Parse-RequirementsTxt -Path "$PSScriptRoot/fixtures/requirements.txt"
        $result.Count | Should -Be 4
    }

    It "extracts names and versions correctly" {
        $result = Parse-RequirementsTxt -Path "$PSScriptRoot/fixtures/requirements.txt"
        $flask = $result | Where-Object { $_.Name -eq "flask" }
        $flask.Version | Should -Be "3.0.0"
    }

    It "handles hyphenated package names" {
        $result = Parse-RequirementsTxt -Path "$PSScriptRoot/fixtures/requirements.txt"
        $gpl = $result | Where-Object { $_.Name -eq "gpl-library" }
        $gpl | Should -Not -BeNullOrEmpty
        $gpl.Version | Should -Be "1.0.0"
    }

    It "throws on missing file" {
        { Parse-RequirementsTxt -Path "/nonexistent/requirements.txt" } | Should -Throw "*not found*"
    }
}

Describe "Read-LicenseConfig" {
    It "loads allowed and denied license lists" {
        $config = Read-LicenseConfig -Path "$PSScriptRoot/fixtures/license-config.json"
        $config.AllowedLicenses | Should -Contain "MIT"
        $config.DeniedLicenses | Should -Contain "GPL-3.0"
    }

    It "loads the license database" {
        $config = Read-LicenseConfig -Path "$PSScriptRoot/fixtures/license-config.json"
        $config.LicenseDatabase["express"] | Should -Be "MIT"
        $config.LicenseDatabase["gpl-library"] | Should -Be "GPL-3.0"
    }

    It "throws on missing config" {
        { Read-LicenseConfig -Path "/nonexistent/config.json" } | Should -Throw "*not found*"
    }
}

Describe "Get-LicenseForDependency" {
    It "returns the license from the database" {
        $db = @{ "express" = "MIT"; "numpy" = "BSD-3-Clause" }
        Get-LicenseForDependency -DependencyName "express" -LicenseDatabase $db | Should -Be "MIT"
    }

    It "returns null for unknown dependencies" {
        $db = @{ "express" = "MIT" }
        Get-LicenseForDependency -DependencyName "unknown-pkg" -LicenseDatabase $db | Should -BeNullOrEmpty
    }
}

Describe "Get-LicenseStatus" {
    It "returns approved for allowed licenses" {
        $result = Get-LicenseStatus -License "MIT" -AllowedLicenses @("MIT", "Apache-2.0") -DeniedLicenses @("GPL-3.0")
        $result | Should -Be "approved"
    }

    It "returns denied for denied licenses" {
        $result = Get-LicenseStatus -License "GPL-3.0" -AllowedLicenses @("MIT") -DeniedLicenses @("GPL-3.0", "AGPL-3.0")
        $result | Should -Be "denied"
    }

    It "returns unknown for unrecognized licenses" {
        $result = Get-LicenseStatus -License "Artistic-2.0" -AllowedLicenses @("MIT") -DeniedLicenses @("GPL-3.0")
        $result | Should -Be "unknown"
    }

    It "returns unknown for null license" {
        $result = Get-LicenseStatus -License $null -AllowedLicenses @("MIT") -DeniedLicenses @("GPL-3.0")
        $result | Should -Be "unknown"
    }
}

Describe "Invoke-LicenseCheck" {
    It "checks package.json dependencies against config" {
        $results = Invoke-LicenseCheck -ManifestPath "$PSScriptRoot/fixtures/package.json" -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $results.Count | Should -Be 4
    }

    It "correctly identifies approved dependencies" {
        $results = Invoke-LicenseCheck -ManifestPath "$PSScriptRoot/fixtures/package.json" -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $approved = @($results | Where-Object { $_.Status -eq "approved" })
        $approved.Count | Should -Be 4
    }

    It "correctly identifies denied dependencies in requirements.txt" {
        $results = Invoke-LicenseCheck -ManifestPath "$PSScriptRoot/fixtures/requirements.txt" -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $denied = @($results | Where-Object { $_.Status -eq "denied" })
        $denied.Count | Should -Be 1
        $denied[0].Name | Should -Be "gpl-library"
    }

    It "throws on unsupported manifest format" {
        # Create a temp file with unsupported name
        $tempFile = Join-Path $TestDrive "Gemfile"
        Set-Content -Path $tempFile -Value "gem 'rails'"
        { Invoke-LicenseCheck -ManifestPath $tempFile -ConfigPath "$PSScriptRoot/fixtures/license-config.json" } | Should -Throw "*Unsupported*"
    }
}

Describe "Format-ComplianceReport" {
    It "generates a report with correct counts" {
        $results = @(
            @{ Name = "express"; Version = "4.18.2"; Type = "production"; License = "MIT"; Status = "approved" },
            @{ Name = "gpl-lib"; Version = "1.0.0"; Type = "production"; License = "GPL-3.0"; Status = "denied" }
        )
        $report = Format-ComplianceReport -Results $results -ManifestPath "package.json"
        $report | Should -Match "Total dependencies: 2"
        $report | Should -Match "Approved: 1"
        $report | Should -Match "Denied: 1"
    }

    It "shows FAIL when denied dependencies exist" {
        $results = @(
            @{ Name = "gpl-lib"; Version = "1.0.0"; Type = "production"; License = "GPL-3.0"; Status = "denied" }
        )
        $report = Format-ComplianceReport -Results $results -ManifestPath "test.json"
        $report | Should -Match "RESULT: FAIL"
    }

    It "shows PASS when all approved" {
        $results = @(
            @{ Name = "express"; Version = "4.18.2"; Type = "production"; License = "MIT"; Status = "approved" }
        )
        $report = Format-ComplianceReport -Results $results -ManifestPath "test.json"
        $report | Should -Match "RESULT: PASS"
    }

    It "shows WARN when unknown licenses present but no denied" {
        $results = @(
            @{ Name = "mystery"; Version = "1.0.0"; Type = "production"; License = "UNKNOWN"; Status = "unknown" }
        )
        $report = Format-ComplianceReport -Results $results -ManifestPath "test.json"
        $report | Should -Match "RESULT: WARN"
    }

    It "includes dependency details with status tags" {
        $results = @(
            @{ Name = "express"; Version = "4.18.2"; Type = "production"; License = "MIT"; Status = "approved" }
        )
        $report = Format-ComplianceReport -Results $results -ManifestPath "test.json"
        $report | Should -Match "\[APPROVED\] express@4.18.2"
    }
}

Describe "End-to-end integration" {
    It "produces complete report for package.json with all approved" {
        $results = Invoke-LicenseCheck -ManifestPath "$PSScriptRoot/fixtures/package.json" -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $report = Format-ComplianceReport -Results $results -ManifestPath "$PSScriptRoot/fixtures/package.json"
        $report | Should -Match "RESULT: PASS"
        $report | Should -Match "\[APPROVED\] express@4.18.2"
        $report | Should -Match "\[APPROVED\] lodash@4.17.21"
    }

    It "produces complete report for requirements.txt with denied deps" {
        $results = Invoke-LicenseCheck -ManifestPath "$PSScriptRoot/fixtures/requirements.txt" -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $report = Format-ComplianceReport -Results $results -ManifestPath "$PSScriptRoot/fixtures/requirements.txt"
        $report | Should -Match "RESULT: FAIL"
        $report | Should -Match "\[DENIED\] gpl-library@1.0.0"
        $report | Should -Match "\[APPROVED\] flask@3.0.0"
    }
}
