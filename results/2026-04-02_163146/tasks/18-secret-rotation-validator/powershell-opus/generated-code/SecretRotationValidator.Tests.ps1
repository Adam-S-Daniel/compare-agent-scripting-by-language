# SecretRotationValidator.Tests.ps1
# Pester tests for the Secret Rotation Validator module
# Following red/green TDD: each test block was written before the implementation code.

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe "Get-SecretStatus" {
    # Test fixture: a reference date so tests are deterministic
    BeforeAll {
        $referenceDate = [datetime]::Parse("2026-04-06")
    }

    Context "When a secret is expired" {
        It "Should return 'Expired' for a secret rotated 100 days ago with a 90-day policy" {
            $secret = @{
                Name          = "db-password"
                LastRotated   = $referenceDate.AddDays(-100)
                RotationDays  = 90
                RequiredBy    = @("api-service", "worker")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.Status | Should -Be "Expired"
        }

        It "Should return 'Expired' for a secret rotated exactly on the expiry boundary" {
            $secret = @{
                Name          = "api-key"
                LastRotated   = $referenceDate.AddDays(-90)
                RotationDays  = 90
                RequiredBy    = @("frontend")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.Status | Should -Be "Expired"
        }

        It "Should compute days overdue correctly" {
            $secret = @{
                Name          = "old-token"
                LastRotated   = $referenceDate.AddDays(-100)
                RotationDays  = 90
                RequiredBy    = @("service-a")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.DaysOverdue | Should -Be 10
        }
    }

    Context "When a secret is in the warning window" {
        It "Should return 'Warning' for a secret expiring within the warning window" {
            $secret = @{
                Name          = "tls-cert"
                LastRotated   = $referenceDate.AddDays(-80)
                RotationDays  = 90
                RequiredBy    = @("load-balancer")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.Status | Should -Be "Warning"
        }

        It "Should return 'Warning' at the exact boundary of the warning window" {
            # Expires in exactly 14 days = warning boundary
            $secret = @{
                Name          = "ssh-key"
                LastRotated   = $referenceDate.AddDays(-76)
                RotationDays  = 90
                RequiredBy    = @("deploy-bot")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.Status | Should -Be "Warning"
        }

        It "Should compute days until expiry correctly" {
            $secret = @{
                Name          = "jwt-secret"
                LastRotated   = $referenceDate.AddDays(-85)
                RotationDays  = 90
                RequiredBy    = @("auth-service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.DaysUntilExpiry | Should -Be 5
        }
    }

    Context "When a secret is OK" {
        It "Should return 'OK' for a recently rotated secret" {
            $secret = @{
                Name          = "new-secret"
                LastRotated   = $referenceDate.AddDays(-10)
                RotationDays  = 90
                RequiredBy    = @("api")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.Status | Should -Be "OK"
        }

        It "Should return 'OK' when secret expires one day after warning window" {
            # Expires in 15 days, warning is 14 => OK
            $secret = @{
                Name          = "safe-key"
                LastRotated   = $referenceDate.AddDays(-75)
                RotationDays  = 90
                RequiredBy    = @("service-b")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
            $result.Status | Should -Be "OK"
        }
    }

    Context "Custom warning window" {
        It "Should respect a custom 30-day warning window" {
            # Expires in 25 days — inside a 30-day warning window
            $secret = @{
                Name          = "custom-key"
                LastRotated   = $referenceDate.AddDays(-65)
                RotationDays  = 90
                RequiredBy    = @("svc")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 30
            $result.Status | Should -Be "Warning"
        }
    }
}

Describe "Get-RotationReport" {
    BeforeAll {
        $referenceDate = [datetime]::Parse("2026-04-06")
        $secrets = @(
            @{ Name = "expired-secret";  LastRotated = $referenceDate.AddDays(-100); RotationDays = 90;  RequiredBy = @("svc-a", "svc-b") }
            @{ Name = "warning-secret";  LastRotated = $referenceDate.AddDays(-80);  RotationDays = 90;  RequiredBy = @("svc-c") }
            @{ Name = "ok-secret";       LastRotated = $referenceDate.AddDays(-10);  RotationDays = 90;  RequiredBy = @("svc-d") }
            @{ Name = "also-expired";    LastRotated = $referenceDate.AddDays(-200); RotationDays = 90;  RequiredBy = @("svc-e", "svc-f", "svc-g") }
        )
    }

    It "Should group secrets by urgency" {
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningDays 14
        $report.Expired.Count | Should -Be 2
        $report.Warning.Count | Should -Be 1
        $report.OK.Count | Should -Be 1
    }

    It "Should include a summary with counts" {
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningDays 14
        $report.Summary.TotalSecrets | Should -Be 4
        $report.Summary.ExpiredCount | Should -Be 2
        $report.Summary.WarningCount | Should -Be 1
        $report.Summary.OKCount | Should -Be 1
    }

    It "Should sort expired secrets by days overdue (most overdue first)" {
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningDays 14
        $report.Expired[0].Name | Should -Be "also-expired"
        $report.Expired[1].Name | Should -Be "expired-secret"
    }
}

Describe "ConvertTo-RotationMarkdown" {
    BeforeAll {
        $referenceDate = [datetime]::Parse("2026-04-06")
        $secrets = @(
            @{ Name = "expired-db-pw";  LastRotated = $referenceDate.AddDays(-100); RotationDays = 90; RequiredBy = @("api", "worker") }
            @{ Name = "warning-cert";   LastRotated = $referenceDate.AddDays(-80);  RotationDays = 90; RequiredBy = @("lb") }
            @{ Name = "ok-token";       LastRotated = $referenceDate.AddDays(-10);  RotationDays = 90; RequiredBy = @("frontend") }
        )
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningDays 14
    }

    It "Should produce markdown with a header" {
        $md = ConvertTo-RotationMarkdown -Report $report
        $md | Should -Match "# Secret Rotation Report"
    }

    It "Should contain a table with pipe delimiters" {
        $md = ConvertTo-RotationMarkdown -Report $report
        $md | Should -Match "\|.*Name.*\|.*Status.*\|"
    }

    It "Should include expired secret names in output" {
        $md = ConvertTo-RotationMarkdown -Report $report
        $md | Should -Match "expired-db-pw"
    }

    It "Should include a summary section" {
        $md = ConvertTo-RotationMarkdown -Report $report
        $md | Should -Match "Summary"
    }
}

Describe "ConvertTo-RotationJson" {
    BeforeAll {
        $referenceDate = [datetime]::Parse("2026-04-06")
        $secrets = @(
            @{ Name = "expired-key"; LastRotated = $referenceDate.AddDays(-95); RotationDays = 90; RequiredBy = @("svc-x") }
            @{ Name = "ok-key";      LastRotated = $referenceDate.AddDays(-5);  RotationDays = 90; RequiredBy = @("svc-y") }
        )
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningDays 14
    }

    It "Should produce valid JSON" {
        $json = ConvertTo-RotationJson -Report $report
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It "Should include expired and ok groups in JSON" {
        $json = ConvertTo-RotationJson -Report $report
        $parsed = $json | ConvertFrom-Json
        $parsed.expired.Count | Should -Be 1
        $parsed.ok.Count | Should -Be 1
    }

    It "Should include summary in JSON output" {
        $json = ConvertTo-RotationJson -Report $report
        $parsed = $json | ConvertFrom-Json
        $parsed.summary.totalSecrets | Should -Be 2
    }
}

Describe "Import-SecretsConfig" {
    BeforeAll {
        # Create a temporary JSON config file as a test fixture
        $tempFile = Join-Path $TestDrive "secrets-config.json"
        $configData = @{
            secrets = @(
                @{
                    name         = "database-password"
                    lastRotated  = "2026-01-01"
                    rotationDays = 90
                    requiredBy   = @("api-service", "background-worker")
                }
                @{
                    name         = "tls-certificate"
                    lastRotated  = "2026-03-15"
                    rotationDays = 365
                    requiredBy   = @("load-balancer")
                }
            )
        }
        $configData | ConvertTo-Json -Depth 5 | Set-Content $tempFile
    }

    It "Should load secrets from a JSON config file" {
        $secrets = Import-SecretsConfig -Path $tempFile
        $secrets.Count | Should -Be 2
    }

    It "Should parse secret names correctly" {
        $secrets = Import-SecretsConfig -Path $tempFile
        $secrets[0].Name | Should -Be "database-password"
    }

    It "Should parse dates as DateTime objects" {
        $secrets = Import-SecretsConfig -Path $tempFile
        $secrets[0].LastRotated | Should -BeOfType [datetime]
    }

    It "Should throw a meaningful error for a non-existent file" {
        { Import-SecretsConfig -Path "/nonexistent/path.json" } | Should -Throw "*not found*"
    }

    It "Should throw a meaningful error for invalid JSON" {
        $badFile = Join-Path $TestDrive "bad.json"
        "not valid json {{{" | Set-Content $badFile
        { Import-SecretsConfig -Path $badFile } | Should -Throw "*Failed to parse*"
    }
}

Describe "Format-RotationOutput" {
    # Integration-level test: end-to-end from secrets to formatted output
    BeforeAll {
        $referenceDate = [datetime]::Parse("2026-04-06")
        $secrets = @(
            @{ Name = "sec-1"; LastRotated = $referenceDate.AddDays(-100); RotationDays = 90; RequiredBy = @("a") }
            @{ Name = "sec-2"; LastRotated = $referenceDate.AddDays(-10);  RotationDays = 90; RequiredBy = @("b") }
        )
    }

    It "Should output markdown when format is 'markdown'" {
        $output = Format-RotationOutput -Secrets $secrets -Format "markdown" -ReferenceDate $referenceDate -WarningDays 14
        $output | Should -Match "# Secret Rotation Report"
    }

    It "Should output valid JSON when format is 'json'" {
        $output = Format-RotationOutput -Secrets $secrets -Format "json" -ReferenceDate $referenceDate -WarningDays 14
        { $output | ConvertFrom-Json } | Should -Not -Throw
    }

    It "Should throw for an unsupported format" {
        { Format-RotationOutput -Secrets $secrets -Format "xml" -ReferenceDate $referenceDate -WarningDays 14 } | Should -Throw "*Unsupported*"
    }
}

Describe "Edge Cases" {
    BeforeAll {
        $referenceDate = [datetime]::Parse("2026-04-06")
    }

    It "Should handle an empty secrets list gracefully" {
        $report = Get-RotationReport -Secrets @() -ReferenceDate $referenceDate -WarningDays 14
        $report.Summary.TotalSecrets | Should -Be 0
        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.OK.Count | Should -Be 0
    }

    It "Should handle a secret with a single required-by service" {
        $secret = @{
            Name         = "single-svc"
            LastRotated  = $referenceDate.AddDays(-50)
            RotationDays = 90
            RequiredBy   = @("only-one")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
        $result.RequiredBy | Should -HaveCount 1
    }

    It "Should handle zero-day rotation policy (always expired)" {
        $secret = @{
            Name         = "zero-policy"
            LastRotated  = $referenceDate
            RotationDays = 0
            RequiredBy   = @("svc")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningDays 14
        $result.Status | Should -Be "Expired"
    }
}
