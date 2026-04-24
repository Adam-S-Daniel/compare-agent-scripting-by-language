# Pester tests for SecretRotationValidator.
# TDD: each Describe block was written before its corresponding implementation.

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
    $script:RefDate = [datetime]'2026-04-20'
}

Describe 'Get-SecretStatus' {
    It 'returns expired when days since rotation exceeds policy' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-01-01'; rotationPolicyDays=30; requiredBy=@() }
        (Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14).Status | Should -Be 'expired'
    }

    It 'returns warning when expiry falls within the warning window' {
        # lastRotated + 90 days = 2026-04-23; 3 days until expiry, warning window 14 -> warning
        $s = [pscustomobject]@{ name='b'; lastRotated='2026-01-23'; rotationPolicyDays=90; requiredBy=@() }
        (Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14).Status | Should -Be 'warning'
    }

    It 'returns ok when expiry is outside the warning window' {
        $s = [pscustomobject]@{ name='c'; lastRotated='2026-04-10'; rotationPolicyDays=90; requiredBy=@() }
        (Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14).Status | Should -Be 'ok'
    }

    It 'computes daysUntilExpiry correctly' {
        $s = [pscustomobject]@{ name='d'; lastRotated='2026-04-10'; rotationPolicyDays=30; requiredBy=@() }
        (Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 7).DaysUntilExpiry | Should -Be 20
    }

    It 'throws on invalid date' {
        $s = [pscustomobject]@{ name='e'; lastRotated='not-a-date'; rotationPolicyDays=30; requiredBy=@() }
        { Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 7 } | Should -Throw
    }
}

Describe 'Invoke-SecretRotationValidator - JSON output' {
    BeforeAll {
        $script:cfg = Join-Path $TestDrive 'secrets.json'
        @{
            secrets = @(
                @{ name='expired-key'; lastRotated='2026-01-01'; rotationPolicyDays=30; requiredBy=@('svc-a') },
                @{ name='warning-key'; lastRotated='2026-01-23'; rotationPolicyDays=90; requiredBy=@('svc-b') },
                @{ name='ok-key';      lastRotated='2026-04-10'; rotationPolicyDays=90; requiredBy=@('svc-c') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cfg
    }

    It 'emits valid JSON with three urgency groups' {
        $out = Invoke-SecretRotationValidator -ConfigPath $script:cfg -Format json -WarningDays 14 -ReferenceDate $script:RefDate
        $parsed = $out | ConvertFrom-Json
        $parsed.expired.Count  | Should -Be 1
        $parsed.warning.Count  | Should -Be 1
        $parsed.ok.Count       | Should -Be 1
        $parsed.expired[0].name | Should -Be 'expired-key'
        $parsed.warning[0].name | Should -Be 'warning-key'
        $parsed.ok[0].name      | Should -Be 'ok-key'
    }

    It 'reports summary totals' {
        $out = Invoke-SecretRotationValidator -ConfigPath $script:cfg -Format json -WarningDays 14 -ReferenceDate $script:RefDate
        $parsed = $out | ConvertFrom-Json
        $parsed.summary.total   | Should -Be 3
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok      | Should -Be 1
    }
}

Describe 'Invoke-SecretRotationValidator - markdown output' {
    BeforeAll {
        $script:cfg = Join-Path $TestDrive 'secrets.json'
        @{
            secrets = @(
                @{ name='expired-key'; lastRotated='2026-01-01'; rotationPolicyDays=30; requiredBy=@('svc-a') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cfg
    }

    It 'emits a markdown table grouped by urgency' {
        $out = Invoke-SecretRotationValidator -ConfigPath $script:cfg -Format markdown -WarningDays 14 -ReferenceDate $script:RefDate
        $out | Should -Match '## Expired'
        $out | Should -Match '\| Name \| Last Rotated \| Policy \(days\) \| Days Until Expiry \| Required By \|'
        $out | Should -Match 'expired-key'
    }

    It 'includes all three section headers even when a group is empty' {
        $out = Invoke-SecretRotationValidator -ConfigPath $script:cfg -Format markdown -WarningDays 14 -ReferenceDate $script:RefDate
        $out | Should -Match '## Expired'
        $out | Should -Match '## Warning'
        $out | Should -Match '## OK'
    }
}

Describe 'Invoke-SecretRotationValidator - error handling' {
    It 'throws a meaningful error when config file is missing' {
        { Invoke-SecretRotationValidator -ConfigPath '/does/not/exist.json' -Format json -WarningDays 14 -ReferenceDate $script:RefDate } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when format is unsupported' {
        $cfg = Join-Path $TestDrive 'bad-format.json'
        '{"secrets":[]}' | Set-Content $cfg
        { Invoke-SecretRotationValidator -ConfigPath $cfg -Format xml -WarningDays 14 -ReferenceDate $script:RefDate } | Should -Throw
    }

    It 'throws when config JSON is malformed' {
        $cfg = Join-Path $TestDrive 'malformed.json'
        'not json' | Set-Content $cfg
        { Invoke-SecretRotationValidator -ConfigPath $cfg -Format json -WarningDays 14 -ReferenceDate $script:RefDate } | Should -Throw
    }
}
