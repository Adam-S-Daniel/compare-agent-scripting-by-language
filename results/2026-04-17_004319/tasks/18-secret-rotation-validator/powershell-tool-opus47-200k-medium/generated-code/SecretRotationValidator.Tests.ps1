# Pester tests for SecretRotationValidator
# Uses TDD: red -> green -> refactor

BeforeAll {
    . $PSScriptRoot/SecretRotationValidator.ps1
}

Describe 'Get-SecretRotationStatus' {
    It 'classifies a secret as expired when age exceeds rotation policy' {
        $now = [datetime]'2026-04-20'
        $secrets = @(
            [pscustomobject]@{ name='db-password'; lastRotated='2025-01-01'; rotationDays=90; requiredBy=@('api') }
        )
        $result = Get-SecretRotationStatus -Secrets $secrets -WarningDays 7 -Now $now
        $result.expired.Count | Should -Be 1
        $result.expired[0].name | Should -Be 'db-password'
        $result.warning.Count | Should -Be 0
        $result.ok.Count | Should -Be 0
    }

    It 'classifies a secret as warning when within warning window' {
        $now = [datetime]'2026-04-20'
        # rotated 85 days ago, policy 90, warning 7 -> 5 days until expiry -> warning
        $secrets = @(
            [pscustomobject]@{ name='api-key'; lastRotated=($now.AddDays(-85)).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('web') }
        )
        $result = Get-SecretRotationStatus -Secrets $secrets -WarningDays 7 -Now $now
        $result.warning.Count | Should -Be 1
        $result.warning[0].daysUntilExpiry | Should -Be 5
    }

    It 'classifies a secret as ok when outside warning window' {
        $now = [datetime]'2026-04-20'
        $secrets = @(
            [pscustomobject]@{ name='signing-key'; lastRotated=($now.AddDays(-10)).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('auth') }
        )
        $result = Get-SecretRotationStatus -Secrets $secrets -WarningDays 7 -Now $now
        $result.ok.Count | Should -Be 1
        $result.ok[0].daysUntilExpiry | Should -Be 80
    }

    It 'handles multiple secrets in mixed states' {
        $now = [datetime]'2026-04-20'
        $secrets = @(
            [pscustomobject]@{ name='s1'; lastRotated=($now.AddDays(-100)).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('a') },
            [pscustomobject]@{ name='s2'; lastRotated=($now.AddDays(-88)).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('b') },
            [pscustomobject]@{ name='s3'; lastRotated=($now.AddDays(-1)).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('c') }
        )
        $result = Get-SecretRotationStatus -Secrets $secrets -WarningDays 7 -Now $now
        $result.expired.Count | Should -Be 1
        $result.warning.Count | Should -Be 1
        $result.ok.Count | Should -Be 1
    }

    It 'throws a meaningful error on invalid date string' {
        $secrets = @(
            [pscustomobject]@{ name='bad'; lastRotated='not-a-date'; rotationDays=30; requiredBy=@() }
        )
        { Get-SecretRotationStatus -Secrets $secrets -WarningDays 7 -Now ([datetime]'2026-04-20') } |
            Should -Throw '*Invalid lastRotated*'
    }

    It 'throws on negative rotationDays' {
        $secrets = @(
            [pscustomobject]@{ name='bad'; lastRotated='2026-01-01'; rotationDays=-1; requiredBy=@() }
        )
        { Get-SecretRotationStatus -Secrets $secrets -WarningDays 7 -Now ([datetime]'2026-04-20') } |
            Should -Throw '*rotationDays*'
    }
}

Describe 'Format-RotationReport' {
    BeforeAll {
        $script:sampleStatus = @{
            expired = @(
                [pscustomobject]@{ name='db'; lastRotated='2025-01-01'; rotationDays=90; requiredBy=@('api','web'); daysUntilExpiry=-384 }
            )
            warning = @(
                [pscustomobject]@{ name='api-key'; lastRotated='2026-01-25'; rotationDays=90; requiredBy=@('web'); daysUntilExpiry=5 }
            )
            ok = @(
                [pscustomobject]@{ name='signing'; lastRotated='2026-04-10'; rotationDays=90; requiredBy=@('auth'); daysUntilExpiry=80 }
            )
        }
    }

    It 'produces markdown with headers for each urgency group' {
        $md = Format-RotationReport -Status $script:sampleStatus -Format markdown
        $md | Should -Match '## Expired'
        $md | Should -Match '## Warning'
        $md | Should -Match '## OK'
        $md | Should -Match '\| Name \| Last Rotated \| Rotation Days \| Days Until Expiry \| Required By \|'
        $md | Should -Match 'db'
        $md | Should -Match 'api, web'
    }

    It 'produces valid JSON with the three buckets' {
        $json = Format-RotationReport -Status $script:sampleStatus -Format json
        $parsed = $json | ConvertFrom-Json
        $parsed.expired.Count | Should -Be 1
        $parsed.warning.Count | Should -Be 1
        $parsed.ok.Count | Should -Be 1
        $parsed.expired[0].name | Should -Be 'db'
    }

    It 'rejects unknown formats' {
        { Format-RotationReport -Status $script:sampleStatus -Format xml } | Should -Throw '*Format*'
    }
}

Describe 'Invoke-SecretRotationValidator (end-to-end)' {
    It 'reads a JSON config file and emits a markdown report' {
        $tempConfig = New-TemporaryFile
        $now = [datetime]'2026-04-20'
        $config = @{
            secrets = @(
                @{ name='expired-secret'; lastRotated='2025-01-01'; rotationDays=90; requiredBy=@('svc-a') },
                @{ name='warn-secret'; lastRotated=$now.AddDays(-88).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('svc-b') },
                @{ name='ok-secret'; lastRotated=$now.AddDays(-1).ToString('yyyy-MM-dd'); rotationDays=90; requiredBy=@('svc-c') }
            )
        }
        $config | ConvertTo-Json -Depth 5 | Set-Content -Path $tempConfig.FullName
        try {
            $out = Invoke-SecretRotationValidator -ConfigPath $tempConfig.FullName -WarningDays 7 -Format markdown -Now $now
            $out | Should -Match 'expired-secret'
            $out | Should -Match 'warn-secret'
            $out | Should -Match 'ok-secret'
        } finally {
            Remove-Item $tempConfig.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'reports exit summary counts' {
        $tempConfig = New-TemporaryFile
        $now = [datetime]'2026-04-20'
        $config = @{
            secrets = @(
                @{ name='s1'; lastRotated='2025-01-01'; rotationDays=90; requiredBy=@() }
            )
        }
        $config | ConvertTo-Json -Depth 5 | Set-Content -Path $tempConfig.FullName
        try {
            $summary = Invoke-SecretRotationValidator -ConfigPath $tempConfig.FullName -WarningDays 7 -Format json -Now $now -AsObject
            $summary.expired.Count | Should -Be 1
        } finally {
            Remove-Item $tempConfig.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'fails gracefully when config file is missing' {
        { Invoke-SecretRotationValidator -ConfigPath '/nonexistent/path.json' -WarningDays 7 -Format markdown } |
            Should -Throw '*not found*'
    }
}
