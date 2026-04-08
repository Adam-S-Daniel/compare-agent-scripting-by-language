# Secret Rotation Validator - Pester Tests
# TDD approach: each Describe block was written as a failing test first,
# then the implementation was added to make it pass.

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe "Get-SecretStatus" {
    # Test fixture: mock secret configurations
    BeforeAll {
        $today = [datetime]::Parse("2026-04-08")
    }

    Context "when a secret is expired" {
        It "returns 'Expired' for a secret past its rotation date" {
            $secret = @{
                Name         = "db-password"
                LastRotated  = "2026-01-01"
                RotationDays = 30
                RequiredBy   = @("api-service", "worker")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
            $result.Urgency | Should -Be "Expired"
        }
    }

    Context "when a secret is within the warning window" {
        It "returns 'Warning' for a secret expiring within the warning window" {
            # Last rotated 25 days ago, rotation policy is 30 days => expires in 5 days
            $secret = @{
                Name         = "api-key"
                LastRotated  = "2026-03-14"
                RotationDays = 30
                RequiredBy   = @("frontend")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
            $result.Urgency | Should -Be "Warning"
        }
    }

    Context "when a secret is OK" {
        It "returns 'OK' for a secret not expiring soon" {
            # Last rotated 5 days ago, rotation policy is 90 days => expires in 85 days
            $secret = @{
                Name         = "tls-cert"
                LastRotated  = "2026-04-03"
                RotationDays = 90
                RequiredBy   = @("gateway")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
            $result.Urgency | Should -Be "OK"
        }
    }

    Context "result properties" {
        It "includes days until expiry and expiry date" {
            $secret = @{
                Name         = "api-key"
                LastRotated  = "2026-03-14"
                RotationDays = 30
                RequiredBy   = @("frontend")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
            $result.DaysUntilExpiry | Should -Be 5
            $result.ExpiryDate | Should -Be ([datetime]::Parse("2026-04-13"))
        }

        It "returns negative days for already-expired secrets" {
            $secret = @{
                Name         = "old-token"
                LastRotated  = "2025-12-01"
                RotationDays = 30
                RequiredBy   = @("batch-job")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
            $result.DaysUntilExpiry | Should -BeLessThan 0
        }
    }
}

Describe "Get-RotationReport" {
    BeforeAll {
        $today = [datetime]::Parse("2026-04-08")
        $secrets = @(
            @{ Name = "db-password";  LastRotated = "2026-01-01"; RotationDays = 30;  RequiredBy = @("api", "worker") }
            @{ Name = "api-key";      LastRotated = "2026-03-14"; RotationDays = 30;  RequiredBy = @("frontend") }
            @{ Name = "tls-cert";     LastRotated = "2026-04-03"; RotationDays = 90;  RequiredBy = @("gateway") }
            @{ Name = "ssh-key";      LastRotated = "2026-04-07"; RotationDays = 365; RequiredBy = @("deploy") }
        )
    }

    It "groups results by urgency" {
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $today -WarningDays 7
        $report.Expired.Count   | Should -Be 1
        $report.Warning.Count   | Should -Be 1
        $report.OK.Count        | Should -Be 2
    }

    It "includes summary counts" {
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $today -WarningDays 7
        $report.Summary.Total   | Should -Be 4
        $report.Summary.Expired | Should -Be 1
        $report.Summary.Warning | Should -Be 1
        $report.Summary.OK      | Should -Be 2
    }

    It "uses a configurable warning window" {
        # With a 10-day warning window, the api-key (6 days left) is still Warning
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $today -WarningDays 10
        $report.Warning.Count | Should -Be 1

        # With a 3-day warning window, the api-key (6 days left) becomes OK
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $today -WarningDays 3
        $report.Warning.Count | Should -Be 0
        $report.OK.Count      | Should -Be 3
    }
}

Describe "Format-RotationReport" {
    BeforeAll {
        $today = [datetime]::Parse("2026-04-08")
        $secrets = @(
            @{ Name = "db-password";  LastRotated = "2026-01-01"; RotationDays = 30;  RequiredBy = @("api", "worker") }
            @{ Name = "api-key";      LastRotated = "2026-03-14"; RotationDays = 30;  RequiredBy = @("frontend") }
            @{ Name = "tls-cert";     LastRotated = "2026-04-03"; RotationDays = 90;  RequiredBy = @("gateway") }
        )
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $today -WarningDays 7
    }

    Context "JSON output" {
        It "produces valid JSON" {
            $json = Format-RotationReport -Report $report -Format "JSON"
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It "contains all secrets in JSON output" {
            $json = Format-RotationReport -Report $report -Format "JSON"
            $parsed = $json | ConvertFrom-Json
            $parsed.secrets.Count | Should -Be 3
        }

        It "includes summary in JSON output" {
            $json = Format-RotationReport -Report $report -Format "JSON"
            $parsed = $json | ConvertFrom-Json
            $parsed.summary.total | Should -Be 3
        }
    }

    Context "Markdown output" {
        It "produces a markdown table with headers" {
            $md = Format-RotationReport -Report $report -Format "Markdown"
            $md | Should -Match "\| Name"
            $md | Should -Match "\| Urgency"
            $md | Should -Match "\|[-\s:]+"
        }

        It "includes all secrets in markdown output" {
            $md = Format-RotationReport -Report $report -Format "Markdown"
            $md | Should -Match "db-password"
            $md | Should -Match "api-key"
            $md | Should -Match "tls-cert"
        }

        It "includes a summary section" {
            $md = Format-RotationReport -Report $report -Format "Markdown"
            $md | Should -Match "Summary"
        }
    }
}

Describe "Import-SecretConfig" {
    It "loads secrets from a JSON file" {
        $tempFile = Join-Path $TestDrive "secrets.json"
        $config = @(
            @{ Name = "test-secret"; LastRotated = "2026-04-01"; RotationDays = 30; RequiredBy = @("svc1") }
        )
        ConvertTo-Json -InputObject $config -Depth 3 | Set-Content $tempFile

        $result = Import-SecretConfig -Path $tempFile
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "test-secret"
    }

    It "throws a meaningful error for a missing file" {
        { Import-SecretConfig -Path "/nonexistent/path.json" } | Should -Throw "*not found*"
    }

    It "throws a meaningful error for invalid JSON" {
        $tempFile = Join-Path $TestDrive "bad.json"
        "not valid json{{{" | Set-Content $tempFile
        { Import-SecretConfig -Path $tempFile } | Should -Throw "*parse*"
    }
}

Describe "Edge cases" {
    BeforeAll {
        $today = [datetime]::Parse("2026-04-08")
    }

    It "handles a secret expiring exactly today as Expired" {
        $secret = @{
            Name         = "today-secret"
            LastRotated  = "2026-03-09"
            RotationDays = 30
            RequiredBy   = @("svc")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
        $result.Urgency | Should -Be "Expired"
    }

    It "handles a secret expiring tomorrow as Warning (within 7-day window)" {
        $secret = @{
            Name         = "tomorrow-secret"
            LastRotated  = "2026-03-10"
            RotationDays = 30
            RequiredBy   = @("svc")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
        $result.Urgency | Should -Be "Warning"
        $result.DaysUntilExpiry | Should -Be 1
    }

    It "handles an empty secrets list" {
        $report = Get-RotationReport -Secrets @() -ReferenceDate $today -WarningDays 7
        $report.Summary.Total | Should -Be 0
    }

    It "handles a secret with multiple required-by services" {
        $secret = @{
            Name         = "shared-secret"
            LastRotated  = "2026-01-01"
            RotationDays = 30
            RequiredBy   = @("svc1", "svc2", "svc3")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $today -WarningDays 7
        $result.RequiredBy.Count | Should -Be 3
    }
}
