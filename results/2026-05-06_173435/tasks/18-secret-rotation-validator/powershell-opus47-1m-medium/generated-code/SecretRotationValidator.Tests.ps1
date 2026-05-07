# Pester tests for SecretRotationValidator. Written test-first (red/green TDD).
# Run with: Invoke-Pester -Path ./SecretRotationValidator.Tests.ps1

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe 'Get-SecretStatus' {
    It 'classifies a secret rotated within policy as ok' {
        $now = [datetime]'2026-05-07'
        $secret = @{ name = 's1'; lastRotated = '2026-05-01'; rotationPolicyDays = 30; requiredBy = @('svc-a') }
        (Get-SecretStatus -Secret $secret -Now $now -WarningDays 7).status | Should -Be 'ok'
    }

    It 'classifies a secret within the warning window as warning' {
        $now = [datetime]'2026-05-07'
        $secret = @{ name = 's1'; lastRotated = '2026-04-12'; rotationPolicyDays = 30; requiredBy = @('svc-a') }
        (Get-SecretStatus -Secret $secret -Now $now -WarningDays 7).status | Should -Be 'warning'
    }

    It 'classifies an overdue secret as expired' {
        $now = [datetime]'2026-05-07'
        $secret = @{ name = 's1'; lastRotated = '2026-01-01'; rotationPolicyDays = 30; requiredBy = @('svc-a') }
        (Get-SecretStatus -Secret $secret -Now $now -WarningDays 7).status | Should -Be 'expired'
    }

    It 'computes daysUntilExpiry correctly (negative when expired)' {
        $now = [datetime]'2026-05-07'
        $secret = @{ name = 's1'; lastRotated = '2026-01-01'; rotationPolicyDays = 30; requiredBy = @('svc-a') }
        (Get-SecretStatus -Secret $secret -Now $now -WarningDays 7).daysUntilExpiry | Should -Be -96
    }

    It 'throws a clear error when lastRotated is invalid' {
        $secret = @{ name = 'bad'; lastRotated = 'nope'; rotationPolicyDays = 30; requiredBy = @() }
        { Get-SecretStatus -Secret $secret -Now ([datetime]'2026-05-07') -WarningDays 7 } |
            Should -Throw "*Invalid lastRotated*"
    }
}

Describe 'Invoke-SecretRotationReport' {
    BeforeAll {
        $script:fixture = @{
            secrets = @(
                @{ name = 'api-key';  lastRotated = '2026-05-01'; rotationPolicyDays = 30; requiredBy = @('api') }
                @{ name = 'db-pass';  lastRotated = '2026-04-12'; rotationPolicyDays = 30; requiredBy = @('db','worker') }
                @{ name = 'old-cert'; lastRotated = '2026-01-01'; rotationPolicyDays = 30; requiredBy = @('gw') }
            )
        }
        $script:now = [datetime]'2026-05-07'
    }

    It 'groups secrets by urgency' {
        $r = Invoke-SecretRotationReport -Config $fixture -Now $now -WarningDays 7 -Format json
        $obj = $r | ConvertFrom-Json
        $obj.expired.Count  | Should -Be 1
        $obj.warning.Count  | Should -Be 1
        $obj.ok.Count       | Should -Be 1
        $obj.expired[0].name | Should -Be 'old-cert'
        $obj.warning[0].name | Should -Be 'db-pass'
        $obj.ok[0].name      | Should -Be 'api-key'
    }

    It 'emits markdown table with headers and rows' {
        $r = Invoke-SecretRotationReport -Config $fixture -Now $now -WarningDays 7 -Format markdown
        $r | Should -Match '\| Name \| Status \| Days Until Expiry \| Required By \|'
        $r | Should -Match 'old-cert'
        $r | Should -Match 'expired'
    }

    It 'has stable ordering: expired first, then warning, then ok' {
        $r = Invoke-SecretRotationReport -Config $fixture -Now $now -WarningDays 7 -Format markdown
        $expIdx = $r.IndexOf('old-cert')
        $warnIdx = $r.IndexOf('db-pass')
        $okIdx = $r.IndexOf('api-key')
        $expIdx | Should -BeLessThan $warnIdx
        $warnIdx | Should -BeLessThan $okIdx
    }

    It 'throws when format is unknown' {
        { Invoke-SecretRotationReport -Config $fixture -Now $now -WarningDays 7 -Format xml } |
            Should -Throw "*Unsupported format*"
    }

    It 'throws when config has no secrets array' {
        { Invoke-SecretRotationReport -Config @{} -Now $now -WarningDays 7 -Format json } |
            Should -Throw "*secrets*"
    }
}

Describe 'Invoke-SecretRotationValidatorCli' {
    It 'reads a JSON file and produces JSON output' {
        $tmp = New-TemporaryFile
        $cfg = @{
            secrets = @(
                @{ name = 'k1'; lastRotated = '2026-05-01'; rotationPolicyDays = 30; requiredBy = @('a') }
            )
        }
        $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp.FullName
        try {
            $out = Invoke-SecretRotationValidatorCli -ConfigPath $tmp.FullName -WarningDays 7 -Format json -Now ([datetime]'2026-05-07')
            ($out | ConvertFrom-Json).ok[0].name | Should -Be 'k1'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'returns nonzero exit code indication when expired secrets exist' {
        $tmp = New-TemporaryFile
        $cfg = @{
            secrets = @(
                @{ name = 'old'; lastRotated = '2026-01-01'; rotationPolicyDays = 30; requiredBy = @('a') }
            )
        }
        $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp.FullName
        try {
            $out = Invoke-SecretRotationValidatorCli -ConfigPath $tmp.FullName -WarningDays 7 -Format json -Now ([datetime]'2026-05-07') -PassThru
            $out.HasExpired | Should -BeTrue
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }
}
