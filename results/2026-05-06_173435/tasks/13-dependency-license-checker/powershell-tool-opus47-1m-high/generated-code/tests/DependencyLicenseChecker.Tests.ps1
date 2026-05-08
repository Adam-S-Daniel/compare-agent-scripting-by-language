# Pester tests for the DependencyLicenseChecker module.
# Built incrementally with red/green TDD: each Describe block was added by
# first writing a failing test, then the minimum code in the module to pass.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'src' 'DependencyLicenseChecker.psm1'
    Import-Module $ModulePath -Force
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
    New-Item -ItemType Directory -Force -Path $script:FixturesDir | Out-Null
}

AfterAll {
    Remove-Module DependencyLicenseChecker -ErrorAction SilentlyContinue
}

Describe 'Read-DependencyManifest' {

    Context 'package.json manifests' {
        BeforeAll {
            $script:PkgJsonPath = Join-Path $script:FixturesDir 'package.json'
            @'
{
  "name": "demo",
  "version": "1.0.0",
  "dependencies": {
    "left-pad": "^1.3.0",
    "lodash": "4.17.21"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  }
}
'@ | Set-Content -Path $script:PkgJsonPath
        }

        It 'parses runtime dependencies into name/version objects' {
            $deps = Read-DependencyManifest -Path $script:PkgJsonPath
            $deps | Should -Not -BeNullOrEmpty
            ($deps | Where-Object Name -EQ 'left-pad').Version | Should -Be '^1.3.0'
            ($deps | Where-Object Name -EQ 'lodash').Version  | Should -Be '4.17.21'
        }

        It 'includes devDependencies' {
            $deps = Read-DependencyManifest -Path $script:PkgJsonPath
            ($deps | Where-Object Name -EQ 'jest').Version | Should -Be '^29.0.0'
        }

        It 'tags devDependencies with Scope=dev' {
            $deps = Read-DependencyManifest -Path $script:PkgJsonPath
            ($deps | Where-Object Name -EQ 'jest').Scope    | Should -Be 'dev'
            ($deps | Where-Object Name -EQ 'lodash').Scope  | Should -Be 'runtime'
        }
    }

    Context 'requirements.txt manifests' {
        BeforeAll {
            $script:ReqPath = Join-Path $script:FixturesDir 'requirements.txt'
            @'
# top of file comment
requests==2.31.0
flask>=2.0.0
django ~= 4.2

   # indented comment
PyYAML
'@ | Set-Content -Path $script:ReqPath
        }

        It 'parses pinned versions' {
            $deps = Read-DependencyManifest -Path $script:ReqPath
            ($deps | Where-Object Name -EQ 'requests').Version | Should -Be '==2.31.0'
        }

        It 'parses range specifiers' {
            $deps = Read-DependencyManifest -Path $script:ReqPath
            ($deps | Where-Object Name -EQ 'flask').Version  | Should -Be '>=2.0.0'
            ($deps | Where-Object Name -EQ 'django').Version | Should -Match '~='
        }

        It 'records unspecified version as empty string' {
            $deps = Read-DependencyManifest -Path $script:ReqPath
            ($deps | Where-Object Name -EQ 'PyYAML').Version | Should -Be ''
        }

        It 'ignores comments and blank lines' {
            $deps = Read-DependencyManifest -Path $script:ReqPath
            $deps.Count | Should -Be 4
        }
    }

    Context 'error handling' {
        It 'throws a meaningful error when the file does not exist' {
            { Read-DependencyManifest -Path '/no/such/file.json' } |
                Should -Throw -ExpectedMessage '*not found*'
        }

        It 'throws when the file format is unrecognized' {
            $tmp = New-TemporaryFile
            'random content' | Set-Content $tmp
            try {
                { Read-DependencyManifest -Path $tmp } |
                    Should -Throw -ExpectedMessage '*Unsupported manifest*'
            } finally {
                Remove-Item $tmp -Force
            }
        }
    }
}

Describe 'Get-LicenseForPackage (mock-friendly)' {

    Context 'with mock data file' {
        BeforeAll {
            $script:MockPath = Join-Path $script:FixturesDir 'mock-licenses.json'
            @'
{
  "left-pad":   "MIT",
  "lodash":     "MIT",
  "jest":       "MIT",
  "requests":   "Apache-2.0",
  "flask":      "BSD-3-Clause",
  "evil-pkg":   "GPL-3.0",
  "django":     "BSD-3-Clause"
}
'@ | Set-Content -Path $script:MockPath
        }

        It 'returns the license string for a known package' {
            Get-LicenseForPackage -Name 'lodash'  -MockDataPath $script:MockPath |
                Should -Be 'MIT'
            Get-LicenseForPackage -Name 'flask'   -MockDataPath $script:MockPath |
                Should -Be 'BSD-3-Clause'
        }

        It 'returns "UNKNOWN" for unknown packages' {
            Get-LicenseForPackage -Name 'nonexistent' -MockDataPath $script:MockPath |
                Should -Be 'UNKNOWN'
        }
    }

    Context 'using Pester Mock to fake the registry call' {
        It 'is overridable via Mock for unit tests' {
            Mock -ModuleName DependencyLicenseChecker `
                 Get-LicenseForPackage { 'ISC' }
            $result = & (Get-Module DependencyLicenseChecker) {
                Get-LicenseForPackage -Name 'whatever' -MockDataPath 'unused'
            }
            $result | Should -Be 'ISC'
        }
    }
}

Describe 'Test-LicenseCompliance' {

    BeforeAll {
        $script:Config = [pscustomobject]@{
            AllowList = @('MIT', 'Apache-2.0', 'BSD-3-Clause', 'ISC')
            DenyList  = @('GPL-3.0', 'AGPL-3.0')
        }
    }

    It 'reports approved when license is on the allow list' {
        (Test-LicenseCompliance -License 'MIT' -Config $script:Config).Status |
            Should -Be 'approved'
    }

    It 'reports denied when license is on the deny list' {
        (Test-LicenseCompliance -License 'GPL-3.0' -Config $script:Config).Status |
            Should -Be 'denied'
    }

    It 'reports unknown when license matches neither list' {
        (Test-LicenseCompliance -License 'WTFPL' -Config $script:Config).Status |
            Should -Be 'unknown'
    }

    It 'reports unknown for the literal "UNKNOWN" sentinel' {
        (Test-LicenseCompliance -License 'UNKNOWN' -Config $script:Config).Status |
            Should -Be 'unknown'
    }

    It 'is case-insensitive when matching license identifiers' {
        (Test-LicenseCompliance -License 'mit' -Config $script:Config).Status |
            Should -Be 'approved'
        (Test-LicenseCompliance -License 'gpl-3.0' -Config $script:Config).Status |
            Should -Be 'denied'
    }

    It 'prefers DenyList when the same string appears on both lists' {
        $cfg = [pscustomobject]@{
            AllowList = @('MIT')
            DenyList  = @('MIT')
        }
        (Test-LicenseCompliance -License 'MIT' -Config $cfg).Status |
            Should -Be 'denied'
    }
}

Describe 'Invoke-LicenseCheck (end-to-end report)' {

    BeforeAll {
        $script:Manifest = Join-Path $script:FixturesDir 'pkg-e2e.json'
        @'
{
  "dependencies": {
    "left-pad": "1.3.0",
    "evil-pkg": "0.1.0"
  },
  "devDependencies": {
    "mystery-lib": "1.0.0"
  }
}
'@ | Set-Content -Path $script:Manifest

        $script:ConfigPath = Join-Path $script:FixturesDir 'license-config.json'
        @'
{
  "AllowList": ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC"],
  "DenyList":  ["GPL-3.0", "AGPL-3.0"]
}
'@ | Set-Content -Path $script:ConfigPath

        $script:MockData = Join-Path $script:FixturesDir 'mock-licenses-e2e.json'
        @'
{
  "left-pad": "MIT",
  "evil-pkg": "GPL-3.0"
}
'@ | Set-Content -Path $script:MockData
    }

    It 'returns a report row per dependency' {
        $report = Invoke-LicenseCheck `
            -ManifestPath $script:Manifest `
            -ConfigPath   $script:ConfigPath `
            -MockDataPath $script:MockData
        $report.Dependencies.Count | Should -Be 3
    }

    It 'classifies each dependency correctly' {
        $report = Invoke-LicenseCheck `
            -ManifestPath $script:Manifest `
            -ConfigPath   $script:ConfigPath `
            -MockDataPath $script:MockData

        ($report.Dependencies | Where-Object Name -EQ 'left-pad').Status     | Should -Be 'approved'
        ($report.Dependencies | Where-Object Name -EQ 'evil-pkg').Status     | Should -Be 'denied'
        ($report.Dependencies | Where-Object Name -EQ 'mystery-lib').Status  | Should -Be 'unknown'
    }

    It 'produces an aggregate summary with counts' {
        $report = Invoke-LicenseCheck `
            -ManifestPath $script:Manifest `
            -ConfigPath   $script:ConfigPath `
            -MockDataPath $script:MockData
        $report.Summary.Approved | Should -Be 1
        $report.Summary.Denied   | Should -Be 1
        $report.Summary.Unknown  | Should -Be 1
        $report.Summary.Total    | Should -Be 3
    }

    It 'sets HasViolations=$true when at least one denied dependency exists' {
        $report = Invoke-LicenseCheck `
            -ManifestPath $script:Manifest `
            -ConfigPath   $script:ConfigPath `
            -MockDataPath $script:MockData
        $report.HasViolations | Should -BeTrue
    }

    It 'sets HasViolations=$false for a fully-compliant manifest' {
        $clean = Join-Path $script:FixturesDir 'pkg-clean.json'
        @'
{ "dependencies": { "left-pad": "1.3.0" } }
'@ | Set-Content -Path $clean

        $report = Invoke-LicenseCheck `
            -ManifestPath $clean `
            -ConfigPath   $script:ConfigPath `
            -MockDataPath $script:MockData
        $report.HasViolations | Should -BeFalse
    }
}

Describe 'Format-LicenseReport' {

    BeforeAll {
        $script:SampleReport = [pscustomobject]@{
            Dependencies = @(
                [pscustomobject]@{ Name = 'left-pad'; Version = '1.3.0'; Scope = 'runtime'; License = 'MIT';     Status = 'approved' },
                [pscustomobject]@{ Name = 'evil-pkg'; Version = '0.1.0'; Scope = 'runtime'; License = 'GPL-3.0'; Status = 'denied'   },
                [pscustomobject]@{ Name = 'mystery';  Version = '1.0.0'; Scope = 'dev';     License = 'UNKNOWN'; Status = 'unknown'  }
            )
            Summary = [pscustomobject]@{
                Total = 3; Approved = 1; Denied = 1; Unknown = 1
            }
            HasViolations = $true
        }
    }

    It 'renders text output with one line per dependency' {
        $text = Format-LicenseReport -Report $script:SampleReport -As Text
        $text | Should -Match 'left-pad'
        $text | Should -Match 'evil-pkg'
        $text | Should -Match 'mystery'
    }

    It 'includes status tokens approved/denied/unknown in text output' {
        $text = Format-LicenseReport -Report $script:SampleReport -As Text
        $text | Should -Match 'approved'
        $text | Should -Match 'denied'
        $text | Should -Match 'unknown'
    }

    It 'renders the Summary line with TOTAL=3 APPROVED=1 DENIED=1 UNKNOWN=1' {
        $text = Format-LicenseReport -Report $script:SampleReport -As Text
        $text | Should -Match 'TOTAL=3'
        $text | Should -Match 'APPROVED=1'
        $text | Should -Match 'DENIED=1'
        $text | Should -Match 'UNKNOWN=1'
    }

    It 'renders JSON output that round-trips through ConvertFrom-Json' {
        $json = Format-LicenseReport -Report $script:SampleReport -As Json
        { $json | ConvertFrom-Json } | Should -Not -Throw
        ($json | ConvertFrom-Json).Summary.Total | Should -Be 3
    }
}
