#Requires -Module Pester

# TDD Cycle 1: Secret data structure — New-Secret
# TDD Cycle 2: Classify a single secret — Get-SecretStatus
# TDD Cycle 3: Build full rotation report — Get-RotationReport
# TDD Cycle 4: JSON output — ConvertTo-JsonReport
# TDD Cycle 5: Markdown output — ConvertTo-MarkdownReport

BeforeAll {
    # Strict mode is set inside BeforeAll to avoid interfering with Pester's
    # own discovery phase, which runs at the script scope before BeforeAll.
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Import the module under test
    $modulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $modulePath -Force
}

# ---------------------------------------------------------------------------
# Cycle 1 — New-Secret: validate and create a secret configuration object
# ---------------------------------------------------------------------------
Describe 'New-Secret' {
    Context 'when given valid inputs' {
        It 'returns a hashtable with the expected keys' {
            $secret = New-Secret -Name 'db-password' `
                                 -LastRotated ([datetime]'2025-01-01') `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('api-service', 'worker')

            $secret               | Should -BeOfType [hashtable]
            $secret.Name          | Should -Be 'db-password'
            $secret.LastRotated   | Should -Be ([datetime]'2025-01-01')
            $secret.RotationPolicyDays | Should -Be 90
            $secret.RequiredBy    | Should -Be @('api-service', 'worker')
        }

        It 'accepts a single service in RequiredBy' {
            $secret = New-Secret -Name 's3-key' `
                                 -LastRotated ([datetime]'2025-06-01') `
                                 -RotationPolicyDays 30 `
                                 -RequiredBy @('storage-svc')
            $secret.RequiredBy.Count | Should -Be 1
        }
    }

    Context 'when given invalid inputs' {
        It 'throws when Name is empty' {
            { New-Secret -Name '' -LastRotated ([datetime]'2025-01-01') -RotationPolicyDays 90 -RequiredBy @('svc') } |
                Should -Throw
        }

        It 'throws when RotationPolicyDays is zero or negative' {
            { New-Secret -Name 'x' -LastRotated ([datetime]'2025-01-01') -RotationPolicyDays 0 -RequiredBy @('svc') } |
                Should -Throw
            { New-Secret -Name 'x' -LastRotated ([datetime]'2025-01-01') -RotationPolicyDays -1 -RequiredBy @('svc') } |
                Should -Throw
        }

        It 'throws when RequiredBy is empty' {
            { New-Secret -Name 'x' -LastRotated ([datetime]'2025-01-01') -RotationPolicyDays 30 -RequiredBy @() } |
                Should -Throw
        }
    }
}

# ---------------------------------------------------------------------------
# Cycle 2 — Get-SecretStatus: classify a single secret
# ---------------------------------------------------------------------------
Describe 'Get-SecretStatus' {
    # Use a fixed reference date so tests are deterministic: 2026-04-08.
    # $script: scope is required so that It blocks (which run in child scopes)
    # can access variables defined in BeforeAll under strict mode.
    BeforeAll {
        $script:refDate = [datetime]'2026-04-08'
    }

    Context 'expired secrets' {
        It 'classifies a secret whose expiry is in the past as Expired' {
            # Last rotated 100 days ago with 90-day policy → expired 10 days ago
            $secret = New-Secret -Name 'old-key' `
                                 -LastRotated $script:refDate.AddDays(-100) `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('svc')

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:refDate -WarningWindowDays 7
            $result.Status      | Should -Be 'Expired'
            $result.DaysUntilExpiry | Should -BeLessThan 0
        }

        It 'classifies a secret that expired exactly today as Expired' {
            $secret = New-Secret -Name 'edge-key' `
                                 -LastRotated $script:refDate.AddDays(-90) `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('svc')

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:refDate -WarningWindowDays 7
            $result.Status | Should -Be 'Expired'
        }
    }

    Context 'warning secrets' {
        It 'classifies a secret expiring within the warning window as Warning' {
            # Expires in 5 days with a 7-day warning window
            $secret = New-Secret -Name 'soon-key' `
                                 -LastRotated $script:refDate.AddDays(-85) `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('svc')

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:refDate -WarningWindowDays 7
            $result.Status          | Should -Be 'Warning'
            $result.DaysUntilExpiry | Should -Be 5
        }

        It 'classifies a secret expiring exactly at the boundary as Warning' {
            # Expires in exactly 7 days
            $secret = New-Secret -Name 'boundary-key' `
                                 -LastRotated $script:refDate.AddDays(-83) `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('svc')

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:refDate -WarningWindowDays 7
            $result.Status          | Should -Be 'Warning'
            $result.DaysUntilExpiry | Should -Be 7
        }
    }

    Context 'ok secrets' {
        It 'classifies a secret expiring beyond the warning window as Ok' {
            # Expires in 30 days with a 7-day window
            $secret = New-Secret -Name 'fresh-key' `
                                 -LastRotated $script:refDate.AddDays(-60) `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('svc')

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:refDate -WarningWindowDays 7
            $result.Status          | Should -Be 'Ok'
            $result.DaysUntilExpiry | Should -Be 30
        }
    }

    Context 'result shape' {
        It 'result includes Name, ExpiryDate, DaysUntilExpiry, RequiredBy, Status' {
            $secret = New-Secret -Name 'shape-key' `
                                 -LastRotated $script:refDate.AddDays(-50) `
                                 -RotationPolicyDays 90 `
                                 -RequiredBy @('svc-a', 'svc-b')

            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:refDate -WarningWindowDays 7
            $result.Keys | Should -Contain 'Name'
            $result.Keys | Should -Contain 'ExpiryDate'
            $result.Keys | Should -Contain 'DaysUntilExpiry'
            $result.Keys | Should -Contain 'RequiredBy'
            $result.Keys | Should -Contain 'Status'
        }
    }
}

# ---------------------------------------------------------------------------
# Cycle 3 — Get-RotationReport: process a list of secrets and group by urgency
# ---------------------------------------------------------------------------
Describe 'Get-RotationReport' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-08'
    }

    BeforeEach {
        # Build a mixed fixture: 1 expired, 1 warning, 1 ok
        $script:secrets = @(
            (New-Secret -Name 'expired-key'  -LastRotated $script:refDate.AddDays(-100) -RotationPolicyDays 90  -RequiredBy @('billing'))
            (New-Secret -Name 'warning-key'  -LastRotated $script:refDate.AddDays(-88)  -RotationPolicyDays 90  -RequiredBy @('api'))
            (New-Secret -Name 'ok-key'       -LastRotated $script:refDate.AddDays(-30)  -RotationPolicyDays 90  -RequiredBy @('worker'))
        )
    }

    It 'returns a report object with Expired, Warning, and Ok keys' {
        $report = Get-RotationReport -Secrets $script:secrets -ReferenceDate $script:refDate -WarningWindowDays 7
        $report.Keys | Should -Contain 'Expired'
        $report.Keys | Should -Contain 'Warning'
        $report.Keys | Should -Contain 'Ok'
        $report.Keys | Should -Contain 'GeneratedAt'
    }

    It 'places expired-key in the Expired group' {
        $report = Get-RotationReport -Secrets $script:secrets -ReferenceDate $script:refDate -WarningWindowDays 7
        ($report.Expired | Where-Object { $_.Name -eq 'expired-key' }) | Should -Not -BeNullOrEmpty
    }

    It 'places warning-key in the Warning group' {
        $report = Get-RotationReport -Secrets $script:secrets -ReferenceDate $script:refDate -WarningWindowDays 7
        ($report.Warning | Where-Object { $_.Name -eq 'warning-key' }) | Should -Not -BeNullOrEmpty
    }

    It 'places ok-key in the Ok group' {
        $report = Get-RotationReport -Secrets $script:secrets -ReferenceDate $script:refDate -WarningWindowDays 7
        ($report.Ok | Where-Object { $_.Name -eq 'ok-key' }) | Should -Not -BeNullOrEmpty
    }

    It 'uses default WarningWindowDays of 7 when not provided' {
        $report = Get-RotationReport -Secrets $script:secrets -ReferenceDate $script:refDate
        $report.Keys | Should -Contain 'Warning'
    }

    It 'handles an empty secrets list without error' {
        $report = Get-RotationReport -Secrets @() -ReferenceDate $script:refDate -WarningWindowDays 7
        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.Ok.Count      | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Cycle 4 — ConvertTo-JsonReport: serialize the report as JSON
# ---------------------------------------------------------------------------
Describe 'ConvertTo-JsonReport' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-08'
    }

    BeforeEach {
        [array]$secrets = @(
            (New-Secret -Name 'alpha' -LastRotated $script:refDate.AddDays(-100) -RotationPolicyDays 90 -RequiredBy @('svc'))
            (New-Secret -Name 'beta'  -LastRotated $script:refDate.AddDays(-85)  -RotationPolicyDays 90 -RequiredBy @('svc'))
            (New-Secret -Name 'gamma' -LastRotated $script:refDate.AddDays(-10)  -RotationPolicyDays 90 -RequiredBy @('svc'))
        )
        $script:report = Get-RotationReport -Secrets $secrets -ReferenceDate $script:refDate -WarningWindowDays 7
    }

    It 'returns a valid JSON string' {
        $json = ConvertTo-JsonReport -Report $script:report
        $json | Should -BeOfType [string]
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON contains Expired, Warning, and Ok arrays' {
        $json    = ConvertTo-JsonReport -Report $script:report
        $parsed  = $json | ConvertFrom-Json
        $parsed.PSObject.Properties.Name | Should -Contain 'Expired'
        $parsed.PSObject.Properties.Name | Should -Contain 'Warning'
        $parsed.PSObject.Properties.Name | Should -Contain 'Ok'
    }

    It 'expired secret alpha appears in JSON Expired array' {
        $json   = ConvertTo-JsonReport -Report $script:report
        $parsed = $json | ConvertFrom-Json
        ($parsed.Expired | Where-Object { $_.Name -eq 'alpha' }) | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# Cycle 5 — ConvertTo-MarkdownReport: serialize the report as a Markdown table
# ---------------------------------------------------------------------------
Describe 'ConvertTo-MarkdownReport' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-08'
    }

    BeforeEach {
        [array]$secrets = @(
            (New-Secret -Name 'alpha' -LastRotated $script:refDate.AddDays(-100) -RotationPolicyDays 90 -RequiredBy @('billing'))
            (New-Secret -Name 'beta'  -LastRotated $script:refDate.AddDays(-85)  -RotationPolicyDays 90 -RequiredBy @('api'))
            (New-Secret -Name 'gamma' -LastRotated $script:refDate.AddDays(-10)  -RotationPolicyDays 90 -RequiredBy @('worker'))
        )
        $script:report = Get-RotationReport -Secrets $secrets -ReferenceDate $script:refDate -WarningWindowDays 7
    }

    It 'returns a non-empty string' {
        $md = ConvertTo-MarkdownReport -Report $script:report
        $md | Should -Not -BeNullOrEmpty
        $md | Should -BeOfType [string]
    }

    It 'contains a section header for each urgency group' {
        $md = ConvertTo-MarkdownReport -Report $script:report
        $md | Should -Match '##\s+Expired'
        $md | Should -Match '##\s+Warning'
        $md | Should -Match '##\s+Ok'
    }

    It 'contains table header row with expected columns' {
        $md = ConvertTo-MarkdownReport -Report $script:report
        $md | Should -Match '\|\s*Name\s*\|'
        $md | Should -Match '\|\s*Status\s*\|'
        $md | Should -Match '\|\s*DaysUntilExpiry\s*\|'
        $md | Should -Match '\|\s*ExpiryDate\s*\|'
        $md | Should -Match '\|\s*RequiredBy\s*\|'
    }

    It 'lists secret alpha under the Expired section' {
        $md = ConvertTo-MarkdownReport -Report $script:report
        $md | Should -Match 'alpha'
    }

    It 'lists secret gamma under the Ok section' {
        $md = ConvertTo-MarkdownReport -Report $script:report
        $md | Should -Match 'gamma'
    }
}
