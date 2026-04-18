# Pester tests for SecretRotation module.
# Written red-then-green during implementation.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'SecretRotation.psm1') -Force
    $script:Ref = [datetime]'2026-04-17'
}

Describe 'Get-SecretStatus' {
    It 'classifies a freshly-rotated secret as ok' {
        $s = @{ name='a'; lastRotated='2026-04-10'; rotationPolicyDays=90; requiredBy=@('svc1') }
        $r = Get-SecretStatus -Secret $s -ReferenceDate $Ref -WarningDays 14
        $r.Status | Should -Be 'ok'
        $r.DaysUntilExpiry | Should -Be 83
    }

    It 'classifies a secret expiring within the warning window as warning' {
        $s = @{ name='b'; lastRotated='2026-01-20'; rotationPolicyDays=90; requiredBy=@() }
        # expires 2026-04-20 → 3 days away
        $r = Get-SecretStatus -Secret $s -ReferenceDate $Ref -WarningDays 14
        $r.Status | Should -Be 'warning'
        $r.DaysUntilExpiry | Should -Be 3
    }

    It 'classifies a past-due secret as expired with negative days' {
        $s = @{ name='c'; lastRotated='2025-01-01'; rotationPolicyDays=30; requiredBy=@('svc') }
        $r = Get-SecretStatus -Secret $s -ReferenceDate $Ref -WarningDays 14
        $r.Status | Should -Be 'expired'
        $r.DaysUntilExpiry | Should -BeLessThan 0
    }

    It 'throws on missing required fields' {
        { Get-SecretStatus -Secret @{ name='x' } -ReferenceDate $Ref -WarningDays 14 } |
            Should -Throw -ExpectedMessage '*lastRotated*'
    }

    It 'throws on non-positive rotationPolicyDays' {
        $s = @{ name='x'; lastRotated='2026-01-01'; rotationPolicyDays=0; requiredBy=@() }
        { Get-SecretStatus -Secret $s -ReferenceDate $Ref -WarningDays 14 } |
            Should -Throw -ExpectedMessage '*rotationPolicyDays*'
    }
}

Describe 'Get-SecretRotationReport' {
    BeforeAll {
        $script:Secrets = @(
            [pscustomobject]@{ name='ok-token';    lastRotated='2026-04-01'; rotationPolicyDays=90; requiredBy=@('api') }
            [pscustomobject]@{ name='warn-key';    lastRotated='2026-01-25'; rotationPolicyDays=90; requiredBy=@('worker') }
            [pscustomobject]@{ name='dead-cred';   lastRotated='2025-06-01'; rotationPolicyDays=90; requiredBy=@('legacy') }
            [pscustomobject]@{ name='other-warn';  lastRotated='2025-12-20'; rotationPolicyDays=120; requiredBy=@('cron') }
        )
    }

    It 'groups secrets into expired/warning/ok' {
        $r = Get-SecretRotationReport -Secrets $Secrets -ReferenceDate $Ref -WarningDays 14
        $r.Counts.Expired | Should -Be 1
        $r.Counts.Warning | Should -Be 2
        $r.Counts.Ok      | Should -Be 1
        $r.Counts.Total   | Should -Be 4
        $r.Expired[0].Name | Should -Be 'dead-cred'
    }

    It 'sorts each group by days until expiry ascending' {
        $r = Get-SecretRotationReport -Secrets $Secrets -ReferenceDate $Ref -WarningDays 14
        $r.Warning[0].DaysUntilExpiry | Should -BeLessOrEqual $r.Warning[1].DaysUntilExpiry
    }
}

Describe 'Format-SecretRotationReport' {
    BeforeAll {
        $secrets = @(
            [pscustomobject]@{ name='dead'; lastRotated='2024-01-01'; rotationPolicyDays=30; requiredBy=@('a','b') }
            [pscustomobject]@{ name='good'; lastRotated='2026-04-10'; rotationPolicyDays=90; requiredBy=@('c') }
        )
        $script:Report = Get-SecretRotationReport -Secrets $secrets -ReferenceDate $Ref -WarningDays 14
    }

    It 'renders markdown with expected sections and summary line' {
        $md = Format-SecretRotationReport -Report $Report -Format markdown
        $md | Should -Match '# Secret Rotation Report'
        $md | Should -Match '## Expired'
        $md | Should -Match '## Warning'
        $md | Should -Match '## Ok'
        $md | Should -Match 'EXPIRED=1'
        $md | Should -Match 'a, b'
    }

    It 'renders json that round-trips through ConvertFrom-Json' {
        $json = Format-SecretRotationReport -Report $Report -Format json
        $obj = $json | ConvertFrom-Json
        $obj.Counts.Expired | Should -Be 1
        $obj.Counts.Ok      | Should -Be 1
    }

    It 'rejects unknown formats' {
        { Format-SecretRotationReport -Report $Report -Format 'xml' } | Should -Throw
    }
}

Describe 'Invoke-SecretRotation.ps1 (CLI)' {
    BeforeAll {
        $script:Cli = Join-Path $PSScriptRoot 'Invoke-SecretRotation.ps1'
        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sr-cli-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $Tmp | Out-Null
        $cfg = @{
            secrets = @(
                @{ name='dead'; lastRotated='2024-01-01'; rotationPolicyDays=30; requiredBy=@('a') }
                @{ name='ok';   lastRotated='2026-04-15'; rotationPolicyDays=90; requiredBy=@('b') }
            )
        } | ConvertTo-Json -Depth 5
        $script:CfgPath = Join-Path $Tmp 'cfg.json'
        Set-Content -LiteralPath $CfgPath -Value $cfg -Encoding utf8
    }
    AfterAll { Remove-Item -Recurse -Force -LiteralPath $Tmp -ErrorAction SilentlyContinue }

    It 'exits 1 when there are expired secrets and prints summary' {
        $out = & pwsh -NoProfile -File $Cli -ConfigPath $CfgPath -ReferenceDate '2026-04-17' -WarningDays 14 -Format markdown 2>&1
        $LASTEXITCODE | Should -Be 1
        ($out -join "`n") | Should -Match 'SUMMARY: EXPIRED=1 WARNING=0 OK=1 TOTAL=2'
    }

    It 'returns valid JSON when format=json' {
        $out = & pwsh -NoProfile -File $Cli -ConfigPath $CfgPath -ReferenceDate '2026-04-17' -WarningDays 14 -Format json 2>&1
        # Extract everything except the trailing SUMMARY line
        $lines  = $out -split "`n"
        $jsonLines = $lines | Where-Object { $_ -notmatch '^SUMMARY:' }
        $obj = ($jsonLines -join "`n") | ConvertFrom-Json
        $obj.Counts.Total | Should -Be 2
    }

    It 'exits 2 on missing config' {
        & pwsh -NoProfile -File $Cli -ConfigPath '/nope/missing.json' 2>$null
        $LASTEXITCODE | Should -Be 2
    }
}
