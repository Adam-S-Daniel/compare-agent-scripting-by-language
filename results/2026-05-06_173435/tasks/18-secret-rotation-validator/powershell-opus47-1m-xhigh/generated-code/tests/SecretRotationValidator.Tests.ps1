# Pester tests for Invoke-SecretRotationValidator.ps1
#
# Approach: each describe block exercises one piece of functionality. Tests
# pin a deterministic "now" via -AsOf so results don't drift over time. The
# fixture data lives under ./fixtures/ and is shared with the act harness.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ScriptPath = Join-Path $RepoRoot 'Invoke-SecretRotationValidator.ps1'
    . $script:ScriptPath
}

Describe 'Get-SecretRotationStatus' {
    Context 'classification by days-until-expiry' {
        It 'classifies a freshly rotated secret as ok' {
            $secret = [pscustomobject]@{
                name               = 'api-key-stripe'
                lastRotated        = '2026-04-01'
                rotationPolicyDays = 90
                requiredBy         = @('payments')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf '2026-05-07' -WarningDays 14
            $result.status | Should -Be 'ok'
            # 2026-04-01 + 90 days = 2026-06-30; 2026-06-30 - 2026-05-07 = 54 days
            $result.daysUntilExpiry | Should -Be 54
            $result.expiresAt | Should -Be '2026-06-30'
        }

        It 'classifies a secret rotated 80 days ago with 90-day policy as warning' {
            # 90 - 80 = 10 days remaining, well inside the 14-day warning window
            $secret = [pscustomobject]@{
                name               = 'db-password'
                lastRotated        = '2026-02-16'  # 80 days before 2026-05-07
                rotationPolicyDays = 90
                requiredBy         = @('orders-svc')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf '2026-05-07' -WarningDays 14
            $result.status | Should -Be 'warning'
            $result.daysUntilExpiry | Should -Be 10
        }

        It 'classifies a secret with daysUntilExpiry == 0 as warning (boundary)' {
            # Expires exactly today: still warning, not expired.
            $secret = [pscustomobject]@{
                name               = 'expires-today'
                lastRotated        = '2026-04-07'
                rotationPolicyDays = 30
                requiredBy         = @()
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf '2026-05-07' -WarningDays 14
            $result.status | Should -Be 'warning'
            $result.daysUntilExpiry | Should -Be 0
        }

        It 'classifies a secret past its expiry as expired with negative daysUntilExpiry' {
            $secret = [pscustomobject]@{
                name               = 'old-token'
                lastRotated        = '2025-01-01'
                rotationPolicyDays = 90
                requiredBy         = @('legacy-cron')
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf '2026-05-07' -WarningDays 14
            $result.status | Should -Be 'expired'
            $result.daysUntilExpiry | Should -BeLessThan 0
        }

        It 'honours WarningDays at the upper boundary (==WarningDays is warning)' {
            # 14 days remaining, WarningDays=14 -> warning (inclusive)
            $secret = [pscustomobject]@{
                name               = 'edge'
                lastRotated        = '2026-02-12'  # 84 days before 2026-05-07
                rotationPolicyDays = 98
                requiredBy         = @()
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf '2026-05-07' -WarningDays 14
            $result.daysUntilExpiry | Should -Be 14
            $result.status | Should -Be 'warning'
        }

        It 'is ok when daysUntilExpiry is one day past the warning boundary' {
            $secret = [pscustomobject]@{
                name               = 'just-ok'
                lastRotated        = '2026-02-11'  # 85 days before 2026-05-07
                rotationPolicyDays = 100
                requiredBy         = @()
            }
            $result = Get-SecretRotationStatus -Secret $secret -AsOf '2026-05-07' -WarningDays 14
            $result.daysUntilExpiry | Should -Be 15
            $result.status | Should -Be 'ok'
        }
    }

    Context 'input validation' {
        It 'throws when a required field is missing' {
            $bad = [pscustomobject]@{
                name        = 'no-policy'
                lastRotated = '2026-04-01'
            }
            { Get-SecretRotationStatus -Secret $bad -AsOf '2026-05-07' -WarningDays 14 } |
                Should -Throw -ExpectedMessage "*rotationPolicyDays*"
        }

        It 'throws on a non-positive rotationPolicyDays' {
            $bad = [pscustomobject]@{
                name               = 'silly'
                lastRotated        = '2026-04-01'
                rotationPolicyDays = 0
            }
            { Get-SecretRotationStatus -Secret $bad -AsOf '2026-05-07' -WarningDays 14 } |
                Should -Throw -ExpectedMessage "*non-positive*"
        }

        It 'throws on an unparseable date string' {
            $bad = [pscustomobject]@{
                name               = 'bad-date'
                lastRotated        = 'yesterday'
                rotationPolicyDays = 30
            }
            { Get-SecretRotationStatus -Secret $bad -AsOf '2026-05-07' -WarningDays 14 } |
                Should -Throw -ExpectedMessage "*Invalid date 'yesterday'*"
        }
    }
}

Describe 'Read-SecretConfig' {
    BeforeAll {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
    }
    AfterAll {
        Remove-Item -Path $script:tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reads a valid config and returns a list of secrets' {
        $path = Join-Path $script:tmpDir 'good.json'
        @{
            secrets = @(
                @{ name = 's1'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('a') }
                @{ name = 's2'; lastRotated = '2026-01-01'; rotationPolicyDays = 30; requiredBy = @('b') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
        $secrets = Read-SecretConfig -Path $path
        $secrets.Count | Should -Be 2
        $secrets[0].name | Should -Be 's1'
        $secrets[1].rotationPolicyDays | Should -Be 30
    }

    It 'throws when the file does not exist' {
        { Read-SecretConfig -Path (Join-Path $script:tmpDir 'nope.json') } |
            Should -Throw -ExpectedMessage "*Config file not found*"
    }

    It 'throws when the JSON is malformed' {
        $path = Join-Path $script:tmpDir 'bad.json'
        Set-Content -Path $path -Value '{ this is not json' -Encoding UTF8
        { Read-SecretConfig -Path $path } |
            Should -Throw -ExpectedMessage "*Failed to parse config*"
    }

    It "throws when the top-level 'secrets' array is missing" {
        $path = Join-Path $script:tmpDir 'noarray.json'
        '{}' | Set-Content -Path $path -Encoding UTF8
        { Read-SecretConfig -Path $path } |
            Should -Throw -ExpectedMessage "*'secrets' array*"
    }
}

Describe 'Get-RotationReport' {
    BeforeAll {
        # Mixed fixture covering all three buckets.
        $script:mixedSecrets = @(
            [pscustomobject]@{ name = 'fresh';   lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('a') }
            [pscustomobject]@{ name = 'soon';    lastRotated = '2026-02-16'; rotationPolicyDays = 90; requiredBy = @('b') } # 10 days left
            [pscustomobject]@{ name = 'stale';   lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('c') }
        )
    }

    It 'returns a report object with asOf, warningDays, counts, and three groups' {
        $report = Get-RotationReport -Secrets $script:mixedSecrets -AsOf '2026-05-07' -WarningDays 14
        $report.asOf        | Should -Be '2026-05-07'
        $report.warningDays | Should -Be 14
        $report.counts.expired | Should -Be 1
        $report.counts.warning | Should -Be 1
        $report.counts.ok      | Should -Be 1
        $report.counts.total   | Should -Be 3
        $report.expired.Count  | Should -Be 1
        $report.warning.Count  | Should -Be 1
        $report.ok.Count       | Should -Be 1
        $report.expired[0].name | Should -Be 'stale'
        $report.warning[0].name | Should -Be 'soon'
        $report.ok[0].name      | Should -Be 'fresh'
    }

    It 'sorts each group by daysUntilExpiry ascending (most-urgent first)' {
        $secrets = @(
            [pscustomobject]@{ name = 'a'; lastRotated = '2026-02-26'; rotationPolicyDays = 90; requiredBy = @() }  # 20 days remaining -> ok
            [pscustomobject]@{ name = 'b'; lastRotated = '2026-02-21'; rotationPolicyDays = 90; requiredBy = @() }  # 15 days remaining -> ok
            [pscustomobject]@{ name = 'c'; lastRotated = '2025-12-01'; rotationPolicyDays = 90; requiredBy = @() }  # expired ~74 days
            [pscustomobject]@{ name = 'd'; lastRotated = '2024-12-01'; rotationPolicyDays = 90; requiredBy = @() }  # expired much earlier
        )
        $report = Get-RotationReport -Secrets $secrets -AsOf '2026-05-07' -WarningDays 14
        # Within "expired", the most-overdue secret comes first (smallest daysUntilExpiry).
        $report.expired[0].name | Should -Be 'd'
        $report.expired[1].name | Should -Be 'c'
        # Within "ok", the soonest-to-expire comes first.
        $report.ok[0].name | Should -Be 'b'
        $report.ok[1].name | Should -Be 'a'
    }

    It 'returns empty arrays for groups with no members' {
        $allOk = @(
            [pscustomobject]@{ name = 'x'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @() }
        )
        $report = Get-RotationReport -Secrets $allOk -AsOf '2026-05-07' -WarningDays 14
        $report.expired.Count | Should -Be 0
        $report.warning.Count | Should -Be 0
        $report.ok.Count      | Should -Be 1
        ,$report.expired | Should -BeOfType [array]
    }
}

Describe 'Format-RotationReportMarkdown' {
    BeforeAll {
        $script:report = Get-RotationReport -Secrets @(
            [pscustomobject]@{ name = 'fresh-key'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('frontend') }
            [pscustomobject]@{ name = 'soon-key';  lastRotated = '2026-02-16'; rotationPolicyDays = 90; requiredBy = @('payments','checkout') }
            [pscustomobject]@{ name = 'old-key';   lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('legacy') }
        ) -AsOf '2026-05-07' -WarningDays 14
        $script:md = Format-RotationReportMarkdown -Report $script:report
    }

    It 'has a header that mentions the report title and the asOf date' {
        $script:md | Should -Match '# Secret Rotation Report'
        $script:md | Should -Match 'as of \*\*2026-05-07\*\*'
    }

    It 'shows summary counts for each bucket' {
        $script:md | Should -Match 'Expired: \*\*1\*\*'
        $script:md | Should -Match 'Warning: \*\*1\*\*'
        $script:md | Should -Match 'OK: \*\*1\*\*'
    }

    It 'has a section per bucket' {
        $script:md | Should -Match '## Expired \(1\)'
        $script:md | Should -Match '## Warning \(1\)'
        $script:md | Should -Match '## OK \(1\)'
    }

    It 'renders a markdown table with the expected columns' {
        $script:md | Should -Match '\| Name \| Last Rotated \| Expires \| Days \| Required By \|'
        $script:md | Should -Match '\|------\|--------------\|---------\|------\|-------------\|'
    }

    It 'lists each secret on its own row with comma-separated requiredBy' {
        $script:md | Should -Match '\| old-key \| 2025-01-01 \| 2025-04-01 \| -401 \| legacy \|'
        $script:md | Should -Match '\| soon-key \| 2026-02-16 \| 2026-05-17 \| 10 \| payments, checkout \|'
        $script:md | Should -Match '\| fresh-key \| 2026-04-01 \| 2026-06-30 \| 54 \| frontend \|'
    }

    It 'uses an em-dash placeholder when a bucket is empty' {
        $allOk = Get-RotationReport -Secrets @(
            [pscustomobject]@{ name = 'a'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @() }
        ) -AsOf '2026-05-07' -WarningDays 14
        $md = Format-RotationReportMarkdown -Report $allOk
        $md | Should -Match '## Expired \(0\)\s+_None_'
        $md | Should -Match '## Warning \(0\)\s+_None_'
    }
}

Describe 'Format-RotationReportJson' {
    BeforeAll {
        $script:report = Get-RotationReport -Secrets @(
            [pscustomobject]@{ name = 'fresh'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('frontend') }
            [pscustomobject]@{ name = 'old';   lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('legacy') }
        ) -AsOf '2026-05-07' -WarningDays 14
    }

    It 'returns a string that round-trips through ConvertFrom-Json' {
        $json = Format-RotationReportJson -Report $script:report
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'preserves the report shape after a JSON round-trip' {
        $json = Format-RotationReportJson -Report $script:report
        $parsed = $json | ConvertFrom-Json
        $parsed.asOf        | Should -Be '2026-05-07'
        $parsed.warningDays | Should -Be 14
        $parsed.counts.expired | Should -Be 1
        $parsed.counts.ok      | Should -Be 1
        @($parsed.expired)[0].name      | Should -Be 'old'
        @($parsed.expired)[0].status    | Should -Be 'expired'
        @($parsed.ok)[0].requiredBy[0]  | Should -Be 'frontend'
    }

    It 'serialises empty buckets as empty arrays, not null' {
        $allOk = Get-RotationReport -Secrets @(
            [pscustomobject]@{ name = 'a'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @() }
        ) -AsOf '2026-05-07' -WarningDays 14
        $json = Format-RotationReportJson -Report $allOk
        $json | Should -Match '"expired":\s*\[\s*\]'
        $json | Should -Match '"warning":\s*\[\s*\]'
    }
}

Describe 'CLI script entrypoint' {
    BeforeAll {
        $script:scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-SecretRotationValidator.ps1'
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
        $script:configPath = Join-Path $script:tmp 'cfg.json'
        @{
            secrets = @(
                @{ name = 'fresh'; lastRotated = '2026-04-01'; rotationPolicyDays = 90; requiredBy = @('a') }
                @{ name = 'old';   lastRotated = '2025-01-01'; rotationPolicyDays = 90; requiredBy = @('legacy') }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:configPath -Encoding UTF8
    }
    AfterAll {
        Remove-Item -Path $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'prints markdown by default and exits 0 when nothing is expired' {
        $cfg = Join-Path $script:tmp 'ok-only.json'
        @{ secrets = @(@{ name='a'; lastRotated='2026-04-01'; rotationPolicyDays=90; requiredBy=@() }) } |
            ConvertTo-Json -Depth 5 | Set-Content -Path $cfg -Encoding UTF8

        # Run the script as a *separate* pwsh process so we can observe its
        # exit code and stdout in isolation from the test runner.
        $output = pwsh -NoProfile -File $script:scriptPath -Config $cfg -AsOf '2026-05-07' -WarningDays 14
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match '# Secret Rotation Report'
        ($output -join "`n") | Should -Match '## OK \(1\)'
    }

    It 'emits JSON when -Format json is supplied' {
        # Mixed fixture has 1 expired + 1 fresh, so expect exit code 2 (expired present).
        $output = pwsh -NoProfile -File $script:scriptPath -Config $script:configPath -AsOf '2026-05-07' -WarningDays 14 -Format json
        $LASTEXITCODE | Should -Be 2
        $joined = $output -join "`n"
        $parsed = $joined | ConvertFrom-Json
        $parsed.counts.expired | Should -Be 1
        $parsed.counts.ok      | Should -Be 1
    }

    It 'exits 2 when secrets are expired (so CI can fail the job)' {
        # Two expired, one fresh: code 2 = expired present.
        $output = pwsh -NoProfile -File $script:scriptPath -Config $script:configPath -AsOf '2026-05-07' -WarningDays 14
        $LASTEXITCODE | Should -Be 2
        ($output -join "`n") | Should -Match '## Expired \(1\)'
    }

    It 'exits 1 when only warnings exist (and no expired)' {
        $cfg = Join-Path $script:tmp 'warn-only.json'
        @{ secrets = @(@{ name='soon'; lastRotated='2026-02-16'; rotationPolicyDays=90; requiredBy=@('svc') }) } |
            ConvertTo-Json -Depth 5 | Set-Content -Path $cfg -Encoding UTF8
        $null = pwsh -NoProfile -File $script:scriptPath -Config $cfg -AsOf '2026-05-07' -WarningDays 14
        $LASTEXITCODE | Should -Be 1
    }

    It 'exits 3 with a meaningful error message when the config file is missing' {
        $missing = Join-Path $script:tmp 'does-not-exist.json'
        $err = pwsh -NoProfile -File $script:scriptPath -Config $missing -AsOf '2026-05-07' 2>&1
        $LASTEXITCODE | Should -Be 3
        ($err -join "`n") | Should -Match 'Config file not found'
    }

    It 'rejects an invalid -Format value (parameter validation)' {
        $err = pwsh -NoProfile -File $script:scriptPath -Config $script:configPath -Format yaml 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
