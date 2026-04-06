# LicenseChecker.Tests.ps1
# Pester tests for the Dependency License Checker
#
# TDD Approach:
#   RED   - Write a failing test that describes desired behavior
#   GREEN - Write minimum code to make the test pass
#   REFACTOR - Clean up without breaking tests
#
# Each Describe block covers one piece of functionality,
# added incrementally following the red/green/refactor cycle.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Resolve paths relative to this test file
$here = $PSScriptRoot
$modulePath = Join-Path $here 'LicenseChecker.psm1'
$fixturesPath = Join-Path $here 'fixtures'

# Import the module (will fail until module is created — that's the RED state)
Import-Module $modulePath -Force

# ---------------------------------------------------------------------------
# CYCLE 1: Parsing package.json manifests
# ---------------------------------------------------------------------------
Describe 'Read-DependencyManifest' {

    Context 'when given a valid package.json' {
        It 'returns a list of dependency objects with name and version' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath

            $deps | Should -Not -BeNullOrEmpty
            $deps.Count | Should -BeGreaterThan 0

            # Each dependency must have Name and Version
            foreach ($dep in $deps) {
                $dep.Name    | Should -Not -BeNullOrEmpty
                $dep.Version | Should -Not -BeNullOrEmpty
            }
        }

        It 'parses known dependency names from package.json' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath
            [string[]]$names = $deps | ForEach-Object { [string]$_.Name }

            $names | Should -Contain 'express'
            $names | Should -Contain 'lodash'
            $names | Should -Contain 'moment'
        }

        It 'parses correct versions from package.json' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath
            [hashtable]$byName = @{}
            foreach ($dep in $deps) {
                $byName[[string]$dep.Name] = [string]$dep.Version
            }

            $byName['express'] | Should -Be '4.18.2'
            $byName['lodash']  | Should -Be '4.17.21'
        }

        It 'includes only runtime dependencies by default (not devDependencies)' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath
            [string[]]$names = $deps | ForEach-Object { [string]$_.Name }

            # jest is a devDependency — should not appear by default
            $names | Should -Not -Contain 'jest'
        }

        It 'includes devDependencies when -IncludeDev is specified' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath -IncludeDev

            [string[]]$names = $deps | ForEach-Object { [string]$_.Name }
            $names | Should -Contain 'jest'
        }
    }

    Context 'when given a valid requirements.txt' {
        It 'returns a list of dependency objects with name and version' {
            [string]$manifestPath = Join-Path $fixturesPath 'requirements.txt'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath

            $deps | Should -Not -BeNullOrEmpty
        }

        It 'parses known packages from requirements.txt' {
            [string]$manifestPath = Join-Path $fixturesPath 'requirements.txt'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath
            [string[]]$names = $deps | ForEach-Object { [string]$_.Name }

            $names | Should -Contain 'requests'
            $names | Should -Contain 'flask'
        }

        It 'parses correct versions from requirements.txt' {
            [string]$manifestPath = Join-Path $fixturesPath 'requirements.txt'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath
            [hashtable]$byName = @{}
            foreach ($dep in $deps) {
                $byName[[string]$dep.Name] = [string]$dep.Version
            }

            $byName['requests'] | Should -Be '2.28.0'
            $byName['flask']    | Should -Be '2.2.0'
        }

        It 'ignores comment lines starting with #' {
            [string]$manifestPath = Join-Path $fixturesPath 'requirements.txt'

            [object[]]$deps = Read-DependencyManifest -ManifestPath $manifestPath
            [string[]]$names = $deps | ForEach-Object { [string]$_.Name }

            # Comment line should not become a dependency
            $names | Should -Not -Contain '#'
            $names | Should -Not -Match '^#'
        }
    }

    Context 'error handling' {
        It 'throws a meaningful error for a non-existent file' {
            { Read-DependencyManifest -ManifestPath 'nonexistent-file.json' } |
                Should -Throw -ExpectedMessage '*not found*'
        }

        It 'throws a meaningful error for an unsupported format' {
            [string]$tmpFile = Join-Path $TestDrive 'deps.toml'
            Set-Content -Path $tmpFile -Value '[dependencies]'

            { Read-DependencyManifest -ManifestPath $tmpFile } |
                Should -Throw -ExpectedMessage '*unsupported*'
        }
    }
}

# ---------------------------------------------------------------------------
# CYCLE 2: License compliance classification
# ---------------------------------------------------------------------------
Describe 'Test-LicenseCompliance' {

    Context 'approved licenses' {
        It 'returns approved when the license is in the allow-list' {
            [string[]]$allowList = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            [string[]]$denyList  = @('GPL-2.0', 'GPL-3.0', 'AGPL-3.0')

            [string]$result = Test-LicenseCompliance `
                -License   'MIT' `
                -AllowList $allowList `
                -DenyList  $denyList

            $result | Should -Be 'approved'
        }

        It 'is case-insensitive when comparing licenses' {
            [string[]]$allowList = @('MIT', 'Apache-2.0')
            [string[]]$denyList  = @('GPL-2.0')

            [string]$result = Test-LicenseCompliance `
                -License   'mit' `
                -AllowList $allowList `
                -DenyList  $denyList

            $result | Should -Be 'approved'
        }
    }

    Context 'denied licenses' {
        It 'returns denied when the license is in the deny-list' {
            [string[]]$allowList = @('MIT', 'Apache-2.0')
            [string[]]$denyList  = @('GPL-2.0', 'GPL-3.0')

            [string]$result = Test-LicenseCompliance `
                -License   'GPL-3.0' `
                -AllowList $allowList `
                -DenyList  $denyList

            $result | Should -Be 'denied'
        }

        It 'prefers denied over approved when a license appears in both lists' {
            [string[]]$allowList = @('MIT', 'GPL-2.0')
            [string[]]$denyList  = @('GPL-2.0')

            [string]$result = Test-LicenseCompliance `
                -License   'GPL-2.0' `
                -AllowList $allowList `
                -DenyList  $denyList

            $result | Should -Be 'denied'
        }
    }

    Context 'unknown licenses' {
        It 'returns unknown when the license is in neither list' {
            [string[]]$allowList = @('MIT', 'Apache-2.0')
            [string[]]$denyList  = @('GPL-2.0')

            [string]$result = Test-LicenseCompliance `
                -License   'LGPL-2.1' `
                -AllowList $allowList `
                -DenyList  $denyList

            $result | Should -Be 'unknown'
        }

        It 'returns unknown when the license is null or empty' {
            [string[]]$allowList = @('MIT')
            [string[]]$denyList  = @('GPL-2.0')

            [string]$result = Test-LicenseCompliance `
                -License   '' `
                -AllowList $allowList `
                -DenyList  $denyList

            $result | Should -Be 'unknown'
        }
    }
}

# ---------------------------------------------------------------------------
# CYCLE 3: License lookup (with mock injection)
# ---------------------------------------------------------------------------
Describe 'Invoke-LicenseLookup' {

    It 'returns a license string for a known package' {
        # Real lookup is mocked via a scriptblock parameter in higher-level functions.
        # This test verifies the built-in mock lookup table used in tests.
        [string]$license = Invoke-LicenseLookup -PackageName 'express' -Version '4.18.2'
        $license | Should -Not -BeNullOrEmpty
    }

    It 'returns an empty string for an unknown package' {
        [string]$license = Invoke-LicenseLookup -PackageName 'totally-unknown-xyz' -Version '9.9.9'
        $license | Should -Be ''
    }
}

# ---------------------------------------------------------------------------
# CYCLE 4: Full compliance report generation
# ---------------------------------------------------------------------------
#
# Script-scoped shared state for New-ComplianceReport tests.
# Declared at the script level (before any Describe block runs them) so they
# are unambiguously accessible in all It blocks regardless of Pester 5 scoping.
#
[scriptblock]$script:reportMockLookup = {
    param([string]$PackageName, [string]$Version)
    [hashtable]$db = @{
        'express'     = 'MIT'
        'lodash'      = 'MIT'
        'moment'      = 'MIT'
        'gpl-lib'     = 'GPL-3.0'
        'unknown-pkg' = ''
        'requests'    = 'Apache-2.0'
        'flask'       = 'BSD-3-Clause'
        'numpy'       = 'BSD-3-Clause'
        'gpl-package' = 'GPL-2.0'
        'mystery-lib' = ''
    }
    if ($db.ContainsKey($PackageName)) {
        return [string]$db[$PackageName]
    }
    return [string]''
}

[hashtable]$script:reportConfig = @{
    AllowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
    DenyList  = [string[]]@('GPL-2.0', 'GPL-3.0', 'AGPL-3.0', 'SSPL')
}

Describe 'New-ComplianceReport' {

    Context 'report structure' {
        It 'returns a report object with Summary and Dependencies properties' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath   $manifestPath `
                -Config         $script:reportConfig `
                -LicenseLookup  $script:reportMockLookup

            $report | Should -Not -BeNullOrEmpty
            $report.ContainsKey('Summary')      | Should -BeTrue
            $report.ContainsKey('Dependencies') | Should -BeTrue
        }

        It 'each dependency entry has Name, Version, License, and Status fields' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            foreach ($dep in $report.Dependencies) {
                $dep.Name    | Should -Not -BeNullOrEmpty
                $dep.Version | Should -Not -BeNullOrEmpty
                # License may be empty for unknown packages — that's OK
                $dep.PSObject.Properties['License'] | Should -Not -BeNullOrEmpty
                $dep.Status  | Should -BeIn @('approved', 'denied', 'unknown')
            }
        }
    }

    Context 'correct status assignment — package.json' {
        It 'marks MIT-licensed packages as approved' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $express = $report.Dependencies | Where-Object { $_.Name -eq 'express' }
            $express.Status  | Should -Be 'approved'
            $express.License | Should -Be 'MIT'
        }

        It 'marks GPL-licensed packages as denied' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $gplLib = $report.Dependencies | Where-Object { $_.Name -eq 'gpl-lib' }
            $gplLib.Status  | Should -Be 'denied'
            $gplLib.License | Should -Be 'GPL-3.0'
        }

        It 'marks packages with no license info as unknown' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $unknownPkg = $report.Dependencies | Where-Object { $_.Name -eq 'unknown-pkg' }
            $unknownPkg.Status | Should -Be 'unknown'
        }
    }

    Context 'summary counts' {
        It 'summary reflects correct approved/denied/unknown counts for package.json' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            # express=MIT(ok), lodash=MIT(ok), moment=MIT(ok), gpl-lib=GPL-3.0(denied), unknown-pkg=(unknown)
            $report.Summary.Approved | Should -Be 3
            $report.Summary.Denied   | Should -Be 1
            $report.Summary.Unknown  | Should -Be 1
            $report.Summary.Total    | Should -Be 5
        }

        It 'summary has IsCompliant=true when there are no denied packages' {
            # Build a manifest with only approved packages
            [string]$tmpManifest = Join-Path $TestDrive 'package.json'
            Set-Content -Path $tmpManifest -Value '{"name":"test","dependencies":{"express":"4.18.2","lodash":"4.17.21"}}'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $tmpManifest `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $report.Summary.IsCompliant | Should -BeTrue
        }

        It 'summary has IsCompliant=false when there are denied packages' {
            [string]$manifestPath = Join-Path $fixturesPath 'package.json'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $report.Summary.IsCompliant | Should -BeFalse
        }
    }

    Context 'correct status assignment — requirements.txt' {
        It 'marks Apache-2.0 packages as approved' {
            [string]$manifestPath = Join-Path $fixturesPath 'requirements.txt'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $requests = $report.Dependencies | Where-Object { $_.Name -eq 'requests' }
            $requests.Status | Should -Be 'approved'
        }

        It 'marks GPL packages as denied in requirements.txt' {
            [string]$manifestPath = Join-Path $fixturesPath 'requirements.txt'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $manifestPath `
                -Config        $script:reportConfig `
                -LicenseLookup $script:reportMockLookup

            $gplPkg = $report.Dependencies | Where-Object { $_.Name -eq 'gpl-package' }
            $gplPkg.Status | Should -Be 'denied'
        }
    }
}

# ---------------------------------------------------------------------------
# CYCLE 5: Report formatting / export
# ---------------------------------------------------------------------------
Describe 'Export-ComplianceReport' {

    # Helper scriptblock — inline so each It block is self-contained.
    # Pester 5 BeforeAll variables are accessible in It via scope inheritance,
    # but for maximum strict-mode safety each test builds what it needs.

    Context 'text format' {
        It 'exports a human-readable text report to a file' {
            [scriptblock]$mockLookup = {
                param([string]$PackageName, [string]$Version)
                [hashtable]$db = @{ 'express' = 'MIT'; 'lodash' = 'MIT'; 'gpl-lib' = 'GPL-3.0' }
                if ($db.ContainsKey($PackageName)) { return [string]$db[$PackageName] }
                return [string]''
            }
            [hashtable]$cfg = @{
                AllowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause')
                DenyList  = [string[]]@('GPL-2.0', 'GPL-3.0')
            }
            [string]$mPath  = Join-Path $TestDrive 'package-txt.json'
            [string]$outFile = Join-Path $TestDrive 'report.txt'
            Set-Content -Path $mPath -Value '{"name":"test","dependencies":{"express":"4.18.2","lodash":"4.17.21","gpl-lib":"1.0.0","unknown-pkg":"0.5.0"}}'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $mPath `
                -Config        $cfg `
                -LicenseLookup $mockLookup

            Export-ComplianceReport -Report $report -OutputPath $outFile -Format 'text'

            Test-Path $outFile | Should -BeTrue
            [string]$content = Get-Content $outFile -Raw
            $content | Should -Match 'express'
            $content | Should -Match 'approved'
            $content | Should -Match 'denied'
        }
    }

    Context 'JSON format' {
        It 'exports a valid JSON report to a file' {
            [scriptblock]$mockLookup = {
                param([string]$PackageName, [string]$Version)
                [hashtable]$db = @{ 'express' = 'MIT'; 'lodash' = 'MIT'; 'gpl-lib' = 'GPL-3.0' }
                if ($db.ContainsKey($PackageName)) { return [string]$db[$PackageName] }
                return [string]''
            }
            [hashtable]$cfg = @{
                AllowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause')
                DenyList  = [string[]]@('GPL-2.0', 'GPL-3.0')
            }
            [string]$mPath  = Join-Path $TestDrive 'package-json1.json'
            [string]$outFile = Join-Path $TestDrive 'report.json'
            Set-Content -Path $mPath -Value '{"name":"test","dependencies":{"express":"4.18.2","lodash":"4.17.21","gpl-lib":"1.0.0","unknown-pkg":"0.5.0"}}'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $mPath `
                -Config        $cfg `
                -LicenseLookup $mockLookup

            Export-ComplianceReport -Report $report -OutputPath $outFile -Format 'json'

            Test-Path $outFile | Should -BeTrue
            [string]$content = Get-Content $outFile -Raw
            # Should parse as valid JSON
            { $null = $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON report contains summary and dependencies' {
            [scriptblock]$mockLookup = {
                param([string]$PackageName, [string]$Version)
                [hashtable]$db = @{ 'express' = 'MIT'; 'lodash' = 'MIT'; 'gpl-lib' = 'GPL-3.0' }
                if ($db.ContainsKey($PackageName)) { return [string]$db[$PackageName] }
                return [string]''
            }
            [hashtable]$cfg = @{
                AllowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause')
                DenyList  = [string[]]@('GPL-2.0', 'GPL-3.0')
            }
            [string]$mPath  = Join-Path $TestDrive 'package-json2.json'
            [string]$outFile = Join-Path $TestDrive 'report2.json'
            Set-Content -Path $mPath -Value '{"name":"test","dependencies":{"express":"4.18.2","lodash":"4.17.21","gpl-lib":"1.0.0","unknown-pkg":"0.5.0"}}'

            [hashtable]$report = New-ComplianceReport `
                -ManifestPath  $mPath `
                -Config        $cfg `
                -LicenseLookup $mockLookup

            Export-ComplianceReport -Report $report -OutputPath $outFile -Format 'json'

            [PSCustomObject]$parsed = Get-Content $outFile -Raw | ConvertFrom-Json
            $parsed.Summary      | Should -Not -BeNullOrEmpty
            $parsed.Dependencies | Should -Not -BeNullOrEmpty
        }
    }
}
