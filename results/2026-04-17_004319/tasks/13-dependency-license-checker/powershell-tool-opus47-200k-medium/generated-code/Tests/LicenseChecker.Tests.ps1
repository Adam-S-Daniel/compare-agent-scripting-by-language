# Pester tests for the license checker module.
# TDD: each Describe block was added with a failing test first, then implementation.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'LicenseChecker.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-DependencyList' {
    It 'parses package.json dependencies and devDependencies' {
        $json = @{
            dependencies    = @{ 'lodash' = '^4.17.21'; 'express' = '~4.18.0' }
            devDependencies = @{ 'jest'   = '^29.0.0' }
        } | ConvertTo-Json
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $json
        try {
            $deps = Get-DependencyList -Path $tmp -Format 'npm'
            $deps.Count | Should -Be 3
            ($deps | Where-Object Name -EQ 'lodash').Version | Should -Be '^4.17.21'
            ($deps | Where-Object Name -EQ 'jest').Version   | Should -Be '^29.0.0'
        } finally { Remove-Item $tmp -Force }
    }

    It 'parses requirements.txt with pinned and unpinned entries' {
        $tmp = New-TemporaryFile
        @('requests==2.31.0', 'flask>=2.0', '# comment line', '', 'numpy') |
            Set-Content -Path $tmp
        try {
            $deps = Get-DependencyList -Path $tmp -Format 'pip'
            $deps.Count | Should -Be 3
            ($deps | Where-Object Name -EQ 'requests').Version | Should -Be '2.31.0'
            ($deps | Where-Object Name -EQ 'numpy').Version    | Should -Be ''
        } finally { Remove-Item $tmp -Force }
    }

    It 'auto-detects format from filename' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "package.json"
        '{"dependencies":{"a":"1.0.0"}}' | Set-Content -Path $tmp
        try {
            $deps = Get-DependencyList -Path $tmp
            $deps[0].Name | Should -Be 'a'
        } finally { Remove-Item $tmp -Force }
    }

    It 'throws a meaningful error when the manifest is missing' {
        { Get-DependencyList -Path '/nonexistent/xyz.json' -Format 'npm' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Test-LicenseCompliance' {
    It 'classifies licenses against allow/deny lists' {
        $cfg = @{ Allow = @('MIT', 'Apache-2.0'); Deny = @('GPL-3.0') }
        (Test-LicenseCompliance -License 'MIT'      -Config $cfg) | Should -Be 'approved'
        (Test-LicenseCompliance -License 'GPL-3.0'  -Config $cfg) | Should -Be 'denied'
        (Test-LicenseCompliance -License 'BSD-2'    -Config $cfg) | Should -Be 'unknown'
        (Test-LicenseCompliance -License $null      -Config $cfg) | Should -Be 'unknown'
    }

    It 'is case-insensitive' {
        $cfg = @{ Allow = @('MIT'); Deny = @('GPL-3.0') }
        (Test-LicenseCompliance -License 'mit' -Config $cfg) | Should -Be 'approved'
    }
}

Describe 'New-ComplianceReport' {
    It 'builds a report using an injected license lookup function' {
        $deps = @(
            [pscustomobject]@{ Name = 'lodash';  Version = '4.17.21' }
            [pscustomobject]@{ Name = 'badpkg';  Version = '1.0.0' }
            [pscustomobject]@{ Name = 'mystery'; Version = '0.1.0' }
        )
        $cfg = @{ Allow = @('MIT'); Deny = @('GPL-3.0') }
        # Injected mock lookup avoids real network calls.
        $lookup = {
            param($name, $version)
            switch ($name) {
                'lodash'  { 'MIT' }
                'badpkg'  { 'GPL-3.0' }
                default   { $null }
            }
        }
        $report = New-ComplianceReport -Dependencies $deps -Config $cfg -LookupLicense $lookup
        $report.Results.Count | Should -Be 3
        ($report.Results | Where-Object Name -EQ 'lodash').Status  | Should -Be 'approved'
        ($report.Results | Where-Object Name -EQ 'badpkg').Status  | Should -Be 'denied'
        ($report.Results | Where-Object Name -EQ 'mystery').Status | Should -Be 'unknown'
        $report.Summary.approved | Should -Be 1
        $report.Summary.denied   | Should -Be 1
        $report.Summary.unknown  | Should -Be 1
    }

    It 'sets OverallCompliant=false when any denied licenses exist' {
        $deps = @([pscustomobject]@{ Name = 'x'; Version = '1' })
        $cfg = @{ Allow = @(); Deny = @('GPL-3.0') }
        $lookup = { 'GPL-3.0' }
        $r = New-ComplianceReport -Dependencies $deps -Config $cfg -LookupLicense $lookup
        $r.OverallCompliant | Should -BeFalse
    }

    It 'sets OverallCompliant=true when no denied licenses' {
        $deps = @([pscustomobject]@{ Name = 'x'; Version = '1' })
        $cfg = @{ Allow = @('MIT'); Deny = @('GPL-3.0') }
        $lookup = { 'MIT' }
        $r = New-ComplianceReport -Dependencies $deps -Config $cfg -LookupLicense $lookup
        $r.OverallCompliant | Should -BeTrue
    }
}

Describe 'Invoke-LicenseCheck (end-to-end with mock)' {
    It 'reads manifest + config and prints a report' {
        $tmpDir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        $manifest = Join-Path $tmpDir 'package.json'
        '{"dependencies":{"lodash":"^4.17.21","badpkg":"1.0.0"}}' | Set-Content $manifest
        $cfg = Join-Path $tmpDir 'licenses.json'
        '{"Allow":["MIT"],"Deny":["GPL-3.0"]}' | Set-Content $cfg
        $mock = Join-Path $tmpDir 'mock-licenses.json'
        '{"lodash":"MIT","badpkg":"GPL-3.0"}' | Set-Content $mock

        try {
            $result = Invoke-LicenseCheck -ManifestPath $manifest -ConfigPath $cfg -MockLicenseFile $mock
            $result.OverallCompliant | Should -BeFalse
            $result.Summary.approved | Should -Be 1
            $result.Summary.denied   | Should -Be 1
        } finally { Remove-Item $tmpDir -Recurse -Force }
    }
}
