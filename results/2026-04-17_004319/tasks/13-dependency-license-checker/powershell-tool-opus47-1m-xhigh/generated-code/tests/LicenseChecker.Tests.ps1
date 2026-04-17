# Pester tests for the LicenseChecker module.
# Uses Pester 5.x syntax. Tests are organized by iteration so each step
# corresponds to a red/green TDD cycle described in the README.

BeforeAll {
    # Resolve the module path relative to the test file so the suite works
    # regardless of where Invoke-Pester is launched from.
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'LicenseChecker.psm1'
    Import-Module $script:ModulePath -Force

    # A reusable sample policy shared by most tests.
    $script:SamplePolicy = [pscustomobject]@{
        allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
        deny  = @('GPL-3.0', 'AGPL-3.0')
    }

    # A deterministic mock license database. The tests never reach a real
    # registry - license lookups always resolve through this hashtable.
    $script:MockLicenseDb = @{
        'lodash'     = 'MIT'
        'express'    = 'MIT'
        'left-pad'   = 'Apache-2.0'
        'copyleft-x' = 'GPL-3.0'
        'phantom-ui' = 'AGPL-3.0'
    }
}

Describe 'Read-DependencyManifest' {

    It 'extracts name+version pairs from a package.json with dependencies only' {
        $tmp = New-TemporaryFile
        @{
            name         = 'demo'
            version      = '1.0.0'
            dependencies = @{
                lodash  = '^4.17.21'
                express = '~4.18.0'
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp

        $result = Read-DependencyManifest -Path $tmp

        $result.Count | Should -Be 2
        ($result | Where-Object Name -eq 'lodash').Version  | Should -Be '^4.17.21'
        ($result | Where-Object Name -eq 'express').Version | Should -Be '~4.18.0'

        Remove-Item $tmp -Force
    }

    It 'merges devDependencies into the dependency list' {
        $tmp = New-TemporaryFile
        @{
            name            = 'demo'
            dependencies    = @{ lodash = '4.17.21' }
            devDependencies = @{ 'left-pad' = '1.3.0' }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp

        $result = Read-DependencyManifest -Path $tmp

        $result.Count | Should -Be 2
        ($result | Where-Object Name -eq 'left-pad').Version | Should -Be '1.3.0'

        Remove-Item $tmp -Force
    }

    It 'returns an empty list when the manifest has no dependency blocks' {
        $tmp = New-TemporaryFile
        @{ name = 'empty'; version = '0.0.0' } | ConvertTo-Json | Set-Content -Path $tmp

        $result = @(Read-DependencyManifest -Path $tmp)

        $result.Count | Should -Be 0
        Remove-Item $tmp -Force
    }

    It 'throws a meaningful error when the manifest file does not exist' {
        { Read-DependencyManifest -Path '/nope/does-not-exist.json' } |
            Should -Throw -ExpectedMessage '*Manifest not found*'
    }

    It 'throws a meaningful error when the manifest is not valid JSON' {
        $tmp = New-TemporaryFile
        'this is { not json' | Set-Content -Path $tmp
        { Read-DependencyManifest -Path $tmp } |
            Should -Throw -ExpectedMessage '*Failed to parse*'
        Remove-Item $tmp -Force
    }
}

Describe 'Get-DependencyLicense (mock lookup)' {

    It 'returns the license string when the dependency is present in the database' {
        Get-DependencyLicense -Name 'lodash' -Database $script:MockLicenseDb |
            Should -Be 'MIT'
    }

    It 'returns $null when the dependency is absent from the database' {
        Get-DependencyLicense -Name 'never-heard-of-it' -Database $script:MockLicenseDb |
            Should -BeNullOrEmpty
    }

    It 'is case-insensitive for dependency names' {
        Get-DependencyLicense -Name 'LoDaSh' -Database $script:MockLicenseDb |
            Should -Be 'MIT'
    }
}

Describe 'Test-LicenseStatus' {

    It 'returns "approved" for a license on the allow-list' {
        Test-LicenseStatus -License 'MIT' -Policy $script:SamplePolicy |
            Should -Be 'approved'
    }

    It 'returns "denied" for a license on the deny-list' {
        Test-LicenseStatus -License 'GPL-3.0' -Policy $script:SamplePolicy |
            Should -Be 'denied'
    }

    It 'returns "unknown" for a license absent from both lists' {
        Test-LicenseStatus -License 'Artistic-2.0' -Policy $script:SamplePolicy |
            Should -Be 'unknown'
    }

    It 'returns "unknown" when license is $null or empty' {
        Test-LicenseStatus -License $null -Policy $script:SamplePolicy | Should -Be 'unknown'
        Test-LicenseStatus -License ''   -Policy $script:SamplePolicy | Should -Be 'unknown'
    }

    It 'treats deny entries as authoritative even if also allowed (deny wins)' {
        $policy = [pscustomobject]@{
            allow = @('MIT')
            deny  = @('MIT')
        }
        Test-LicenseStatus -License 'MIT' -Policy $policy | Should -Be 'denied'
    }
}

Describe 'New-ComplianceReport (integration)' {

    BeforeAll {
        # Build a manifest with one approved, one denied, one unknown (missing license).
        $script:ManifestPath = New-TemporaryFile
        @{
            name         = 'integration-demo'
            version      = '1.0.0'
            dependencies = @{
                lodash        = '4.17.21'
                'copyleft-x'  = '2.0.0'
                'mystery-dep' = '0.1.0'
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:ManifestPath
    }

    AfterAll {
        Remove-Item $script:ManifestPath -Force -ErrorAction SilentlyContinue
    }

    It 'produces a report entry for every dependency in the manifest' {
        $report = New-ComplianceReport -ManifestPath $script:ManifestPath `
                                       -Policy $script:SamplePolicy `
                                       -LicenseDatabase $script:MockLicenseDb

        $report.dependencies.Count | Should -Be 3
    }

    It 'marks approved, denied, and unknown dependencies correctly' {
        $report = New-ComplianceReport -ManifestPath $script:ManifestPath `
                                       -Policy $script:SamplePolicy `
                                       -LicenseDatabase $script:MockLicenseDb

        ($report.dependencies | Where-Object Name -eq 'lodash').status       | Should -Be 'approved'
        ($report.dependencies | Where-Object Name -eq 'copyleft-x').status   | Should -Be 'denied'
        ($report.dependencies | Where-Object Name -eq 'mystery-dep').status  | Should -Be 'unknown'
    }

    It 'records the resolved license (or "unknown") for each dependency' {
        $report = New-ComplianceReport -ManifestPath $script:ManifestPath `
                                       -Policy $script:SamplePolicy `
                                       -LicenseDatabase $script:MockLicenseDb

        ($report.dependencies | Where-Object Name -eq 'lodash').license       | Should -Be 'MIT'
        ($report.dependencies | Where-Object Name -eq 'copyleft-x').license   | Should -Be 'GPL-3.0'
        ($report.dependencies | Where-Object Name -eq 'mystery-dep').license  | Should -Be 'unknown'
    }

    It 'summarises counts per status in the report header' {
        $report = New-ComplianceReport -ManifestPath $script:ManifestPath `
                                       -Policy $script:SamplePolicy `
                                       -LicenseDatabase $script:MockLicenseDb

        $report.summary.approved | Should -Be 1
        $report.summary.denied   | Should -Be 1
        $report.summary.unknown  | Should -Be 1
        $report.summary.total    | Should -Be 3
    }

    It 'sets compliant=false when any dependency is denied' {
        $report = New-ComplianceReport -ManifestPath $script:ManifestPath `
                                       -Policy $script:SamplePolicy `
                                       -LicenseDatabase $script:MockLicenseDb

        $report.compliant | Should -Be $false
    }

    It 'sets compliant=true when every dependency is approved' {
        $tmp = New-TemporaryFile
        @{
            name         = 'all-good'
            dependencies = @{ lodash = '1'; express = '1'; 'left-pad' = '1' }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp

        $report = New-ComplianceReport -ManifestPath $tmp `
                                       -Policy $script:SamplePolicy `
                                       -LicenseDatabase $script:MockLicenseDb

        $report.compliant        | Should -Be $true
        $report.summary.approved | Should -Be 3
        $report.summary.denied   | Should -Be 0

        Remove-Item $tmp -Force
    }
}
