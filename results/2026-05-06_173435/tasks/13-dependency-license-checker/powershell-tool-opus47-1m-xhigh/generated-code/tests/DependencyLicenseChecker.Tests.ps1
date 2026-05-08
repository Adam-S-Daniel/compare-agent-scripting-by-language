# Pester tests for the Dependency License Checker.
# Built with red/green TDD: each Describe/It below was written before the
# corresponding code in src/DependencyLicenseChecker.psm1.
#
# Pester 5+ syntax. Run with: Invoke-Pester ./tests

BeforeAll {
    $script:moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:modulePath = Join-Path $script:moduleRoot 'src/DependencyLicenseChecker.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'Get-DependencyManifest' {

    It 'parses a package.json with dependencies and devDependencies' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $path = Join-Path $tmp 'package.json'
        @'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "jest": "29.7.0"
  }
}
'@ | Set-Content -Path $path

        $deps = Get-DependencyManifest -Path $path

        $deps | Should -HaveCount 3
        $names = $deps | ForEach-Object Name
        $names | Should -Contain 'react'
        $names | Should -Contain 'lodash'
        $names | Should -Contain 'jest'

        ($deps | Where-Object Name -eq 'react').Version  | Should -Be '18.2.0'
        ($deps | Where-Object Name -eq 'lodash').Version | Should -Be '^4.17.21'
    }

    It 'parses requirements.txt with == pinned versions' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $path = Join-Path $tmp 'requirements.txt'
        @'
# comment line, ignored
requests==2.31.0
pytest==7.4.0

flask>=2.0.0
'@ | Set-Content -Path $path

        $deps = Get-DependencyManifest -Path $path

        $deps | Should -HaveCount 3
        ($deps | Where-Object Name -eq 'requests').Version | Should -Be '2.31.0'
        ($deps | Where-Object Name -eq 'pytest').Version   | Should -Be '7.4.0'
        ($deps | Where-Object Name -eq 'flask').Version    | Should -Be '>=2.0.0'
    }

    It 'throws a meaningful error when the manifest does not exist' {
        { Get-DependencyManifest -Path '/no/such/file.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when the manifest format is unrecognised' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $path = Join-Path $tmp 'unknown.toml'
        '[tool.poetry]' | Set-Content -Path $path

        { Get-DependencyManifest -Path $path } |
            Should -Throw -ExpectedMessage '*unsupported*'
    }
}

Describe 'Get-LicenseConfig' {

    It 'loads allow and deny lists from JSON' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $path = Join-Path $tmp 'cfg.json'
        @'
{
  "allow": ["MIT", "Apache-2.0"],
  "deny":  ["GPL-3.0"]
}
'@ | Set-Content -Path $path

        $cfg = Get-LicenseConfig -Path $path
        $cfg.Allow | Should -Contain 'MIT'
        $cfg.Allow | Should -Contain 'Apache-2.0'
        $cfg.Deny  | Should -Contain 'GPL-3.0'
    }

    It 'rejects malformed config JSON with a clear error' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $path = Join-Path $tmp 'cfg.json'
        'not-json{{' | Set-Content -Path $path

        { Get-LicenseConfig -Path $path } |
            Should -Throw -ExpectedMessage '*invalid*'
    }
}

Describe 'Test-LicenseCompliance' {

    BeforeAll {
        $script:cfg = [pscustomobject]@{
            Allow = @('MIT', 'Apache-2.0', 'BSD-3-Clause')
            Deny  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'returns Approved when license is in the allow list' {
        Test-LicenseCompliance -License 'MIT' -Config $script:cfg | Should -Be 'Approved'
    }

    It 'returns Denied when license is in the deny list' {
        Test-LicenseCompliance -License 'GPL-3.0' -Config $script:cfg | Should -Be 'Denied'
    }

    It 'returns Unknown when license is in neither list' {
        Test-LicenseCompliance -License 'WTFPL' -Config $script:cfg | Should -Be 'Unknown'
    }

    It 'returns Unknown when license is null or empty' {
        Test-LicenseCompliance -License $null -Config $script:cfg | Should -Be 'Unknown'
        Test-LicenseCompliance -License ''    -Config $script:cfg | Should -Be 'Unknown'
    }

    It 'matches case-insensitively' {
        Test-LicenseCompliance -License 'mit' -Config $script:cfg | Should -Be 'Approved'
    }

    It 'treats deny-list as winning over allow-list when both contain the same entry' {
        $cfg = [pscustomobject]@{ Allow = @('MIT'); Deny = @('MIT') }
        Test-LicenseCompliance -License 'MIT' -Config $cfg | Should -Be 'Denied'
    }
}

Describe 'Get-DependencyLicense (mockable license lookup)' {

    BeforeAll {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
        $script:dbPath = Join-Path $script:tmp 'db.json'
        @'
{
  "react@18.2.0": "MIT",
  "lodash":        "MIT",
  "evil-pkg":      "GPL-3.0"
}
'@ | Set-Content -Path $script:dbPath
    }

    It 'returns the license for a name@version exact match' {
        Get-DependencyLicense -Name 'react' -Version '18.2.0' -DatabasePath $script:dbPath |
            Should -Be 'MIT'
    }

    It 'falls back to a name-only match when version is not in the db' {
        Get-DependencyLicense -Name 'lodash' -Version '4.17.21' -DatabasePath $script:dbPath |
            Should -Be 'MIT'
    }

    It 'returns $null for a dependency that is not in the db' {
        Get-DependencyLicense -Name 'totally-new-pkg' -Version '0.0.1' -DatabasePath $script:dbPath |
            Should -BeNullOrEmpty
    }
}

Describe 'Invoke-LicenseCheck (end-to-end with mocks)' {

    BeforeAll {
        # Build an isolated working tree so the test does not pollute the repo.
        $script:run = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:run | Out-Null

        # Sample package.json: react = MIT (approved), evil-pkg = GPL-3.0 (denied),
        # mystery-pkg has no entry in the db (unknown).
        @'
{
  "name":         "demo",
  "version":      "1.0.0",
  "dependencies": {
    "react":         "18.2.0",
    "evil-pkg":      "1.0.0",
    "mystery-pkg":   "0.1.0"
  }
}
'@ | Set-Content -Path (Join-Path $script:run 'package.json')

        @'
{
  "allow": ["MIT", "Apache-2.0"],
  "deny":  ["GPL-3.0"]
}
'@ | Set-Content -Path (Join-Path $script:run 'cfg.json')

        @'
{
  "react@18.2.0": "MIT",
  "evil-pkg":     "GPL-3.0"
}
'@ | Set-Content -Path (Join-Path $script:run 'db.json')

        $script:reportPath = Join-Path $script:run 'report.json'
    }

    It 'produces a report with a row per dependency and exits non-zero on denied licenses' {
        $exit = Invoke-LicenseCheck `
            -ManifestPath (Join-Path $script:run 'package.json') `
            -ConfigPath   (Join-Path $script:run 'cfg.json')   `
            -DatabasePath (Join-Path $script:run 'db.json')   `
            -ReportPath   $script:reportPath

        # Exit non-zero because at least one dependency was Denied.
        $exit | Should -Be 1

        Test-Path $script:reportPath | Should -BeTrue
        $report = Get-Content $script:reportPath -Raw | ConvertFrom-Json

        $report.Dependencies | Should -HaveCount 3

        $byName = @{}
        foreach ($r in $report.Dependencies) { $byName[$r.Name] = $r }

        $byName['react'].Status        | Should -Be 'Approved'
        $byName['react'].License       | Should -Be 'MIT'
        $byName['evil-pkg'].Status     | Should -Be 'Denied'
        $byName['evil-pkg'].License    | Should -Be 'GPL-3.0'
        $byName['mystery-pkg'].Status  | Should -Be 'Unknown'

        $report.Summary.Approved | Should -Be 1
        $report.Summary.Denied   | Should -Be 1
        $report.Summary.Unknown  | Should -Be 1
        $report.Summary.Total    | Should -Be 3
    }

    It 'returns exit code 0 when every dependency is Approved' {
        # Fresh subdir so package.json does not collide with the parent test.
        $okDir = Join-Path $script:run 'ok'
        New-Item -ItemType Directory -Path $okDir | Out-Null
        @'
{
  "name": "ok",
  "dependencies": {"react": "18.2.0"}
}
'@ | Set-Content -Path (Join-Path $okDir 'package.json')

        $exit = Invoke-LicenseCheck `
            -ManifestPath (Join-Path $okDir       'package.json') `
            -ConfigPath   (Join-Path $script:run  'cfg.json')   `
            -DatabasePath (Join-Path $script:run  'db.json')   `
            -ReportPath   (Join-Path $okDir       'report.json')

        $exit | Should -Be 0
    }

    It 'demonstrates Pester Mock can replace Get-DependencyLicense for testability' {
        # Provide an in-memory mock so the lookup never reaches a JSON file.
        # This proves the public function is mockable and the test is hermetic.
        InModuleScope DependencyLicenseChecker {
            Mock Get-DependencyLicense { 'Apache-2.0' } -Verifiable

            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tmp | Out-Null

            @'
{
  "name": "x",
  "dependencies": {"only-dep": "1.0.0"}
}
'@ | Set-Content -Path (Join-Path $tmp 'package.json')

            @'
{"allow":["Apache-2.0"],"deny":[]}
'@ | Set-Content -Path (Join-Path $tmp 'cfg.json')

            $exit = Invoke-LicenseCheck `
                -ManifestPath (Join-Path $tmp 'package.json') `
                -ConfigPath   (Join-Path $tmp 'cfg.json')   `
                -DatabasePath (Join-Path $tmp 'cfg.json')   `
                -ReportPath   (Join-Path $tmp 'r.json')

            $exit | Should -Be 0

            $r = Get-Content (Join-Path $tmp 'r.json') -Raw | ConvertFrom-Json
            $r.Dependencies[0].License | Should -Be 'Apache-2.0'
            $r.Dependencies[0].Status  | Should -Be 'Approved'

            Should -InvokeVerifiable
        }
    }

    It 'errors out cleanly when the manifest does not exist' {
        { Invoke-LicenseCheck `
            -ManifestPath '/does/not/exist.json' `
            -ConfigPath   (Join-Path $script:run 'cfg.json') `
            -DatabasePath (Join-Path $script:run 'db.json') `
            -ReportPath   (Join-Path $script:run 'never.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}
