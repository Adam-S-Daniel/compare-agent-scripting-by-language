# Pester tests for the secret rotation validator.
# Built incrementally with red/green/refactor TDD.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'SecretRotation.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-SecretRotationStatus' {

    Context 'classification of secrets' {

        It 'classifies a secret rotated yesterday with a 30-day policy as ok' {
            $today = [datetime]'2026-05-07'
            $secret = [pscustomobject]@{
                Name           = 'db-password'
                LastRotated    = '2026-05-06'
                RotationDays   = 30
                RequiredBy     = @('api', 'worker')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf $today -WarningDays 7
            $result.Status        | Should -Be 'ok'
            $result.Name          | Should -Be 'db-password'
            $result.DaysUntilDue  | Should -Be 29
        }

        It 'classifies a secret due in 5 days with a 7 day warning window as warning' {
            $today = [datetime]'2026-05-07'
            $secret = [pscustomobject]@{
                Name           = 'api-key'
                LastRotated    = '2026-04-09' # 28 days ago, policy 30 days => due in 2
                RotationDays   = 30
                RequiredBy     = @('api')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf $today -WarningDays 7
            $result.Status        | Should -Be 'warning'
            $result.DaysUntilDue  | Should -Be 2
        }

        It 'classifies a secret past its policy as expired with a positive DaysOverdue' {
            $today = [datetime]'2026-05-07'
            $secret = [pscustomobject]@{
                Name           = 'jwt-signing'
                LastRotated    = '2026-03-01' # 67 days ago, policy 30 => 37 days overdue
                RotationDays   = 30
                RequiredBy     = @('auth')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf $today -WarningDays 7
            $result.Status        | Should -Be 'expired'
            $result.DaysOverdue   | Should -Be 37
            $result.DaysUntilDue  | Should -Be -37
        }

        It 'classifies a secret due exactly today as warning (not yet expired)' {
            # Boundary: due today (DaysUntilDue=0) is still within the warning window.
            $today = [datetime]'2026-05-07'
            $secret = [pscustomobject]@{
                Name         = 'edge-secret'
                LastRotated  = '2026-04-07' # exactly 30 days ago
                RotationDays = 30
                RequiredBy   = @('svc')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf $today -WarningDays 7
            $result.Status       | Should -Be 'warning'
            $result.DaysUntilDue | Should -Be 0
        }
    }

    Context 'input validation' {
        It 'throws a meaningful error when LastRotated is unparseable' {
            $today = [datetime]'2026-05-07'
            $secret = [pscustomobject]@{
                Name         = 'broken'
                LastRotated  = 'not-a-date'
                RotationDays = 30
                RequiredBy   = @('svc')
            }
            { Get-SecretRotationStatus -Secret $secret -AsOf $today -WarningDays 7 } |
                Should -Throw "*Invalid LastRotated*broken*"
        }

        It 'throws when RotationDays is zero or negative' {
            $today = [datetime]'2026-05-07'
            $secret = [pscustomobject]@{
                Name         = 'zero'
                LastRotated  = '2026-05-01'
                RotationDays = 0
                RequiredBy   = @('svc')
            }
            { Get-SecretRotationStatus -Secret $secret -AsOf $today -WarningDays 7 } |
                Should -Throw "*RotationDays*positive*"
        }
    }
}

Describe 'Invoke-SecretRotationReport' {
    BeforeAll {
        $script:Today = [datetime]'2026-05-07'
        $script:Fixture = @(
            [pscustomobject]@{ Name='db';   LastRotated='2026-04-30'; RotationDays=90; RequiredBy=@('api') }       # ok
            [pscustomobject]@{ Name='jwt';  LastRotated='2026-04-09'; RotationDays=30; RequiredBy=@('auth') }      # warning (due in 2)
            [pscustomobject]@{ Name='ssh';  LastRotated='2026-01-01'; RotationDays=60; RequiredBy=@('infra') }     # expired
        )
    }

    It 'groups secrets into expired, warning and ok buckets' {
        $report = Invoke-SecretRotationReport -Secrets $script:Fixture -AsOf $script:Today -WarningDays 7
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count      | Should -Be 1
        $report.Expired[0].Name | Should -Be 'ssh'
        $report.Warning[0].Name | Should -Be 'jwt'
        $report.Ok[0].Name      | Should -Be 'db'
    }

    It 'returns a summary count of total/expired/warning/ok' {
        $report = Invoke-SecretRotationReport -Secrets $script:Fixture -AsOf $script:Today -WarningDays 7
        $report.Summary.Total   | Should -Be 3
        $report.Summary.Expired | Should -Be 1
        $report.Summary.Warning | Should -Be 1
        $report.Summary.Ok      | Should -Be 1
    }

    It 'sorts expired secrets by most overdue first' {
        $secrets = @(
            [pscustomobject]@{ Name='a'; LastRotated='2026-04-01'; RotationDays=30; RequiredBy=@('x') } # 6 overdue
            [pscustomobject]@{ Name='b'; LastRotated='2026-01-01'; RotationDays=30; RequiredBy=@('x') } # 96 overdue
            [pscustomobject]@{ Name='c'; LastRotated='2026-03-01'; RotationDays=30; RequiredBy=@('x') } # 37 overdue
        )
        $report = Invoke-SecretRotationReport -Secrets $secrets -AsOf $script:Today -WarningDays 7
        $report.Expired[0].Name | Should -Be 'b'
        $report.Expired[1].Name | Should -Be 'c'
        $report.Expired[2].Name | Should -Be 'a'
    }
}

Describe 'Format-SecretRotationReport' {

    BeforeAll {
        $script:Today = [datetime]'2026-05-07'
        $script:Fixture = @(
            [pscustomobject]@{ Name='db';  LastRotated='2026-04-30'; RotationDays=90; RequiredBy=@('api') }
            [pscustomobject]@{ Name='jwt'; LastRotated='2026-04-09'; RotationDays=30; RequiredBy=@('auth') }
            [pscustomobject]@{ Name='ssh'; LastRotated='2026-01-01'; RotationDays=60; RequiredBy=@('infra') }
        )
        $script:Report = Invoke-SecretRotationReport -Secrets $script:Fixture -AsOf $script:Today -WarningDays 7
    }

    Context 'markdown output' {
        It 'produces a markdown table with section headers per urgency' {
            $md = Format-SecretRotationReport -Report $script:Report -Format markdown
            $md | Should -Match '## Expired'
            $md | Should -Match '## Warning'
            $md | Should -Match '## Ok'
            $md | Should -Match '\| Name \| Last Rotated \| Policy \(days\) \| Days Until Due \| Required By \|'
        }

        It 'includes the summary line with total counts' {
            $md = Format-SecretRotationReport -Report $script:Report -Format markdown
            $md | Should -Match 'Total: 3.*Expired: 1.*Warning: 1.*Ok: 1'
        }

        It 'lists each expired secret in the Expired section' {
            $md = Format-SecretRotationReport -Report $script:Report -Format markdown
            $expiredSection = ($md -split '## Warning')[0]
            $expiredSection | Should -Match '\| ssh \|'
        }
    }

    Context 'json output' {
        It 'returns parseable JSON with expired, warning, ok keys and summary' {
            $json = Format-SecretRotationReport -Report $script:Report -Format json
            $obj  = $json | ConvertFrom-Json
            $obj.summary.total   | Should -Be 3
            $obj.summary.expired | Should -Be 1
            $obj.expired[0].name | Should -Be 'ssh'
            $obj.warning[0].name | Should -Be 'jwt'
            $obj.ok[0].name      | Should -Be 'db'
        }
    }

    Context 'invalid format' {
        It 'rejects unknown formats with a meaningful error' {
            { Format-SecretRotationReport -Report $script:Report -Format yaml } |
                Should -Throw "*format*"
        }
    }
}

Describe 'Read-SecretConfig' {
    BeforeAll {
        $script:TempFile = Join-Path $TestDrive 'secrets.json'
        @(
            [pscustomobject]@{ Name='a'; LastRotated='2026-04-01'; RotationDays=30; RequiredBy=@('s1') }
            [pscustomobject]@{ Name='b'; LastRotated='2026-01-01'; RotationDays=60; RequiredBy=@('s2') }
        ) | ConvertTo-Json | Set-Content -Path $script:TempFile
    }

    It 'loads a JSON file into an array of secret objects' {
        $secrets = Read-SecretConfig -Path $script:TempFile
        $secrets.Count | Should -Be 2
        $secrets[0].Name | Should -Be 'a'
    }

    It 'throws a clear error when the file does not exist' {
        { Read-SecretConfig -Path (Join-Path $TestDrive 'missing.json') } |
            Should -Throw "*not found*"
    }

    It 'throws a clear error when JSON is malformed' {
        $bad = Join-Path $TestDrive 'bad.json'
        '{ this is not valid json' | Set-Content -Path $bad
        { Read-SecretConfig -Path $bad } | Should -Throw "*JSON*"
    }
}

Describe 'Invoke-SecretRotationValidator end-to-end (script entrypoint)' {
    BeforeAll {
        $script:ScriptPath  = Join-Path $PSScriptRoot '..' 'src' 'Invoke-SecretRotationValidator.ps1'
        $script:FixturePath = Join-Path $TestDrive 'fixture.json'
        @(
            [pscustomobject]@{ Name='db';  LastRotated='2026-04-30'; RotationDays=90; RequiredBy=@('api') }
            [pscustomobject]@{ Name='jwt'; LastRotated='2026-04-09'; RotationDays=30; RequiredBy=@('auth') }
            [pscustomobject]@{ Name='ssh'; LastRotated='2026-01-01'; RotationDays=60; RequiredBy=@('infra') }
        ) | ConvertTo-Json | Set-Content -Path $script:FixturePath
    }

    It 'prints a markdown report to stdout when -Format markdown' {
        $output = & $script:ScriptPath -ConfigPath $script:FixturePath -Format markdown -AsOf '2026-05-07' -WarningDays 7
        ($output -join "`n") | Should -Match '## Expired'
        ($output -join "`n") | Should -Match '\| ssh \|'
    }

    It 'prints valid JSON when -Format json' {
        $output = & $script:ScriptPath -ConfigPath $script:FixturePath -Format json -AsOf '2026-05-07' -WarningDays 7
        $obj = ($output -join "`n") | ConvertFrom-Json
        $obj.summary.expired | Should -Be 1
    }

    It 'exits with code 1 when any secret is expired and -FailOnExpired is set' {
        $null = & $script:ScriptPath -ConfigPath $script:FixturePath -Format markdown -AsOf '2026-05-07' -WarningDays 7 -FailOnExpired
        $LASTEXITCODE | Should -Be 1
    }

    It 'exits with code 0 when nothing is expired even with -FailOnExpired' {
        $okFile = Join-Path $TestDrive 'ok.json'
        @(
            [pscustomobject]@{ Name='db'; LastRotated='2026-05-01'; RotationDays=90; RequiredBy=@('api') }
        ) | ConvertTo-Json | Set-Content -Path $okFile
        $null = & $script:ScriptPath -ConfigPath $okFile -Format markdown -AsOf '2026-05-07' -WarningDays 7 -FailOnExpired
        $LASTEXITCODE | Should -Be 0
    }
}
