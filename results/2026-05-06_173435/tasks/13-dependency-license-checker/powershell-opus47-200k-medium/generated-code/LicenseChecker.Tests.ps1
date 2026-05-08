# Pester tests for the dependency license checker.
# Written TDD-style: each Describe block was added as a failing test
# before the corresponding implementation in LicenseChecker.ps1.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'LicenseChecker.ps1'
    . $script:ModulePath
}

Describe 'Get-DependencyList' {
    It 'parses dependencies and devDependencies from package.json' {
        $tmp = New-TemporaryFile
        @'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": { "express": "^4.18.0", "lodash": "4.17.21" },
  "devDependencies": { "jest": "^29.0.0" }
}
'@ | Set-Content -Path $tmp

        $deps = Get-DependencyList -Path $tmp
        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -eq 'express').Version | Should -Be '^4.18.0'
        ($deps | Where-Object Name -eq 'lodash').Version  | Should -Be '4.17.21'
        ($deps | Where-Object Name -eq 'jest').Version    | Should -Be '^29.0.0'
        Remove-Item $tmp
    }

    It 'parses requirements.txt format' {
        $tmp = New-TemporaryFile
        @'
# comment line
requests==2.31.0
flask>=2.0.0
black

  pytest~=7.4
'@ | Set-Content -Path $tmp

        $deps = Get-DependencyList -Path $tmp -Format requirements
        $deps.Count | Should -Be 4
        ($deps | Where-Object Name -eq 'requests').Version | Should -Be '2.31.0'
        ($deps | Where-Object Name -eq 'flask').Version    | Should -Be '2.0.0'
        ($deps | Where-Object Name -eq 'black').Version    | Should -Be 'unspecified'
        Remove-Item $tmp
    }

    It 'auto-detects package.json by file name' {
        $dir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $pkg = Join-Path $dir 'package.json'
        '{ "dependencies": { "react": "18.0.0" } }' | Set-Content -Path $pkg
        $deps = Get-DependencyList -Path $pkg
        $deps.Count | Should -Be 1
        Remove-Item $dir -Recurse
    }

    It 'throws a meaningful error if the file does not exist' {
        { Get-DependencyList -Path '/nonexistent/missing-file.json' } |
            Should -Throw '*not found*'
    }

    It 'throws a meaningful error if package.json is malformed' {
        $tmp = New-TemporaryFile
        '{ this is not json' | Set-Content -Path $tmp
        { Get-DependencyList -Path $tmp -Format package } |
            Should -Throw '*Failed to parse*'
        Remove-Item $tmp
    }
}

Describe 'Get-DependencyLicense (mock)' {
    It 'returns a license string for a known dependency' {
        $map = @{ express = 'MIT'; lodash = 'MIT'; jest = 'MIT' }
        Get-DependencyLicense -Name 'express' -Version '4.18.0' -LicenseMap $map |
            Should -Be 'MIT'
    }

    It 'returns "UNKNOWN" when the dependency is missing from the lookup' {
        $map = @{ express = 'MIT' }
        Get-DependencyLicense -Name 'mystery-pkg' -Version '1.0.0' -LicenseMap $map |
            Should -Be 'UNKNOWN'
    }
}

Describe 'Test-LicenseCompliance' {
    BeforeAll {
        $script:cfg = @{
            allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'classifies an allowed license as Approved' {
        Test-LicenseCompliance -License 'MIT' -Config $cfg | Should -Be 'Approved'
    }

    It 'classifies a denied license as Denied' {
        Test-LicenseCompliance -License 'GPL-3.0' -Config $cfg | Should -Be 'Denied'
    }

    It 'classifies an unlisted license as Unknown' {
        Test-LicenseCompliance -License 'WTFPL' -Config $cfg | Should -Be 'Unknown'
    }

    It 'classifies UNKNOWN license token as Unknown' {
        Test-LicenseCompliance -License 'UNKNOWN' -Config $cfg | Should -Be 'Unknown'
    }

    It 'is case-insensitive in matching' {
        Test-LicenseCompliance -License 'mit' -Config $cfg | Should -Be 'Approved'
    }
}

Describe 'New-ComplianceReport' {
    BeforeEach {
        $script:tmp     = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $script:manif   = Join-Path $tmp 'package.json'
        $script:cfgPath = Join-Path $tmp 'licenses.json'
        $script:lookup  = Join-Path $tmp 'lookup.json'

        @'
{
  "dependencies": {
    "express": "4.18.0",
    "evil-pkg": "1.0.0",
    "mystery": "0.1.0"
  }
}
'@ | Set-Content -Path $manif

        @'
{
  "allow": ["MIT", "Apache-2.0"],
  "deny":  ["GPL-3.0"]
}
'@ | Set-Content -Path $cfgPath

        @'
{
  "express":  "MIT",
  "evil-pkg": "GPL-3.0"
}
'@ | Set-Content -Path $lookup
    }

    AfterEach {
        Remove-Item $tmp -Recurse -Force
    }

    It 'produces a report row per dependency with license + status' {
        $report = New-ComplianceReport -ManifestPath $manif `
                                       -ConfigPath $cfgPath `
                                       -LookupPath $lookup
        $report.Count | Should -Be 3
        ($report | Where-Object Name -eq 'express').Status  | Should -Be 'Approved'
        ($report | Where-Object Name -eq 'evil-pkg').Status | Should -Be 'Denied'
        ($report | Where-Object Name -eq 'mystery').Status  | Should -Be 'Unknown'
        ($report | Where-Object Name -eq 'mystery').License | Should -Be 'UNKNOWN'
    }

    It 'aggregate summary counts each status correctly' {
        $report  = New-ComplianceReport -ManifestPath $manif -ConfigPath $cfgPath -LookupPath $lookup
        $summary = Get-ComplianceSummary -Report $report
        $summary.Total    | Should -Be 3
        $summary.Approved | Should -Be 1
        $summary.Denied   | Should -Be 1
        $summary.Unknown  | Should -Be 1
    }
}

Describe 'Invoke-LicenseChecker (CLI entry point)' {
    BeforeEach {
        $script:tmp    = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $script:manif  = Join-Path $tmp 'package.json'
        $script:cfg    = Join-Path $tmp 'licenses.json'
        $script:lookup = Join-Path $tmp 'lookup.json'
        $script:out    = Join-Path $tmp 'report.json'

        '{ "dependencies": { "express": "4.18.0", "evil-pkg": "1.0.0" } }' |
            Set-Content -Path $manif
        '{ "allow": ["MIT"], "deny": ["GPL-3.0"] }' | Set-Content -Path $cfg
        '{ "express": "MIT", "evil-pkg": "GPL-3.0" }' | Set-Content -Path $lookup
    }

    AfterEach {
        Remove-Item $tmp -Recurse -Force
    }

    It 'writes a JSON report file when -OutputPath is given' {
        Invoke-LicenseChecker -ManifestPath $manif -ConfigPath $cfg -LookupPath $lookup -OutputPath $out -Quiet | Out-Null
        Test-Path $out | Should -BeTrue
        $obj = Get-Content $out -Raw | ConvertFrom-Json
        $obj.summary.Denied | Should -Be 1
        $obj.report.Count   | Should -Be 2
    }

    It 'returns a non-zero failure count when any license is denied' {
        $result = Invoke-LicenseChecker -ManifestPath $manif -ConfigPath $cfg -LookupPath $lookup -Quiet
        $result.Summary.Denied | Should -Be 1
    }
}
