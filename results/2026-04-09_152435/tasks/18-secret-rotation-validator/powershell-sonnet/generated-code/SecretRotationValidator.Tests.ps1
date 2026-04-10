# SecretRotationValidator.Tests.ps1
# Pester test suite for the Secret Rotation Validator
# Follows red/green TDD: tests are written first, then implementation follows.
#
# Reference date used throughout tests: 2026-04-10 (fixed for determinism)
#   EXPIRED_DB_PASSWORD: rotated 2026-01-01, policy 90d -> expiry 2026-04-01 -> -9 days (EXPIRED)
#   WARNING_API_KEY:     rotated 2026-01-17, policy 90d -> expiry 2026-04-17 ->  7 days (WARNING)
#   OK_OAUTH_SECRET:     rotated 2026-02-01, policy 90d -> expiry 2026-05-02 -> 22 days (OK)

BeforeAll {
    # Dot-source the main script to load functions without executing main body
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

# ============================================================
# TDD Round 1: Get-SecretStatus - classify individual secrets
# ============================================================

Describe "Get-SecretStatus" {

    It "Returns 'expired' when secret is past its rotation deadline" {
        # RED: This test fails until Get-SecretStatus is implemented
        $secret = @{
            name               = "DB_PASSWORD"
            lastRotated        = "2026-01-01"
            rotationPolicyDays = 90
            requiredBy         = @("api-server")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.urgency | Should -Be "expired"
    }

    It "Returns 'warning' when secret is within the warning window" {
        $secret = @{
            name               = "API_KEY"
            lastRotated        = "2026-01-17"
            rotationPolicyDays = 90
            requiredBy         = @("payment-service")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.urgency | Should -Be "warning"
    }

    It "Returns 'ok' when secret is healthy and not near expiry" {
        $secret = @{
            name               = "OAUTH_SECRET"
            lastRotated        = "2026-02-01"
            rotationPolicyDays = 90
            requiredBy         = @("web-app")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.urgency | Should -Be "ok"
    }

    It "Computes the correct expiry date" {
        $secret = @{
            name               = "TEST_SECRET"
            lastRotated        = "2026-01-01"
            rotationPolicyDays = 90
            requiredBy         = @()
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.expiryDate | Should -Be "2026-04-01"
    }

    It "Computes negative daysUntilExpiry for expired secrets" {
        $secret = @{
            name               = "OLD_SECRET"
            lastRotated        = "2026-01-01"
            rotationPolicyDays = 90
            requiredBy         = @()
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.daysUntilExpiry | Should -Be -9
    }

    It "Handles warning boundary: exactly at warning window" {
        # Exactly 14 days until expiry -> should be "warning"
        # 2026-01-17 + 97 days = 2026-04-24  (14 days after reference 2026-04-10)
        # Calculation: 14 (rest of Jan) + 28 (Feb) + 31 (Mar) + 24 (Apr 1-24) = 97
        $secret = @{
            name               = "BOUNDARY_SECRET"
            lastRotated        = "2026-01-17"
            rotationPolicyDays = 97
            requiredBy         = @()
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.urgency | Should -Be "warning"
        $result.daysUntilExpiry | Should -Be 14
    }

    It "Handles exactly-expired boundary: 0 days until expiry is warning (expires today)" {
        # Expiry = today -> 0 days -> still "warning" (not yet expired)
        $secret = @{
            name               = "TODAY_EXPIRY"
            lastRotated        = "2026-01-10"
            rotationPolicyDays = 90   # 2026-01-10 + 90 = 2026-04-10 exactly
            requiredBy         = @()
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.urgency | Should -Be "warning"
        $result.daysUntilExpiry | Should -Be 0
    }

    It "Passes through requiredBy services" {
        $secret = @{
            name               = "MULTI_SERVICE"
            lastRotated        = "2026-02-01"
            rotationPolicyDays = 90
            requiredBy         = @("svc-a", "svc-b", "svc-c")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.requiredBy | Should -HaveCount 3
    }

    It "Accepts PSCustomObject secrets (from ConvertFrom-Json)" {
        # ConvertFrom-Json returns PSCustomObject, not hashtable
        $secret = [PSCustomObject]@{
            name               = "JSON_SECRET"
            lastRotated        = "2026-02-01"
            rotationPolicyDays = 90
            requiredBy         = @("service-x")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $result.urgency | Should -Be "ok"
    }
}

# ============================================================
# TDD Round 2: New-RotationReport - generate report from statuses
# ============================================================

Describe "New-RotationReport" {

    BeforeAll {
        # Build a set of statuses using fixed reference date
        $script:mixedSecrets = @(
            @{ name = "EXPIRED_DB_PASSWORD"; lastRotated = "2026-01-01"; rotationPolicyDays = 90; requiredBy = @("api-server", "auth-service") },
            @{ name = "WARNING_API_KEY";     lastRotated = "2026-01-17"; rotationPolicyDays = 90; requiredBy = @("payment-service") },
            @{ name = "OK_OAUTH_SECRET";     lastRotated = "2026-02-01"; rotationPolicyDays = 90; requiredBy = @("web-app") }
        )
        $script:statuses = $script:mixedSecrets | ForEach-Object {
            Get-SecretStatus -Secret $_ -ReferenceDate "2026-04-10" -WarningWindowDays 14
        }
    }

    It "Produces a report object with summary counts" {
        $report = New-RotationReport -Statuses $script:statuses -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.summary.total   | Should -Be 3
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok      | Should -Be 1
    }

    It "Produces valid JSON output when Format is 'json'" {
        $report = New-RotationReport -Statuses $script:statuses -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        { $report | ConvertFrom-Json } | Should -Not -Throw
    }

    It "Groups expired secrets correctly in JSON output" {
        $report = New-RotationReport -Statuses $script:statuses -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.notifications.expired[0].name | Should -Be "EXPIRED_DB_PASSWORD"
        $parsed.notifications.expired[0].urgency | Should -Be "expired"
    }

    It "Groups warning secrets correctly in JSON output" {
        $report = New-RotationReport -Statuses $script:statuses -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.notifications.warning[0].name | Should -Be "WARNING_API_KEY"
        $parsed.notifications.warning[0].urgency | Should -Be "warning"
    }

    It "Groups ok secrets correctly in JSON output" {
        $report = New-RotationReport -Statuses $script:statuses -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.notifications.ok[0].name | Should -Be "OK_OAUTH_SECRET"
        $parsed.notifications.ok[0].urgency | Should -Be "ok"
    }

    It "Produces markdown output containing summary table" {
        $report = New-RotationReport -Statuses $script:statuses -Format "markdown" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $report | Should -Match "Secret Rotation Report"
        $report | Should -Match "EXPIRED_DB_PASSWORD"
        $report | Should -Match "WARNING_API_KEY"
        $report | Should -Match "OK_OAUTH_SECRET"
    }

    It "Markdown output contains the summary section" {
        $report = New-RotationReport -Statuses $script:statuses -Format "markdown" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $report | Should -Match "Summary"
        $report | Should -Match "Expired"
        $report | Should -Match "Warning"
    }

    It "Handles all-ok secrets (no expired or warning)" {
        $okStatuses = @(
            @{ name = "A"; lastRotated = "2026-02-01"; rotationPolicyDays = 90; requiredBy = @() },
            @{ name = "B"; lastRotated = "2026-02-15"; rotationPolicyDays = 90; requiredBy = @() }
        ) | ForEach-Object { Get-SecretStatus -Secret $_ -ReferenceDate "2026-04-10" -WarningWindowDays 14 }

        $report = New-RotationReport -Statuses $okStatuses -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.summary.total   | Should -Be 2
        $parsed.summary.expired | Should -Be 0
        $parsed.summary.warning | Should -Be 0
        $parsed.summary.ok      | Should -Be 2
    }

    It "Handles empty secrets list" {
        $report = New-RotationReport -Statuses @() -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.summary.total | Should -Be 0
    }
}

# ============================================================
# TDD Round 3: Invoke-SecretRotationValidator - end-to-end from config file
# ============================================================

Describe "Invoke-SecretRotationValidator" {

    BeforeAll {
        $script:fixtureFile = "$PSScriptRoot/fixtures/mixed-secrets.json"
    }

    It "Reads config file and returns JSON report" {
        $report = Invoke-SecretRotationValidator -ConfigFile $script:fixtureFile -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        { $report | ConvertFrom-Json } | Should -Not -Throw
    }

    It "Uses warningWindowDays from config file when not overridden" {
        # mixed-secrets.json has warningWindowDays=14
        $report = Invoke-SecretRotationValidator -ConfigFile $script:fixtureFile -Format "json" -ReferenceDate "2026-04-10"
        $parsed = $report | ConvertFrom-Json
        $parsed.warningWindowDays | Should -Be 14
    }

    It "Produces correct summary from fixture file" {
        $report = Invoke-SecretRotationValidator -ConfigFile $script:fixtureFile -Format "json" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $parsed = $report | ConvertFrom-Json
        $parsed.summary.total   | Should -Be 3
        $parsed.summary.expired | Should -Be 1
        $parsed.summary.warning | Should -Be 1
        $parsed.summary.ok      | Should -Be 1
    }

    It "Produces markdown output from fixture file" {
        $report = Invoke-SecretRotationValidator -ConfigFile $script:fixtureFile -Format "markdown" -ReferenceDate "2026-04-10" -WarningWindowDays 14
        $report | Should -Match "EXPIRED_DB_PASSWORD"
    }

    It "Throws meaningful error when config file does not exist" {
        { Invoke-SecretRotationValidator -ConfigFile "/nonexistent/path.json" -Format "json" -ReferenceDate "2026-04-10" } | Should -Throw
    }
}

# ============================================================
# TDD Round 4: Workflow structure validation tests
# ============================================================

Describe "Workflow Structure" {

    BeforeAll {
        $script:workflowPath = "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml"
        # Parse YAML using PowerShell's built-in approach: convert to JSON-like via ConvertFrom-Yaml
        # Since PowerShell doesn't have built-in YAML, we read the raw content and check with regex/string ops
        $script:workflowContent = Get-Content $script:workflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "Workflow file exists" {
        Test-Path $script:workflowPath | Should -Be $true
    }

    It "Workflow has push trigger" {
        $script:workflowContent | Should -Match "push:"
    }

    It "Workflow has workflow_dispatch trigger" {
        $script:workflowContent | Should -Match "workflow_dispatch:"
    }

    It "Workflow references the main script" {
        $script:workflowContent | Should -Match "SecretRotationValidator.ps1"
    }

    It "Workflow references the fixtures directory" {
        $script:workflowContent | Should -Match "fixtures"
    }

    It "Workflow uses shell: pwsh for run steps" {
        $script:workflowContent | Should -Match "shell: pwsh"
    }

    It "Workflow uses actions/checkout@v4" {
        $script:workflowContent | Should -Match "actions/checkout@v4"
    }

    It "Main script file exists" {
        Test-Path "$PSScriptRoot/SecretRotationValidator.ps1" | Should -Be $true
    }

    It "Fixtures directory exists" {
        Test-Path "$PSScriptRoot/fixtures" | Should -Be $true
    }

    It "Mixed-secrets fixture file exists" {
        Test-Path "$PSScriptRoot/fixtures/mixed-secrets.json" | Should -Be $true
    }

    It "actionlint passes on the workflow file" {
        # Skip gracefully if actionlint is not installed (e.g., inside the Docker container)
        $cmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $cmd) {
            Set-ItResult -Skipped -Because "actionlint is not installed in this environment"
            return
        }
        # Run actionlint and assert exit code 0
        $output = actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $output"
    }
}
