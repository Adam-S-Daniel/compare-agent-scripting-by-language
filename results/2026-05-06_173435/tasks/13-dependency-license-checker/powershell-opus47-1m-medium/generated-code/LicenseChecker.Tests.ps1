# Pester tests for the license-compliance checker. We use Pester 5 syntax.
# The tests drive the public surface of LicenseChecker.psm1 plus the
# Invoke-LicenseCheck.ps1 entry script.

BeforeAll {
    $script:Here = Split-Path -Parent $PSCommandPath
    Import-Module (Join-Path $Here 'LicenseChecker.psm1') -Force
}

Describe 'Get-Dependencies' {
    It 'parses dependencies + devDependencies from a package.json' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'pkg')
        $manifest = Join-Path $tmp 'package.json'
        @'
{
  "name": "demo",
  "dependencies": { "left-pad": "1.3.0", "lodash": "4.17.21" },
  "devDependencies": { "jest": "29.0.0" }
}
'@ | Set-Content -Path $manifest

        $deps = Get-Dependencies -Path $manifest | Sort-Object Name
        $deps.Count | Should -Be 3
        $deps[0].Name    | Should -Be 'jest'
        $deps[0].Version | Should -Be '29.0.0'
        $deps[1].Name    | Should -Be 'left-pad'
        $deps[2].Name    | Should -Be 'lodash'
        $deps[2].Version | Should -Be '4.17.21'
    }

    It 'parses requirements.txt with pinned and unpinned entries, skipping blanks/comments' {
        $req = Join-Path $TestDrive 'requirements.txt'
        @'
# top-level deps
requests==2.31.0
flask>=2.0.0

   # indented comment
numpy
'@ | Set-Content -Path $req

        $deps = Get-Dependencies -Path $req | Sort-Object Name
        $deps.Count | Should -Be 3
        ($deps | Where-Object Name -EQ 'requests').Version | Should -Be '2.31.0'
        ($deps | Where-Object Name -EQ 'flask').Version    | Should -Be '2.0.0'
        ($deps | Where-Object Name -EQ 'numpy').Version    | Should -Be 'unspecified'
    }

    It 'throws a descriptive error when the manifest is missing' {
        { Get-Dependencies -Path (Join-Path $TestDrive 'nope.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Test-LicenseCompliance' {
    BeforeAll {
        $script:Config = [pscustomobject]@{
            allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'classifies an allow-listed license as approved' {
        (Test-LicenseCompliance -License 'MIT' -Config $script:Config) | Should -Be 'approved'
    }

    It 'classifies a deny-listed license as denied' {
        (Test-LicenseCompliance -License 'GPL-3.0' -Config $script:Config) | Should -Be 'denied'
    }

    It 'classifies an absent or unrecognised license as unknown' {
        (Test-LicenseCompliance -License 'WTFPL' -Config $script:Config) | Should -Be 'unknown'
        (Test-LicenseCompliance -License $null    -Config $script:Config) | Should -Be 'unknown'
    }

    It 'gives deny precedence over allow when a license is in both lists' {
        $weird = [pscustomobject]@{ allow = @('MIT'); deny = @('MIT') }
        (Test-LicenseCompliance -License 'MIT' -Config $weird) | Should -Be 'denied'
    }
}

Describe 'New-ComplianceReport' {
    It 'produces one row per dependency with the looked-up license and status' {
        $deps = @(
            [pscustomobject]@{ Name = 'left-pad'; Version = '1.3.0' }
            [pscustomobject]@{ Name = 'evil';     Version = '0.1.0' }
            [pscustomobject]@{ Name = 'mystery';  Version = '9.9.9' }
        )
        $config = [pscustomobject]@{
            allow = @('MIT')
            deny  = @('GPL-3.0')
        }
        # Mock lookup keyed by package name.
        $lookup = {
            param($name, $version)
            switch ($name) {
                'left-pad' { 'MIT' }
                'evil'     { 'GPL-3.0' }
                default    { $null }
            }
        }

        $report = New-ComplianceReport -Dependencies $deps -Config $config -LicenseLookup $lookup
        $report.Count | Should -Be 3
        ($report | Where-Object Name -EQ 'left-pad').Status | Should -Be 'approved'
        ($report | Where-Object Name -EQ 'left-pad').License | Should -Be 'MIT'
        ($report | Where-Object Name -EQ 'evil').Status     | Should -Be 'denied'
        ($report | Where-Object Name -EQ 'mystery').Status  | Should -Be 'unknown'
        ($report | Where-Object Name -EQ 'mystery').License | Should -Be 'UNKNOWN'
    }
}

Describe 'Invoke-LicenseCheck.ps1 (end-to-end)' {
    It 'writes a JSON report and exits non-zero when a denied dep is found' {
        $work = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2e')
        $manifest = Join-Path $work 'package.json'
        @'
{
  "dependencies": { "good-pkg": "1.0.0", "bad-pkg": "2.0.0", "weird-pkg": "0.0.1" }
}
'@ | Set-Content -Path $manifest

        $configPath = Join-Path $work 'license-policy.json'
        @'
{ "allow": ["MIT","Apache-2.0"], "deny": ["GPL-3.0"] }
'@ | Set-Content -Path $configPath

        # Mock license database used by the entry script.
        $mockDbPath = Join-Path $work 'mock-licenses.json'
        @'
{ "good-pkg": "MIT", "bad-pkg": "GPL-3.0" }
'@ | Set-Content -Path $mockDbPath

        $reportPath = Join-Path $work 'report.json'
        $entry = Join-Path $script:Here 'Invoke-LicenseCheck.ps1'

        # Run the entry script in-process so we can capture exit code + stdout.
        $output = & pwsh -NoLogo -NoProfile -File $entry `
            -ManifestPath $manifest `
            -ConfigPath   $configPath `
            -MockDatabase $mockDbPath `
            -ReportPath   $reportPath
        $exit = $LASTEXITCODE

        Test-Path $reportPath | Should -BeTrue
        $report = Get-Content $reportPath -Raw | ConvertFrom-Json
        $report.Count | Should -Be 3
        ($report | Where-Object Name -EQ 'good-pkg').Status  | Should -Be 'approved'
        ($report | Where-Object Name -EQ 'bad-pkg').Status   | Should -Be 'denied'
        ($report | Where-Object Name -EQ 'weird-pkg').Status | Should -Be 'unknown'

        # Stdout summary must include the headline counts so CI can grep them.
        ($output -join "`n") | Should -Match 'approved=1'
        ($output -join "`n") | Should -Match 'denied=1'
        ($output -join "`n") | Should -Match 'unknown=1'

        # Denied dep -> non-zero exit so the workflow can fail the build.
        $exit | Should -Be 2
    }

    It 'exits zero when every dependency is approved' {
        $work = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2e-clean')
        $manifest = Join-Path $work 'requirements.txt'
        "requests==2.31.0`nflask==2.3.0`n" | Set-Content -Path $manifest

        $configPath = Join-Path $work 'license-policy.json'
        '{ "allow": ["Apache-2.0","BSD-3-Clause"], "deny": ["GPL-3.0"] }' |
            Set-Content -Path $configPath

        $mockDbPath = Join-Path $work 'mock-licenses.json'
        '{ "requests": "Apache-2.0", "flask": "BSD-3-Clause" }' |
            Set-Content -Path $mockDbPath

        $reportPath = Join-Path $work 'report.json'
        $entry = Join-Path $script:Here 'Invoke-LicenseCheck.ps1'

        & pwsh -NoLogo -NoProfile -File $entry `
            -ManifestPath $manifest `
            -ConfigPath   $configPath `
            -MockDatabase $mockDbPath `
            -ReportPath   $reportPath | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
