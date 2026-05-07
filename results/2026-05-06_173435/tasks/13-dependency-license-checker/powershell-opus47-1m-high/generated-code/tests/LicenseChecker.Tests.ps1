# Pester tests for LicenseChecker.psm1
#
# These tests were written red-first (failing tests before implementation):
# 1) parser tests (no implementation -> Get-ManifestDependency missing)
# 2) compliance classifier tests (allow / deny / unknown branches)
# 3) license-resolver mock tests
# 4) report formatter tests
# 5) end-to-end orchestrator tests using fixture files
#
# All license lookups are mocked. The real CLI surface (Invoke-LicenseCheck)
# accepts a -LicenseData hashtable or -LicenseDataPath JSON file, both of which
# the tests use.

BeforeAll {
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:ModuleRoot 'src/LicenseChecker.psm1') -Force

    $script:FixtureRoot = Join-Path $script:ModuleRoot 'fixtures'
}

Describe 'Get-ManifestDependency' {
    Context 'package.json manifests' {
        It 'parses dependencies and devDependencies and strips version prefixes' {
            $deps = Get-ManifestDependency -Path (Join-Path $script:FixtureRoot 'package.basic.json')

            $deps | Should -HaveCount 3
            ($deps | Where-Object Name -EQ 'lodash').Version          | Should -Be '4.17.21'
            ($deps | Where-Object Name -EQ 'lodash').Scope            | Should -Be 'dependencies'
            ($deps | Where-Object Name -EQ 'left-pad').Version        | Should -Be '1.3.0'
            ($deps | Where-Object Name -EQ 'jest').Scope              | Should -Be 'devDependencies'
        }

        It 'returns an empty array when there are no dependencies' {
            $deps = Get-ManifestDependency -Path (Join-Path $script:FixtureRoot 'package.empty.json')
            ,$deps | Should -BeOfType [System.Array]
            $deps.Count | Should -Be 0
        }

        It 'throws on malformed JSON' {
            $bad = Join-Path $TestDrive 'bad.package.json'
            Set-Content -Path $bad -Value '{ this is not json'
            { Get-ManifestDependency -Path $bad } | Should -Throw -ExpectedMessage '*Failed to parse JSON*'
        }
    }

    Context 'requirements.txt manifests' {
        It 'parses pinned and unpinned entries and skips comments' {
            $req = Join-Path $TestDrive 'requirements.txt'
            Set-Content -Path $req -Value @(
                '# pinned production deps',
                'requests==2.31.0',
                'urllib3>=1.26.0',
                'flask  # web framework',
                ''
            )
            $deps = Get-ManifestDependency -Path $req
            $deps | Should -HaveCount 3
            ($deps | Where-Object Name -EQ 'requests').Version | Should -Be '2.31.0'
            ($deps | Where-Object Name -EQ 'flask').Version    | Should -Be ''
        }
    }

    It 'throws when the manifest file does not exist' {
        { Get-ManifestDependency -Path (Join-Path $TestDrive 'nope.json') } |
            Should -Throw -ExpectedMessage '*Manifest not found*'
    }

    It 'throws when given an unsupported manifest format' {
        $weird = Join-Path $TestDrive 'cargo.toml'
        Set-Content -Path $weird -Value '[package]'
        { Get-ManifestDependency -Path $weird } | Should -Throw -ExpectedMessage '*Unsupported manifest format*'
    }
}

Describe 'Test-LicenseCompliance' {
    BeforeAll {
        $script:Allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
        $script:Deny  = @('GPL-3.0', 'AGPL-3.0')
    }

    It 'returns approved for allow-listed licenses (case-insensitive)' {
        Test-LicenseCompliance -License 'mit'        -AllowList $script:Allow -DenyList $script:Deny | Should -Be 'approved'
        Test-LicenseCompliance -License 'Apache-2.0' -AllowList $script:Allow -DenyList $script:Deny | Should -Be 'approved'
    }

    It 'returns denied for deny-listed licenses' {
        Test-LicenseCompliance -License 'GPL-3.0' -AllowList $script:Allow -DenyList $script:Deny | Should -Be 'denied'
    }

    It 'returns denied when a license is in both allow and deny (deny wins)' {
        Test-LicenseCompliance -License 'GPL-3.0' `
            -AllowList @('GPL-3.0') -DenyList @('GPL-3.0') | Should -Be 'denied'
    }

    It 'returns unknown for licenses outside both lists' {
        Test-LicenseCompliance -License 'WTFPL' -AllowList $script:Allow -DenyList $script:Deny | Should -Be 'unknown'
    }

    It 'returns unknown when license is null or empty' {
        Test-LicenseCompliance -License $null -AllowList $script:Allow -DenyList $script:Deny | Should -Be 'unknown'
        Test-LicenseCompliance -License ''    -AllowList $script:Allow -DenyList $script:Deny | Should -Be 'unknown'
    }
}

Describe 'Get-DependencyLicense (mock)' {
    It 'returns the license for a package@version key' {
        $data = @{ 'lodash@4.17.21' = 'MIT' }
        Get-DependencyLicense -Name 'lodash' -Version '4.17.21' -LicenseData $data | Should -Be 'MIT'
    }

    It 'falls back to the bare package name when no version match exists' {
        $data = @{ 'left-pad' = 'WTFPL' }
        Get-DependencyLicense -Name 'left-pad' -Version '1.0.0' -LicenseData $data | Should -Be 'WTFPL'
    }

    It 'returns $null when no fixture data is supplied' {
        Get-DependencyLicense -Name 'requests' -Version '2.31.0' | Should -BeNullOrEmpty
    }

    It 'returns $null when the package is not in the fixture' {
        Get-DependencyLicense -Name 'foo' -Version '1.0.0' -LicenseData @{} | Should -BeNullOrEmpty
    }
}

Describe 'New-LicenseReport' {
    It 'summarises status counts and marks NON-COMPLIANT when a denied dep is present' {
        $findings = @(
            [pscustomobject]@{ Name='a'; Version='1'; Scope='dependencies'; License='MIT';     Status='approved' }
            [pscustomobject]@{ Name='b'; Version='2'; Scope='dependencies'; License='GPL-3.0'; Status='denied'   }
            [pscustomobject]@{ Name='c'; Version='3'; Scope='dependencies'; License=$null;     Status='unknown'  }
        )
        $report = New-LicenseReport -Findings $findings
        $report.Total     | Should -Be 3
        $report.Approved  | Should -Be 1
        $report.Denied    | Should -Be 1
        $report.Unknown   | Should -Be 1
        $report.Compliant | Should -BeFalse
        $report.Text      | Should -Match 'Status\s+:\s+NON-COMPLIANT'
        $report.Text      | Should -Match 'b@2 \| license=GPL-3\.0 \| status=denied'
        $report.Text      | Should -Match 'c@3 \| license=<none> \| status=unknown'
    }

    It 'is COMPLIANT when nothing is denied' {
        $findings = @(
            [pscustomobject]@{ Name='a'; Version='1'; Scope='dependencies'; License='MIT'; Status='approved' }
        )
        $report = New-LicenseReport -Findings $findings
        $report.Compliant | Should -BeTrue
        $report.Text      | Should -Match 'Status\s+:\s+COMPLIANT'
    }
}

Describe 'Invoke-LicenseCheck (end-to-end with fixtures)' {
    It 'classifies dependencies correctly for the all-approved fixture' {
        $report = Invoke-LicenseCheck `
            -ManifestPath    (Join-Path $script:FixtureRoot 'package.basic.json') `
            -ConfigPath      (Join-Path $script:FixtureRoot 'license-config.json') `
            -LicenseDataPath (Join-Path $script:FixtureRoot 'license-data.allgood.json')

        $report.Compliant | Should -BeTrue
        $report.Approved  | Should -Be 3
        $report.Denied    | Should -Be 0
        $report.Unknown   | Should -Be 0
    }

    It 'flags denied and unknown dependencies for the mixed fixture' {
        $report = Invoke-LicenseCheck `
            -ManifestPath    (Join-Path $script:FixtureRoot 'package.basic.json') `
            -ConfigPath      (Join-Path $script:FixtureRoot 'license-config.json') `
            -LicenseDataPath (Join-Path $script:FixtureRoot 'license-data.mixed.json')

        $report.Compliant | Should -BeFalse
        $report.Approved  | Should -Be 1
        $report.Denied    | Should -Be 1
        $report.Unknown   | Should -Be 1

        ($report.Findings | Where-Object Name -EQ 'lodash').Status   | Should -Be 'approved'
        ($report.Findings | Where-Object Name -EQ 'left-pad').Status | Should -Be 'denied'
        ($report.Findings | Where-Object Name -EQ 'jest').Status     | Should -Be 'unknown'
    }

    It 'throws a meaningful error when the config file is missing' {
        {
            Invoke-LicenseCheck `
                -ManifestPath (Join-Path $script:FixtureRoot 'package.basic.json') `
                -ConfigPath   (Join-Path $TestDrive 'no-such-config.json')
        } | Should -Throw -ExpectedMessage '*Config not found*'
    }
}
