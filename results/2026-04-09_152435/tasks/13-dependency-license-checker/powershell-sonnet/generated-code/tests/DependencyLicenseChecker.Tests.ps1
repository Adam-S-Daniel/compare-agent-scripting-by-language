# DependencyLicenseChecker.Tests.ps1
# TDD tests for the dependency license checker.
# Tests are written FIRST (red), then implementation makes them pass (green).

# In Pester 5, dot-sourcing must be done inside BeforeAll so functions are
# available during test execution (not just discovery).
BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot ".." "dependency-license-checker.ps1"
    . $ScriptPath
}

Describe "Parse-PackageJson" {
    # Test 1 (RED): Parse dependencies from package.json content
    It "extracts production dependency names and versions" {
        $json = @'
{
  "dependencies": {
    "express": "^4.18.0",
    "lodash": "~4.17.21"
  }
}
'@
        $deps = Parse-PackageJson -JsonContent $json
        $deps.Count | Should -Be 2
        $deps[0].Name | Should -Be "express"
        $deps[0].Version | Should -Be "4.18.0"
        $deps[1].Name | Should -Be "lodash"
        $deps[1].Version | Should -Be "4.17.21"
    }

    # Test 2: Parse both dependencies and devDependencies
    It "includes devDependencies when requested" {
        $json = @'
{
  "dependencies": {
    "express": "4.18.0"
  },
  "devDependencies": {
    "jest": "29.0.0"
  }
}
'@
        $deps = Parse-PackageJson -JsonContent $json -IncludeDev
        $deps.Count | Should -Be 2
        ($deps | Where-Object { $_.Name -eq "jest" }).Name | Should -Be "jest"
    }

    # Test 3: Handle empty/missing dependencies gracefully
    It "returns empty list for manifest with no dependencies" {
        $json = '{"name": "my-app", "version": "1.0.0"}'
        $deps = Parse-PackageJson -JsonContent $json
        $deps.Count | Should -Be 0
    }

    # Test 4: Strip version prefixes (^, ~, >=, etc.)
    It "strips semver range operators from version strings" {
        $json = @'
{
  "dependencies": {
    "pkg-a": ">=1.2.3",
    "pkg-b": "<=2.0.0",
    "pkg-c": ">3.0.0",
    "pkg-d": "*"
  }
}
'@
        $deps = Parse-PackageJson -JsonContent $json
        ($deps | Where-Object { $_.Name -eq "pkg-a" }).Version | Should -Be "1.2.3"
        ($deps | Where-Object { $_.Name -eq "pkg-b" }).Version | Should -Be "2.0.0"
        ($deps | Where-Object { $_.Name -eq "pkg-c" }).Version | Should -Be "3.0.0"
        ($deps | Where-Object { $_.Name -eq "pkg-d" }).Version | Should -Be "*"
    }
}

Describe "Parse-RequirementsTxt" {
    # Test 5: Parse pip requirements.txt
    It "extracts package names and versions from requirements.txt" {
        $content = @"
requests==2.31.0
flask==2.3.3
"@
        $deps = Parse-RequirementsTxt -Content $content
        $deps.Count | Should -Be 2
        $deps[0].Name | Should -Be "requests"
        $deps[0].Version | Should -Be "2.31.0"
        $deps[1].Name | Should -Be "flask"
        $deps[1].Version | Should -Be "2.3.3"
    }

    # Test 6: Skip blank lines and comments
    It "skips comments and blank lines in requirements.txt" {
        $content = @"
# This is a comment
requests==2.31.0

# Another comment
flask==2.3.3
"@
        $deps = Parse-RequirementsTxt -Content $content
        $deps.Count | Should -Be 2
    }

    # Test 7: Handle various version operators
    It "handles version range operators in requirements.txt" {
        $content = @"
requests>=2.0.0
numpy~=1.24.0
pandas
"@
        $deps = Parse-RequirementsTxt -Content $content
        $deps.Count | Should -Be 3
        ($deps | Where-Object { $_.Name -eq "requests" }).Version | Should -Be "2.0.0"
        ($deps | Where-Object { $_.Name -eq "numpy" }).Version | Should -Be "1.24.0"
        ($deps | Where-Object { $_.Name -eq "pandas" }).Version | Should -Be "*"
    }
}

Describe "Get-LicenseStatus" {
    # Test 8: Approved license
    It "returns APPROVED for license in allow-list" {
        $config = @{ Allow = @("MIT", "Apache-2.0"); Deny = @("GPL-3.0") }
        $status = Get-LicenseStatus -License "MIT" -Config $config
        $status | Should -Be "APPROVED"
    }

    # Test 9: Denied license
    It "returns DENIED for license in deny-list" {
        $config = @{ Allow = @("MIT", "Apache-2.0"); Deny = @("GPL-3.0") }
        $status = Get-LicenseStatus -License "GPL-3.0" -Config $config
        $status | Should -Be "DENIED"
    }

    # Test 10: Unknown license (not in either list)
    It "returns UNKNOWN for license not in any list" {
        $config = @{ Allow = @("MIT"); Deny = @("GPL-3.0") }
        $status = Get-LicenseStatus -License "CUSTOM-1.0" -Config $config
        $status | Should -Be "UNKNOWN"
    }

    # Test 11: Null/empty license is UNKNOWN
    It "returns UNKNOWN for null or empty license" {
        $config = @{ Allow = @("MIT"); Deny = @("GPL-3.0") }
        $status = Get-LicenseStatus -License $null -Config $config
        $status | Should -Be "UNKNOWN"
    }
}

Describe "Invoke-LicenseLookup" {
    # Test 12: Mock license lookup returns correct license
    It "looks up license from mock database" {
        $mockDb = @{ "express" = "MIT"; "lodash" = "MIT"; "gpl-lib" = "GPL-3.0" }
        $license = Invoke-LicenseLookup -PackageName "express" -MockDatabase $mockDb
        $license | Should -Be "MIT"
    }

    # Test 13: Returns null for unknown package
    It "returns null for package not in mock database" {
        $mockDb = @{ "express" = "MIT" }
        $license = Invoke-LicenseLookup -PackageName "unknown-pkg" -MockDatabase $mockDb
        $license | Should -BeNullOrEmpty
    }
}

Describe "Invoke-ComplianceCheck" {
    # Test 14: Full compliance check with all approved
    It "generates correct report for all-approved manifest" {
        $deps = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.0" }
            [PSCustomObject]@{ Name = "lodash"; Version = "4.17.21" }
        )
        $mockDb = @{ "express" = "MIT"; "lodash" = "MIT" }
        $config = @{ Allow = @("MIT", "Apache-2.0"); Deny = @("GPL-3.0") }

        $results = Invoke-ComplianceCheck -Dependencies $deps -MockDatabase $mockDb -Config $config
        $results.Count | Should -Be 2
        $results[0].Name | Should -Be "express"
        $results[0].License | Should -Be "MIT"
        $results[0].Status | Should -Be "APPROVED"
        $results[1].Status | Should -Be "APPROVED"
    }

    # Test 15: Compliance check flags denied license
    It "flags denied license correctly" {
        $deps = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.0" }
            [PSCustomObject]@{ Name = "gpl-package"; Version = "1.0.0" }
        )
        $mockDb = @{ "express" = "MIT"; "gpl-package" = "GPL-3.0" }
        $config = @{ Allow = @("MIT"); Deny = @("GPL-3.0") }

        $results = Invoke-ComplianceCheck -Dependencies $deps -MockDatabase $mockDb -Config $config
        ($results | Where-Object { $_.Name -eq "gpl-package" }).Status | Should -Be "DENIED"
        ($results | Where-Object { $_.Name -eq "express" }).Status | Should -Be "APPROVED"
    }

    # Test 16: Compliance check marks unknown packages
    It "marks packages with no license info as UNKNOWN" {
        $deps = @(
            [PSCustomObject]@{ Name = "mystery-lib"; Version = "2.0.0" }
        )
        $mockDb = @{}
        $config = @{ Allow = @("MIT"); Deny = @("GPL-3.0") }

        $results = Invoke-ComplianceCheck -Dependencies $deps -MockDatabase $mockDb -Config $config
        $results[0].License | Should -Be "UNKNOWN"
        $results[0].Status | Should -Be "UNKNOWN"
    }
}

Describe "Format-ComplianceReport" {
    # Test 17: Report contains header
    It "report contains header section" {
        $results = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.0"; License = "MIT"; Status = "APPROVED" }
        )
        $report = Format-ComplianceReport -Results $results
        $report | Should -Match "DEPENDENCY LICENSE COMPLIANCE REPORT"
    }

    # Test 18: Report contains dependency entries
    It "report lists each dependency with status" {
        $results = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.0"; License = "MIT"; Status = "APPROVED" }
            [PSCustomObject]@{ Name = "gpl-package"; Version = "1.0.0"; License = "GPL-3.0"; Status = "DENIED" }
        )
        $report = Format-ComplianceReport -Results $results
        $report | Should -Match "express.*MIT.*APPROVED"
        $report | Should -Match "gpl-package.*GPL-3\.0.*DENIED"
    }

    # Test 19: Report shows summary statistics
    It "report includes summary with totals" {
        $results = @(
            [PSCustomObject]@{ Name = "pkg1"; Version = "1.0"; License = "MIT"; Status = "APPROVED" }
            [PSCustomObject]@{ Name = "pkg2"; Version = "1.0"; License = "GPL-3.0"; Status = "DENIED" }
            [PSCustomObject]@{ Name = "pkg3"; Version = "1.0"; License = "UNKNOWN"; Status = "UNKNOWN" }
        )
        $report = Format-ComplianceReport -Results $results
        $report | Should -Match "TOTAL: 3"
        $report | Should -Match "APPROVED: 1"
        $report | Should -Match "DENIED: 1"
        $report | Should -Match "UNKNOWN: 1"
    }

    # Test 20: Report shows PASSED status when all approved
    It "shows COMPLIANCE STATUS: PASSED when all approved" {
        $results = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.0"; License = "MIT"; Status = "APPROVED" }
        )
        $report = Format-ComplianceReport -Results $results
        $report | Should -Match "COMPLIANCE STATUS: PASSED"
    }

    # Test 21: Report shows FAILED status when any denied or unknown
    It "shows COMPLIANCE STATUS: FAILED when any denied" {
        $results = @(
            [PSCustomObject]@{ Name = "express"; Version = "4.18.0"; License = "MIT"; Status = "APPROVED" }
            [PSCustomObject]@{ Name = "gpl-pkg"; Version = "1.0.0"; License = "GPL-3.0"; Status = "DENIED" }
        )
        $report = Format-ComplianceReport -Results $results
        $report | Should -Match "COMPLIANCE STATUS: FAILED"
    }
}

Describe "Workflow Structure" {
    # Test 22: Workflow file exists
    It "GitHub Actions workflow file exists" {
        $workflowPath = Join-Path $PSScriptRoot ".." ".github" "workflows" "dependency-license-checker.yml"
        $workflowPath | Should -Exist
    }

    # Test 23: Workflow has correct triggers
    It "workflow has push and pull_request triggers" {
        $workflowPath = Join-Path $PSScriptRoot ".." ".github" "workflows" "dependency-license-checker.yml"
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "push:"
        $content | Should -Match "pull_request:"
    }

    # Test 24: Workflow references existing script file
    It "workflow references the main script which exists" {
        $scriptPath = Join-Path $PSScriptRoot ".." "dependency-license-checker.ps1"
        $scriptPath | Should -Exist
    }

    # Test 25: Workflow uses shell: pwsh for PowerShell steps
    It "workflow uses shell: pwsh for PowerShell steps" {
        $workflowPath = Join-Path $PSScriptRoot ".." ".github" "workflows" "dependency-license-checker.yml"
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    # Test 26: Actionlint passes on the workflow file
    # Skips gracefully when actionlint is not installed (e.g., inside a Docker container)
    It "workflow passes actionlint validation" {
        $actionlintCmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $workflowPath = Join-Path $PSScriptRoot ".." ".github" "workflows" "dependency-license-checker.yml"
        $result = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
