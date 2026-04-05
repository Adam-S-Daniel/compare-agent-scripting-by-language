# DependencyLicenseChecker.Tests.ps1
# Pester tests for the Dependency License Checker module.
# Written FIRST following red/green TDD — each Describe block represents
# a TDD cycle where tests were written before the corresponding implementation.

BeforeAll {
    . "$PSScriptRoot/DependencyLicenseChecker.ps1"

    # Shared test fixture directory
    $script:fixtureDir = Join-Path $PSScriptRoot "test-fixtures"
    if (-not (Test-Path $script:fixtureDir)) {
        New-Item -ItemType Directory -Path $script:fixtureDir -Force | Out-Null
    }
}

AfterAll {
    # Clean up test fixtures
    $fixtureDir = Join-Path $PSScriptRoot "test-fixtures"
    if (Test-Path $fixtureDir) {
        Remove-Item -Recurse -Force $fixtureDir
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 1: Parse package.json
# RED:  These tests fail because Parse-DependencyManifest doesn't exist yet.
# GREEN: Implement the function to parse package.json dependencies.
# ---------------------------------------------------------------------------
Describe "Parse-DependencyManifest - package.json" {

    BeforeAll {
        $packageJson = @{
            name            = "test-project"
            version         = "1.0.0"
            dependencies    = @{
                "express" = "^4.18.2"
                "lodash"  = "4.17.21"
            }
            devDependencies = @{
                "jest" = "~29.7.0"
            }
        } | ConvertTo-Json -Depth 5

        $script:pkgPath = Join-Path $script:fixtureDir "package.json"
        Set-Content -Path $script:pkgPath -Value $packageJson
    }

    It "Returns dependency objects with Name and Version properties" {
        $deps = Parse-DependencyManifest -Path $script:pkgPath
        $deps | Should -Not -BeNullOrEmpty
        $deps[0].PSObject.Properties.Name | Should -Contain "Name"
        $deps[0].PSObject.Properties.Name | Should -Contain "Version"
    }

    It "Parses all production dependencies" {
        $deps = Parse-DependencyManifest -Path $script:pkgPath
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain "express"
        $names | Should -Contain "lodash"
    }

    It "Includes devDependencies" {
        $deps = Parse-DependencyManifest -Path $script:pkgPath
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain "jest"
    }

    It "Strips version prefix characters (^ and ~)" {
        $deps = Parse-DependencyManifest -Path $script:pkgPath
        $express = $deps | Where-Object { $_.Name -eq "express" }
        $express.Version | Should -Be "4.18.2"

        $jest = $deps | Where-Object { $_.Name -eq "jest" }
        $jest.Version | Should -Be "29.7.0"
    }

    It "Returns 3 total dependencies" {
        $deps = Parse-DependencyManifest -Path $script:pkgPath
        $deps.Count | Should -Be 3
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 2: Parse requirements.txt
# RED:  Tests fail because requirements.txt parsing isn't implemented.
# GREEN: Extend Parse-DependencyManifest to detect and parse requirements.txt.
# ---------------------------------------------------------------------------
Describe "Parse-DependencyManifest - requirements.txt" {

    BeforeAll {
        $reqContent = @"
# Python dependencies
flask==2.3.2
requests>=2.31.0
numpy==1.24.3
# A comment line
pandas>=2.0.0

"@
        $script:reqPath = Join-Path $script:fixtureDir "requirements.txt"
        Set-Content -Path $script:reqPath -Value $reqContent
    }

    It "Parses dependencies from requirements.txt" {
        $deps = Parse-DependencyManifest -Path $script:reqPath
        $deps | Should -Not -BeNullOrEmpty
    }

    It "Extracts correct dependency names" {
        $deps = Parse-DependencyManifest -Path $script:reqPath
        $names = $deps | ForEach-Object { $_.Name }
        $names | Should -Contain "flask"
        $names | Should -Contain "requests"
        $names | Should -Contain "numpy"
        $names | Should -Contain "pandas"
    }

    It "Extracts version numbers" {
        $deps = Parse-DependencyManifest -Path $script:reqPath
        $flask = $deps | Where-Object { $_.Name -eq "flask" }
        $flask.Version | Should -Be "2.3.2"
    }

    It "Skips comment lines and blank lines" {
        $deps = Parse-DependencyManifest -Path $script:reqPath
        $deps.Count | Should -Be 4
    }

    It "Handles >= version specifiers" {
        $deps = Parse-DependencyManifest -Path $script:reqPath
        $requests = $deps | Where-Object { $_.Name -eq "requests" }
        $requests.Version | Should -Be "2.31.0"
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 3: Parse .csproj (NuGet / .NET)
# RED:  Tests fail because .csproj parsing isn't implemented.
# GREEN: Extend Parse-DependencyManifest to handle XML-based .csproj files.
# ---------------------------------------------------------------------------
Describe "Parse-DependencyManifest - .csproj" {

    BeforeAll {
        $csprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
    <PackageReference Include="Serilog" Version="3.1.1" />
  </ItemGroup>
</Project>
"@
        $script:csprojPath = Join-Path $script:fixtureDir "TestProject.csproj"
        Set-Content -Path $script:csprojPath -Value $csprojContent
    }

    It "Parses PackageReference entries from .csproj" {
        $deps = Parse-DependencyManifest -Path $script:csprojPath
        $deps | Should -Not -BeNullOrEmpty
        $deps.Count | Should -Be 2
    }

    It "Extracts correct names and versions from .csproj" {
        $deps = Parse-DependencyManifest -Path $script:csprojPath
        $nj = $deps | Where-Object { $_.Name -eq "Newtonsoft.Json" }
        $nj | Should -Not -BeNullOrEmpty
        $nj.Version | Should -Be "13.0.3"
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 4: Error handling for Parse-DependencyManifest
# RED:  Tests fail because error handling isn't in place.
# GREEN: Add validation and meaningful error messages.
# ---------------------------------------------------------------------------
Describe "Parse-DependencyManifest - error handling" {

    It "Throws an error when file does not exist" {
        { Parse-DependencyManifest -Path "/nonexistent/file.json" } |
            Should -Throw "*does not exist*"
    }

    It "Throws an error for unsupported file types" {
        $txtPath = Join-Path $script:fixtureDir "unsupported.yaml"
        Set-Content -Path $txtPath -Value "key: value"
        { Parse-DependencyManifest -Path $txtPath } |
            Should -Throw "*Unsupported*"
    }

    It "Handles a package.json with no dependencies gracefully" {
        $emptyPkg = @{ name = "empty"; version = "1.0.0" } | ConvertTo-Json
        $emptyPath = Join-Path $script:fixtureDir "empty-package.json"
        Set-Content -Path $emptyPath -Value $emptyPkg

        # Should not throw; returns an empty array
        $deps = Parse-DependencyManifest -Path $emptyPath
        @($deps).Count | Should -Be 0
    }

    It "Handles an empty requirements.txt gracefully" {
        $emptyReqPath = Join-Path $script:fixtureDir "empty-requirements.txt"
        Set-Content -Path $emptyReqPath -Value ""

        # Should not throw; returns an empty array
        $deps = Parse-DependencyManifest -Path $emptyReqPath
        @($deps).Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 5: License lookup with mock
# RED:  Tests fail because Get-DependencyLicense doesn't exist.
# GREEN: Implement the function with a -LicenseLookup scriptblock parameter
#        to allow mocking/injection of the license resolution strategy.
# ---------------------------------------------------------------------------
Describe "Get-DependencyLicense" {

    BeforeAll {
        # Mock license lookup: simulates an external license database
        $script:mockLookup = {
            param([string]$Name, [string]$Version)
            switch ($Name) {
                "express"  { "MIT" }
                "lodash"   { "MIT" }
                "flask"    { "BSD-3-Clause" }
                "requests" { "Apache-2.0" }
                "numpy"    { "BSD-3-Clause" }
                "unknown-pkg" { $null }
                default    { $null }
            }
        }
    }

    It "Returns license for a known dependency" {
        $result = Get-DependencyLicense -Name "express" -Version "4.18.2" -LicenseLookup $script:mockLookup
        $result | Should -Be "MIT"
    }

    It "Returns null for an unknown dependency" {
        $result = Get-DependencyLicense -Name "unknown-pkg" -Version "1.0.0" -LicenseLookup $script:mockLookup
        $result | Should -BeNullOrEmpty
    }

    It "Uses the built-in mock database when no lookup is provided" {
        # The built-in database has common packages mapped
        $result = Get-DependencyLicense -Name "express" -Version "4.18.2"
        $result | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 6: License compliance checking
# RED:  Tests fail because Test-LicenseCompliance doesn't exist.
# GREEN: Implement the function that checks a license against allow/deny config.
# ---------------------------------------------------------------------------
Describe "Test-LicenseCompliance" {

    BeforeAll {
        # Config with allow-list and deny-list
        $script:config = @{
            AllowedLicenses = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
            DeniedLicenses  = @("GPL-3.0", "AGPL-3.0", "SSPL-1.0")
        }
    }

    It "Returns 'approved' for an allowed license" {
        $status = Test-LicenseCompliance -License "MIT" -Config $script:config
        $status | Should -Be "approved"
    }

    It "Returns 'denied' for a denied license" {
        $status = Test-LicenseCompliance -License "GPL-3.0" -Config $script:config
        $status | Should -Be "denied"
    }

    It "Returns 'unknown' when license is null" {
        $status = Test-LicenseCompliance -License $null -Config $script:config
        $status | Should -Be "unknown"
    }

    It "Returns 'unknown' when license is not in either list" {
        $status = Test-LicenseCompliance -License "Unlicense" -Config $script:config
        $status | Should -Be "unknown"
    }

    It "Is case-insensitive" {
        $status = Test-LicenseCompliance -License "mit" -Config $script:config
        $status | Should -Be "approved"

        $status2 = Test-LicenseCompliance -License "gpl-3.0" -Config $script:config
        $status2 | Should -Be "denied"
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 7: Compliance report generation
# RED:  Tests fail because New-ComplianceReport doesn't exist.
# GREEN: Implement end-to-end report generation that ties everything together.
# ---------------------------------------------------------------------------
Describe "New-ComplianceReport" {

    BeforeAll {
        # Create a package.json fixture for the report
        $packageJson = @{
            name         = "report-test"
            version      = "1.0.0"
            dependencies = @{
                "express" = "^4.18.2"
                "lodash"  = "4.17.21"
            }
        } | ConvertTo-Json -Depth 5

        $script:reportPkgPath = Join-Path $script:fixtureDir "report-package.json"
        Set-Content -Path $script:reportPkgPath -Value $packageJson

        # Config file
        $script:reportConfig = @{
            AllowedLicenses = @("MIT", "Apache-2.0", "BSD-3-Clause")
            DeniedLicenses  = @("GPL-3.0", "AGPL-3.0")
        }

        # Mock that returns MIT for express, GPL-3.0 for lodash
        $script:reportMockLookup = {
            param([string]$Name, [string]$Version)
            switch ($Name) {
                "express" { "MIT" }
                "lodash"  { "GPL-3.0" }
                default   { $null }
            }
        }
    }

    It "Returns a report object with expected properties" {
        $report = New-ComplianceReport -ManifestPath $script:reportPkgPath `
            -Config $script:reportConfig -LicenseLookup $script:reportMockLookup

        $report.PSObject.Properties.Name | Should -Contain "GeneratedAt"
        $report.PSObject.Properties.Name | Should -Contain "ManifestFile"
        $report.PSObject.Properties.Name | Should -Contain "TotalDependencies"
        $report.PSObject.Properties.Name | Should -Contain "Summary"
        $report.PSObject.Properties.Name | Should -Contain "Dependencies"
    }

    It "Lists all dependencies with their license and status" {
        $report = New-ComplianceReport -ManifestPath $script:reportPkgPath `
            -Config $script:reportConfig -LicenseLookup $script:reportMockLookup

        $report.Dependencies.Count | Should -Be 2

        $expressDep = $report.Dependencies | Where-Object { $_.Name -eq "express" }
        $expressDep.License | Should -Be "MIT"
        $expressDep.Status | Should -Be "approved"

        $lodashDep = $report.Dependencies | Where-Object { $_.Name -eq "lodash" }
        $lodashDep.License | Should -Be "GPL-3.0"
        $lodashDep.Status | Should -Be "denied"
    }

    It "Produces correct summary counts" {
        $report = New-ComplianceReport -ManifestPath $script:reportPkgPath `
            -Config $script:reportConfig -LicenseLookup $script:reportMockLookup

        $report.Summary.Approved | Should -Be 1
        $report.Summary.Denied   | Should -Be 1
        $report.Summary.Unknown  | Should -Be 0
        $report.TotalDependencies | Should -Be 2
    }

    It "Handles unknown licenses in the report" {
        $mixedMock = {
            param([string]$Name, [string]$Version)
            switch ($Name) {
                "express" { "MIT" }
                "lodash"  { $null }  # unknown license
                default   { $null }
            }
        }

        $report = New-ComplianceReport -ManifestPath $script:reportPkgPath `
            -Config $script:reportConfig -LicenseLookup $mixedMock

        $lodashDep = $report.Dependencies | Where-Object { $_.Name -eq "lodash" }
        $lodashDep.Status | Should -Be "unknown"
        $report.Summary.Unknown | Should -Be 1
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 8: Config loading from JSON file
# RED:  Tests fail because Import-LicenseConfig doesn't exist.
# GREEN: Implement config loading with validation.
# ---------------------------------------------------------------------------
Describe "Import-LicenseConfig" {

    BeforeAll {
        $validConfig = @{
            AllowedLicenses = @("MIT", "Apache-2.0")
            DeniedLicenses  = @("GPL-3.0")
        } | ConvertTo-Json

        $script:configPath = Join-Path $script:fixtureDir "license-config.json"
        Set-Content -Path $script:configPath -Value $validConfig
    }

    It "Loads config from a JSON file" {
        $config = Import-LicenseConfig -Path $script:configPath
        $config.AllowedLicenses | Should -Contain "MIT"
        $config.DeniedLicenses  | Should -Contain "GPL-3.0"
    }

    It "Throws when config file is missing" {
        { Import-LicenseConfig -Path "/nonexistent/config.json" } |
            Should -Throw "*does not exist*"
    }

    It "Throws when AllowedLicenses is missing from config" {
        $badConfig = @{ DeniedLicenses = @("GPL-3.0") } | ConvertTo-Json
        $badPath = Join-Path $script:fixtureDir "bad-config.json"
        Set-Content -Path $badPath -Value $badConfig

        { Import-LicenseConfig -Path $badPath } |
            Should -Throw "*AllowedLicenses*"
    }

    It "Throws when DeniedLicenses is missing from config" {
        $badConfig = @{ AllowedLicenses = @("MIT") } | ConvertTo-Json
        $badPath = Join-Path $script:fixtureDir "bad-config2.json"
        Set-Content -Path $badPath -Value $badConfig

        { Import-LicenseConfig -Path $badPath } |
            Should -Throw "*DeniedLicenses*"
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 9: Report formatting (text output)
# RED:  Tests fail because Format-ComplianceReport doesn't exist.
# GREEN: Implement text formatting of the report for console/file output.
# ---------------------------------------------------------------------------
Describe "Format-ComplianceReport" {

    BeforeAll {
        # Build a mock report object directly
        $script:mockReport = [PSCustomObject]@{
            GeneratedAt       = "2026-04-05T12:00:00"
            ManifestFile      = "package.json"
            TotalDependencies = 3
            Summary           = [PSCustomObject]@{
                Approved = 2
                Denied   = 1
                Unknown  = 0
            }
            Dependencies      = @(
                [PSCustomObject]@{ Name = "express"; Version = "4.18.2"; License = "MIT"; Status = "approved" }
                [PSCustomObject]@{ Name = "lodash"; Version = "4.17.21"; License = "MIT"; Status = "approved" }
                [PSCustomObject]@{ Name = "leftpad"; Version = "1.0.0"; License = "GPL-3.0"; Status = "denied" }
            )
        }
    }

    It "Returns a non-empty string" {
        $output = Format-ComplianceReport -Report $script:mockReport
        $output | Should -Not -BeNullOrEmpty
    }

    It "Contains the manifest file name" {
        $output = Format-ComplianceReport -Report $script:mockReport
        $output | Should -BeLike "*package.json*"
    }

    It "Contains summary counts" {
        $output = Format-ComplianceReport -Report $script:mockReport
        $output | Should -BeLike "*Approved: 2*"
        $output | Should -BeLike "*Denied: 1*"
        $output | Should -BeLike "*Unknown: 0*"
    }

    It "Lists each dependency with its status" {
        $output = Format-ComplianceReport -Report $script:mockReport
        $output | Should -BeLike "*express*MIT*approved*"
        $output | Should -BeLike "*leftpad*GPL-3.0*denied*"
    }
}
