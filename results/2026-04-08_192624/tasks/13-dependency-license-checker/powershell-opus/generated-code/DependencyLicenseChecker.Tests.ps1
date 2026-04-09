# DependencyLicenseChecker.Tests.ps1
# Pester tests for the Dependency License Checker module.
#
# TDD approach: each Describe block was written as a failing test first,
# then the corresponding function was implemented to make it pass.

BeforeAll {
    # Dot-source the module to import all functions
    . "$PSScriptRoot/DependencyLicenseChecker.ps1"
}

# --- Test 1 (RED): Parse package.json and extract dependencies ---
# Written FIRST: expected Import-DependencyManifest to return dependency objects.
# Then implemented Import-PackageJson to make it GREEN.
Describe 'Import-DependencyManifest - package.json' {
    BeforeAll {
        $fixtureDir = "$PSScriptRoot/test-fixtures"
    }

    It 'parses dependencies from a package.json file' {
        $deps = Import-DependencyManifest -Path "$fixtureDir/mixed-package.json"
        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 4
    }

    It 'extracts correct dependency names' {
        $deps = Import-DependencyManifest -Path "$fixtureDir/mixed-package.json"
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain 'express'
        $names | Should -Contain 'lodash'
        $names | Should -Contain 'gpl-pkg'
        $names | Should -Contain 'mystery-pkg'
    }

    It 'strips version prefixes (^, ~) from versions' {
        $deps = Import-DependencyManifest -Path "$fixtureDir/mixed-package.json"
        $express = $deps | Where-Object { $_.Name -eq 'express' }
        $express.Version | Should -Be '4.18.2'
    }

    It 'throws on missing file' {
        { Import-DependencyManifest -Path '/nonexistent/package.json' } | Should -Throw '*not found*'
    }
}

# --- Test 2 (RED): Parse requirements.txt ---
# Written FIRST: expected Import-DependencyManifest to handle .txt format.
# Then implemented Import-RequirementsTxt to make it GREEN.
Describe 'Import-DependencyManifest - requirements.txt' {
    BeforeAll {
        $fixtureDir = "$PSScriptRoot/test-fixtures"
    }

    It 'parses dependencies from requirements.txt' {
        $deps = Import-DependencyManifest -Path "$fixtureDir/approved-requirements.txt"
        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 2
    }

    It 'extracts correct names and versions' {
        $deps = Import-DependencyManifest -Path "$fixtureDir/approved-requirements.txt"
        $requests = $deps | Where-Object { $_.Name -eq 'requests' }
        $requests.Version | Should -Be '2.31.0'
        $flask = $deps | Where-Object { $_.Name -eq 'flask' }
        $flask.Version | Should -Be '3.0.0'
    }
}

# --- Test 3 (RED): Look up license from mock database ---
# Written FIRST: expected Get-DependencyLicense to return the correct license.
# Then implemented the lookup function to make it GREEN.
Describe 'Get-DependencyLicense' {
    BeforeAll {
        $dbPath = "$PSScriptRoot/license-db.json"
    }

    It 'returns MIT for express' {
        $license = Get-DependencyLicense -Name 'express' -LicenseDbPath $dbPath
        $license | Should -Be 'MIT'
    }

    It 'returns GPL-3.0 for gpl-pkg' {
        $license = Get-DependencyLicense -Name 'gpl-pkg' -LicenseDbPath $dbPath
        $license | Should -Be 'GPL-3.0'
    }

    It 'returns Unknown for packages not in the database' {
        $license = Get-DependencyLicense -Name 'mystery-pkg' -LicenseDbPath $dbPath
        $license | Should -Be 'Unknown'
    }

    It 'throws when license DB file is missing' {
        { Get-DependencyLicense -Name 'test' -LicenseDbPath '/nonexistent/db.json' } | Should -Throw '*not found*'
    }
}

# --- Test 4 (RED): Check license compliance against config ---
# Written FIRST: expected Test-LicenseCompliance to classify licenses.
# Then implemented the compliance checker to make it GREEN.
Describe 'Test-LicenseCompliance' {
    BeforeAll {
        $config = Import-LicenseConfig -ConfigPath "$PSScriptRoot/license-config.json"
    }

    It 'returns approved for MIT' {
        Test-LicenseCompliance -License 'MIT' -Config $config | Should -Be 'approved'
    }

    It 'returns approved for Apache-2.0' {
        Test-LicenseCompliance -License 'Apache-2.0' -Config $config | Should -Be 'approved'
    }

    It 'returns denied for GPL-3.0' {
        Test-LicenseCompliance -License 'GPL-3.0' -Config $config | Should -Be 'denied'
    }

    It 'returns denied for AGPL-3.0' {
        Test-LicenseCompliance -License 'AGPL-3.0' -Config $config | Should -Be 'denied'
    }

    It 'returns unknown for Unknown license string' {
        Test-LicenseCompliance -License 'Unknown' -Config $config | Should -Be 'unknown'
    }

    It 'returns unknown for a license not in either list' {
        Test-LicenseCompliance -License 'WTFPL' -Config $config | Should -Be 'unknown'
    }
}

# --- Test 5 (RED): Generate full compliance report ---
# Written FIRST: expected New-ComplianceReport to produce a structured report.
# Then implemented the report generator to make it GREEN.
Describe 'New-ComplianceReport' {
    BeforeAll {
        $fixtureDir = "$PSScriptRoot/test-fixtures"
        $configPath = "$PSScriptRoot/license-config.json"
        $dbPath = "$PSScriptRoot/license-db.json"
    }

    Context 'Mixed licenses (some approved, denied, unknown)' {
        BeforeAll {
            $report = New-ComplianceReport `
                -ManifestPath "$fixtureDir/mixed-package.json" `
                -ConfigPath $configPath `
                -LicenseDbPath $dbPath
        }

        It 'includes the report header' {
            $report | Should -Match '=== Dependency License Compliance Report ==='
        }

        It 'shows manifest name' {
            $report | Should -Match 'Manifest: mixed-package.json'
        }

        It 'shows total dependency count of 4' {
            $report | Should -Match 'Total Dependencies: 4'
        }

        It 'marks express as APPROVED with MIT' {
            $report | Should -Match '\[APPROVED\] express@4\.18\.2 - MIT'
        }

        It 'marks lodash as APPROVED with MIT' {
            $report | Should -Match '\[APPROVED\] lodash@4\.17\.21 - MIT'
        }

        It 'marks gpl-pkg as DENIED with GPL-3.0' {
            $report | Should -Match '\[DENIED\] gpl-pkg@1\.0\.0 - GPL-3\.0'
        }

        It 'marks mystery-pkg as UNKNOWN' {
            $report | Should -Match '\[UNKNOWN\] mystery-pkg@0\.1\.0 - Unknown'
        }

        It 'shows correct summary counts' {
            $report | Should -Match 'Summary: 2 approved, 1 denied, 1 unknown'
        }

        It 'shows FAIL overall status' {
            $report | Should -Match 'Overall Status: FAIL'
        }
    }

    Context 'All approved (requirements.txt)' {
        BeforeAll {
            $report = New-ComplianceReport `
                -ManifestPath "$fixtureDir/approved-requirements.txt" `
                -ConfigPath $configPath `
                -LicenseDbPath $dbPath
        }

        It 'shows total dependency count of 2' {
            $report | Should -Match 'Total Dependencies: 2'
        }

        It 'marks requests as APPROVED' {
            $report | Should -Match '\[APPROVED\] requests@2\.31\.0 - Apache-2\.0'
        }

        It 'marks flask as APPROVED' {
            $report | Should -Match '\[APPROVED\] flask@3\.0\.0 - BSD-3-Clause'
        }

        It 'shows PASS overall status' {
            $report | Should -Match 'Overall Status: PASS'
        }

        It 'shows correct summary: 2 approved, 0 denied, 0 unknown' {
            $report | Should -Match 'Summary: 2 approved, 0 denied, 0 unknown'
        }
    }

    Context 'All denied' {
        BeforeAll {
            $report = New-ComplianceReport `
                -ManifestPath "$fixtureDir/denied-package.json" `
                -ConfigPath $configPath `
                -LicenseDbPath $dbPath
        }

        It 'shows total dependency count of 2' {
            $report | Should -Match 'Total Dependencies: 2'
        }

        It 'marks gpl-pkg as DENIED' {
            $report | Should -Match '\[DENIED\] gpl-pkg@1\.0\.0 - GPL-3\.0'
        }

        It 'marks agpl-pkg as DENIED' {
            $report | Should -Match '\[DENIED\] agpl-pkg@2\.0\.0 - AGPL-3\.0'
        }

        It 'shows FAIL overall status' {
            $report | Should -Match 'Overall Status: FAIL'
        }

        It 'shows correct summary: 0 approved, 2 denied, 0 unknown' {
            $report | Should -Match 'Summary: 0 approved, 2 denied, 0 unknown'
        }
    }
}

# --- Test 6 (RED): Error handling ---
# Written FIRST: expected graceful error handling for various edge cases.
Describe 'Error Handling' {
    It 'throws for unsupported manifest format' {
        $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) 'test.yaml'
        '' | Set-Content $tmpFile
        { Import-DependencyManifest -Path $tmpFile } | Should -Throw '*Unsupported manifest format*'
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }

    It 'throws for missing license config' {
        { Import-LicenseConfig -ConfigPath '/nonexistent/config.json' } | Should -Throw '*not found*'
    }
}
