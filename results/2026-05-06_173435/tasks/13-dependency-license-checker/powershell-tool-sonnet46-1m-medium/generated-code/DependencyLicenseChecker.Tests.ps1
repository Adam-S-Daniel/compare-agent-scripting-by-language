# DependencyLicenseChecker.Tests.ps1
# Pester test suite for the Dependency License Checker
# Uses red/green TDD: tests written first, then implementation

BeforeAll {
    # Dot-source the implementation so we can test its functions
    . "$PSScriptRoot/DependencyLicenseChecker.ps1"

    # Mock license lookup: simulates calling an external API or registry
    $script:MockLicenses = @{
        "react"       = "MIT"
        "express"     = "MIT"
        "lodash"      = "MIT"
        "axios"       = "MIT"
        "jest"        = "MIT"
        "bad-lib"     = "GPL-3.0"
        "another-bad" = "AGPL-3.0"
        "numpy"       = "BSD-3-Clause"
        "requests"    = "Apache-2.0"
        "django"      = "BSD-3-Clause"
        # custom-lib intentionally absent to simulate unknown license
    }

    $script:LicenseLookupMock = {
        param([string]$Name, [string]$Version)
        if ($script:MockLicenses.ContainsKey($Name)) {
            return $script:MockLicenses[$Name]
        }
        return $null  # unknown
    }

    $script:FixturesPath = "$PSScriptRoot/fixtures"
}

# ============================================================
# SECTION 1: Parsing dependency manifests
# ============================================================

Describe "Get-Dependencies - package.json" {
    It "Parses package.json and returns all production dependencies" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/package-basic.json"
        $deps | Should -HaveCount 3
    }

    It "Each dependency has a Name property" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/package-basic.json"
        $deps[0].Name | Should -Be "react"
    }

    It "Each dependency has a Version property (semver prefix stripped)" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/package-basic.json"
        # package.json has "^18.2.0"; we normalize to "18.2.0"
        $react = $deps | Where-Object { $_.Name -eq "react" }
        $react.Version | Should -Be "18.2.0"
    }

    It "Includes devDependencies when requested" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/package-basic.json" -IncludeDev
        $deps.Count | Should -BeGreaterThan 3
    }

    It "Parses package-mixed.json with 4 dependencies" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/package-mixed.json"
        $deps | Should -HaveCount 4
    }
}

Describe "Get-Dependencies - requirements.txt" {
    It "Parses requirements.txt and returns all dependencies" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/requirements-basic.txt"
        $deps | Should -HaveCount 3
    }

    It "Parses == version specifier" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/requirements-basic.txt"
        $numpy = $deps | Where-Object { $_.Name -eq "numpy" }
        $numpy | Should -Not -BeNullOrEmpty
        $numpy.Version | Should -Be "1.24.0"
    }

    It "Parses >= version specifier" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/requirements-basic.txt"
        $requests = $deps | Where-Object { $_.Name -eq "requests" }
        $requests | Should -Not -BeNullOrEmpty
        $requests.Version | Should -Be "2.28.0"
    }

    It "Skips comment lines and blank lines" {
        $deps = Get-Dependencies -ManifestPath "$script:FixturesPath/requirements-basic.txt"
        # requirements-basic.txt has comments; only 3 real deps
        $deps | Should -HaveCount 3
    }
}

Describe "Get-Dependencies - error handling" {
    It "Throws a meaningful error for a missing manifest file" {
        { Get-Dependencies -ManifestPath "/nonexistent/path/package.json" } |
            Should -Throw "*not found*"
    }

    It "Throws a meaningful error for an unsupported file type" {
        { Get-Dependencies -ManifestPath "$script:FixturesPath/unsupported.xyz" } |
            Should -Throw "*not supported*"
    }
}

# ============================================================
# SECTION 2: License status logic
# ============================================================

Describe "Get-LicenseStatus" {
    BeforeAll {
        $script:AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
        $script:DenyList  = @("GPL-2.0", "GPL-3.0", "LGPL-2.0", "LGPL-3.0", "AGPL-3.0")
    }

    It "Returns 'approved' for a license on the allow list" {
        $status = Get-LicenseStatus -License "MIT" -AllowList $script:AllowList -DenyList $script:DenyList
        $status | Should -Be "approved"
    }

    It "Returns 'approved' for Apache-2.0" {
        $status = Get-LicenseStatus -License "Apache-2.0" -AllowList $script:AllowList -DenyList $script:DenyList
        $status | Should -Be "approved"
    }

    It "Returns 'denied' for a license on the deny list" {
        $status = Get-LicenseStatus -License "GPL-3.0" -AllowList $script:AllowList -DenyList $script:DenyList
        $status | Should -Be "denied"
    }

    It "Returns 'denied' for AGPL-3.0" {
        $status = Get-LicenseStatus -License "AGPL-3.0" -AllowList $script:AllowList -DenyList $script:DenyList
        $status | Should -Be "denied"
    }

    It "Returns 'unknown' for a license not in either list" {
        $status = Get-LicenseStatus -License "Proprietary" -AllowList $script:AllowList -DenyList $script:DenyList
        $status | Should -Be "unknown"
    }

    It "Returns 'unknown' when license is null" {
        $status = Get-LicenseStatus -License $null -AllowList $script:AllowList -DenyList $script:DenyList
        $status | Should -Be "unknown"
    }

    It "Deny list takes priority over allow list when license appears in both" {
        $status = Get-LicenseStatus -License "GPL-3.0" -AllowList @("GPL-3.0") -DenyList @("GPL-3.0")
        $status | Should -Be "denied"
    }

    It "Comparison is case-insensitive" {
        $status = Get-LicenseStatus -License "mit" -AllowList @("MIT") -DenyList @()
        $status | Should -Be "approved"
    }
}

# ============================================================
# SECTION 3: Full compliance report
# ============================================================

Describe "Get-ComplianceReport" {
    It "Returns report entries for all dependencies" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $report | Should -Not -BeNullOrEmpty
        $report | Should -HaveCount 4
    }

    It "Correctly identifies approved dependencies" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $approved = $report | Where-Object { $_.Status -eq "approved" }
        $approved | Should -HaveCount 2
        ($approved.Name) | Should -Contain "react"
        ($approved.Name) | Should -Contain "express"
    }

    It "Correctly identifies denied dependencies" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $denied = $report | Where-Object { $_.Status -eq "denied" }
        $denied | Should -HaveCount 1
        $denied[0].Name    | Should -Be "bad-lib"
        $denied[0].License | Should -Be "GPL-3.0"
    }

    It "Correctly identifies unknown dependencies" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $unknown = $report | Where-Object { $_.Status -eq "unknown" }
        $unknown | Should -HaveCount 1
        $unknown[0].Name | Should -Be "custom-lib"
    }

    It "Works with an all-approved manifest" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-approved-only.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $denied  = $report | Where-Object { $_.Status -eq "denied" }
        $unknown = $report | Where-Object { $_.Status -eq "unknown" }
        $denied  | Should -BeNullOrEmpty
        $unknown | Should -BeNullOrEmpty
    }

    It "Works with requirements.txt" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/requirements-basic.txt" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $report | Should -HaveCount 3
        $approved = $report | Where-Object { $_.Status -eq "approved" }
        $approved | Should -HaveCount 3  # numpy=BSD-3, requests=Apache-2, django=BSD-3
    }

    It "Each report entry has Name, Version, License, and Status properties" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-basic.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $entry = $report[0]
        $entry.PSObject.Properties.Name | Should -Contain "Name"
        $entry.PSObject.Properties.Name | Should -Contain "Version"
        $entry.PSObject.Properties.Name | Should -Contain "License"
        $entry.PSObject.Properties.Name | Should -Contain "Status"
    }
}

# ============================================================
# SECTION 4: Format-ComplianceReport (output formatting)
# ============================================================

Describe "Format-ComplianceReport" {
    It "Output contains APPROVED section header" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-mixed.json"
        $output | Should -Match "APPROVED \(2\):"
    }

    It "Output contains DENIED section header" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-mixed.json"
        $output | Should -Match "DENIED \(1\):"
    }

    It "Output contains UNKNOWN section header" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-mixed.json"
        $output | Should -Match "UNKNOWN \(1\):"
    }

    It "Output shows dependency name and license for each entry" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-mixed.json"
        $output | Should -Match "bad-lib"
        $output | Should -Match "GPL-3.0"
        $output | Should -Match "react"
        $output | Should -Match "MIT"
    }

    It "Output contains summary line with counts" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-mixed.json"
        $output | Should -Match "2 approved"
        $output | Should -Match "1 denied"
        $output | Should -Match "1 unknown"
    }

    It "Shows FAIL status when denied deps exist" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-mixed.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-mixed.json"
        $output | Should -Match "Status: FAIL"
    }

    It "Shows PASS status when no denied deps" {
        $report = Get-ComplianceReport `
            -ManifestPath "$script:FixturesPath/package-approved-only.json" `
            -ConfigPath   "$script:FixturesPath/license-config.json" `
            -LicenseLookup $script:LicenseLookupMock

        $output = Format-ComplianceReport -Report $report -ManifestPath "$script:FixturesPath/package-approved-only.json"
        $output | Should -Match "Status: PASS"
    }
}

# ============================================================
# SECTION 5: Config loading
# ============================================================

Describe "Get-LicenseConfig" {
    It "Loads allow list from config file" {
        $config = Get-LicenseConfig -ConfigPath "$script:FixturesPath/license-config.json"
        $config.AllowList | Should -Contain "MIT"
        $config.AllowList | Should -Contain "Apache-2.0"
    }

    It "Loads deny list from config file" {
        $config = Get-LicenseConfig -ConfigPath "$script:FixturesPath/license-config.json"
        $config.DenyList | Should -Contain "GPL-3.0"
        $config.DenyList | Should -Contain "AGPL-3.0"
    }

    It "Throws meaningful error for missing config file" {
        { Get-LicenseConfig -ConfigPath "/nonexistent/config.json" } |
            Should -Throw "*not found*"
    }
}

# ============================================================
# SECTION 6: Workflow structure tests
# ============================================================

Describe "GitHub Actions Workflow Structure" {
    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/dependency-license-checker.yml"
        $script:WorkflowContent = Get-Content $script:WorkflowPath -Raw -ErrorAction Stop
        # Parse YAML using PowerShell's ConvertFrom-Yaml (requires powershell-yaml module)
        # Fallback: use string matching for basic structure validation
    }

    It "Workflow file exists" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "Workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "Workflow has pull_request trigger" {
        $script:WorkflowContent | Should -Match "pull_request:"
    }

    It "Workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "Workflow references the main script" {
        $script:WorkflowContent | Should -Match "DependencyLicenseChecker\.ps1"
    }

    It "Workflow uses actions/checkout@v4" {
        $script:WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "Workflow uses shell: pwsh for run steps" {
        $script:WorkflowContent | Should -Match "shell: pwsh"
    }

    It "Workflow has a license-check job" {
        $script:WorkflowContent | Should -Match "license-check:"
    }

    It "Main script file exists" {
        Test-Path "$PSScriptRoot/DependencyLicenseChecker.ps1" | Should -BeTrue
    }

    It "Fixtures directory exists" {
        Test-Path "$PSScriptRoot/fixtures" | Should -BeTrue
    }

    It "License config fixture exists" {
        Test-Path "$PSScriptRoot/fixtures/license-config.json" | Should -BeTrue
    }

    It "package-mixed.json fixture exists" {
        Test-Path "$PSScriptRoot/fixtures/package-mixed.json" | Should -BeTrue
    }

    It "actionlint passes on the workflow file" {
        # Skip gracefully when actionlint is not in PATH (e.g. inside act container)
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not found in PATH"
            return
        }
        $result = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $result"
    }
}
