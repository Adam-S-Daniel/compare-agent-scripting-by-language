# Pester tests for the secret rotation validator.
# Approach: each Describe block exercises one piece of behavior, written before
# (or in lockstep with) the implementation under TDD. Tests pin a fixed "AsOf"
# date so they are deterministic regardless of when they run.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulePath = Join-Path $RepoRoot 'src/SecretRotationValidator.psm1'
    $script:ScriptPath = Join-Path $RepoRoot 'Invoke-SecretRotationValidator.ps1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-SecretStatus' {
    BeforeAll {
        $script:AsOf = [datetime]'2026-05-07'
    }

    It 'computes the expiry date as lastRotated + rotationPolicyDays' {
        $secret = [pscustomobject]@{
            name               = 'API_KEY'
            lastRotated        = '2026-04-15'
            rotationPolicyDays = 30
            requiredBy         = @('billing-svc')
        }
        $status = Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 14
        $status.expiresOn | Should -Be '2026-05-15'
        $status.daysUntilExpiry | Should -Be 8
    }

    It 'classifies a long-past secret as expired' {
        $secret = [pscustomobject]@{
            name               = 'DB_PASSWORD'
            lastRotated        = '2025-01-01'
            rotationPolicyDays = 90
            requiredBy         = @('orders-svc', 'reporting-svc')
        }
        (Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 14).urgency `
            | Should -Be 'expired'
    }

    It 'classifies a secret inside the warning window as warning' {
        $secret = [pscustomobject]@{
            name               = 'API_KEY'
            lastRotated        = '2026-04-15'
            rotationPolicyDays = 30
            requiredBy         = @('billing-svc')
        }
        (Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 14).urgency `
            | Should -Be 'warning'
    }

    It 'classifies a secret outside the warning window as ok' {
        $secret = [pscustomobject]@{
            name               = 'TLS_CERT'
            lastRotated        = '2026-04-01'
            rotationPolicyDays = 365
            requiredBy         = @('public-api')
        }
        (Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 14).urgency `
            | Should -Be 'ok'
    }

    It 'treats a secret expiring exactly today as warning, not expired' {
        # On the day of expiry, daysUntilExpiry == 0 -> still time to rotate.
        $secret = [pscustomobject]@{
            name               = 'TODAY_KEY'
            lastRotated        = '2026-04-07'
            rotationPolicyDays = 30
            requiredBy         = @('svc')
        }
        $status = Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 14
        $status.daysUntilExpiry | Should -Be 0
        $status.urgency         | Should -Be 'warning'
    }

    It 'respects a configurable warning window' {
        $secret = [pscustomobject]@{
            name               = 'API_KEY'
            lastRotated        = '2026-04-15'
            rotationPolicyDays = 30
            requiredBy         = @('billing-svc')
        }
        # 8 days out -> outside a 3-day window -> ok
        (Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 3).urgency `
            | Should -Be 'ok'
    }

    It 'throws a clear error when a required field is missing' {
        $secret = [pscustomobject]@{
            name        = 'INCOMPLETE'
            lastRotated = '2026-04-15'
            # rotationPolicyDays and requiredBy missing
        }
        { Get-SecretStatus -Secret $secret -AsOf $AsOf -WarningWindowDays 14 } `
            | Should -Throw "*rotationPolicyDays*"
    }
}

Describe 'Get-SecretRotationReport' {
    BeforeAll {
        $script:AsOf = [datetime]'2026-05-07'
        $script:Secrets = @(
            [pscustomobject]@{ name='DB_PASSWORD'; lastRotated='2025-01-01'; rotationPolicyDays=90;  requiredBy=@('orders-svc') },
            [pscustomobject]@{ name='API_KEY';     lastRotated='2026-04-15'; rotationPolicyDays=30;  requiredBy=@('billing-svc') },
            [pscustomobject]@{ name='TLS_CERT';    lastRotated='2026-04-01'; rotationPolicyDays=365; requiredBy=@('public-api') }
        )
    }

    It 'groups secrets by urgency with correct summary counts' {
        $report = Get-SecretRotationReport -Secrets $Secrets -AsOf $AsOf -WarningWindowDays 14
        $report.summary.total   | Should -Be 3
        $report.summary.expired | Should -Be 1
        $report.summary.warning | Should -Be 1
        $report.summary.ok      | Should -Be 1
        $report.expired[0].name | Should -Be 'DB_PASSWORD'
        $report.warning[0].name | Should -Be 'API_KEY'
        $report.ok[0].name      | Should -Be 'TLS_CERT'
    }

    It 'produces zero counts for an empty input' {
        $report = Get-SecretRotationReport -Secrets @() -AsOf $AsOf -WarningWindowDays 14
        $report.summary.total   | Should -Be 0
        $report.summary.expired | Should -Be 0
        $report.summary.warning | Should -Be 0
        $report.summary.ok      | Should -Be 0
    }

    It 'records the asOf date and warning window on the report' {
        $report = Get-SecretRotationReport -Secrets $Secrets -AsOf $AsOf -WarningWindowDays 21
        $report.asOf              | Should -Be '2026-05-07'
        $report.warningWindowDays | Should -Be 21
    }
}

Describe 'Format-RotationReport' {
    BeforeAll {
        $script:AsOf = [datetime]'2026-05-07'
        $script:Secrets = @(
            [pscustomobject]@{ name='DB_PASSWORD'; lastRotated='2025-01-01'; rotationPolicyDays=90;  requiredBy=@('orders-svc') },
            [pscustomobject]@{ name='API_KEY';     lastRotated='2026-04-15'; rotationPolicyDays=30;  requiredBy=@('billing-svc','admin-ui') },
            [pscustomobject]@{ name='TLS_CERT';    lastRotated='2026-04-01'; rotationPolicyDays=365; requiredBy=@('public-api') }
        )
        $script:Report = Get-SecretRotationReport -Secrets $Secrets -AsOf $AsOf -WarningWindowDays 14
    }

    It 'renders markdown with grouped sections and a summary' {
        $md = Format-RotationReport -Report $Report -Format 'markdown'
        $md | Should -Match '# Secret Rotation Report'
        $md | Should -Match '## Expired \(1\)'
        $md | Should -Match '## Warning \(1\)'
        $md | Should -Match '## OK \(1\)'
        $md | Should -Match 'DB_PASSWORD'
        $md | Should -Match 'API_KEY'
        $md | Should -Match 'TLS_CERT'
        # Required-by services are joined with ", "
        $md | Should -Match 'billing-svc, admin-ui'
    }

    It 'renders JSON that round-trips to the same shape as the report' {
        $json = Format-RotationReport -Report $Report -Format 'json'
        $obj  = $json | ConvertFrom-Json
        $obj.summary.expired | Should -Be 1
        $obj.summary.warning | Should -Be 1
        $obj.summary.ok      | Should -Be 1
        $obj.expired[0].name | Should -Be 'DB_PASSWORD'
    }

    It 'rejects an unknown format with a clear error' {
        { Format-RotationReport -Report $Report -Format 'xml' } | Should -Throw '*format*'
    }
}

Describe 'Invoke-SecretRotationValidator.ps1 (CLI)' {
    BeforeAll {
        $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("srv-cli-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $TestRoot | Out-Null
        $script:CfgPath = Join-Path $TestRoot 'secrets.json'
        @{
            secrets = @(
                @{ name='DB_PASSWORD'; lastRotated='2025-01-01'; rotationPolicyDays=90;  requiredBy=@('orders-svc') },
                @{ name='API_KEY';     lastRotated='2026-04-15'; rotationPolicyDays=30;  requiredBy=@('billing-svc') },
                @{ name='TLS_CERT';    lastRotated='2026-04-01'; rotationPolicyDays=365; requiredBy=@('public-api') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $CfgPath
    }

    AfterAll {
        if (Test-Path $TestRoot) { Remove-Item -Recurse -Force $TestRoot }
    }

    It 'exits 0 and emits markdown by default' {
        $out = & pwsh -NoProfile -File $ScriptPath -ConfigPath $CfgPath -Today '2026-05-07' -WarningWindowDays 14
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '# Secret Rotation Report'
        ($out -join "`n") | Should -Match '## Expired \(1\)'
    }

    It 'emits valid JSON when -Format json is given' {
        $out = & pwsh -NoProfile -File $ScriptPath -ConfigPath $CfgPath -Today '2026-05-07' -WarningWindowDays 14 -Format json
        $LASTEXITCODE | Should -Be 0
        $obj = ($out -join "`n") | ConvertFrom-Json
        $obj.summary.total   | Should -Be 3
        $obj.summary.expired | Should -Be 1
    }

    It 'handles a config with an empty secrets array as JSON' {
        $emptyCfg = Join-Path $TestRoot 'empty.json'
        '{ "secrets": [] }' | Set-Content -LiteralPath $emptyCfg
        $out = & pwsh -NoProfile -File $ScriptPath -ConfigPath $emptyCfg -Today '2026-05-07' -Format json
        $LASTEXITCODE | Should -Be 0
        $obj = ($out -join "`n") | ConvertFrom-Json
        $obj.summary.total | Should -Be 0
    }

    It 'exits non-zero with a helpful error when the config file is missing' {
        $missing = Join-Path $TestRoot 'does-not-exist.json'
        $err = & pwsh -NoProfile -File $ScriptPath -ConfigPath $missing -Today '2026-05-07' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($err -join "`n") | Should -Match 'not found'
    }

    It 'exits non-zero with a helpful error when the JSON is malformed' {
        $bad = Join-Path $TestRoot 'bad.json'
        Set-Content -LiteralPath $bad -Value '{ not valid json'
        $err = & pwsh -NoProfile -File $ScriptPath -ConfigPath $bad -Today '2026-05-07' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($err -join "`n") | Should -Match 'parse'
    }
}
