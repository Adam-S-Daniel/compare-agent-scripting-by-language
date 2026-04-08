# DependencyLicenseChecker.Tests.ps1
# Pester tests for the dependency license checker.
# We follow red/green TDD: each test is written before the implementation.

BeforeAll {
    . "$PSScriptRoot/DependencyLicenseChecker.ps1"
}

Describe "Get-Dependencies" {

    Context "package.json parsing" {
        It "extracts dependencies with names and versions from package.json" {
            $json = @'
{
  "name": "my-app",
  "dependencies": {
    "express": "^4.18.0",
    "lodash": "4.17.21"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  }
}
'@
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tmpDir | Out-Null
            $tmpFile = Join-Path $tmpDir "package.json"
            Set-Content -Path $tmpFile -Value $json
            try {
                $deps = Get-Dependencies -Path $tmpFile
                $deps | Should -HaveCount 3
                $deps[0].Name | Should -Be "express"
                $deps[0].Version | Should -Be "^4.18.0"
                $deps[1].Name | Should -Be "lodash"
                $deps[1].Version | Should -Be "4.17.21"
                $deps[2].Name | Should -Be "jest"
                $deps[2].Version | Should -Be "^29.0.0"
            } finally {
                Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
            }
        }
    }

    Context "requirements.txt parsing" {
        It "extracts dependencies with pinned versions from requirements.txt" {
            $content = @"
flask==2.3.0
requests>=2.28.0
# a comment
numpy==1.24.0

"@
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tmpDir | Out-Null
            $tmpFile = Join-Path $tmpDir "requirements.txt"
            Set-Content -Path $tmpFile -Value $content
            try {
                $deps = Get-Dependencies -Path $tmpFile
                $deps | Should -HaveCount 3
                $deps[0].Name | Should -Be "flask"
                $deps[0].Version | Should -Be "2.3.0"
                $deps[1].Name | Should -Be "requests"
                $deps[1].Version | Should -Be "2.28.0"
                $deps[2].Name | Should -Be "numpy"
                $deps[2].Version | Should -Be "1.24.0"
            } finally {
                Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
            }
        }
    }

    Context "error handling" {
        It "throws when file does not exist" {
            { Get-Dependencies -Path "/nonexistent/package.json" } | Should -Throw "*not found*"
        }

        It "throws for unsupported manifest formats" {
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tmpDir | Out-Null
            $tmpFile = Join-Path $tmpDir "Gemfile"
            Set-Content -Path $tmpFile -Value "gem 'rails'"
            try {
                { Get-Dependencies -Path $tmpFile } | Should -Throw "*Unsupported*"
            } finally {
                Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Get-DependencyLicense" {
    # Uses a mock license database (hashtable) to simulate license lookups.
    # This avoids hitting any real registry API during tests.

    It "returns the license for a known package" {
        $mockDb = @{
            "express" = "MIT"
            "lodash"  = "MIT"
            "flask"   = "BSD-3-Clause"
        }
        $result = Get-DependencyLicense -Name "express" -LicenseDatabase $mockDb
        $result | Should -Be "MIT"
    }

    It "returns 'Unknown' for a package not in the database" {
        $mockDb = @{ "express" = "MIT" }
        $result = Get-DependencyLicense -Name "obscure-pkg" -LicenseDatabase $mockDb
        $result | Should -Be "Unknown"
    }
}

Describe "Test-LicenseCompliance" {
    # Tests license checking against allow and deny lists.
    # Config structure: AllowList = @("MIT", "Apache-2.0"), DenyList = @("GPL-3.0")

    It "marks allowed licenses as Approved" {
        $config = @{
            AllowList = @("MIT", "Apache-2.0")
            DenyList  = @("GPL-3.0")
        }
        $result = Test-LicenseCompliance -License "MIT" -Config $config
        $result | Should -Be "Approved"
    }

    It "marks denied licenses as Denied" {
        $config = @{
            AllowList = @("MIT", "Apache-2.0")
            DenyList  = @("GPL-3.0")
        }
        $result = Test-LicenseCompliance -License "GPL-3.0" -Config $config
        $result | Should -Be "Denied"
    }

    It "marks licenses not on either list as Unknown" {
        $config = @{
            AllowList = @("MIT")
            DenyList  = @("GPL-3.0")
        }
        $result = Test-LicenseCompliance -License "ISC" -Config $config
        $result | Should -Be "Unknown"
    }

    It "marks Unknown license lookups as Unknown status" {
        $config = @{
            AllowList = @("MIT")
            DenyList  = @("GPL-3.0")
        }
        $result = Test-LicenseCompliance -License "Unknown" -Config $config
        $result | Should -Be "Unknown"
    }

    It "deny list takes precedence over allow list" {
        # If a license appears on both lists, deny wins (safety first)
        $config = @{
            AllowList = @("MIT", "GPL-3.0")
            DenyList  = @("GPL-3.0")
        }
        $result = Test-LicenseCompliance -License "GPL-3.0" -Config $config
        $result | Should -Be "Denied"
    }
}

Describe "New-ComplianceReport" {
    # Integration test: wires together parsing, license lookup, and compliance check.
    # Uses a mock license database and a sample package.json.

    BeforeAll {
        # Shared test fixtures
        $script:mockLicenseDb = @{
            "express"  = "MIT"
            "lodash"   = "MIT"
            "evil-pkg" = "GPL-3.0"
        }
        $script:config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-3-Clause")
            DenyList  = @("GPL-3.0", "AGPL-3.0")
        }
    }

    It "produces a report with correct statuses for each dependency" {
        $json = @'
{
  "dependencies": {
    "express": "^4.18.0",
    "lodash": "4.17.21",
    "evil-pkg": "1.0.0",
    "mystery-lib": "2.0.0"
  }
}
'@
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        $tmpFile = Join-Path $tmpDir "package.json"
        Set-Content -Path $tmpFile -Value $json
        try {
            $report = New-ComplianceReport -ManifestPath $tmpFile -LicenseDatabase $script:mockLicenseDb -Config $script:config
            $report.Entries | Should -HaveCount 4

            # express: MIT -> Approved
            $express = $report.Entries | Where-Object { $_.Name -eq "express" }
            $express.License | Should -Be "MIT"
            $express.Status | Should -Be "Approved"

            # evil-pkg: GPL-3.0 -> Denied
            $evil = $report.Entries | Where-Object { $_.Name -eq "evil-pkg" }
            $evil.License | Should -Be "GPL-3.0"
            $evil.Status | Should -Be "Denied"

            # mystery-lib: not in DB -> Unknown license -> Unknown status
            $mystery = $report.Entries | Where-Object { $_.Name -eq "mystery-lib" }
            $mystery.License | Should -Be "Unknown"
            $mystery.Status | Should -Be "Unknown"
        } finally {
            Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
        }
    }

    It "includes summary counts in the report" {
        $json = @'
{
  "dependencies": {
    "express": "^4.18.0",
    "evil-pkg": "1.0.0",
    "mystery-lib": "2.0.0"
  }
}
'@
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        $tmpFile = Join-Path $tmpDir "package.json"
        Set-Content -Path $tmpFile -Value $json
        try {
            $report = New-ComplianceReport -ManifestPath $tmpFile -LicenseDatabase $script:mockLicenseDb -Config $script:config
            $report.Summary.Total | Should -Be 3
            $report.Summary.Approved | Should -Be 1
            $report.Summary.Denied | Should -Be 1
            $report.Summary.Unknown | Should -Be 1
        } finally {
            Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
        }
    }

    It "works with requirements.txt" {
        $content = @"
flask==2.3.0
requests>=2.28.0
"@
        $mockDb = @{
            "flask"    = "BSD-3-Clause"
            "requests" = "Apache-2.0"
        }
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        $tmpFile = Join-Path $tmpDir "requirements.txt"
        Set-Content -Path $tmpFile -Value $content
        try {
            $report = New-ComplianceReport -ManifestPath $tmpFile -LicenseDatabase $mockDb -Config $script:config
            $report.Entries | Should -HaveCount 2
            ($report.Entries | Where-Object { $_.Status -eq "Approved" }) | Should -HaveCount 2
            $report.Summary.Approved | Should -Be 2
            $report.Summary.Denied | Should -Be 0
        } finally {
            Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
        }
    }
}

Describe "Import-LicenseConfig" {
    It "loads allow and deny lists from a JSON config file" {
        $configJson = @'
{
  "allowList": ["MIT", "Apache-2.0", "BSD-2-Clause"],
  "denyList": ["GPL-3.0", "AGPL-3.0"]
}
'@
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        $tmpFile = Join-Path $tmpDir "license-config.json"
        Set-Content -Path $tmpFile -Value $configJson
        try {
            $config = Import-LicenseConfig -Path $tmpFile
            $config.AllowList | Should -Contain "MIT"
            $config.AllowList | Should -Contain "Apache-2.0"
            $config.DenyList | Should -Contain "GPL-3.0"
            $config.DenyList | Should -HaveCount 2
        } finally {
            Remove-Item $tmpDir -Recurse -ErrorAction SilentlyContinue
        }
    }

    It "throws when config file is missing" {
        { Import-LicenseConfig -Path "/nonexistent/config.json" } | Should -Throw "*not found*"
    }
}

Describe "Format-ComplianceReport" {
    It "produces a human-readable text report" {
        $report = [PSCustomObject]@{
            Entries = @(
                [PSCustomObject]@{ Name = "express"; Version = "^4.18.0"; License = "MIT"; Status = "Approved" }
                [PSCustomObject]@{ Name = "evil-pkg"; Version = "1.0.0"; License = "GPL-3.0"; Status = "Denied" }
                [PSCustomObject]@{ Name = "mystery"; Version = "2.0.0"; License = "Unknown"; Status = "Unknown" }
            )
            Summary = [PSCustomObject]@{ Total = 3; Approved = 1; Denied = 1; Unknown = 1 }
        }
        $text = Format-ComplianceReport -Report $report
        # Should contain key pieces of information
        $text | Should -Match "express"
        $text | Should -Match "Approved"
        $text | Should -Match "evil-pkg"
        $text | Should -Match "Denied"
        $text | Should -Match "mystery"
        $text | Should -Match "Unknown"
        # Should include summary line
        $text | Should -Match "Total: 3"
        $text | Should -Match "Approved: 1"
        $text | Should -Match "Denied: 1"
    }
}
