# SecretRotationValidator.Tests.ps1
# TDD tests for Secret Rotation Validator
# Written BEFORE the implementation (red phase)
#
# Pester 5 scoping note: variables and dot-sourcing must live in BeforeAll blocks
# so they are visible during the run phase (not just the discovery phase).

BeforeAll {
    # Import the module under test via dot-sourcing
    $script:ModulePath = Join-Path $PSScriptRoot "SecretRotationValidator.ps1"
    . $script:ModulePath
}

Describe "Get-SecretStatus" {
    BeforeAll {
        # Fixed reference date so every test is deterministic
        $script:RefDate = [datetime]"2024-06-01"
    }

    Context "when a secret is within rotation policy (ok)" {
        It "returns 'ok' status when secret was rotated recently" {
            # Rotated 10 days ago, policy is 90 days — clearly ok
            $secret = @{
                Name               = "DB_PASSWORD"
                LastRotated        = $script:RefDate.AddDays(-10)
                RotationPolicyDays = 90
                RequiredBy         = @("api-service")
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.Status | Should -Be "ok"
        }

        It "returns positive DaysUntilExpiry when secret is ok" {
            $secret = @{
                Name               = "API_KEY"
                LastRotated        = $script:RefDate.AddDays(-10)
                RotationPolicyDays = 90
                RequiredBy         = @()
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.DaysUntilExpiry | Should -Be 80
        }
    }

    Context "when a secret is expired" {
        It "returns 'expired' status when past rotation deadline" {
            # Rotated 100 days ago, policy is 90 days — expired
            $secret = @{
                Name               = "OLD_API_KEY"
                LastRotated        = $script:RefDate.AddDays(-100)
                RotationPolicyDays = 90
                RequiredBy         = @("legacy-service")
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.Status | Should -Be "expired"
        }

        It "returns negative DaysUntilExpiry when expired" {
            $secret = @{
                Name               = "OLD_API_KEY"
                LastRotated        = $script:RefDate.AddDays(-100)
                RotationPolicyDays = 90
                RequiredBy         = @()
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.DaysUntilExpiry | Should -Be -10
        }

        It "returns 'expired' when secret expires exactly today (0 days left)" {
            $secret = @{
                Name               = "EXACT_EXPIRY_KEY"
                LastRotated        = $script:RefDate.AddDays(-90)
                RotationPolicyDays = 90
                RequiredBy         = @()
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.Status | Should -Be "expired"
        }
    }

    Context "when a secret is in the warning window" {
        It "returns 'warning' status when within warning window but not yet expired" {
            # Rotated 80 days ago, policy is 90 days, warning window is 14 days
            # DaysUntilExpiry = 10 — within the 14-day warning window
            $secret = @{
                Name               = "SOON_TO_EXPIRE"
                LastRotated        = $script:RefDate.AddDays(-80)
                RotationPolicyDays = 90
                RequiredBy         = @("payments-service")
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.Status | Should -Be "warning"
        }

        It "returns 'warning' when exactly at the warning window boundary" {
            # DaysUntilExpiry = 14 exactly — should be warning
            $secret = @{
                Name               = "BOUNDARY_KEY"
                LastRotated        = $script:RefDate.AddDays(-76)
                RotationPolicyDays = 90
                RequiredBy         = @()
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.Status | Should -Be "warning"
        }

        It "returns 'ok' when one day past the warning boundary" {
            # DaysUntilExpiry = 15 — just outside the 14-day warning window
            $secret = @{
                Name               = "JUST_OUTSIDE_WARNING"
                LastRotated        = $script:RefDate.AddDays(-75)
                RotationPolicyDays = 90
                RequiredBy         = @()
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 14

            $result.Status | Should -Be "ok"
        }
    }

    Context "result object shape" {
        It "includes all required fields in the result" {
            $secret = @{
                Name               = "COMPLETE_KEY"
                LastRotated        = $script:RefDate.AddDays(-10)
                RotationPolicyDays = 30
                RequiredBy         = @("svc-a", "svc-b")
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningWindowDays 7

            $result.Keys | Should -Contain "Name"
            $result.Keys | Should -Contain "LastRotated"
            $result.Keys | Should -Contain "RotationPolicyDays"
            $result.Keys | Should -Contain "DaysUntilExpiry"
            $result.Keys | Should -Contain "Status"
            $result.Keys | Should -Contain "RequiredBy"
            $result.Keys | Should -Contain "ExpiryDate"
        }
    }
}

Describe "Invoke-SecretRotationAnalysis" {
    BeforeAll {
        $script:RefDate2 = [datetime]"2024-06-01"

        # Shared fixture: a mix of expired, warning, and ok secrets
        $script:MixedSecrets = @(
            @{
                Name               = "EXPIRED_SECRET"
                LastRotated        = $script:RefDate2.AddDays(-100)
                RotationPolicyDays = 90
                RequiredBy         = @("service-a")
            },
            @{
                Name               = "WARNING_SECRET"
                LastRotated        = $script:RefDate2.AddDays(-80)
                RotationPolicyDays = 90
                RequiredBy         = @("service-b")
            },
            @{
                Name               = "OK_SECRET"
                LastRotated        = $script:RefDate2.AddDays(-10)
                RotationPolicyDays = 90
                RequiredBy         = @("service-c")
            }
        )
    }

    It "returns a report object with Expired, Warning, and Ok groups" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate2 -WarningWindowDays 14

        $report.Keys | Should -Contain "Expired"
        $report.Keys | Should -Contain "Warning"
        $report.Keys | Should -Contain "Ok"
    }

    It "correctly groups expired secrets" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate2 -WarningWindowDays 14

        $report.Expired.Count | Should -Be 1
        $report.Expired[0].Name | Should -Be "EXPIRED_SECRET"
    }

    It "correctly groups warning secrets" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate2 -WarningWindowDays 14

        $report.Warning.Count | Should -Be 1
        $report.Warning[0].Name | Should -Be "WARNING_SECRET"
    }

    It "correctly groups ok secrets" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate2 -WarningWindowDays 14

        $report.Ok.Count | Should -Be 1
        $report.Ok[0].Name | Should -Be "OK_SECRET"
    }

    It "includes summary statistics" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate2 -WarningWindowDays 14

        $report.Keys | Should -Contain "Summary"
        $report.Summary.Total | Should -Be 3
        $report.Summary.ExpiredCount | Should -Be 1
        $report.Summary.WarningCount | Should -Be 1
        $report.Summary.OkCount | Should -Be 1
    }

    It "handles an empty secrets list gracefully" {
        $report = Invoke-SecretRotationAnalysis -Secrets @() -ReferenceDate $script:RefDate2 -WarningWindowDays 14

        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.Ok.Count | Should -Be 0
        $report.Summary.Total | Should -Be 0
    }

    It "uses default warning window of 30 days when not specified" {
        # Secret expires in 20 days — should be 'warning' with default 30-day window
        $secrets = @(
            @{
                Name               = "NEAR_EXPIRY"
                LastRotated        = $script:RefDate2.AddDays(-70)
                RotationPolicyDays = 90
                RequiredBy         = @()
            }
        )

        $report = Invoke-SecretRotationAnalysis -Secrets $secrets -ReferenceDate $script:RefDate2

        $report.Warning.Count | Should -Be 1
    }
}

Describe "Format-RotationReport (Markdown)" {
    BeforeAll {
        $script:RefDate3 = [datetime]"2024-06-01"

        $script:MdSecrets = @(
            @{
                Name               = "DB_PASSWORD"
                LastRotated        = $script:RefDate3.AddDays(-100)
                RotationPolicyDays = 90
                RequiredBy         = @("api", "worker")
            },
            @{
                Name               = "JWT_SECRET"
                LastRotated        = $script:RefDate3.AddDays(-80)
                RotationPolicyDays = 90
                RequiredBy         = @("auth-service")
            },
            @{
                Name               = "SMTP_PASSWORD"
                LastRotated        = $script:RefDate3.AddDays(-5)
                RotationPolicyDays = 180
                RequiredBy         = @("mailer")
            }
        )
    }

    It "produces a markdown string when Format is 'Markdown'" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MdSecrets -ReferenceDate $script:RefDate3 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "Markdown"

        $output | Should -BeOfType [string]
        $output.Length | Should -BeGreaterThan 0
    }

    It "markdown output contains a table header row" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MdSecrets -ReferenceDate $script:RefDate3 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "Markdown"

        # Markdown table headers use | separator
        $output | Should -Match "\|.*Name.*\|"
    }

    It "markdown output contains the secret names" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MdSecrets -ReferenceDate $script:RefDate3 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "Markdown"

        $output | Should -Match "DB_PASSWORD"
        $output | Should -Match "JWT_SECRET"
        $output | Should -Match "SMTP_PASSWORD"
    }

    It "markdown output contains urgency sections" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MdSecrets -ReferenceDate $script:RefDate3 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "Markdown"

        $output | Should -Match "Expired"
        $output | Should -Match "Warning"
        $output | Should -Match "OK|Ok"
    }

    It "markdown output includes the summary statistics" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:MdSecrets -ReferenceDate $script:RefDate3 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "Markdown"

        # Total count (3) should appear somewhere in the summary
        $output | Should -Match "3"
    }
}

Describe "Format-RotationReport (JSON)" {
    BeforeAll {
        $script:RefDate4 = [datetime]"2024-06-01"

        $script:JsonSecrets = @(
            @{
                Name               = "API_KEY"
                LastRotated        = $script:RefDate4.AddDays(-95)
                RotationPolicyDays = 90
                RequiredBy         = @("service-x")
            },
            @{
                Name               = "WEBHOOK_SECRET"
                LastRotated        = $script:RefDate4.AddDays(-20)
                RotationPolicyDays = 30
                RequiredBy         = @("webhooks")
            }
        )
    }

    It "produces a valid JSON string when Format is 'JSON'" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:JsonSecrets -ReferenceDate $script:RefDate4 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "JSON"

        # Should not throw when parsing
        { $null = $output | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON output contains expired secrets array" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:JsonSecrets -ReferenceDate $script:RefDate4 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "JSON"
        $parsed = $output | ConvertFrom-Json

        $parsed.expired | Should -Not -BeNullOrEmpty
        $parsed.expired[0].name | Should -Be "API_KEY"
    }

    It "JSON output contains warning secrets array" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:JsonSecrets -ReferenceDate $script:RefDate4 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "JSON"
        $parsed = $output | ConvertFrom-Json

        $parsed.warning | Should -Not -BeNullOrEmpty
        $parsed.warning[0].name | Should -Be "WEBHOOK_SECRET"
    }

    It "JSON output contains summary" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:JsonSecrets -ReferenceDate $script:RefDate4 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "JSON"
        $parsed = $output | ConvertFrom-Json

        $parsed.summary | Should -Not -BeNullOrEmpty
        $parsed.summary.total | Should -Be 2
    }

    It "JSON output includes required_by services for each secret" {
        $report = Invoke-SecretRotationAnalysis -Secrets $script:JsonSecrets -ReferenceDate $script:RefDate4 -WarningWindowDays 14

        $output = Format-RotationReport -Report $report -Format "JSON"
        $parsed = $output | ConvertFrom-Json

        $parsed.expired[0].required_by | Should -Contain "service-x"
    }
}

Describe "Format-RotationReport (error handling)" {
    It "throws a meaningful error for unsupported format" {
        $report = @{ Expired = @(); Warning = @(); Ok = @(); Summary = @{ Total = 0 } }

        { Format-RotationReport -Report $report -Format "XML" } | Should -Throw "*Unsupported format*"
    }
}

Describe "New-RotationReport (integration)" {
    BeforeAll {
        $script:IntRefDate = [datetime]"2024-06-01"

        # Integration fixture: full pipeline from raw config to formatted output
        $script:IntConfig = @{
            Secrets = @(
                @{
                    Name               = "PROD_DB_PASS"
                    LastRotated        = "2024-01-15"  # string date — must be parsed
                    RotationPolicyDays = 90
                    RequiredBy         = @("backend", "reporting")
                },
                @{
                    Name               = "STRIPE_KEY"
                    LastRotated        = "2024-05-25"  # recently rotated
                    RotationPolicyDays = 30
                    RequiredBy         = @("payments")
                },
                @{
                    Name               = "INTERNAL_TOKEN"
                    LastRotated        = "2024-05-20"  # expiring soon
                    RotationPolicyDays = 14
                    RequiredBy         = @("internal-api")
                }
            )
            WarningWindowDays = 7
        }
    }

    It "produces markdown output end-to-end" {
        $output = New-RotationReport -Config $script:IntConfig -Format "Markdown" -ReferenceDate $script:IntRefDate

        $output | Should -BeOfType [string]
        $output | Should -Match "PROD_DB_PASS"
        $output | Should -Match "STRIPE_KEY"
        $output | Should -Match "INTERNAL_TOKEN"
    }

    It "produces JSON output end-to-end" {
        $output = New-RotationReport -Config $script:IntConfig -Format "JSON" -ReferenceDate $script:IntRefDate

        { $null = $output | ConvertFrom-Json } | Should -Not -Throw
        $parsed = $output | ConvertFrom-Json
        $parsed.summary.total | Should -Be 3
    }

    It "accepts string dates for LastRotated in config" {
        # Should not throw even though LastRotated is a string
        { New-RotationReport -Config $script:IntConfig -Format "JSON" -ReferenceDate $script:IntRefDate } | Should -Not -Throw
    }

    It "correctly classifies PROD_DB_PASS as expired (rotated ~137 days ago, policy 90 days)" {
        $output = New-RotationReport -Config $script:IntConfig -Format "JSON" -ReferenceDate $script:IntRefDate
        $parsed = $output | ConvertFrom-Json

        $expiredNames = $parsed.expired | ForEach-Object { $_.name }
        $expiredNames | Should -Contain "PROD_DB_PASS"
    }

    It "correctly classifies STRIPE_KEY as ok (rotated 7 days ago, policy 30 days)" {
        $output = New-RotationReport -Config $script:IntConfig -Format "JSON" -ReferenceDate $script:IntRefDate
        $parsed = $output | ConvertFrom-Json

        $okNames = $parsed.ok | ForEach-Object { $_.name }
        $okNames | Should -Contain "STRIPE_KEY"
    }
}
