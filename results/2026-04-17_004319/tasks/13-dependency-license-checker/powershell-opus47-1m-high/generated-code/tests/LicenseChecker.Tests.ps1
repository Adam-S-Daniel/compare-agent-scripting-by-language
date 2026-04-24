# Pester tests for the dependency license checker.
# Tests were authored first (red phase) to drive the module design:
#   1. Red:   Describe a behavior in a test and watch it fail
#   2. Green: Implement the minimum code needed in LicenseChecker.psm1
#   3. Refactor: Clean up once the test passes
# Each Describe block below corresponds to one slice of functionality that was
# added in sequence during the TDD cycle.

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src'
    $script:ModulePath = Join-Path $script:ModuleRoot 'LicenseChecker.psm1'
    Import-Module -Name $script:ModulePath -Force

    # Per-test temp directory for manifest / config fixtures.
    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("license-checker-tests-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:TmpRoot | Out-Null
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -Recurse -Force -LiteralPath $script:TmpRoot
    }
    Remove-Module LicenseChecker -ErrorAction SilentlyContinue
}

Describe 'Get-ManifestDependencies (package.json)' {
    It 'extracts dependency name/version pairs from a package.json file' {
        $manifest = @{
            name         = 'demo'
            version      = '1.0.0'
            dependencies = @{ 'left-pad' = '^1.3.0'; 'lodash' = '4.17.21' }
        } | ConvertTo-Json -Depth 5
        $path = Join-Path $TmpRoot 'package.json'
        Set-Content -LiteralPath $path -Value $manifest

        $deps = Get-ManifestDependencies -Path $path

        $deps | Should -HaveCount 2
        ($deps | Where-Object Name -eq 'lodash').Version | Should -Be '4.17.21'
        ($deps | Where-Object Name -eq 'left-pad').Version | Should -Be '^1.3.0'
    }

    It 'merges devDependencies with dependencies' {
        $manifest = @{
            dependencies    = @{ 'express' = '^4.18.0' }
            devDependencies = @{ 'jest'    = '^29.0.0' }
        } | ConvertTo-Json -Depth 5
        $path = Join-Path $TmpRoot 'with-dev.json'
        Copy-Item -LiteralPath (Join-Path $TmpRoot 'package.json') -Destination (Join-Path $TmpRoot 'package.json.bak') -ErrorAction SilentlyContinue
        Set-Content -LiteralPath (Join-Path $TmpRoot 'package.json') -Value $manifest

        $deps = Get-ManifestDependencies -Path (Join-Path $TmpRoot 'package.json')

        ($deps | Measure-Object).Count | Should -Be 2
        ($deps | Where-Object Name -eq 'jest').Version | Should -Be '^29.0.0'
    }
}

Describe 'Get-ManifestDependencies (requirements.txt)' {
    It 'parses pinned and unpinned pip requirements, ignoring comments and blanks' {
        $body = @(
            '# top-level comment'
            ''
            'requests==2.31.0'
            'flask>=2.0.0'
            'rich   # trailing comment'
            '   pydantic~=2.4  '
        ) -join "`n"
        $path = Join-Path $TmpRoot 'requirements.txt'
        Set-Content -LiteralPath $path -Value $body

        $deps = Get-ManifestDependencies -Path $path

        $deps | Should -HaveCount 4
        ($deps | Where-Object Name -eq 'requests').Version | Should -Be '2.31.0'
        ($deps | Where-Object Name -eq 'flask').Version   | Should -Be '2.0.0'
        ($deps | Where-Object Name -eq 'rich').Version    | Should -Be '*'
        ($deps | Where-Object Name -eq 'pydantic').Version | Should -Be '2.4'
    }
}

Describe 'Get-ManifestDependencies error handling' {
    It 'throws a clear error when the manifest file does not exist' {
        { Get-ManifestDependencies -Path (Join-Path $TmpRoot 'nope.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a clear error for unsupported manifest file names' {
        $path = Join-Path $TmpRoot 'Cargo.lock'
        Set-Content -LiteralPath $path -Value 'placeholder'
        { Get-ManifestDependencies -Path $path } |
            Should -Throw -ExpectedMessage '*Unsupported manifest*'
    }
}

Describe 'Test-LicenseCompliance' {
    It 'returns approved when license is on the allow list' {
        Test-LicenseCompliance -License 'MIT' -AllowList @('MIT','Apache-2.0') -DenyList @('GPL-3.0') |
            Should -Be 'approved'
    }
    It 'returns denied when license is on the deny list (deny wins over allow)' {
        Test-LicenseCompliance -License 'GPL-3.0' -AllowList @('GPL-3.0') -DenyList @('GPL-3.0') |
            Should -Be 'denied'
    }
    It 'returns unknown when license is neither allowed nor denied' {
        Test-LicenseCompliance -License 'SomethingNew' -AllowList @('MIT') -DenyList @('GPL-3.0') |
            Should -Be 'unknown'
    }
    It 'returns unknown when license is null or empty' {
        Test-LicenseCompliance -License $null -AllowList @('MIT') -DenyList @('GPL') | Should -Be 'unknown'
        Test-LicenseCompliance -License ''    -AllowList @('MIT') -DenyList @('GPL') | Should -Be 'unknown'
    }
}

Describe 'Invoke-LicenseCheck end-to-end' {
    BeforeAll {
        $manifest = @{
            dependencies = @{
                'left-pad' = '1.3.0'
                'evilpkg'  = '0.0.1'
                'mystery'  = '9.9.9'
            }
        } | ConvertTo-Json -Depth 5
        $script:ManifestPath = Join-Path $TmpRoot 'e2e-package.json'
        # Use the file name package.json to pass manifest detection.
        $script:ManifestPath = Join-Path $TmpRoot 'package.json'
        Set-Content -LiteralPath $script:ManifestPath -Value $manifest

        $config = @{
            allow = @('MIT','Apache-2.0','BSD-3-Clause')
            deny  = @('GPL-3.0','AGPL-3.0')
        } | ConvertTo-Json -Depth 5
        $script:ConfigPath = Join-Path $TmpRoot 'license-config.json'
        Set-Content -LiteralPath $script:ConfigPath -Value $config

        # Mocked license lookup: explicit mapping per package. A missing package
        # means the registry returned no license info -> status should be unknown.
        $licenseData = @{
            'left-pad' = 'MIT'
            'evilpkg'  = 'GPL-3.0'
        } | ConvertTo-Json -Depth 5
        $script:LicenseDataPath = Join-Path $TmpRoot 'license-data.json'
        Set-Content -LiteralPath $script:LicenseDataPath -Value $licenseData
    }

    It 'classifies each dependency as approved, denied, or unknown' {
        $report = Invoke-LicenseCheck -ManifestPath $script:ManifestPath `
                                      -ConfigPath $script:ConfigPath `
                                      -LicenseDataPath $script:LicenseDataPath

        ($report | Where-Object Name -eq 'left-pad').Status | Should -Be 'approved'
        ($report | Where-Object Name -eq 'evilpkg').Status  | Should -Be 'denied'
        ($report | Where-Object Name -eq 'mystery').Status  | Should -Be 'unknown'
    }

    It 'includes a summary count of each status' {
        $summary = Get-LicenseSummary -Report (Invoke-LicenseCheck `
                    -ManifestPath $script:ManifestPath `
                    -ConfigPath $script:ConfigPath `
                    -LicenseDataPath $script:LicenseDataPath)

        $summary.Approved | Should -Be 1
        $summary.Denied   | Should -Be 1
        $summary.Unknown  | Should -Be 1
        $summary.Total    | Should -Be 3
    }

    It 'throws a helpful error when the config file is missing' {
        { Invoke-LicenseCheck -ManifestPath $script:ManifestPath `
                              -ConfigPath (Join-Path $TmpRoot 'nope.json') } |
            Should -Throw -ExpectedMessage '*config*not found*'
    }
}

Describe 'Format-LicenseReport' {
    It 'renders a human-readable report with name, version, license and status' {
        $rows = @(
            [PSCustomObject]@{ Name='lodash';  Version='4.17.21'; License='MIT';     Status='approved' }
            [PSCustomObject]@{ Name='copyleft';Version='1.0.0';   License='GPL-3.0'; Status='denied' }
            [PSCustomObject]@{ Name='mystery'; Version='*';       License=$null;     Status='unknown' }
        )

        $text = Format-LicenseReport -Report $rows

        $text | Should -Match 'lodash'
        $text | Should -Match 'approved'
        $text | Should -Match 'GPL-3.0'
        $text | Should -Match 'denied'
        $text | Should -Match 'mystery'
        $text | Should -Match 'unknown'
    }
}
