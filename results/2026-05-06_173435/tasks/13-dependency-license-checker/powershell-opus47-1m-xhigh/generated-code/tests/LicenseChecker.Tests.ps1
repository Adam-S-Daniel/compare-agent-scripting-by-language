# Pester tests for LicenseChecker - TDD red/green cycle.
#
# These tests follow the order in which functionality was developed.
# Each Describe block represents one TDD iteration: write the failing
# test, implement the minimum code to pass, refactor, repeat.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:RepoRoot 'src/LicenseChecker.psm1') -Force
    $script:FixturesRoot = Join-Path $script:RepoRoot 'fixtures'
}

Describe 'Get-DependencyManifest - package.json parsing' {
    It 'returns one entry per dependency in package.json' {
        $manifestPath = Join-Path $script:FixturesRoot 'package.json'
        $deps = Get-DependencyManifest -Path $manifestPath
        $deps | Should -HaveCount 4
    }

    It 'extracts name and version for each dependency' {
        $manifestPath = Join-Path $script:FixturesRoot 'package.json'
        $deps = Get-DependencyManifest -Path $manifestPath
        $express = $deps | Where-Object { $_.Name -eq 'express' }
        $express | Should -Not -BeNullOrEmpty
        $express.Version | Should -Be '4.18.2'
    }

    It 'includes both runtime and dev dependencies' {
        $manifestPath = Join-Path $script:FixturesRoot 'package.json'
        $deps = Get-DependencyManifest -Path $manifestPath
        ($deps | Where-Object { $_.Name -eq 'jest' }).Version | Should -Be '29.7.0'
    }

    It 'strips semver range prefixes like ^ and ~' {
        $manifestPath = Join-Path $script:FixturesRoot 'package.json'
        $deps = Get-DependencyManifest -Path $manifestPath
        # lodash is "^4.17.21" in fixture; expect plain 4.17.21
        ($deps | Where-Object { $_.Name -eq 'lodash' }).Version | Should -Be '4.17.21'
    }

    It 'throws a meaningful error when the file does not exist' {
        { Get-DependencyManifest -Path '/no/such/file.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error when the JSON is malformed' {
        # Use a .json extension so the format dispatcher routes to the JSON parser.
        $tmpJson = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.json')
        Set-Content -Path $tmpJson -Value '{ this is not json'
        try {
            { Get-DependencyManifest -Path $tmpJson } |
                Should -Throw -ExpectedMessage '*Failed to parse*'
        } finally {
            Remove-Item $tmpJson -Force
        }
    }
}

Describe 'Get-DependencyManifest - requirements.txt parsing' {
    It 'parses a requirements.txt file with == version pins' {
        $manifestPath = Join-Path $script:FixturesRoot 'requirements.txt'
        $deps = Get-DependencyManifest -Path $manifestPath
        $deps | Should -HaveCount 3
        ($deps | Where-Object { $_.Name -eq 'requests' }).Version | Should -Be '2.31.0'
        ($deps | Where-Object { $_.Name -eq 'flask' }).Version | Should -Be '3.0.0'
    }

    It 'ignores comments and blank lines' {
        $manifestPath = Join-Path $script:FixturesRoot 'requirements.txt'
        $deps = Get-DependencyManifest -Path $manifestPath
        $deps.Name | Should -Not -Contain '#'
        $deps | ForEach-Object { $_.Name | Should -Not -BeNullOrEmpty }
    }
}

Describe 'Get-LicenseInfo - mock license lookup' {
    It 'returns a license string for a known dependency' {
        # The mock database is bundled with the module for offline determinism.
        $info = Get-LicenseInfo -Name 'express' -Version '4.18.2'
        $info.License | Should -Be 'MIT'
    }

    It 'returns Unknown for a dependency not in the mock database' {
        $info = Get-LicenseInfo -Name 'totally-made-up-pkg' -Version '1.0.0'
        $info.License | Should -Be 'UNKNOWN'
    }

    It 'allows callers to inject a custom license database for testability' {
        $custom = @{ 'foo' = 'BSD-3-Clause' }
        $info = Get-LicenseInfo -Name 'foo' -Version '1.0.0' -LicenseDatabase $custom
        $info.License | Should -Be 'BSD-3-Clause'
    }
}

Describe 'Test-LicenseCompliance - allow/deny evaluation' {
    BeforeAll {
        $script:Policy = @{
            Allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            Deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'reports Approved when license is on the allow list' {
        $r = Test-LicenseCompliance -License 'MIT' -Policy $script:Policy
        $r.Status | Should -Be 'Approved'
    }

    It 'reports Denied when license is on the deny list' {
        $r = Test-LicenseCompliance -License 'GPL-3.0' -Policy $script:Policy
        $r.Status | Should -Be 'Denied'
    }

    It 'reports Unknown when license is on neither list' {
        $r = Test-LicenseCompliance -License 'WTFPL' -Policy $script:Policy
        $r.Status | Should -Be 'Unknown'
    }

    It 'reports Unknown when license is the literal UNKNOWN sentinel' {
        $r = Test-LicenseCompliance -License 'UNKNOWN' -Policy $script:Policy
        $r.Status | Should -Be 'Unknown'
    }

    It 'is case-insensitive for license matching' {
        $r = Test-LicenseCompliance -License 'mit' -Policy $script:Policy
        $r.Status | Should -Be 'Approved'
    }

    It 'prefers Deny over Allow when a license appears on both lists' {
        $contradictory = @{ Allow = @('MIT'); Deny = @('MIT') }
        $r = Test-LicenseCompliance -License 'MIT' -Policy $contradictory
        $r.Status | Should -Be 'Denied'
    }
}

Describe 'Invoke-LicenseCheck - end-to-end orchestration' {
    BeforeAll {
        $script:ConfigPath = Join-Path $script:FixturesRoot 'license-policy.json'
        $script:ManifestPath = Join-Path $script:FixturesRoot 'package.json'
    }

    It 'returns one report row per dependency' {
        $report = Invoke-LicenseCheck -ManifestPath $script:ManifestPath -PolicyPath $script:ConfigPath
        $report.Results | Should -HaveCount 4
    }

    It 'each row contains Name, Version, License, Status' {
        $report = Invoke-LicenseCheck -ManifestPath $script:ManifestPath -PolicyPath $script:ConfigPath
        $row = $report.Results[0]
        $row.PSObject.Properties.Name | Should -Contain 'Name'
        $row.PSObject.Properties.Name | Should -Contain 'Version'
        $row.PSObject.Properties.Name | Should -Contain 'License'
        $row.PSObject.Properties.Name | Should -Contain 'Status'
    }

    It 'classifies the fixture data correctly' {
        $report = Invoke-LicenseCheck -ManifestPath $script:ManifestPath -PolicyPath $script:ConfigPath
        $byName = @{}
        foreach ($row in $report.Results) { $byName[$row.Name] = $row }
        # Fixture: express=MIT (allow), lodash=MIT (allow),
        #          some-gpl-pkg=GPL-3.0 (deny), jest=MIT (allow)
        $byName['express'].Status      | Should -Be 'Approved'
        $byName['lodash'].Status       | Should -Be 'Approved'
        $byName['some-gpl-pkg'].Status | Should -Be 'Denied'
        $byName['jest'].Status         | Should -Be 'Approved'
    }

    It 'aggregates Summary counts (ApprovedCount, DeniedCount, UnknownCount, Total)' {
        $report = Invoke-LicenseCheck -ManifestPath $script:ManifestPath -PolicyPath $script:ConfigPath
        $report.Summary.Total         | Should -Be 4
        $report.Summary.ApprovedCount | Should -Be 3
        $report.Summary.DeniedCount   | Should -Be 1
        $report.Summary.UnknownCount  | Should -Be 0
    }

    It 'sets Compliant=$false when there are any Denied dependencies' {
        $report = Invoke-LicenseCheck -ManifestPath $script:ManifestPath -PolicyPath $script:ConfigPath
        $report.Compliant | Should -BeFalse
    }

    It 'sets Compliant=$true when only allow-listed licenses are present' {
        # Use a manifest that contains only allow-listed deps.
        $tmp = New-TemporaryFile
        $tmpJson = "$($tmp.FullName).json"
        Move-Item -Path $tmp.FullName -Destination $tmpJson
        @{
            name = 'clean'
            dependencies = @{ express = '4.18.2' }
        } | ConvertTo-Json | Set-Content -Path $tmpJson
        try {
            $report = Invoke-LicenseCheck -ManifestPath $tmpJson -PolicyPath $script:ConfigPath
            $report.Compliant | Should -BeTrue
        } finally {
            Remove-Item $tmpJson -Force
        }
    }
}

Describe 'Format-ComplianceReport - human-readable output' {
    BeforeAll {
        $script:SampleReport = [pscustomobject]@{
            Compliant = $false
            Summary   = [pscustomobject]@{
                Total = 2; ApprovedCount = 1; DeniedCount = 1; UnknownCount = 0
            }
            Results = @(
                [pscustomobject]@{ Name='a'; Version='1.0'; License='MIT';     Status='Approved' }
                [pscustomobject]@{ Name='b'; Version='2.0'; License='GPL-3.0'; Status='Denied'   }
            )
        }
    }

    It 'renders a header line listing the compliance verdict' {
        $text = Format-ComplianceReport -Report $script:SampleReport
        $text | Should -Match 'NON-COMPLIANT'
    }

    It 'lists every dependency with its status' {
        $text = Format-ComplianceReport -Report $script:SampleReport
        $text | Should -Match 'a\s+1\.0\s+MIT\s+Approved'
        $text | Should -Match 'b\s+2\.0\s+GPL-3\.0\s+Denied'
    }

    It 'shows the summary counts' {
        $text = Format-ComplianceReport -Report $script:SampleReport
        $text | Should -Match 'Total:\s*2'
        $text | Should -Match 'Approved:\s*1'
        $text | Should -Match 'Denied:\s*1'
    }
}
