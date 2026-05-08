BeforeAll {
    Import-Module "$PSScriptRoot/DependencyLicenseChecker.psm1" -Force
}

Describe 'Get-MockLicense' {
    It 'returns MIT for express' {
        Get-MockLicense -PackageName 'express' | Should -Be 'MIT'
    }
    It 'returns Apache-2.0 for requests' {
        Get-MockLicense -PackageName 'requests' | Should -Be 'Apache-2.0'
    }
    It 'returns GPL-3.0 for gpl-lib' {
        Get-MockLicense -PackageName 'gpl-lib' | Should -Be 'GPL-3.0'
    }
    It 'returns null for unknown packages' {
        Get-MockLicense -PackageName 'totally-fake-package' | Should -BeNullOrEmpty
    }
    It 'is case-insensitive' {
        Get-MockLicense -PackageName 'Express' | Should -Be 'MIT'
    }
    It 'accepts a custom lookup table' {
        $table = @{ 'custom-pkg' = 'CUSTOM-1.0' }
        Get-MockLicense -PackageName 'custom-pkg' -LookupTable $table | Should -Be 'CUSTOM-1.0'
    }
}

Describe 'Read-PackageJson' {
    It 'parses dependencies and devDependencies from package.json' {
        $deps = Read-PackageJson -Path "$PSScriptRoot/fixtures/package.json"
        $deps.Count | Should -Be 4
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain 'express'
        $names | Should -Contain 'lodash'
        $names | Should -Contain 'gpl-lib'
        $names | Should -Contain 'jest'
    }
    It 'returns empty array for package.json with no dependencies' {
        $deps = Read-PackageJson -Path "$PSScriptRoot/fixtures/empty-package.json"
        $deps.Count | Should -Be 0
    }
    It 'throws for missing file' {
        { Read-PackageJson -Path "$PSScriptRoot/fixtures/nonexistent.json" } | Should -Throw '*Manifest not found*'
    }
}

Describe 'Read-RequirementsTxt' {
    It 'parses requirements.txt with versions and comments' {
        $deps = Read-RequirementsTxt -Path "$PSScriptRoot/fixtures/requirements.txt"
        $deps.Count | Should -Be 5
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain 'flask'
        $names | Should -Contain 'requests'
        $names | Should -Contain 'numpy'
        $names | Should -Contain 'pandas'
        $names | Should -Contain 'gpl-lib'
    }
    It 'extracts correct versions' {
        $deps = Read-RequirementsTxt -Path "$PSScriptRoot/fixtures/requirements.txt"
        $flask = $deps | Where-Object { $_.Name -eq 'flask' }
        $flask.Version | Should -Be '==2.3.0'
        $pandas = $deps | Where-Object { $_.Name -eq 'pandas' }
        $pandas.Version | Should -Be '*'
    }
    It 'throws for missing file' {
        { Read-RequirementsTxt -Path "$PSScriptRoot/fixtures/nonexistent.txt" } | Should -Throw '*Manifest not found*'
    }
}

Describe 'Read-DependencyManifest' {
    It 'dispatches to package.json parser' {
        $deps = Read-DependencyManifest -Path "$PSScriptRoot/fixtures/package.json"
        $deps.Count | Should -Be 4
    }
    It 'dispatches to requirements.txt parser' {
        $deps = Read-DependencyManifest -Path "$PSScriptRoot/fixtures/requirements.txt"
        $deps.Count | Should -Be 5
    }
    It 'throws for unsupported format' {
        { Read-DependencyManifest -Path "$PSScriptRoot/fixtures/Gemfile.rb" } | Should -Throw '*Unsupported manifest*'
    }
}

Describe 'Read-LicenseConfig' {
    It 'reads allow and deny lists from config' {
        $config = Read-LicenseConfig -Path "$PSScriptRoot/fixtures/license-config.json"
        $config.AllowList | Should -Contain 'MIT'
        $config.AllowList | Should -Contain 'Apache-2.0'
        $config.DenyList | Should -Contain 'GPL-3.0'
        $config.DenyList | Should -Contain 'AGPL-3.0'
    }
    It 'throws for missing config file' {
        { Read-LicenseConfig -Path "$PSScriptRoot/fixtures/nonexistent-config.json" } | Should -Throw '*Config file not found*'
    }
}

Describe 'Get-LicenseStatus' {
    BeforeAll {
        $script:config = @{
            AllowList = @('MIT', 'Apache-2.0', 'ISC')
            DenyList  = @('GPL-3.0', 'AGPL-3.0')
        }
    }
    It 'returns approved for allowed licenses' {
        Get-LicenseStatus -License 'MIT' -Config $script:config | Should -Be 'approved'
    }
    It 'returns denied for denied licenses' {
        Get-LicenseStatus -License 'GPL-3.0' -Config $script:config | Should -Be 'denied'
    }
    It 'returns unknown for unlisted licenses' {
        Get-LicenseStatus -License 'WTFPL' -Config $script:config | Should -Be 'unknown'
    }
    It 'is case-insensitive' {
        Get-LicenseStatus -License 'mit' -Config $script:config | Should -Be 'approved'
        Get-LicenseStatus -License 'gpl-3.0' -Config $script:config | Should -Be 'denied'
    }
    It 'deny list takes precedence over allow list' {
        $bothConfig = @{
            AllowList = @('GPL-3.0')
            DenyList  = @('GPL-3.0')
        }
        Get-LicenseStatus -License 'GPL-3.0' -Config $bothConfig | Should -Be 'denied'
    }
}

Describe 'New-ComplianceReport' {
    BeforeAll {
        $script:config = @{
            AllowList = @('MIT', 'Apache-2.0', 'ISC')
            DenyList  = @('GPL-3.0', 'AGPL-3.0')
        }
    }
    It 'generates report with correct statuses for package.json deps' {
        $deps = Read-PackageJson -Path "$PSScriptRoot/fixtures/package.json"
        $report = New-ComplianceReport -Dependencies $deps -Config $script:config
        $report.Count | Should -Be 4

        $express = $report | Where-Object { $_.Name -eq 'express' }
        $express.License | Should -Be 'MIT'
        $express.Status | Should -Be 'approved'

        $gpl = $report | Where-Object { $_.Name -eq 'gpl-lib' }
        $gpl.License | Should -Be 'GPL-3.0'
        $gpl.Status | Should -Be 'denied'
    }
    It 'marks unknown-license packages as unknown' {
        $deps = @(@{ Name = 'totally-unknown-pkg'; Version = '1.0.0' })
        $report = New-ComplianceReport -Dependencies $deps -Config $script:config
        $report[0].License | Should -Be 'UNKNOWN'
        $report[0].Status | Should -Be 'unknown'
    }
    It 'uses custom lookup table when provided' {
        $table = @{ 'my-pkg' = 'MIT' }
        $deps = @(@{ Name = 'my-pkg'; Version = '2.0.0' })
        $report = New-ComplianceReport -Dependencies $deps -Config $script:config -LookupTable $table
        $report[0].License | Should -Be 'MIT'
        $report[0].Status | Should -Be 'approved'
    }
}

Describe 'Format-ComplianceReport' {
    It 'produces formatted output with summary and sections' {
        $report = @(
            [PSCustomObject]@{ Name = 'express'; Version = '^4.18.0'; License = 'MIT'; Status = 'approved' },
            [PSCustomObject]@{ Name = 'gpl-lib'; Version = '^1.0.0'; License = 'GPL-3.0'; Status = 'denied' },
            [PSCustomObject]@{ Name = 'mystery'; Version = '1.0.0'; License = 'UNKNOWN'; Status = 'unknown' }
        )
        $output = Format-ComplianceReport -Report $report
        $output | Should -Match 'DEPENDENCY LICENSE COMPLIANCE REPORT'
        $output | Should -Match 'Approved: 1'
        $output | Should -Match 'Denied:   1'
        $output | Should -Match 'Unknown:  1'
        $output | Should -Match '\[DENIED\].*gpl-lib'
        $output | Should -Match '\[APPROVED\].*express'
        $output | Should -Match '\[UNKNOWN\].*mystery'
        $output | Should -Match 'RESULT: FAIL'
    }
    It 'shows PASS when no denied dependencies' {
        $report = @(
            [PSCustomObject]@{ Name = 'express'; Version = '^4.18.0'; License = 'MIT'; Status = 'approved' }
        )
        $output = Format-ComplianceReport -Report $report
        $output | Should -Match 'RESULT: PASS'
    }
}

Describe 'Invoke-LicenseCheck (integration)' {
    It 'runs full check on package.json and returns report objects' {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $report.Count | Should -Be 4
        $denied = @($report | Where-Object { $_.Status -eq 'denied' })
        $denied.Count | Should -Be 1
        $denied[0].Name | Should -Be 'gpl-lib'
    }
    It 'runs full check on requirements.txt' {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$PSScriptRoot/fixtures/requirements.txt" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $report.Count | Should -Be 5
        $approved = @($report | Where-Object { $_.Status -eq 'approved' })
        $approved.Count | Should -BeGreaterOrEqual 3
    }
    It 'returns empty for package with no dependencies' {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$PSScriptRoot/fixtures/empty-package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $report.Count | Should -Be 0
    }
    It 'all-approved project passes with no denied' {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$PSScriptRoot/fixtures/all-approved-package.json" `
            -ConfigPath "$PSScriptRoot/fixtures/all-approved-config.json"
        $denied = @($report | Where-Object { $_.Status -eq 'denied' })
        $denied.Count | Should -Be 0
        $approved = @($report | Where-Object { $_.Status -eq 'approved' })
        $approved.Count | Should -Be 3
    }
}
