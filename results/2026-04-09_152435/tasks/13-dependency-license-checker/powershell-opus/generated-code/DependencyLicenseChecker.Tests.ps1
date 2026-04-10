# DependencyLicenseChecker.Tests.ps1
# TDD tests for the dependency license checker module.
# Each Describe block tests a specific function following red/green/refactor.

BeforeAll {
    Import-Module "$PSScriptRoot/DependencyLicenseChecker.psm1" -Force
}

# --- Test 1: Parse package.json dependencies ---
Describe 'Get-PackageJsonDependencies' {
    It 'should extract dependencies and devDependencies from package.json' {
        $deps = Get-PackageJsonDependencies -Path "$PSScriptRoot/fixtures/package.json"
        $deps.Count | Should -Be 3
        $deps[0].Name | Should -Be 'express'
        $deps[0].Version | Should -Be '^4.18.0'
        $deps[1].Name | Should -Be 'lodash'
        $deps[2].Name | Should -Be 'jest'
        $deps[2].Source | Should -Be 'devDependencies'
    }

    It 'should throw for missing file' {
        { Get-PackageJsonDependencies -Path '/nonexistent/package.json' } | Should -Throw 'File not found*'
    }
}

# --- Test 2: Parse requirements.txt dependencies ---
Describe 'Get-RequirementsTxtDependencies' {
    It 'should extract dependencies from requirements.txt' {
        $deps = Get-RequirementsTxtDependencies -Path "$PSScriptRoot/fixtures/requirements.txt"
        $deps.Count | Should -Be 4
        $deps[0].Name | Should -Be 'requests'
        $deps[0].Version | Should -Be '2.31.0'
        $deps[1].Name | Should -Be 'flask'
        $deps[1].Version | Should -Be '2.3.0'
        $deps[2].Name | Should -Be 'numpy'
        $deps[3].Name | Should -Be 'pandas'
        $deps[3].Version | Should -Be '*'
    }

    It 'should skip comments and blank lines' {
        $deps = Get-RequirementsTxtDependencies -Path "$PSScriptRoot/fixtures/requirements.txt"
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Not -Contain '#'
    }
}

# --- Test 3: Unified Get-Dependencies dispatcher ---
Describe 'Get-Dependencies' {
    It 'should dispatch to package.json parser' {
        $deps = Get-Dependencies -Path "$PSScriptRoot/fixtures/package.json"
        $deps.Count | Should -Be 3
    }

    It 'should dispatch to requirements.txt parser' {
        $deps = Get-Dependencies -Path "$PSScriptRoot/fixtures/requirements.txt"
        $deps.Count | Should -Be 4
    }

    It 'should throw for unsupported formats' {
        # Create a temp file with unsupported name
        $tmpDir = [System.IO.Path]::GetTempPath()
        $tmpFile = Join-Path $tmpDir 'Gemfile'
        Set-Content -Path $tmpFile -Value 'gem "rails"'
        { Get-Dependencies -Path $tmpFile } | Should -Throw 'Unsupported manifest format*'
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }
}

# --- Test 4: Config parsing ---
Describe 'Get-LicenseConfig' {
    It 'should load allowed and denied license lists' {
        $config = Get-LicenseConfig -Path "$PSScriptRoot/fixtures/license-config.json"
        $config.allowedLicenses | Should -Contain 'MIT'
        $config.allowedLicenses | Should -Contain 'Apache-2.0'
        $config.deniedLicenses | Should -Contain 'GPL-3.0'
    }

    It 'should throw for missing config file' {
        { Get-LicenseConfig -Path '/nonexistent/config.json' } | Should -Throw 'Config file not found*'
    }

    It 'should throw if allowedLicenses is missing' {
        $tmpDir = [System.IO.Path]::GetTempPath()
        $tmpFile = Join-Path $tmpDir 'bad-config.json'
        Set-Content -Path $tmpFile -Value '{"deniedLicenses": ["GPL-3.0"]}'
        { Get-LicenseConfig -Path $tmpFile } | Should -Throw '*allowedLicenses*'
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }
}

# --- Test 5: License lookup with mock data ---
Describe 'Get-DependencyLicense' {
    It 'should return the license from the lookup table' {
        $lookup = @{ 'express' = 'MIT'; 'lodash' = 'MIT' }
        Get-DependencyLicense -DependencyName 'express' -LookupTable $lookup | Should -Be 'MIT'
    }

    It 'should return null for unknown dependencies' {
        $lookup = @{ 'express' = 'MIT' }
        Get-DependencyLicense -DependencyName 'unknown-pkg' -LookupTable $lookup | Should -BeNullOrEmpty
    }
}

# --- Test 6: License status classification ---
Describe 'Get-LicenseStatus' {
    BeforeAll {
        $allowed = @('MIT', 'Apache-2.0')
        $denied = @('GPL-3.0', 'AGPL-3.0')
    }

    It 'should return approved for allowed licenses' {
        Get-LicenseStatus -License 'MIT' -AllowedLicenses $allowed -DeniedLicenses $denied | Should -Be 'approved'
    }

    It 'should return denied for denied licenses' {
        Get-LicenseStatus -License 'GPL-3.0' -AllowedLicenses $allowed -DeniedLicenses $denied | Should -Be 'denied'
    }

    It 'should return unknown for licenses not in either list' {
        Get-LicenseStatus -License 'WTFPL' -AllowedLicenses $allowed -DeniedLicenses $denied | Should -Be 'unknown'
    }

    It 'should return unknown for null license' {
        Get-LicenseStatus -License $null -AllowedLicenses $allowed -DeniedLicenses $denied | Should -Be 'unknown'
    }

    It 'should prioritize denied over allowed when license is in both lists' {
        $bothAllowed = @('MIT', 'GPL-3.0')
        $bothDenied = @('GPL-3.0')
        Get-LicenseStatus -License 'GPL-3.0' -AllowedLicenses $bothAllowed -DeniedLicenses $bothDenied | Should -Be 'denied'
    }
}

# --- Test 7: Full compliance report generation ---
Describe 'New-ComplianceReport' {
    It 'should generate a report with all approved dependencies' {
        $report = New-ComplianceReport `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json"

        $report.Summary.Total | Should -Be 3
        $report.Summary.Approved | Should -Be 3
        $report.Summary.Denied | Should -Be 0
        $report.Summary.Unknown | Should -Be 0
        $report.HasDenied | Should -BeFalse
    }

    It 'should flag denied licenses in the report' {
        $report = New-ComplianceReport `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/denied-config.json"

        $report.Summary.Denied | Should -Be 1
        $report.HasDenied | Should -BeTrue
        $denied = $report.Details | Where-Object { $_.Status -eq 'denied' }
        $denied.Name | Should -Be 'lodash'
        $denied.License | Should -Be 'GPL-3.0'
    }

    It 'should mark unknown when dependency not in lookup' {
        # Override lookup to omit jest
        $lookup = @{ 'express' = 'MIT'; 'lodash' = 'MIT' }
        $report = New-ComplianceReport `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json" `
            -LookupOverride $lookup

        $report.Summary.Unknown | Should -Be 1
        $unknown = $report.Details | Where-Object { $_.Status -eq 'unknown' }
        $unknown.Name | Should -Be 'jest'
    }

    It 'should work with requirements.txt' {
        $report = New-ComplianceReport `
            -ManifestPath "$PSScriptRoot/fixtures/requirements.txt" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json"

        $report.Summary.Total | Should -Be 4
        $report.Summary.Approved | Should -Be 4
    }
}

# --- Test 8: Report formatting ---
Describe 'Format-ComplianceReport' {
    It 'should produce readable text output with summary and details' {
        $report = New-ComplianceReport `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json"

        $text = Format-ComplianceReport -Report $report
        $text | Should -Match 'Dependency License Compliance Report'
        $text | Should -Match 'Total dependencies: 3'
        $text | Should -Match 'Approved: 3'
        $text | Should -Match 'express'
    }

    It 'should include warning when denied licenses exist' {
        $report = New-ComplianceReport `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/denied-config.json"

        $text = Format-ComplianceReport -Report $report
        $text | Should -Match 'WARNING: Denied licenses found'
    }
}
