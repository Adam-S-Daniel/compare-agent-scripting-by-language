# Test suite for Secret Rotation Validator
# Red/Green TDD: write failing tests first, then implement minimum code to pass

BeforeAll {
    # Import the main module
    . $PSScriptRoot/Invoke-SecretRotationValidator.ps1
}

Describe "Secret Rotation Validator" {

    Context "Get-SecretStatus function" {
        It "should return 'expired' for secrets past rotation date" {
            # Arrange
            $secret = @{
                Name = "db-password"
                LastRotated = (Get-Date).AddDays(-35)
                RotationPolicyDays = 30
                RequiredBy = @("api", "worker")
            }

            # Act
            $status = Get-SecretStatus -Secret $secret

            # Assert
            $status.Status | Should -Be "expired"
            $status.DaysOverdue | Should -Be 5
        }

        It "should return 'warning' for secrets expiring within warning window" {
            # Arrange
            $secret = @{
                Name = "api-key"
                LastRotated = (Get-Date).AddDays(-27)
                RotationPolicyDays = 30
                RequiredBy = @("web-service")
            }

            # Act
            $status = Get-SecretStatus -Secret $secret -WarningWindow 7

            # Assert
            $status.Status | Should -Be "warning"
            $status.DaysUntilExpiry | Should -Be 3
        }

        It "should return 'ok' for secrets with sufficient time before expiry" {
            # Arrange
            $secret = @{
                Name = "cache-key"
                LastRotated = (Get-Date).AddDays(-5)
                RotationPolicyDays = 30
                RequiredBy = @("cache-service")
            }

            # Act
            $status = Get-SecretStatus -Secret $secret

            # Assert
            $status.Status | Should -Be "ok"
            $status.DaysUntilExpiry | Should -Be 25
        }

        It "should support custom warning window" {
            # Arrange - 23 days since rotation, 30 day policy, 3 day warning = ok (23 < 27)
            $secret = @{
                Name = "test-secret"
                LastRotated = (Get-Date).AddDays(-23)
                RotationPolicyDays = 30
                RequiredBy = @("service")
            }

            # Act
            $status = Get-SecretStatus -Secret $secret -WarningWindow 3

            # Assert
            $status.Status | Should -Be "ok"
            $status.DaysUntilExpiry | Should -Be 7
        }
    }

    Context "Invoke-SecretRotationValidator main function" {
        It "should throw error when no secrets provided" {
            # Act & Assert
            { Invoke-SecretRotationValidator -Secrets @() } | Should -Throw "No secrets provided"
        }

        It "should process multiple secrets and categorize correctly" {
            # Arrange
            $secrets = @(
                @{
                    Name = "expired-secret"
                    LastRotated = (Get-Date).AddDays(-40)
                    RotationPolicyDays = 30
                    RequiredBy = @("app1")
                },
                @{
                    Name = "warning-secret"
                    LastRotated = (Get-Date).AddDays(-27)
                    RotationPolicyDays = 30
                    RequiredBy = @("app2")
                },
                @{
                    Name = "healthy-secret"
                    LastRotated = (Get-Date).AddDays(-10)
                    RotationPolicyDays = 30
                    RequiredBy = @("app3")
                }
            )

            # Act
            $result = Invoke-SecretRotationValidator -Secrets $secrets -WarningWindow 7 -OutputFormat json | ConvertFrom-Json

            # Assert
            $result.expired.Count | Should -Be 1
            $result.warning.Count | Should -Be 1
            $result.ok.Count | Should -Be 1
        }

        It "should return markdown formatted output by default" {
            # Arrange
            $secrets = @(
                @{
                    Name = "test-secret"
                    LastRotated = (Get-Date).AddDays(-15)
                    RotationPolicyDays = 30
                    RequiredBy = @("service")
                }
            )

            # Act
            $output = Invoke-SecretRotationValidator -Secrets $secrets

            # Assert
            $output | Should -Match "Healthy Secrets"
            $output | Should -Match "test-secret"
        }

        It "should return valid JSON when OutputFormat is json" {
            # Arrange
            $secrets = @(
                @{
                    Name = "json-test"
                    LastRotated = (Get-Date).AddDays(-5)
                    RotationPolicyDays = 30
                    RequiredBy = @("api")
                }
            )

            # Act
            $jsonOutput = Invoke-SecretRotationValidator -Secrets $secrets -OutputFormat json
            $parsed = $jsonOutput | ConvertFrom-Json

            # Assert
            $parsed | Should -Not -Be $null
            $parsed.ok | Should -Not -Be $null
            $parsed.ok[0].Name | Should -Be "json-test"
        }
    }

    Context "Format-SecretRotationReport function" {
        It "should format expired secrets in markdown" {
            # Arrange
            $results = @{
                expired = @(
                    @{
                        Name = "db-pass"
                        DaysOverdue = 10
                        RequiredBy = @("backend", "worker")
                        DaysSinceRotation = 40
                    }
                )
                warning = @()
                ok = @()
            }

            # Act
            $report = Format-SecretRotationReport -Results $results

            # Assert
            $report | Should -Match "Expired Secrets"
            $report | Should -Match "db-pass"
            $report | Should -Match "backend"
        }

        It "should handle multiple required-by services" {
            # Arrange
            $results = @{
                expired = @()
                warning = @(
                    @{
                        Name = "api-key"
                        DaysUntilExpiry = 3
                        RequiredBy = @("service1", "service2", "service3")
                        DaysSinceRotation = 27
                    }
                )
                ok = @()
            }

            # Act
            $report = Format-SecretRotationReport -Results $results

            # Assert
            $report | Should -Match "Warning - Expiring Soon"
            $report | Should -Match "service1.*service2.*service3"
        }

        It "should omit sections with no secrets" {
            # Arrange
            $results = @{
                expired = @()
                warning = @()
                ok = @(
                    @{
                        Name = "healthy"
                        DaysUntilExpiry = 20
                        RequiredBy = @("app")
                        DaysSinceRotation = 10
                    }
                )
            }

            # Act
            $report = Format-SecretRotationReport -Results $results

            # Assert
            $report | Should -Not -Match "Expired Secrets"
            $report | Should -Not -Match "Warning"
            $report | Should -Match "Healthy Secrets"
        }
    }
}
