# Pester tests for the Dependency License Checker.
# Tests are written red/green: each `Describe` block was introduced before the
# corresponding production code. The license lookup is mocked so tests do not
# reach the network.

BeforeAll {
    . $PSScriptRoot/DependencyLicenseChecker.ps1
}

Describe 'Read-Manifest' {
    It 'extracts dependencies and versions from a package.json' {
        $path = Join-Path $TestDrive 'package.json'
        @'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21",
    "express": "4.18.2"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  }
}
'@ | Set-Content -Path $path -Encoding utf8

        $deps = Read-Manifest -Path $path

        $deps | Should -HaveCount 3
        ($deps | Where-Object Name -eq 'lodash').Version   | Should -Be '^4.17.21'
        ($deps | Where-Object Name -eq 'express').Version  | Should -Be '4.18.2'
        ($deps | Where-Object Name -eq 'jest').Version     | Should -Be '^29.0.0'
    }

    It 'extracts dependencies and versions from a requirements.txt' {
        $path = Join-Path $TestDrive 'requirements.txt'
        @'
# comment — should be ignored
requests==2.31.0
flask>=2.3.0
pytest~=7.4

django
'@ | Set-Content -Path $path -Encoding utf8

        $deps = Read-Manifest -Path $path

        $deps | Should -HaveCount 4
        ($deps | Where-Object Name -eq 'requests').Version | Should -Be '2.31.0'
        ($deps | Where-Object Name -eq 'flask').Version    | Should -Be '2.3.0'
        ($deps | Where-Object Name -eq 'pytest').Version   | Should -Be '7.4'
        ($deps | Where-Object Name -eq 'django').Version   | Should -Be 'unspecified'
    }

    It 'throws a meaningful error when the manifest does not exist' {
        { Read-Manifest -Path (Join-Path $TestDrive 'missing.json') } |
            Should -Throw -ExpectedMessage '*manifest not found*'
    }

    It 'throws a meaningful error for unsupported manifest formats' {
        $path = Join-Path $TestDrive 'Gemfile'
        'source "https://rubygems.org"' | Set-Content -Path $path
        { Read-Manifest -Path $path } |
            Should -Throw -ExpectedMessage '*unsupported manifest*'
    }
}

Describe 'Get-DependencyLicense' {
    It 'returns the mocked license for a known dependency' {
        $lookup = @{ 'lodash' = 'MIT' }
        Get-DependencyLicense -Name 'lodash' -Version '4.17.21' -LookupTable $lookup |
            Should -Be 'MIT'
    }

    It 'returns UNKNOWN when the dependency is not in the lookup' {
        $lookup = @{}
        Get-DependencyLicense -Name 'does-not-exist' -Version '0.0.0' -LookupTable $lookup |
            Should -Be 'UNKNOWN'
    }
}

Describe 'Get-ComplianceStatus' {
    BeforeAll {
        $script:config = @{
            allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'returns approved when the license is on the allow list' {
        Get-ComplianceStatus -License 'MIT' -Config $script:config | Should -Be 'approved'
    }

    It 'returns denied when the license is on the deny list' {
        Get-ComplianceStatus -License 'GPL-3.0' -Config $script:config | Should -Be 'denied'
    }

    It 'returns unknown when the license appears on neither list' {
        Get-ComplianceStatus -License 'WTFPL' -Config $script:config | Should -Be 'unknown'
    }

    It 'returns unknown when the license is the literal UNKNOWN sentinel' {
        Get-ComplianceStatus -License 'UNKNOWN' -Config $script:config | Should -Be 'unknown'
    }

    It 'treats deny-list matches as denied even if also on allow-list' {
        $overlap = @{ allow = @('MIT', 'GPL-3.0'); deny = @('GPL-3.0') }
        Get-ComplianceStatus -License 'GPL-3.0' -Config $overlap | Should -Be 'denied'
    }
}

Describe 'Invoke-LicenseCheck' {
    BeforeAll {
        # Shared fixtures for the compliance report tests. The manifest must
        # live in its own directory so the canonical filename is preserved.
        $manifestDir = Join-Path $TestDrive 'app'
        New-Item -ItemType Directory -Path $manifestDir | Out-Null
        $script:manifest = Join-Path $manifestDir 'package.json'
        @'
{
  "name": "demo",
  "dependencies": {
    "lodash": "4.17.21",
    "left-pad": "1.3.0",
    "secret-sauce": "0.1.0"
  }
}
'@ | Set-Content -Path $script:manifest -Encoding utf8

        $script:configPath = Join-Path $TestDrive 'licenses.json'
        @'
{
  "allow": ["MIT", "Apache-2.0"],
  "deny":  ["GPL-3.0"]
}
'@ | Set-Content -Path $script:configPath -Encoding utf8

        $script:lookup = @{
            'lodash'   = 'MIT'
            'left-pad' = 'GPL-3.0'
            # `secret-sauce` intentionally omitted to exercise the UNKNOWN path.
        }
    }

    It 'produces a per-dependency status report' {
        $report = Invoke-LicenseCheck -ManifestPath $script:manifest `
                                      -ConfigPath   $script:configPath `
                                      -LookupTable  $script:lookup

        $report.Results             | Should -HaveCount 3
        $report.Summary.Approved    | Should -Be 1
        $report.Summary.Denied      | Should -Be 1
        $report.Summary.Unknown     | Should -Be 1
        $report.Summary.HasDenied   | Should -BeTrue

        $byName = @{}
        foreach ($row in $report.Results) { $byName[$row.Name] = $row }
        $byName['lodash'].Status       | Should -Be 'approved'
        $byName['lodash'].License      | Should -Be 'MIT'
        $byName['left-pad'].Status     | Should -Be 'denied'
        $byName['secret-sauce'].Status | Should -Be 'unknown'
        $byName['secret-sauce'].License| Should -Be 'UNKNOWN'
    }

    It 'throws when the config file is missing' {
        { Invoke-LicenseCheck -ManifestPath $script:manifest `
                              -ConfigPath   (Join-Path $TestDrive 'nope.json') `
                              -LookupTable  $script:lookup } |
            Should -Throw -ExpectedMessage '*config not found*'
    }

    It 'throws when the config JSON is missing required keys' {
        $bad = Join-Path $TestDrive 'bad-config.json'
        '{"allow": ["MIT"]}' | Set-Content -Path $bad -Encoding utf8
        { Invoke-LicenseCheck -ManifestPath $script:manifest `
                              -ConfigPath   $bad `
                              -LookupTable  $script:lookup } |
            Should -Throw -ExpectedMessage '*must contain*allow*deny*'
    }
}

Describe 'Format-ComplianceReport' {
    It 'renders a human-readable markdown-ish report' {
        $report = [pscustomobject]@{
            Results = @(
                [pscustomobject]@{ Name='lodash';   Version='4.17.21'; License='MIT';     Status='approved' }
                [pscustomobject]@{ Name='left-pad'; Version='1.3.0';   License='GPL-3.0'; Status='denied'   }
                [pscustomobject]@{ Name='mystery';  Version='0.0.1';   License='UNKNOWN'; Status='unknown'  }
            )
            Summary = [pscustomobject]@{
                Approved  = 1
                Denied    = 1
                Unknown   = 1
                Total     = 3
                HasDenied = $true
            }
        }

        $text = Format-ComplianceReport -Report $report

        $text | Should -Match 'lodash'
        $text | Should -Match 'left-pad'
        $text | Should -Match 'mystery'
        $text | Should -Match 'approved: 1'
        $text | Should -Match 'denied: 1'
        $text | Should -Match 'unknown: 1'
    }
}

Describe 'Workflow file' {
    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot '.github/workflows/dependency-license-checker.yml'
    }

    It 'exists at the canonical path' {
        Test-Path $script:workflowPath | Should -BeTrue
    }

    It 'passes actionlint' {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlint) { Set-ItResult -Skipped -Because 'actionlint not installed' }
        $result = & actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($result | Out-String)
    }

    It 'defines the expected triggers and references the script' {
        $yaml = Get-Content -Raw $script:workflowPath
        $yaml | Should -Match 'push:'
        $yaml | Should -Match 'pull_request:'
        $yaml | Should -Match 'workflow_dispatch:'
        $yaml | Should -Match 'DependencyLicenseChecker\.ps1'
        # Ensure every `run:` step declares `shell: pwsh` (we don't use bash).
        $yaml | Should -Match 'shell: pwsh'
    }

    It 'references scripts and configs that exist on disk' {
        $script:workflowPath | Should -Exist
        (Join-Path $PSScriptRoot 'DependencyLicenseChecker.ps1')     | Should -Exist
        (Join-Path $PSScriptRoot 'fixtures/licenses-config.json')    | Should -Exist
        (Join-Path $PSScriptRoot 'fixtures/mock-license-db.json')    | Should -Exist
    }
}
