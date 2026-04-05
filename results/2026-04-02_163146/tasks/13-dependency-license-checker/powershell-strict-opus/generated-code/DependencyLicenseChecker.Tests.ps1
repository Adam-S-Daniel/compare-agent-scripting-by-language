# DependencyLicenseChecker.Tests.ps1
# Pester tests for the Dependency License Checker module.
# Follows red/green TDD: each Describe block represents a TDD cycle where
# the test was written FIRST (red), then the implementation made it pass (green).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    Import-Module "$PSScriptRoot/DependencyLicenseChecker.psm1" -Force
}

# --------------------------------------------------------------------------
# TDD Cycle 1: Parse package.json — extract dependency names and versions
# RED:  Wrote this test first. No Read-DependencyManifest function existed.
# GREEN: Implemented Read-DependencyManifest for package.json parsing.
# --------------------------------------------------------------------------
Describe 'Read-DependencyManifest - package.json' {
    BeforeAll {
        [string]$script:fixturesPath = "$PSScriptRoot/fixtures"
    }

    It 'Should parse dependencies from a package.json file' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/package.json"
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 5  # 3 deps + 2 devDeps
    }

    It 'Should extract correct dependency names from package.json' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/package.json"
        [string[]]$names = $result | ForEach-Object { $_.Name }
        $names | Should -Contain 'express'
        $names | Should -Contain 'lodash'
        $names | Should -Contain 'axios'
        $names | Should -Contain 'jest'
        $names | Should -Contain 'eslint'
    }

    It 'Should extract correct version strings from package.json' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/package.json"
        [PSObject]$express = $result | Where-Object { $_.Name -eq 'express' }
        $express.Version | Should -Be '^4.18.2'
    }

    It 'Should return an empty array for package.json with no dependencies' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/empty-package.json"
        $result.Count | Should -Be 0
    }

    It 'Should throw for a non-existent file' {
        { Read-DependencyManifest -Path "$script:fixturesPath/nonexistent.json" } |
            Should -Throw '*does not exist*'
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 2: Parse requirements.txt — extract dependency names and versions
# RED:  Wrote this test. Read-DependencyManifest only handled package.json.
# GREEN: Extended Read-DependencyManifest to detect and parse requirements.txt.
# --------------------------------------------------------------------------
Describe 'Read-DependencyManifest - requirements.txt' {
    BeforeAll {
        [string]$script:fixturesPath = "$PSScriptRoot/fixtures"
    }

    It 'Should parse dependencies from a requirements.txt file' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/requirements.txt"
        $result | Should -Not -BeNullOrEmpty
        # flask, requests, numpy, pandas, black = 5 (comments and -e lines skipped)
        $result.Count | Should -Be 5
    }

    It 'Should extract correct dependency names from requirements.txt' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/requirements.txt"
        [string[]]$names = $result | ForEach-Object { $_.Name }
        $names | Should -Contain 'flask'
        $names | Should -Contain 'requests'
        $names | Should -Contain 'numpy'
        $names | Should -Contain 'pandas'
        $names | Should -Contain 'black'
    }

    It 'Should extract version specifiers from requirements.txt' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/requirements.txt"
        [PSObject]$flask = $result | Where-Object { $_.Name -eq 'flask' }
        $flask.Version | Should -Be '==2.3.3'

        [PSObject]$requests = $result | Where-Object { $_.Name -eq 'requests' }
        $requests.Version | Should -Be '>=2.31.0'
    }

    It 'Should skip comments and blank lines in requirements.txt' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/requirements.txt"
        [string[]]$names = $result | ForEach-Object { $_.Name }
        # Should not contain comment lines or -e lines
        $names | Should -Not -Contain '#'
        $names | Should -Not -Contain '-e'
    }

    It 'Should return an empty array for requirements.txt with only comments' {
        [PSObject[]]$result = Read-DependencyManifest -Path "$script:fixturesPath/empty-requirements.txt"
        $result.Count | Should -Be 0
    }

    It 'Should throw for an unsupported manifest format' {
        # Create a temporary file with an unsupported extension
        [string]$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) 'deps.xml'
        Set-Content -Path $tempFile -Value '<deps/>'
        try {
            { Read-DependencyManifest -Path $tempFile } |
                Should -Throw '*Unsupported manifest format*'
        }
        finally {
            Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
        }
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 3: Read license configuration (allow-list / deny-list)
# RED:  Wrote this test. No Read-LicenseConfig function existed.
# GREEN: Implemented Read-LicenseConfig to parse the JSON config file.
# --------------------------------------------------------------------------
Describe 'Read-LicenseConfig' {
    BeforeAll {
        [string]$script:fixturesPath = "$PSScriptRoot/fixtures"
    }

    It 'Should parse allow and deny lists from config JSON' {
        [PSObject]$config = Read-LicenseConfig -Path "$script:fixturesPath/license-config.json"
        $config.AllowList | Should -Not -BeNullOrEmpty
        $config.DenyList | Should -Not -BeNullOrEmpty
    }

    It 'Should contain MIT in the allow list' {
        [PSObject]$config = Read-LicenseConfig -Path "$script:fixturesPath/license-config.json"
        $config.AllowList | Should -Contain 'MIT'
    }

    It 'Should contain GPL-3.0 in the deny list' {
        [PSObject]$config = Read-LicenseConfig -Path "$script:fixturesPath/license-config.json"
        $config.DenyList | Should -Contain 'GPL-3.0'
    }

    It 'Should throw for a non-existent config file' {
        { Read-LicenseConfig -Path "$script:fixturesPath/nonexistent-config.json" } |
            Should -Throw '*does not exist*'
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 4: License lookup with mock — Get-DependencyLicense
# RED:  Wrote this test. No Get-DependencyLicense function existed.
# GREEN: Implemented Get-DependencyLicense accepting a LicenseLookup scriptblock.
# --------------------------------------------------------------------------
Describe 'Get-DependencyLicense' {
    It 'Should return a license using the provided lookup function' {
        # Mock lookup: returns 'MIT' for any dependency
        [scriptblock]$mockLookup = {
            param([string]$Name, [string]$Version)
            return [string]'MIT'
        }

        [string]$license = Get-DependencyLicense -Name 'express' -Version '^4.18.2' -LicenseLookup $mockLookup
        $license | Should -Be 'MIT'
    }

    It 'Should return UNKNOWN when the lookup returns null' {
        [scriptblock]$mockLookup = {
            param([string]$Name, [string]$Version)
            return $null
        }

        [string]$license = Get-DependencyLicense -Name 'mystery-pkg' -Version '1.0.0' -LicenseLookup $mockLookup
        $license | Should -Be 'UNKNOWN'
    }

    It 'Should return UNKNOWN when the lookup throws an error' {
        [scriptblock]$mockLookup = {
            param([string]$Name, [string]$Version)
            throw "Network error"
        }

        [string]$license = Get-DependencyLicense -Name 'broken-pkg' -Version '1.0.0' -LicenseLookup $mockLookup
        $license | Should -Be 'UNKNOWN'
    }

    It 'Should pass the correct name and version to the lookup' {
        [string]$script:capturedName = ''
        [string]$script:capturedVersion = ''
        [scriptblock]$mockLookup = {
            param([string]$Name, [string]$Version)
            $script:capturedName = $Name
            $script:capturedVersion = $Version
            return [string]'Apache-2.0'
        }

        Get-DependencyLicense -Name 'lodash' -Version '^4.17.21' -LicenseLookup $mockLookup
        $script:capturedName | Should -Be 'lodash'
        $script:capturedVersion | Should -Be '^4.17.21'
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 5: License compliance check — Test-LicenseCompliance
# RED:  Wrote this test. No Test-LicenseCompliance function existed.
# GREEN: Implemented Test-LicenseCompliance to check against allow/deny lists.
# --------------------------------------------------------------------------
Describe 'Test-LicenseCompliance' {
    BeforeAll {
        [string[]]$script:allowList = @('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
        [string[]]$script:denyList = @('GPL-3.0', 'AGPL-3.0')
    }

    It 'Should return Approved for a license on the allow list' {
        [string]$status = Test-LicenseCompliance -License 'MIT' -AllowList $script:allowList -DenyList $script:denyList
        $status | Should -Be 'Approved'
    }

    It 'Should return Denied for a license on the deny list' {
        [string]$status = Test-LicenseCompliance -License 'GPL-3.0' -AllowList $script:allowList -DenyList $script:denyList
        $status | Should -Be 'Denied'
    }

    It 'Should return Unknown for a license on neither list' {
        [string]$status = Test-LicenseCompliance -License 'MPL-2.0' -AllowList $script:allowList -DenyList $script:denyList
        $status | Should -Be 'Unknown'
    }

    It 'Should return Unknown for UNKNOWN license identifier' {
        [string]$status = Test-LicenseCompliance -License 'UNKNOWN' -AllowList $script:allowList -DenyList $script:denyList
        $status | Should -Be 'Unknown'
    }

    It 'Should perform case-insensitive matching' {
        [string]$status = Test-LicenseCompliance -License 'mit' -AllowList $script:allowList -DenyList $script:denyList
        $status | Should -Be 'Approved'

        [string]$statusDeny = Test-LicenseCompliance -License 'gpl-3.0' -AllowList $script:allowList -DenyList $script:denyList
        $statusDeny | Should -Be 'Denied'
    }

    It 'Should prioritize deny list over allow list if license appears in both' {
        # Edge case: license is on both lists — deny takes precedence
        [string[]]$bothAllow = @('MIT', 'GPL-3.0')
        [string[]]$bothDeny = @('GPL-3.0')
        [string]$status = Test-LicenseCompliance -License 'GPL-3.0' -AllowList $bothAllow -DenyList $bothDeny
        $status | Should -Be 'Denied'
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 6: Full compliance report generation — New-ComplianceReport
# RED:  Wrote this test. No New-ComplianceReport function existed.
# GREEN: Implemented New-ComplianceReport orchestrating all other functions.
# --------------------------------------------------------------------------
Describe 'New-ComplianceReport' {
    BeforeAll {
        [string]$script:fixturesPath = "$PSScriptRoot/fixtures"

        # Define a mock license lookup that returns known licenses for test deps
        [scriptblock]$script:mockLookup = {
            param([string]$Name, [string]$Version)
            [hashtable]$licenses = @{
                'express' = 'MIT'
                'lodash'  = 'MIT'
                'axios'   = 'MIT'
                'jest'    = 'MIT'
                'eslint'  = 'MIT'
            }
            if ($licenses.ContainsKey($Name)) {
                return [string]$licenses[$Name]
            }
            return $null
        }
    }

    It 'Should generate a report with entries for every dependency' {
        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $script:mockLookup

        $report.Dependencies | Should -Not -BeNullOrEmpty
        $report.Dependencies.Count | Should -Be 5
    }

    It 'Should include name, version, license, and status for each entry' {
        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $script:mockLookup

        [PSObject]$entry = $report.Dependencies | Where-Object { $_.Name -eq 'express' }
        $entry.Name | Should -Be 'express'
        $entry.Version | Should -Be '^4.18.2'
        $entry.License | Should -Be 'MIT'
        $entry.Status | Should -Be 'Approved'
    }

    It 'Should mark dependencies with unknown licenses as Unknown status' {
        # Lookup that returns null for everything
        [scriptblock]$nullLookup = {
            param([string]$Name, [string]$Version)
            return $null
        }

        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $nullLookup

        [PSObject]$entry = $report.Dependencies | Where-Object { $_.Name -eq 'express' }
        $entry.License | Should -Be 'UNKNOWN'
        $entry.Status | Should -Be 'Unknown'
    }

    It 'Should correctly mark denied licenses' {
        # Lookup that returns GPL-3.0 for lodash
        [scriptblock]$gplLookup = {
            param([string]$Name, [string]$Version)
            [hashtable]$licenses = @{
                'express' = 'MIT'
                'lodash'  = 'GPL-3.0'
                'axios'   = 'Apache-2.0'
                'jest'    = 'BSD-3-Clause'
                'eslint'  = 'AGPL-3.0'
            }
            if ($licenses.ContainsKey($Name)) {
                return [string]$licenses[$Name]
            }
            return $null
        }

        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $gplLookup

        [PSObject]$lodash = $report.Dependencies | Where-Object { $_.Name -eq 'lodash' }
        $lodash.Status | Should -Be 'Denied'

        [PSObject]$eslint = $report.Dependencies | Where-Object { $_.Name -eq 'eslint' }
        $eslint.Status | Should -Be 'Denied'

        [PSObject]$express = $report.Dependencies | Where-Object { $_.Name -eq 'express' }
        $express.Status | Should -Be 'Approved'
    }

    It 'Should include a summary with counts' {
        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $script:mockLookup

        $report.Summary | Should -Not -BeNullOrEmpty
        $report.Summary.Total | Should -Be 5
        $report.Summary.Approved | Should -Be 5
        $report.Summary.Denied | Should -Be 0
        $report.Summary.Unknown | Should -Be 0
    }

    It 'Should work with requirements.txt manifests' {
        [scriptblock]$pyLookup = {
            param([string]$Name, [string]$Version)
            [hashtable]$licenses = @{
                'flask'    = 'BSD-3-Clause'
                'requests' = 'Apache-2.0'
                'numpy'    = 'BSD-3-Clause'
                'pandas'   = 'BSD-3-Clause'
                'black'    = 'MIT'
            }
            if ($licenses.ContainsKey($Name)) {
                return [string]$licenses[$Name]
            }
            return $null
        }

        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/requirements.txt" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $pyLookup

        $report.Dependencies.Count | Should -Be 5
        $report.Summary.Approved | Should -Be 5
    }

    It 'Should include the manifest path and timestamp in the report' {
        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $script:mockLookup

        $report.ManifestPath | Should -Not -BeNullOrEmpty
        $report.Timestamp | Should -Not -BeNullOrEmpty
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 7: Export-ComplianceReport — format report as JSON string
# RED:  Wrote this test. No Export-ComplianceReport function existed.
# GREEN: Implemented Export-ComplianceReport to serialize the report.
# --------------------------------------------------------------------------
Describe 'Export-ComplianceReport' {
    It 'Should produce valid JSON output' {
        [scriptblock]$mockLookup = {
            param([string]$Name, [string]$Version)
            return [string]'MIT'
        }

        [string]$fixturesPath = "$PSScriptRoot/fixtures"
        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$fixturesPath/package.json" `
            -ConfigPath "$fixturesPath/license-config.json" `
            -LicenseLookup $mockLookup

        [string]$json = Export-ComplianceReport -Report $report -Format 'JSON'
        # Verify it's valid JSON by parsing it
        [PSObject]$parsed = $json | ConvertFrom-Json
        $parsed.Dependencies | Should -Not -BeNullOrEmpty
        $parsed.Summary | Should -Not -BeNullOrEmpty
    }

    It 'Should produce readable text output' {
        [scriptblock]$mockLookup = {
            param([string]$Name, [string]$Version)
            return [string]'MIT'
        }

        [string]$fixturesPath = "$PSScriptRoot/fixtures"
        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$fixturesPath/package.json" `
            -ConfigPath "$fixturesPath/license-config.json" `
            -LicenseLookup $mockLookup

        [string]$text = Export-ComplianceReport -Report $report -Format 'Text'
        $text | Should -Match 'Compliance Report'
        $text | Should -Match 'express'
        $text | Should -Match 'Approved'
    }
}

# --------------------------------------------------------------------------
# TDD Cycle 8: Edge cases and error handling
# RED:  Wrote these tests for robustness.
# GREEN: Enhanced functions with proper error handling.
# --------------------------------------------------------------------------
Describe 'Error handling and edge cases' {
    BeforeAll {
        [string]$script:fixturesPath = "$PSScriptRoot/fixtures"
    }

    It 'Should handle malformed JSON in package.json gracefully' {
        [string]$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) 'bad-package.json'
        Set-Content -Path $tempFile -Value '{ this is not valid json }'
        try {
            { Read-DependencyManifest -Path $tempFile } |
                Should -Throw '*Failed to parse*'
        }
        finally {
            Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
        }
    }

    It 'Should handle empty allow and deny lists' {
        [string]$status = Test-LicenseCompliance -License 'MIT' -AllowList @() -DenyList @()
        $status | Should -Be 'Unknown'
    }

    It 'Should handle a report with mixed statuses in summary' {
        [scriptblock]$mixedLookup = {
            param([string]$Name, [string]$Version)
            [hashtable]$licenses = @{
                'express' = 'MIT'          # Approved
                'lodash'  = 'GPL-3.0'      # Denied
                'axios'   = 'WTFPL'        # Unknown (not in either list)
                'jest'    = 'MIT'           # Approved
                'eslint'  = 'Apache-2.0'   # Approved
            }
            if ($licenses.ContainsKey($Name)) {
                return [string]$licenses[$Name]
            }
            return $null
        }

        [PSObject]$report = New-ComplianceReport `
            -ManifestPath "$script:fixturesPath/package.json" `
            -ConfigPath "$script:fixturesPath/license-config.json" `
            -LicenseLookup $mixedLookup

        $report.Summary.Total | Should -Be 5
        $report.Summary.Approved | Should -Be 3
        $report.Summary.Denied | Should -Be 1
        $report.Summary.Unknown | Should -Be 1
    }
}
