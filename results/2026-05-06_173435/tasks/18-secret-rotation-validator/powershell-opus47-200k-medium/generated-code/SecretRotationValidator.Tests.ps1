# Pester v5 tests for the secret rotation validator.
# TDD: these tests are written first; the implementation is then built up to satisfy them.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $ModulePath -Force

    # Reference "today" for deterministic age math. All fixtures below are
    # expressed relative to this date.
    $script:Today = [datetime]'2026-05-08'
}

AfterAll {
    Remove-Module SecretRotationValidator -ErrorAction SilentlyContinue
}

Describe 'Get-SecretStatus (single secret classification)' {
    It 'classifies a freshly rotated secret as ok' {
        $secret = [pscustomobject]@{
            name           = 'db-password'
            lastRotated    = '2026-05-01'   # 7 days ago
            rotationDays   = 90
            requiredBy     = @('api')
        }
        $result = Get-SecretStatus -Secret $secret -Today $script:Today -WarningDays 14
        $result.status      | Should -Be 'ok'
        $result.daysOverdue | Should -Be -83   # 83 days remaining
    }

    It 'classifies a secret inside the warning window as warning' {
        $secret = [pscustomobject]@{
            name         = 'api-key'
            lastRotated  = '2026-02-15'   # 82 days ago
            rotationDays = 90
            requiredBy   = @('frontend')
        }
        $result = Get-SecretStatus -Secret $secret -Today $script:Today -WarningDays 14
        $result.status | Should -Be 'warning'
    }

    It 'classifies a secret past its rotation policy as expired' {
        $secret = [pscustomobject]@{
            name         = 'old-token'
            lastRotated  = '2025-10-01'   # >180 days ago
            rotationDays = 90
            requiredBy   = @('worker')
        }
        $result = Get-SecretStatus -Secret $secret -Today $script:Today -WarningDays 14
        $result.status      | Should -Be 'expired'
        $result.daysOverdue | Should -BeGreaterThan 0
    }

    It 'throws a meaningful error when lastRotated is missing' {
        $bad = [pscustomobject]@{ name = 'x'; rotationDays = 30; requiredBy = @() }
        { Get-SecretStatus -Secret $bad -Today $script:Today -WarningDays 7 } |
            Should -Throw '*lastRotated*'
    }

    It 'throws a meaningful error when rotationDays is missing or non-positive' {
        $bad = [pscustomobject]@{ name = 'x'; lastRotated = '2026-01-01'; rotationDays = 0; requiredBy = @() }
        { Get-SecretStatus -Secret $bad -Today $script:Today -WarningDays 7 } |
            Should -Throw '*rotationDays*'
    }
}

Describe 'Get-SecretRotationReport (grouping and aggregation)' {
    BeforeAll {
        $script:Secrets = @(
            [pscustomobject]@{ name='ok-1';       lastRotated='2026-05-01'; rotationDays=90; requiredBy=@('api') }
            [pscustomobject]@{ name='warn-1';     lastRotated='2026-02-15'; rotationDays=90; requiredBy=@('web') }
            [pscustomobject]@{ name='expired-1';  lastRotated='2025-10-01'; rotationDays=90; requiredBy=@('worker','api') }
            [pscustomobject]@{ name='expired-2';  lastRotated='2025-01-01'; rotationDays=30; requiredBy=@('cron') }
        )
    }

    It 'groups secrets into expired / warning / ok buckets' {
        $report = Get-SecretRotationReport -Secrets $script:Secrets -Today $script:Today -WarningDays 14
        $report.expired.Count | Should -Be 2
        $report.warning.Count | Should -Be 1
        $report.ok.Count      | Should -Be 1
    }

    It 'sorts expired secrets by most-overdue first' {
        $report = Get-SecretRotationReport -Secrets $script:Secrets -Today $script:Today -WarningDays 14
        # expired-2: rotated 2025-01-01, policy 30d => ~462 days overdue
        # expired-1: rotated 2025-10-01, policy 90d => ~129 days overdue
        $report.expired[0].name | Should -Be 'expired-2'
        $report.expired[1].name | Should -Be 'expired-1'
    }

    It 'reports correct summary counts' {
        $report = Get-SecretRotationReport -Secrets $script:Secrets -Today $script:Today -WarningDays 14
        $report.summary.total   | Should -Be 4
        $report.summary.expired | Should -Be 2
        $report.summary.warning | Should -Be 1
        $report.summary.ok      | Should -Be 1
    }

    It 'returns empty buckets gracefully for an empty input' {
        $report = Get-SecretRotationReport -Secrets @() -Today $script:Today -WarningDays 14
        $report.summary.total | Should -Be 0
        $report.expired.Count | Should -Be 0
        $report.warning.Count | Should -Be 0
        $report.ok.Count      | Should -Be 0
    }
}

Describe 'Format-SecretRotationReport (output formats)' {
    BeforeAll {
        $script:Secrets = @(
            [pscustomobject]@{ name='ok-1';      lastRotated='2026-05-01'; rotationDays=90; requiredBy=@('api') }
            [pscustomobject]@{ name='expired-1'; lastRotated='2025-10-01'; rotationDays=90; requiredBy=@('worker','api') }
        )
        $script:Report = Get-SecretRotationReport -Secrets $script:Secrets -Today $script:Today -WarningDays 14
    }

    It 'produces a markdown table with section headers' {
        $md = Format-SecretRotationReport -Report $script:Report -Format markdown
        $md | Should -Match '## Expired'
        $md | Should -Match '## OK'
        $md | Should -Match '\| Name \| Last Rotated \| Policy \(days\) \| Days Overdue \| Required By \|'
        $md | Should -Match 'expired-1'
        $md | Should -Match 'worker, api'
    }

    It 'produces parseable JSON with the same structure as the report' {
        $json = Format-SecretRotationReport -Report $script:Report -Format json
        $parsed = $json | ConvertFrom-Json
        $parsed.summary.total   | Should -Be 2
        $parsed.summary.expired | Should -Be 1
        $parsed.expired[0].name | Should -Be 'expired-1'
    }

    It 'rejects an unknown format' {
        { Format-SecretRotationReport -Report $script:Report -Format xml } |
            Should -Throw '*Format*'
    }
}

Describe 'Invoke-Validator.ps1 (CLI entry point)' {
    BeforeAll {
        $script:Cli = Join-Path $PSScriptRoot 'Invoke-Validator.ps1'
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-test-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
    }

    It 'reads a JSON config and prints a markdown report' {
        $cfg = Join-Path $script:TempDir 'cfg.json'
        @(
            @{ name='ok-1';      lastRotated='2026-05-01'; rotationDays=90; requiredBy=@('api') }
            @{ name='expired-1'; lastRotated='2025-10-01'; rotationDays=90; requiredBy=@('worker') }
        ) | ConvertTo-Json -Depth 5 | Set-Content -Path $cfg

        $out = & pwsh -NoProfile -File $script:Cli -ConfigPath $cfg -WarningDays 14 -Format markdown -Today '2026-05-08' 2>&1
        $LASTEXITCODE | Should -Be 2   # expired present => non-zero exit
        ($out -join "`n") | Should -Match 'expired-1'
        ($out -join "`n") | Should -Match '## Expired'
    }

    It 'exits 0 when nothing is expired or warning' {
        $cfg = Join-Path $script:TempDir 'cfg-ok.json'
        @(
            @{ name='ok-1'; lastRotated='2026-05-01'; rotationDays=90; requiredBy=@('api') }
        ) | ConvertTo-Json -Depth 5 | Set-Content -Path $cfg

        $null = & pwsh -NoProfile -File $script:Cli -ConfigPath $cfg -WarningDays 14 -Format json -Today '2026-05-08' 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It 'exits 1 when only warnings are present' {
        $cfg = Join-Path $script:TempDir 'cfg-warn.json'
        @(
            @{ name='warn-1'; lastRotated='2026-02-15'; rotationDays=90; requiredBy=@('web') }
        ) | ConvertTo-Json -Depth 5 | Set-Content -Path $cfg

        $null = & pwsh -NoProfile -File $script:Cli -ConfigPath $cfg -WarningDays 14 -Format json -Today '2026-05-08' 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It 'errors clearly when the config file is missing' {
        $out = & pwsh -NoProfile -File $script:Cli -ConfigPath '/nonexistent/nope.json' -WarningDays 14 -Format json -Today '2026-05-08' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($out -join "`n") | Should -Match 'not found'
    }
}

Describe 'Workflow file structure' {
    BeforeAll {
        $script:WfPath = Join-Path $PSScriptRoot '.github/workflows/secret-rotation-validator.yml'
    }

    It 'exists' {
        Test-Path $script:WfPath | Should -BeTrue
    }

    It 'declares the expected triggers' {
        $content = Get-Content $script:WfPath -Raw
        $content | Should -Match '(?m)^on:'
        $content | Should -Match 'push:'
        $content | Should -Match 'pull_request:'
        $content | Should -Match 'workflow_dispatch:'
        $content | Should -Match 'schedule:'
    }

    It 'references the validator script' {
        $content = Get-Content $script:WfPath -Raw
        $content | Should -Match 'Invoke-Validator\.ps1'
    }

    It 'uses checkout@v4 and shell: pwsh' {
        $content = Get-Content $script:WfPath -Raw
        $content | Should -Match 'actions/checkout@v4'
        $content | Should -Match 'shell:\s*pwsh'
    }

    It 'passes actionlint' -Skip:(-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
        $null = & actionlint $script:WfPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
