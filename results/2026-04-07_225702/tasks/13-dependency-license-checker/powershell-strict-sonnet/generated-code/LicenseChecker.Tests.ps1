# LicenseChecker.Tests.ps1
# Dependency License Checker — Pester test suite (strict mode)
#
# TDD methodology: each Describe block corresponds to one red/green/refactor cycle.
# Tests were written before the implementation; the implementation was then written
# to satisfy exactly these tests.

BeforeAll {
    # Strict mode must be applied inside BeforeAll so it does not interfere with
    # Pester's own discovery phase (which runs at script scope before BeforeAll).
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    # Import the module under test. -Force ensures a clean reload each run.
    Import-Module (Join-Path $PSScriptRoot 'LicenseChecker.psm1') -Force
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
    $script:ConfigPath  = Join-Path $script:FixturesDir 'license-config.json'
}

# ---------------------------------------------------------------------------
# CYCLE 1 — Read-DependencyManifest: package.json parsing
# ---------------------------------------------------------------------------
Describe 'Read-DependencyManifest — package.json' {

    BeforeAll {
        $script:packageJsonPath = Join-Path $script:FixturesDir 'package.json'
        $script:pkgDeps = Read-DependencyManifest -ManifestPath $script:packageJsonPath
    }

    It 'returns an array' {
        $script:pkgDeps | Should -Not -BeNullOrEmpty
    }

    It 'returns PSCustomObjects with Name and Version properties' {
        $first = $script:pkgDeps[0]
        $first.PSObject.Properties.Name | Should -Contain 'Name'
        $first.PSObject.Properties.Name | Should -Contain 'Version'
    }

    It 'includes packages from the dependencies section' {
        $names = $script:pkgDeps | Select-Object -ExpandProperty Name
        $names | Should -Contain 'express'
        $names | Should -Contain 'lodash'
        $names | Should -Contain 'axios'
    }

    It 'includes packages from the devDependencies section' {
        $names = $script:pkgDeps | Select-Object -ExpandProperty Name
        $names | Should -Contain 'jest'
        $names | Should -Contain 'typescript'
    }

    It 'captures the version string for a dependency' {
        $express = $script:pkgDeps | Where-Object { $_.Name -eq 'express' }
        $express.Version | Should -Be '^4.18.0'
    }

    It 'throws a meaningful error when the file does not exist' {
        { Read-DependencyManifest -ManifestPath '/nonexistent/package.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error for unsupported manifest types' {
        # Create a temp file with an unsupported name
        [string]$tmpFile = Join-Path $TestDrive 'composer.json'
        Set-Content -Path $tmpFile -Value '{}'
        { Read-DependencyManifest -ManifestPath $tmpFile } |
            Should -Throw -ExpectedMessage '*Unsupported*'
    }
}

# ---------------------------------------------------------------------------
# CYCLE 2 — Read-DependencyManifest: requirements.txt parsing
# ---------------------------------------------------------------------------
Describe 'Read-DependencyManifest — requirements.txt' {

    BeforeAll {
        $script:reqPath = Join-Path $script:FixturesDir 'requirements.txt'
        $script:reqDeps = Read-DependencyManifest -ManifestPath $script:reqPath
    }

    It 'returns an array of dependencies' {
        $script:reqDeps | Should -Not -BeNullOrEmpty
    }

    It 'parses exact-version pins (package==version)' {
        $req = $script:reqDeps | Where-Object { $_.Name -eq 'requests' }
        $req | Should -Not -BeNullOrEmpty
        $req.Version | Should -Be '==2.28.0'
    }

    It 'parses range version specifiers (package>=version)' {
        $req = $script:reqDeps | Where-Object { $_.Name -eq 'flask' }
        $req | Should -Not -BeNullOrEmpty
        $req.Version | Should -Be '>=2.0.0,<3.0.0'
    }

    It 'parses compatible-release specifiers (package~=version)' {
        $req = $script:reqDeps | Where-Object { $_.Name -eq 'numpy' }
        $req | Should -Not -BeNullOrEmpty
        $req.Version | Should -Be '~=1.24.0'
    }

    It 'parses bare package names with no version' {
        $req = $script:reqDeps | Where-Object { $_.Name -eq 'boto3' }
        $req | Should -Not -BeNullOrEmpty
        $req.Version | Should -Be ''
    }

    It 'skips comment lines' {
        $names = $script:reqDeps | Select-Object -ExpandProperty Name
        $names | Where-Object { $_ -like '#*' } | Should -BeNullOrEmpty
    }

    It 'skips blank lines' {
        # All returned entries must have a non-empty Name
        $blank = $script:reqDeps | Where-Object { [string]::IsNullOrWhiteSpace($_.Name) }
        $blank | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Get-LicenseConfig: loading the allow/deny config
# ---------------------------------------------------------------------------
Describe 'Get-LicenseConfig' {

    It 'loads allowList and denyList from a valid JSON file' {
        $cfg = Get-LicenseConfig -ConfigPath $script:ConfigPath
        $cfg.allowList | Should -Contain 'MIT'
        $cfg.allowList | Should -Contain 'Apache-2.0'
        $cfg.denyList  | Should -Contain 'GPL-3.0'
    }

    It 'throws when the config file does not exist' {
        { Get-LicenseConfig -ConfigPath '/no/such/config.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when allowList is missing' {
        [string]$badCfg = Join-Path $TestDrive 'bad-config.json'
        Set-Content -Path $badCfg -Value '{ "denyList": ["GPL-3.0"] }'
        { Get-LicenseConfig -ConfigPath $badCfg } |
            Should -Throw -ExpectedMessage '*allowList*'
    }

    It 'throws when denyList is missing' {
        [string]$badCfg = Join-Path $TestDrive 'bad-config2.json'
        Set-Content -Path $badCfg -Value '{ "allowList": ["MIT"] }'
        { Get-LicenseConfig -ConfigPath $badCfg } |
            Should -Throw -ExpectedMessage '*denyList*'
    }
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Test-LicenseCompliance: status determination
# ---------------------------------------------------------------------------
Describe 'Test-LicenseCompliance' {

    BeforeAll {
        $script:cfg = [PSCustomObject]@{
            allowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
            denyList  = [string[]]@('GPL-3.0', 'AGPL-3.0', 'LGPL-2.1')
        }
    }

    It "returns 'approved' when the license is in the allowList" {
        Test-LicenseCompliance -License 'MIT' -Config $script:cfg | Should -Be 'approved'
    }

    It "returns 'approved' for any license in the allowList" {
        Test-LicenseCompliance -License 'Apache-2.0' -Config $script:cfg | Should -Be 'approved'
        Test-LicenseCompliance -License 'BSD-3-Clause' -Config $script:cfg | Should -Be 'approved'
    }

    It "returns 'denied' when the license is in the denyList" {
        Test-LicenseCompliance -License 'GPL-3.0' -Config $script:cfg | Should -Be 'denied'
    }

    It "returns 'denied' for any license in the denyList" {
        Test-LicenseCompliance -License 'AGPL-3.0' -Config $script:cfg | Should -Be 'denied'
        Test-LicenseCompliance -License 'LGPL-2.1' -Config $script:cfg | Should -Be 'denied'
    }

    It "returns 'unknown' when license is not in either list" {
        Test-LicenseCompliance -License 'EUPL-1.2' -Config $script:cfg | Should -Be 'unknown'
    }

    It "returns 'unknown' when the license string itself is 'unknown'" {
        Test-LicenseCompliance -License 'unknown' -Config $script:cfg | Should -Be 'unknown'
    }

    It 'deny-list takes priority over allow-list when both would match (safety test)' {
        # A license in BOTH lists should be denied (deny-list wins)
        $overlapCfg = [PSCustomObject]@{
            allowList = [string[]]@('MIT', 'GPL-3.0')
            denyList  = [string[]]@('GPL-3.0')
        }
        Test-LicenseCompliance -License 'GPL-3.0' -Config $overlapCfg | Should -Be 'denied'
    }
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Get-DependencyLicense: mock license lookup
# ---------------------------------------------------------------------------
Describe 'Get-DependencyLicense' {

    It 'returns a known license for a well-known package' {
        # The module ships a built-in mock DB for testing
        Get-DependencyLicense -PackageName 'express'  | Should -Be 'MIT'
        Get-DependencyLicense -PackageName 'requests' | Should -Be 'Apache-2.0'
        Get-DependencyLicense -PackageName 'flask'    | Should -Be 'BSD-3-Clause'
    }

    It "returns 'unknown' for a package not in the mock database" {
        Get-DependencyLicense -PackageName 'some-obscure-package-xyz' | Should -Be 'unknown'
    }

    It 'returns a denied license for a known GPL package' {
        Get-DependencyLicense -PackageName 'gpl-lib' | Should -Be 'GPL-3.0'
    }
}

# ---------------------------------------------------------------------------
# CYCLE 6 — New-ComplianceReport: end-to-end report generation
# ---------------------------------------------------------------------------
Describe 'New-ComplianceReport' {

    BeforeAll {
        $script:reportCfg = [PSCustomObject]@{
            allowList = [string[]]@('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
            denyList  = [string[]]@('GPL-3.0', 'AGPL-3.0', 'LGPL-2.1')
        }
    }

    It 'returns an entry for every dependency' {
        # Mock license lookup so the test is deterministic
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' { 'MIT' }

        $deps = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'alpha'; Version = '1.0.0' }
            [PSCustomObject]@{ Name = 'beta';  Version = '2.0.0' }
            [PSCustomObject]@{ Name = 'gamma'; Version = '3.0.0' }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $script:reportCfg
        $report.Count | Should -Be 3
    }

    It 'includes Name, Version, License, and Status in each entry' {
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' { 'MIT' }

        $deps = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'express'; Version = '^4.18.0' }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $script:reportCfg
        $entry = $report[0]
        $entry.PSObject.Properties.Name | Should -Contain 'Name'
        $entry.PSObject.Properties.Name | Should -Contain 'Version'
        $entry.PSObject.Properties.Name | Should -Contain 'License'
        $entry.PSObject.Properties.Name | Should -Contain 'Status'
    }

    It "sets Status to 'approved' for a package with an allowed license" {
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' -ParameterFilter {
            $PackageName -eq 'express'
        } { 'MIT' }

        $deps = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'express'; Version = '^4.18.0' }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $script:reportCfg
        $report[0].Status   | Should -Be 'approved'
        $report[0].License  | Should -Be 'MIT'
    }

    It "sets Status to 'denied' for a package with a denied license" {
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' -ParameterFilter {
            $PackageName -eq 'gpl-lib'
        } { 'GPL-3.0' }

        $deps = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'gpl-lib'; Version = '^1.0.0' }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $script:reportCfg
        $report[0].Status  | Should -Be 'denied'
        $report[0].License | Should -Be 'GPL-3.0'
    }

    It "sets Status to 'unknown' for a package with an unrecognised license" {
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' -ParameterFilter {
            $PackageName -eq 'mystery-pkg'
        } { 'unknown' }

        $deps = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'mystery-pkg'; Version = '0.1.0' }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $script:reportCfg
        $report[0].Status  | Should -Be 'unknown'
        $report[0].License | Should -Be 'unknown'
    }

    It 'produces mixed statuses across a heterogeneous dependency list' {
        # Provide per-package mocks
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' -ParameterFilter {
            $PackageName -eq 'alpha'
        } { 'MIT' }
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' -ParameterFilter {
            $PackageName -eq 'beta'
        } { 'GPL-3.0' }
        Mock Get-DependencyLicense -ModuleName 'LicenseChecker' -ParameterFilter {
            $PackageName -eq 'gamma'
        } { 'unknown' }

        $deps = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'alpha'; Version = '1.0.0' }
            [PSCustomObject]@{ Name = 'beta';  Version = '2.0.0' }
            [PSCustomObject]@{ Name = 'gamma'; Version = '3.0.0' }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $script:reportCfg

        ($report | Where-Object { $_.Status -eq 'approved' }).Count | Should -Be 1
        ($report | Where-Object { $_.Status -eq 'denied'   }).Count | Should -Be 1
        ($report | Where-Object { $_.Status -eq 'unknown'  }).Count | Should -Be 1
    }

    It 'works end-to-end using the real fixture files without mocking' {
        # Integration-style test: parses real fixture package.json + real config,
        # relies on the module's built-in mock license DB
        $pkgDeps = Read-DependencyManifest -ManifestPath (
            Join-Path $script:FixturesDir 'package.json')
        $cfg     = Get-LicenseConfig -ConfigPath $script:ConfigPath

        $report  = New-ComplianceReport -Dependencies $pkgDeps -Config $cfg

        $report.Count | Should -BeGreaterThan 0

        # express is MIT → approved
        $expressEntry = $report | Where-Object { $_.Name -eq 'express' }
        $expressEntry.Status | Should -Be 'approved'

        # gpl-lib is GPL-3.0 → denied
        $gplEntry = $report | Where-Object { $_.Name -eq 'gpl-lib' }
        $gplEntry.Status | Should -Be 'denied'
    }
}
