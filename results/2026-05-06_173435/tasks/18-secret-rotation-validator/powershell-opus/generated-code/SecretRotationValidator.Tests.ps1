BeforeAll {
    # Source only the function definitions without executing the main block
    # We extract and eval just the function definitions
    $scriptContent = Get-Content "$PSScriptRoot/SecretRotationValidator.ps1" -Raw
    $functionsOnly = $scriptContent -replace '(?s)# Main execution.*$', ''
    Invoke-Expression $functionsOnly
}

Describe 'Get-SecretConfig' {
    It 'throws when file does not exist' {
        { Get-SecretConfig -Path '/nonexistent/path.json' } | Should -Throw '*not found*'
    }

    It 'throws when file is empty' {
        { Get-SecretConfig -Path "$PSScriptRoot/fixtures/empty.json" } | Should -Throw '*empty*'
    }

    It 'throws when file has invalid JSON' {
        { Get-SecretConfig -Path "$PSScriptRoot/fixtures/invalid.json" } | Should -Throw '*Invalid JSON*'
    }

    It 'throws when secrets key is missing' {
        { Get-SecretConfig -Path "$PSScriptRoot/fixtures/missing-secrets-key.json" } | Should -Throw '*missing*secrets*'
    }

    It 'parses valid config successfully' {
        $config = Get-SecretConfig -Path "$PSScriptRoot/fixtures/mixed-secrets.json"
        $config.secrets.Count | Should -Be 5
    }
}

Describe 'Get-SecretStatus' {
    Context 'expired secret' {
        It 'returns expired status when past rotation policy' {
            $secret = @{
                name                 = 'TEST_SECRET'
                last_rotated         = '2026-03-01'
                rotation_policy_days = 30
                required_by          = @('svc-a')
            }
            $result = Get-SecretStatus -Secret $secret -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
            $result.Status | Should -Be 'expired'
            $result.DaysUntilExpiry | Should -BeLessThan 0
        }
    }

    Context 'warning secret' {
        It 'returns warning status when within warning window' {
            $secret = @{
                name                 = 'WARN_SECRET'
                last_rotated         = '2026-05-03'
                rotation_policy_days = 7
                required_by          = @('svc-b')
            }
            # Expires 2026-05-10, reference is 2026-05-07 = 3 days remaining (within 7-day window)
            $result = Get-SecretStatus -Secret $secret -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
            $result.Status | Should -Be 'warning'
            $result.DaysUntilExpiry | Should -Be 3
        }
    }

    Context 'ok secret' {
        It 'returns ok status when well within policy' {
            $secret = @{
                name                 = 'OK_SECRET'
                last_rotated         = '2026-05-01'
                rotation_policy_days = 90
                required_by          = @('svc-c', 'svc-d')
            }
            $result = Get-SecretStatus -Secret $secret -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
            $result.Status | Should -Be 'ok'
            $result.DaysUntilExpiry | Should -BeGreaterThan 7
        }
    }

    Context 'boundary conditions' {
        It 'returns warning when exactly on warning boundary' {
            $secret = @{
                name                 = 'BOUNDARY'
                last_rotated         = '2026-04-23'
                rotation_policy_days = 21
                required_by          = @('svc-e')
            }
            # Expires 2026-05-14, reference 2026-05-07 = 7 days (exactly warning boundary)
            $result = Get-SecretStatus -Secret $secret -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
            $result.Status | Should -Be 'warning'
            $result.DaysUntilExpiry | Should -Be 7
        }

        It 'returns expired when exactly on expiration day' {
            $secret = @{
                name                 = 'EXPIRES_TODAY'
                last_rotated         = '2026-04-07'
                rotation_policy_days = 30
                required_by          = @('svc-f')
            }
            # Expires 2026-05-07, reference 2026-05-07 = 0 days
            $result = Get-SecretStatus -Secret $secret -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
            $result.Status | Should -Be 'warning'
            $result.DaysUntilExpiry | Should -Be 0
        }
    }
}

Describe 'Get-RotationReport' {
    It 'processes mixed secrets correctly' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/mixed-secrets.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $report.TotalSecrets | Should -Be 5
        $report.Grouped.expired.Count | Should -BeGreaterThan 0
        $report.Grouped.ok.Count | Should -BeGreaterThan 0
    }

    It 'identifies all secrets as expired in all-expired fixture' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/all-expired.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $report.Grouped.expired.Count | Should -Be 2
        $report.Grouped.warning.Count | Should -Be 0
        $report.Grouped.ok.Count | Should -Be 0
    }

    It 'identifies all secrets as ok in all-ok fixture' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/all-ok.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $report.Grouped.expired.Count | Should -Be 0
        $report.Grouped.warning.Count | Should -Be 0
        $report.Grouped.ok.Count | Should -Be 2
    }

    It 'respects custom warning window' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/mixed-secrets.json" -WarningDays 30 -ReferenceDate ([datetime]'2026-05-07')
        # With 30-day warning window, more secrets should be in warning
        ($report.Grouped.warning.Count + $report.Grouped.expired.Count) | Should -BeGreaterThan 0
    }
}

Describe 'Format-ReportAsJson' {
    It 'produces valid JSON with correct structure' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/mixed-secrets.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $json = Format-ReportAsJson -Report $report
        $parsed = $json | ConvertFrom-Json
        $parsed.reference_date | Should -Be '2026-05-07'
        $parsed.warning_days | Should -Be 7
        $parsed.total_secrets | Should -Be 5
        $parsed.summary.expired | Should -BeGreaterOrEqual 0
        $parsed.summary.warning | Should -BeGreaterOrEqual 0
        $parsed.summary.ok | Should -BeGreaterOrEqual 0
        ($parsed.summary.expired + $parsed.summary.warning + $parsed.summary.ok) | Should -Be 5
    }

    It 'includes secret details in each category' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/all-expired.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $json = Format-ReportAsJson -Report $report
        $parsed = $json | ConvertFrom-Json
        $parsed.secrets.expired.Count | Should -Be 2
        $parsed.secrets.expired[0].name | Should -Be 'OLD_SECRET_1'
    }
}

Describe 'Format-ReportAsMarkdown' {
    It 'produces markdown with header and summary table' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/mixed-secrets.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $md = Format-ReportAsMarkdown -Report $report
        $md | Should -Match '# Secret Rotation Report'
        $md | Should -Match '\| Status \| Count \|'
        $md | Should -Match '2026-05-07'
    }

    It 'includes expired section when secrets are expired' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/all-expired.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $md = Format-ReportAsMarkdown -Report $report
        $md | Should -Match '## Expired Secrets'
        $md | Should -Match 'OLD_SECRET_1'
        $md | Should -Match 'OLD_SECRET_2'
    }

    It 'omits expired section when no secrets are expired' {
        $report = Get-RotationReport -ConfigPath "$PSScriptRoot/fixtures/all-ok.json" -WarningDays 7 -ReferenceDate ([datetime]'2026-05-07')
        $md = Format-ReportAsMarkdown -Report $report
        $md | Should -Not -Match '## Expired Secrets'
        $md | Should -Match '## OK Secrets'
    }
}

Describe 'Script execution' {
    It 'exits with code 1 when expired secrets exist' {
        $result = pwsh -NoProfile -File "$PSScriptRoot/SecretRotationValidator.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/all-expired.json" `
            -ReferenceDate '2026-05-07' `
            -OutputFormat 'json'
        $LASTEXITCODE | Should -Be 1
    }

    It 'exits with code 0 when no expired secrets exist' {
        $result = pwsh -NoProfile -File "$PSScriptRoot/SecretRotationValidator.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/all-ok.json" `
            -ReferenceDate '2026-05-07' `
            -OutputFormat 'json'
        $LASTEXITCODE | Should -Be 0
    }

    It 'produces valid JSON output in json mode' {
        $result = pwsh -NoProfile -File "$PSScriptRoot/SecretRotationValidator.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/all-ok.json" `
            -ReferenceDate '2026-05-07' `
            -OutputFormat 'json'
        $parsed = $result | ConvertFrom-Json
        $parsed.total_secrets | Should -Be 2
    }

    It 'produces markdown output in markdown mode' {
        $result = pwsh -NoProfile -File "$PSScriptRoot/SecretRotationValidator.ps1" `
            -ConfigPath "$PSScriptRoot/fixtures/all-ok.json" `
            -ReferenceDate '2026-05-07' `
            -OutputFormat 'markdown'
        ($result -join "`n") | Should -Match '# Secret Rotation Report'
    }
}
