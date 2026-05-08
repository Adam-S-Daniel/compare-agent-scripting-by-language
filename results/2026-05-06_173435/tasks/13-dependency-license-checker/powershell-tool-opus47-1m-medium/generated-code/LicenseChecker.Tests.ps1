# Pester 5 tests for LicenseChecker.psm1.
# Written TDD-style: each Context/It block asserts behavior the module
# is expected to provide. Mocks are produced via in-memory hashtables and
# temp-file fixtures so no network or filesystem state leaks between tests.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'LicenseChecker.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Read-DependencyManifest' {
    BeforeEach {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lc-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
    }
    AfterEach {
        if (Test-Path $script:tmpDir) { Remove-Item -Recurse -Force $script:tmpDir }
    }

    It 'extracts dependencies and devDependencies from package.json' {
        $manifest = @{
            name            = 'demo'
            dependencies    = @{ 'left-pad' = '1.3.0'; lodash = '4.17.21' }
            devDependencies = @{ jest = '29.0.0' }
        } | ConvertTo-Json -Depth 5
        $path = Join-Path $script:tmpDir 'package.json'
        Set-Content -LiteralPath $path -Value $manifest

        $deps = Read-DependencyManifest -Path $path
        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -eq 'left-pad').Version | Should -Be '1.3.0'
        ($deps | Where-Object Name -eq 'jest').Version | Should -Be '29.0.0'
    }

    It 'throws on missing file' {
        { Read-DependencyManifest -Path (Join-Path $script:tmpDir 'nope.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws on invalid JSON' {
        $path = Join-Path $script:tmpDir 'bad.json'
        Set-Content -LiteralPath $path -Value '{ this is not json'
        { Read-DependencyManifest -Path $path } | Should -Throw -ExpectedMessage '*not valid JSON*'
    }

    It 'returns empty array when no deps sections present' {
        $path = Join-Path $script:tmpDir 'empty.json'
        Set-Content -LiteralPath $path -Value '{ "name": "x" }'
        $deps = Read-DependencyManifest -Path $path
        @($deps).Count | Should -Be 0
    }
}

Describe 'Read-LicenseConfig' {
    BeforeEach {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lc-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
    }
    AfterEach {
        if (Test-Path $script:tmpDir) { Remove-Item -Recurse -Force $script:tmpDir }
    }

    It 'parses allow and deny arrays' {
        $cfg = @{ allow = @('MIT','Apache-2.0'); deny = @('GPL-3.0') } | ConvertTo-Json
        $path = Join-Path $script:tmpDir 'cfg.json'
        Set-Content -LiteralPath $path -Value $cfg
        $parsed = Read-LicenseConfig -Path $path
        $parsed.Allow | Should -Contain 'MIT'
        $parsed.Allow | Should -Contain 'Apache-2.0'
        $parsed.Deny  | Should -Contain 'GPL-3.0'
    }

    It 'treats missing arrays as empty' {
        $path = Join-Path $script:tmpDir 'cfg.json'
        Set-Content -LiteralPath $path -Value '{}'
        $parsed = Read-LicenseConfig -Path $path
        @($parsed.Allow).Count | Should -Be 0
        @($parsed.Deny).Count  | Should -Be 0
    }
}

Describe 'Get-ComplianceStatus' {
    It 'returns approved when license is on the allow list' {
        Get-ComplianceStatus -License 'MIT' -Allow @('MIT') -Deny @() | Should -Be 'approved'
    }
    It 'returns denied when license is on the deny list' {
        Get-ComplianceStatus -License 'GPL-3.0' -Allow @('MIT') -Deny @('GPL-3.0') | Should -Be 'denied'
    }
    It 'returns unknown when license is not on either list' {
        Get-ComplianceStatus -License 'WTFPL' -Allow @('MIT') -Deny @('GPL-3.0') | Should -Be 'unknown'
    }
    It 'returns unknown for null/empty license' {
        Get-ComplianceStatus -License $null -Allow @('MIT') -Deny @() | Should -Be 'unknown'
        Get-ComplianceStatus -License ''    -Allow @('MIT') -Deny @() | Should -Be 'unknown'
    }
    It 'lets deny win when license appears in both lists' {
        Get-ComplianceStatus -License 'MIT' -Allow @('MIT') -Deny @('MIT') | Should -Be 'denied'
    }
}

Describe 'Get-DependencyLicense (mocked lookup)' {
    It 'returns license from lookup table' {
        $table = @{ 'lodash' = 'MIT' }
        Get-DependencyLicense -Name 'lodash' -Version '4.0.0' -LookupTable $table | Should -Be 'MIT'
    }
    It 'returns $null for unknown dependency' {
        $table = @{ 'lodash' = 'MIT' }
        Get-DependencyLicense -Name 'mystery' -Version '1.0.0' -LookupTable $table | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-LicenseComplianceReport (end-to-end with mocks)' {
    BeforeEach {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lc-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null

        $manifest = @{
            dependencies    = @{ lodash = '4.17.21'; 'evil-pkg' = '1.0.0' }
            devDependencies = @{ mystery = '0.0.1' }
        } | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath (Join-Path $script:tmpDir 'package.json') -Value $manifest

        $config = @{ allow = @('MIT','Apache-2.0'); deny = @('GPL-3.0') } | ConvertTo-Json
        Set-Content -LiteralPath (Join-Path $script:tmpDir 'license-config.json') -Value $config

        $script:LookupTable = @{
            lodash    = 'MIT'
            'evil-pkg'= 'GPL-3.0'
            # `mystery` deliberately absent → unknown
        }
    }
    AfterEach {
        if (Test-Path $script:tmpDir) { Remove-Item -Recurse -Force $script:tmpDir }
    }

    It 'classifies each dependency correctly' {
        $rows = Invoke-LicenseComplianceReport `
            -ManifestPath (Join-Path $script:tmpDir 'package.json') `
            -ConfigPath   (Join-Path $script:tmpDir 'license-config.json') `
            -LookupTable  $script:LookupTable

        ($rows | Where-Object Name -eq 'lodash').Status   | Should -Be 'approved'
        ($rows | Where-Object Name -eq 'evil-pkg').Status | Should -Be 'denied'
        ($rows | Where-Object Name -eq 'mystery').Status  | Should -Be 'unknown'
    }
}

Describe 'Format-ComplianceReport' {
    It 'produces a deterministic text report with summary and rows' {
        $rows = @(
            [pscustomobject]@{ Name = 'b'; Version = '1.0'; License = 'MIT';     Status = 'approved' }
            [pscustomobject]@{ Name = 'a'; Version = '2.0'; License = 'GPL-3.0'; Status = 'denied'   }
            [pscustomobject]@{ Name = 'c'; Version = '0.1'; License = '';        Status = 'unknown'  }
        )
        $text = Format-ComplianceReport -Rows $rows
        $text | Should -Match 'Total: 3 \| Approved: 1 \| Denied: 1 \| Unknown: 1'
        $text | Should -Match 'a@2\.0 :: GPL-3\.0 :: DENIED'
        $text | Should -Match 'b@1\.0 :: MIT :: APPROVED'
        $text | Should -Match 'c@0\.1 :: <none> :: UNKNOWN'
        # Sorted alphabetically: a before b before c
        $idxA = $text.IndexOf('a@2.0')
        $idxB = $text.IndexOf('b@1.0')
        $idxC = $text.IndexOf('c@0.1')
        $idxA | Should -BeLessThan $idxB
        $idxB | Should -BeLessThan $idxC
    }
}
