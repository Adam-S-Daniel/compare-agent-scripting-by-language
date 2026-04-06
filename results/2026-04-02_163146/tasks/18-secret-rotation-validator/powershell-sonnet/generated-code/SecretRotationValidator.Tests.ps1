# SecretRotationValidator.Tests.ps1
# TDD tests for Secret Rotation Validator using Pester framework
# Following red/green/refactor methodology

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0

# Import the module under test (will fail until implementation exists)
$scriptPath = Join-Path $PSScriptRoot 'SecretRotationValidator.ps1'

# ============================================================
# TEST SUITE: Secret Classification
# ============================================================
Describe 'Get-SecretStatus' {
    BeforeAll {
        . $scriptPath
        # Fixed reference date for deterministic tests
        $script:ReferenceDate = [datetime]'2024-01-15'
    }

    Context 'Expired secrets' {
        It 'classifies a secret as Expired when past its rotation deadline' {
            # A secret rotated 100 days ago with a 90-day policy is expired
            $secret = @{
                Name              = 'DB_PASSWORD'
                LastRotated       = '2023-10-07'  # 100 days before 2024-01-15
                RotationPolicyDays = 90
                RequiredBy        = @('api-service', 'worker')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result.Status | Should -Be 'Expired'
        }

        It 'classifies a secret as Expired exactly on its expiry date' {
            # Rotated exactly 90 days ago with a 90-day policy
            $secret = @{
                Name              = 'API_KEY'
                LastRotated       = '2023-10-17'  # 90 days before 2024-01-15
                RotationPolicyDays = 90
                RequiredBy        = @('frontend')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result.Status | Should -Be 'Expired'
        }
    }

    Context 'Warning secrets' {
        It 'classifies a secret as Warning when expiring within the warning window' {
            # Rotated 80 days ago with a 90-day policy: expires in 10 days (within 14-day window)
            $secret = @{
                Name              = 'OAUTH_SECRET'
                LastRotated       = '2023-10-27'  # 80 days before 2024-01-15
                RotationPolicyDays = 90
                RequiredBy        = @('auth-service')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result.Status | Should -Be 'Warning'
        }

        It 'classifies a secret as Warning exactly at the warning window boundary' {
            # Rotated 76 days ago with a 90-day policy: expires in 14 days (boundary)
            $secret = @{
                Name              = 'SMTP_PASSWORD'
                LastRotated       = '2023-10-31'  # 76 days before 2024-01-15
                RotationPolicyDays = 90
                RequiredBy        = @('notification-service')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result.Status | Should -Be 'Warning'
        }
    }

    Context 'OK secrets' {
        It 'classifies a secret as Ok when well within rotation policy' {
            # Rotated 10 days ago with a 90-day policy: 80 days remaining
            $secret = @{
                Name              = 'JWT_SECRET'
                LastRotated       = '2024-01-05'  # 10 days before 2024-01-15
                RotationPolicyDays = 90
                RequiredBy        = @('api-service')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result.Status | Should -Be 'Ok'
        }

        It 'classifies a secret as Ok when just outside the warning window' {
            # Rotated 75 days ago with a 90-day policy: expires in 15 days (just outside 14-day window)
            $secret = @{
                Name              = 'ENCRYPTION_KEY'
                LastRotated       = '2023-11-01'  # 75 days before 2024-01-15
                RotationPolicyDays = 90
                RequiredBy        = @('storage-service')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result.Status | Should -Be 'Ok'
        }
    }

    Context 'Status result properties' {
        It 'returns all required fields in the status result' {
            $secret = @{
                Name              = 'TEST_SECRET'
                LastRotated       = '2023-10-07'
                RotationPolicyDays = 90
                RequiredBy        = @('service-a', 'service-b')
            }

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $result | Should -Not -BeNullOrEmpty
            $result.Name       | Should -Be 'TEST_SECRET'
            $result.Status     | Should -BeIn @('Expired', 'Warning', 'Ok')
            $result.ExpiryDate | Should -Not -BeNullOrEmpty
            $result.DaysUntilExpiry | Should -Not -BeNullOrEmpty
            $result.RequiredBy | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'throws an error when secret name is missing' {
            $secret = @{
                LastRotated        = '2023-10-07'
                RotationPolicyDays = 90
                RequiredBy         = @('api-service')
            }

            { Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14 } |
                Should -Throw -ExpectedMessage '*Name*'
        }

        It 'throws an error when LastRotated date is invalid' {
            $secret = @{
                Name               = 'BAD_SECRET'
                LastRotated        = 'not-a-date'
                RotationPolicyDays = 90
                RequiredBy         = @('api-service')
            }

            { Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14 } |
                Should -Throw
        }

        It 'throws an error when RotationPolicyDays is zero or negative' {
            $secret = @{
                Name               = 'BAD_SECRET'
                LastRotated        = '2023-10-07'
                RotationPolicyDays = 0
                RequiredBy         = @('api-service')
            }

            { Get-SecretStatus -Secret $secret -ReferenceDate $script:ReferenceDate -WarningWindowDays 14 } |
                Should -Throw -ExpectedMessage '*RotationPolicyDays*'
        }
    }
}

# ============================================================
# TEST SUITE: Report Generation
# ============================================================
Describe 'Invoke-SecretRotationReport' {
    BeforeAll {
        . $scriptPath
        $script:ReferenceDate = [datetime]'2024-01-15'

        # Test fixture: a realistic mix of secrets
        $script:TestSecrets = @(
            @{
                Name               = 'DB_PASSWORD'
                LastRotated        = '2023-10-07'   # 100 days ago — expired
                RotationPolicyDays = 90
                RequiredBy         = @('api-service', 'worker')
            },
            @{
                Name               = 'OAUTH_SECRET'
                LastRotated        = '2023-10-27'   # 80 days ago — warning (expires in 10d)
                RotationPolicyDays = 90
                RequiredBy         = @('auth-service')
            },
            @{
                Name               = 'JWT_SECRET'
                LastRotated        = '2024-01-05'   # 10 days ago — ok
                RotationPolicyDays = 90
                RequiredBy         = @('api-service')
            },
            @{
                Name               = 'API_KEY'
                LastRotated        = '2023-10-17'   # 90 days ago — exactly expired
                RotationPolicyDays = 90
                RequiredBy         = @('frontend')
            },
            @{
                Name               = 'SMTP_PASSWORD'
                LastRotated        = '2023-11-01'   # 75 days ago — ok (expires in 15d)
                RotationPolicyDays = 90
                RequiredBy         = @('notification-service')
            }
        )
    }

    Context 'Report structure' {
        It 'returns a report with Expired, Warning, and Ok groups' {
            $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets `
                -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $report | Should -Not -BeNullOrEmpty
            $report.Expired | Should -Not -BeNullOrEmpty
            $report.Warning | Should -Not -BeNullOrEmpty
            $report.Ok      | Should -Not -BeNullOrEmpty
        }

        It 'correctly counts secrets in each urgency group' {
            $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets `
                -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $report.Expired.Count | Should -Be 2   # DB_PASSWORD, API_KEY
            $report.Warning.Count | Should -Be 1   # OAUTH_SECRET
            $report.Ok.Count      | Should -Be 2   # JWT_SECRET, SMTP_PASSWORD
        }

        It 'includes GeneratedAt timestamp in the report' {
            $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets `
                -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $report.GeneratedAt | Should -Not -BeNullOrEmpty
        }

        It 'includes Summary statistics in the report' {
            $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets `
                -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $report.Summary | Should -Not -BeNullOrEmpty
            $report.Summary.TotalSecrets   | Should -Be 5
            $report.Summary.ExpiredCount   | Should -Be 2
            $report.Summary.WarningCount   | Should -Be 1
            $report.Summary.OkCount        | Should -Be 2
        }
    }

    Context 'Edge cases' {
        It 'handles an empty secrets list' {
            $report = Invoke-SecretRotationReport -Secrets @() `
                -ReferenceDate $script:ReferenceDate -WarningWindowDays 14

            $report.Expired.Count | Should -Be 0
            $report.Warning.Count | Should -Be 0
            $report.Ok.Count      | Should -Be 0
            $report.Summary.TotalSecrets | Should -Be 0
        }

        It 'uses a default warning window when not specified' {
            # Should not throw — default WarningWindowDays should be used
            { Invoke-SecretRotationReport -Secrets $script:TestSecrets -ReferenceDate $script:ReferenceDate } |
                Should -Not -Throw
        }
    }
}

# ============================================================
# TEST SUITE: Output Formatting
# ============================================================
Describe 'Format-RotationReport' {
    BeforeAll {
        . $scriptPath
        $script:ReferenceDate = [datetime]'2024-01-15'

        $script:TestSecrets = @(
            @{
                Name               = 'DB_PASSWORD'
                LastRotated        = '2023-10-07'
                RotationPolicyDays = 90
                RequiredBy         = @('api-service', 'worker')
            },
            @{
                Name               = 'OAUTH_SECRET'
                LastRotated        = '2023-10-27'
                RotationPolicyDays = 90
                RequiredBy         = @('auth-service')
            },
            @{
                Name               = 'JWT_SECRET'
                LastRotated        = '2024-01-05'
                RotationPolicyDays = 90
                RequiredBy         = @('api-service')
            }
        )

        $script:Report = Invoke-SecretRotationReport -Secrets $script:TestSecrets `
            -ReferenceDate $script:ReferenceDate -WarningWindowDays 14
    }

    Context 'JSON format' {
        It 'produces valid JSON output' {
            $output = Format-RotationReport -Report $script:Report -Format 'JSON'

            $output | Should -Not -BeNullOrEmpty
            # Should be parseable as JSON
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON output contains all urgency groups' {
            $output = Format-RotationReport -Report $script:Report -Format 'JSON'
            $parsed = $output | ConvertFrom-Json

            $parsed.Expired | Should -Not -BeNullOrEmpty
            $parsed.Warning | Should -Not -BeNullOrEmpty
            $parsed.Ok      | Should -Not -BeNullOrEmpty
        }

        It 'JSON output includes summary section' {
            $output = Format-RotationReport -Report $script:Report -Format 'JSON'
            $parsed = $output | ConvertFrom-Json

            $parsed.Summary | Should -Not -BeNullOrEmpty
            $parsed.Summary.TotalSecrets | Should -Be 3
        }
    }

    Context 'Markdown format' {
        It 'produces markdown table output' {
            $output = Format-RotationReport -Report $script:Report -Format 'Markdown'

            $output | Should -Not -BeNullOrEmpty
            # Markdown tables use pipe characters
            $output | Should -Match '\|'
        }

        It 'markdown output contains section headers' {
            $output = Format-RotationReport -Report $script:Report -Format 'Markdown'

            $output | Should -Match '## Expired'
            $output | Should -Match '## Warning'
            $output | Should -Match '## Ok'
        }

        It 'markdown output contains secret names' {
            $output = Format-RotationReport -Report $script:Report -Format 'Markdown'

            $output | Should -Match 'DB_PASSWORD'
        }

        It 'markdown output contains a summary section' {
            $output = Format-RotationReport -Report $script:Report -Format 'Markdown'

            $output | Should -Match '## Summary'
        }
    }

    Context 'Error handling' {
        It 'throws for unsupported format' {
            { Format-RotationReport -Report $script:Report -Format 'XML' } |
                Should -Throw -ExpectedMessage '*format*'
        }
    }
}

# ============================================================
# TEST SUITE: Configuration Loading
# ============================================================
Describe 'Import-SecretConfig' {
    BeforeAll {
        . $scriptPath

        # Create a temporary fixture file for testing
        $script:TempDir = Join-Path $PSScriptRoot 'fixtures'
        if (-not (Test-Path $script:TempDir)) {
            New-Item -ItemType Directory -Path $script:TempDir | Out-Null
        }

        $script:FixtureFile = Join-Path $script:TempDir 'test-secrets.json'
        $fixtureContent = @{
            warningWindowDays = 14
            secrets = @(
                @{
                    name               = 'DB_PASSWORD'
                    lastRotated        = '2023-10-07'
                    rotationPolicyDays = 90
                    requiredBy         = @('api-service', 'worker')
                },
                @{
                    name               = 'JWT_SECRET'
                    lastRotated        = '2024-01-05'
                    rotationPolicyDays = 90
                    requiredBy         = @('api-service')
                }
            )
        } | ConvertTo-Json -Depth 5

        Set-Content -Path $script:FixtureFile -Value $fixtureContent
    }

    AfterAll {
        if (Test-Path $script:FixtureFile) {
            Remove-Item $script:FixtureFile -Force
        }
    }

    It 'loads secrets from a JSON configuration file' {
        $config = Import-SecretConfig -Path $script:FixtureFile

        $config | Should -Not -BeNullOrEmpty
        $config.Secrets.Count | Should -Be 2
        $config.WarningWindowDays | Should -Be 14
    }

    It 'throws a meaningful error for missing file' {
        { Import-SecretConfig -Path '/nonexistent/path/secrets.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error for invalid JSON' {
        $badFile = Join-Path $script:TempDir 'bad-secrets.json'
        Set-Content -Path $badFile -Value 'this is not json {{ }'

        { Import-SecretConfig -Path $badFile } |
            Should -Throw

        Remove-Item $badFile -Force
    }
}
