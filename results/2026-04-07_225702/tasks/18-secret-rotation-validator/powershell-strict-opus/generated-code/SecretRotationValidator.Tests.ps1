Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe 'Get-SecretStatus' {
    It 'marks a secret as Expired when past rotation policy' {
        [hashtable]$secret = @{
            Name         = 'db-password'
            LastRotated  = ([datetime]'2026-01-01')
            PolicyDays   = 30
            RequiredBy   = @('api-server', 'worker')
        }
        [datetime]$now = [datetime]'2026-03-15'
        [int]$warningDays = 7

        $result = Get-SecretStatus -Secret $secret -ReferenceDate $now -WarningDays $warningDays
        $result.Urgency | Should -Be 'Expired'
        $result.DaysOverdue | Should -BeGreaterThan 0
    }

    It 'marks a secret as Warning when expiring within warning window' {
        [hashtable]$secret = @{
            Name         = 'api-key'
            LastRotated  = ([datetime]'2026-03-01')
            PolicyDays   = 30
            RequiredBy   = @('frontend')
        }
        # Expires on 2026-03-31, reference is 2026-03-27 => 4 days left, within 7-day warning
        [datetime]$now = [datetime]'2026-03-27'
        [int]$warningDays = 7

        $result = Get-SecretStatus -Secret $secret -ReferenceDate $now -WarningDays $warningDays
        $result.Urgency | Should -Be 'Warning'
        $result.DaysUntilExpiry | Should -Be 4
    }

    It 'marks a secret as OK when not expiring soon' {
        [hashtable]$secret = @{
            Name         = 'tls-cert'
            LastRotated  = ([datetime]'2026-03-01')
            PolicyDays   = 90
            RequiredBy   = @('load-balancer')
        }
        [datetime]$now = [datetime]'2026-03-15'
        [int]$warningDays = 7

        $result = Get-SecretStatus -Secret $secret -ReferenceDate $now -WarningDays $warningDays
        $result.Urgency | Should -Be 'OK'
        $result.DaysUntilExpiry | Should -Be 76
    }

    It 'treats a secret expiring exactly on the boundary as Warning' {
        [hashtable]$secret = @{
            Name         = 'boundary-key'
            LastRotated  = ([datetime]'2026-03-01')
            PolicyDays   = 30
            RequiredBy   = @('svc')
        }
        # Expires 2026-03-31, reference 2026-03-24 => 7 days left == warningDays
        [datetime]$now = [datetime]'2026-03-24'
        [int]$warningDays = 7

        $result = Get-SecretStatus -Secret $secret -ReferenceDate $now -WarningDays $warningDays
        $result.Urgency | Should -Be 'Warning'
    }
}

Describe 'Get-RotationReport' {
    BeforeAll {
        # Fixture: a mix of expired, warning, and ok secrets
        [hashtable[]]$script:testSecrets = @(
            @{ Name = 'expired-secret';  LastRotated = ([datetime]'2026-01-01'); PolicyDays = 30;  RequiredBy = @('svc-a', 'svc-b') }
            @{ Name = 'warning-secret';  LastRotated = ([datetime]'2026-03-01'); PolicyDays = 30;  RequiredBy = @('svc-c') }
            @{ Name = 'ok-secret';       LastRotated = ([datetime]'2026-03-01'); PolicyDays = 90;  RequiredBy = @('svc-d') }
        )
    }

    It 'groups secrets by urgency' {
        [datetime]$now = [datetime]'2026-03-27'
        [int]$warningDays = 7

        $report = Get-RotationReport -Secrets $script:testSecrets -ReferenceDate $now -WarningDays $warningDays
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 1
        $report.OK.Count      | Should -Be 1
        $report.Expired[0].Name | Should -Be 'expired-secret'
        $report.Warning[0].Name | Should -Be 'warning-secret'
        $report.OK[0].Name      | Should -Be 'ok-secret'
    }

    It 'includes summary counts in the report' {
        [datetime]$now = [datetime]'2026-03-27'
        $report = Get-RotationReport -Secrets $script:testSecrets -ReferenceDate $now -WarningDays 7
        $report.Summary.TotalSecrets  | Should -Be 3
        $report.Summary.ExpiredCount  | Should -Be 1
        $report.Summary.WarningCount  | Should -Be 1
        $report.Summary.OKCount       | Should -Be 1
        $report.Summary.ReportDate    | Should -Be $now
    }
}

Describe 'ConvertTo-MarkdownReport' {
    It 'produces a markdown table with headers and rows' {
        [hashtable]$report = @{
            Expired = @(
                @{ Name = 'db-pw'; Urgency = 'Expired'; DaysOverdue = 44; DaysUntilExpiry = 0;
                   LastRotated = ([datetime]'2026-01-01'); ExpiryDate = ([datetime]'2026-01-31');
                   PolicyDays = 30; RequiredBy = @('svc-a','svc-b') }
            )
            Warning = @(
                @{ Name = 'api-key'; Urgency = 'Warning'; DaysOverdue = 0; DaysUntilExpiry = 4;
                   LastRotated = ([datetime]'2026-03-01'); ExpiryDate = ([datetime]'2026-03-31');
                   PolicyDays = 30; RequiredBy = @('frontend') }
            )
            OK = @(
                @{ Name = 'tls-cert'; Urgency = 'OK'; DaysOverdue = 0; DaysUntilExpiry = 76;
                   LastRotated = ([datetime]'2026-03-01'); ExpiryDate = ([datetime]'2026-05-29');
                   PolicyDays = 90; RequiredBy = @('lb') }
            )
            Summary = @{ TotalSecrets = 3; ExpiredCount = 1; WarningCount = 1; OKCount = 1;
                          ReportDate = ([datetime]'2026-03-15') }
        }

        [string]$md = ConvertTo-MarkdownReport -Report $report
        # Should contain the markdown table header
        $md | Should -Match '\| Name'
        $md | Should -Match '\| Urgency'
        # Should contain each secret name
        $md | Should -Match 'db-pw'
        $md | Should -Match 'api-key'
        $md | Should -Match 'tls-cert'
        # Should contain summary section
        $md | Should -Match 'Summary'
        # Expired section header
        $md | Should -Match 'EXPIRED'
    }
}

Describe 'ConvertTo-JsonReport' {
    It 'produces valid JSON output' {
        [hashtable]$report = @{
            Expired = @(
                @{ Name = 'db-pw'; Urgency = 'Expired'; DaysOverdue = 44; DaysUntilExpiry = 0;
                   LastRotated = ([datetime]'2026-01-01'); ExpiryDate = ([datetime]'2026-01-31');
                   PolicyDays = 30; RequiredBy = @('svc-a') }
            )
            Warning = @()
            OK      = @()
            Summary = @{ TotalSecrets = 1; ExpiredCount = 1; WarningCount = 0; OKCount = 0;
                         ReportDate = ([datetime]'2026-03-15') }
        }

        [string]$json = ConvertTo-JsonReport -Report $report
        # Must be valid JSON
        $parsed = $json | ConvertFrom-Json
        $parsed | Should -Not -BeNullOrEmpty
        $parsed.summary.TotalSecrets | Should -Be 1
        $parsed.expired.Count | Should -Be 1
        $parsed.expired[0].Name | Should -Be 'db-pw'
    }
}

Describe 'Error Handling' {
    It 'throws when a secret is missing the Name field' {
        [hashtable]$bad = @{
            LastRotated = ([datetime]'2026-01-01')
            PolicyDays  = 30
            RequiredBy  = @('svc')
        }
        { Get-SecretStatus -Secret $bad -ReferenceDate ([datetime]'2026-03-15') -WarningDays 7 } |
            Should -Throw '*Name*'
    }

    It 'throws when PolicyDays is zero or negative' {
        [hashtable]$bad = @{
            Name        = 'bad-policy'
            LastRotated = ([datetime]'2026-01-01')
            PolicyDays  = 0
            RequiredBy  = @('svc')
        }
        { Get-SecretStatus -Secret $bad -ReferenceDate ([datetime]'2026-03-15') -WarningDays 7 } |
            Should -Throw '*PolicyDays*'
    }

    It 'throws when LastRotated is missing' {
        [hashtable]$bad = @{
            Name       = 'no-date'
            PolicyDays = 30
            RequiredBy = @('svc')
        }
        { Get-SecretStatus -Secret $bad -ReferenceDate ([datetime]'2026-03-15') -WarningDays 7 } |
            Should -Throw '*LastRotated*'
    }
}

Describe 'Edge Cases' {
    It 'handles an empty secrets list gracefully' {
        [hashtable[]]$empty = @()
        $report = Get-RotationReport -Secrets $empty -ReferenceDate ([datetime]'2026-03-15') -WarningDays 7
        $report.Summary.TotalSecrets | Should -Be 0
        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.OK.Count      | Should -Be 0
    }

    It 'handles a secret expiring exactly today as Warning (0 days left)' {
        [hashtable]$secret = @{
            Name        = 'today-expiry'
            LastRotated = ([datetime]'2026-03-01')
            PolicyDays  = 14
            RequiredBy  = @('svc')
        }
        # Expires 2026-03-15, reference is 2026-03-15 => 0 days left
        $result = Get-SecretStatus -Secret $secret -ReferenceDate ([datetime]'2026-03-15') -WarningDays 7
        $result.Urgency | Should -Be 'Warning'
        $result.DaysUntilExpiry | Should -Be 0
    }

    It 'supports a custom warning window of 0 days (only expired or ok)' {
        [hashtable]$secret = @{
            Name        = 'tight-window'
            LastRotated = ([datetime]'2026-03-01')
            PolicyDays  = 30
            RequiredBy  = @('svc')
        }
        # Expires 2026-03-31, reference 2026-03-27 => 4 days left, but warning=0 so it's OK
        $result = Get-SecretStatus -Secret $secret -ReferenceDate ([datetime]'2026-03-27') -WarningDays 0
        $result.Urgency | Should -Be 'OK'
    }

    It 'correctly formats markdown for empty groups' {
        [hashtable]$report = @{
            Expired = @()
            Warning = @()
            OK      = @()
            Summary = @{ TotalSecrets = 0; ExpiredCount = 0; WarningCount = 0; OKCount = 0;
                         ReportDate = ([datetime]'2026-03-15') }
        }
        [string]$md = ConvertTo-MarkdownReport -Report $report
        $md | Should -Match '_None_'
    }
}

Describe 'Mock Data' {
    BeforeAll {
        . "$PSScriptRoot/MockSecrets.ps1"
    }

    It 'Get-MockSecrets returns 8 secrets with all required fields' {
        [hashtable[]]$secrets = Get-MockSecrets
        $secrets.Count | Should -Be 8
        foreach ($s in $secrets) {
            $s.Name        | Should -Not -BeNullOrEmpty
            $s.LastRotated | Should -BeOfType [datetime]
            $s.PolicyDays  | Should -BeGreaterThan 0
            $s.RequiredBy  | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Integration: full pipeline' {
    BeforeAll {
        . "$PSScriptRoot/MockSecrets.ps1"
    }

    It 'generates a complete markdown report from mock data' {
        [hashtable[]]$secrets = Get-MockSecrets
        [datetime]$refDate = [datetime]'2026-04-08'
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $refDate -WarningDays 7
        [string]$md = ConvertTo-MarkdownReport -Report $report

        # Report should contain all secret names
        foreach ($s in $secrets) {
            $md | Should -Match $s.Name
        }
        # Should have at least one section
        $md | Should -Match '## EXPIRED|## WARNING|## OK'
    }

    It 'generates valid JSON report from mock data' {
        [hashtable[]]$secrets = Get-MockSecrets
        [datetime]$refDate = [datetime]'2026-04-08'
        $report = Get-RotationReport -Secrets $secrets -ReferenceDate $refDate -WarningDays 7
        [string]$json = ConvertTo-JsonReport -Report $report

        $parsed = $json | ConvertFrom-Json
        $parsed.summary.TotalSecrets | Should -Be 8
        # All groups should sum to total
        [int]$sum = $parsed.expired.Count + $parsed.warning.Count + $parsed.ok.Count
        $sum | Should -Be 8
    }
}
