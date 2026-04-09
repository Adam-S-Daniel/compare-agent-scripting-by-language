# Pester tests for Dependency License Checker
# TDD approach: each Describe block was written as a failing test first,
# then the implementation was added to make it pass.

BeforeAll {
    # Import the module under test
    $scriptPath = Join-Path $PSScriptRoot ".." "LicenseChecker.ps1"
    . $scriptPath
}

# --- Test 1: Parse package.json ---
Describe "Parse-PackageJson" {
    It "extracts dependency names and versions from package.json" {
        $fixturePath = Join-Path $PSScriptRoot "fixtures" "package.json"
        $deps = Parse-PackageJson -Path $fixturePath

        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 5
        ($deps | Where-Object { $_.Name -eq "express" }).Version | Should -Be "4.18.2"
        ($deps | Where-Object { $_.Name -eq "lodash" }).Version | Should -Be "4.17.21"
    }

    It "throws a meaningful error for missing file" {
        { Parse-PackageJson -Path "/nonexistent/package.json" } | Should -Throw "*not found*"
    }
}

# --- Test 2: Parse requirements.txt ---
Describe "Parse-RequirementsTxt" {
    It "extracts dependency names and versions from requirements.txt" {
        $fixturePath = Join-Path $PSScriptRoot "fixtures" "requirements.txt"
        $deps = Parse-RequirementsTxt -Path $fixturePath

        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 5
        ($deps | Where-Object { $_.Name -eq "requests" }).Version | Should -Be "2.31.0"
        ($deps | Where-Object { $_.Name -eq "flask" }).Version | Should -Be "3.0.0"
    }

    It "throws a meaningful error for missing file" {
        { Parse-RequirementsTxt -Path "/nonexistent/requirements.txt" } | Should -Throw "*not found*"
    }
}

# --- Test 3: Load license config ---
Describe "Get-LicenseConfig" {
    It "loads allow and deny lists from JSON config" {
        $configPath = Join-Path $PSScriptRoot "fixtures" "license-config.json"
        $config = Get-LicenseConfig -Path $configPath

        $config.AllowList | Should -Contain "MIT"
        $config.AllowList | Should -Contain "Apache-2.0"
        $config.DenyList | Should -Contain "GPL-2.0"
        $config.DenyList | Should -Contain "GPL-3.0"
    }
}

# --- Test 4: Mock license lookup ---
Describe "Get-DependencyLicense" {
    It "returns license for known dependency using mock data" {
        # Mock lookup table simulating a license database
        $mockDb = @{
            "express"     = "MIT"
            "lodash"      = "MIT"
            "react"       = "MIT"
            "gpl-package" = "GPL-3.0"
            "requests"    = "Apache-2.0"
            "flask"       = "BSD-3-Clause"
            "django"      = "BSD-3-Clause"
            "gpl-lib"     = "GPL-2.0"
        }

        $license = Get-DependencyLicense -Name "express" -Version "4.18.2" -MockDatabase $mockDb
        $license | Should -Be "MIT"

        $license = Get-DependencyLicense -Name "gpl-package" -Version "1.0.0" -MockDatabase $mockDb
        $license | Should -Be "GPL-3.0"
    }

    It "returns UNKNOWN for dependencies not in mock database" {
        $mockDb = @{ "express" = "MIT" }
        $license = Get-DependencyLicense -Name "mystery-package" -Version "0.1.0" -MockDatabase $mockDb
        $license | Should -Be "UNKNOWN"
    }
}

# --- Test 5: Check license against allow/deny list ---
Describe "Get-LicenseStatus" {
    It "returns 'approved' for licenses in the allow list" {
        $config = [PSCustomObject]@{
            AllowList = @("MIT", "Apache-2.0")
            DenyList  = @("GPL-2.0", "GPL-3.0")
        }
        $status = Get-LicenseStatus -License "MIT" -Config $config
        $status | Should -Be "approved"
    }

    It "returns 'denied' for licenses in the deny list" {
        $config = [PSCustomObject]@{
            AllowList = @("MIT", "Apache-2.0")
            DenyList  = @("GPL-2.0", "GPL-3.0")
        }
        $status = Get-LicenseStatus -License "GPL-3.0" -Config $config
        $status | Should -Be "denied"
    }

    It "returns 'unknown' for licenses in neither list" {
        $config = [PSCustomObject]@{
            AllowList = @("MIT", "Apache-2.0")
            DenyList  = @("GPL-2.0", "GPL-3.0")
        }
        $status = Get-LicenseStatus -License "UNKNOWN" -Config $config
        $status | Should -Be "unknown"

        $status = Get-LicenseStatus -License "WTFPL" -Config $config
        $status | Should -Be "unknown"
    }
}

# --- Test 6: Generate compliance report ---
Describe "Invoke-LicenseCheck" {
    BeforeAll {
        $script:mockDb = @{
            "express"         = "MIT"
            "lodash"          = "MIT"
            "react"           = "MIT"
            "gpl-package"     = "GPL-3.0"
            "unknown-lib"     = "UNKNOWN"
            "requests"        = "Apache-2.0"
            "flask"           = "BSD-3-Clause"
            "django"          = "BSD-3-Clause"
            "gpl-lib"         = "GPL-2.0"
            "mystery-package" = "UNKNOWN"
        }
        $script:config = [PSCustomObject]@{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0")
        }
    }

    It "generates a report with approved, denied, and unknown entries for package.json" {
        $fixturePath = Join-Path $PSScriptRoot "fixtures" "package.json"
        $report = Invoke-LicenseCheck -ManifestPath $fixturePath -Config $script:config -MockDatabase $script:mockDb

        $report | Should -Not -BeNullOrEmpty
        $report.Count | Should -Be 5

        ($report | Where-Object { $_.Name -eq "express" }).Status | Should -Be "approved"
        ($report | Where-Object { $_.Name -eq "gpl-package" }).Status | Should -Be "denied"
        ($report | Where-Object { $_.Name -eq "unknown-lib" }).Status | Should -Be "unknown"
    }

    It "generates a report for requirements.txt" {
        $fixturePath = Join-Path $PSScriptRoot "fixtures" "requirements.txt"
        $report = Invoke-LicenseCheck -ManifestPath $fixturePath -Config $script:config -MockDatabase $script:mockDb

        $report | Should -Not -BeNullOrEmpty
        $report.Count | Should -Be 5
        ($report | Where-Object { $_.Name -eq "flask" }).Status | Should -Be "approved"
        ($report | Where-Object { $_.Name -eq "gpl-lib" }).Status | Should -Be "denied"
        ($report | Where-Object { $_.Name -eq "mystery-package" }).Status | Should -Be "unknown"
    }

    It "report entries contain Name, Version, License, and Status fields" {
        $fixturePath = Join-Path $PSScriptRoot "fixtures" "package.json"
        $report = Invoke-LicenseCheck -ManifestPath $fixturePath -Config $script:config -MockDatabase $script:mockDb

        $entry = $report | Where-Object { $_.Name -eq "express" }
        $entry.Name    | Should -Be "express"
        $entry.Version | Should -Be "4.18.2"
        $entry.License | Should -Be "MIT"
        $entry.Status  | Should -Be "approved"
    }
}

# --- Test 7: Format report output ---
Describe "Format-ComplianceReport" {
    It "formats report as readable text with summary" {
        $report = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.2"; License = "MIT";     Status = "approved" }
            [PSCustomObject]@{ Name = "gpl-pkg"; Version = "1.0.0";  License = "GPL-3.0"; Status = "denied"   }
            [PSCustomObject]@{ Name = "unknown"; Version = "0.1.0";  License = "UNKNOWN"; Status = "unknown"  }
        )

        $output = Format-ComplianceReport -Report $report

        $output | Should -Match "express"
        $output | Should -Match "approved"
        $output | Should -Match "gpl-pkg"
        $output | Should -Match "denied"
        $output | Should -Match "SUMMARY"
        $output | Should -Match "Approved:"
        $output | Should -Match "Denied:"
        $output | Should -Match "Unknown:"
    }
}

# --- Test 8: Overall exit code based on denied licenses ---
Describe "Get-ComplianceExitCode" {
    It "returns 0 when no denied licenses" {
        $report = @(
            [PSCustomObject]@{ Status = "approved" }
            [PSCustomObject]@{ Status = "unknown"  }
        )
        $code = Get-ComplianceExitCode -Report $report
        $code | Should -Be 0
    }

    It "returns 1 when at least one denied license exists" {
        $report = @(
            [PSCustomObject]@{ Status = "approved" }
            [PSCustomObject]@{ Status = "denied"   }
        )
        $code = Get-ComplianceExitCode -Report $report
        $code | Should -Be 1
    }
}
