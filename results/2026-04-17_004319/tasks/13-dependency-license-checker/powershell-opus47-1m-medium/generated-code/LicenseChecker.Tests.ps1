# Pester tests for the LicenseChecker module.
# Built via red/green TDD: each Describe block adds one responsibility.

BeforeAll {
    $script:Here = Split-Path -Parent $PSCommandPath
    Import-Module (Join-Path $script:Here 'LicenseChecker.psm1') -Force
}

Describe 'Get-DependenciesFromManifest' {

    It 'parses a package.json with dependencies and devDependencies' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $manifest = Join-Path $tmp 'package.json'
        @'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": { "left-pad": "^1.3.0", "lodash": "4.17.21" },
  "devDependencies": { "jest": "~29.0.0" }
}
'@ | Set-Content -LiteralPath $manifest

        $deps = Get-DependenciesFromManifest -Path $manifest
        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -eq 'left-pad').Version | Should -Be '1.3.0'
        ($deps | Where-Object Name -eq 'lodash').Version   | Should -Be '4.17.21'
        ($deps | Where-Object Name -eq 'jest').Version     | Should -Be '29.0.0'
    }

    It 'parses requirements.txt entries' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $manifest = Join-Path $tmp 'requirements.txt'
        @'
# comment line
requests==2.31.0
flask>=2.0.0
numpy
'@ | Set-Content -LiteralPath $manifest

        $deps = Get-DependenciesFromManifest -Path $manifest
        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -eq 'requests').Version | Should -Be '2.31.0'
        ($deps | Where-Object Name -eq 'flask').Version    | Should -Be '2.0.0'
        ($deps | Where-Object Name -eq 'numpy').Version    | Should -Be ''
    }

    It 'throws when the manifest is missing' {
        { Get-DependenciesFromManifest -Path '/does/not/exist.json' } | Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws on invalid JSON' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $manifest = Join-Path $tmp 'package.json'
        'not-json' | Set-Content -LiteralPath $manifest
        { Get-DependenciesFromManifest -Path $manifest } | Should -Throw -ExpectedMessage '*Invalid JSON*'
    }
}

Describe 'Test-LicenseCompliance' {
    BeforeAll {
        $script:cfg = @{ allow = @('MIT','Apache-2.0'); deny = @('GPL-3.0') }
    }

    It 'returns approved for an allow-listed license' {
        Test-LicenseCompliance -License 'MIT' -Config $script:cfg | Should -Be 'approved'
    }
    It 'returns denied for a deny-listed license' {
        Test-LicenseCompliance -License 'GPL-3.0' -Config $script:cfg | Should -Be 'denied'
    }
    It 'returns unknown for anything else' {
        Test-LicenseCompliance -License 'BSD-3-Clause' -Config $script:cfg | Should -Be 'unknown'
    }
    It 'returns unknown for null license' {
        Test-LicenseCompliance -License $null -Config $script:cfg | Should -Be 'unknown'
    }
    It 'prefers deny over allow when a license appears on both' {
        $cfg2 = @{ allow = @('MIT'); deny = @('MIT') }
        Test-LicenseCompliance -License 'MIT' -Config $cfg2 | Should -Be 'denied'
    }
}

Describe 'New-ComplianceReport' {
    BeforeAll {
        $script:tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $script:manifest = Join-Path $script:tmp 'package.json'
        @'
{
  "name": "demo",
  "dependencies": { "alpha": "1.0.0", "beta": "2.0.0", "gamma": "3.0.0" }
}
'@ | Set-Content -LiteralPath $script:manifest

        $script:cfg = @{ allow = @('MIT'); deny = @('GPL-3.0') }

        # Mock the license lookup with a known mapping.
        Mock -ModuleName LicenseChecker Get-LicenseForDependency {
            switch ($Name) {
                'alpha' { 'MIT' }
                'beta'  { 'GPL-3.0' }
                default { $null }
            }
        }
    }

    It 'classifies each dependency against the mocked lookup' {
        $report = New-ComplianceReport -ManifestPath $script:manifest -Config $script:cfg
        $report.Summary.Total    | Should -Be 3
        $report.Summary.Approved | Should -Be 1
        $report.Summary.Denied   | Should -Be 1
        $report.Summary.Unknown  | Should -Be 1

        ($report.Dependencies | Where-Object Name -eq 'alpha').Status | Should -Be 'approved'
        ($report.Dependencies | Where-Object Name -eq 'beta').Status  | Should -Be 'denied'
        ($report.Dependencies | Where-Object Name -eq 'gamma').Status | Should -Be 'unknown'
    }
}

Describe 'ConvertTo-LicenseConfig' {
    It 'loads allow/deny arrays from JSON' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
        $p = Join-Path $tmp 'licenses.json'
        '{"allow":["MIT","Apache-2.0"],"deny":["GPL-3.0"]}' | Set-Content -LiteralPath $p
        $cfg = ConvertTo-LicenseConfig -Path $p
        $cfg.allow | Should -Contain 'MIT'
        $cfg.deny  | Should -Contain 'GPL-3.0'
    }
}
