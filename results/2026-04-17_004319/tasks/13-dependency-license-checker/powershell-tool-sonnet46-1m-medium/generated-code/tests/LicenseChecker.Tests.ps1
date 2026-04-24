# LicenseChecker.Tests.ps1
# Unit tests and workflow structure tests for the Dependency License Checker.
# Run with: Invoke-Pester -Path ./tests/LicenseChecker.Tests.ps1

BeforeAll {
    # Dot-source the function library so all functions are available in test scope
    . "$PSScriptRoot/../LicenseChecker-Functions.ps1"

    $ProjectRoot = Resolve-Path "$PSScriptRoot/.."
    $FixturesDir = Join-Path $ProjectRoot "fixtures"
    $ConfigDir   = Join-Path $ProjectRoot "config"
}

# ─── TDD Phase 1: Parse-Manifest ──────────────────────────────────────────────

Describe "Parse-Manifest" {
    Context "package.json" {
        It "extracts dependencies from package.json" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "package.json")
            $deps | Should -Not -BeNullOrEmpty
            $deps.ContainsKey("lodash") | Should -Be $true
        }

        It "records the correct version for each dependency" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "package.json")
            $deps["lodash"] | Should -Be "4.17.21"
        }

        It "includes devDependencies" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "package.json")
            $deps.ContainsKey("jest") | Should -Be $true
        }

        It "returns all expected packages" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "package.json")
            $deps.Count | Should -BeGreaterOrEqual 4
        }
    }

    Context "requirements.txt" {
        It "extracts packages from requirements.txt" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "requirements.txt")
            $deps | Should -Not -BeNullOrEmpty
            $deps.ContainsKey("requests") | Should -Be $true
        }

        It "skips comment lines" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "requirements.txt")
            $deps.Keys | Should -Not -Contain "#comment"
        }

        It "handles == version pins" {
            $deps = Parse-Manifest -Path (Join-Path $FixturesDir "requirements.txt")
            $deps["requests"] | Should -Match "2\.31\."
        }
    }

    Context "error handling" {
        It "throws when manifest file does not exist" {
            { Parse-Manifest -Path "/nonexistent/path/package.json" } | Should -Throw
        }

        It "throws for unsupported file format" {
            $tmpFile = New-TemporaryFile
            Rename-Item $tmpFile "$($tmpFile.FullName).gemfile"
            { Parse-Manifest -Path "$($tmpFile.FullName).gemfile" } | Should -Throw
            Remove-Item "$($tmpFile.FullName).gemfile" -ErrorAction SilentlyContinue
        }
    }
}

# ─── TDD Phase 2: Get-LicenseStatus ───────────────────────────────────────────

Describe "Get-LicenseStatus" {
    BeforeAll {
        $AllowList = @("MIT", "Apache-2.0", "BSD-3-Clause", "ISC", "BSD-2-Clause")
        $DenyList  = @("GPL-3.0", "GPL-2.0", "LGPL-3.0", "AGPL-3.0", "SSPL-1.0")
    }

    It "returns 'approved' for a license in the allow list" {
        Get-LicenseStatus -License "MIT" -AllowList $AllowList -DenyList $DenyList |
            Should -Be "approved"
    }

    It "returns 'approved' for Apache-2.0" {
        Get-LicenseStatus -License "Apache-2.0" -AllowList $AllowList -DenyList $DenyList |
            Should -Be "approved"
    }

    It "returns 'denied' for GPL-3.0 in the deny list" {
        Get-LicenseStatus -License "GPL-3.0" -AllowList $AllowList -DenyList $DenyList |
            Should -Be "denied"
    }

    It "returns 'denied' for AGPL-3.0 in the deny list" {
        Get-LicenseStatus -License "AGPL-3.0" -AllowList $AllowList -DenyList $DenyList |
            Should -Be "denied"
    }

    It "returns 'unknown' for a license not in either list" {
        Get-LicenseStatus -License "CUSTOM-1.0" -AllowList $AllowList -DenyList $DenyList |
            Should -Be "unknown"
    }

    It "returns 'unknown' when license is null" {
        Get-LicenseStatus -License $null -AllowList $AllowList -DenyList $DenyList |
            Should -Be "unknown"
    }

    It "deny list takes precedence over allow list" {
        # A license in both lists should be denied
        Get-LicenseStatus -License "GPL-3.0" -AllowList @("GPL-3.0") -DenyList @("GPL-3.0") |
            Should -Be "denied"
    }
}

# ─── TDD Phase 3: Get-LicenseForPackage (mock lookup) ─────────────────────────

Describe "Get-LicenseForPackage" {
    BeforeAll {
        $MockLicenses = @{
            "lodash"  = "MIT"
            "express" = "MIT"
            "gpl-lib" = "GPL-3.0"
        }
    }

    It "returns the mocked license for a known package" {
        Get-LicenseForPackage -PackageName "lodash" -MockLicenses $MockLicenses |
            Should -Be "MIT"
    }

    It "returns null for a package not in the mock data" {
        Get-LicenseForPackage -PackageName "mystery-pkg" -MockLicenses $MockLicenses |
            Should -BeNullOrEmpty
    }

    It "returns GPL-3.0 for gpl-lib" {
        Get-LicenseForPackage -PackageName "gpl-lib" -MockLicenses $MockLicenses |
            Should -Be "GPL-3.0"
    }
}

# ─── TDD Phase 4: Invoke-LicenseCheck (full orchestration) ───────────────────

Describe "Invoke-LicenseCheck" {
    BeforeAll {
        $Config = [PSCustomObject]@{
            allowList = @("MIT", "Apache-2.0", "BSD-3-Clause", "ISC")
            denyList  = @("GPL-3.0", "GPL-2.0", "LGPL-3.0", "AGPL-3.0")
        }

        # Mock data includes approved, denied, and unknown
        $MockLicenses = @{
            "lodash"     = "MIT"
            "express"    = "MIT"
            "apache-sdk" = "Apache-2.0"
            "gpl-lib"    = "GPL-3.0"
            # "mystery-pkg" intentionally absent → unknown
        }

        $ManifestPath = Join-Path $FixturesDir "package-mixed.json"
    }

    It "generates a report with one entry per dependency" {
        $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -Config $Config -MockLicenses $MockLicenses
        $report | Should -Not -BeNullOrEmpty
        $report.Count | Should -BeGreaterOrEqual 3
    }

    It "marks MIT-licensed lodash as approved" {
        $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -Config $Config -MockLicenses $MockLicenses
        $entry = $report | Where-Object { $_.Name -eq "lodash" }
        $entry.Status  | Should -Be "approved"
        $entry.License | Should -Be "MIT"
    }

    It "marks GPL-3.0 gpl-lib as denied" {
        $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -Config $Config -MockLicenses $MockLicenses
        $entry = $report | Where-Object { $_.Name -eq "gpl-lib" }
        $entry.Status  | Should -Be "denied"
        $entry.License | Should -Be "GPL-3.0"
    }

    It "marks unlisted mystery-pkg as unknown" {
        $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -Config $Config -MockLicenses $MockLicenses
        $entry = $report | Where-Object { $_.Name -eq "mystery-pkg" }
        $entry.Status  | Should -Be "unknown"
        $entry.License | Should -Be "unknown"
    }

    It "report objects have Name, Version, License, Status properties" {
        $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -Config $Config -MockLicenses $MockLicenses
        $entry = $report | Select-Object -First 1
        $entry.PSObject.Properties.Name | Should -Contain "Name"
        $entry.PSObject.Properties.Name | Should -Contain "Version"
        $entry.PSObject.Properties.Name | Should -Contain "License"
        $entry.PSObject.Properties.Name | Should -Contain "Status"
    }
}

# ─── TDD Phase 5: Workflow structure tests ────────────────────────────────────

Describe "Workflow structure" {
    BeforeAll {
        $WorkflowPath = Join-Path $ProjectRoot ".github/workflows/dependency-license-checker.yml"
    }

    It "workflow file exists" {
        Test-Path $WorkflowPath | Should -Be $true
    }

    It "workflow file references Invoke-LicenseChecker.ps1" {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match "Invoke-LicenseChecker\.ps1"
    }

    It "workflow file references LicenseChecker.Tests.ps1" {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match "LicenseChecker\.Tests\.ps1"
    }

    It "workflow has a push trigger" {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match "push"
    }

    It "workflow uses actions/checkout@v4" {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match "actions/checkout@v4"
    }

    It "workflow uses shell: pwsh" {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match "shell:\s*pwsh"
    }

    It "all referenced script files exist" {
        Test-Path (Join-Path $ProjectRoot "Invoke-LicenseChecker.ps1")    | Should -Be $true
        Test-Path (Join-Path $ProjectRoot "LicenseChecker-Functions.ps1") | Should -Be $true
        Test-Path (Join-Path $ProjectRoot "fixtures/package.json")        | Should -Be $true
        Test-Path (Join-Path $ProjectRoot "config/license-config.json")   | Should -Be $true
        Test-Path (Join-Path $ProjectRoot "fixtures/mock-licenses.json")  | Should -Be $true
    }

    It "actionlint passes with exit code 0" -Skip:(-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
        $output = actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
