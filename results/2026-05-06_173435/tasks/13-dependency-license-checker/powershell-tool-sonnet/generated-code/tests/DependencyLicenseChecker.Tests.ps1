# Dependency License Checker - Pester Tests
# Red/Green TDD: tests written first, then minimum code to pass

BeforeAll {
    . "$PSScriptRoot/../src/Invoke-LicenseCheck.ps1"
}

# ─── Test: Parse package.json ───────────────────────────────────────────────
Describe "Get-ManifestDependencies (package.json)" {
    BeforeAll {
        $pkgJsonPath = "$PSScriptRoot/../fixtures/package.json"
    }

    It "extracts dependencies from package.json" {
        $deps = Get-ManifestDependencies -Path $pkgJsonPath
        $deps | Should -Not -BeNullOrEmpty
    }

    It "returns objects with Name and Version properties" {
        $deps = Get-ManifestDependencies -Path $pkgJsonPath
        $deps[0].Name    | Should -Not -BeNullOrEmpty
        $deps[0].Version | Should -Not -BeNullOrEmpty
    }

    It "includes known dependency 'express'" {
        $deps = Get-ManifestDependencies -Path $pkgJsonPath
        $deps.Name | Should -Contain "express"
    }

    It "includes devDependencies when -IncludeDev is given" {
        $deps = Get-ManifestDependencies -Path $pkgJsonPath -IncludeDev
        $deps.Name | Should -Contain "jest"
    }

    It "excludes devDependencies by default" {
        $deps = Get-ManifestDependencies -Path $pkgJsonPath
        $deps.Name | Should -Not -Contain "jest"
    }
}

# ─── Test: Parse requirements.txt ───────────────────────────────────────────
Describe "Get-ManifestDependencies (requirements.txt)" {
    BeforeAll {
        $reqPath = "$PSScriptRoot/../fixtures/requirements.txt"
    }

    It "extracts packages from requirements.txt" {
        $deps = Get-ManifestDependencies -Path $reqPath
        $deps | Should -Not -BeNullOrEmpty
    }

    It "parses package name and version" {
        $deps = Get-ManifestDependencies -Path $reqPath
        $deps[0].Name    | Should -Not -BeNullOrEmpty
        $deps[0].Version | Should -Not -BeNullOrEmpty
    }

    It "includes known package 'requests'" {
        $deps = Get-ManifestDependencies -Path $reqPath
        $deps.Name | Should -Contain "requests"
    }

    It "handles packages without version specifier" {
        $deps = Get-ManifestDependencies -Path $reqPath
        $unversioned = $deps | Where-Object { $_.Name -eq "unversioned-pkg" }
        $unversioned | Should -Not -BeNullOrEmpty
        $unversioned.Version | Should -Be "any"
    }
}

# ─── Test: License lookup (mocked) ──────────────────────────────────────────
Describe "Get-DependencyLicense (mock)" {
    It "returns a license string for a known package" {
        $license = Get-DependencyLicense -Name "express" -Version "4.18.2" -MockData $true
        $license | Should -Not -BeNullOrEmpty
    }

    It "returns 'MIT' for express in mock data" {
        $license = Get-DependencyLicense -Name "express" -Version "4.18.2" -MockData $true
        $license | Should -Be "MIT"
    }

    It "returns 'UNKNOWN' for packages not in mock data" {
        $license = Get-DependencyLicense -Name "some-obscure-pkg" -Version "1.0.0" -MockData $true
        $license | Should -Be "UNKNOWN"
    }
}

# ─── Test: License compliance check ─────────────────────────────────────────
Describe "Test-LicenseCompliance" {
    BeforeAll {
        $config = @{
            AllowList = @("MIT", "Apache-2.0", "BSD-3-Clause", "ISC")
            DenyList  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1")
        }
    }

    It "returns 'approved' for an allowed license" {
        $result = Test-LicenseCompliance -License "MIT" -Config $config
        $result | Should -Be "approved"
    }

    It "returns 'denied' for a denied license" {
        $result = Test-LicenseCompliance -License "GPL-3.0" -Config $config
        $result | Should -Be "denied"
    }

    It "returns 'unknown' when license is not on either list" {
        $result = Test-LicenseCompliance -License "UNKNOWN" -Config $config
        $result | Should -Be "unknown"
    }

    It "returns 'unknown' when license is a non-standard string" {
        $result = Test-LicenseCompliance -License "Proprietary" -Config $config
        $result | Should -Be "unknown"
    }

    It "deny-list takes precedence over allow-list if both match" {
        $mixedConfig = @{
            AllowList = @("MIT", "GPL-3.0")
            DenyList  = @("GPL-3.0")
        }
        $result = Test-LicenseCompliance -License "GPL-3.0" -Config $mixedConfig
        $result | Should -Be "denied"
    }
}

# ─── Test: Full compliance report generation ────────────────────────────────
Describe "Invoke-LicenseCheck (end-to-end)" {
    BeforeAll {
        $pkgJsonPath = "$PSScriptRoot/../fixtures/package.json"
        $configPath  = "$PSScriptRoot/../fixtures/license-config.json"

        $report = Invoke-LicenseCheck -ManifestPath $pkgJsonPath `
                                      -ConfigPath $configPath `
                                      -MockData $true
    }

    It "returns a non-empty report" {
        $report | Should -Not -BeNullOrEmpty
    }

    It "report entries have Name, Version, License, Status" {
        $report[0].Name    | Should -Not -BeNullOrEmpty
        $report[0].Version | Should -Not -BeNullOrEmpty
        $report[0].License | Should -Not -BeNullOrEmpty
        $report[0].Status  | Should -BeIn @("approved", "denied", "unknown")
    }

    It "express is approved (MIT)" {
        $entry = $report | Where-Object { $_.Name -eq "express" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.License | Should -Be "MIT"
        $entry.Status  | Should -Be "approved"
    }

    It "gpl-package is denied" {
        $entry = $report | Where-Object { $_.Name -eq "gpl-package" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.Status | Should -Be "denied"
    }

    It "mystery-package has unknown status" {
        $entry = $report | Where-Object { $_.Name -eq "mystery-package" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.Status | Should -Be "unknown"
    }
}

# ─── Test: Error handling ────────────────────────────────────────────────────
Describe "Error handling" {
    It "throws a meaningful error for a missing manifest" {
        { Get-ManifestDependencies -Path "/nonexistent/file.json" } |
            Should -Throw "*not found*"
    }

    It "throws a meaningful error for an unsupported manifest type" {
        $tmp = [System.IO.Path]::GetTempFileName() + ".lock"
        New-Item -Path $tmp -ItemType File -Force | Out-Null
        try {
            { Get-ManifestDependencies -Path $tmp } | Should -Throw "*Unsupported*"
        } finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
}

# ─── Test: Workflow structure ────────────────────────────────────────────────
Describe "GitHub Actions workflow structure" {
    BeforeAll {
        $workflowPath = "$PSScriptRoot/../.github/workflows/dependency-license-checker.yml"
        $yaml = Get-Content $workflowPath -Raw
    }

    It "workflow file exists" {
        Test-Path "$PSScriptRoot/../.github/workflows/dependency-license-checker.yml" |
            Should -BeTrue
    }

    It "workflow has push trigger" {
        $yaml | Should -Match "push:"
    }

    It "workflow has pull_request trigger" {
        $yaml | Should -Match "pull_request:"
    }

    It "workflow has workflow_dispatch trigger" {
        $yaml | Should -Match "workflow_dispatch:"
    }

    It "workflow references the checker script" {
        $yaml | Should -Match "Invoke-LicenseCheck\.ps1"
    }

    It "workflow uses pwsh shell" {
        $yaml | Should -Match "shell:\s*pwsh"
    }

    It "workflow uses actions/checkout" {
        $yaml | Should -Match "actions/checkout"
    }

    It "checker script file exists" {
        Test-Path "$PSScriptRoot/../src/Invoke-LicenseCheck.ps1" | Should -BeTrue
    }

    It "actionlint passes" {
        $result = & actionlint "$PSScriptRoot/../.github/workflows/dependency-license-checker.yml" 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
