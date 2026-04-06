Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Secret Rotation Validator - Pester Tests
# =============================================================================
# Tests follow TDD methodology: each Describe block represents a cycle where
# a failing test was written first, then the minimum code to pass, then refactored.
#
# Test structure:
#   Cycle 1: Get-SecretStatus — classify a single secret's urgency
#   Cycle 2: Import-SecretConfig — parse secret configuration from JSON
#   Cycle 3: Get-RotationReport — full report with grouping
#   Cycle 4: ConvertTo-RotationMarkdown — markdown table output
#   Cycle 5: ConvertTo-RotationJson — JSON output
#   Cycle 6: Error handling — graceful failures with meaningful messages
# =============================================================================

BeforeAll {
    Import-Module "$PSScriptRoot/SecretRotationValidator.psm1" -Force
}

# =============================================================================
# TDD Cycle 1: Get-SecretStatus
# RED:   Tests written first; Get-SecretStatus did not exist.
# GREEN: Implemented date arithmetic and classification logic.
# REFACTOR: Extracted expiry calculation into clean local variables.
# =============================================================================
Describe 'Get-SecretStatus' {
    # Fixed reference date for deterministic tests
    BeforeAll {
        [datetime]$script:refDate = [datetime]'2026-04-06'
    }

    Context 'When a secret has exceeded its rotation policy' {
        It 'Should return Expired status' {
            # Secret rotated 100 days ago with 90-day policy => 10 days overdue
            [datetime]$lastRotated = $script:refDate.AddDays(-100)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'Expired'
        }

        It 'Should calculate correct days overdue' {
            [datetime]$lastRotated = $script:refDate.AddDays(-100)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.DaysOverdue | Should -Be 10
        }

        It 'Should set DaysUntilExpiry to negative value when expired' {
            [datetime]$lastRotated = $script:refDate.AddDays(-100)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.DaysUntilExpiry | Should -Be -10
        }
    }

    Context 'When a secret is within the warning window' {
        It 'Should return Warning status' {
            # Rotated 80 days ago, 90-day policy, 14-day warning => expires in 10 days
            [datetime]$lastRotated = $script:refDate.AddDays(-80)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'Warning'
        }

        It 'Should calculate days until expiry' {
            [datetime]$lastRotated = $script:refDate.AddDays(-80)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.DaysUntilExpiry | Should -Be 10
        }

        It 'Should have zero days overdue' {
            [datetime]$lastRotated = $script:refDate.AddDays(-80)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.DaysOverdue | Should -Be 0
        }
    }

    Context 'When a secret is not near expiry' {
        It 'Should return OK status' {
            # Rotated 10 days ago, 90-day policy => expires in 80 days
            [datetime]$lastRotated = $script:refDate.AddDays(-10)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'OK'
        }

        It 'Should show days until expiry for OK secrets' {
            [datetime]$lastRotated = $script:refDate.AddDays(-10)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.DaysUntilExpiry | Should -Be 80
        }
    }

    Context 'Edge cases' {
        It 'Should return Expired when exactly at policy boundary (0 days left)' {
            [datetime]$lastRotated = $script:refDate.AddDays(-90)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'Expired'
            $result.DaysUntilExpiry | Should -Be 0
            $result.DaysOverdue | Should -Be 0
        }

        It 'Should return Warning when exactly at warning boundary' {
            # Rotated 76 days ago, 90-day policy, 14-day warning => expires in exactly 14 days
            [datetime]$lastRotated = $script:refDate.AddDays(-76)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'Warning'
            $result.DaysUntilExpiry | Should -Be 14
        }

        It 'Should return OK when 1 day outside warning window' {
            # Rotated 75 days ago, 90-day policy, 14-day warning => expires in 15 days
            [datetime]$lastRotated = $script:refDate.AddDays(-75)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'OK'
            $result.DaysUntilExpiry | Should -Be 15
        }

        It 'Should calculate correct expiry date' {
            [datetime]$lastRotated = [datetime]'2026-01-01'

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 14 -ReferenceDate $script:refDate

            $result.ExpiryDate | Should -Be ([datetime]'2026-04-01')
        }

        It 'Should handle custom warning days' {
            # Rotated 60 days ago, 90-day policy, 30-day warning => expires in 30 days = within warning
            [datetime]$lastRotated = $script:refDate.AddDays(-60)

            $result = Get-SecretStatus -LastRotated $lastRotated `
                -PolicyDays 90 -WarningDays 30 -ReferenceDate $script:refDate

            $result.Status | Should -Be 'Warning'
        }
    }
}

# =============================================================================
# TDD Cycle 2: Import-SecretConfig
# RED:   Tests written for JSON parsing; function did not exist.
# GREEN: Implemented JSON loading from file and string, with field validation.
# REFACTOR: Unified file/string loading, added typed field extraction.
# =============================================================================
Describe 'Import-SecretConfig' {
    Context 'When loading from a JSON string' {
        It 'Should parse a single secret' {
            [string]$json = @'
{
    "secrets": [
        {
            "name": "test-secret",
            "lastRotated": "2026-03-01",
            "policyDays": 90,
            "requiredBy": ["service-a"]
        }
    ]
}
'@
            [hashtable[]]$result = Import-SecretConfig -JsonString $json

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'test-secret'
            $result[0].PolicyDays | Should -Be 90
        }

        It 'Should parse multiple secrets' {
            [string]$json = @'
{
    "secrets": [
        {
            "name": "secret-1",
            "lastRotated": "2026-03-01",
            "policyDays": 30,
            "requiredBy": ["svc-a"]
        },
        {
            "name": "secret-2",
            "lastRotated": "2026-02-01",
            "policyDays": 60,
            "requiredBy": ["svc-b", "svc-c"]
        }
    ]
}
'@
            [hashtable[]]$result = Import-SecretConfig -JsonString $json

            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'secret-1'
            $result[1].Name | Should -Be 'secret-2'
        }

        It 'Should parse lastRotated as a datetime' {
            [string]$json = @'
{
    "secrets": [
        {
            "name": "date-test",
            "lastRotated": "2026-03-15",
            "policyDays": 90,
            "requiredBy": ["svc"]
        }
    ]
}
'@
            [hashtable[]]$result = Import-SecretConfig -JsonString $json

            $result[0].LastRotated | Should -BeOfType [datetime]
            $result[0].LastRotated.Month | Should -Be 3
            $result[0].LastRotated.Day | Should -Be 15
        }

        It 'Should parse requiredBy as a string array' {
            [string]$json = @'
{
    "secrets": [
        {
            "name": "array-test",
            "lastRotated": "2026-01-01",
            "policyDays": 30,
            "requiredBy": ["alpha", "beta", "gamma"]
        }
    ]
}
'@
            [hashtable[]]$result = Import-SecretConfig -JsonString $json

            $result[0].RequiredBy.Count | Should -Be 3
            $result[0].RequiredBy[0] | Should -Be 'alpha'
            $result[0].RequiredBy[2] | Should -Be 'gamma'
        }
    }

    Context 'When loading from a file' {
        It 'Should load the fixture file correctly' {
            [string]$fixturePath = "$PSScriptRoot/fixtures/secrets.json"
            [hashtable[]]$result = Import-SecretConfig -Path $fixturePath

            $result.Count | Should -Be 6
            $result[0].Name | Should -Be 'db-password-prod'
        }
    }
}

# =============================================================================
# TDD Cycle 3: Get-RotationReport
# RED:   Tests for report generation with grouping; function did not exist.
# GREEN: Implemented iteration over secrets, calling Get-SecretStatus and grouping.
# REFACTOR: Extracted summary computation, used typed collections.
# =============================================================================
Describe 'Get-RotationReport' {
    BeforeAll {
        [datetime]$script:refDate = [datetime]'2026-04-06'

        # Build test secrets with known outcomes:
        #   expired-secret:  rotated 100 days ago, 90-day policy  => Expired
        #   warning-secret:  rotated 80 days ago,  90-day policy  => Warning (10 days left)
        #   ok-secret:       rotated 10 days ago,  90-day policy  => OK (80 days left)
        [hashtable[]]$script:testSecrets = @(
            @{
                Name        = [string]'expired-secret'
                LastRotated = [datetime]$script:refDate.AddDays(-100)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-a', 'svc-b')
            },
            @{
                Name        = [string]'warning-secret'
                LastRotated = [datetime]$script:refDate.AddDays(-80)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-c')
            },
            @{
                Name        = [string]'ok-secret'
                LastRotated = [datetime]$script:refDate.AddDays(-10)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-d', 'svc-e')
            }
        )
    }

    Context 'Report structure' {
        It 'Should contain all required top-level keys' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.Keys | Should -Contain 'GeneratedAt'
            $report.Keys | Should -Contain 'WarningDays'
            $report.Keys | Should -Contain 'TotalSecrets'
            $report.Keys | Should -Contain 'Summary'
            $report.Keys | Should -Contain 'Expired'
            $report.Keys | Should -Contain 'Warning'
            $report.Keys | Should -Contain 'OK'
        }

        It 'Should set the correct total count' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.TotalSecrets | Should -Be 3
        }

        It 'Should record the reference date' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.GeneratedAt | Should -Be $script:refDate
        }

        It 'Should record the warning window' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.WarningDays | Should -Be 14
        }
    }

    Context 'Grouping by urgency' {
        It 'Should place expired secrets in the Expired group' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.Expired.Count | Should -Be 1
            $report.Expired[0].Name | Should -Be 'expired-secret'
        }

        It 'Should place warning secrets in the Warning group' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.Warning.Count | Should -Be 1
            $report.Warning[0].Name | Should -Be 'warning-secret'
        }

        It 'Should place OK secrets in the OK group' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.OK.Count | Should -Be 1
            $report.OK[0].Name | Should -Be 'ok-secret'
        }

        It 'Should include summary counts' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.Summary.Expired | Should -Be 1
            $report.Summary.Warning | Should -Be 1
            $report.Summary.OK | Should -Be 1
        }
    }

    Context 'Report entries contain full metadata' {
        It 'Should include RequiredBy in each entry' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.Expired[0].RequiredBy | Should -Contain 'svc-a'
            $report.Expired[0].RequiredBy | Should -Contain 'svc-b'
        }

        It 'Should include status details in each entry' {
            $report = Get-RotationReport -Secrets $script:testSecrets `
                -WarningDays 14 -ReferenceDate $script:refDate

            $report.Expired[0].DaysOverdue | Should -Be 10
            $report.Warning[0].DaysUntilExpiry | Should -Be 10
            $report.OK[0].DaysUntilExpiry | Should -Be 80
        }
    }

    Context 'Configurable warning window' {
        It 'Should reclassify secrets when warning window changes' {
            # With 30-day warning, the ok-secret (80 days left) is still OK
            # But a secret expiring in 20 days would become Warning
            [hashtable[]]$secrets = @(
                @{
                    Name        = [string]'near-expiry'
                    LastRotated = [datetime]$script:refDate.AddDays(-70)
                    PolicyDays  = [int]90
                    RequiredBy  = [string[]]@('svc-x')
                }
            )

            # With default 14-day window, 20 days left => OK
            $report14 = Get-RotationReport -Secrets $secrets `
                -WarningDays 14 -ReferenceDate $script:refDate
            $report14.OK.Count | Should -Be 1

            # With 30-day window, 20 days left => Warning
            $report30 = Get-RotationReport -Secrets $secrets `
                -WarningDays 30 -ReferenceDate $script:refDate
            $report30.Warning.Count | Should -Be 1
        }
    }
}

# =============================================================================
# TDD Cycle 4: ConvertTo-RotationMarkdown
# RED:   Tests for markdown table rendering; function did not exist.
# GREEN: Implemented StringBuilder-based markdown generation with sections.
# REFACTOR: Extracted section rendering into a scriptblock.
# =============================================================================
Describe 'ConvertTo-RotationMarkdown' {
    BeforeAll {
        [datetime]$script:refDate = [datetime]'2026-04-06'

        [hashtable[]]$script:testSecrets = @(
            @{
                Name        = [string]'expired-key'
                LastRotated = [datetime]$script:refDate.AddDays(-100)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-a')
            },
            @{
                Name        = [string]'warning-key'
                LastRotated = [datetime]$script:refDate.AddDays(-80)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-b', 'svc-c')
            },
            @{
                Name        = [string]'ok-key'
                LastRotated = [datetime]$script:refDate.AddDays(-10)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-d')
            }
        )

        $script:report = Get-RotationReport -Secrets $script:testSecrets `
            -WarningDays 14 -ReferenceDate $script:refDate
        $script:markdown = ConvertTo-RotationMarkdown -Report $script:report
    }

    Context 'Header section' {
        It 'Should include the report title' {
            $script:markdown | Should -Match '# Secret Rotation Report'
        }

        It 'Should include the generated date' {
            $script:markdown | Should -Match '2026-04-06'
        }

        It 'Should include the warning window' {
            $script:markdown | Should -Match '14 days'
        }

        It 'Should include total secrets count' {
            $script:markdown | Should -Match 'Total Secrets.*3'
        }
    }

    Context 'Summary table' {
        It 'Should include a summary section' {
            $script:markdown | Should -Match '## Summary'
        }

        It 'Should show expired count in summary' {
            $script:markdown | Should -Match 'Expired \| 1'
        }

        It 'Should show warning count in summary' {
            $script:markdown | Should -Match 'Warning \| 1'
        }

        It 'Should show OK count in summary' {
            $script:markdown | Should -Match 'OK \| 1'
        }
    }

    Context 'Urgency sections' {
        It 'Should include Expired Secrets section' {
            $script:markdown | Should -Match '## Expired Secrets'
        }

        It 'Should include Warning Secrets section' {
            $script:markdown | Should -Match '## Warning Secrets'
        }

        It 'Should include OK Secrets section' {
            $script:markdown | Should -Match '## OK Secrets'
        }

        It 'Should contain expired secret name in the table' {
            $script:markdown | Should -Match 'expired-key'
        }

        It 'Should show overdue text for expired secrets' {
            $script:markdown | Should -Match '10 overdue'
        }

        It 'Should contain warning secret name' {
            $script:markdown | Should -Match 'warning-key'
        }

        It 'Should show required-by services' {
            $script:markdown | Should -Match 'svc-b, svc-c'
        }
    }

    Context 'Table structure' {
        It 'Should contain markdown table headers' {
            $script:markdown | Should -Match '\| Name \| Last Rotated \|'
        }

        It 'Should contain table separator row' {
            $script:markdown | Should -Match '\| --- \| --- \|'
        }
    }
}

# =============================================================================
# TDD Cycle 5: ConvertTo-RotationJson
# RED:   Tests for JSON serialization; function did not exist.
# GREEN: Implemented structured JSON output with proper date formatting.
# REFACTOR: Extracted entry conversion to helper function.
# =============================================================================
Describe 'ConvertTo-RotationJson' {
    BeforeAll {
        [datetime]$script:refDate = [datetime]'2026-04-06'

        [hashtable[]]$script:testSecrets = @(
            @{
                Name        = [string]'expired-key'
                LastRotated = [datetime]$script:refDate.AddDays(-100)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-a')
            },
            @{
                Name        = [string]'ok-key'
                LastRotated = [datetime]$script:refDate.AddDays(-10)
                PolicyDays  = [int]90
                RequiredBy  = [string[]]@('svc-b')
            }
        )

        $script:report = Get-RotationReport -Secrets $script:testSecrets `
            -WarningDays 14 -ReferenceDate $script:refDate
        $script:json = ConvertTo-RotationJson -Report $script:report
        $script:parsed = $script:json | ConvertFrom-Json
    }

    Context 'JSON structure' {
        It 'Should produce valid JSON' {
            # If ConvertFrom-Json succeeded in BeforeAll, the JSON is valid
            $script:parsed | Should -Not -BeNullOrEmpty
        }

        It 'Should include generatedAt field' {
            $script:parsed.generatedAt | Should -Be '2026-04-06'
        }

        It 'Should include warningDays field' {
            $script:parsed.warningDays | Should -Be 14
        }

        It 'Should include totalSecrets field' {
            $script:parsed.totalSecrets | Should -Be 2
        }

        It 'Should include summary with counts' {
            $script:parsed.summary.expired | Should -Be 1
            $script:parsed.summary.warning | Should -Be 0
            $script:parsed.summary.ok | Should -Be 1
        }
    }

    Context 'JSON entries' {
        It 'Should contain expired entries' {
            @($script:parsed.expired).Count | Should -Be 1
            @($script:parsed.expired)[0].name | Should -Be 'expired-key'
        }

        It 'Should contain ok entries' {
            @($script:parsed.ok).Count | Should -Be 1
            @($script:parsed.ok)[0].name | Should -Be 'ok-key'
        }

        It 'Should format dates as ISO strings in entries' {
            @($script:parsed.expired)[0].lastRotated | Should -Match '^\d{4}-\d{2}-\d{2}$'
        }

        It 'Should include requiredBy as an array' {
            @($script:parsed.expired)[0].requiredBy | Should -Contain 'svc-a'
        }

        It 'Should include status in each entry' {
            @($script:parsed.expired)[0].status | Should -Be 'Expired'
            @($script:parsed.ok)[0].status | Should -Be 'OK'
        }
    }
}

# =============================================================================
# TDD Cycle 6: Error Handling
# RED:   Tests for error conditions; no error handling existed.
# GREEN: Added validation in Import-SecretConfig for missing files, invalid JSON, missing fields.
# REFACTOR: Improved error messages with context.
# =============================================================================
Describe 'Error Handling' {
    Context 'Import-SecretConfig with missing file' {
        It 'Should throw when file does not exist' {
            { Import-SecretConfig -Path '/nonexistent/path/secrets.json' } |
                Should -Throw '*not found*'
        }
    }

    Context 'Import-SecretConfig with invalid JSON' {
        It 'Should throw on malformed JSON' {
            [string]$invalidPath = "$PSScriptRoot/fixtures/invalid-json.json"
            { Import-SecretConfig -Path $invalidPath } |
                Should -Throw '*Invalid JSON*'
        }
    }

    Context 'Import-SecretConfig with missing required fields' {
        It 'Should throw when required field is missing' {
            [string]$missingPath = "$PSScriptRoot/fixtures/missing-field.json"
            { Import-SecretConfig -Path $missingPath } |
                Should -Throw '*Missing required field*'
        }
    }

    Context 'Import-SecretConfig with invalid date' {
        It 'Should throw on unparseable date' {
            [string]$json = @'
{
    "secrets": [
        {
            "name": "bad-date",
            "lastRotated": "not-a-date",
            "policyDays": 90,
            "requiredBy": ["svc"]
        }
    ]
}
'@
            { Import-SecretConfig -JsonString $json } |
                Should -Throw '*Invalid date*'
        }
    }
}

# =============================================================================
# Integration test: end-to-end from fixture file to both output formats
# =============================================================================
Describe 'End-to-End Integration' {
    BeforeAll {
        [datetime]$script:refDate = [datetime]'2026-04-06'
        [string]$script:fixturePath = "$PSScriptRoot/fixtures/secrets.json"
        [hashtable[]]$script:secrets = Import-SecretConfig -Path $script:fixturePath
        $script:report = Get-RotationReport -Secrets $script:secrets `
            -WarningDays 14 -ReferenceDate $script:refDate
    }

    It 'Should load all 6 secrets from fixture' {
        $script:secrets.Count | Should -Be 6
    }

    It 'Should classify secrets correctly for reference date 2026-04-06' {
        # db-password-prod: rotated 2025-12-01, 90 days => expires 2026-03-01 => Expired
        # api-key-stripe:   rotated 2026-03-25, 30 days => expires 2026-04-24 => OK (18 days left, >14)
        # jwt-signing-key:  rotated 2026-04-01, 180 days => expires 2026-09-28 => OK
        # tls-cert-wildcard: rotated 2026-01-10, 90 days => expires 2026-04-10 => Warning (4 days left)
        # ssh-deploy-key:   rotated 2026-03-01, 60 days => expires 2026-04-30 => OK (24 days left)
        # oauth-client-secret: rotated 2026-02-15, 90 days => expires 2026-05-16 => OK
        $script:report.Summary.Expired | Should -Be 1
        $script:report.Summary.Warning | Should -Be 1
        $script:report.Summary.OK | Should -Be 4
    }

    It 'Should identify db-password-prod as expired' {
        $script:report.Expired[0].Name | Should -Be 'db-password-prod'
    }

    It 'Should identify tls-cert-wildcard as warning' {
        $script:report.Warning[0].Name | Should -Be 'tls-cert-wildcard'
    }

    It 'Should produce valid markdown output' {
        [string]$md = ConvertTo-RotationMarkdown -Report $script:report
        $md | Should -Match '# Secret Rotation Report'
        $md | Should -Match 'db-password-prod'
        $md | Should -Match 'tls-cert-wildcard'
    }

    It 'Should produce valid JSON output' {
        [string]$json = ConvertTo-RotationJson -Report $script:report
        $parsed = $json | ConvertFrom-Json
        $parsed.totalSecrets | Should -Be 6
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
    }

    It 'Should produce different results with a different warning window' {
        # With 20-day warning, api-key-stripe (18 days left) moves to Warning
        $reportWide = Get-RotationReport -Secrets $script:secrets `
            -WarningDays 20 -ReferenceDate $script:refDate

        $reportWide.Summary.Warning | Should -Be 2
    }
}
