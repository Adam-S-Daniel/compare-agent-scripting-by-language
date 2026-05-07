# Pester tests for SecretRotationValidator.
# TDD: these were written before the implementation. Each Describe block
# corresponds to one piece of behaviour added incrementally.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-SecretRotationStatus' {

    It 'classifies a secret rotated recently as ok' {
        $secret = [pscustomobject]@{
            name = 'db'; lastRotated = '2026-04-01'
            rotationPolicyDays = 90; requiredBy = @('api')
        }
        $result = Get-SecretRotationStatus -Secret $secret -AsOfDate '2026-05-07' -WarningDays 14
        $result.Status | Should -Be 'ok'
        $result.DaysUntilExpiry | Should -Be 54
    }

    It 'classifies a secret within warning window as warning' {
        $secret = [pscustomobject]@{
            name = 'db'; lastRotated = '2026-02-15'
            rotationPolicyDays = 90; requiredBy = @('api')
        }
        $result = Get-SecretRotationStatus -Secret $secret -AsOfDate '2026-05-07' -WarningDays 14
        $result.Status | Should -Be 'warning'
    }

    It 'classifies a secret past its policy as expired' {
        $secret = [pscustomobject]@{
            name = 'db'; lastRotated = '2025-01-01'
            rotationPolicyDays = 90; requiredBy = @('api')
        }
        $result = Get-SecretRotationStatus -Secret $secret -AsOfDate '2026-05-07' -WarningDays 14
        $result.Status | Should -Be 'expired'
        $result.DaysUntilExpiry | Should -BeLessThan 0
    }

    It 'throws a meaningful error when required fields are missing' {
        $bad = [pscustomobject]@{ name = 'db' }
        { Get-SecretRotationStatus -Secret $bad -AsOfDate '2026-05-07' -WarningDays 14 } |
            Should -Throw -ExpectedMessage '*lastRotated*'
    }
}

Describe 'Invoke-SecretRotationValidator (config loading)' {

    BeforeAll {
        $script:fixture = Join-Path $TestDrive 'secrets.json'
        @{
            secrets = @(
                @{ name = 'ok-secret';     lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('api') }
                @{ name = 'warn-secret';   lastRotated = '2026-02-15'; rotationPolicyDays = 90; requiredBy = @('worker') }
                @{ name = 'expired-secret';lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('cron','api') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:fixture
    }

    It 'returns a report object with three urgency buckets' {
        $report = Invoke-SecretRotationValidator -ConfigPath $script:fixture -WarningDays 14 -AsOfDate '2026-05-07' -Format object
        $report.expired.Count  | Should -Be 1
        $report.warning.Count  | Should -Be 1
        $report.ok.Count       | Should -Be 1
        $report.expired[0].name | Should -Be 'expired-secret'
    }

    It 'emits valid JSON with the expected top-level keys' {
        $json = Invoke-SecretRotationValidator -ConfigPath $script:fixture -WarningDays 14 -AsOfDate '2026-05-07' -Format json
        $obj = $json | ConvertFrom-Json
        $obj.summary.expired | Should -Be 1
        $obj.summary.warning | Should -Be 1
        $obj.summary.ok      | Should -Be 1
        $obj.expired[0].name | Should -Be 'expired-secret'
    }

    It 'emits a markdown report grouped by urgency' {
        $md = Invoke-SecretRotationValidator -ConfigPath $script:fixture -WarningDays 14 -AsOfDate '2026-05-07' -Format markdown
        $md | Should -Match '## Expired'
        $md | Should -Match '## Warning'
        $md | Should -Match '## OK'
        $md | Should -Match 'expired-secret'
        $md | Should -Match '\| Name \| Last Rotated \| Days Until Expiry \| Required By \|'
    }

    It 'throws a clear error when the config file does not exist' {
        { Invoke-SecretRotationValidator -ConfigPath '/no/such/file.json' -WarningDays 14 -AsOfDate '2026-05-07' -Format json } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a clear error when the config JSON is malformed' {
        $bad = Join-Path $TestDrive 'bad.json'
        Set-Content -Path $bad -Value '{ this is not json'
        { Invoke-SecretRotationValidator -ConfigPath $bad -WarningDays 14 -AsOfDate '2026-05-07' -Format json } |
            Should -Throw -ExpectedMessage '*Failed to parse*'
    }
}
