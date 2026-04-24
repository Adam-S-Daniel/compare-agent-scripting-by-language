# SecretRotationValidator.Tests.ps1
#
# TDD approach: each Describe block represents a red-green-refactor cycle.
# Tests are written BEFORE the implementation. The file is dot-sourced below;
# running this before the implementation exists will cause failures (red phase).
# After implementing SecretRotationValidator.ps1 all tests should pass (green).

BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"

    # Fixed reference date makes every test deterministic regardless of run date.
    $script:RefDate = [datetime]"2026-04-19"

    # Shared fixture secrets (with reference date 2026-04-19):
    #   database-password: expired 2025-12-30 → 110 days overdue
    #   api-key:           expires 2026-04-26 → 7 days left  (warning, within 14d window)
    #   jwt-secret:        expires 2026-05-19 → 30 days left (ok)
    $script:SecretExpired = @{
        Name               = "database-password"
        LastRotated        = "2025-10-01"
        RotationPolicyDays = 90
        RequiredBy         = @("web-app", "api-service")
    }
    $script:SecretWarning = @{
        Name               = "api-key"
        LastRotated        = "2026-04-12"
        RotationPolicyDays = 14
        RequiredBy         = @("mobile-app")
    }
    $script:SecretOk = @{
        Name               = "jwt-secret"
        LastRotated        = "2026-02-18"
        RotationPolicyDays = 90
        RequiredBy         = @("auth-service")
    }
}

# ===========================================================================
# TDD Cycle 1 (RED → GREEN): Classify expired secrets
# ===========================================================================
Describe "Get-SecretStatus: expired classification" {
    It "returns status=expired when past rotation date" {
        $result = Get-SecretStatus -Secret $script:SecretExpired `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.Status | Should -Be "expired"
    }

    It "calculates DaysOverdue=110 for database-password" {
        $result = Get-SecretStatus -Secret $script:SecretExpired `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.DaysOverdue | Should -Be 110
    }

    It "sets ExpiryDate to 2025-12-30 for database-password" {
        $result = Get-SecretStatus -Secret $script:SecretExpired `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.ExpiryDate | Should -Be ([datetime]"2025-12-30")
    }

    It "returns status=expired when secret expires exactly today (0 days overdue)" {
        $todaySecret = @{
            Name               = "expires-today"
            LastRotated        = "2026-04-09"
            RotationPolicyDays = 10
            RequiredBy         = @("app")
        }
        $result = Get-SecretStatus -Secret $todaySecret `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.Status      | Should -Be "expired"
        $result.DaysOverdue | Should -Be 0
    }
}

# ===========================================================================
# TDD Cycle 2 (RED → GREEN): Classify warning secrets
# ===========================================================================
Describe "Get-SecretStatus: warning classification" {
    It "returns status=warning when within warning window" {
        $result = Get-SecretStatus -Secret $script:SecretWarning `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.Status | Should -Be "warning"
    }

    It "calculates DaysUntilExpiry=7 for api-key" {
        $result = Get-SecretStatus -Secret $script:SecretWarning `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.DaysUntilExpiry | Should -Be 7
    }

    It "sets ExpiryDate to 2026-04-26 for api-key" {
        $result = Get-SecretStatus -Secret $script:SecretWarning `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.ExpiryDate | Should -Be ([datetime]"2026-04-26")
    }

    It "returns status=warning when exactly at warning boundary (14 days left)" {
        $boundarySecret = @{
            Name               = "boundary-secret"
            LastRotated        = "2026-03-06"
            RotationPolicyDays = 44
            RequiredBy         = @("app")
        }
        # 2026-03-06 + 44 days = 2026-04-19 + 0 days... let me use a precise calc:
        # We want expiry = 2026-04-19 + 14 = 2026-05-03
        # lastRotated = 2026-05-03 - 30 days policy = 2026-04-03
        $boundarySecret = @{
            Name               = "boundary-14days"
            LastRotated        = "2026-04-03"
            RotationPolicyDays = 30
            RequiredBy         = @("app")
        }
        # ExpiryDate = 2026-04-03 + 30 = 2026-05-03, DaysUntilExpiry = 14 → warning (≤14)
        $result = Get-SecretStatus -Secret $boundarySecret `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.Status          | Should -Be "warning"
        $result.DaysUntilExpiry | Should -Be 14
    }
}

# ===========================================================================
# TDD Cycle 3 (RED → GREEN): Classify ok secrets
# ===========================================================================
Describe "Get-SecretStatus: ok classification" {
    It "returns status=ok when well outside warning window" {
        $result = Get-SecretStatus -Secret $script:SecretOk `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.Status | Should -Be "ok"
    }

    It "calculates DaysUntilExpiry=30 for jwt-secret" {
        $result = Get-SecretStatus -Secret $script:SecretOk `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.DaysUntilExpiry | Should -Be 30
    }

    It "sets ExpiryDate to 2026-05-19 for jwt-secret" {
        $result = Get-SecretStatus -Secret $script:SecretOk `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.ExpiryDate | Should -Be ([datetime]"2026-05-19")
    }

    It "returns status=ok when just outside warning boundary (15 days left)" {
        $okSecret = @{
            Name               = "just-ok"
            LastRotated        = "2026-04-04"
            RotationPolicyDays = 30
            RequiredBy         = @("app")
        }
        # ExpiryDate = 2026-04-04 + 30 = 2026-05-04, DaysUntilExpiry = 15 → ok (>14)
        $result = Get-SecretStatus -Secret $okSecret `
                                   -ReferenceDate $script:RefDate `
                                   -WarningWindowDays 14
        $result.Status          | Should -Be "ok"
        $result.DaysUntilExpiry | Should -Be 15
    }
}

# ===========================================================================
# TDD Cycle 4 (RED → GREEN): Error handling in Get-SecretStatus
# ===========================================================================
Describe "Get-SecretStatus: error handling" {
    It "throws when LastRotated field is missing" {
        $badSecret = @{ Name = "no-date"; RotationPolicyDays = 30; RequiredBy = @() }
        { Get-SecretStatus -Secret $badSecret -ReferenceDate $script:RefDate } |
            Should -Throw
    }

    It "throws when LastRotated date format is invalid" {
        $badSecret = @{ Name = "bad-date"; LastRotated = "not-a-date"; RotationPolicyDays = 30; RequiredBy = @() }
        { Get-SecretStatus -Secret $badSecret -ReferenceDate $script:RefDate } |
            Should -Throw
    }

    It "throws when RotationPolicyDays field is missing" {
        $badSecret = @{ Name = "no-policy"; LastRotated = "2026-01-01"; RequiredBy = @() }
        { Get-SecretStatus -Secret $badSecret -ReferenceDate $script:RefDate } |
            Should -Throw
    }
}

# ===========================================================================
# TDD Cycle 5 (RED → GREEN): Invoke-SecretRotationValidator groups by urgency
# ===========================================================================
Describe "Invoke-SecretRotationValidator: grouping" {
    BeforeAll {
        $script:AllSecrets = @(
            $script:SecretExpired,
            $script:SecretWarning,
            $script:SecretOk
        )
        $script:ValidatorResult = Invoke-SecretRotationValidator `
            -Secrets $script:AllSecrets `
            -WarningWindowDays 14 `
            -ReferenceDate $script:RefDate
    }

    It "places database-password in the Expired group" {
        $script:ValidatorResult.Expired | Where-Object { $_.Name -eq "database-password" } |
            Should -Not -BeNullOrEmpty
    }

    It "places api-key in the Warning group" {
        $script:ValidatorResult.Warning | Where-Object { $_.Name -eq "api-key" } |
            Should -Not -BeNullOrEmpty
    }

    It "places jwt-secret in the Ok group" {
        $script:ValidatorResult.Ok | Where-Object { $_.Name -eq "jwt-secret" } |
            Should -Not -BeNullOrEmpty
    }

    It "counts exactly 1 expired, 1 warning, 1 ok" {
        $script:ValidatorResult.Expired.Count | Should -Be 1
        $script:ValidatorResult.Warning.Count | Should -Be 1
        $script:ValidatorResult.Ok.Count      | Should -Be 1
    }

    It "includes RequiredBy in the result entry" {
        $entry = $script:ValidatorResult.Expired | Where-Object { $_.Name -eq "database-password" }
        $entry.RequiredBy | Should -Contain "web-app"
        $entry.RequiredBy | Should -Contain "api-service"
    }

    It "includes DaysOverdue=110 in the expired entry" {
        $entry = $script:ValidatorResult.Expired | Where-Object { $_.Name -eq "database-password" }
        $entry.DaysOverdue | Should -Be 110
    }

    It "includes DaysUntilExpiry=7 in the warning entry" {
        $entry = $script:ValidatorResult.Warning | Where-Object { $_.Name -eq "api-key" }
        $entry.DaysUntilExpiry | Should -Be 7
    }

    It "stores ReferenceDate and WarningWindowDays in results" {
        $script:ValidatorResult.WarningWindowDays | Should -Be 14
        $script:ValidatorResult.ReferenceDate     | Should -Be "2026-04-19"
    }
}

# ===========================================================================
# TDD Cycle 6 (RED → GREEN): Format-RotationReport produces Markdown
# ===========================================================================
Describe "Format-RotationReport: Markdown output" {
    BeforeAll {
        $secrets = @($script:SecretExpired, $script:SecretWarning, $script:SecretOk)
        $results = Invoke-SecretRotationValidator -Secrets $secrets `
            -WarningWindowDays 14 -ReferenceDate $script:RefDate
        $script:Markdown = Format-RotationReport -Results $results -Format "Markdown"
    }

    It "contains the report title" {
        $script:Markdown | Should -Match "Secret Rotation Report"
    }

    It "contains the EXPIRED section header" {
        $script:Markdown | Should -Match "EXPIRED"
    }

    It "contains the WARNING section header" {
        $script:Markdown | Should -Match "WARNING"
    }

    It "contains the OK section header" {
        $script:Markdown | Should -Match "\bOK\b"
    }

    It "contains the secret name 'database-password' in the output" {
        $script:Markdown | Should -Match "database-password"
    }

    It "contains 'api-key' in the output" {
        $script:Markdown | Should -Match "api-key"
    }

    It "contains 'jwt-secret' in the output" {
        $script:Markdown | Should -Match "jwt-secret"
    }

    It "contains the exact DaysOverdue value 110 in the expired row" {
        $script:Markdown | Should -Match "\b110\b"
    }

    It "contains the exact DaysUntilExpiry value 7 in the warning row" {
        $script:Markdown | Should -Match "\b7\b"
    }

    It "contains markdown table pipe characters" {
        $script:Markdown | Should -Match "\|"
    }

    It "contains the reference date 2026-04-19" {
        $script:Markdown | Should -Match "2026-04-19"
    }
}

# ===========================================================================
# TDD Cycle 7 (RED → GREEN): Format-RotationReport produces valid JSON
# ===========================================================================
Describe "Format-RotationReport: JSON output" {
    BeforeAll {
        $secrets = @($script:SecretExpired, $script:SecretWarning, $script:SecretOk)
        $results = Invoke-SecretRotationValidator -Secrets $secrets `
            -WarningWindowDays 14 -ReferenceDate $script:RefDate
        $script:JsonString = Format-RotationReport -Results $results -Format "JSON"
        $script:Json = $script:JsonString | ConvertFrom-Json
    }

    It "produces valid JSON (no parse errors)" {
        { $script:JsonString | ConvertFrom-Json } | Should -Not -Throw
    }

    It "has a summary field" {
        $script:Json.summary | Should -Not -BeNullOrEmpty
    }

    It "has summary.expired=1" {
        $script:Json.summary.expired | Should -Be 1
    }

    It "has summary.warning=1" {
        $script:Json.summary.warning | Should -Be 1
    }

    It "has summary.ok=1" {
        $script:Json.summary.ok | Should -Be 1
    }

    It "has generatedAt=2026-04-19" {
        $script:Json.generatedAt | Should -Be "2026-04-19"
    }

    It "has warningWindowDays=14" {
        $script:Json.warningWindowDays | Should -Be 14
    }

    It "expired array contains database-password with daysOverdue=110" {
        $entry = $script:Json.expired | Where-Object { $_.name -eq "database-password" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.daysOverdue | Should -Be 110
    }

    It "warning array contains api-key with daysUntilExpiry=7" {
        $entry = $script:Json.warning | Where-Object { $_.name -eq "api-key" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.daysUntilExpiry | Should -Be 7
    }

    It "ok array contains jwt-secret with daysUntilExpiry=30" {
        $entry = $script:Json.ok | Where-Object { $_.name -eq "jwt-secret" }
        $entry | Should -Not -BeNullOrEmpty
        $entry.daysUntilExpiry | Should -Be 30
    }
}

# ===========================================================================
# Workflow Structure Tests (required by spec)
# ===========================================================================
Describe "Workflow structure validation" {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/secret-rotation-validator.yml"
        $script:WorkflowContent = Get-Content $script:WorkflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow YAML file exists at expected path" {
        $script:WorkflowPath | Should -Exist
    }

    It "workflow references SecretRotationValidator.ps1 which exists" {
        $script:WorkflowContent | Should -Match "SecretRotationValidator\.ps1"
        (Join-Path $PSScriptRoot "SecretRotationValidator.ps1") | Should -Exist
    }

    It "workflow references fixtures/secrets-config.json which exists" {
        $script:WorkflowContent | Should -Match "secrets-config\.json"
        (Join-Path $PSScriptRoot "fixtures/secrets-config.json") | Should -Exist
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push"
    }

    It "workflow has pull_request trigger" {
        $script:WorkflowContent | Should -Match "pull_request"
    }

    It "workflow has schedule trigger" {
        $script:WorkflowContent | Should -Match "schedule"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch"
    }

    It "workflow uses actions/checkout@v4" {
        $script:WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $script:WorkflowContent | Should -Match "shell: pwsh"
    }

    It "actionlint passes on workflow file" {
        $actionlintCmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            Set-ItResult -Skipped -Because "actionlint not installed in this environment"
            return
        }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
