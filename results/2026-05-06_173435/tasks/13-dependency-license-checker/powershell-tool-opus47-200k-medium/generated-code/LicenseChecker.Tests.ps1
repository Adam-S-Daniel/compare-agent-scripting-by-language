# Pester tests for the LicenseChecker module.
# Written first (red), then code is implemented to make them pass (green).

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'LicenseChecker.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Read-DependencyManifest' {

    It 'parses package.json dependencies and devDependencies' {
        $tmp = New-TemporaryFile
        @'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21",
    "express": "4.18.2"
  },
  "devDependencies": {
    "jest": "29.0.0"
  }
}
'@ | Set-Content -Path $tmp.FullName -Encoding utf8

        $deps = Read-DependencyManifest -Path $tmp.FullName
        Remove-Item $tmp.FullName -Force

        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -EQ 'lodash').Version  | Should -Be '^4.17.21'
        ($deps | Where-Object Name -EQ 'express').Version | Should -Be '4.18.2'
        ($deps | Where-Object Name -EQ 'jest').Version    | Should -Be '29.0.0'
    }

    It 'parses requirements.txt with version specifiers and skips comments/blank lines' {
        $tmp = [System.IO.Path]::GetTempFileName() + '.txt'
        @'
# python deps
requests==2.31.0
flask>=2.0,<3.0

numpy~=1.26.0
'@ | Set-Content -Path $tmp -Encoding utf8

        $deps = Read-DependencyManifest -Path $tmp
        Remove-Item $tmp -Force

        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -EQ 'requests').Version | Should -Be '==2.31.0'
        ($deps | Where-Object Name -EQ 'flask').Version    | Should -Be '>=2.0,<3.0'
        ($deps | Where-Object Name -EQ 'numpy').Version    | Should -Be '~=1.26.0'
    }

    It 'throws a meaningful error if the manifest does not exist' {
        { Read-DependencyManifest -Path '/no/such/file.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Test-LicenseCompliance' {

    BeforeAll {
        $script:Config = @{
            Allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            Deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'returns Approved when license is on the allow-list' {
        Test-LicenseCompliance -License 'MIT' -Config $script:Config |
            Should -Be 'Approved'
    }

    It 'returns Denied when license is on the deny-list' {
        Test-LicenseCompliance -License 'GPL-3.0' -Config $script:Config |
            Should -Be 'Denied'
    }

    It 'returns Unknown when license is on neither list' {
        Test-LicenseCompliance -License 'WTFPL' -Config $script:Config |
            Should -Be 'Unknown'
    }

    It 'returns Unknown when license is null or empty' {
        Test-LicenseCompliance -License $null  -Config $script:Config | Should -Be 'Unknown'
        Test-LicenseCompliance -License ''     -Config $script:Config | Should -Be 'Unknown'
    }

    It 'treats deny-list as authoritative even if also on allow-list' {
        $cfg = @{ Allow = @('MIT'); Deny = @('MIT') }
        Test-LicenseCompliance -License 'MIT' -Config $cfg | Should -Be 'Denied'
    }
}

Describe 'Invoke-LicenseCheck (full report)' {

    BeforeAll {
        $script:Manifest = New-TemporaryFile
        @'
{
  "dependencies": {
    "lodash": "4.17.21",
    "leftpad": "1.0.0",
    "evilpkg": "0.1.0",
    "mysterypkg": "0.0.1"
  }
}
'@ | Set-Content -Path $script:Manifest.FullName -Encoding utf8

        # Mock license lookup: deterministic, no network.
        $script:LicenseMap = @{
            'lodash'     = 'MIT'
            'leftpad'    = 'BSD-3-Clause'
            'evilpkg'    = 'GPL-3.0'
            'mysterypkg' = 'CustomWeirdLicense'
        }
        $script:Lookup = { param($name) $script:LicenseMap[$name] }

        $script:Config = @{
            Allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            Deny  = @('GPL-3.0')
        }
    }

    AfterAll {
        if (Test-Path $script:Manifest.FullName) {
            Remove-Item $script:Manifest.FullName -Force
        }
    }

    It 'produces a report with one entry per dependency' {
        $report = Invoke-LicenseCheck -ManifestPath $script:Manifest.FullName `
            -Config $script:Config -LicenseLookup $script:Lookup
        $report.Count | Should -Be 4
    }

    It 'classifies each dependency correctly' {
        $report = Invoke-LicenseCheck -ManifestPath $script:Manifest.FullName `
            -Config $script:Config -LicenseLookup $script:Lookup

        ($report | Where-Object Name -EQ 'lodash').Status     | Should -Be 'Approved'
        ($report | Where-Object Name -EQ 'leftpad').Status    | Should -Be 'Approved'
        ($report | Where-Object Name -EQ 'evilpkg').Status    | Should -Be 'Denied'
        ($report | Where-Object Name -EQ 'mysterypkg').Status | Should -Be 'Unknown'
    }

    It 'records the resolved license string on each report row' {
        $report = Invoke-LicenseCheck -ManifestPath $script:Manifest.FullName `
            -Config $script:Config -LicenseLookup $script:Lookup
        ($report | Where-Object Name -EQ 'lodash').License  | Should -Be 'MIT'
        ($report | Where-Object Name -EQ 'evilpkg').License | Should -Be 'GPL-3.0'
    }

    It 'reports Unknown when the license lookup returns null' {
        $lookup = { param($n) $null }
        $report = Invoke-LicenseCheck -ManifestPath $script:Manifest.FullName `
            -Config $script:Config -LicenseLookup $lookup
        ($report | ForEach-Object Status) | Should -Not -Contain 'Approved'
        ($report | Where-Object Name -EQ 'lodash').Status | Should -Be 'Unknown'
    }
}

Describe 'Format-ComplianceReport' {

    It 'renders a summary line with counts of each status' {
        $rows = @(
            [pscustomobject]@{ Name='a'; Version='1'; License='MIT';     Status='Approved' }
            [pscustomobject]@{ Name='b'; Version='1'; License='GPL-3.0'; Status='Denied'   }
            [pscustomobject]@{ Name='c'; Version='1'; License='?';       Status='Unknown'  }
            [pscustomobject]@{ Name='d'; Version='1'; License='MIT';     Status='Approved' }
        )
        $text = Format-ComplianceReport -Report $rows
        $text | Should -Match 'Approved:\s*2'
        $text | Should -Match 'Denied:\s*1'
        $text | Should -Match 'Unknown:\s*1'
    }

    It 'lists every dependency with its name, version, license, and status' {
        $rows = @(
            [pscustomobject]@{ Name='lodash'; Version='4.17.21'; License='MIT'; Status='Approved' }
        )
        $text = Format-ComplianceReport -Report $rows
        $text | Should -Match 'lodash'
        $text | Should -Match '4\.17\.21'
        $text | Should -Match 'MIT'
        $text | Should -Match 'Approved'
    }
}
