# Dependency License Checker - Test Suite (TDD)
# Following red/green TDD: write failing test, implement minimum code, refactor

# In Pester 5, dot-sourcing must live inside BeforeAll so that the functions
# are available during the run phase (not just discovery).
BeforeAll {
    . "$PSScriptRoot/LicenseChecker.ps1"
}

Describe "Parse-PackageJson" {
    # TEST 1: Parse package.json and extract dependency name/version pairs
    Context "Given a valid package.json content" {
        It "extracts dependencies with their versions" {
            $json = @{
                name = "my-app"
                dependencies = @{
                    "express"  = "^4.18.2"
                    "lodash"   = "~4.17.21"
                    "axios"    = "1.4.0"
                }
            } | ConvertTo-Json

            $result = Parse-PackageJson -Content $json

            $result | Should -HaveCount 3
            $result | Where-Object { $_.Name -eq "express"  } | Select-Object -ExpandProperty Version | Should -Be "^4.18.2"
            $result | Where-Object { $_.Name -eq "lodash"   } | Select-Object -ExpandProperty Version | Should -Be "~4.17.21"
            $result | Where-Object { $_.Name -eq "axios"    } | Select-Object -ExpandProperty Version | Should -Be "1.4.0"
        }

        It "returns empty array when there are no dependencies" {
            $json = @{ name = "empty-app" } | ConvertTo-Json
            $result = Parse-PackageJson -Content $json
            $result | Should -HaveCount 0
        }

        It "includes devDependencies when IncludeDev flag is set" {
            $json = @{
                dependencies    = @{ "express" = "4.0.0" }
                devDependencies = @{ "jest"    = "29.0.0" }
            } | ConvertTo-Json

            $result = Parse-PackageJson -Content $json -IncludeDev
            $result | Should -HaveCount 2
            $result | Where-Object { $_.Name -eq "jest" } | Should -Not -BeNullOrEmpty
        }
    }

    Context "Given invalid input" {
        It "throws a meaningful error for malformed JSON" {
            { Parse-PackageJson -Content "not-json{{" } | Should -Throw "*Invalid JSON*"
        }
    }
}

Describe "Parse-RequirementsTxt" {
    # TEST 2: Parse requirements.txt and extract dependency name/version pairs
    Context "Given a valid requirements.txt content" {
        It "extracts packages with pinned versions" {
            $content = @"
requests==2.31.0
flask==2.3.2
numpy==1.25.0
"@
            $result = Parse-RequirementsTxt -Content $content
            $result | Should -HaveCount 3
            $result | Where-Object { $_.Name -eq "requests" } | Select-Object -ExpandProperty Version | Should -Be "2.31.0"
            $result | Where-Object { $_.Name -eq "flask"    } | Select-Object -ExpandProperty Version | Should -Be "2.3.2"
        }

        It "skips comment lines and blank lines" {
            $content = @"
# This is a comment
requests==2.31.0

# Another comment
flask==2.3.2
"@
            $result = Parse-RequirementsTxt -Content $content
            $result | Should -HaveCount 2
        }

        It "handles packages without a pinned version" {
            $content = "requests"
            $result = Parse-RequirementsTxt -Content $content
            $result | Should -HaveCount 1
            $result[0].Name    | Should -Be "requests"
            $result[0].Version | Should -Be "unspecified"
        }

        It "handles version specifiers other than ==" {
            $content = @"
requests>=2.0.0
flask<=3.0.0
numpy~=1.25
"@
            $result = Parse-RequirementsTxt -Content $content
            $result | Should -HaveCount 3
            $result | Where-Object { $_.Name -eq "requests" } | Select-Object -ExpandProperty Version | Should -Be ">=2.0.0"
        }
    }
}

Describe "Get-DependencyLicense (mocked)" {
    # TEST 3: License lookup with a mock lookup function
    Context "Given a mock license database" {
        BeforeAll {
            # Mock license database: maps package name -> license identifier
            $script:MockLicenseDb = @{
                "express"  = "MIT"
                "lodash"   = "MIT"
                "axios"    = "MIT"
                "requests" = "Apache-2.0"
                "flask"    = "BSD-3-Clause"
                "gpl-lib"  = "GPL-3.0"
                "agpl-pkg" = "AGPL-3.0"
            }

            # The mock lookup function replaces the real HTTP call
            function script:Invoke-LicenseLookup([string]$PackageName) {
                if ($script:MockLicenseDb.ContainsKey($PackageName)) {
                    return $script:MockLicenseDb[$PackageName]
                }
                return $null  # unknown
            }
        }

        It "returns the license for a known package" {
            $license = Get-DependencyLicense -PackageName "express" -LookupFn ${function:script:Invoke-LicenseLookup}
            $license | Should -Be "MIT"
        }

        It "returns null for an unknown package" {
            $license = Get-DependencyLicense -PackageName "unknown-pkg" -LookupFn ${function:script:Invoke-LicenseLookup}
            $license | Should -BeNullOrEmpty
        }
    }
}

Describe "Test-LicenseCompliance" {
    # TEST 4: Check a license against allow/deny lists
    Context "Given an allow-list and deny-list config" {
        BeforeAll {
            $script:Config = @{
                AllowedLicenses = @("MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC")
                DeniedLicenses  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.1")
            }
        }

        It "returns 'approved' for an allowed license" {
            $status = Test-LicenseCompliance -License "MIT" -Config $script:Config
            $status | Should -Be "approved"
        }

        It "returns 'approved' for Apache-2.0" {
            $status = Test-LicenseCompliance -License "Apache-2.0" -Config $script:Config
            $status | Should -Be "approved"
        }

        It "returns 'denied' for a denied license" {
            $status = Test-LicenseCompliance -License "GPL-3.0" -Config $script:Config
            $status | Should -Be "denied"
        }

        It "returns 'unknown' for a license not in either list" {
            $status = Test-LicenseCompliance -License "CC-BY-4.0" -Config $script:Config
            $status | Should -Be "unknown"
        }

        It "returns 'unknown' when license is null" {
            $status = Test-LicenseCompliance -License $null -Config $script:Config
            $status | Should -Be "unknown"
        }
    }
}

Describe "New-ComplianceReport" {
    # TEST 5: Full end-to-end compliance report generation
    Context "Given dependencies and a mock license lookup" {
        BeforeAll {
            $script:MockDb = @{
                "express"  = "MIT"
                "lodash"   = "MIT"
                "gpl-lib"  = "GPL-3.0"
                "mystery"  = $null   # no license info available
            }

            function script:MockLookup([string]$PackageName) {
                return $script:MockDb[$PackageName]
            }

            $script:ReportConfig = @{
                AllowedLicenses = @("MIT", "Apache-2.0", "BSD-3-Clause")
                DeniedLicenses  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0")
            }

            $script:Dependencies = @(
                [PSCustomObject]@{ Name = "express"; Version = "4.18.2" }
                [PSCustomObject]@{ Name = "lodash";  Version = "4.17.21" }
                [PSCustomObject]@{ Name = "gpl-lib"; Version = "1.0.0"  }
                [PSCustomObject]@{ Name = "mystery"; Version = "2.0.0"  }
            )
        }

        It "generates a report with one entry per dependency" {
            $report = New-ComplianceReport -Dependencies $script:Dependencies `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $report.Entries | Should -HaveCount 4
        }

        It "correctly marks MIT packages as approved" {
            $report = New-ComplianceReport -Dependencies $script:Dependencies `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $express = $report.Entries | Where-Object { $_.Name -eq "express" }
            $express.License | Should -Be "MIT"
            $express.Status  | Should -Be "approved"
        }

        It "correctly marks GPL packages as denied" {
            $report = New-ComplianceReport -Dependencies $script:Dependencies `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $gpl = $report.Entries | Where-Object { $_.Name -eq "gpl-lib" }
            $gpl.License | Should -Be "GPL-3.0"
            $gpl.Status  | Should -Be "denied"
        }

        It "correctly marks unknown packages as unknown" {
            $report = New-ComplianceReport -Dependencies $script:Dependencies `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $mystery = $report.Entries | Where-Object { $_.Name -eq "mystery" }
            $mystery.Status | Should -Be "unknown"
        }

        It "includes a summary with counts" {
            $report = New-ComplianceReport -Dependencies $script:Dependencies `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $report.Summary.Approved | Should -Be 2
            $report.Summary.Denied   | Should -Be 1
            $report.Summary.Unknown  | Should -Be 1
            $report.Summary.Total    | Should -Be 4
        }

        It "sets Compliant=true only when there are no denied dependencies" {
            $clean = @(
                [PSCustomObject]@{ Name = "express"; Version = "4.18.2" }
            )
            $report = New-ComplianceReport -Dependencies $clean `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $report.Summary.Compliant | Should -Be $true
        }

        It "sets Compliant=false when there are denied dependencies" {
            $report = New-ComplianceReport -Dependencies $script:Dependencies `
                                           -Config $script:ReportConfig `
                                           -LookupFn ${function:script:MockLookup}
            $report.Summary.Compliant | Should -Be $false
        }
    }
}

Describe "Format-ComplianceReport" {
    # TEST 6: Human-readable report output
    Context "Given a completed compliance report object" {
        BeforeAll {
            $script:SampleReport = [PSCustomObject]@{
                Entries = @(
                    [PSCustomObject]@{ Name = "express"; Version = "4.18.2"; License = "MIT";     Status = "approved" }
                    [PSCustomObject]@{ Name = "gpl-lib"; Version = "1.0.0";  License = "GPL-3.0"; Status = "denied"   }
                    [PSCustomObject]@{ Name = "mystery"; Version = "2.0.0";  License = $null;     Status = "unknown"  }
                )
                Summary = [PSCustomObject]@{
                    Total     = 3
                    Approved  = 1
                    Denied    = 1
                    Unknown   = 1
                    Compliant = $false
                }
            }
        }

        It "produces text output containing each package name" {
            $text = Format-ComplianceReport -Report $script:SampleReport
            $text | Should -Match "express"
            $text | Should -Match "gpl-lib"
            $text | Should -Match "mystery"
        }

        It "includes status labels in the output" {
            $text = Format-ComplianceReport -Report $script:SampleReport
            $text | Should -Match "approved"
            $text | Should -Match "denied"
            $text | Should -Match "unknown"
        }

        It "includes the summary counts" {
            $text = Format-ComplianceReport -Report $script:SampleReport
            $text | Should -Match "Total.*3|3.*Total"
        }
    }
}

Describe "Invoke-LicenseCheck (integration)" {
    # TEST 7: End-to-end integration using file fixtures
    Context "Given a package.json fixture file" {
        BeforeAll {
            # Create a temp package.json fixture
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-checker-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TempDir | Out-Null

            $pkgJson = @{
                name = "test-app"
                dependencies = @{
                    "express" = "^4.18.2"
                    "lodash"  = "~4.17.21"
                    "gpl-lib" = "1.0.0"
                }
            } | ConvertTo-Json
            Set-Content -Path (Join-Path $script:TempDir "package.json") -Value $pkgJson

            # Config file
            $config = @{
                AllowedLicenses = @("MIT", "Apache-2.0", "BSD-3-Clause")
                DeniedLicenses  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0")
            } | ConvertTo-Json
            Set-Content -Path (Join-Path $script:TempDir "license-config.json") -Value $config

            # Mock license DB for integration test
            $script:IntMockDb = @{
                "express" = "MIT"
                "lodash"  = "MIT"
                "gpl-lib" = "GPL-3.0"
            }
            function script:IntMockLookup([string]$PackageName) {
                return $script:IntMockDb[$PackageName]
            }
        }

        AfterAll {
            Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
        }

        It "runs end-to-end and returns a report with correct statuses" {
            $report = Invoke-LicenseCheck `
                -ManifestPath (Join-Path $script:TempDir "package.json") `
                -ConfigPath   (Join-Path $script:TempDir "license-config.json") `
                -LookupFn     ${function:script:IntMockLookup}

            $report.Summary.Total    | Should -Be 3
            $report.Summary.Approved | Should -Be 2
            $report.Summary.Denied   | Should -Be 1
            $report.Summary.Compliant | Should -Be $false
        }
    }

    Context "Given a requirements.txt fixture file" {
        BeforeAll {
            $script:TempDir2 = Join-Path ([System.IO.Path]::GetTempPath()) "license-checker-test2-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TempDir2 | Out-Null

            Set-Content -Path (Join-Path $script:TempDir2 "requirements.txt") -Value @"
requests==2.31.0
flask==2.3.2
agpl-pkg==1.0.0
"@

            $config = @{
                AllowedLicenses = @("MIT", "Apache-2.0", "BSD-3-Clause")
                DeniedLicenses  = @("GPL-2.0", "GPL-3.0", "AGPL-3.0")
            } | ConvertTo-Json
            Set-Content -Path (Join-Path $script:TempDir2 "license-config.json") -Value $config

            $script:IntMockDb2 = @{
                "requests" = "Apache-2.0"
                "flask"    = "BSD-3-Clause"
                "agpl-pkg" = "AGPL-3.0"
            }
            function script:IntMockLookup2([string]$PackageName) {
                return $script:IntMockDb2[$PackageName]
            }
        }

        AfterAll {
            Remove-Item -Recurse -Force $script:TempDir2 -ErrorAction SilentlyContinue
        }

        It "parses requirements.txt and checks licenses correctly" {
            $report = Invoke-LicenseCheck `
                -ManifestPath (Join-Path $script:TempDir2 "requirements.txt") `
                -ConfigPath   (Join-Path $script:TempDir2 "license-config.json") `
                -LookupFn     ${function:script:IntMockLookup2}

            $report.Summary.Total    | Should -Be 3
            $report.Summary.Approved | Should -Be 2
            $report.Summary.Denied   | Should -Be 1
        }
    }
}
