# Pester tests for SecretRotationValidator.
# Written with red/green TDD: each Describe block represents a feature added
# one failing test at a time. The module is imported fresh in BeforeAll so
# tests are hermetic.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module SecretRotationValidator -ErrorAction SilentlyContinue
}

Describe 'Get-SecretStatus' {
    It 'classifies a secret past its rotation policy as expired' {
        $now = [DateTime]'2026-04-19'
        $secret = [pscustomobject]@{
            Name               = 'db-password'
            LastRotated        = '2026-01-01'
            RotationPolicyDays = 30
            RequiredBy         = @('api')
        }
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 7
        $result.Status         | Should -Be 'expired'
        $result.DaysUntilDue   | Should -BeLessThan 0
    }

    It 'classifies a secret within the warning window as warning' {
        $now = [DateTime]'2026-04-19'
        $secret = [pscustomobject]@{
            Name               = 'api-key'
            LastRotated        = '2026-04-15'   # +30 -> 2026-05-15; 26 days away
            RotationPolicyDays = 30
            RequiredBy         = @('web')
        }
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 30
        $result.Status       | Should -Be 'warning'
        $result.DaysUntilDue | Should -Be 26
    }

    It 'classifies a freshly rotated secret as ok' {
        $now = [DateTime]'2026-04-19'
        $secret = [pscustomobject]@{
            Name               = 'signing-key'
            LastRotated        = '2026-04-18'
            RotationPolicyDays = 365
            RequiredBy         = @('auth')
        }
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 30
        $result.Status | Should -Be 'ok'
    }

    It 'treats a secret that expires exactly today as expired' {
        $now = [DateTime]'2026-04-19'
        $secret = [pscustomobject]@{
            Name               = 'token'
            LastRotated        = '2026-03-20'   # +30 -> 2026-04-19
            RotationPolicyDays = 30
            RequiredBy         = @('svc')
        }
        (Get-SecretStatus -Secret $secret -Now $now -WarningDays 7).Status `
            | Should -Be 'expired'
    }

    It 'throws a meaningful error for malformed LastRotated' {
        $bad = [pscustomobject]@{
            Name = 'x'; LastRotated = 'not-a-date'
            RotationPolicyDays = 30; RequiredBy = @()
        }
        { Get-SecretStatus -Secret $bad -Now ([DateTime]'2026-04-19') -WarningDays 7 } `
            | Should -Throw '*LastRotated*'
    }
}

Describe 'Get-RotationReport' {
    BeforeAll {
        $script:Fixture = @(
            [pscustomobject]@{ Name='db';     LastRotated='2026-01-01'; RotationPolicyDays=30;  RequiredBy=@('api') }
            [pscustomobject]@{ Name='api';    LastRotated='2026-04-15'; RotationPolicyDays=30;  RequiredBy=@('web') }
            [pscustomobject]@{ Name='signer'; LastRotated='2026-04-18'; RotationPolicyDays=365; RequiredBy=@('auth') }
        )
        $script:Now = [DateTime]'2026-04-19'
    }

    It 'buckets secrets by urgency' {
        $r = Get-RotationReport -Secrets $script:Fixture -Now $script:Now -WarningDays 30
        $r.Expired.Count | Should -Be 1
        $r.Warning.Count | Should -Be 1
        $r.Ok.Count      | Should -Be 1
        $r.Expired[0].Name | Should -Be 'db'
        $r.Warning[0].Name | Should -Be 'api'
        $r.Ok[0].Name      | Should -Be 'signer'
    }

    It 'includes a generatedAt timestamp and totals' {
        $r = Get-RotationReport -Secrets $script:Fixture -Now $script:Now -WarningDays 30
        $r.GeneratedAt | Should -Be $script:Now
        $r.Totals.Expired | Should -Be 1
        $r.Totals.Warning | Should -Be 1
        $r.Totals.Ok      | Should -Be 1
    }

    It 'handles an empty secret list' {
        $r = Get-RotationReport -Secrets @() -Now $script:Now -WarningDays 30
        $r.Totals.Expired | Should -Be 0
        $r.Totals.Warning | Should -Be 0
        $r.Totals.Ok      | Should -Be 0
    }
}

Describe 'Format-RotationReport (markdown)' {
    BeforeAll {
        $script:Report = Get-RotationReport `
            -Secrets @(
                [pscustomobject]@{ Name='db';  LastRotated='2026-01-01'; RotationPolicyDays=30;  RequiredBy=@('api','worker') }
                [pscustomobject]@{ Name='api'; LastRotated='2026-04-15'; RotationPolicyDays=30;  RequiredBy=@('web') }
                [pscustomobject]@{ Name='sig'; LastRotated='2026-04-18'; RotationPolicyDays=365; RequiredBy=@('auth') }
            ) `
            -Now ([DateTime]'2026-04-19') -WarningDays 30
    }

    It 'emits an Expired section with a markdown table' {
        $md = Format-RotationReport -Report $script:Report -Format markdown
        $md | Should -Match '## Expired \(1\)'
        $md | Should -Match '\| Name \| Last Rotated \| Policy \(days\) \| Days Until Due \| Required By \|'
        $md | Should -Match '\| db \| 2026-01-01 \| 30 \| -\d+ \| api, worker \|'
    }

    It 'emits Warning and OK sections' {
        $md = Format-RotationReport -Report $script:Report -Format markdown
        $md | Should -Match '## Warning \(1\)'
        $md | Should -Match '## OK \(1\)'
        $md | Should -Match '\| api \|'
        $md | Should -Match '\| sig \|'
    }

    It 'emits a "No secrets" line for an empty bucket' {
        $empty = Get-RotationReport -Secrets @() -Now ([DateTime]'2026-04-19') -WarningDays 30
        $md = Format-RotationReport -Report $empty -Format markdown
        $md | Should -Match '## Expired \(0\)'
        $md | Should -Match 'No secrets in this bucket'
    }
}

Describe 'Format-RotationReport (json)' {
    It 'emits a valid JSON document with expected keys' {
        $report = Get-RotationReport `
            -Secrets @(
                [pscustomobject]@{ Name='db'; LastRotated='2026-01-01'; RotationPolicyDays=30; RequiredBy=@('api') }
            ) `
            -Now ([DateTime]'2026-04-19') -WarningDays 30
        $json = Format-RotationReport -Report $report -Format json
        $parsed = $json | ConvertFrom-Json
        $parsed.totals.expired | Should -Be 1
        $parsed.expired[0].name | Should -Be 'db'
        $parsed.expired[0].daysUntilDue | Should -BeLessThan 0
    }
}

Describe 'Invoke-SecretRotationValidator' {
    BeforeAll {
        $script:TmpDir = Join-Path ([IO.Path]::GetTempPath()) "srv-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TmpDir | Out-Null
    }
    AfterAll {
        Remove-Item -Recurse -Force $script:TmpDir -ErrorAction SilentlyContinue
    }

    It 'reads a JSON config file and emits markdown by default' {
        $cfg = Join-Path $script:TmpDir 'cfg.json'
        @(
            @{ name='db'; lastRotated='2026-01-01'; rotationPolicyDays=30; requiredBy=@('api') }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $cfg
        $out = Invoke-SecretRotationValidator -ConfigPath $cfg `
            -Now ([DateTime]'2026-04-19') -WarningDays 30 -Format markdown
        $out | Should -Match '## Expired \(1\)'
    }

    It 'returns a non-zero exit code via the ExitCode property when expired secrets exist' {
        $cfg = Join-Path $script:TmpDir 'cfg2.json'
        @(
            @{ name='db'; lastRotated='2026-01-01'; rotationPolicyDays=30; requiredBy=@('api') }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $cfg
        $res = Invoke-SecretRotationValidator -ConfigPath $cfg `
            -Now ([DateTime]'2026-04-19') -WarningDays 30 -Format json -ReturnExitCode
        $res.ExitCode | Should -Be 2
    }

    It 'returns exit code 1 when only warnings are present' {
        $cfg = Join-Path $script:TmpDir 'cfg3.json'
        @(
            @{ name='api'; lastRotated='2026-04-15'; rotationPolicyDays=30; requiredBy=@('web') }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $cfg
        $res = Invoke-SecretRotationValidator -ConfigPath $cfg `
            -Now ([DateTime]'2026-04-19') -WarningDays 30 -Format markdown -ReturnExitCode
        $res.ExitCode | Should -Be 1
    }

    It 'returns exit code 0 when all secrets are ok' {
        $cfg = Join-Path $script:TmpDir 'cfg4.json'
        @(
            @{ name='sig'; lastRotated='2026-04-18'; rotationPolicyDays=365; requiredBy=@('auth') }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $cfg
        $res = Invoke-SecretRotationValidator -ConfigPath $cfg `
            -Now ([DateTime]'2026-04-19') -WarningDays 30 -Format markdown -ReturnExitCode
        $res.ExitCode | Should -Be 0
    }

    It 'throws a meaningful error when the config file is missing' {
        { Invoke-SecretRotationValidator -ConfigPath (Join-Path $script:TmpDir 'missing.json') `
            -Now ([DateTime]'2026-04-19') -WarningDays 7 -Format markdown } `
            | Should -Throw '*not found*'
    }

    It 'throws a meaningful error when the config is malformed JSON' {
        $cfg = Join-Path $script:TmpDir 'bad.json'
        Set-Content -Path $cfg -Value '{ not valid json'
        { Invoke-SecretRotationValidator -ConfigPath $cfg `
            -Now ([DateTime]'2026-04-19') -WarningDays 7 -Format markdown } `
            | Should -Throw '*JSON*'
    }
}
