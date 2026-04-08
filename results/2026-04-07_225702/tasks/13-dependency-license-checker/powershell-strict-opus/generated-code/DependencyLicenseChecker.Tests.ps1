Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/DependencyLicenseChecker.ps1"
}

Describe 'Parse-PackageJson' {
    It 'Should extract dependencies with versions from package.json' {
        # Arrange
        [string]$json = @'
{
    "name": "my-app",
    "version": "1.0.0",
    "dependencies": {
        "express": "^4.18.0",
        "lodash": "~4.17.21"
    },
    "devDependencies": {
        "jest": "^29.0.0"
    }
}
'@
        [string]$tempFile = Join-Path $TestDrive 'package.json'
        Set-Content -Path $tempFile -Value $json

        # Act
        [array]$result = Parse-DependencyManifest -Path $tempFile

        # Assert
        $result.Count | Should -Be 3
        $result[0].Name | Should -Be 'express'
        $result[0].Version | Should -Be '^4.18.0'
        $result[1].Name | Should -Be 'lodash'
        $result[2].Name | Should -Be 'jest'
    }
}

Describe 'Parse-RequirementsTxt' {
    It 'Should extract dependencies with versions from requirements.txt' {
        # Arrange
        [string]$content = @'
flask==2.3.0
requests>=2.28.0
numpy==1.24.0
# this is a comment
pytest>=7.0.0
'@
        [string]$tempFile = Join-Path $TestDrive 'requirements.txt'
        Set-Content -Path $tempFile -Value $content

        # Act
        [array]$result = Parse-DependencyManifest -Path $tempFile

        # Assert
        $result.Count | Should -Be 4
        $result[0].Name | Should -Be 'flask'
        $result[0].Version | Should -Be '==2.3.0'
        $result[1].Name | Should -Be 'requests'
        $result[1].Version | Should -Be '>=2.28.0'
    }

    It 'Should handle lines without version specifiers' {
        # Arrange
        [string]$content = @'
flask
requests>=2.28.0
'@
        [string]$tempFile = Join-Path $TestDrive 'requirements.txt'
        Set-Content -Path $tempFile -Value $content

        # Act
        [array]$result = Parse-DependencyManifest -Path $tempFile

        # Assert
        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'flask'
        $result[0].Version | Should -Be '*'
    }
}

Describe 'Parse-DependencyManifest error handling' {
    It 'Should throw for missing file' {
        { Parse-DependencyManifest -Path '/nonexistent/package.json' } | Should -Throw '*not found*'
    }

    It 'Should throw for unsupported format' {
        [string]$tempFile = Join-Path $TestDrive 'Gemfile'
        Set-Content -Path $tempFile -Value 'gem "rails"'
        { Parse-DependencyManifest -Path $tempFile } | Should -Throw '*Unsupported*'
    }
}

Describe 'Get-DependencyLicense (mock lookup)' {
    It 'Should return license for known packages' {
        # The mock database maps package names to licenses
        [hashtable]$mockDb = @{
            'express'  = 'MIT'
            'lodash'   = 'MIT'
            'react'    = 'MIT'
            'flask'    = 'BSD-3-Clause'
            'numpy'    = 'BSD-3-Clause'
            'requests' = 'Apache-2.0'
        }

        [string]$license = Get-DependencyLicense -Name 'express' -LicenseDatabase $mockDb
        $license | Should -Be 'MIT'
    }

    It 'Should return UNKNOWN for packages not in the database' {
        [hashtable]$mockDb = @{ 'express' = 'MIT' }
        [string]$license = Get-DependencyLicense -Name 'unknown-pkg' -LicenseDatabase $mockDb
        $license | Should -Be 'UNKNOWN'
    }
}

Describe 'Test-LicenseCompliance' {
    BeforeEach {
        # Config: allow MIT and Apache-2.0, deny GPL-3.0
        [hashtable]$script:config = @{
            AllowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause')
            DenyList  = [string[]]@('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'Should mark allowed licenses as Approved' {
        [string]$status = Test-LicenseCompliance -License 'MIT' -Config $script:config
        $status | Should -Be 'Approved'
    }

    It 'Should mark denied licenses as Denied' {
        [string]$status = Test-LicenseCompliance -License 'GPL-3.0' -Config $script:config
        $status | Should -Be 'Denied'
    }

    It 'Should mark unknown licenses as Unknown' {
        [string]$status = Test-LicenseCompliance -License 'UNKNOWN' -Config $script:config
        $status | Should -Be 'Unknown'
    }

    It 'Should mark licenses not in either list as Unknown' {
        [string]$status = Test-LicenseCompliance -License 'ISC' -Config $script:config
        $status | Should -Be 'Unknown'
    }
}

Describe 'New-ComplianceReport' {
    It 'Should generate a full compliance report from a manifest' {
        # Arrange: create a package.json fixture
        [string]$json = @'
{
    "name": "test-app",
    "dependencies": {
        "express": "^4.18.0",
        "lodash": "~4.17.21",
        "evil-gpl-lib": "1.0.0",
        "mystery-pkg": "2.0.0"
    }
}
'@
        [string]$tempFile = Join-Path $TestDrive 'package.json'
        Set-Content -Path $tempFile -Value $json

        [hashtable]$mockDb = @{
            'express'      = 'MIT'
            'lodash'       = 'MIT'
            'evil-gpl-lib' = 'GPL-3.0'
        }

        [hashtable]$config = @{
            AllowList = [string[]]@('MIT', 'Apache-2.0')
            DenyList  = [string[]]@('GPL-3.0', 'AGPL-3.0')
        }

        # Act
        [PSCustomObject]$report = New-ComplianceReport -ManifestPath $tempFile -LicenseDatabase $mockDb -Config $config

        # Assert: report has summary and entries
        $report.TotalDependencies | Should -Be 4
        $report.Approved | Should -Be 2
        $report.Denied | Should -Be 1
        $report.Unknown | Should -Be 1

        # Check individual entries
        [array]$entries = $report.Entries
        $entries.Count | Should -Be 4

        [PSCustomObject]$expressEntry = $entries | Where-Object { $_.Name -eq 'express' }
        $expressEntry.License | Should -Be 'MIT'
        $expressEntry.Status | Should -Be 'Approved'

        [PSCustomObject]$gplEntry = $entries | Where-Object { $_.Name -eq 'evil-gpl-lib' }
        $gplEntry.License | Should -Be 'GPL-3.0'
        $gplEntry.Status | Should -Be 'Denied'

        [PSCustomObject]$mysteryEntry = $entries | Where-Object { $_.Name -eq 'mystery-pkg' }
        $mysteryEntry.License | Should -Be 'UNKNOWN'
        $mysteryEntry.Status | Should -Be 'Unknown'
    }

    It 'Should work with requirements.txt' {
        # Arrange
        [string]$content = @'
flask==2.3.0
requests>=2.28.0
evil-gpl-pkg==1.0.0
'@
        [string]$tempFile = Join-Path $TestDrive 'requirements.txt'
        Set-Content -Path $tempFile -Value $content

        [hashtable]$mockDb = @{
            'flask'        = 'BSD-3-Clause'
            'requests'     = 'Apache-2.0'
            'evil-gpl-pkg' = 'GPL-3.0'
        }

        [hashtable]$config = @{
            AllowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause')
            DenyList  = [string[]]@('GPL-3.0')
        }

        # Act
        [PSCustomObject]$report = New-ComplianceReport -ManifestPath $tempFile -LicenseDatabase $mockDb -Config $config

        # Assert
        $report.TotalDependencies | Should -Be 3
        $report.Approved | Should -Be 2
        $report.Denied | Should -Be 1
        $report.Unknown | Should -Be 0
    }
}

Describe 'Format-ComplianceReport' {
    It 'Should produce human-readable text output' {
        # Arrange
        [PSCustomObject]$report = [PSCustomObject]@{
            ManifestPath      = [string]'/tmp/package.json'
            TotalDependencies = [int]3
            Approved          = [int]2
            Denied            = [int]1
            Unknown           = [int]0
            Entries           = [PSCustomObject[]]@(
                [PSCustomObject]@{ Name = 'express'; Version = '^4.18.0'; License = 'MIT'; Status = 'Approved' }
                [PSCustomObject]@{ Name = 'lodash'; Version = '~4.17.21'; License = 'MIT'; Status = 'Approved' }
                [PSCustomObject]@{ Name = 'bad-lib'; Version = '1.0.0'; License = 'GPL-3.0'; Status = 'Denied' }
            )
        }

        # Act
        [string]$output = Format-ComplianceReport -Report $report

        # Assert: key content is present in the output
        $output | Should -Match 'Compliance Report'
        $output | Should -Match 'express'
        $output | Should -Match 'Approved'
        $output | Should -Match 'bad-lib'
        $output | Should -Match 'Denied'
        $output | Should -Match 'Total: 3'
    }
}

Describe 'Get-DefaultLicenseDatabase' {
    It 'Should return a hashtable with common packages' {
        [hashtable]$db = Get-DefaultLicenseDatabase
        $db | Should -BeOfType [hashtable]
        $db.Count | Should -BeGreaterThan 0
        $db['express'] | Should -Be 'MIT'
    }
}

Describe 'Import-LicenseConfig' {
    It 'Should load config from a JSON file' {
        # Arrange
        [string]$configJson = @'
{
    "allowList": ["MIT", "Apache-2.0"],
    "denyList": ["GPL-3.0"]
}
'@
        [string]$tempFile = Join-Path $TestDrive 'license-config.json'
        Set-Content -Path $tempFile -Value $configJson

        # Act
        [hashtable]$config = Import-LicenseConfig -Path $tempFile

        # Assert
        $config['AllowList'] | Should -Contain 'MIT'
        $config['AllowList'] | Should -Contain 'Apache-2.0'
        $config['DenyList'] | Should -Contain 'GPL-3.0'
    }

    It 'Should throw for missing config file' {
        { Import-LicenseConfig -Path '/nonexistent/config.json' } | Should -Throw '*not found*'
    }
}

Describe 'End-to-end integration' {
    It 'Should produce a complete report using default database' {
        # Arrange
        [string]$json = @'
{
    "name": "integration-app",
    "dependencies": {
        "express": "^4.0.0",
        "axios": "^1.0.0",
        "typescript": "^5.0.0"
    }
}
'@
        [string]$manifestFile = Join-Path $TestDrive 'package.json'
        Set-Content -Path $manifestFile -Value $json

        [string]$configJson = @'
{
    "allowList": ["MIT", "Apache-2.0", "BSD-3-Clause"],
    "denyList": ["GPL-3.0", "AGPL-3.0"]
}
'@
        [string]$configFile = Join-Path $TestDrive 'license-config.json'
        Set-Content -Path $configFile -Value $configJson

        [hashtable]$db = Get-DefaultLicenseDatabase
        [hashtable]$config = Import-LicenseConfig -Path $configFile

        # Act
        [PSCustomObject]$report = New-ComplianceReport -ManifestPath $manifestFile -LicenseDatabase $db -Config $config
        [string]$formatted = Format-ComplianceReport -Report $report

        # Assert
        $report.TotalDependencies | Should -Be 3
        $report.Approved | Should -Be 3
        $report.Denied | Should -Be 0
        $formatted | Should -Match 'express'
        $formatted | Should -Match 'Approved'
    }
}
