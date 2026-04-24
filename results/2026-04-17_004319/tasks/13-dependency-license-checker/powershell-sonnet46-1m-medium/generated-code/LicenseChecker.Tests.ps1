# TDD: Dependency License Checker Tests
# Approach: Red-Green-Refactor cycle
# 1. Write failing tests for each function
# 2. Implement minimum code to pass
# 3. Refactor and repeat

#Requires -Modules Pester

BeforeAll {
    # Load the main script (dot-source to get all functions in scope)
    . "$PSScriptRoot/Invoke-LicenseChecker.ps1"
}

# ============================================================
# CYCLE 1: Read-DependencyManifest
# RED: These tests fail before implementation
# ============================================================
Describe "Read-DependencyManifest" {
    Context "package.json (npm)" {
        It "parses dependencies and returns name+version pairs" {
            $manifest = "$PSScriptRoot/fixtures/package.json"
            $deps = Read-DependencyManifest -Path $manifest
            $deps | Should -Not -BeNullOrEmpty
            $deps.Count | Should -Be 4
        }

        It "extracts correct package names" {
            $manifest = "$PSScriptRoot/fixtures/package.json"
            $deps = Read-DependencyManifest -Path $manifest
            $names = $deps | ForEach-Object { $_.Name }
            $names | Should -Contain "express"
            $names | Should -Contain "lodash"
            $names | Should -Contain "gpl-package"
            $names | Should -Contain "unknown-lib"
        }

        It "strips version range specifiers" {
            $manifest = "$PSScriptRoot/fixtures/package.json"
            $deps = Read-DependencyManifest -Path $manifest
            $express = $deps | Where-Object { $_.Name -eq "express" }
            $express.Version | Should -Be "4.18.2"
        }

        It "includes devDependencies when present" {
            $manifest = "$PSScriptRoot/fixtures/package-with-dev.json"
            $deps = Read-DependencyManifest -Path $manifest
            $names = $deps | ForEach-Object { $_.Name }
            $names | Should -Contain "jest"
        }
    }

    Context "requirements.txt (Python)" {
        It "parses Python requirements and returns name+version pairs" {
            $manifest = "$PSScriptRoot/fixtures/requirements.txt"
            $deps = Read-DependencyManifest -Path $manifest
            $deps | Should -Not -BeNullOrEmpty
            $deps.Count | Should -Be 4
        }

        It "extracts correct package names from requirements.txt" {
            $manifest = "$PSScriptRoot/fixtures/requirements.txt"
            $deps = Read-DependencyManifest -Path $manifest
            $names = $deps | ForEach-Object { $_.Name }
            $names | Should -Contain "requests"
            $names | Should -Contain "flask"
        }

        It "handles packages without pinned versions" {
            $manifest = "$PSScriptRoot/fixtures/requirements.txt"
            $deps = Read-DependencyManifest -Path $manifest
            $unpinned = $deps | Where-Object { $_.Name -eq "unpinned-lib" }
            $unpinned.Version | Should -Be "unpinned"
        }
    }

    Context "Error handling" {
        It "throws a meaningful error for missing files" {
            { Read-DependencyManifest -Path "nonexistent.json" } | Should -Throw "*not found*"
        }

        It "throws a meaningful error for unsupported file types" {
            { Read-DependencyManifest -Path "$PSScriptRoot/fixtures/unsupported.toml" } | Should -Throw "*not supported*"
        }
    }
}

# ============================================================
# CYCLE 2: Get-LicenseInfo (mocked lookup)
# RED: These tests fail before implementation
# ============================================================
Describe "Get-LicenseInfo" {
    It "returns license for a known package from mock database" {
        $mockDb = "$PSScriptRoot/fixtures/mock-licenses.json"
        $license = Get-LicenseInfo -PackageName "express" -MockLicensesPath $mockDb
        $license | Should -Be "MIT"
    }

    It "returns UNKNOWN for a package not in the mock database" {
        $mockDb = "$PSScriptRoot/fixtures/mock-licenses.json"
        $license = Get-LicenseInfo -PackageName "unknown-lib" -MockLicensesPath $mockDb
        $license | Should -Be "UNKNOWN"
    }

    It "returns correct license for a denied package" {
        $mockDb = "$PSScriptRoot/fixtures/mock-licenses.json"
        $license = Get-LicenseInfo -PackageName "gpl-package" -MockLicensesPath $mockDb
        $license | Should -Be "GPL-3.0"
    }
}

# ============================================================
# CYCLE 3: Test-LicenseCompliance
# RED: These tests fail before implementation
# ============================================================
Describe "Test-LicenseCompliance" {
    BeforeAll {
        $config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1")
        }
    }

    It "returns APPROVED for an allowed license" {
        $result = Test-LicenseCompliance -License "MIT" -Config $config
        $result | Should -Be "APPROVED"
    }

    It "returns DENIED for a denied license" {
        $result = Test-LicenseCompliance -License "GPL-3.0" -Config $config
        $result | Should -Be "DENIED"
    }

    It "returns UNKNOWN for a license not in either list" {
        $result = Test-LicenseCompliance -License "UNKNOWN" -Config $config
        $result | Should -Be "UNKNOWN"
    }

    It "returns UNKNOWN for a license that is unlisted but not denied" {
        $result = Test-LicenseCompliance -License "WTFPL" -Config $config
        $result | Should -Be "UNKNOWN"
    }

    It "is case-insensitive for license matching" {
        $result = Test-LicenseCompliance -License "mit" -Config $config
        $result | Should -Be "APPROVED"
    }
}

# ============================================================
# CYCLE 4: New-ComplianceReport
# RED: These tests fail before implementation
# ============================================================
Describe "New-ComplianceReport" {
    BeforeAll {
        $entries = @(
            [PSCustomObject]@{ Name = "express";     Version = "4.18.2"; License = "MIT";     Status = "APPROVED" },
            [PSCustomObject]@{ Name = "lodash";      Version = "4.17.21"; License = "MIT";    Status = "APPROVED" },
            [PSCustomObject]@{ Name = "gpl-package"; Version = "1.0.0";  License = "GPL-3.0"; Status = "DENIED"  },
            [PSCustomObject]@{ Name = "unknown-lib"; Version = "2.0.0";  License = "UNKNOWN"; Status = "UNKNOWN" }
        )
    }

    It "returns a report object with all entries" {
        $report = New-ComplianceReport -Entries $entries
        $report.Entries.Count | Should -Be 4
    }

    It "computes correct summary counts" {
        $report = New-ComplianceReport -Entries $entries
        $report.ApprovedCount | Should -Be 2
        $report.DeniedCount   | Should -Be 1
        $report.UnknownCount  | Should -Be 1
    }

    It "formats a human-readable text report" {
        $report = New-ComplianceReport -Entries $entries
        $text = $report.ToText()
        $text | Should -Match "express \(4\.18\.2\): MIT -> APPROVED"
        $text | Should -Match "gpl-package \(1\.0\.0\): GPL-3\.0 -> DENIED"
        $text | Should -Match "unknown-lib \(2\.0\.0\): UNKNOWN -> UNKNOWN"
        $text | Should -Match "Summary: 2 approved, 1 denied, 1 unknown"
    }
}

# ============================================================
# CYCLE 5: Invoke-LicenseChecker (end-to-end integration)
# RED: These tests fail before implementation
# ============================================================
Describe "Invoke-LicenseChecker (integration)" {
    It "produces APPROVED for MIT packages in package.json" {
        $result = Invoke-LicenseChecker `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -LicenseConfigPath "$PSScriptRoot/fixtures/license-config.json" `
            -MockLicensesPath "$PSScriptRoot/fixtures/mock-licenses.json"
        $approved = $result.Entries | Where-Object { $_.Name -eq "express" }
        $approved.Status | Should -Be "APPROVED"
    }

    It "produces DENIED for GPL packages in package.json" {
        $result = Invoke-LicenseChecker `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -LicenseConfigPath "$PSScriptRoot/fixtures/license-config.json" `
            -MockLicensesPath "$PSScriptRoot/fixtures/mock-licenses.json"
        $denied = $result.Entries | Where-Object { $_.Name -eq "gpl-package" }
        $denied.Status | Should -Be "DENIED"
    }

    It "produces UNKNOWN for packages not in mock DB" {
        $result = Invoke-LicenseChecker `
            -ManifestPath "$PSScriptRoot/fixtures/package.json" `
            -LicenseConfigPath "$PSScriptRoot/fixtures/license-config.json" `
            -MockLicensesPath "$PSScriptRoot/fixtures/mock-licenses.json"
        $unknown = $result.Entries | Where-Object { $_.Name -eq "unknown-lib" }
        $unknown.Status | Should -Be "UNKNOWN"
    }

    It "works end-to-end with requirements.txt" {
        $result = Invoke-LicenseChecker `
            -ManifestPath "$PSScriptRoot/fixtures/requirements.txt" `
            -LicenseConfigPath "$PSScriptRoot/fixtures/license-config.json" `
            -MockLicensesPath "$PSScriptRoot/fixtures/mock-licenses.json"
        $approved = $result.Entries | Where-Object { $_.Name -eq "requests" }
        $approved.Status | Should -Be "APPROVED"
    }
}

# ============================================================
# CYCLE 6: Workflow Structure Tests
# Verify the GitHub Actions workflow file is correct
# ============================================================
Describe "Workflow Structure" {
    BeforeAll {
        $workflowPath = "$PSScriptRoot/.github/workflows/dependency-license-checker.yml"
        $workflowContent = Get-Content $workflowPath -Raw
        # Parse YAML using PowerShell (simple line-by-line approach)
        $workflowLines = Get-Content $workflowPath
    }

    It "workflow file exists" {
        Test-Path "$PSScriptRoot/.github/workflows/dependency-license-checker.yml" | Should -Be $true
    }

    It "has push trigger" {
        $workflowContent | Should -Match "push:"
    }

    It "has workflow_dispatch trigger" {
        $workflowContent | Should -Match "workflow_dispatch:"
    }

    It "references the main script" {
        $workflowContent | Should -Match "Invoke-LicenseChecker\.ps1"
    }

    It "uses shell: pwsh for PowerShell steps" {
        $workflowContent | Should -Match "shell:\s*pwsh"
    }

    It "uses actions/checkout@v4" {
        $workflowContent | Should -Match "actions/checkout@v4"
    }

    It "main script file exists" {
        Test-Path "$PSScriptRoot/Invoke-LicenseChecker.ps1" | Should -Be $true
    }

    It "fixture files exist" {
        Test-Path "$PSScriptRoot/fixtures/package.json"         | Should -Be $true
        Test-Path "$PSScriptRoot/fixtures/license-config.json"  | Should -Be $true
        Test-Path "$PSScriptRoot/fixtures/mock-licenses.json"   | Should -Be $true
    }

    It "passes actionlint validation" -Tag "RequiresActionlint" {
        $actionlintCmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $output = actionlint "$PSScriptRoot/.github/workflows/dependency-license-checker.yml" 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

# ============================================================
# CYCLE 7: Act Execution Tests
# Run the workflow via act and assert on exact output
# ============================================================
Describe "Act Execution" -Tag "ActExecution" {
    BeforeAll {
        # Set up a temp git repo with all project files
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-checker-act-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null

        # Copy all project files into temp dir
        $projectRoot = $PSScriptRoot
        Copy-Item "$projectRoot/Invoke-LicenseChecker.ps1"  $script:TempDir
        Copy-Item "$projectRoot/LicenseChecker.Tests.ps1"   $script:TempDir
        Copy-Item "$projectRoot/.actrc"                      $script:TempDir -ErrorAction SilentlyContinue

        # Copy fixtures directory
        Copy-Item "$projectRoot/fixtures" $script:TempDir -Recurse

        # Copy .github directory
        Copy-Item "$projectRoot/.github" $script:TempDir -Recurse

        # Initialize git repo
        Push-Location $script:TempDir
        git init --quiet
        git config user.email "test@example.com"
        git config user.name "Test"
        git add -A
        git commit -m "test: add license checker" --quiet
        Pop-Location

        # Run act and capture output
        $actResultPath = "$projectRoot/act-result.txt"
        $delimiter = "=" * 60

        Add-Content -Path $actResultPath -Value ""
        Add-Content -Path $actResultPath -Value "$delimiter"
        Add-Content -Path $actResultPath -Value "TEST CASE: Full workflow execution via act"
        Add-Content -Path $actResultPath -Value "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Add-Content -Path $actResultPath -Value "$delimiter"

        Push-Location $script:TempDir
        $script:ActOutput = act push --rm 2>&1 | Tee-Object -Variable actLines
        $script:ActExitCode = $LASTEXITCODE
        Pop-Location

        $outputText = $script:ActOutput -join "`n"
        Add-Content -Path $actResultPath -Value $outputText
        Add-Content -Path $actResultPath -Value "$delimiter"
        Add-Content -Path $actResultPath -Value "Exit code: $($script:ActExitCode)"
        Add-Content -Path $actResultPath -Value "$delimiter"
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "act exits with code 0" {
        $script:ActExitCode | Should -Be 0
    }

    It "all jobs show success" {
        $outputText = $script:ActOutput -join "`n"
        $outputText | Should -Match "Job succeeded"
    }

    It "report shows express as APPROVED" {
        $outputText = $script:ActOutput -join "`n"
        $outputText | Should -Match "express.*APPROVED"
    }

    It "report shows lodash as APPROVED" {
        $outputText = $script:ActOutput -join "`n"
        $outputText | Should -Match "lodash.*APPROVED"
    }

    It "report shows gpl-package as DENIED" {
        $outputText = $script:ActOutput -join "`n"
        $outputText | Should -Match "gpl-package.*DENIED"
    }

    It "report shows unknown-lib as UNKNOWN" {
        $outputText = $script:ActOutput -join "`n"
        $outputText | Should -Match "unknown-lib.*UNKNOWN"
    }

    It "report shows correct summary counts" {
        $outputText = $script:ActOutput -join "`n"
        $outputText | Should -Match "Summary: 2 approved, 1 denied, 1 unknown"
    }

    It "act-result.txt artifact exists" {
        Test-Path "$PSScriptRoot/act-result.txt" | Should -Be $true
    }
}
