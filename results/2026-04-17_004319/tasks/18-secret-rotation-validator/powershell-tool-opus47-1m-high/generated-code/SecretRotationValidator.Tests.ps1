#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

# Pester tests for SecretRotationValidator. Follow red/green/refactor TDD:
# each Describe block exercises one function and encodes our expectations
# before implementation. The module is imported relative to the test file.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-SecretStatus' {
    It 'classifies a secret rotated inside its policy window as ok' {
        $secret = [pscustomobject]@{
            name               = 'svc-api-key'
            lastRotated        = '2026-04-01'
            rotationPolicyDays = 90
            requiredBy         = @('api')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate '2026-04-19' -WarningDays 14
        $result.Status | Should -Be 'ok'
        $result.DaysUntilRotation | Should -Be 72
        $result.Name | Should -Be 'svc-api-key'
    }

    It 'classifies a secret past its rotation date as expired' {
        $secret = [pscustomobject]@{
            name               = 'db-password'
            lastRotated        = '2025-12-01'
            rotationPolicyDays = 90
            requiredBy         = @('api', 'worker')
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate '2026-04-19' -WarningDays 14
        $result.Status | Should -Be 'expired'
        $result.DaysUntilRotation | Should -BeLessThan 0
    }

    It 'classifies a secret inside the warning window as warning' {
        $secret = [pscustomobject]@{
            name               = 'tls-cert'
            lastRotated        = '2026-01-25'
            rotationPolicyDays = 90
            requiredBy         = @('gateway')
        }
        # rotation due 2026-04-25, reference 2026-04-19 -> 6 days out, inside 14-day window
        $result = Get-SecretStatus -Secret $secret -ReferenceDate '2026-04-19' -WarningDays 14
        $result.Status | Should -Be 'warning'
        $result.DaysUntilRotation | Should -Be 6
    }

    It 'throws a meaningful error when lastRotated is missing' {
        $bad = [pscustomobject]@{
            name               = 'broken'
            rotationPolicyDays = 30
            requiredBy         = @('x')
        }
        { Get-SecretStatus -Secret $bad -ReferenceDate '2026-04-19' -WarningDays 7 } |
            Should -Throw "*lastRotated*"
    }

    It 'throws a meaningful error when rotationPolicyDays is not positive' {
        $bad = [pscustomobject]@{
            name               = 'broken'
            lastRotated        = '2026-04-01'
            rotationPolicyDays = 0
            requiredBy         = @('x')
        }
        { Get-SecretStatus -Secret $bad -ReferenceDate '2026-04-19' -WarningDays 7 } |
            Should -Throw "*rotationPolicyDays*"
    }

    It 'throws a meaningful error when lastRotated is not a valid date' {
        $bad = [pscustomobject]@{
            name               = 'broken'
            lastRotated        = 'not-a-date'
            rotationPolicyDays = 30
            requiredBy         = @('x')
        }
        { Get-SecretStatus -Secret $bad -ReferenceDate '2026-04-19' -WarningDays 7 } |
            Should -Throw "*not-a-date*"
    }
}

Describe 'Get-RotationReport' {
    BeforeAll {
        $script:Secrets = @(
            [pscustomobject]@{ name = 'ok-secret';      lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('api') }
            [pscustomobject]@{ name = 'warning-secret'; lastRotated = '2026-01-25'; rotationPolicyDays = 90; requiredBy = @('gateway') }
            [pscustomobject]@{ name = 'expired-secret'; lastRotated = '2025-12-01'; rotationPolicyDays = 90; requiredBy = @('api','worker') }
        )
    }

    It 'groups secrets by urgency bucket' {
        $report = Get-RotationReport -Secrets $script:Secrets -ReferenceDate '2026-04-19' -WarningDays 14
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count      | Should -Be 1
        $report.Expired[0].Name | Should -Be 'expired-secret'
        $report.Warning[0].Name | Should -Be 'warning-secret'
        $report.Ok[0].Name      | Should -Be 'ok-secret'
    }

    It 'includes metadata with reference date and warning window' {
        $report = Get-RotationReport -Secrets $script:Secrets -ReferenceDate '2026-04-19' -WarningDays 14
        $report.ReferenceDate | Should -Be '2026-04-19'
        $report.WarningDays   | Should -Be 14
        $report.TotalSecrets  | Should -Be 3
    }

    It 'sorts expired secrets most-overdue first' {
        $manySecrets = @(
            [pscustomobject]@{ name = 'recently-expired'; lastRotated = '2026-01-01'; rotationPolicyDays = 90; requiredBy = @('a') }
            [pscustomobject]@{ name = 'long-expired';     lastRotated = '2025-06-01'; rotationPolicyDays = 90; requiredBy = @('b') }
        )
        $report = Get-RotationReport -Secrets $manySecrets -ReferenceDate '2026-04-19' -WarningDays 14
        $report.Expired[0].Name | Should -Be 'long-expired'
        $report.Expired[1].Name | Should -Be 'recently-expired'
    }

    It 'returns empty buckets (not null) when no secrets match' {
        $onlyOk = @(
            [pscustomobject]@{ name = 'fresh'; lastRotated = '2026-04-18'; rotationPolicyDays = 90; requiredBy = @('a') }
        )
        $report = Get-RotationReport -Secrets $onlyOk -ReferenceDate '2026-04-19' -WarningDays 14
        ,$report.Expired | Should -BeOfType [System.Array]
        ,$report.Warning | Should -BeOfType [System.Array]
        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.Ok.Count      | Should -Be 1
    }
}

Describe 'Format-RotationReport' {
    BeforeAll {
        $script:Secrets = @(
            [pscustomobject]@{ name = 'ok-secret';      lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('api') }
            [pscustomobject]@{ name = 'warning-secret'; lastRotated = '2026-01-25'; rotationPolicyDays = 90; requiredBy = @('gateway') }
            [pscustomobject]@{ name = 'expired-secret'; lastRotated = '2025-12-01'; rotationPolicyDays = 90; requiredBy = @('api','worker') }
        )
        $script:Report = Get-RotationReport -Secrets $script:Secrets -ReferenceDate '2026-04-19' -WarningDays 14
    }

    Context 'markdown format' {
        It 'emits a markdown header and urgency sections' {
            $md = Format-RotationReport -Report $script:Report -Format markdown
            $md | Should -Match '# Secret Rotation Report'
            $md | Should -Match '## Expired'
            $md | Should -Match '## Warning'
            $md | Should -Match '## Ok'
        }

        It 'renders a table row per secret with required-by services joined' {
            $md = Format-RotationReport -Report $script:Report -Format markdown
            $md | Should -Match 'expired-secret'
            $md | Should -Match 'api, worker'
            $md | Should -Match '\| Name \| Last Rotated \| Policy \(days\) \| Days Until Rotation \| Required By \|'
        }
    }

    Context 'json format' {
        It 'emits valid JSON parseable back into the same shape' {
            $json = Format-RotationReport -Report $script:Report -Format json
            $parsed = $json | ConvertFrom-Json
            $parsed.ReferenceDate | Should -Be '2026-04-19'
            $parsed.WarningDays   | Should -Be 14
            $parsed.Expired.Count | Should -Be 1
            $parsed.Expired[0].Name | Should -Be 'expired-secret'
        }
    }

    It 'throws on an unknown format' {
        { Format-RotationReport -Report $script:Report -Format xml } | Should -Throw
    }
}

Describe 'Invoke-SecretRotationValidator (end-to-end)' {
    BeforeAll {
        $script:FixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-tests-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:FixtureDir | Out-Null

        $script:ConfigPath = Join-Path $script:FixtureDir 'secrets.json'
        @(
            [pscustomobject]@{ name = 'ok-secret';      lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('api') }
            [pscustomobject]@{ name = 'warning-secret'; lastRotated = '2026-01-25'; rotationPolicyDays = 90; requiredBy = @('gateway') }
            [pscustomobject]@{ name = 'expired-secret'; lastRotated = '2025-12-01'; rotationPolicyDays = 90; requiredBy = @('api','worker') }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $script:ConfigPath
    }

    AfterAll {
        if (Test-Path $script:FixtureDir) { Remove-Item -Recurse -Force $script:FixtureDir }
    }

    It 'reads a config file, produces a report, and returns exit metadata' {
        $result = Invoke-SecretRotationValidator -ConfigPath $script:ConfigPath `
            -ReferenceDate '2026-04-19' -WarningDays 14 -Format json
        $parsed = $result.Output | ConvertFrom-Json
        $parsed.Expired.Count | Should -Be 1
        $result.ExitCode | Should -Be 2   # any expired -> exit 2
    }

    It 'returns exit code 1 when only warnings present, 0 otherwise' {
        $onlyWarn = Join-Path $script:FixtureDir 'warn.json'
        @([pscustomobject]@{ name = 'w'; lastRotated = '2026-01-25'; rotationPolicyDays = 90; requiredBy = @('a') }) |
            ConvertTo-Json -Depth 4 | Set-Content -Path $onlyWarn
        $r = Invoke-SecretRotationValidator -ConfigPath $onlyWarn -ReferenceDate '2026-04-19' -WarningDays 14 -Format markdown
        $r.ExitCode | Should -Be 1

        $onlyOk = Join-Path $script:FixtureDir 'ok.json'
        @([pscustomobject]@{ name = 'o'; lastRotated = '2026-04-18'; rotationPolicyDays = 90; requiredBy = @('a') }) |
            ConvertTo-Json -Depth 4 | Set-Content -Path $onlyOk
        $r2 = Invoke-SecretRotationValidator -ConfigPath $onlyOk -ReferenceDate '2026-04-19' -WarningDays 14 -Format markdown
        $r2.ExitCode | Should -Be 0
    }

    It 'throws a meaningful error when the config file is missing' {
        { Invoke-SecretRotationValidator -ConfigPath '/no/such/file.json' -ReferenceDate '2026-04-19' -WarningDays 14 -Format json } |
            Should -Throw "*not found*"
    }

    It 'handles an empty-array config without error (exit 0)' {
        $empty = Join-Path $script:FixtureDir 'empty.json'
        '[]' | Set-Content -Path $empty
        $r = Invoke-SecretRotationValidator -ConfigPath $empty -ReferenceDate '2026-04-19' -WarningDays 14 -Format json
        $r.ExitCode | Should -Be 0
        $parsed = $r.Output | ConvertFrom-Json
        $parsed.TotalSecrets | Should -Be 0
    }

    It 'throws a meaningful error when the config is not valid JSON' {
        $bad = Join-Path $script:FixtureDir 'bad.json'
        'not json at all' | Set-Content -Path $bad
        { Invoke-SecretRotationValidator -ConfigPath $bad -ReferenceDate '2026-04-19' -WarningDays 14 -Format json } |
            Should -Throw "*JSON*"
    }
}
