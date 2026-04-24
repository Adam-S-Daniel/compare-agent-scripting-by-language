#Requires -Modules Pester

# TDD: Tests written before implementation. Each Describe block follows red/green/refactor.
# Fixtures are defined in BeforeAll to work correctly with Pester 5's runspace isolation.

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"

    # Fixed reference date for deterministic tests
    $script:BaseDate = [datetime]::new(2026, 4, 20)

    # Sample secrets mock data
    $script:SampleSecrets = @(
        @{
            Name         = 'db-password'
            LastRotated  = '2026-01-01'   # 109 days ago; policy 90d => expired
            RotationDays = 90
            RequiredBy   = @('api-service', 'worker')
        },
        @{
            Name         = 'api-key'
            LastRotated  = '2026-04-05'   # 15 days ago; policy 14d => expired
            RotationDays = 14
            RequiredBy   = @('frontend')
        },
        @{
            Name         = 'signing-cert'
            LastRotated  = '2026-04-02'   # 18 days ago; policy 30d => expiry 2026-05-02 => 12 days left => warning
            RotationDays = 30
            RequiredBy   = @('auth-service')
        },
        @{
            Name         = 'internal-token'
            LastRotated  = '2026-04-18'   # 2 days ago; policy 60d => 58 days left => ok
            RotationDays = 60
            RequiredBy   = @('scheduler')
        }
    )
}

# ============================================================
# RED PHASE 1: Get-SecretStatus returns correct urgency labels
# ============================================================
Describe 'Get-SecretStatus' {
    It 'marks a secret as expired when past rotation deadline' {
        $secret = @{
            Name         = 'db-password'
            LastRotated  = '2026-01-01'
            RotationDays = 90
            RequiredBy   = @('api-service')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:BaseDate -WarningDays 14
        $result.Urgency | Should -Be 'expired'
    }

    It 'marks a secret as warning when within warning window' {
        $secret = @{
            Name         = 'signing-cert'
            LastRotated  = '2026-04-02'
            RotationDays = 30
            RequiredBy   = @('auth-service')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:BaseDate -WarningDays 14
        # 2026-04-02 + 30d = 2026-05-02; reference 2026-04-20 => 12 days left => warning
        $result.Urgency | Should -Be 'warning'
    }

    It 'marks a secret as ok when well within rotation window' {
        $secret = @{
            Name         = 'internal-token'
            LastRotated  = '2026-04-18'
            RotationDays = 60
            RequiredBy   = @('scheduler')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:BaseDate -WarningDays 14
        $result.Urgency | Should -Be 'ok'
    }

    It 'includes DaysUntilExpiry in result (58 days for internal-token)' {
        $secret = @{
            Name         = 'internal-token'
            LastRotated  = '2026-04-18'
            RotationDays = 60
            RequiredBy   = @('scheduler')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:BaseDate -WarningDays 14
        # 2026-04-18 + 60d = 2026-06-17; 2026-04-20 to 2026-06-17 = 58 days
        $result.DaysUntilExpiry | Should -Be 58
    }

    It 'includes negative DaysUntilExpiry for expired secrets' {
        $secret = @{
            Name         = 'db-password'
            LastRotated  = '2026-01-01'
            RotationDays = 90
            RequiredBy   = @('api-service')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:BaseDate -WarningDays 14
        # 2026-01-01 + 90d = 2026-04-01; 2026-04-20 is 19 days past => -19
        $result.DaysUntilExpiry | Should -Be -19
    }
}

# ============================================================
# RED PHASE 2: Get-RotationReport groups by urgency
# ============================================================
Describe 'Get-RotationReport' {
    BeforeAll {
        $script:Report = Get-RotationReport -Secrets $script:SampleSecrets -ReferenceDate $script:BaseDate -WarningDays 14
    }

    It 'returns a report object with expired, warning, ok groups' {
        $script:Report | Should -Not -BeNullOrEmpty
        $script:Report.Expired | Should -Not -BeNullOrEmpty
        $script:Report.Warning | Should -Not -BeNullOrEmpty
        $script:Report.Ok      | Should -Not -BeNullOrEmpty
    }

    It 'correctly counts expired secrets (db-password and api-key)' {
        $script:Report.Expired.Count | Should -Be 2
    }

    It 'correctly counts warning secrets (signing-cert: 12 days left, within 14d window)' {
        $script:Report.Warning.Count | Should -Be 1
    }

    It 'correctly counts ok secrets (internal-token: 58 days left)' {
        $script:Report.Ok.Count | Should -Be 1
    }

    It 'includes RequiredBy in each secret entry' {
        $expired = $script:Report.Expired | Where-Object { $_.Name -eq 'db-password' }
        $expired.RequiredBy | Should -Contain 'api-service'
        $expired.RequiredBy | Should -Contain 'worker'
    }
}

# ============================================================
# RED PHASE 3: Format-RotationReport outputs markdown
# ============================================================
Describe 'Format-RotationReport - Markdown' {
    BeforeAll {
        $report = Get-RotationReport -Secrets $script:SampleSecrets -ReferenceDate $script:BaseDate -WarningDays 14
        $script:MarkdownOutput = Format-RotationReport -Report $report -Format 'Markdown'
    }

    It 'produces a non-empty string' {
        $script:MarkdownOutput | Should -Not -BeNullOrEmpty
    }

    It 'contains an Expired section header' {
        $script:MarkdownOutput | Should -Match '##\s+Expired'
    }

    It 'contains a Warning section header' {
        $script:MarkdownOutput | Should -Match '##\s+Warning'
    }

    It 'contains an Ok section header' {
        $script:MarkdownOutput | Should -Match '##\s+Ok'
    }

    It 'contains a markdown table header row' {
        $script:MarkdownOutput | Should -Match '\|\s*Name\s*\|'
    }

    It 'contains db-password in the output' {
        $script:MarkdownOutput | Should -Match 'db-password'
    }

    It 'contains signing-cert in warning section (not in expired or ok)' {
        $warningIdx = $script:MarkdownOutput.IndexOf('## Warning')
        $okIdx      = $script:MarkdownOutput.IndexOf('## Ok')
        $warningSection = $script:MarkdownOutput.Substring($warningIdx, $okIdx - $warningIdx)
        $warningSection | Should -Match 'signing-cert'
    }
}

# ============================================================
# RED PHASE 4: Format-RotationReport outputs JSON
# ============================================================
Describe 'Format-RotationReport - JSON' {
    BeforeAll {
        $report = Get-RotationReport -Secrets $script:SampleSecrets -ReferenceDate $script:BaseDate -WarningDays 14
        $script:JsonOutput = Format-RotationReport -Report $report -Format 'JSON'
        $script:Parsed     = $script:JsonOutput | ConvertFrom-Json
    }

    It 'produces valid JSON' {
        { $script:JsonOutput | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON has expired array' {
        $script:Parsed.expired | Should -Not -BeNullOrEmpty
    }

    It 'JSON has warning array' {
        $script:Parsed.warning | Should -Not -BeNullOrEmpty
    }

    It 'JSON has ok array' {
        $script:Parsed.ok | Should -Not -BeNullOrEmpty
    }

    It 'JSON expired count is 2' {
        $script:Parsed.expired.Count | Should -Be 2
    }

    It 'JSON includes generatedAt timestamp' {
        $script:Parsed.generatedAt | Should -Not -BeNullOrEmpty
    }
}

# ============================================================
# RED PHASE 5: Invoke-SecretRotationValidator end-to-end
# ============================================================
Describe 'Invoke-SecretRotationValidator' {
    It 'accepts a JSON config file path and returns a report' {
        $configPath = Join-Path $TestDrive 'secrets.json'
        $config = @{
            warningDays = 14
            secrets     = $script:SampleSecrets
        }
        $config | ConvertTo-Json -Depth 5 | Set-Content $configPath

        $result = Invoke-SecretRotationValidator -ConfigPath $configPath -ReferenceDate $script:BaseDate
        $result.Expired.Count | Should -Be 2
        $result.Warning.Count | Should -Be 1
        $result.Ok.Count      | Should -Be 1
    }

    It 'uses default warning window of 14 days when not specified in config' {
        $configPath = Join-Path $TestDrive 'secrets-nowarning.json'
        $config = @{
            secrets = @(
                @{
                    Name         = 'mykey'
                    LastRotated  = '2026-04-02'   # 18 days ago; expiry 2026-05-02 => 12 days left => warning
                    RotationDays = 30
                    RequiredBy   = @('svc')
                }
            )
        }
        $config | ConvertTo-Json -Depth 5 | Set-Content $configPath

        $result = Invoke-SecretRotationValidator -ConfigPath $configPath -ReferenceDate $script:BaseDate
        # 18 days ago, 30d policy => 12 days left, within default 14d warning => warning
        $result.Warning.Count | Should -Be 1
    }

    It 'throws a meaningful error for missing config file' {
        { Invoke-SecretRotationValidator -ConfigPath '/nonexistent/path.json' } |
            Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
    }
}
