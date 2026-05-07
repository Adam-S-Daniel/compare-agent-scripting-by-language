#Requires -Version 5.1
# SecretRotationValidator.Tests.ps1
# TDD: tests are written first to define expected behavior.
# Reference date is pinned to 2026-05-07 so assertions never drift.

BeforeAll {
    # Import the module under test (will fail until module is created — red phase)
    Import-Module "$PSScriptRoot/SecretRotationValidator.psm1" -Force

    # Fixed reference date for deterministic calculations
    $script:RefDate = [datetime]::ParseExact("2026-05-07", "yyyy-MM-dd", $null)
}

# ---------------------------------------------------------------------------
# Get-SecretStatus unit tests
# ---------------------------------------------------------------------------
Describe "Get-SecretStatus" {

    Context "Expired secrets" {

        It "returns 'expired' when secret is past rotation date" {
            $secret = [PSCustomObject]@{
                name         = "OLD_SECRET"
                lastRotated  = "2025-01-01"
                rotationDays = 90
                requiredBy   = @("service-a")
            }
            # Expires 2025-04-01 — 401 days before ref date
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.Status | Should -Be "expired"
        }

        It "calculates DaysOverdue correctly" {
            $secret = [PSCustomObject]@{
                name         = "OLD_SECRET"
                lastRotated  = "2025-01-01"
                rotationDays = 90
                requiredBy   = @("service-a")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.DaysOverdue | Should -Be 401
        }

        It "sets DaysUntilExpiry to negative for expired secrets" {
            $secret = [PSCustomObject]@{
                name         = "OLD_SECRET"
                lastRotated  = "2025-01-01"
                rotationDays = 90
                requiredBy   = @("service-a")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.DaysUntilExpiry | Should -BeLessThan 0
        }
    }

    Context "Warning secrets" {

        It "returns 'warning' when secret expires within warning window" {
            $secret = [PSCustomObject]@{
                name         = "EXPIRING_SOON"
                lastRotated  = "2026-04-15"
                rotationDays = 30
                requiredBy   = @("frontend")
            }
            # Expires 2026-05-15 — 8 days from ref date, within 30-day window
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.Status | Should -Be "warning"
        }

        It "returns 'warning' for secret expiring exactly today (boundary)" {
            $secret = [PSCustomObject]@{
                name         = "BORDERLINE"
                lastRotated  = "2026-04-07"
                rotationDays = 30
                requiredBy   = @("service")
            }
            # Expires exactly on ref date (0 days) — not negative, within window
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.Status | Should -Be "warning"
        }

        It "respects custom warning days parameter" {
            $secret = [PSCustomObject]@{
                name         = "MEDIUM_TERM"
                lastRotated  = "2026-04-08"
                rotationDays = 60
                requiredBy   = @("service")
            }
            # Expires 2026-06-07 — 31 days from ref date
            $result30 = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result45 = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 45
            $result30.Status | Should -Be "ok"       # 31 days > 30-day window
            $result45.Status | Should -Be "warning"  # 31 days <= 45-day window
        }
    }

    Context "OK secrets" {

        It "returns 'ok' for recently rotated secret" {
            $secret = [PSCustomObject]@{
                name         = "FRESH_SECRET"
                lastRotated  = "2026-04-20"
                rotationDays = 90
                requiredBy   = @("auth")
            }
            # Expires 2026-07-19 — 73 days from ref date
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.Status | Should -Be "ok"
        }

        It "calculates ExpiryDate correctly" {
            $secret = [PSCustomObject]@{
                name         = "TEST_SECRET"
                lastRotated  = "2026-04-20"
                rotationDays = 90
                requiredBy   = @("service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.ExpiryDate | Should -Be "2026-07-19"
        }

        It "includes all required-by services" {
            $secret = [PSCustomObject]@{
                name         = "MULTI_SERVICE"
                lastRotated  = "2026-04-20"
                rotationDays = 90
                requiredBy   = @("api", "frontend", "mobile")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:RefDate -WarningDays 30
            $result.RequiredBy | Should -Contain "api"
            $result.RequiredBy | Should -Contain "frontend"
            $result.RequiredBy | Should -Contain "mobile"
        }
    }
}

# ---------------------------------------------------------------------------
# Get-RotationReport unit tests
# ---------------------------------------------------------------------------
Describe "Get-RotationReport" {

    BeforeEach {
        # Mixed fixture: 1 expired, 1 warning, 1 ok
        $script:MixedSecrets = @(
            [PSCustomObject]@{ name = "DB_PASSWORD"; lastRotated = "2025-01-01"; rotationDays = 90; requiredBy = @("api", "db-connector") },
            [PSCustomObject]@{ name = "API_KEY";     lastRotated = "2026-04-15"; rotationDays = 30; requiredBy = @("frontend") },
            [PSCustomObject]@{ name = "JWT_SECRET";  lastRotated = "2026-04-20"; rotationDays = 90; requiredBy = @("auth-service") }
        )
    }

    It "returns a hashtable with Expired, Warning, Ok, ReferenceDate, WarningDays keys" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 30
        $report.Keys | Should -Contain "Expired"
        $report.Keys | Should -Contain "Warning"
        $report.Keys | Should -Contain "Ok"
        $report.Keys | Should -Contain "ReferenceDate"
        $report.Keys | Should -Contain "WarningDays"
    }

    It "places DB_PASSWORD into Expired" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 30
        ($report.Expired | ForEach-Object { $_.Name }) | Should -Contain "DB_PASSWORD"
    }

    It "places API_KEY into Warning" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 30
        ($report.Warning | ForEach-Object { $_.Name }) | Should -Contain "API_KEY"
    }

    It "places JWT_SECRET into Ok" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 30
        ($report.Ok | ForEach-Object { $_.Name }) | Should -Contain "JWT_SECRET"
    }

    It "produces counts of 1, 1, 1 for the mixed fixture" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 30
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 1
        $report.Ok.Count      | Should -Be 1
    }

    It "records the reference date as yyyy-MM-dd string" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 30
        $report.ReferenceDate | Should -Be "2026-05-07"
    }

    It "records the warning days in the report" {
        $report = Get-RotationReport -Secrets $script:MixedSecrets -ReferenceDate $script:RefDate -WarningDays 45
        $report.WarningDays | Should -Be 45
    }
}

# ---------------------------------------------------------------------------
# Format-JsonReport unit tests
# ---------------------------------------------------------------------------
Describe "Format-JsonReport" {

    BeforeEach {
        $secrets = @(
            [PSCustomObject]@{ name = "DB_PASSWORD"; lastRotated = "2025-01-01"; rotationDays = 90; requiredBy = @("api") },
            [PSCustomObject]@{ name = "API_KEY";     lastRotated = "2026-04-15"; rotationDays = 30; requiredBy = @("frontend") },
            [PSCustomObject]@{ name = "JWT_SECRET";  lastRotated = "2026-04-20"; rotationDays = 90; requiredBy = @("auth") }
        )
        $script:Report = Get-RotationReport -Secrets $secrets -ReferenceDate $script:RefDate -WarningDays 30
    }

    It "outputs valid JSON" {
        $json = Format-JsonReport -Report $script:Report
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON contains Expired, Warning, Ok, ReferenceDate, WarningDays keys" {
        $parsed = (Format-JsonReport -Report $script:Report) | ConvertFrom-Json
        $parsed.PSObject.Properties.Name | Should -Contain "Expired"
        $parsed.PSObject.Properties.Name | Should -Contain "Warning"
        $parsed.PSObject.Properties.Name | Should -Contain "Ok"
        $parsed.PSObject.Properties.Name | Should -Contain "ReferenceDate"
        $parsed.PSObject.Properties.Name | Should -Contain "WarningDays"
    }

    It "DB_PASSWORD appears in the Expired JSON array" {
        $parsed = (Format-JsonReport -Report $script:Report) | ConvertFrom-Json
        $parsed.Expired[0].Name | Should -Be "DB_PASSWORD"
    }

    It "API_KEY appears in the Warning JSON array" {
        $parsed = (Format-JsonReport -Report $script:Report) | ConvertFrom-Json
        $parsed.Warning[0].Name | Should -Be "API_KEY"
    }

    It "JWT_SECRET appears in the Ok JSON array" {
        $parsed = (Format-JsonReport -Report $script:Report) | ConvertFrom-Json
        $parsed.Ok[0].Name | Should -Be "JWT_SECRET"
    }
}

# ---------------------------------------------------------------------------
# Format-MarkdownReport unit tests
# ---------------------------------------------------------------------------
Describe "Format-MarkdownReport" {

    BeforeEach {
        $secrets = @(
            [PSCustomObject]@{ name = "DB_PASSWORD"; lastRotated = "2025-01-01"; rotationDays = 90; requiredBy = @("api") },
            [PSCustomObject]@{ name = "API_KEY";     lastRotated = "2026-04-15"; rotationDays = 30; requiredBy = @("frontend") },
            [PSCustomObject]@{ name = "JWT_SECRET";  lastRotated = "2026-04-20"; rotationDays = 90; requiredBy = @("auth") }
        )
        $script:MdReport = Get-RotationReport -Secrets $secrets -ReferenceDate $script:RefDate -WarningDays 30
    }

    It "outputs the report title" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "# Secret Rotation Report"
    }

    It "includes the reference date" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "\*\*Reference Date\*\*: 2026-05-07"
    }

    It "includes a summary table" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "## Summary"
        $md | Should -Match "\| Expired \|"
        $md | Should -Match "\| Warning \|"
        $md | Should -Match "\| OK \|"
    }

    It "includes Expired section with DB_PASSWORD" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "## Expired Secrets"
        $md | Should -Match "DB_PASSWORD"
    }

    It "includes correct expiry date and days-overdue for DB_PASSWORD" {
        $md = Format-MarkdownReport -Report $script:MdReport
        # Exact values: expiry 2025-04-01, 401 days overdue
        $md | Should -Match "2025-04-01"
        $md | Should -Match "\| 401 \|"
    }

    It "includes Warning section with API_KEY" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "## Expiring Soon"
        $md | Should -Match "API_KEY"
    }

    It "includes correct expiry date and days-until-expiry for API_KEY" {
        $md = Format-MarkdownReport -Report $script:MdReport
        # Exact values: expiry 2026-05-15, 8 days remaining
        $md | Should -Match "2026-05-15"
        $md | Should -Match "\| 8 \|"
    }

    It "includes OK section with JWT_SECRET" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "## Current Secrets"
        $md | Should -Match "JWT_SECRET"
    }

    It "includes required-by services in the output" {
        $md = Format-MarkdownReport -Report $script:MdReport
        $md | Should -Match "api"
        $md | Should -Match "frontend"
        $md | Should -Match "auth"
    }
}

# ---------------------------------------------------------------------------
# Workflow structure tests
# ---------------------------------------------------------------------------
Describe "Workflow Structure" {

    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml"
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow has push trigger" {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match "push:"
    }

    It "workflow has pull_request trigger" {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match "pull_request:"
    }

    It "workflow has schedule trigger" {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match "schedule:"
    }

    It "workflow has workflow_dispatch trigger" {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match "workflow_dispatch:"
    }

    It "workflow references the main script" {
        (Get-Content $script:WorkflowPath -Raw) | Should -Match "SecretRotationValidator\.ps1"
    }

    It "SecretRotationValidator.ps1 exists" {
        Test-Path "$PSScriptRoot/SecretRotationValidator.ps1" | Should -Be $true
    }

    It "SecretRotationValidator.psm1 module exists" {
        Test-Path "$PSScriptRoot/SecretRotationValidator.psm1" | Should -Be $true
    }

    It "fixtures directory exists" {
        Test-Path "$PSScriptRoot/fixtures" | Should -Be $true
    }

    It "fixtures/secrets-mixed.json exists" {
        Test-Path "$PSScriptRoot/fixtures/secrets-mixed.json" | Should -Be $true
    }

    It "workflow passes actionlint" -Skip:($env:GITHUB_ACTIONS -eq 'true') {
        $result = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Act integration tests — skipped when running inside GitHub Actions (Docker)
# to avoid infinite recursion: host runs Pester -> Pester runs act -> act runs
# this file -> GITHUB_ACTIONS=true -> these tests skip.
# ---------------------------------------------------------------------------
Describe "Act Integration Tests" -Skip:($env:GITHUB_ACTIONS -eq 'true') {

    BeforeAll {
        # One temp repo shared by all integration tests to save act invocations
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "srv-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null

        # Files the workflow needs
        $filesToCopy = @(
            "SecretRotationValidator.ps1",
            "SecretRotationValidator.psm1",
            "SecretRotationValidator.Tests.ps1",
            ".github/workflows/secret-rotation-validator.yml"
        )
        foreach ($rel in $filesToCopy) {
            $dest = Join-Path $script:TempDir $rel
            $destDir = Split-Path $dest -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item (Join-Path $PSScriptRoot $rel) -Destination $dest
        }

        # Copy fixture directory
        Copy-Item (Join-Path $PSScriptRoot "fixtures") -Destination $script:TempDir -Recurse -Force

        # Copy .actrc so act uses the custom image
        $actrc = Join-Path $PSScriptRoot ".actrc"
        if (Test-Path $actrc) {
            Copy-Item $actrc -Destination $script:TempDir
        }

        # Initialize git repo so act recognises it as a project root
        Push-Location $script:TempDir
        git init -q 2>&1 | Out-Null
        git config user.email "test@example.com"
        git config user.name "Test User"
        git add -A 2>&1 | Out-Null
        git commit -m "test: initial fixture commit" -q 2>&1 | Out-Null
        Pop-Location

        # Where to accumulate all act output
        $script:ActResultFile = Join-Path $PSScriptRoot "act-result.txt"
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "workflow runs and produces expected mixed-secrets markdown report" {
        # Run act from the temp repo — simulates a push event
        Push-Location $script:TempDir
        $actOutput = ""
        try {
            $actOutput = (act push --rm 2>&1) -join "`n"
            $script:LastActExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        # Append to act-result.txt (clearly delimited)
        @"
=== Test Case: Mixed Secrets Markdown (act push) ===
$actOutput
=== End Test Case ===
"@ | Add-Content $script:ActResultFile

        # Assert overall success
        $script:LastActExitCode | Should -Be 0

        # Assert at least one job succeeded
        $actOutput | Should -Match "Job succeeded"

        # --- Exact expected values for DB_PASSWORD (expired, 401 days overdue) ---
        $actOutput | Should -Match "DB_PASSWORD"
        $actOutput | Should -Match "2025-04-01"   # exact expiry date
        $actOutput | Should -Match "401"           # exact days overdue

        # --- Exact expected values for API_KEY (warning, 8 days remaining) ---
        $actOutput | Should -Match "API_KEY"
        $actOutput | Should -Match "2026-05-15"   # exact expiry date
        $actOutput | Should -Match "8"             # exact days until expiry

        # --- Exact expected values for JWT_SECRET (ok, 73 days remaining) ---
        $actOutput | Should -Match "JWT_SECRET"
        $actOutput | Should -Match "2026-07-19"   # exact expiry date
        $actOutput | Should -Match "73"            # exact days until expiry

        # Summary counts
        $actOutput | Should -Match "Expired.*1|1.*Expired"
        $actOutput | Should -Match "Warning.*1|1.*Warning"
    }
}
