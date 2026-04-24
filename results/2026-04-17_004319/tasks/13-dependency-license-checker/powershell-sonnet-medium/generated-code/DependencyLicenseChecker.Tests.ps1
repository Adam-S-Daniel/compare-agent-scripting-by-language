# Pester tests for the Dependency License Checker
# TDD: tests written before implementation, red -> green -> refactor

# In Pester v5 functions must be dot-sourced inside BeforeAll so they
# survive into the test run phase (discovery-phase imports are discarded).
BeforeAll {
    . (Join-Path $PSScriptRoot "DependencyLicenseChecker.ps1")
}

Describe "Parse-DependencyManifest" {
    Context "package.json parsing" {
        It "extracts production dependencies with versions" {
            $fixture = Join-Path $PSScriptRoot "fixtures/package.json"
            $result = Parse-DependencyManifest -Path $fixture
            $result.Count | Should -Be 5
            $dep = $result | Where-Object { $_.Name -eq "lodash" }
            $dep | Should -Not -BeNullOrEmpty
            $dep.Version | Should -Be "^4.17.21"
        }

        It "includes devDependencies" {
            $fixture = Join-Path $PSScriptRoot "fixtures/package.json"
            $result = Parse-DependencyManifest -Path $fixture
            $names = $result | Select-Object -ExpandProperty Name
            $names | Should -Contain "jest"
            $names | Should -Contain "typescript"
        }

        It "sets ManifestType to npm for package.json" {
            $fixture = Join-Path $PSScriptRoot "fixtures/package.json"
            $result = Parse-DependencyManifest -Path $fixture
            $result[0].ManifestType | Should -Be "npm"
        }
    }

    Context "requirements.txt parsing" {
        It "extracts packages with pinned versions" {
            $fixture = Join-Path $PSScriptRoot "fixtures/requirements.txt"
            $result = Parse-DependencyManifest -Path $fixture
            $result.Count | Should -Be 5
            $dep = $result | Where-Object { $_.Name -eq "requests" }
            $dep.Version | Should -Be "2.31.0"
        }

        It "sets ManifestType to pip for requirements.txt" {
            $fixture = Join-Path $PSScriptRoot "fixtures/requirements.txt"
            $result = Parse-DependencyManifest -Path $fixture
            $result[0].ManifestType | Should -Be "pip"
        }
    }

    Context "error handling" {
        It "throws on missing file" {
            { Parse-DependencyManifest -Path "nonexistent.json" } | Should -Throw
        }

        It "throws on unsupported manifest type" {
            $tmp = New-TemporaryFile
            Rename-Item $tmp.FullName ($tmp.FullName + ".toml")
            { Parse-DependencyManifest -Path ($tmp.FullName + ".toml") } | Should -Throw
            Remove-Item ($tmp.FullName + ".toml") -ErrorAction SilentlyContinue
        }
    }
}

Describe "Get-LicenseInfo" {
    It "returns known license from mock database" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $result = Get-LicenseInfo -PackageName "lodash" -MockDatabasePath $mockDb
        $result | Should -Be "MIT"
    }

    It "returns null for unknown package" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $result = Get-LicenseInfo -PackageName "unknown-package" -MockDatabasePath $mockDb
        $result | Should -BeNullOrEmpty
    }

    It "is case-insensitive for package names" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $result = Get-LicenseInfo -PackageName "Lodash" -MockDatabasePath $mockDb
        $result | Should -Be "MIT"
    }
}

Describe "Test-LicenseCompliance" {
    BeforeAll {
        # $script: prefix makes the variable available inside all It blocks
        $script:tlcConfig = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1", "LGPL-3.0")
        }
    }

    It "returns approved for MIT license" {
        $result = Test-LicenseCompliance -License "MIT" -Config $script:tlcConfig
        $result | Should -Be "approved"
    }

    It "returns denied for GPL-3.0 license" {
        $result = Test-LicenseCompliance -License "GPL-3.0" -Config $script:tlcConfig
        $result | Should -Be "denied"
    }

    It "returns unknown for unlisted license" {
        $result = Test-LicenseCompliance -License "WTFPL" -Config $script:tlcConfig
        $result | Should -Be "unknown"
    }

    It "returns unknown when license is null" {
        $result = Test-LicenseCompliance -License $null -Config $script:tlcConfig
        $result | Should -Be "unknown"
    }

    It "returns approved for Apache-2.0" {
        $result = Test-LicenseCompliance -License "Apache-2.0" -Config $script:tlcConfig
        $result | Should -Be "approved"
    }
}

Describe "New-ComplianceReport" {
    It "produces a report with correct status counts" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1", "LGPL-3.0")
        }
        $deps = @(
            [PSCustomObject]@{ Name = "lodash"; Version = "^4.17.21"; ManifestType = "npm" },
            [PSCustomObject]@{ Name = "gpl-package"; Version = "1.0.0"; ManifestType = "npm" },
            [PSCustomObject]@{ Name = "unknown-package"; Version = "0.1.0"; ManifestType = "npm" }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $config -MockDatabasePath $mockDb

        $report.Summary.Total | Should -Be 3
        $report.Summary.Approved | Should -Be 1
        $report.Summary.Denied | Should -Be 1
        $report.Summary.Unknown | Should -Be 1
    }

    It "includes per-dependency details" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1", "LGPL-3.0")
        }
        $deps = @(
            [PSCustomObject]@{ Name = "lodash"; Version = "^4.17.21"; ManifestType = "npm" }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $config -MockDatabasePath $mockDb

        $entry = $report.Dependencies[0]
        $entry.Name    | Should -Be "lodash"
        $entry.Version | Should -Be "^4.17.21"
        $entry.License | Should -Be "MIT"
        $entry.Status  | Should -Be "approved"
    }

    It "sets overall compliance to false when any dependency is denied" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1", "LGPL-3.0")
        }
        $deps = @(
            [PSCustomObject]@{ Name = "lodash"; Version = "^4.17.21"; ManifestType = "npm" },
            [PSCustomObject]@{ Name = "gpl-package"; Version = "1.0.0"; ManifestType = "npm" }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $config -MockDatabasePath $mockDb
        $report.Compliant | Should -Be $false
    }

    It "sets overall compliance to true when all dependencies are approved" {
        $mockDb = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1", "LGPL-3.0")
        }
        $deps = @(
            [PSCustomObject]@{ Name = "lodash"; Version = "^4.17.21"; ManifestType = "npm" },
            [PSCustomObject]@{ Name = "express"; Version = "^4.18.2"; ManifestType = "npm" }
        )
        $report = New-ComplianceReport -Dependencies $deps -Config $config -MockDatabasePath $mockDb
        $report.Compliant | Should -Be $true
    }
}

Describe "Invoke-LicenseCheck (integration)" {
    It "runs end-to-end on package.json and produces report" {
        $manifest = Join-Path $PSScriptRoot "fixtures/package.json"
        $mockDb   = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $config   = Join-Path $PSScriptRoot "fixtures/license-config.json"

        $report = Invoke-LicenseCheck -ManifestPath $manifest -ConfigPath $config -MockDatabasePath $mockDb

        $report | Should -Not -BeNullOrEmpty
        $report.Summary.Total | Should -Be 5
        # lodash, express, moment, jest, typescript are all MIT/Apache -> approved
        $report.Summary.Approved | Should -Be 5
        $report.Summary.Denied   | Should -Be 0
        $report.Compliant        | Should -Be $true
    }

    It "runs end-to-end on requirements.txt and detects denied package" {
        $manifest = Join-Path $PSScriptRoot "fixtures/requirements.txt"
        $mockDb   = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
        $config   = Join-Path $PSScriptRoot "fixtures/license-config.json"

        $report = Invoke-LicenseCheck -ManifestPath $manifest -ConfigPath $config -MockDatabasePath $mockDb

        $report.Summary.Total   | Should -Be 5
        $report.Summary.Denied  | Should -Be 1
        $report.Summary.Unknown | Should -Be 1
        $report.Compliant       | Should -Be $false
    }
}
