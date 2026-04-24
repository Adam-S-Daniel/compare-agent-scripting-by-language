#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for Secret Rotation Validator using red/green TDD.
    Written BEFORE the implementation to drive design.
#>

# Load the script functions (dot-source) before tests run.
# The script guards its main execution so dot-sourcing only imports functions.
BeforeAll {
    . "$PSScriptRoot/SecretRotationValidator.ps1"
}

# ─── Unit: Get-SecretStatus ───────────────────────────────────────────────────

Describe "Get-SecretStatus" -Tag "Unit" {
    BeforeAll {
        $refDate = [datetime]::ParseExact("2024-06-01", "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture)
    }

    It "classifies an overdue secret as expired" {
        $secret = [PSCustomObject]@{
            name        = "OLD_KEY"
            lastRotated = "2024-01-01"
            rotationDays = 30
            requiredBy  = @("svc-a")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.Status | Should -Be "expired"
    }

    It "returns negative DaysUntilExpiry for an expired secret" {
        $secret = [PSCustomObject]@{
            name        = "OLD_KEY"
            lastRotated = "2024-01-01"
            rotationDays = 30
            requiredBy  = @("svc-a")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.DaysUntilExpiry | Should -BeLessThan 0
    }

    It "classifies a secret expiring within the warning window as warning" {
        # lastRotated 2024-05-08, rotation 30 days -> expires 2024-06-07 (6 days from ref)
        $secret = [PSCustomObject]@{
            name        = "SOON_KEY"
            lastRotated = "2024-05-08"
            rotationDays = 30
            requiredBy  = @("svc-b")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.Status | Should -Be "warning"
    }

    It "classifies a secret with plenty of time as ok" {
        # lastRotated 2024-05-25, rotation 30 days -> expires 2024-06-24 (23 days from ref)
        $secret = [PSCustomObject]@{
            name        = "GOOD_KEY"
            lastRotated = "2024-05-25"
            rotationDays = 30
            requiredBy  = @("svc-c")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.Status | Should -Be "ok"
    }

    It "returns the correct ExpiryDate" {
        $secret = [PSCustomObject]@{
            name        = "TEST_KEY"
            lastRotated = "2024-05-01"
            rotationDays = 90
            requiredBy  = @("svc-d")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.ExpiryDate | Should -Be "2024-07-30"
    }

    It "includes the secret name and requiredBy in the result" {
        $secret = [PSCustomObject]@{
            name        = "API_TOKEN"
            lastRotated = "2024-05-25"
            rotationDays = 30
            requiredBy  = @("service-x", "service-y")
        }
        $result = Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays 14
        $result.Name      | Should -Be "API_TOKEN"
        $result.RequiredBy | Should -Contain "service-x"
        $result.RequiredBy | Should -Contain "service-y"
    }
}

# ─── Unit: Format-MarkdownReport ─────────────────────────────────────────────

Describe "Format-MarkdownReport" -Tag "Unit" {
    BeforeAll {
        $refDate = [datetime]::ParseExact("2024-06-01", "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture)

        $results = @(
            [PSCustomObject]@{ Name="EXPIRED_KEY"; LastRotated="2024-01-01"; ExpiryDate="2024-01-31"; DaysUntilExpiry=-122; RotationDays=30; RequiredBy=@("svc-a"); Status="expired" }
            [PSCustomObject]@{ Name="WARN_KEY";    LastRotated="2024-05-08"; ExpiryDate="2024-06-07"; DaysUntilExpiry=6;    RotationDays=30; RequiredBy=@("svc-b"); Status="warning" }
            [PSCustomObject]@{ Name="OK_KEY";      LastRotated="2024-05-25"; ExpiryDate="2024-06-24"; DaysUntilExpiry=23;   RotationDays=30; RequiredBy=@("svc-c"); Status="ok" }
        )
        $script:md = Format-MarkdownReport -Results $results
    }

    It "contains a heading for expired secrets" {
        $script:md | Should -Match "## Expired Secrets"
    }

    It "contains a heading for warning secrets" {
        $script:md | Should -Match "## Warning"
    }

    It "contains a heading for ok secrets" {
        $script:md | Should -Match "## OK"
    }

    It "lists expired secret names" {
        $script:md | Should -Match "EXPIRED_KEY"
    }

    It "lists warning secret names" {
        $script:md | Should -Match "WARN_KEY"
    }

    It "lists ok secret names" {
        $script:md | Should -Match "OK_KEY"
    }

    It "includes summary counts" {
        $script:md | Should -Match "\*\*Expired\*\*: 1"
        $script:md | Should -Match "\*\*Warning\*\*: 1"
        $script:md | Should -Match "\*\*OK\*\*: 1"
        $script:md | Should -Match "\*\*Total\*\*: 3"
    }
}

# ─── Unit: Format-JsonReport ─────────────────────────────────────────────────

Describe "Format-JsonReport" -Tag "Unit" {
    BeforeAll {
        $results = @(
            [PSCustomObject]@{ Name="EXPIRED_KEY"; LastRotated="2024-01-01"; ExpiryDate="2024-01-31"; DaysUntilExpiry=-122; RotationDays=30; RequiredBy=@("svc-a"); Status="expired" }
            [PSCustomObject]@{ Name="WARN_KEY";    LastRotated="2024-05-08"; ExpiryDate="2024-06-07"; DaysUntilExpiry=6;    RotationDays=30; RequiredBy=@("svc-b"); Status="warning" }
            [PSCustomObject]@{ Name="OK_KEY1";     LastRotated="2024-05-25"; ExpiryDate="2024-06-24"; DaysUntilExpiry=23;   RotationDays=30; RequiredBy=@("svc-c"); Status="ok" }
            [PSCustomObject]@{ Name="OK_KEY2";     LastRotated="2024-05-01"; ExpiryDate="2024-07-29"; DaysUntilExpiry=58;   RotationDays=90; RequiredBy=@("svc-d"); Status="ok" }
        )
        $jsonStr = Format-JsonReport -Results $results
        $script:data = $jsonStr | ConvertFrom-Json
    }

    It "produces valid JSON" {
        { $script:data } | Should -Not -Throw
    }

    It "has correct summary counts" {
        $script:data.summary.expired | Should -Be 1
        $script:data.summary.warning | Should -Be 1
        $script:data.summary.ok      | Should -Be 2
        $script:data.summary.total   | Should -Be 4
    }

    It "groups notifications by urgency" {
        $script:data.notifications.expired | Should -Not -BeNullOrEmpty
        $script:data.notifications.warning | Should -Not -BeNullOrEmpty
        $script:data.notifications.ok      | Should -Not -BeNullOrEmpty
    }

    It "includes generatedAt timestamp" {
        $script:data.generatedAt | Should -Not -BeNullOrEmpty
    }
}

# ─── Unit: Invoke-SecretRotationValidator (end-to-end with fixture) ───────────

Describe "Invoke-SecretRotationValidator" -Tag "Unit" {
    BeforeAll {
        $fixturePath = "$PSScriptRoot/fixtures/secrets-config.json"
        $refDateStr  = "2024-06-01"
    }

    It "produces markdown output from fixture file" {
        $output = Invoke-SecretRotationValidator -ConfigPath $fixturePath `
            -OutputFormat markdown -ReferenceDate $refDateStr
        $output | Should -Match "PROD_API_KEY"
        $output | Should -Match "## Expired Secrets"
    }

    It "produces JSON output from fixture file" {
        $output = Invoke-SecretRotationValidator -ConfigPath $fixturePath `
            -OutputFormat json -ReferenceDate $refDateStr
        $data = $output | ConvertFrom-Json
        $data.summary.expired | Should -Be 1
        $data.summary.warning | Should -Be 1
        $data.summary.ok      | Should -Be 2
    }

    It "throws a meaningful error for a missing config file" {
        { Invoke-SecretRotationValidator -ConfigPath "nonexistent.json" -ReferenceDate $refDateStr } |
            Should -Throw "*not found*"
    }

    It "uses warningWindowDays from config when not overridden" {
        $output = Invoke-SecretRotationValidator -ConfigPath $fixturePath `
            -OutputFormat json -ReferenceDate $refDateStr
        $data = $output | ConvertFrom-Json
        # Fixture has warningWindowDays=14 which should classify STAGING_TOKEN as warning
        $data.notifications.warning | Where-Object { $_.Name -eq "STAGING_TOKEN" } |
            Should -Not -BeNullOrEmpty
    }
}

# ─── Unit: Workflow YAML structure ───────────────────────────────────────────

Describe "Workflow YAML structure" -Tag "Unit" {
    BeforeAll {
        $script:wfPath = "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml"
        $script:wfContent = Get-Content $script:wfPath -Raw
    }

    It "workflow file exists" {
        Test-Path $script:wfPath | Should -BeTrue
    }

    It "has push trigger" {
        $script:wfContent | Should -Match "push:"
    }

    It "has pull_request trigger" {
        $script:wfContent | Should -Match "pull_request:"
    }

    It "has schedule trigger" {
        $script:wfContent | Should -Match "schedule:"
    }

    It "has workflow_dispatch trigger" {
        $script:wfContent | Should -Match "workflow_dispatch:"
    }

    It "uses actions/checkout@v4" {
        $script:wfContent | Should -Match "actions/checkout@v4"
    }

    It "uses shell: pwsh for run steps" {
        $script:wfContent | Should -Match "shell: pwsh"
    }

    It "references SecretRotationValidator.ps1" {
        $script:wfContent | Should -Match "SecretRotationValidator\.ps1"
        Test-Path "$PSScriptRoot/SecretRotationValidator.ps1" | Should -BeTrue
    }

    It "references the fixture file" {
        $script:wfContent | Should -Match "fixtures/secrets-config\.json"
        Test-Path "$PSScriptRoot/fixtures/secrets-config.json" | Should -BeTrue
    }

    It "passes actionlint validation" {
        $result = & actionlint $script:wfPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

# ─── Integration: act end-to-end ─────────────────────────────────────────────
# These tests set up a temp git repo, run `act push --rm`, save output to
# act-result.txt, and assert on exact expected values in the workflow output.

Describe "Act integration" -Tag "Integration" {
    It "runs act push and validates exact expected output" {
        $actResultPath = "$PSScriptRoot/act-result.txt"

        # Build a temp repo with all project files
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        try {
            # Copy source files into temp repo
            Copy-Item "$PSScriptRoot/SecretRotationValidator.ps1" $tempDir
            Copy-Item "$PSScriptRoot/SecretRotationValidator.Tests.ps1" $tempDir
            Copy-Item "$PSScriptRoot/.actrc" $tempDir
            Copy-Item -Path "$PSScriptRoot/fixtures" -Destination $tempDir -Recurse

            $wfDest = Join-Path $tempDir ".github/workflows"
            New-Item -ItemType Directory -Path $wfDest -Force | Out-Null
            Copy-Item "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml" $wfDest

            # Initialize a real git repo (required by act)
            Push-Location $tempDir
            git init -q
            git config user.email "test@act.local"
            git config user.name "Act Test"
            git add -A
            git commit -q -m "test: secret rotation validator"
            Pop-Location

            # Run act - capture combined stdout+stderr.
            # --pull=false avoids attempting a registry pull of the local-only image.
            $actOutput = & act push --rm --pull=false -C $tempDir 2>&1
            $actExitCode = $LASTEXITCODE

            # ── Save output to act-result.txt (append) ──────────────────────
            $divider = "=" * 70
            $block = @(
                "",
                $divider,
                "TEST CASE: Default fixture secrets-config.json (ref date 2024-06-01)",
                $divider
            ) + $actOutput + @($divider, "")
            $block | Out-File -FilePath $actResultPath -Append -Encoding utf8

            # ── Assertions ───────────────────────────────────────────────────
            $joined = $actOutput -join "`n"

            # Exit code
            $actExitCode | Should -Be 0 -Because "act must exit 0 for a passing workflow"

            # Every job must succeed
            $joined | Should -Match "Job succeeded"

            # Secrets appear in report
            $joined | Should -Match "PROD_API_KEY"
            $joined | Should -Match "STAGING_TOKEN"
            $joined | Should -Match "DEV_SECRET"
            $joined | Should -Match "BACKUP_KEY"

            # Exact summary counts (from JSON validation step in workflow)
            $joined | Should -Match "Expired: 1"
            $joined | Should -Match "Warning: 1"
            $joined | Should -Match "OK: 2"

            # Final validation marker written by workflow
            $joined | Should -Match "VALIDATION PASSED"

        } finally {
            Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        }
    }
}
