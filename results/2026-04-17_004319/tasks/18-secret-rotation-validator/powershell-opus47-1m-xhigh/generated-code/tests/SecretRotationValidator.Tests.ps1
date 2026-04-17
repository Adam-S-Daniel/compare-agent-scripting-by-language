# Pester tests for the Secret Rotation Validator.
#
# These tests were written following red/green/refactor TDD:
#   1. Each Describe block reflects a feature added incrementally.
#   2. Tests were written first and failed, then code in
#      ../src/SecretRotationValidator.psm1 was written to make them pass.
#   3. Once all tests passed, naming and structure were cleaned up.
#
# Run with:  Invoke-Pester -Path tests/SecretRotationValidator.Tests.ps1

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'src' 'SecretRotationValidator.psm1'
    if (-not (Test-Path $ModulePath)) {
        throw "Module not found at $ModulePath"
    }
    Import-Module $ModulePath -Force
}

Describe 'Get-SecretStatus' {
    # Feature 1: classify a single secret as expired / warning / ok based on
    # last rotation date, rotation policy in days, a configurable warning
    # window, and the current time.

    It 'classifies a secret as expired when past its rotation policy' {
        $secret = [pscustomobject]@{
            Name               = 'db-password'
            LastRotated        = '2026-01-01'
            RotationPolicyDays = 30
            RequiredBy         = @('api')
        }
        $now = [datetime]'2026-04-17'
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 7
        $result.Status | Should -Be 'expired'
        $result.Name   | Should -Be 'db-password'
        $result.DaysUntilRotation | Should -BeLessThan 0
    }

    It 'classifies a secret as warning when within the warning window' {
        $secret = [pscustomobject]@{
            Name               = 'session-key'
            LastRotated        = '2026-04-01'
            RotationPolicyDays = 20  # due on 2026-04-21 -> 4 days away on 2026-04-17
            RequiredBy         = @('web')
        }
        $now = [datetime]'2026-04-17'
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 7
        $result.Status | Should -Be 'warning'
        $result.DaysUntilRotation | Should -Be 4
    }

    It 'classifies a secret as ok when outside the warning window' {
        $secret = [pscustomobject]@{
            Name               = 'api-token'
            LastRotated        = '2026-04-01'
            RotationPolicyDays = 90
            RequiredBy         = @('billing')
        }
        $now = [datetime]'2026-04-17'
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 7
        $result.Status | Should -Be 'ok'
        $result.DaysUntilRotation | Should -Be 74
    }

    It 'treats a secret rotated exactly on boundary as warning (inclusive)' {
        # Policy 10 days, rotated exactly 3 days ago, warning=7 => 7 days to go.
        $secret = [pscustomobject]@{
            Name               = 'edge-key'
            LastRotated        = '2026-04-10'
            RotationPolicyDays = 10
            RequiredBy         = @('x')
        }
        $now = [datetime]'2026-04-13'
        $result = Get-SecretStatus -Secret $secret -Now $now -WarningDays 7
        $result.Status | Should -Be 'warning'
        $result.DaysUntilRotation | Should -Be 7
    }

    It 'throws a meaningful error when LastRotated is unparseable' {
        $secret = [pscustomobject]@{
            Name               = 'bad'
            LastRotated        = 'not-a-date'
            RotationPolicyDays = 10
            RequiredBy         = @()
        }
        { Get-SecretStatus -Secret $secret -Now (Get-Date) -WarningDays 7 } |
            Should -Throw -ExpectedMessage "*LastRotated*"
    }

    It 'throws when RotationPolicyDays is missing or not positive' {
        $secret = [pscustomobject]@{
            Name               = 'bad'
            LastRotated        = '2026-01-01'
            RotationPolicyDays = 0
            RequiredBy         = @()
        }
        { Get-SecretStatus -Secret $secret -Now (Get-Date) -WarningDays 7 } |
            Should -Throw -ExpectedMessage "*RotationPolicyDays*"
    }
}

Describe 'Get-RotationReport' {
    # Feature 2: classify a collection of secrets and return an object grouped
    # by urgency.

    BeforeAll {
        $script:Now = [datetime]'2026-04-17'
        $script:Secrets = @(
            [pscustomobject]@{
                Name = 'expired-a'; LastRotated = '2026-01-01'
                RotationPolicyDays = 30; RequiredBy = @('api','web')
            },
            [pscustomobject]@{
                Name = 'warning-b'; LastRotated = '2026-04-01'
                RotationPolicyDays = 20; RequiredBy = @('web')
            },
            [pscustomobject]@{
                Name = 'ok-c'; LastRotated = '2026-04-01'
                RotationPolicyDays = 90; RequiredBy = @('billing')
            }
        )
    }

    It 'groups secrets by urgency' {
        $report = Get-RotationReport -Secrets $script:Secrets -Now $script:Now -WarningDays 7
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count      | Should -Be 1
        $report.Expired[0].Name | Should -Be 'expired-a'
        $report.Warning[0].Name | Should -Be 'warning-b'
        $report.Ok[0].Name      | Should -Be 'ok-c'
    }

    It 'includes metadata (generated-at, warning days, totals)' {
        $report = Get-RotationReport -Secrets $script:Secrets -Now $script:Now -WarningDays 7
        $report.GeneratedAt | Should -Be $script:Now
        $report.WarningDays | Should -Be 7
        $report.TotalSecrets | Should -Be 3
    }

    It 'sorts expired secrets by most-overdue first' {
        $secrets = @(
            [pscustomobject]@{
                Name = 'mild'; LastRotated = '2026-04-01'
                RotationPolicyDays = 10; RequiredBy = @() },  # 6 days overdue
            [pscustomobject]@{
                Name = 'severe'; LastRotated = '2026-01-01'
                RotationPolicyDays = 10; RequiredBy = @() }   # ~100 days overdue
        )
        $report = Get-RotationReport -Secrets $secrets -Now $script:Now -WarningDays 7
        $report.Expired[0].Name | Should -Be 'severe'
        $report.Expired[1].Name | Should -Be 'mild'
    }

    It 'sorts warning secrets by soonest-due first' {
        $secrets = @(
            [pscustomobject]@{
                Name = 'later'; LastRotated = '2026-04-11'
                RotationPolicyDays = 12; RequiredBy = @() },  # due 2026-04-23 => 6 days
            [pscustomobject]@{
                Name = 'sooner'; LastRotated = '2026-04-11'
                RotationPolicyDays = 8; RequiredBy = @() }    # due 2026-04-19 => 2 days
        )
        $report = Get-RotationReport -Secrets $secrets -Now $script:Now -WarningDays 7
        $report.Warning[0].Name | Should -Be 'sooner'
        $report.Warning[1].Name | Should -Be 'later'
    }

    It 'accepts an empty secrets array' {
        $report = Get-RotationReport -Secrets @() -Now $script:Now -WarningDays 7
        $report.TotalSecrets | Should -Be 0
        $report.Expired.Count | Should -Be 0
    }
}

Describe 'ConvertTo-MarkdownReport' {
    BeforeAll {
        $script:Now = [datetime]'2026-04-17'
        $script:Report = Get-RotationReport -WarningDays 7 -Now $script:Now -Secrets @(
            [pscustomobject]@{ Name='expired-a'; LastRotated='2026-01-01'
                RotationPolicyDays=30; RequiredBy=@('api','web') },
            [pscustomobject]@{ Name='warning-b'; LastRotated='2026-04-01'
                RotationPolicyDays=20; RequiredBy=@('web') },
            [pscustomobject]@{ Name='ok-c'; LastRotated='2026-04-01'
                RotationPolicyDays=90; RequiredBy=@('billing') }
        )
    }

    It 'includes a top-level heading' {
        $md = ConvertTo-MarkdownReport -Report $script:Report
        $md | Should -Match '# Secret Rotation Report'
    }

    It 'has sections for each urgency level' {
        $md = ConvertTo-MarkdownReport -Report $script:Report
        $md | Should -Match '## Expired \(1\)'
        $md | Should -Match '## Warning \(1\)'
        $md | Should -Match '## OK \(1\)'
    }

    It 'renders tables with the expected headers' {
        $md = ConvertTo-MarkdownReport -Report $script:Report
        $md | Should -Match '\| Name \| Last Rotated \| Days Until Rotation \| Required By \|'
    }

    It 'includes secret rows' {
        $md = ConvertTo-MarkdownReport -Report $script:Report
        $md | Should -Match 'expired-a'
        $md | Should -Match 'warning-b'
        $md | Should -Match 'ok-c'
        # Required-by list is joined with commas.
        $md | Should -Match 'api, web'
    }

    It 'omits sections that have no secrets' {
        $report = Get-RotationReport -Secrets @() -Now $script:Now -WarningDays 7
        $md = ConvertTo-MarkdownReport -Report $report
        $md | Should -Not -Match '## Expired'
        $md | Should -Not -Match '## Warning'
        $md | Should -Match '_No secrets found._'
    }
}

Describe 'ConvertTo-JsonReport' {
    BeforeAll {
        $script:Now = [datetime]'2026-04-17'
        $script:Report = Get-RotationReport -WarningDays 7 -Now $script:Now -Secrets @(
            [pscustomobject]@{ Name='expired-a'; LastRotated='2026-01-01'
                RotationPolicyDays=30; RequiredBy=@('api','web') },
            [pscustomobject]@{ Name='warning-b'; LastRotated='2026-04-01'
                RotationPolicyDays=20; RequiredBy=@('web') },
            [pscustomobject]@{ Name='ok-c'; LastRotated='2026-04-01'
                RotationPolicyDays=90; RequiredBy=@('billing') }
        )
    }

    It 'returns valid JSON' {
        $json = ConvertTo-JsonReport -Report $script:Report
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'contains expired/warning/ok top-level arrays' {
        $json = ConvertTo-JsonReport -Report $script:Report
        $obj  = $json | ConvertFrom-Json
        $obj.expired.Count | Should -Be 1
        $obj.warning.Count | Should -Be 1
        $obj.ok.Count      | Should -Be 1
        $obj.expired[0].name | Should -Be 'expired-a'
        $obj.expired[0].daysUntilRotation | Should -BeLessThan 0
    }

    It 'emits generatedAt, warningDays, totalSecrets as top-level fields' {
        $json = ConvertTo-JsonReport -Report $script:Report
        $obj  = $json | ConvertFrom-Json
        $obj.warningDays  | Should -Be 7
        $obj.totalSecrets | Should -Be 3
        # Assert the raw JSON text holds an ISO-8601 date — ConvertFrom-Json
        # auto-converts ISO strings into [datetime], so we can't regex the
        # parsed object.
        $json | Should -Match '"generatedAt":\s*"\d{4}-\d{2}-\d{2}T'
    }
}

Describe 'Invoke-SecretRotationValidator (entry-point cmdlet)' {
    # Feature 3: a single function that the entry script calls — reads a JSON
    # config from disk, returns the chosen format as a string.

    BeforeAll {
        $script:FixtureDir = Join-Path $TestDrive 'fixtures'
        New-Item -ItemType Directory -Path $script:FixtureDir | Out-Null
        $script:FixturePath = Join-Path $script:FixtureDir 'secrets.json'
        @(
            [pscustomobject]@{ name='expired-a'; lastRotated='2026-01-01'
                rotationPolicyDays=30; requiredBy=@('api','web') },
            [pscustomobject]@{ name='warning-b'; lastRotated='2026-04-01'
                rotationPolicyDays=20; requiredBy=@('web') },
            [pscustomobject]@{ name='ok-c'; lastRotated='2026-04-01'
                rotationPolicyDays=90; requiredBy=@('billing') }
        ) | ConvertTo-Json -Depth 5 | Set-Content -Path $script:FixturePath -Encoding UTF8
    }

    It 'produces markdown output by default' {
        $out = Invoke-SecretRotationValidator -Path $script:FixturePath `
            -WarningDays 7 -Format markdown -Now ([datetime]'2026-04-17')
        $out | Should -Match '# Secret Rotation Report'
        $out | Should -Match 'expired-a'
    }

    It 'produces JSON output when requested' {
        $out = Invoke-SecretRotationValidator -Path $script:FixturePath `
            -WarningDays 7 -Format json -Now ([datetime]'2026-04-17')
        { $out | ConvertFrom-Json } | Should -Not -Throw
        ($out | ConvertFrom-Json).expired[0].name | Should -Be 'expired-a'
    }

    It 'accepts camelCase property names in the JSON config' {
        # JSON idiom is camelCase; the validator should handle it.
        $report = Invoke-SecretRotationValidator -Path $script:FixturePath `
            -WarningDays 7 -Format json -Now ([datetime]'2026-04-17') | ConvertFrom-Json
        $report.totalSecrets | Should -Be 3
    }

    It 'throws a clear error if the config file does not exist' {
        { Invoke-SecretRotationValidator -Path '/no/such/file.json' `
            -WarningDays 7 -Format markdown } |
            Should -Throw -ExpectedMessage "*not found*"
    }

    It 'throws a clear error if the config is not valid JSON' {
        $badPath = Join-Path $TestDrive 'bad.json'
        '{ this is not json' | Set-Content -Path $badPath
        { Invoke-SecretRotationValidator -Path $badPath `
            -WarningDays 7 -Format markdown } |
            Should -Throw -ExpectedMessage "*JSON*"
    }
}
