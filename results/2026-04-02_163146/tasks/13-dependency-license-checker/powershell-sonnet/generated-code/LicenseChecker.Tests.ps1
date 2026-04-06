# LicenseChecker.Tests.ps1
# TDD tests for the dependency license checker.
# Tests are written first (red), then the implementation makes them pass (green).

# Pester v5 configuration
BeforeAll {
    # Dot-source the implementation so all functions are available in tests.
    # This will fail until LicenseChecker.ps1 exists — that's intentional (red phase).
    . "$PSScriptRoot/LicenseChecker.ps1"

    # Paths to test fixtures
    $script:FixturesDir  = "$PSScriptRoot/fixtures"
    $script:ConfigFile   = "$PSScriptRoot/config/license-config.json"
}

# ---------------------------------------------------------------------------
# 1. Manifest parsing — package.json
# ---------------------------------------------------------------------------
Describe "Parse-PackageJson" {
    It "extracts production dependencies with cleaned version strings" {
        $deps = Parse-PackageJson -Path "$script:FixturesDir/package.json"

        # Should return a list of objects with Name + Version
        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 6   # 6 production deps (devDeps excluded)

        $express = $deps | Where-Object { $_.Name -eq "express" }
        $express | Should -Not -BeNullOrEmpty
        # Version prefix characters (^, ~) should be stripped
        $express.Version | Should -Be "4.18.2"
    }

    It "strips ~ and ^ version prefix characters" {
        $deps = Parse-PackageJson -Path "$script:FixturesDir/package.json"
        $lodash = $deps | Where-Object { $_.Name -eq "lodash" }
        $lodash.Version | Should -Be "4.17.21"
    }

    It "throws a meaningful error when the file does not exist" {
        { Parse-PackageJson -Path "nonexistent/package.json" } | Should -Throw "*not found*"
    }
}

# ---------------------------------------------------------------------------
# 2. Manifest parsing — requirements.txt
# ---------------------------------------------------------------------------
Describe "Parse-RequirementsTxt" {
    It "extracts packages with their pinned versions" {
        $deps = Parse-RequirementsTxt -Path "$script:FixturesDir/requirements.txt"

        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 6   # 6 non-comment lines

        $requests = $deps | Where-Object { $_.Name -eq "requests" }
        $requests | Should -Not -BeNullOrEmpty
        $requests.Version | Should -Be "2.31.0"
    }

    It "ignores comment lines starting with #" {
        $deps = Parse-RequirementsTxt -Path "$script:FixturesDir/requirements.txt"
        # No dependency name should start with '#'
        $deps | ForEach-Object { $_.Name | Should -Not -Match "^#" }
    }

    It "throws a meaningful error when the file does not exist" {
        { Parse-RequirementsTxt -Path "nonexistent/requirements.txt" } | Should -Throw "*not found*"
    }
}

# ---------------------------------------------------------------------------
# 3. License configuration loading
# ---------------------------------------------------------------------------
Describe "Get-LicenseConfig" {
    It "loads allow-list and deny-list from a JSON config file" {
        $config = Get-LicenseConfig -Path $script:ConfigFile

        $config.AllowList | Should -Contain "MIT"
        $config.AllowList | Should -Contain "Apache-2.0"
        $config.DenyList  | Should -Contain "GPL-3.0"
        $config.DenyList  | Should -Contain "AGPL-3.0"
    }

    It "throws when config file is missing" {
        { Get-LicenseConfig -Path "no/such/config.json" } | Should -Throw "*not found*"
    }
}

# ---------------------------------------------------------------------------
# 4. License lookup (mocked)
# ---------------------------------------------------------------------------
Describe "Get-DependencyLicense" {
    It "returns the license for a known package via the mock lookup table" {
        # The mock lookup is a hashtable passed to the function so tests stay deterministic.
        $mockLookup = @{
            "express"     = "MIT"
            "lodash"      = "MIT"
            "axios"       = "MIT"
            "react"       = "MIT"
            "gpl-lib"     = "GPL-3.0"
            "mystery-pkg" = $null       # unknown — not in lookup
        }

        $license = Get-DependencyLicense -Name "express" -Version "4.18.2" -MockLookup $mockLookup
        $license | Should -Be "MIT"
    }

    It "returns `$null for a package not in the mock lookup table" {
        $mockLookup = @{ "known-pkg" = "MIT" }
        $license = Get-DependencyLicense -Name "mystery-pkg" -Version "1.0.0" -MockLookup $mockLookup
        $license | Should -BeNullOrEmpty
    }

    It "returns a GPL license for a denied package" {
        $mockLookup = @{ "gpl-lib" = "GPL-3.0" }
        $license = Get-DependencyLicense -Name "gpl-lib" -Version "2.0.0" -MockLookup $mockLookup
        $license | Should -Be "GPL-3.0"
    }
}

# ---------------------------------------------------------------------------
# 5. Compliance classification
# ---------------------------------------------------------------------------
Describe "Get-ComplianceStatus" {
    BeforeAll {
        $script:Config = Get-LicenseConfig -Path $script:ConfigFile
    }

    It "returns 'approved' for a license on the allow-list" {
        $status = Get-ComplianceStatus -License "MIT" -Config $script:Config
        $status | Should -Be "approved"
    }

    It "returns 'denied' for a license on the deny-list" {
        $status = Get-ComplianceStatus -License "GPL-3.0" -Config $script:Config
        $status | Should -Be "denied"
    }

    It "returns 'unknown' when the license is null" {
        $status = Get-ComplianceStatus -License $null -Config $script:Config
        $status | Should -Be "unknown"
    }

    It "returns 'unknown' when the license is not in either list" {
        $status = Get-ComplianceStatus -License "LicenseRef-Proprietary" -Config $script:Config
        $status | Should -Be "unknown"
    }
}

# ---------------------------------------------------------------------------
# 6. Full compliance report generation
# ---------------------------------------------------------------------------
Describe "Invoke-LicenseCheck" {
    BeforeAll {
        # Mock license lookup table covering all deps in fixtures/package.json
        $script:MockLookup = @{
            "express"     = "MIT"
            "lodash"      = "MIT"
            "axios"       = "MIT"
            "react"       = "MIT"
            "gpl-lib"     = "GPL-3.0"
            "mystery-pkg" = $null
        }
    }

    It "produces a report entry for every dependency" {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$script:FixturesDir/package.json" `
            -ConfigPath   $script:ConfigFile `
            -MockLookup   $script:MockLookup

        $report.Count | Should -Be 6
    }

    It "marks MIT-licensed packages as approved" {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$script:FixturesDir/package.json" `
            -ConfigPath   $script:ConfigFile `
            -MockLookup   $script:MockLookup

        $express = $report | Where-Object { $_.Name -eq "express" }
        $express.License | Should -Be "MIT"
        $express.Status  | Should -Be "approved"
    }

    It "marks GPL packages as denied" {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$script:FixturesDir/package.json" `
            -ConfigPath   $script:ConfigFile `
            -MockLookup   $script:MockLookup

        $gpl = $report | Where-Object { $_.Name -eq "gpl-lib" }
        $gpl.License | Should -Be "GPL-3.0"
        $gpl.Status  | Should -Be "denied"
    }

    It "marks packages with no license info as unknown" {
        $report = Invoke-LicenseCheck `
            -ManifestPath "$script:FixturesDir/package.json" `
            -ConfigPath   $script:ConfigFile `
            -MockLookup   $script:MockLookup

        $mystery = $report | Where-Object { $_.Name -eq "mystery-pkg" }
        $mystery.License | Should -BeNullOrEmpty
        $mystery.Status  | Should -Be "unknown"
    }

    It "works with a requirements.txt manifest" {
        $pyMock = @{
            "requests"    = "Apache-2.0"
            "flask"       = "BSD-3-Clause"
            "numpy"       = "BSD-3-Clause"
            "pandas"      = "BSD-3-Clause"
            "gpl-package" = "GPL-2.0"
            "unknown-lib" = $null
        }

        $report = Invoke-LicenseCheck `
            -ManifestPath "$script:FixturesDir/requirements.txt" `
            -ConfigPath   $script:ConfigFile `
            -MockLookup   $pyMock

        $report.Count | Should -Be 6

        ($report | Where-Object { $_.Name -eq "requests" }).Status  | Should -Be "approved"
        ($report | Where-Object { $_.Name -eq "gpl-package" }).Status | Should -Be "denied"
        ($report | Where-Object { $_.Name -eq "unknown-lib" }).Status | Should -Be "unknown"
    }
}

# ---------------------------------------------------------------------------
# 7. Report formatting / export
# ---------------------------------------------------------------------------
Describe "Format-ComplianceReport" {
    BeforeAll {
        $script:SampleReport = @(
            [PSCustomObject]@{ Name = "express";     Version = "4.18.2"; License = "MIT";     Status = "approved" }
            [PSCustomObject]@{ Name = "gpl-lib";     Version = "2.0.0";  License = "GPL-3.0"; Status = "denied"   }
            [PSCustomObject]@{ Name = "mystery-pkg"; Version = "1.0.0";  License = $null;     Status = "unknown"  }
        )
    }

    It "returns a non-empty string summary" {
        $output = Format-ComplianceReport -Report $script:SampleReport
        $output | Should -Not -BeNullOrEmpty
        $output | Should -Match "express"
        $output | Should -Match "approved"
        $output | Should -Match "denied"
        $output | Should -Match "unknown"
    }

    It "includes a summary line with counts" {
        $output = Format-ComplianceReport -Report $script:SampleReport
        # Expect totals somewhere in the output
        $output | Should -Match "approved.*1|1.*approved"
        $output | Should -Match "denied.*1|1.*denied"
        $output | Should -Match "unknown.*1|1.*unknown"
    }
}
