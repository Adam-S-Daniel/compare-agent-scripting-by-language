# Pester tests for LicenseChecker module. Written TDD-style: each Describe block
# covers one capability. Mocks replace the license lookup so tests are hermetic.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'LicenseChecker.psm1'
    Import-Module $script:ModulePath -Force

    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Get-DependenciesFromManifest' {
    It 'parses a package.json with dependencies and devDependencies' {
        $path = Join-Path $script:FixturesDir 'package.json'
        $deps = Get-DependenciesFromManifest -Path $path
        $deps.Count | Should -Be 4
        ($deps | Where-Object Name -eq 'lodash').Version  | Should -Be '4.17.21'
        ($deps | Where-Object Name -eq 'jest').Scope      | Should -Be 'devDependencies'
    }

    It 'throws a clear error when the file does not exist' {
        { Get-DependenciesFromManifest -Path '/no/such/file.json' } |
            Should -Throw '*not found*'
    }

    It 'throws a clear error when the manifest is not valid JSON' {
        $bad = Join-Path $script:FixturesDir 'invalid.json'
        { Get-DependenciesFromManifest -Path $bad } | Should -Throw '*parse*'
    }

    It 'returns an empty array when manifest has no dependencies' {
        $empty = Join-Path $script:FixturesDir 'empty-package.json'
        $deps = Get-DependenciesFromManifest -Path $empty
        @($deps).Count | Should -Be 0
    }
}

Describe 'Test-LicenseCompliance' {
    It 'returns approved for a license on the allow list' {
        Test-LicenseCompliance -License 'MIT' -AllowList @('MIT','Apache-2.0') -DenyList @('GPL-3.0') |
            Should -Be 'approved'
    }
    It 'returns denied for a license on the deny list' {
        Test-LicenseCompliance -License 'GPL-3.0' -AllowList @('MIT') -DenyList @('GPL-3.0') |
            Should -Be 'denied'
    }
    It 'returns unknown for a license on neither list' {
        Test-LicenseCompliance -License 'BSD-2-Clause' -AllowList @('MIT') -DenyList @('GPL-3.0') |
            Should -Be 'unknown'
    }
    It 'returns unknown when the license is UNKNOWN' {
        Test-LicenseCompliance -License 'UNKNOWN' -AllowList @('MIT') -DenyList @('GPL-3.0') |
            Should -Be 'unknown'
    }
    It 'prefers deny over allow if a license somehow appears on both' {
        Test-LicenseCompliance -License 'MIT' -AllowList @('MIT') -DenyList @('MIT') |
            Should -Be 'denied'
    }
}

Describe 'Invoke-LicenseCheck' {
    BeforeEach {
        # Mock Get-PackageLicense inside the module scope — each fixture dep
        # maps to a known license so assertions on the final report are exact.
        Mock -ModuleName LicenseChecker Get-PackageLicense {
            param($Name, $Version)
            switch ($Name) {
                'lodash'    { 'MIT' }
                'express'   { 'MIT' }
                'some-gpl'  { 'GPL-3.0' }
                'jest'      { 'Apache-2.0' }
                'mystery'   { 'UNKNOWN' }
                default     { 'UNKNOWN' }
            }
        }
    }

    It 'produces a report with correct statuses for each dependency' {
        $report = Invoke-LicenseCheck `
            -ManifestPath (Join-Path $script:FixturesDir 'package.json') `
            -ConfigPath   (Join-Path $script:FixturesDir 'config.json')

        $report.summary.total    | Should -Be 4
        $report.summary.approved | Should -Be 2   # lodash(MIT), jest(Apache)
        $report.summary.denied   | Should -Be 1   # some-gpl(GPL-3.0)
        $report.summary.unknown  | Should -Be 1   # mystery(UNKNOWN)

        ($report.dependencies | Where-Object name -eq 'some-gpl').status | Should -Be 'denied'
        ($report.dependencies | Where-Object name -eq 'mystery').status  | Should -Be 'unknown'
        ($report.dependencies | Where-Object name -eq 'lodash').status   | Should -Be 'approved'
    }

    It 'throws a clear error when config is missing' {
        { Invoke-LicenseCheck `
            -ManifestPath (Join-Path $script:FixturesDir 'package.json') `
            -ConfigPath   '/no/such/config.json' } | Should -Throw '*Config*not found*'
    }
}
