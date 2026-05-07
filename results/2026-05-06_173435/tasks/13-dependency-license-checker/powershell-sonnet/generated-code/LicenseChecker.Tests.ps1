# TDD: Dependency License Checker - Pester Tests
# Red/Green cycle: tests written first, then implementation added to make them pass.

BeforeAll {
    # Dot-source the implementation file to load all functions
    . "$PSScriptRoot/LicenseChecker.ps1"
}

# ─── PHASE 1: Parsing dependency manifests ────────────────────────────────────

Describe "Get-DependenciesFromManifest" {

    It "parses dependencies from package.json" {
        $deps = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/package.json"
        @($deps).Count | Should -Be 4
        $deps[0].Name    | Should -Be "express"
        $deps[0].Version | Should -Be "4.18.2"
    }

    It "parses all four dependencies from package.json with correct names" {
        $deps = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/package.json"
        ($deps | Where-Object Name -eq "lodash").Version | Should -Be "4.17.21"
        ($deps | Where-Object Name -eq "gpl-lib").Version | Should -Be "1.0.0"
        ($deps | Where-Object Name -eq "unknown-lib").Version | Should -Be "2.0.0"
    }

    It "parses dependencies from requirements.txt" {
        $deps = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/requirements.txt"
        @($deps).Count | Should -Be 4
        $deps[0].Name    | Should -Be "requests"
        $deps[0].Version | Should -Be "2.31.0"
    }

    It "parses all four requirements.txt packages with correct versions" {
        $deps = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/requirements.txt"
        ($deps | Where-Object Name -eq "flask").Version      | Should -Be "2.3.3"
        ($deps | Where-Object Name -eq "copyleft-lib").Version | Should -Be "1.0.0"
        ($deps | Where-Object Name -eq "mystery-package").Version | Should -Be "0.5.0"
    }

    It "throws a meaningful error for an unsupported manifest type" {
        # File name matters, not existence — type check precedes existence check
        { Get-DependenciesFromManifest -ManifestPath "Gemfile" } | Should -Throw "*Unsupported manifest*"
    }

    It "throws a meaningful error when the file does not exist" {
        # Uses a supported filename but a path that cannot exist → triggers the existence check
        { Get-DependenciesFromManifest -ManifestPath "/tmp/no-such-dir-xyz/package.json" } | Should -Throw "*not found*"
    }
}

# ─── PHASE 2: License compliance checking ─────────────────────────────────────

Describe "Test-LicenseCompliance" {

    BeforeAll {
        $Config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.0", "LGPL-3.0")
        }
    }

    It "returns APPROVED for a license on the allow-list" {
        Test-LicenseCompliance -License "MIT" -Config $Config | Should -Be "APPROVED"
    }

    It "returns APPROVED for Apache-2.0" {
        Test-LicenseCompliance -License "Apache-2.0" -Config $Config | Should -Be "APPROVED"
    }

    It "returns DENIED for a license on the deny-list" {
        Test-LicenseCompliance -License "GPL-3.0" -Config $Config | Should -Be "DENIED"
    }

    It "returns DENIED for AGPL-3.0" {
        Test-LicenseCompliance -License "AGPL-3.0" -Config $Config | Should -Be "DENIED"
    }

    It "returns UNKNOWN when the license is not on either list" {
        Test-LicenseCompliance -License "Proprietary" -Config $Config | Should -Be "UNKNOWN"
    }

    It "returns UNKNOWN for an empty license string" {
        Test-LicenseCompliance -License "" -Config $Config | Should -Be "UNKNOWN"
    }

    It "returns UNKNOWN when the license value is already UNKNOWN" {
        Test-LicenseCompliance -License "UNKNOWN" -Config $Config | Should -Be "UNKNOWN"
    }
}

# ─── PHASE 3: Loading license configuration ───────────────────────────────────

Describe "Get-LicenseConfig" {

    It "loads AllowList and DenyList from the config JSON file" {
        $config = Get-LicenseConfig -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $config.AllowList | Should -Contain "MIT"
        $config.AllowList | Should -Contain "Apache-2.0"
        $config.DenyList  | Should -Contain "GPL-3.0"
        $config.DenyList  | Should -Contain "AGPL-3.0"
    }

    It "throws a meaningful error when config file does not exist" {
        { Get-LicenseConfig -ConfigPath "no-such-config.json" } | Should -Throw "*not found*"
    }
}

# ─── PHASE 4: Compliance report generation (with mocked lookup) ───────────────

Describe "New-ComplianceReport" {

    BeforeAll {
        $Config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0")
        }

        # Mock license lookup: returns deterministic values without hitting any registry
        $MockLookup = {
            param([string]$Name, [string]$Version)
            $table = @{
                "express"     = "MIT"
                "lodash"      = "MIT"
                "gpl-lib"     = "GPL-3.0"
                "unknown-lib" = "UNKNOWN"
            }
            if ($table.ContainsKey($Name)) { return $table[$Name] }
            return "UNKNOWN"
        }

        $Deps = @(
            [PSCustomObject]@{ Name = "express";     Version = "4.18.2"  }
            [PSCustomObject]@{ Name = "lodash";      Version = "4.17.21" }
            [PSCustomObject]@{ Name = "gpl-lib";     Version = "1.0.0"   }
            [PSCustomObject]@{ Name = "unknown-lib"; Version = "2.0.0"   }
        )
    }

    It "returns one result per dependency" {
        $report = New-ComplianceReport -Dependencies $Deps -Config $Config -LicenseLookup $MockLookup
        @($report).Count | Should -Be 4
    }

    It "correctly marks MIT-licensed packages as APPROVED" {
        $report = New-ComplianceReport -Dependencies $Deps -Config $Config -LicenseLookup $MockLookup
        @($report | Where-Object Status -eq "APPROVED").Count | Should -Be 2
    }

    It "correctly marks GPL-licensed package as DENIED" {
        $report = New-ComplianceReport -Dependencies $Deps -Config $Config -LicenseLookup $MockLookup
        $denied = @($report | Where-Object Status -eq "DENIED")
        $denied.Count      | Should -Be 1
        $denied[0].Name    | Should -Be "gpl-lib"
    }

    It "correctly marks unknown-license package as UNKNOWN" {
        $report = New-ComplianceReport -Dependencies $Deps -Config $Config -LicenseLookup $MockLookup
        $unknown = @($report | Where-Object Status -eq "UNKNOWN")
        $unknown.Count      | Should -Be 1
        $unknown[0].Name    | Should -Be "unknown-lib"
    }

    It "includes the dependency version in each report entry" {
        $report = New-ComplianceReport -Dependencies $Deps -Config $Config -LicenseLookup $MockLookup
        ($report | Where-Object Name -eq "express").Version | Should -Be "4.18.2"
    }

    It "includes the resolved license in each report entry" {
        $report = New-ComplianceReport -Dependencies $Deps -Config $Config -LicenseLookup $MockLookup
        ($report | Where-Object Name -eq "express").License | Should -Be "MIT"
        ($report | Where-Object Name -eq "gpl-lib").License | Should -Be "GPL-3.0"
    }
}

# ─── PHASE 5: Formatting the compliance report ────────────────────────────────

Describe "Format-ComplianceReport" {

    BeforeAll {
        $Items = @(
            [PSCustomObject]@{ Name = "express";     Version = "4.18.2"; License = "MIT";     Status = "APPROVED" }
            [PSCustomObject]@{ Name = "gpl-lib";     Version = "1.0.0";  License = "GPL-3.0"; Status = "DENIED"   }
            [PSCustomObject]@{ Name = "unknown-lib"; Version = "2.0.0";  License = "UNKNOWN"; Status = "UNKNOWN"  }
        )
    }

    It "output contains the dependency name" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "express"
        $out | Should -Match "gpl-lib"
    }

    It "output contains the license value" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "MIT"
        $out | Should -Match "GPL-3.0"
    }

    It "output contains APPROVED status" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "APPROVED"
    }

    It "output contains DENIED status" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "DENIED"
    }

    It "summary section shows correct APPROVED count" {
        $out = Format-ComplianceReport -ReportItems $Items
        # "APPROVED: 1" somewhere in the string
        $out | Should -Match "APPROVED:\s*1"
    }

    It "summary section shows correct DENIED count" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "DENIED:\s*1"
    }

    It "summary section shows correct UNKNOWN count" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "UNKNOWN:\s*1"
    }

    It "summary section shows correct Total count" {
        $out = Format-ComplianceReport -ReportItems $Items
        $out | Should -Match "Total:\s*3"
    }
}

# ─── PHASE 6: End-to-end integration using fixture files ──────────────────────

Describe "End-to-end integration" {

    It "produces a DENIED result for gpl-lib in package.json fixture" {
        $config = Get-LicenseConfig -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $deps   = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/package.json"

        $lookup = {
            param([string]$Name, [string]$Version)
            $data = Get-Content "$PSScriptRoot/fixtures/mock-licenses.json" -Raw | ConvertFrom-Json
            $val  = $data.$Name
            if ($null -ne $val) { return $val }
            return "UNKNOWN"
        }

        $report = New-ComplianceReport -Dependencies $deps -Config $config -LicenseLookup $lookup
        ($report | Where-Object Name -eq "gpl-lib").Status | Should -Be "DENIED"
    }

    It "produces APPROVED results for express and lodash in package.json fixture" {
        $config = Get-LicenseConfig -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $deps   = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/package.json"

        $lookup = {
            param([string]$Name, [string]$Version)
            $data = Get-Content "$PSScriptRoot/fixtures/mock-licenses.json" -Raw | ConvertFrom-Json
            $val  = $data.$Name
            if ($null -ne $val) { return $val }
            return "UNKNOWN"
        }

        $report = New-ComplianceReport -Dependencies $deps -Config $config -LicenseLookup $lookup
        ($report | Where-Object Name -eq "express").Status | Should -Be "APPROVED"
        ($report | Where-Object Name -eq "lodash").Status  | Should -Be "APPROVED"
    }

    It "produces a DENIED result for copyleft-lib in requirements.txt fixture" {
        $config = Get-LicenseConfig -ConfigPath "$PSScriptRoot/fixtures/license-config.json"
        $deps   = Get-DependenciesFromManifest -ManifestPath "$PSScriptRoot/fixtures/requirements.txt"

        $lookup = {
            param([string]$Name, [string]$Version)
            $data = Get-Content "$PSScriptRoot/fixtures/mock-licenses.json" -Raw | ConvertFrom-Json
            $val  = $data.$Name
            if ($null -ne $val) { return $val }
            return "UNKNOWN"
        }

        $report = New-ComplianceReport -Dependencies $deps -Config $config -LicenseLookup $lookup
        ($report | Where-Object Name -eq "copyleft-lib").Status | Should -Be "DENIED"
    }
}
