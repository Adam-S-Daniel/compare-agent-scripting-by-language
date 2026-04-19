BeforeAll {
    # Import the module under test
    . $PSScriptRoot/SecretRotationValidator.ps1
}

Describe "SecretRotationValidator" {
    Context "Test Suite 1: Initialize Validator" {
        It "Should create a new validator instance" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $validator | Should -Not -BeNullOrEmpty
            $validator.WarningDays | Should -Be 7
        }
    }

    Context "Test Suite 2: Load and Parse Secrets" {
        It "Should load secrets from JSON configuration" {
            $configPath = Join-Path $PSScriptRoot "test-secrets.json"
            $secrets = Import-SecretsFromJson -ConfigPath $configPath
            $secrets | Should -Not -BeNullOrEmpty
            $secrets | Should -HaveCount 3
        }

        It "Should parse secret metadata correctly" {
            $secret = @{
                Name = "db-password"
                LastRotated = "2026-03-01"
                RotationPolicyDays = 30
                RequiredByServices = @("app-server", "api-gateway")
            }
            $secret.Name | Should -Be "db-password"
            $secret.RotationPolicyDays | Should -Be 30
        }
    }

    Context "Test Suite 3: Calculate Secret Status" {
        It "Should identify expired secrets" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secret = @{
                Name = "old-secret"
                LastRotated = (Get-Date).AddDays(-35).ToString("yyyy-MM-dd")
                RotationPolicyDays = 30
            }
            $status = Get-SecretStatus -Validator $validator -Secret $secret
            $status.Status | Should -Be "Expired"
        }

        It "Should identify secrets in warning window" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secret = @{
                Name = "aging-secret"
                LastRotated = (Get-Date).AddDays(-28).ToString("yyyy-MM-dd")
                RotationPolicyDays = 30
            }
            $status = Get-SecretStatus -Validator $validator -Secret $secret
            $status.Status | Should -Be "Warning"
        }

        It "Should identify healthy secrets" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secret = @{
                Name = "new-secret"
                LastRotated = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd")
                RotationPolicyDays = 30
            }
            $status = Get-SecretStatus -Validator $validator -Secret $secret
            $status.Status | Should -Be "OK"
        }
    }

    Context "Test Suite 4: Generate Report" {
        It "Should generate a rotation report" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secrets = @(
                @{ Name = "expired"; LastRotated = (Get-Date).AddDays(-35).ToString("yyyy-MM-dd"); RotationPolicyDays = 30; RequiredByServices = @("app") },
                @{ Name = "warning"; LastRotated = (Get-Date).AddDays(-28).ToString("yyyy-MM-dd"); RotationPolicyDays = 30; RequiredByServices = @("api") },
                @{ Name = "ok"; LastRotated = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd"); RotationPolicyDays = 30; RequiredByServices = @("db") }
            )
            $report = New-RotationReport -Validator $validator -Secrets $secrets
            $report | Should -Not -BeNullOrEmpty
            $report.Expired | Should -HaveCount 1
            $report.Warning | Should -HaveCount 1
            $report.OK | Should -HaveCount 1
        }
    }

    Context "Test Suite 5: Format Output" {
        It "Should format report as markdown table" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secrets = @(
                @{ Name = "secret1"; LastRotated = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd"); RotationPolicyDays = 30; RequiredByServices = @("app") }
            )
            $report = New-RotationReport -Validator $validator -Secrets $secrets
            $markdown = Format-RotationReportAsMarkdown -Report $report
            $markdown | Should -Match "Name"
            $markdown | Should -Match "Status"
            $markdown | Should -Match "secret1"
        }

        It "Should format report as JSON" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secrets = @(
                @{ Name = "secret1"; LastRotated = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd"); RotationPolicyDays = 30; RequiredByServices = @("app") }
            )
            $report = New-RotationReport -Validator $validator -Secrets $secrets
            $json = Format-RotationReportAsJson -Report $report
            $json | Should -Match "ReportDate"
            $json | Should -Match "Summary"
            $json | Should -Match "secret1"
        }
    }

    Context "Test Suite 6: Edge Cases" {
        It "Should handle empty services list" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secret = @{
                Name = "orphan-secret"
                LastRotated = (Get-Date).AddDays(-5).ToString("yyyy-MM-dd")
                RotationPolicyDays = 30
                RequiredByServices = @()
            }
            $status = Get-SecretStatus -Validator $validator -Secret $secret
            $status.Services | Should -Be ""
            $status.Status | Should -Be "OK"
        }

        It "Should handle very short rotation policies" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secret = @{
                Name = "short-policy"
                LastRotated = (Get-Date).AddDays(-6).ToString("yyyy-MM-dd")
                RotationPolicyDays = 7
                RequiredByServices = @("test")
            }
            $status = Get-SecretStatus -Validator $validator -Secret $secret
            $status.Status | Should -Be "Warning"
        }

        It "Should handle long rotation policies" {
            $validator = New-SecretRotationValidator -WarningDays 7
            $secret = @{
                Name = "long-policy"
                LastRotated = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
                RotationPolicyDays = 365
                RequiredByServices = @("test")
            }
            $status = Get-SecretStatus -Validator $validator -Secret $secret
            $status.Status | Should -Be "OK"
            $status.DaysUntilExpiry | Should -Be 335
        }
    }
}
