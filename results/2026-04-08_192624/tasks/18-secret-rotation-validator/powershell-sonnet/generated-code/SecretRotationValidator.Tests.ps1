#Requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

# TDD Approach: Tests written FIRST (red), then implementation (green), then refactor.
# Each Describe block represents one TDD cycle.

BeforeAll {
    # Import the module directly (avoids CmdletBinding param-set conflicts
    # that arise when dot-sourcing a script with its own param() block).
    Import-Module -Name "$PSScriptRoot/SecretRotationValidator.psm1" -Force

    # Fixed reference date for deterministic testing (2026-04-09)
    $script:AsOf = [DateTime]"2026-04-09"
}

# ============================================================
# TDD Round 1: Get-SecretDaysUntilExpiry
# Tests written BEFORE the function exists (red phase)
# ============================================================
Describe "Get-SecretDaysUntilExpiry" {
    It "returns negative value for an expired secret" {
        # Policy: 90 days. Last rotated 2025-12-01. Expiry: 2026-03-01.
        # Days from 2026-03-01 to 2026-04-09 = 39 days over expiry => -39
        $result = Get-SecretDaysUntilExpiry `
            -LastRotated ([DateTime]"2025-12-01") `
            -RotationPolicyDays 90 `
            -AsOf $script:AsOf
        $result | Should -Be -39
    }

    It "returns positive value for a secret expiring in the future" {
        # Policy: 90 days. Last rotated 2026-01-29. Expiry: 2026-04-29.
        # Days from 2026-04-09 to 2026-04-29 = 20 days remaining
        $result = Get-SecretDaysUntilExpiry `
            -LastRotated ([DateTime]"2026-01-29") `
            -RotationPolicyDays 90 `
            -AsOf $script:AsOf
        $result | Should -Be 20
    }

    It "returns a large positive value for a recently rotated secret" {
        # Policy: 90 days. Last rotated 2026-03-10. Expiry: 2026-06-08.
        # Days from 2026-04-09 to 2026-06-08 = 60 days remaining
        $result = Get-SecretDaysUntilExpiry `
            -LastRotated ([DateTime]"2026-03-10") `
            -RotationPolicyDays 90 `
            -AsOf $script:AsOf
        $result | Should -Be 60
    }

    It "returns 0 when the secret expires exactly today" {
        # Expired exactly on AsOf date
        $lastRotated = $script:AsOf.AddDays(-90)
        $result = Get-SecretDaysUntilExpiry `
            -LastRotated $lastRotated `
            -RotationPolicyDays 90 `
            -AsOf $script:AsOf
        $result | Should -Be 0
    }

    It "uses current date as default AsOf when not specified" {
        $lastRotated = (Get-Date).AddDays(-50)
        $result = Get-SecretDaysUntilExpiry -LastRotated $lastRotated -RotationPolicyDays 90
        # Should be approximately 40 days (90 - 50). Use -BeGreaterOrEqual/-BeLessOrEqual
        # because Pester 5.7 does not have -BeInRange.
        $result | Should -BeGreaterOrEqual 39
        $result | Should -BeLessOrEqual 41
    }
}

# ============================================================
# TDD Round 2: Get-SecretUrgency
# ============================================================
Describe "Get-SecretUrgency" {
    It "returns 'expired' when days until expiry is negative" {
        $result = Get-SecretUrgency -DaysUntilExpiry -39 -WarningWindowDays 30
        $result | Should -Be "expired"
    }

    It "returns 'expired' when days until expiry is zero" {
        $result = Get-SecretUrgency -DaysUntilExpiry 0 -WarningWindowDays 30
        $result | Should -Be "expired"
    }

    It "returns 'warning' when days until expiry is within the warning window" {
        $result = Get-SecretUrgency -DaysUntilExpiry 20 -WarningWindowDays 30
        $result | Should -Be "warning"
    }

    It "returns 'warning' when days until expiry equals the warning window boundary" {
        $result = Get-SecretUrgency -DaysUntilExpiry 30 -WarningWindowDays 30
        $result | Should -Be "warning"
    }

    It "returns 'ok' when days until expiry exceeds the warning window" {
        $result = Get-SecretUrgency -DaysUntilExpiry 60 -WarningWindowDays 30
        $result | Should -Be "ok"
    }

    It "uses default warning window of 30 days when not specified" {
        $result = Get-SecretUrgency -DaysUntilExpiry 25
        $result | Should -Be "warning"
    }
}

# ============================================================
# TDD Round 3: Get-SecretRotationReport
# ============================================================
Describe "Get-SecretRotationReport" {
    BeforeAll {
        # Fixture: mixed urgency secrets
        $script:MixedSecrets = @(
            [PSCustomObject]@{
                Name               = "DB_PASSWORD"
                LastRotated        = [DateTime]"2025-12-01"
                RotationPolicyDays = 90
                RequiredByServices = @("api", "database")
            },
            [PSCustomObject]@{
                Name               = "API_KEY"
                LastRotated        = [DateTime]"2026-01-29"
                RotationPolicyDays = 90
                RequiredByServices = @("frontend", "mobile")
            },
            [PSCustomObject]@{
                Name               = "JWT_SECRET"
                LastRotated        = [DateTime]"2026-03-10"
                RotationPolicyDays = 90
                RequiredByServices = @("auth-service")
            }
        )
    }

    It "groups secrets by urgency: expired, warning, ok" {
        $report = Get-SecretRotationReport `
            -Secrets $script:MixedSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.expired | Should -HaveCount 1
        $report.warning | Should -HaveCount 1
        $report.ok | Should -HaveCount 1
    }

    It "puts DB_PASSWORD (expired) in the expired group" {
        $report = Get-SecretRotationReport `
            -Secrets $script:MixedSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.expired[0].Name | Should -Be "DB_PASSWORD"
        $report.expired[0].DaysUntilExpiry | Should -Be -39
    }

    It "puts API_KEY (warning) in the warning group with correct days" {
        $report = Get-SecretRotationReport `
            -Secrets $script:MixedSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.warning[0].Name | Should -Be "API_KEY"
        $report.warning[0].DaysUntilExpiry | Should -Be 20
    }

    It "puts JWT_SECRET (ok) in the ok group with correct days" {
        $report = Get-SecretRotationReport `
            -Secrets $script:MixedSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.ok[0].Name | Should -Be "JWT_SECRET"
        $report.ok[0].DaysUntilExpiry | Should -Be 60
    }

    It "preserves RequiredByServices in each enriched secret" {
        $report = Get-SecretRotationReport `
            -Secrets $script:MixedSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.expired[0].RequiredByServices | Should -Contain "api"
        $report.expired[0].RequiredByServices | Should -Contain "database"
    }

    It "includes summary counts in the report" {
        $report = Get-SecretRotationReport `
            -Secrets $script:MixedSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.summary.expired | Should -Be 1
        $report.summary.warning | Should -Be 1
        $report.summary.ok | Should -Be 1
    }

    It "returns empty groups when all secrets are ok" {
        $allOkSecrets = @(
            [PSCustomObject]@{
                Name               = "NEW_SECRET"
                LastRotated        = [DateTime]"2026-03-15"
                RotationPolicyDays = 90
                RequiredByServices = @("service1")
            }
        )
        $report = Get-SecretRotationReport `
            -Secrets $allOkSecrets `
            -WarningWindowDays 30 `
            -AsOf $script:AsOf

        $report.expired | Should -HaveCount 0
        $report.warning | Should -HaveCount 0
        $report.ok | Should -HaveCount 1
    }
}

# ============================================================
# TDD Round 4: Format-RotationReportMarkdown
# ============================================================
Describe "Format-RotationReportMarkdown" {
    BeforeAll {
        # Build a sample report for formatting tests
        $secrets = @(
            [PSCustomObject]@{
                Name               = "DB_PASSWORD"
                LastRotated        = [DateTime]"2025-12-01"
                RotationPolicyDays = 90
                RequiredByServices = @("api", "database")
            },
            [PSCustomObject]@{
                Name               = "API_KEY"
                LastRotated        = [DateTime]"2026-01-29"
                RotationPolicyDays = 90
                RequiredByServices = @("frontend")
            },
            [PSCustomObject]@{
                Name               = "JWT_SECRET"
                LastRotated        = [DateTime]"2026-03-10"
                RotationPolicyDays = 90
                RequiredByServices = @("auth-service")
            }
        )
        $script:SampleReport = Get-SecretRotationReport `
            -Secrets $secrets -WarningWindowDays 30 -AsOf $script:AsOf
    }

    It "contains a main title" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "# Secret Rotation Report"
    }

    It "has an Expired Secrets section" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "Expired Secrets"
    }

    It "has a Warning section" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "Warning"
    }

    It "has an OK section" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "OK"
    }

    It "lists expired secret DB_PASSWORD in the table" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "DB_PASSWORD"
    }

    It "lists warning secret API_KEY in the table" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "API_KEY"
    }

    It "includes table pipe characters for markdown tables" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "\|"
    }

    It "shows correct days until expiry for expired secret (-39)" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "\-39"
    }

    It "shows correct days until expiry for warning secret (20)" {
        $md = Format-RotationReportMarkdown -Report $script:SampleReport
        $md | Should -Match "\b20\b"
    }
}

# ============================================================
# TDD Round 5: Format-RotationReportJson
# ============================================================
Describe "Format-RotationReportJson" {
    BeforeAll {
        $secrets = @(
            [PSCustomObject]@{
                Name               = "DB_PASSWORD"
                LastRotated        = [DateTime]"2025-12-01"
                RotationPolicyDays = 90
                RequiredByServices = @("api", "database")
            },
            [PSCustomObject]@{
                Name               = "API_KEY"
                LastRotated        = [DateTime]"2026-01-29"
                RotationPolicyDays = 90
                RequiredByServices = @("frontend")
            }
        )
        $script:SmallReport = Get-SecretRotationReport `
            -Secrets $secrets -WarningWindowDays 30 -AsOf $script:AsOf
    }

    It "produces valid JSON that can be parsed" {
        $json = Format-RotationReportJson -Report $script:SmallReport
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It "includes summary with correct counts" {
        $json = Format-RotationReportJson -Report $script:SmallReport
        $parsed = $json | ConvertFrom-Json
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok | Should -Be 0
    }

    It "includes expired secrets array with DB_PASSWORD" {
        $json = Format-RotationReportJson -Report $script:SmallReport
        $parsed = $json | ConvertFrom-Json
        $parsed.expired | Should -HaveCount 1
        $parsed.expired[0].Name | Should -Be "DB_PASSWORD"
    }

    It "includes warning secrets array with API_KEY" {
        $json = Format-RotationReportJson -Report $script:SmallReport
        $parsed = $json | ConvertFrom-Json
        $parsed.warning | Should -HaveCount 1
        $parsed.warning[0].Name | Should -Be "API_KEY"
    }

    It "includes generatedAt timestamp field" {
        $json = Format-RotationReportJson -Report $script:SmallReport
        $parsed = $json | ConvertFrom-Json
        $parsed.generatedAt | Should -Not -BeNullOrEmpty
    }

    It "includes DaysUntilExpiry field with exact value for expired secret" {
        $json = Format-RotationReportJson -Report $script:SmallReport
        $parsed = $json | ConvertFrom-Json
        $parsed.expired[0].DaysUntilExpiry | Should -Be -39
    }
}

# ============================================================
# TDD Round 6: Read-SecretsConfig (load from JSON file)
# ============================================================
Describe "Read-SecretsConfig" {
    BeforeAll {
        # Create a temporary config file for testing
        $script:TempConfigFile = Join-Path $TestDrive "test-secrets.json"
        $configContent = @{
            warningWindowDays = 30
            asOf              = "2026-04-09"
            secrets           = @(
                @{
                    name               = "TEST_SECRET"
                    lastRotated        = "2025-12-01"
                    rotationPolicyDays = 90
                    requiredByServices = @("test-service")
                }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -Path $script:TempConfigFile -Value $configContent
    }

    It "reads and parses a valid JSON config file" {
        $config = Read-SecretsConfig -ConfigFile $script:TempConfigFile
        $config | Should -Not -BeNullOrEmpty
        $config.secrets | Should -HaveCount 1
    }

    It "returns warningWindowDays from config" {
        $config = Read-SecretsConfig -ConfigFile $script:TempConfigFile
        $config.warningWindowDays | Should -Be 30
    }

    It "returns asOf date from config" {
        $config = Read-SecretsConfig -ConfigFile $script:TempConfigFile
        $config.asOf | Should -Be "2026-04-09"
    }

    It "parses secret name correctly" {
        $config = Read-SecretsConfig -ConfigFile $script:TempConfigFile
        $config.secrets[0].name | Should -Be "TEST_SECRET"
    }

    It "throws a meaningful error for missing file" {
        { Read-SecretsConfig -ConfigFile "/nonexistent/path/secrets.json" } |
            Should -Throw "*not found*"
    }

    It "throws a meaningful error for invalid JSON" {
        $badFile = Join-Path $TestDrive "bad.json"
        Set-Content -Path $badFile -Value "{ not valid json"
        { Read-SecretsConfig -ConfigFile $badFile } | Should -Throw
    }
}
