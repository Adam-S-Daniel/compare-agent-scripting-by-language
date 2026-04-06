#Requires -Modules Pester
# SecretRotationValidator.Tests.ps1
# TDD test suite for the Secret Rotation Validator
#
# RED/GREEN TDD approach:
#   1. Write a failing test
#   2. Write minimum code to pass it
#   3. Refactor
#   4. Repeat for each piece of functionality
#
# Tests are organized by function in the order they were developed.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test
    [string]$modulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
    Import-Module $modulePath -Force

    # Fixed reference date for deterministic tests (avoids time-of-day sensitivity)
    [datetime]$script:RefDate = [datetime]'2024-06-15'

    # --- TEST FIXTURE FACTORY ---
    # Helper to create secret config objects with minimal boilerplate in tests
    function New-SecretFixture {
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [datetime]$LastRotated,

            [Parameter(Mandatory)]
            [int]$RotationDays,

            [Parameter()]
            [string[]]$RequiredBy = @('test-service')
        )
        return [PSCustomObject]@{
            Name         = $Name
            LastRotated  = $LastRotated
            RotationDays = $RotationDays
            RequiredBy   = $RequiredBy
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 1: Get-SecretStatus — expired detection
# FIRST FAILING TEST: This test fails before SecretRotationValidator.psm1 exists
# =============================================================================

Describe 'Get-SecretStatus' {

    Context 'Expired secrets' {
        It 'Returns expired status when secret is past its rotation date' {
            # Arrange: 100 days ago, 90-day policy → expired by 10 days
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'DB_PASSWORD' `
                -LastRotated $script:RefDate.AddDays(-100) `
                -RotationDays 90

            # Act
            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            # Assert
            $result.Status | Should -Be 'expired'
        }

        It 'Returns negative DaysUntilExpiry when expired' {
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'API_KEY' `
                -LastRotated $script:RefDate.AddDays(-100) `
                -RotationDays 90

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.DaysUntilExpiry | Should -BeLessThan 0
            $result.DaysUntilExpiry | Should -Be -10
        }

        It 'Handles a secret expired by exactly 1 day' {
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'DB_PASSWORD' `
                -LastRotated $script:RefDate.AddDays(-91) `
                -RotationDays 90

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.Status | Should -Be 'expired'
            $result.DaysUntilExpiry | Should -Be -1
        }
    }

    # =============================================================================
    # RED/GREEN CYCLE 2: Get-SecretStatus — warning window detection
    # =============================================================================

    Context 'Warning secrets' {
        It 'Returns warning status when secret is within the warning window' {
            # 83 days ago, 90-day policy → expires in 7 days (inside 14-day warning)
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'SMTP_PASSWORD' `
                -LastRotated $script:RefDate.AddDays(-83) `
                -RotationDays 90

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.Status | Should -Be 'warning'
        }

        It 'Returns warning when DaysUntilExpiry exactly equals warning window boundary' {
            # 76 days ago, 90-day policy → expires in exactly 14 days (boundary = warning)
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'AUTH_TOKEN' `
                -LastRotated $script:RefDate.AddDays(-76) `
                -RotationDays 90

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.Status | Should -Be 'warning'
            $result.DaysUntilExpiry | Should -Be 14
        }
    }

    # =============================================================================
    # RED/GREEN CYCLE 3: Get-SecretStatus — OK status
    # =============================================================================

    Context 'OK secrets' {
        It 'Returns ok status for a recently rotated secret' {
            # 10 days ago, 90-day policy → 80 days remaining
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'FRESH_SECRET' `
                -LastRotated $script:RefDate.AddDays(-10) `
                -RotationDays 90

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.Status | Should -Be 'ok'
        }

        It 'Returns ok when exactly 1 day outside the warning window' {
            # 75 days ago, 90-day policy → expires in 15 days (just outside 14-day warning)
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'NEAR_SECRET' `
                -LastRotated $script:RefDate.AddDays(-75) `
                -RotationDays 90

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.Status | Should -Be 'ok'
            $result.DaysUntilExpiry | Should -Be 15
        }
    }

    # =============================================================================
    # RED/GREEN CYCLE 4: Get-SecretStatus — output object shape
    # =============================================================================

    Context 'Output object properties' {
        It 'Returns all expected properties with correct values' {
            [PSCustomObject]$secret = New-SecretFixture `
                -Name 'TEST_SECRET' `
                -LastRotated $script:RefDate.AddDays(-50) `
                -RotationDays 90 `
                -RequiredBy @('app1', 'app2')

            [PSCustomObject]$result = Get-SecretStatus -Secret $secret -WarningDays 14 -ReferenceDate $script:RefDate

            $result.Name            | Should -Be 'TEST_SECRET'
            $result.RotationDays    | Should -Be 90
            $result.DaysUntilExpiry | Should -Be 40
            $result.ExpiryDate      | Should -Be ([datetime]$script:RefDate.AddDays(-50).AddDays(90))
            $result.RequiredBy      | Should -Contain 'app1'
            $result.RequiredBy      | Should -Contain 'app2'
        }
    }
}

# =============================================================================
# RED/GREEN CYCLE 5: Get-RotationReport — grouping secrets by urgency
# =============================================================================

Describe 'Get-RotationReport' {

    BeforeEach {
        # Mixed fixture: 2 expired, 1 warning, 2 ok
        [PSCustomObject[]]$script:TestSecrets = @(
            (New-SecretFixture -Name 'EXPIRED_1' -LastRotated $script:RefDate.AddDays(-100) -RotationDays 90 -RequiredBy @('web'))
            (New-SecretFixture -Name 'EXPIRED_2' -LastRotated $script:RefDate.AddDays(-120) -RotationDays 90 -RequiredBy @('api'))
            (New-SecretFixture -Name 'WARNING_1' -LastRotated $script:RefDate.AddDays(-83)  -RotationDays 90 -RequiredBy @('app'))
            (New-SecretFixture -Name 'OK_1'      -LastRotated $script:RefDate.AddDays(-10)  -RotationDays 90 -RequiredBy @('db'))
            (New-SecretFixture -Name 'OK_2'      -LastRotated $script:RefDate.AddDays(-5)   -RotationDays 90 -RequiredBy @('cache'))
        )
    }

    It 'Groups secrets into correct urgency buckets' {
        [hashtable]$report = Get-RotationReport -Secrets $script:TestSecrets -WarningDays 14 -ReferenceDate $script:RefDate

        $report.Expired.Count | Should -Be 2
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count      | Should -Be 2
    }

    It 'Correctly identifies expired secret names' {
        [hashtable]$report = Get-RotationReport -Secrets $script:TestSecrets -WarningDays 14 -ReferenceDate $script:RefDate

        $report.Expired.Name | Should -Contain 'EXPIRED_1'
        $report.Expired.Name | Should -Contain 'EXPIRED_2'
    }

    It 'Includes WarningDays metadata in the report' {
        [hashtable]$report = Get-RotationReport -Secrets $script:TestSecrets -WarningDays 14 -ReferenceDate $script:RefDate

        $report.WarningDays | Should -Be 14
    }

    It 'Returns empty arrays for groups with no secrets' {
        [PSCustomObject[]]$allOk = @(
            (New-SecretFixture -Name 'OK_ONLY' -LastRotated $script:RefDate.AddDays(-10) -RotationDays 90)
        )

        [hashtable]$report = Get-RotationReport -Secrets $allOk -WarningDays 14 -ReferenceDate $script:RefDate

        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.Ok.Count      | Should -Be 1
    }

    It 'Handles an empty secrets array without error' {
        [PSCustomObject[]]$emptySecrets = [PSCustomObject[]]@()

        [hashtable]$report = Get-RotationReport -Secrets $emptySecrets -WarningDays 14 -ReferenceDate $script:RefDate

        $report.Expired.Count | Should -Be 0
        $report.Warning.Count | Should -Be 0
        $report.Ok.Count      | Should -Be 0
    }
}

# =============================================================================
# RED/GREEN CYCLE 6: Format-MarkdownTable — markdown output format
# =============================================================================

Describe 'Format-MarkdownTable' {

    BeforeEach {
        [PSCustomObject[]]$script:MixedSecrets = @(
            (New-SecretFixture -Name 'EXPIRED_DB'   -LastRotated $script:RefDate.AddDays(-100) -RotationDays 90 -RequiredBy @('web', 'api'))
            (New-SecretFixture -Name 'WARNING_SMTP'  -LastRotated $script:RefDate.AddDays(-83)  -RotationDays 90 -RequiredBy @('mailer'))
            (New-SecretFixture -Name 'OK_TOKEN'      -LastRotated $script:RefDate.AddDays(-5)   -RotationDays 90 -RequiredBy @('service'))
        )
        [hashtable]$script:MdReport = Get-RotationReport `
            -Secrets $script:MixedSecrets `
            -WarningDays 14 `
            -ReferenceDate $script:RefDate
    }

    It 'Starts with the markdown report header' {
        [string]$output = Format-MarkdownTable -Report $script:MdReport

        $output | Should -Match '# Secret Rotation Report'
    }

    It 'Contains a summary table with correct counts' {
        [string]$output = Format-MarkdownTable -Report $script:MdReport

        $output | Should -Match '\| Expired \|'
        $output | Should -Match '\| Warning \|'
        $output | Should -Match '\| OK \|'
    }

    It 'Contains the expired secret name' {
        [string]$output = Format-MarkdownTable -Report $script:MdReport

        $output | Should -Match 'EXPIRED_DB'
    }

    It 'Shows OVERDUE indicator for expired secrets' {
        [string]$output = Format-MarkdownTable -Report $script:MdReport

        $output | Should -Match 'OVERDUE'
    }

    It 'Contains warning secret name' {
        [string]$output = Format-MarkdownTable -Report $script:MdReport

        $output | Should -Match 'WARNING_SMTP'
    }

    It 'Lists all RequiredBy services joined in the table' {
        [string]$output = Format-MarkdownTable -Report $script:MdReport

        $output | Should -Match 'web, api'
    }

    It 'Shows a placeholder message when a group has no secrets' {
        [PSCustomObject[]]$singleExpired = @(
            (New-SecretFixture -Name 'ONLY_EXPIRED' -LastRotated $script:RefDate.AddDays(-100) -RotationDays 90)
        )
        [hashtable]$report = Get-RotationReport -Secrets $singleExpired -WarningDays 14 -ReferenceDate $script:RefDate

        [string]$output = Format-MarkdownTable -Report $report

        $output | Should -Match 'No secrets in this category'
    }
}

# =============================================================================
# RED/GREEN CYCLE 7: Format-JsonOutput — JSON output format
# =============================================================================

Describe 'Format-JsonOutput' {

    BeforeEach {
        [PSCustomObject[]]$script:JsonSecrets = @(
            (New-SecretFixture -Name 'EXPIRED_KEY'    -LastRotated $script:RefDate.AddDays(-100) -RotationDays 90 -RequiredBy @('api'))
            (New-SecretFixture -Name 'WARNING_TOKEN'  -LastRotated $script:RefDate.AddDays(-83)  -RotationDays 90 -RequiredBy @('web'))
        )
        [hashtable]$script:JsonReport = Get-RotationReport `
            -Secrets $script:JsonSecrets `
            -WarningDays 14 `
            -ReferenceDate $script:RefDate
    }

    It 'Produces valid JSON' {
        [string]$output = Format-JsonOutput -Report $script:JsonReport

        { $null = $output | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'JSON summary has correct counts' {
        [string]$output = Format-JsonOutput -Report $script:JsonReport
        [PSCustomObject]$parsed = $output | ConvertFrom-Json

        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok      | Should -Be 0
    }

    It 'JSON contains expired secret details with correct fields' {
        [string]$output = Format-JsonOutput -Report $script:JsonReport
        [PSCustomObject]$parsed = $output | ConvertFrom-Json

        $parsed.secrets.expired[0].name            | Should -Be 'EXPIRED_KEY'
        $parsed.secrets.expired[0].daysUntilExpiry | Should -Be -10
    }

    It 'JSON contains the warningDays field' {
        [string]$output = Format-JsonOutput -Report $script:JsonReport
        [PSCustomObject]$parsed = $output | ConvertFrom-Json

        $parsed.warningDays | Should -Be 14
    }

    It 'JSON requiredBy field is accessible as array element' {
        [string]$output = Format-JsonOutput -Report $script:JsonReport
        [PSCustomObject]$parsed = $output | ConvertFrom-Json

        $parsed.secrets.expired[0].requiredBy[0] | Should -Be 'api'
    }

    It 'JSON summary includes total count' {
        [string]$output = Format-JsonOutput -Report $script:JsonReport
        [PSCustomObject]$parsed = $output | ConvertFrom-Json

        $parsed.summary.total | Should -Be 2
    }
}

# =============================================================================
# RED/GREEN CYCLE 8: Invoke-SecretRotationValidator — integration / entry point
# =============================================================================

Describe 'Invoke-SecretRotationValidator' {

    BeforeEach {
        [PSCustomObject[]]$script:IntegSecrets = @(
            (New-SecretFixture -Name 'EXPIRED' -LastRotated $script:RefDate.AddDays(-100) -RotationDays 90)
            (New-SecretFixture -Name 'OK'      -LastRotated $script:RefDate.AddDays(-10)  -RotationDays 90)
        )
    }

    It 'Returns markdown output by default' {
        [string]$result = Invoke-SecretRotationValidator `
            -Secrets $script:IntegSecrets `
            -WarningDays 14 `
            -ReferenceDate $script:RefDate

        $result | Should -Match '# Secret Rotation Report'
    }

    It 'Returns valid JSON when OutputFormat is Json' {
        [string]$result = Invoke-SecretRotationValidator `
            -Secrets $script:IntegSecrets `
            -WarningDays 14 `
            -OutputFormat 'Json' `
            -ReferenceDate $script:RefDate

        { $null = $result | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Respects a custom warning window — larger window promotes ok to warning' {
        # Secret expires in 7 days; with WarningDays=14 it's warning, with WarningDays=5 it's ok
        [PSCustomObject[]]$secrets = @(
            (New-SecretFixture -Name 'EXPIRING' -LastRotated $script:RefDate.AddDays(-83) -RotationDays 90)
        )

        [string]$result = Invoke-SecretRotationValidator `
            -Secrets $secrets `
            -WarningDays 5 `
            -OutputFormat 'Json' `
            -ReferenceDate $script:RefDate
        [PSCustomObject]$parsed = $result | ConvertFrom-Json

        # 7 days until expiry > 5-day warning window → OK
        $parsed.summary.ok      | Should -Be 1
        $parsed.summary.warning | Should -Be 0
    }

    It 'Respects a custom warning window — secret in window is warning' {
        [PSCustomObject[]]$secrets = @(
            (New-SecretFixture -Name 'EXPIRING' -LastRotated $script:RefDate.AddDays(-83) -RotationDays 90)
        )

        [string]$result = Invoke-SecretRotationValidator `
            -Secrets $secrets `
            -WarningDays 14 `
            -OutputFormat 'Json' `
            -ReferenceDate $script:RefDate
        [PSCustomObject]$parsed = $result | ConvertFrom-Json

        # 7 days until expiry ≤ 14-day warning window → Warning
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok      | Should -Be 0
    }
}
