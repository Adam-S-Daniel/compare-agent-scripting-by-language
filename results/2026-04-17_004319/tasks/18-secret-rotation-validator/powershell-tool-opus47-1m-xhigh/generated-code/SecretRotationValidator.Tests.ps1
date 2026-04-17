# Pester tests for SecretRotationValidator.
# Red/green TDD: each Describe block was added test-first, then the module
# was grown until these tests pass. Tests stay deterministic by pinning
# "now" via -Now parameter so we never depend on wall-clock time.

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module SecretRotationValidator -ErrorAction SilentlyContinue
}

Describe 'Get-SecretRotationStatus' {
    It 'classifies a secret rotated today as ok when policy > 0' {
        $secret = [pscustomobject]@{
            name          = 'api-key'
            lastRotated   = '2026-04-17'
            rotationDays  = 90
            requiredBy    = @('svc-a')
        }
        $result = Get-SecretRotationStatus -Secret $secret -WarningDays 14 -Now '2026-04-17'
        $result.Status | Should -Be 'ok'
        $result.DaysUntilExpiry | Should -Be 90
    }

    It 'classifies a secret past its policy window as expired' {
        $secret = [pscustomobject]@{
            name          = 'db-password'
            lastRotated   = '2025-01-01'
            rotationDays  = 30
            requiredBy    = @('svc-b')
        }
        $result = Get-SecretRotationStatus -Secret $secret -WarningDays 14 -Now '2026-04-17'
        $result.Status | Should -Be 'expired'
        $result.DaysUntilExpiry | Should -BeLessThan 0
    }

    It 'classifies a secret inside the warning window as warning' {
        $secret = [pscustomobject]@{
            name          = 'webhook-secret'
            lastRotated   = '2026-01-25'  # 82 days before 2026-04-17
            rotationDays  = 90            # expires 2026-04-25 -> 8 days away
            requiredBy    = @('svc-c')
        }
        $result = Get-SecretRotationStatus -Secret $secret -WarningDays 14 -Now '2026-04-17'
        $result.Status | Should -Be 'warning'
        $result.DaysUntilExpiry | Should -Be 8
    }

    It 'treats the exact warning boundary (DaysUntilExpiry == WarningDays) as warning' {
        $secret = [pscustomobject]@{
            name          = 'edge-boundary'
            lastRotated   = '2026-02-17'  # 59 days earlier
            rotationDays  = 73            # expires 2026-05-01 -> 14 days from now
            requiredBy    = @('svc-d')
        }
        $result = Get-SecretRotationStatus -Secret $secret -WarningDays 14 -Now '2026-04-17'
        $result.Status | Should -Be 'warning'
        $result.DaysUntilExpiry | Should -Be 14
    }

    It 'reports an absolute ExpiresOn date for tooling/automation' {
        $secret = [pscustomobject]@{
            name          = 'tls-cert'
            lastRotated   = '2026-04-01'
            rotationDays  = 30
            requiredBy    = @('svc-e')
        }
        $result = Get-SecretRotationStatus -Secret $secret -WarningDays 7 -Now '2026-04-17'
        $result.ExpiresOn | Should -Be ([datetime]'2026-05-01')
    }
}

Describe 'Import-SecretConfig' {
    It 'loads secrets from a JSON file' {
        $tmp = New-TemporaryFile
        try {
            @'
{
  "secrets": [
    { "name": "a", "lastRotated": "2026-01-01", "rotationDays": 30, "requiredBy": ["svc-1"] },
    { "name": "b", "lastRotated": "2026-04-01", "rotationDays": 90, "requiredBy": ["svc-2","svc-3"] }
  ]
}
'@ | Set-Content -Path $tmp -Encoding utf8
            $config = Import-SecretConfig -Path $tmp
            $config.Count | Should -Be 2
            $config[0].name | Should -Be 'a'
            $config[1].requiredBy.Count | Should -Be 2
        } finally {
            Remove-Item $tmp -Force
        }
    }

    It 'throws a meaningful error when the file is missing' {
        { Import-SecretConfig -Path '/no/such/path-$(Get-Random).json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error when the JSON is malformed' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -Path $tmp -Value '{ this is not json' -Encoding utf8
            { Import-SecretConfig -Path $tmp } |
                Should -Throw -ExpectedMessage '*Invalid*'
        } finally {
            Remove-Item $tmp -Force
        }
    }

    It 'throws when a secret is missing required fields' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -Path $tmp -Value '{ "secrets": [ { "name": "x" } ] }' -Encoding utf8
            { Import-SecretConfig -Path $tmp } |
                Should -Throw -ExpectedMessage '*missing*'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}

Describe 'Invoke-SecretRotationReport' {
    BeforeAll {
        $script:sample = @(
            [pscustomobject]@{ name = 'expired-one'; lastRotated = '2025-01-01'; rotationDays = 30;  requiredBy = @('svc-a') }
            [pscustomobject]@{ name = 'expired-two'; lastRotated = '2024-06-01'; rotationDays = 90;  requiredBy = @('svc-b','svc-c') }
            [pscustomobject]@{ name = 'warning-one'; lastRotated = '2026-01-25'; rotationDays = 90;  requiredBy = @('svc-d') }
            [pscustomobject]@{ name = 'ok-one';     lastRotated = '2026-04-15'; rotationDays = 90;  requiredBy = @('svc-e') }
        )
    }

    It 'groups secrets by urgency (expired, warning, ok)' {
        $report = Invoke-SecretRotationReport -Secrets $script:sample -WarningDays 14 -Now '2026-04-17'
        $report.Expired.Count | Should -Be 2
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count      | Should -Be 1
        # Most-overdue comes first -> expired-two (-595 days) before expired-one (-441 days).
        $report.Expired[0].name | Should -Be 'expired-two'
        $report.Warning[0].name | Should -Be 'warning-one'
    }

    It 'sorts each group with the most-urgent secrets first' {
        $report = Invoke-SecretRotationReport -Secrets $script:sample -WarningDays 14 -Now '2026-04-17'
        # Expired: most negative DaysUntilExpiry first.
        $report.Expired[0].DaysUntilExpiry | Should -BeLessThan $report.Expired[1].DaysUntilExpiry
        # Ok group should be sorted ascending (soonest-to-expire first).
        if ($report.Ok.Count -gt 1) {
            $report.Ok[0].DaysUntilExpiry | Should -BeLessOrEqual $report.Ok[1].DaysUntilExpiry
        }
    }

    It 'returns summary counts for quick consumption' {
        $report = Invoke-SecretRotationReport -Secrets $script:sample -WarningDays 14 -Now '2026-04-17'
        $report.Summary.Expired | Should -Be 2
        $report.Summary.Warning | Should -Be 1
        $report.Summary.Ok      | Should -Be 1
        $report.Summary.Total   | Should -Be 4
    }

    It 'exposes the WarningDays value on the report' {
        $report = Invoke-SecretRotationReport -Secrets $script:sample -WarningDays 21 -Now '2026-04-17'
        $report.WarningDays | Should -Be 21
    }
}

Describe 'Format-SecretRotationReport -As json' {
    It 'produces valid JSON with grouped urgency keys' {
        $secrets = @(
            # Already one day past its expiry -> must land in 'expired'.
            [pscustomobject]@{ name = 's1'; lastRotated = '2026-04-10'; rotationDays = 1; requiredBy = @('svc') }
        )
        $report = Invoke-SecretRotationReport -Secrets $secrets -WarningDays 7 -Now '2026-04-17'
        $json = Format-SecretRotationReport -Report $report -As json
        $parsed = $json | ConvertFrom-Json
        $parsed.summary.total | Should -Be 1
        $parsed.expired.Count | Should -Be 1
        $parsed.expired[0].name | Should -Be 's1'
    }
}

Describe 'Format-SecretRotationReport -As markdown' {
    It 'emits grouped sections with a markdown table per non-empty group' {
        $secrets = @(
            [pscustomobject]@{ name = 'gone'; lastRotated = '2026-01-01'; rotationDays = 30; requiredBy = @('svc-a') }
            [pscustomobject]@{ name = 'soon'; lastRotated = '2026-02-01'; rotationDays = 80; requiredBy = @('svc-b') }
        )
        $report = Invoke-SecretRotationReport -Secrets $secrets -WarningDays 30 -Now '2026-04-17'
        $md = Format-SecretRotationReport -Report $report -As markdown

        $md | Should -Match '# Secret Rotation Report'
        $md | Should -Match '## Expired'
        $md | Should -Match '## Warning'
        $md | Should -Match '\| Name \| Last Rotated \| Expires On \| Days \| Required By \|'
        $md | Should -Match 'gone'
        $md | Should -Match 'soon'
    }

    It 'omits empty groups but still shows a summary line' {
        $secrets = @(
            [pscustomobject]@{ name = 'only-ok'; lastRotated = '2026-04-17'; rotationDays = 365; requiredBy = @('svc') }
        )
        $report = Invoke-SecretRotationReport -Secrets $secrets -WarningDays 14 -Now '2026-04-17'
        $md = Format-SecretRotationReport -Report $report -As markdown
        $md | Should -Not -Match '## Expired'
        $md | Should -Not -Match '## Warning'
        $md | Should -Match '## Ok'
        $md | Should -Match 'Total: 1'
    }

    It 'rejects an unknown output format' {
        $report = Invoke-SecretRotationReport -Secrets @() -WarningDays 14 -Now '2026-04-17'
        { Format-SecretRotationReport -Report $report -As xml } |
            Should -Throw -ExpectedMessage '*Unsupported*'
    }
}

Describe 'Invoke-SecretRotationValidator (end-to-end CLI)' {
    It 'reads config, builds report, and prints to stdout' {
        $tmp = New-TemporaryFile
        try {
            @'
{
  "secrets": [
    { "name": "e", "lastRotated": "2025-01-01", "rotationDays": 30,  "requiredBy": ["svc-a"] },
    { "name": "w", "lastRotated": "2026-01-25", "rotationDays": 90,  "requiredBy": ["svc-b"] },
    { "name": "o", "lastRotated": "2026-04-15", "rotationDays": 180, "requiredBy": ["svc-c"] }
  ]
}
'@ | Set-Content -Path $tmp -Encoding utf8

            $out = Invoke-SecretRotationValidator -ConfigPath $tmp -WarningDays 14 -Format json -Now '2026-04-17'
            $parsed = $out | ConvertFrom-Json
            $parsed.summary.expired | Should -Be 1
            $parsed.summary.warning | Should -Be 1
            $parsed.summary.ok      | Should -Be 1
        } finally {
            Remove-Item $tmp -Force
        }
    }

    It 'defaults to markdown when -Format is omitted' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -Path $tmp -Value '{ "secrets": [] }' -Encoding utf8
            $out = Invoke-SecretRotationValidator -ConfigPath $tmp -WarningDays 14 -Now '2026-04-17'
            $out | Should -Match '# Secret Rotation Report'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}
