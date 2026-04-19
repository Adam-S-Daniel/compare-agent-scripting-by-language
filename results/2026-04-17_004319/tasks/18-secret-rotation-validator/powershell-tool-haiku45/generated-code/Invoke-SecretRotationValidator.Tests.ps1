BeforeAll {
    . $PSScriptRoot/Invoke-SecretRotationValidator.ps1
}

Describe "Invoke-SecretRotationValidator" {
    Context "Parsing secret configuration" {
        It "should parse a valid secret configuration object" {
            $secretConfig = @{
                name = "api-key-prod"
                lastRotated = "2026-04-01"
                rotationPolicyDays = 30
                requiredByServices = @("api", "scheduler")
            }

            $secretConfig.name | Should -Be "api-key-prod"
            $secretConfig.rotationPolicyDays | Should -Be 30
        }
    }

    Context "Secret expiration status" {
        BeforeEach {
            $referenceDate = [datetime]::ParseExact("2026-04-19", "yyyy-MM-dd", $null)
            $warningWindow = 7
        }

        It "should mark secret as expired when rotation date has passed" {
            $secret = @{
                name = "expired-key"
                lastRotated = "2026-02-15"
                rotationPolicyDays = 30
                requiredByServices = @("service1")
            }

            $status = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningWindow $warningWindow
            $status | Should -Be "expired"
        }

        It "should mark secret as warning when expiration is within warning window" {
            $secret = @{
                name = "warning-key"
                lastRotated = "2026-04-15"
                rotationPolicyDays = 7
                requiredByServices = @("service1")
            }

            $status = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningWindow $warningWindow
            $status | Should -Be "warning"
        }

        It "should mark secret as ok when expiration is outside warning window" {
            $secret = @{
                name = "ok-key"
                lastRotated = "2026-04-01"
                rotationPolicyDays = 30
                requiredByServices = @("service1")
            }

            $status = Get-SecretStatus -Secret $secret -ReferenceDate $referenceDate -WarningWindow $warningWindow
            $status | Should -Be "ok"
        }
    }

    Context "Rotation report generation" {
        It "should generate report grouped by urgency" {
            $secrets = @(
                @{
                    name = "expired"
                    lastRotated = "2026-02-10"
                    rotationPolicyDays = 30
                    requiredByServices = @("api")
                },
                @{
                    name = "warning"
                    lastRotated = "2026-04-15"
                    rotationPolicyDays = 7
                    requiredByServices = @("worker")
                },
                @{
                    name = "ok"
                    lastRotated = "2026-04-01"
                    rotationPolicyDays = 45
                    requiredByServices = @("scheduler")
                }
            )

            $referenceDate = [datetime]::ParseExact("2026-04-19", "yyyy-MM-dd", $null)
            $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningWindow 7

            $report.expired.Count | Should -Be 1
            $report.warning.Count | Should -Be 1
            $report.ok.Count | Should -Be 1
            $report.expired[0].name | Should -Be "expired"
        }

        It "should calculate correct days until expiration" {
            $secrets = @(
                @{
                    name = "test-key"
                    lastRotated = "2026-04-12"
                    rotationPolicyDays = 10
                    requiredByServices = @("api")
                }
            )

            $referenceDate = [datetime]::ParseExact("2026-04-19", "yyyy-MM-dd", $null)
            $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningWindow 7

            $report.warning[0].daysUntilExpiration | Should -Be 3
        }
    }

    Context "Markdown report formatting" {
        It "should generate valid markdown table" {
            $secrets = @(
                @{
                    name = "api-key"
                    lastRotated = "2026-04-01"
                    rotationPolicyDays = 30
                    requiredByServices = @("api", "worker")
                }
            )

            $referenceDate = [datetime]::ParseExact("2026-04-19", "yyyy-MM-dd", $null)
            $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningWindow 7
            $markdown = Get-MarkdownReport -Report $report

            $markdown | Should -Match "# Secret Rotation Report"
            $markdown | Should -Match "## Ok"
            $markdown | Should -Match "api-key"
            $markdown | Should -Match "api, worker"
        }
    }

    Context "JSON report formatting" {
        It "should generate valid JSON output" {
            $secrets = @(
                @{
                    name = "secret1"
                    lastRotated = "2026-04-01"
                    rotationPolicyDays = 30
                    requiredByServices = @("svc1")
                }
            )

            $referenceDate = [datetime]::ParseExact("2026-04-19", "yyyy-MM-dd", $null)
            $report = Get-RotationReport -Secrets $secrets -ReferenceDate $referenceDate -WarningWindow 7
            $json = Get-JsonReport -Report $report

            $parsed = $json | ConvertFrom-Json
            $parsed.ok.Count | Should -Be 1
            $parsed.ok[0].name | Should -Be "secret1"
        }
    }
}
