# TDD tests for Secret Rotation Validator
# Red/Green cycle: write failing test, implement minimum code, refactor

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

Describe "Get-SecretStatus" {
    # Test 1 (RED): expired secret is identified correctly
    It "marks a secret as expired when past rotation date" {
        $secret = @{
            Name         = "DB_PASSWORD"
            LastRotated  = (Get-Date).AddDays(-100)
            RotationDays = 90
            RequiredBy   = @("api-service", "worker")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate (Get-Date) -WarningDays 14
        $result.Status | Should -Be "expired"
    }

    # Test 2 (RED): secret expiring within warning window
    It "marks a secret as warning when expiring within warning window" {
        $secret = @{
            Name         = "API_KEY"
            LastRotated  = (Get-Date).AddDays(-80)
            RotationDays = 90
            RequiredBy   = @("frontend")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate (Get-Date) -WarningDays 14
        $result.Status | Should -Be "warning"
    }

    # Test 3 (RED): healthy secret
    It "marks a secret as ok when well within rotation window" {
        $secret = @{
            Name         = "JWT_SECRET"
            LastRotated  = (Get-Date).AddDays(-10)
            RotationDays = 90
            RequiredBy   = @("auth-service")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate (Get-Date) -WarningDays 14
        $result.Status | Should -Be "ok"
    }

    # Test 4 (RED): DaysUntilExpiry is calculated correctly
    It "calculates DaysUntilExpiry correctly" {
        $refDate = [datetime]"2026-01-01"
        $secret = @{
            Name         = "WEBHOOK_SECRET"
            LastRotated  = [datetime]"2025-11-01"
            RotationDays = 90
            RequiredBy   = @()
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        # LastRotated 2025-11-01 + 90 days = 2026-01-30, which is 29 days from 2026-01-01
        $result.DaysUntilExpiry | Should -Be 29
    }

    # Test 5 (RED): negative DaysUntilExpiry for expired
    It "returns negative DaysUntilExpiry for expired secrets" {
        $refDate = [datetime]"2026-04-01"
        $secret = @{
            Name         = "OLD_KEY"
            LastRotated  = [datetime]"2026-01-01"
            RotationDays = 30
            RequiredBy   = @()
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.DaysUntilExpiry | Should -BeLessThan 0
        $result.Status | Should -Be "expired"
    }
}

Describe "Invoke-SecretRotationReport" {
    BeforeAll {
        # Fixed reference date for deterministic tests
        $script:RefDate = [datetime]"2026-04-19"

        $script:TestSecrets = @(
            @{
                Name         = "DB_PASSWORD"
                LastRotated  = $script:RefDate.AddDays(-95)
                RotationDays = 90
                RequiredBy   = @("api", "worker")
            },
            @{
                Name         = "API_KEY"
                LastRotated  = $script:RefDate.AddDays(-80)
                RotationDays = 90
                RequiredBy   = @("frontend")
            },
            @{
                Name         = "JWT_SECRET"
                LastRotated  = $script:RefDate.AddDays(-10)
                RotationDays = 90
                RequiredBy   = @("auth")
            }
        )
    }

    # Test 6 (RED): report groups secrets by urgency
    It "groups secrets into expired, warning, and ok categories" {
        $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets -ReferenceDate $script:RefDate -WarningDays 14
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count | Should -Be 1
    }

    It "puts expired secret in the Expired group" {
        $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets -ReferenceDate $script:RefDate -WarningDays 14
        $report.Expired[0].Name | Should -Be "DB_PASSWORD"
    }

    It "puts warning secret in the Warning group" {
        $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets -ReferenceDate $script:RefDate -WarningDays 14
        $report.Warning[0].Name | Should -Be "API_KEY"
    }

    It "puts ok secret in the Ok group" {
        $report = Invoke-SecretRotationReport -Secrets $script:TestSecrets -ReferenceDate $script:RefDate -WarningDays 14
        $report.Ok[0].Name | Should -Be "JWT_SECRET"
    }
}

Describe "Format-RotationReport" {
    BeforeAll {
        $refDate = [datetime]"2026-04-19"
        $secrets = @(
            @{ Name = "DB_PASSWORD"; LastRotated = $refDate.AddDays(-95); RotationDays = 90; RequiredBy = @("api") },
            @{ Name = "JWT_SECRET";  LastRotated = $refDate.AddDays(-10); RotationDays = 90; RequiredBy = @("auth") }
        )
        $script:Report = Invoke-SecretRotationReport -Secrets $secrets -ReferenceDate $refDate -WarningDays 14
    }

    # Test 7 (RED): markdown output contains table header
    It "produces markdown output with table headers" {
        $output = Format-RotationReport -Report $script:Report -Format "markdown"
        $output | Should -Match "\|.*Name.*\|"
        $output | Should -Match "\|.*Status.*\|"
    }

    It "produces markdown output with section headers for each urgency" {
        $output = Format-RotationReport -Report $script:Report -Format "markdown"
        $output | Should -Match "## Expired"
        $output | Should -Match "## Ok"
    }

    # Test 8 (RED): JSON output is valid JSON with expected keys
    It "produces valid JSON output" {
        $output = Format-RotationReport -Report $script:Report -Format "json"
        { $output | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON output contains expired and ok arrays" {
        $output = Format-RotationReport -Report $script:Report -Format "json"
        $json = $output | ConvertFrom-Json
        $json.expired | Should -Not -BeNullOrEmpty
        $json.ok | Should -Not -BeNullOrEmpty
    }

    It "throws on unsupported format" {
        { Format-RotationReport -Report $script:Report -Format "xml" } | Should -Throw
    }
}

Describe "Get-DefaultSecrets" {
    # Test 9 (RED): default fixture data is loaded
    It "returns a non-empty list of secrets" {
        $secrets = Get-DefaultSecrets
        $secrets | Should -Not -BeNullOrEmpty
        $secrets.Count | Should -BeGreaterThan 0
    }

    It "each secret has required fields" {
        $secrets = Get-DefaultSecrets
        foreach ($s in $secrets) {
            $s.Name | Should -Not -BeNullOrEmpty
            $s.LastRotated | Should -BeOfType [datetime]
            $s.RotationDays | Should -BeGreaterThan 0
        }
    }
}
