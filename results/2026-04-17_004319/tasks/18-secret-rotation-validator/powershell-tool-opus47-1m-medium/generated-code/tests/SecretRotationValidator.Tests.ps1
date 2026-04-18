# Pester tests for SecretRotationValidator, written red/green style.
# Each describe block corresponds to a piece of functionality that was added
# test-first before implementation.

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    . "$script:Root/SecretRotationValidator.ps1"
    $script:Fixture = Join-Path $script:Root 'fixtures/sample.json'
    $script:RefDate = [datetime]'2026-04-17'
}

Describe 'Get-SecretStatus' {
    It 'classifies a secret rotated long ago as expired' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-01-01'; rotationDays=30 }
        $r = Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14
        $r.urgency | Should -Be 'expired'
        $r.daysLeft | Should -BeLessThan 0
    }

    It 'classifies a secret within the warning window as warning' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-03-20'; rotationDays=30 }
        $r = Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14
        $r.urgency | Should -Be 'warning'
    }

    It 'classifies a secret safely beyond the warning window as ok' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-04-14'; rotationDays=90 }
        $r = Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14
        $r.urgency | Should -Be 'ok'
    }

    It 'computes expiresOn as lastRotated + rotationDays' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-01-01'; rotationDays=30 }
        $r = Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14
        $r.expiresOn | Should -Be '2026-01-31'
    }

    It 'throws on missing required field' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-01-01' }
        { Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14 } |
            Should -Throw -ExpectedMessage "*rotationDays*"
    }

    It 'throws on non-positive rotationDays' {
        $s = [pscustomobject]@{ name='a'; lastRotated='2026-01-01'; rotationDays=0 }
        { Get-SecretStatus -Secret $s -ReferenceDate $script:RefDate -WarningDays 14 } |
            Should -Throw -ExpectedMessage "*invalid rotationDays*"
    }
}

Describe 'Invoke-RotationReport - JSON format' {
    It 'emits valid JSON with expected urgency counts for the sample fixture' {
        $json = Invoke-RotationReport -ConfigPath $script:Fixture -Format json -WarningDays 14 -ReferenceDate $script:RefDate
        $parsed = $json | ConvertFrom-Json
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok      | Should -Be 1
        $parsed.referenceDate   | Should -Be '2026-04-17'
        $parsed.warningDays     | Should -Be 14
    }

    It 'orders secrets expired first, then warning, then ok' {
        $json = Invoke-RotationReport -ConfigPath $script:Fixture -Format json -WarningDays 14 -ReferenceDate $script:RefDate
        $parsed = $json | ConvertFrom-Json
        $parsed.secrets[0].urgency | Should -Be 'expired'
        $parsed.secrets[1].urgency | Should -Be 'warning'
        $parsed.secrets[2].urgency | Should -Be 'ok'
    }

    It 'preserves the requiredBy services' {
        $json = Invoke-RotationReport -ConfigPath $script:Fixture -Format json -WarningDays 14 -ReferenceDate $script:RefDate
        $parsed = $json | ConvertFrom-Json
        $db = $parsed.secrets | Where-Object { $_.name -eq 'db-password' }
        $db.requiredBy | Should -Contain 'api'
        $db.requiredBy | Should -Contain 'worker'
    }
}

Describe 'Invoke-RotationReport - Markdown format' {
    BeforeAll {
        $script:md = Invoke-RotationReport -ConfigPath $script:Fixture -Format markdown -WarningDays 14 -ReferenceDate $script:RefDate
    }

    It 'includes a top-level report heading' {
        $script:md | Should -Match '# Secret Rotation Report'
    }

    It 'includes grouped sections for each urgency' {
        $script:md | Should -Match '## EXPIRED \(1\)'
        $script:md | Should -Match '## WARNING \(1\)'
        $script:md | Should -Match '## OK \(1\)'
    }

    It 'renders a table row for the expired secret' {
        $script:md | Should -Match '\| db-password \|'
    }

    It 'shows the summary line with counts' {
        $script:md | Should -Match 'expired=1, warning=1, ok=1'
    }
}

Describe 'Invoke-RotationReport - error handling' {
    It 'throws on missing config file' {
        { Invoke-RotationReport -ConfigPath '/nonexistent/path.json' -ReferenceDate $script:RefDate } |
            Should -Throw -ExpectedMessage "*not found*"
    }

    It 'throws on invalid JSON' {
        $tmp = New-TemporaryFile
        Set-Content -LiteralPath $tmp -Value '{ this is not json'
        try {
            { Invoke-RotationReport -ConfigPath $tmp -ReferenceDate $script:RefDate } |
                Should -Throw -ExpectedMessage "*Failed to parse*"
        } finally {
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        }
    }

    It 'throws on config missing secrets array' {
        $tmp = New-TemporaryFile
        Set-Content -LiteralPath $tmp -Value '{}'
        try {
            { Invoke-RotationReport -ConfigPath $tmp -ReferenceDate $script:RefDate } |
                Should -Throw -ExpectedMessage "*secrets*"
        } finally {
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-RotationReport - configurable warning window' {
    It 'shifts a secret into warning with a wider window' {
        $json = Invoke-RotationReport -ConfigPath $script:Fixture -Format json -WarningDays 120 -ReferenceDate $script:RefDate
        $parsed = $json | ConvertFrom-Json
        # github-token (87 days left) should now be warning instead of ok
        $parsed.summary.warning | Should -Be 2
        $parsed.summary.ok      | Should -Be 0
    }
}
