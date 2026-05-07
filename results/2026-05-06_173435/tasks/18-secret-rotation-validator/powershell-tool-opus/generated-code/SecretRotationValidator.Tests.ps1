BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe 'Get-SecretConfig' {
    It 'loads secrets from a JSON file' {
        $secrets = Get-SecretConfig -Path "$PSScriptRoot/fixtures/secrets.json"
        $secrets | Should -HaveCount 5
        $secrets[0].name | Should -Be 'DB_PASSWORD'
    }

    It 'throws on missing file' {
        { Get-SecretConfig -Path '/nonexistent/file.json' } | Should -Throw '*does not exist*'
    }

    It 'throws on invalid JSON' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'bad.json'
        Set-Content -Path $tmp -Value 'not json'
        try {
            { Get-SecretConfig -Path $tmp } | Should -Throw '*Failed to parse*'
        } finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-SecretRotation' {
    BeforeAll {
        # Reference date: 2026-05-07
        $refDate = [datetime]'2026-05-07'
        $secrets = @(
            [PSCustomObject]@{ name = 'EXPIRED';  lastRotated = '2026-01-01'; rotationPolicyDays = 90;  requiredBy = @('svc-a') }
            [PSCustomObject]@{ name = 'WARNING';  lastRotated = '2026-04-15'; rotationPolicyDays = 30;  requiredBy = @('svc-b') }
            [PSCustomObject]@{ name = 'OK_SECRET'; lastRotated = '2026-05-01'; rotationPolicyDays = 365; requiredBy = @('svc-c') }
        )
    }

    It 'classifies expired secrets' {
        $results = Test-SecretRotation -Secrets $secrets -ReferenceDate $refDate -WarningDays 14
        $expired = $results | Where-Object { $_.status -eq 'expired' }
        $expired | Should -HaveCount 1
        $expired[0].name | Should -Be 'EXPIRED'
    }

    It 'classifies warning secrets' {
        $results = Test-SecretRotation -Secrets $secrets -ReferenceDate $refDate -WarningDays 14
        $warning = $results | Where-Object { $_.status -eq 'warning' }
        $warning | Should -HaveCount 1
        $warning[0].name | Should -Be 'WARNING'
    }

    It 'classifies ok secrets' {
        $results = Test-SecretRotation -Secrets $secrets -ReferenceDate $refDate -WarningDays 14
        $ok = $results | Where-Object { $_.status -eq 'ok' }
        $ok | Should -HaveCount 1
        $ok[0].name | Should -Be 'OK_SECRET'
    }

    It 'computes daysUntilExpiry correctly' {
        $results = Test-SecretRotation -Secrets $secrets -ReferenceDate $refDate -WarningDays 14
        # EXPIRED: rotated 2026-01-01 + 90 days = 2026-04-01, ref 2026-05-07 => -36 days
        $expired = $results | Where-Object { $_.name -eq 'EXPIRED' }
        $expired.daysUntilExpiry | Should -Be -36
        # WARNING: rotated 2026-04-15 + 30 days = 2026-05-15, ref 2026-05-07 => 8 days
        $warning = $results | Where-Object { $_.name -eq 'WARNING' }
        $warning.daysUntilExpiry | Should -Be 8
    }

    It 'respects custom warning window' {
        # With a 5-day warning window, WARNING secret (8 days out) should be ok
        $results = Test-SecretRotation -Secrets $secrets -ReferenceDate $refDate -WarningDays 5
        $ok = $results | Where-Object { $_.status -eq 'ok' }
        $ok | Should -HaveCount 2
    }
}

Describe 'Format-RotationReport' {
    BeforeAll {
        $testResults = @(
            [PSCustomObject]@{ name = 'SEC_A'; status = 'expired'; daysUntilExpiry = -10; expiryDate = [datetime]'2026-04-27'; requiredBy = @('svc-1','svc-2'); rotationPolicyDays = 30 }
            [PSCustomObject]@{ name = 'SEC_B'; status = 'warning'; daysUntilExpiry = 5;   expiryDate = [datetime]'2026-05-12'; requiredBy = @('svc-3'); rotationPolicyDays = 60 }
            [PSCustomObject]@{ name = 'SEC_C'; status = 'ok';      daysUntilExpiry = 200; expiryDate = [datetime]'2026-11-23'; requiredBy = @('svc-4'); rotationPolicyDays = 365 }
        )
    }

    It 'produces valid JSON output' {
        $json = Format-RotationReport -Results $testResults -Format 'json'
        $parsed = $json | ConvertFrom-Json
        $parsed.summary.total | Should -Be 3
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok | Should -Be 1
        $parsed.secrets | Should -HaveCount 3
    }

    It 'produces markdown table output' {
        $md = Format-RotationReport -Results $testResults -Format 'markdown'
        $md | Should -BeLike '*# Secret Rotation Report*'
        $md | Should -BeLike '*| SEC_A *'
        $md | Should -BeLike '*| SEC_B *'
        $md | Should -BeLike '*EXPIRED*'
        $md | Should -BeLike '*WARNING*'
    }

    It 'includes urgency grouping in markdown' {
        $md = Format-RotationReport -Results $testResults -Format 'markdown'
        $md | Should -BeLike '*## Expired*'
        $md | Should -BeLike '*## Warning*'
        $md | Should -BeLike '*## OK*'
    }

    It 'throws on unknown format' {
        { Format-RotationReport -Results $testResults -Format 'xml' } | Should -Throw '*does not belong to the set*'
    }
}

Describe 'Invoke-SecretRotationValidator (integration)' {
    It 'produces a full report from fixture file' {
        $report = Invoke-SecretRotationValidator `
            -ConfigPath "$PSScriptRoot/fixtures/secrets.json" `
            -ReferenceDate ([datetime]'2026-05-07') `
            -WarningDays 14 `
            -Format 'json'
        $parsed = $report | ConvertFrom-Json
        $parsed.summary.total | Should -Be 5
        # DB_PASSWORD: rotated 2026-01-15 + 90 = 2026-04-15, expired
        # JWT_SIGNING_KEY: rotated 2026-03-01 + 60 = 2026-04-30, expired
        $parsed.summary.expired | Should -Be 2
        # API_KEY_EXTERNAL: rotated 2026-04-20 + 30 = 2026-05-20, 13 days out => warning
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok | Should -Be 2
    }

    It 'returns markdown when requested' {
        $md = Invoke-SecretRotationValidator `
            -ConfigPath "$PSScriptRoot/fixtures/secrets.json" `
            -ReferenceDate ([datetime]'2026-05-07') `
            -WarningDays 14 `
            -Format 'markdown'
        $md | Should -BeLike '*# Secret Rotation Report*'
        $md | Should -BeLike '*DB_PASSWORD*'
    }
}
