# Pester tests for LicenseChecker.ps1 — developed red/green TDD.
# Each Describe block corresponds to one TDD cycle: the test was added first,
# observed to fail, then the minimal code was written in LicenseChecker.ps1.

BeforeAll {
    . $PSScriptRoot/LicenseChecker.ps1
}

Describe 'Get-Dependencies (package.json parser)' {
    It 'extracts names and versions from dependencies + devDependencies' {
        $fixture = Join-Path $TestDrive 'package.json'
        @'
{
  "name": "fixture",
  "version": "1.0.0",
  "dependencies": { "lodash": "^4.17.21", "express": "4.18.0" },
  "devDependencies": { "jest": "29.0.0" }
}
'@ | Set-Content $fixture

        $deps = Get-Dependencies -ManifestPath $fixture
        $deps | Should -HaveCount 3
        ($deps | Where-Object Name -eq 'lodash').Version  | Should -Be '^4.17.21'
        ($deps | Where-Object Name -eq 'express').Version | Should -Be '4.18.0'
        ($deps | Where-Object Name -eq 'jest').Version    | Should -Be '29.0.0'
    }

    It 'throws a meaningful error if manifest is missing' {
        { Get-Dependencies -ManifestPath (Join-Path $TestDrive 'nope.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'returns an empty array if no dependencies sections exist' {
        $fixture = Join-Path $TestDrive 'empty.json'
        '{ "name": "x", "version": "0.0.1" }' | Set-Content $fixture
        ,(Get-Dependencies -ManifestPath $fixture) | Should -BeOfType ([array])
        (Get-Dependencies -ManifestPath $fixture).Count | Should -Be 0
    }
}

Describe 'Test-LicenseStatus (allow/deny classification)' {
    It 'marks license on allow-list as approved' {
        Test-LicenseStatus -License 'MIT' -Allow @('MIT','Apache-2.0') -Deny @('GPL-3.0') |
            Should -Be 'approved'
    }
    It 'marks license on deny-list as denied' {
        Test-LicenseStatus -License 'GPL-3.0' -Allow @('MIT') -Deny @('GPL-3.0') |
            Should -Be 'denied'
    }
    It 'marks unrecognized license as unknown' {
        Test-LicenseStatus -License 'WTFPL' -Allow @('MIT') -Deny @('GPL-3.0') |
            Should -Be 'unknown'
    }
    It 'marks null/empty license as unknown' {
        Test-LicenseStatus -License $null -Allow @('MIT') -Deny @() | Should -Be 'unknown'
    }
    It 'is case-insensitive on matches' {
        Test-LicenseStatus -License 'mit' -Allow @('MIT') -Deny @() | Should -Be 'approved'
    }
}

Describe 'Invoke-LicenseCheck (end-to-end with mocked lookup)' {
    It 'produces a report using an injected license-lookup function' {
        $manifest = Join-Path $TestDrive 'package.json'
        @'
{
  "dependencies": { "lodash": "^4.17.21", "evil-pkg": "1.0.0", "mystery": "0.1.0" }
}
'@ | Set-Content $manifest

        # Mock lookup: hashtable-based so tests are deterministic and offline.
        $lookup = {
            param($name, $version)
            @{ 'lodash' = 'MIT'; 'evil-pkg' = 'GPL-3.0' }[$name]
        }

        $report = Invoke-LicenseCheck `
            -ManifestPath $manifest `
            -AllowList @('MIT','Apache-2.0') `
            -DenyList  @('GPL-3.0') `
            -LicenseLookup $lookup

        $report | Should -HaveCount 3
        ($report | Where-Object Name -eq 'lodash').Status   | Should -Be 'approved'
        ($report | Where-Object Name -eq 'lodash').License  | Should -Be 'MIT'
        ($report | Where-Object Name -eq 'evil-pkg').Status | Should -Be 'denied'
        ($report | Where-Object Name -eq 'mystery').Status  | Should -Be 'unknown'
    }

    It 'reads allow/deny lists from a JSON config file' {
        $manifest = Join-Path $TestDrive 'package.json'
        '{ "dependencies": { "a": "1.0.0" } }' | Set-Content $manifest
        $config = Join-Path $TestDrive 'config.json'
        '{ "allow": ["MIT"], "deny": ["GPL-3.0"] }' | Set-Content $config

        $lookup = { param($n,$v) 'MIT' }
        $report = Invoke-LicenseCheck -ManifestPath $manifest -ConfigPath $config -LicenseLookup $lookup
        $report[0].Status | Should -Be 'approved'
    }
}

Describe 'Format-ComplianceReport' {
    It 'renders report as text with a summary line' {
        $report = @(
            [pscustomobject]@{ Name='a'; Version='1.0.0'; License='MIT';     Status='approved' }
            [pscustomobject]@{ Name='b'; Version='2.0.0'; License='GPL-3.0'; Status='denied'   }
            [pscustomobject]@{ Name='c'; Version='0.1.0'; License=$null;     Status='unknown'  }
        )
        $text = Format-ComplianceReport -Report $report
        $text | Should -Match 'a\s+1\.0\.0\s+MIT\s+approved'
        $text | Should -Match 'b\s+2\.0\.0\s+GPL-3\.0\s+denied'
        $text | Should -Match 'approved: 1'
        $text | Should -Match 'denied: 1'
        $text | Should -Match 'unknown: 1'
    }
}
