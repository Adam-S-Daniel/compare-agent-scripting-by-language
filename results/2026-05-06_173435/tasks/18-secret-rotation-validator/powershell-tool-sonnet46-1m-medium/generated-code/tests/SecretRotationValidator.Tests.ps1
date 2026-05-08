# Secret Rotation Validator - Pester Unit Tests
# TDD approach: tests written first (red), then implementation makes them pass (green)

BeforeAll {
    # Dot-source the functions file so all tests share these functions
    . "$PSScriptRoot/../SecretRotationFunctions.ps1"
}

# ─── Get-SecretStatus ────────────────────────────────────────────────────────

Describe "Get-SecretStatus" {
    # Reference date used across all status tests for determinism
    $refDate = "2026-05-08"

    It "returns Expired when secret is past rotation deadline" {
        # SECRET_ALPHA: rotated 2026-01-01, policy 90 days -> expired 2026-04-01
        $result = Get-SecretStatus -LastRotated "2026-01-01" -PolicyDays 90 -ReferenceDate $refDate
        $result.Status | Should -Be "Expired"
    }

    It "returns correct DaysOverdue when expired" {
        # 2026-05-08 - 2026-04-01 = 37 days overdue
        $result = Get-SecretStatus -LastRotated "2026-01-01" -PolicyDays 90 -ReferenceDate $refDate
        $result.DaysOverdue | Should -Be 37
    }

    It "returns Warning when within the warning window" {
        # SECRET_BETA: rotated 2026-04-17, policy 30 days -> expires 2026-05-17 (9 days away)
        $result = Get-SecretStatus -LastRotated "2026-04-17" -PolicyDays 30 -WarningDays 14 -ReferenceDate $refDate
        $result.Status | Should -Be "Warning"
    }

    It "returns correct DaysUntilExpiry when in warning state" {
        $result = Get-SecretStatus -LastRotated "2026-04-17" -PolicyDays 30 -WarningDays 14 -ReferenceDate $refDate
        $result.DaysUntilExpiry | Should -Be 9
    }

    It "returns OK when outside the warning window" {
        # SECRET_GAMMA: rotated 2026-04-24, policy 30 days -> expires 2026-05-24 (16 days away)
        $result = Get-SecretStatus -LastRotated "2026-04-24" -PolicyDays 30 -WarningDays 14 -ReferenceDate $refDate
        $result.Status | Should -Be "OK"
    }

    It "returns correct DaysUntilExpiry when OK" {
        $result = Get-SecretStatus -LastRotated "2026-04-24" -PolicyDays 30 -WarningDays 14 -ReferenceDate $refDate
        $result.DaysUntilExpiry | Should -Be 16
    }

    It "treats boundary exactly-at-window as Warning (not OK)" {
        # Exactly 14 days until expiry with 14-day window should be Warning
        $result = Get-SecretStatus -LastRotated "2026-04-10" -PolicyDays 30 -WarningDays 14 -ReferenceDate $refDate
        # expiryDate = 2026-05-10 + 30 days? No: 2026-04-10 + 30 = 2026-05-10
        # daysUntilExpiry = 2026-05-10 - 2026-05-08 = 2 days... adjust test:
        # For exactly 14 days: expiry must be 2026-05-22, so lastRotated = 2026-04-22
        $result2 = Get-SecretStatus -LastRotated "2026-04-22" -PolicyDays 30 -WarningDays 14 -ReferenceDate $refDate
        # expiryDate = 2026-05-22, daysUntilExpiry = 14 -> exactly at boundary
        $result2.Status | Should -Be "Warning"
        $result2.DaysUntilExpiry | Should -Be 14
    }

    It "includes ExpiryDate in result" {
        $result = Get-SecretStatus -LastRotated "2026-01-01" -PolicyDays 90 -ReferenceDate $refDate
        $result.ExpiryDate | Should -Be "2026-04-01"
    }
}

# ─── Get-RotationReport ──────────────────────────────────────────────────────

Describe "Get-RotationReport" {
    BeforeAll {
        # Fixture: three secrets covering all three urgency states
        $script:testSecrets = @(
            [PSCustomObject]@{
                name               = "SECRET_ALPHA"
                lastRotated        = "2026-01-01"
                rotationPolicyDays = 90
                requiredBy         = @("api-service")
            },
            [PSCustomObject]@{
                name               = "SECRET_BETA"
                lastRotated        = "2026-04-17"
                rotationPolicyDays = 30
                requiredBy         = @("auth-service")
            },
            [PSCustomObject]@{
                name               = "SECRET_GAMMA"
                lastRotated        = "2026-04-24"
                rotationPolicyDays = 30
                requiredBy         = @("worker-service")
            }
        )
        $script:report = Get-RotationReport -Secrets $script:testSecrets -WarningDays 14 -ReferenceDate "2026-05-08"
    }

    It "groups expired secrets into Expired list" {
        $report.Expired | Should -HaveCount 1
        $report.Expired[0].Name | Should -Be "SECRET_ALPHA"
    }

    It "groups warning secrets into Warning list" {
        $report.Warning | Should -HaveCount 1
        $report.Warning[0].Name | Should -Be "SECRET_BETA"
    }

    It "groups OK secrets into OK list" {
        $report.OK | Should -HaveCount 1
        $report.OK[0].Name | Should -Be "SECRET_GAMMA"
    }

    It "includes GeneratedAt field" {
        $report.GeneratedAt | Should -Be "2026-05-08"
    }

    It "includes DaysOverdue for expired secrets" {
        $report.Expired[0].DaysOverdue | Should -Be 37
    }

    It "includes DaysUntilExpiry for warning secrets" {
        $report.Warning[0].DaysUntilExpiry | Should -Be 9
    }

    It "includes DaysUntilExpiry for OK secrets" {
        $report.OK[0].DaysUntilExpiry | Should -Be 16
    }

    It "includes RequiredBy in report entries" {
        $report.Expired[0].RequiredBy | Should -Contain "api-service"
    }
}

# ─── Format-ReportAsMarkdown ─────────────────────────────────────────────────

Describe "Format-ReportAsMarkdown" {
    BeforeAll {
        $secrets = @(
            [PSCustomObject]@{
                name               = "SECRET_ALPHA"
                lastRotated        = "2026-01-01"
                rotationPolicyDays = 90
                requiredBy         = @("api-service")
            },
            [PSCustomObject]@{
                name               = "SECRET_BETA"
                lastRotated        = "2026-04-17"
                rotationPolicyDays = 30
                requiredBy         = @("auth-service")
            },
            [PSCustomObject]@{
                name               = "SECRET_GAMMA"
                lastRotated        = "2026-04-24"
                rotationPolicyDays = 30
                requiredBy         = @("worker-service")
            }
        )
        $rep = Get-RotationReport -Secrets $secrets -WarningDays 14 -ReferenceDate "2026-05-08"
        $script:md = Format-ReportAsMarkdown -Report $rep
    }

    It "contains report header" {
        $md | Should -Match "# Secret Rotation Report"
    }

    It "contains EXPIRED section" {
        $md | Should -Match "EXPIRED"
    }

    It "contains WARNING section" {
        $md | Should -Match "WARNING"
    }

    It "contains OK section" {
        $md | Should -Match "OK"
    }

    It "lists expired secret name in EXPIRED section" {
        $md | Should -Match "SECRET_ALPHA"
    }

    It "lists warning secret name in WARNING section" {
        $md | Should -Match "SECRET_BETA"
    }

    It "lists OK secret name in OK section" {
        $md | Should -Match "SECRET_GAMMA"
    }

    It "includes GeneratedAt date" {
        $md | Should -Match "2026-05-08"
    }

    It "includes summary table with counts" {
        $md | Should -Match "## Summary"
        $md | Should -Match "\| Expired"
        $md | Should -Match "\| Warning"
        $md | Should -Match "\| OK"
    }
}

# ─── Format-ReportAsJson ─────────────────────────────────────────────────────

Describe "Format-ReportAsJson" {
    BeforeAll {
        $secrets = @(
            [PSCustomObject]@{
                name               = "SECRET_ALPHA"
                lastRotated        = "2026-01-01"
                rotationPolicyDays = 90
                requiredBy         = @("api-service")
            }
        )
        $rep = Get-RotationReport -Secrets $secrets -WarningDays 14 -ReferenceDate "2026-05-08"
        $script:jsonStr = Format-ReportAsJson -Report $rep
    }

    It "returns valid JSON" {
        { $jsonStr | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON contains Expired array" {
        $obj = $jsonStr | ConvertFrom-Json
        $obj.Expired | Should -Not -BeNullOrEmpty
    }

    It "JSON contains GeneratedAt" {
        $obj = $jsonStr | ConvertFrom-Json
        $obj.GeneratedAt | Should -Be "2026-05-08"
    }

    It "JSON expired entry has correct DaysOverdue" {
        $obj = $jsonStr | ConvertFrom-Json
        $obj.Expired[0].DaysOverdue | Should -Be 37
    }

    It "JSON expired entry has correct Name" {
        $obj = $jsonStr | ConvertFrom-Json
        $obj.Expired[0].Name | Should -Be "SECRET_ALPHA"
    }
}
