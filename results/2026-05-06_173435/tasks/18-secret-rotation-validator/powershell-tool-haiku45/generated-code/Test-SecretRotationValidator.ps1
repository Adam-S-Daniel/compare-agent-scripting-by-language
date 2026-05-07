param(
    [string]$TestMode = "all"
)

# Red/Green TDD: Start with failing tests that drive implementation

Describe "SecretRotationValidator Module" {

    # Load the module
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "SecretRotationValidator.ps1"
        . $scriptPath
    }

    Describe "Parse-SecretConfig" {

        It "should parse a valid secret configuration JSON" {
            $configJson = @"
[
    {
        "name": "db-password",
        "lastRotated": "2026-04-06",
        "rotationPolicyDays": 30,
        "requiredByServices": ["api", "worker"]
    }
]
"@
            $config = Parse-SecretConfig -ConfigJson $configJson
            $config | Should -Not -BeNullOrEmpty
            $config.Count | Should -Be 1
            $config[0].name | Should -Be "db-password"
            $config[0].lastRotated | Should -Be "2026-04-06"
            $config[0].rotationPolicyDays | Should -Be 30
            $config[0].requiredByServices | Should -Contain "api"
        }

        It "should throw on invalid JSON" {
            $invalidJson = "{ invalid json }"
            { Parse-SecretConfig -ConfigJson $invalidJson } | Should -Throw
        }
    }

    Describe "Test-SecretExpiration" {

        It "should identify an expired secret" {
            $secret = @{
                name = "old-secret"
                lastRotated = "2026-03-01"
                rotationPolicyDays = 10
            }
            $today = Get-Date "2026-04-06"
            $isExpired = Test-SecretExpiration -Secret $secret -ReferenceDate $today
            $isExpired | Should -Be $true
        }

        It "should identify a non-expired secret" {
            $secret = @{
                name = "new-secret"
                lastRotated = "2026-04-05"
                rotationPolicyDays = 30
            }
            $today = Get-Date "2026-04-06"
            $isExpired = Test-SecretExpiration -Secret $secret -ReferenceDate $today
            $isExpired | Should -Be $false
        }

        It "should identify a secret in warning window" {
            $secret = @{
                name = "warning-secret"
                lastRotated = "2026-03-25"
                rotationPolicyDays = 14
            }
            $today = Get-Date "2026-04-06"
            $warningDays = 5
            $inWarning = Test-SecretWarning -Secret $secret -ReferenceDate $today -WarningDays $warningDays
            $inWarning | Should -Be $true
        }
    }

    Describe "Get-RotationStatus" {

        It "should categorize secrets by status (expired, warning, ok)" {
            $secrets = @(
                @{ name = "expired"; lastRotated = "2026-03-01"; rotationPolicyDays = 10 },
                @{ name = "warning"; lastRotated = "2026-03-25"; rotationPolicyDays = 14 },
                @{ name = "ok"; lastRotated = "2026-04-05"; rotationPolicyDays = 30 }
            )
            $today = Get-Date "2026-04-06"
            $statuses = Get-RotationStatus -Secrets $secrets -ReferenceDate $today -WarningDays 5

            $expired = @($statuses | Where-Object { $_.status -eq "expired" })
            $warning = @($statuses | Where-Object { $_.status -eq "warning" })
            $ok = @($statuses | Where-Object { $_.status -eq "ok" })

            $expired.Count | Should -Be 1
            $warning.Count | Should -Be 1
            $ok.Count | Should -Be 1
        }
    }

    Describe "Format-RotationReport" {

        It "should generate a markdown table" {
            $statuses = @(
                @{ name = "db-pass"; status = "ok"; daysUntilRotation = 24 }
            )
            $output = Format-RotationReport -Statuses $statuses -Format "markdown"
            $output | Should -Match "markdown|Table|Secret"
            $output | Should -Match "db-pass"
        }

        It "should generate JSON output" {
            $statuses = @(
                @{ name = "db-pass"; status = "ok"; daysUntilRotation = 24 }
            )
            $output = Format-RotationReport -Statuses $statuses -Format "json"
            $parsed = $output | ConvertFrom-Json
            $parsed[0].name | Should -Be "db-pass"
            $parsed[0].status | Should -Be "ok"
        }
    }

    Describe "Invoke-SecretRotationValidator" {

        It "should process a complete rotation validation workflow" {
            $configJson = @"
[
    {
        "name": "api-key",
        "lastRotated": "2026-03-01",
        "rotationPolicyDays": 20,
        "requiredByServices": ["frontend"]
    },
    {
        "name": "db-password",
        "lastRotated": "2026-04-05",
        "rotationPolicyDays": 30,
        "requiredByServices": ["api", "worker"]
    }
]
"@
            $today = Get-Date "2026-04-06"
            $result = Invoke-SecretRotationValidator -ConfigJson $configJson -ReferenceDate $today -Format "markdown" -WarningDays 5

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "api-key|db-password"
        }
    }

    Describe "Edge Cases and Error Handling" {

        It "should handle empty secret configuration" {
            $emptyConfig = "[]"
            $today = Get-Date "2026-04-06"
            $result = Invoke-SecretRotationValidator -ConfigJson $emptyConfig -ReferenceDate $today -Format "markdown"
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "Secret Rotation Report"
        }

        It "should handle multiple services per secret" {
            $configJson = @"
[
    {
        "name": "multi-service-secret",
        "lastRotated": "2026-04-05",
        "rotationPolicyDays": 7,
        "requiredByServices": ["api", "worker", "scheduler", "cache"]
    }
]
"@
            $today = Get-Date "2026-04-06"
            $result = Invoke-SecretRotationValidator -ConfigJson $configJson -ReferenceDate $today -Format "markdown"
            $result | Should -Match "api.*worker.*scheduler.*cache"
        }

        It "should calculate days until rotation correctly for expired secrets" {
            $secrets = @(
                @{ name = "very-expired"; lastRotated = "2026-01-01"; rotationPolicyDays = 10; requiredByServices = @("app") }
            )
            $today = Get-Date "2026-04-06"
            $statuses = Get-RotationStatus -Secrets $secrets -ReferenceDate $today -WarningDays 5

            $statuses[0].daysUntilRotation | Should -BeLessThan 0
            $statuses[0].status | Should -Be "expired"
        }

        It "should output valid JSON format" {
            $configJson = @"
[
    {
        "name": "test-secret",
        "lastRotated": "2026-04-05",
        "rotationPolicyDays": 10,
        "requiredByServices": ["app"]
    }
]
"@
            $today = Get-Date "2026-04-06"
            $jsonOutput = Invoke-SecretRotationValidator -ConfigJson $configJson -ReferenceDate $today -Format "json"

            { $jsonOutput | ConvertFrom-Json } | Should -Not -Throw
            $parsed = $jsonOutput | ConvertFrom-Json
            $parsed | Should -HaveCount 1
        }

        It "should handle configurable warning window" {
            $today = Get-Date "2026-04-06"
            $secrets = @(
                @{ name = "window-test"; lastRotated = "2026-03-20"; rotationPolicyDays = 20; requiredByServices = @("app") }
            )

            $longWarning = Get-RotationStatus -Secrets $secrets -ReferenceDate $today -WarningDays 15
            $longWarning[0].status | Should -Be "warning"

            $shortWarning = Get-RotationStatus -Secrets $secrets -ReferenceDate $today -WarningDays 1
            $shortWarning[0].status | Should -Be "ok"
        }
    }
}

Write-Host "All tests defined. Running with Invoke-Pester..."
