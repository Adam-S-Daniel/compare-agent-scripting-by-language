#requires -Modules Pester
# Unit tests for the secret rotation validator. Red/green TDD: each Describe
# block was added by writing the test first, watching it fail, and then
# implementing the minimum code in SecretRotationValidator.ps1 to make it pass.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'SecretRotationValidator.ps1'
    . $script:ScriptPath
}

Describe 'Get-SecretRotationStatus' {
    It 'classifies a secret rotated long ago as expired' {
        $now = [datetime]'2026-05-08'
        $secret = [pscustomobject]@{
            name = 'db-password'
            lastRotated = '2025-01-01'
            rotationPolicyDays = 90
            requiredBy = @('billing')
        }
        $result = Get-SecretRotationStatus -Secret $secret -Now $now -WarningWindowDays 14
        $result.urgency | Should -Be 'expired'
        $result.daysUntilDue | Should -BeLessThan 0
    }

    It 'classifies a secret due within the warning window as warning' {
        $now = [datetime]'2026-05-08'
        # rotated 80 days ago, policy 90 -> due in 10 days, window 14 -> warning
        $secret = [pscustomobject]@{
            name = 'tls-cert'
            lastRotated = $now.AddDays(-80).ToString('yyyy-MM-dd')
            rotationPolicyDays = 90
            requiredBy = @('api')
        }
        $result = Get-SecretRotationStatus -Secret $secret -Now $now -WarningWindowDays 14
        $result.urgency | Should -Be 'warning'
        $result.daysUntilDue | Should -Be 10
    }

    It 'classifies a fresh secret as ok' {
        $now = [datetime]'2026-05-08'
        $secret = [pscustomobject]@{
            name = 'signing-key'
            lastRotated = $now.AddDays(-5).ToString('yyyy-MM-dd')
            rotationPolicyDays = 90
            requiredBy = @('auth')
        }
        $result = Get-SecretRotationStatus -Secret $secret -Now $now -WarningWindowDays 14
        $result.urgency | Should -Be 'ok'
        $result.daysUntilDue | Should -Be 85
    }

    It 'throws a meaningful error on invalid date' {
        $secret = [pscustomobject]@{
            name = 'broken'
            lastRotated = 'not-a-date'
            rotationPolicyDays = 30
            requiredBy = @()
        }
        { Get-SecretRotationStatus -Secret $secret -Now ([datetime]'2026-05-08') -WarningWindowDays 14 } |
            Should -Throw '*broken*lastRotated*'
    }

    It 'throws a meaningful error on non-positive policy' {
        $secret = [pscustomobject]@{
            name = 'bad-policy'
            lastRotated = '2026-01-01'
            rotationPolicyDays = 0
            requiredBy = @()
        }
        { Get-SecretRotationStatus -Secret $secret -Now ([datetime]'2026-05-08') -WarningWindowDays 14 } |
            Should -Throw '*bad-policy*rotationPolicyDays*'
    }
}

Describe 'Get-SecretRotationReport' {
    It 'groups secrets into expired/warning/ok buckets' {
        $now = [datetime]'2026-05-08'
        $config = [pscustomobject]@{
            secrets = @(
                [pscustomobject]@{ name='a'; lastRotated='2025-01-01'; rotationPolicyDays=90; requiredBy=@('s1') },
                [pscustomobject]@{ name='b'; lastRotated=$now.AddDays(-80).ToString('yyyy-MM-dd'); rotationPolicyDays=90; requiredBy=@('s2') },
                [pscustomobject]@{ name='c'; lastRotated=$now.AddDays(-1).ToString('yyyy-MM-dd');  rotationPolicyDays=90; requiredBy=@('s3') }
            )
        }
        $report = Get-SecretRotationReport -Config $config -Now $now -WarningWindowDays 14
        $report.expired.Count | Should -Be 1
        $report.warning.Count | Should -Be 1
        $report.ok.Count | Should -Be 1
        $report.expired[0].name | Should -Be 'a'
        $report.warning[0].name | Should -Be 'b'
        $report.ok[0].name | Should -Be 'c'
        $report.summary.total | Should -Be 3
    }

    It 'sorts each bucket by daysUntilDue ascending (most urgent first)' {
        $now = [datetime]'2026-05-08'
        $config = [pscustomobject]@{
            secrets = @(
                [pscustomobject]@{ name='old';    lastRotated='2024-01-01'; rotationPolicyDays=30; requiredBy=@() },
                [pscustomobject]@{ name='older';  lastRotated='2023-01-01'; rotationPolicyDays=30; requiredBy=@() }
            )
        }
        $report = Get-SecretRotationReport -Config $config -Now $now -WarningWindowDays 14
        $report.expired[0].name | Should -Be 'older'
        $report.expired[1].name | Should -Be 'old'
    }
}

Describe 'Format-RotationReport' {
    BeforeAll {
        $script:now = [datetime]'2026-05-08'
        $script:config = [pscustomobject]@{
            secrets = @(
                [pscustomobject]@{ name='api-key'; lastRotated='2025-01-01'; rotationPolicyDays=90; requiredBy=@('billing','api') },
                [pscustomobject]@{ name='tls';     lastRotated=$script:now.AddDays(-80).ToString('yyyy-MM-dd'); rotationPolicyDays=90; requiredBy=@('api') },
                [pscustomobject]@{ name='session'; lastRotated=$script:now.AddDays(-1).ToString('yyyy-MM-dd');  rotationPolicyDays=30; requiredBy=@('web') }
            )
        }
        $script:report = Get-SecretRotationReport -Config $script:config -Now $script:now -WarningWindowDays 14
    }

    It 'produces JSON containing all three buckets with counts' {
        $json = Format-RotationReport -Report $script:report -Format json
        $obj = $json | ConvertFrom-Json
        $obj.summary.total | Should -Be 3
        $obj.summary.expired | Should -Be 1
        $obj.summary.warning | Should -Be 1
        $obj.summary.ok | Should -Be 1
        ($obj.expired | Measure-Object).Count | Should -Be 1
    }

    It 'produces markdown with a table and urgency headers' {
        $md = Format-RotationReport -Report $script:report -Format markdown
        $md | Should -Match '# Secret Rotation Report'
        $md | Should -Match '## Expired'
        $md | Should -Match '## Warning'
        $md | Should -Match '## OK'
        $md | Should -Match '\| Name \| Last Rotated \| Policy \(days\) \| Days Until Due \| Required By \|'
        $md | Should -Match 'api-key'
        $md | Should -Match 'billing, api'
    }

    It 'rejects unknown formats with a meaningful error' {
        { Format-RotationReport -Report $script:report -Format yaml } |
            Should -Throw '*Unsupported format*yaml*'
    }
}

Describe 'Invoke-SecretRotationValidator (script entrypoint)' {
    BeforeAll {
        $script:fixture = Join-Path $TestDrive 'secrets.json'
        @{
            secrets = @(
                @{ name='a'; lastRotated='2025-01-01'; rotationPolicyDays=90; requiredBy=@('s1') },
                @{ name='b'; lastRotated='2026-05-01'; rotationPolicyDays=90; requiredBy=@('s2') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:fixture
    }

    It 'reads a config file and emits JSON' {
        $out = Invoke-SecretRotationValidator -ConfigPath $script:fixture -Format json `
            -WarningWindowDays 14 -Now ([datetime]'2026-05-08')
        $obj = $out | ConvertFrom-Json
        $obj.summary.total | Should -Be 2
        $obj.summary.expired | Should -Be 1
    }

    It 'returns non-zero exit-style indicator when expired secrets exist and -FailOnExpired is set' {
        # The function returns a hashtable with .ExitCode in addition to text output
        $result = Invoke-SecretRotationValidator -ConfigPath $script:fixture -Format json `
            -WarningWindowDays 14 -Now ([datetime]'2026-05-08') -FailOnExpired -PassThru
        $result.ExitCode | Should -Be 2
    }

    It 'throws if the config file is missing' {
        { Invoke-SecretRotationValidator -ConfigPath (Join-Path $TestDrive 'nope.json') -Format json } |
            Should -Throw '*not found*'
    }
}
