# SecretRotationValidator.Tests.ps1
# Pester test suite for the Secret Rotation Validator.
# TDD approach: tests were written before implementation.
# Run with: Invoke-Pester ./SecretRotationValidator.Tests.ps1 -Output Detailed

BeforeAll {
    # Dot-source the implementation so functions are available in tests
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe "Get-SecretRotationStatus" {
    Context "Secret classification - EXPIRED" {
        It "classifies a secret that exceeded its rotation policy as EXPIRED" {
            # DB_PASSWORD: last rotated 2024-01-01, policy 90 days, ref date 2024-06-01
            # Days since rotation: 152 days -> EXPIRED (152 >= 90)
            $secrets = @(
                @{
                    Name               = "DB_PASSWORD"
                    LastRotated        = "2024-01-01"
                    RotationPolicyDays = 90
                    RequiredBy         = @("api-service", "web-frontend")
                }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Expired | Should -HaveCount 1
            $result.Expired[0].Name | Should -Be "DB_PASSWORD"
            $result.Expired[0].Status | Should -Be "EXPIRED"
            $result.Warning | Should -HaveCount 0
            $result.Ok      | Should -HaveCount 0
        }

        It "classifies a secret exactly at the expiry boundary as EXPIRED" {
            # Exactly 90 days since rotation with 90-day policy -> EXPIRED
            $secrets = @(
                @{
                    Name               = "BOUNDARY_SECRET"
                    LastRotated        = "2024-03-03"
                    RotationPolicyDays = 90
                    RequiredBy         = @("service-a")
                }
            )
            # 2024-03-03 + 90 days = 2024-06-01 -> exactly expired
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Expired | Should -HaveCount 1
            $result.Expired[0].Name | Should -Be "BOUNDARY_SECRET"
        }
    }

    Context "Secret classification - WARNING" {
        It "classifies a secret expiring within the warning window as WARNING" {
            # API_KEY: last rotated 2024-04-20, policy 60 days, ref date 2024-06-01
            # Days since: 42 days. Days until expiry: 18 days -> WARNING (18 <= 30)
            $secrets = @(
                @{
                    Name               = "API_KEY"
                    LastRotated        = "2024-04-20"
                    RotationPolicyDays = 60
                    RequiredBy         = @("external-api")
                }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Warning | Should -HaveCount 1
            $result.Warning[0].Name | Should -Be "API_KEY"
            $result.Warning[0].Status | Should -Be "WARNING"
            $result.Expired | Should -HaveCount 0
            $result.Ok      | Should -HaveCount 0
        }

        It "classifies a secret exactly at the warning boundary as WARNING" {
            # Exactly 30 days until expiry with 30-day warning window -> WARNING
            $secrets = @(
                @{
                    Name               = "EDGE_SECRET"
                    LastRotated        = "2024-03-03"
                    RotationPolicyDays = 90
                    RequiredBy         = @("service-b")
                }
            )
            # Ref: 2024-06-01, last rotated 2024-03-03 = 90 days ago
            # Days until expiry: 90 - 90 = 0 -> actually expired. Let me pick a different date.
            # EDGE_SECRET: last rotated 2024-04-02, policy 90 days, ref 2024-06-01
            # Days since: 60 days. Days until expiry: 30 days -> exactly at warning boundary (30 <= 30) -> WARNING
            $secrets = @(
                @{
                    Name               = "EDGE_SECRET"
                    LastRotated        = "2024-04-02"
                    RotationPolicyDays = 90
                    RequiredBy         = @("service-b")
                }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Warning | Should -HaveCount 1
            $result.Warning[0].Name | Should -Be "EDGE_SECRET"
        }
    }

    Context "Secret classification - OK" {
        It "classifies a recently rotated secret as OK" {
            # JWT_SECRET: last rotated 2024-05-15, policy 90 days, ref date 2024-06-01
            # Days since: 17 days. Days until expiry: 73 days -> OK (73 > 30)
            $secrets = @(
                @{
                    Name               = "JWT_SECRET"
                    LastRotated        = "2024-05-15"
                    RotationPolicyDays = 90
                    RequiredBy         = @("auth-service")
                }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Ok | Should -HaveCount 1
            $result.Ok[0].Name | Should -Be "JWT_SECRET"
            $result.Ok[0].Status | Should -Be "OK"
            $result.Expired | Should -HaveCount 0
            $result.Warning | Should -HaveCount 0
        }
    }

    Context "Multiple secrets classified together" {
        It "correctly classifies a mixed set of secrets" {
            $secrets = @(
                @{ Name = "DB_PASSWORD";  LastRotated = "2024-01-01"; RotationPolicyDays = 90; RequiredBy = @("api-service") }
                @{ Name = "API_KEY";      LastRotated = "2024-04-20"; RotationPolicyDays = 60; RequiredBy = @("external-api") }
                @{ Name = "JWT_SECRET";   LastRotated = "2024-05-15"; RotationPolicyDays = 90; RequiredBy = @("auth-service") }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Expired | Should -HaveCount 1
            $result.Warning | Should -HaveCount 1
            $result.Ok      | Should -HaveCount 1
            $result.Expired[0].Name | Should -Be "DB_PASSWORD"
            $result.Warning[0].Name | Should -Be "API_KEY"
            $result.Ok[0].Name      | Should -Be "JWT_SECRET"
        }

        It "includes DaysSinceRotation and DaysUntilExpiry in results" {
            $secrets = @(
                @{ Name = "DB_PASSWORD"; LastRotated = "2024-01-01"; RotationPolicyDays = 90; RequiredBy = @("api") }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
            $result.Expired[0].DaysSinceRotation | Should -Be 152
            $result.Expired[0].DaysUntilExpiry   | Should -Be -62
        }
    }

    Context "Custom warning window" {
        It "respects a custom warning window" {
            # API_KEY: 18 days until expiry. With 15-day window -> OK (not warning)
            $secrets = @(
                @{ Name = "API_KEY"; LastRotated = "2024-04-20"; RotationPolicyDays = 60; RequiredBy = @("api") }
            )
            $result = Get-SecretRotationStatus -Secrets $secrets -ReferenceDate "2024-06-01" -WarningWindowDays 15
            $result.Ok      | Should -HaveCount 1
            $result.Warning | Should -HaveCount 0
        }
    }
}

Describe "Format-RotationReport" {
    BeforeAll {
        # Build a standard status object for formatting tests
        $script:secrets = @(
            @{ Name = "DB_PASSWORD"; LastRotated = "2024-01-01"; RotationPolicyDays = 90; RequiredBy = @("api-service", "web-frontend") }
            @{ Name = "API_KEY";     LastRotated = "2024-04-20"; RotationPolicyDays = 60; RequiredBy = @("external-api") }
            @{ Name = "JWT_SECRET";  LastRotated = "2024-05-15"; RotationPolicyDays = 90; RequiredBy = @("auth-service") }
        )
        $script:status = Get-SecretRotationStatus -Secrets $script:secrets -ReferenceDate "2024-06-01" -WarningWindowDays 30
    }

    Context "JSON output format" {
        It "generates valid JSON" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "JSON"
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "JSON contains expired, warning, and ok arrays" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "JSON"
            $parsed = $output | ConvertFrom-Json
            $parsed.Expired | Should -HaveCount 1
            $parsed.Warning | Should -HaveCount 1
            $parsed.Ok      | Should -HaveCount 1
        }

        It "JSON expired entry has correct secret name" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "JSON"
            $parsed = $output | ConvertFrom-Json
            $parsed.Expired[0].Name | Should -Be "DB_PASSWORD"
        }

        It "JSON warning entry has correct secret name" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "JSON"
            $parsed = $output | ConvertFrom-Json
            $parsed.Warning[0].Name | Should -Be "API_KEY"
        }

        It "JSON ok entry has correct secret name" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "JSON"
            $parsed = $output | ConvertFrom-Json
            $parsed.Ok[0].Name | Should -Be "JWT_SECRET"
        }
    }

    Context "Markdown output format" {
        It "generates a markdown table containing pipe characters" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "Markdown"
            $output | Should -Match "\|"
        }

        It "markdown contains the expired secret name" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "Markdown"
            $output | Should -Match "DB_PASSWORD"
        }

        It "markdown contains the EXPIRED status label" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "Markdown"
            $output | Should -Match "EXPIRED"
        }

        It "markdown contains the WARNING section" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "Markdown"
            $output | Should -Match "WARNING"
            $output | Should -Match "API_KEY"
        }

        It "markdown contains a report header" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "Markdown"
            $output | Should -Match "# Secret Rotation Report"
        }

        It "markdown contains the reference date" {
            $output = Format-RotationReport -Status $script:status -OutputFormat "Markdown"
            $output | Should -Match "2024-06-01"
        }
    }
}

Describe "Invoke-SecretRotationValidator" {
    Context "Loading from config file" {
        It "loads secrets from a JSON config file and returns JSON output" {
            $configPath = "$PSScriptRoot/fixtures/secrets-standard.json"
            $output = Invoke-SecretRotationValidator -ConfigPath $configPath -ReferenceDate "2024-06-01" -WarningWindowDays 30 -OutputFormat "JSON"
            $parsed = $output | ConvertFrom-Json
            $parsed.Expired | Should -HaveCount 1
            $parsed.Warning | Should -HaveCount 1
            $parsed.Ok      | Should -HaveCount 1
            $parsed.Expired[0].Name | Should -Be "DB_PASSWORD"
            $parsed.Warning[0].Name | Should -Be "API_KEY"
            $parsed.Ok[0].Name      | Should -Be "JWT_SECRET"
        }

        It "loads secrets and returns Markdown output" {
            $configPath = "$PSScriptRoot/fixtures/secrets-standard.json"
            $output = Invoke-SecretRotationValidator -ConfigPath $configPath -ReferenceDate "2024-06-01" -WarningWindowDays 30 -OutputFormat "Markdown"
            $output | Should -Match "DB_PASSWORD"
            $output | Should -Match "EXPIRED"
        }

        It "throws a meaningful error when config file does not exist" {
            { Invoke-SecretRotationValidator -ConfigPath "./nonexistent.json" } | Should -Throw "*not found*"
        }
    }
}

Describe "Workflow Structure Tests" {
    BeforeAll {
        $script:workflowPath = "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml"
        $script:workflowContent = Get-Content $script:workflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow file exists at expected path" {
        Test-Path $script:workflowPath | Should -Be $true
    }

    It "workflow has a push trigger" {
        $script:workflowContent | Should -Match "push"
    }

    It "workflow has a workflow_dispatch trigger" {
        $script:workflowContent | Should -Match "workflow_dispatch"
    }

    It "workflow has at least one job" {
        $script:workflowContent | Should -Match "jobs:"
    }

    It "workflow uses actions/checkout" {
        $script:workflowContent | Should -Match "actions/checkout"
    }

    It "workflow uses shell: pwsh for run steps" {
        $script:workflowContent | Should -Match "shell: pwsh"
    }

    It "workflow references the main script file" {
        $script:workflowContent | Should -Match "SecretRotationValidator.ps1"
    }

    It "workflow references the fixtures directory" {
        $script:workflowContent | Should -Match "fixtures"
    }

    It "main script file exists" {
        Test-Path "$PSScriptRoot/SecretRotationValidator.ps1" | Should -Be $true
    }

    It "fixtures directory exists" {
        Test-Path "$PSScriptRoot/fixtures" | Should -Be $true
    }

    It "standard fixture file exists" {
        Test-Path "$PSScriptRoot/fixtures/secrets-standard.json" | Should -Be $true
    }

    It "actionlint passes on the workflow file" {
        # Skip gracefully inside Docker containers where actionlint is not installed
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not installed in this environment"
            return
        }
        $lintOutput = & actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $lintOutput"
    }
}
