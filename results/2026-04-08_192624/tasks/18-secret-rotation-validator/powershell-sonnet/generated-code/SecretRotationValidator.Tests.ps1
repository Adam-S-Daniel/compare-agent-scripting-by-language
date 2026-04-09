# Secret Rotation Validator - Pester Tests
# TDD approach: write failing tests first, then implement to make them pass
#
# Test reference date: 2026-04-09 (fixed to make tests deterministic)
# Fixture secrets and expected results are calculated relative to this date.

BeforeAll {
    # Source the implementation (will fail until we create it)
    . "$PSScriptRoot/SecretRotationValidator.ps1"

    # Fixed reference date for deterministic testing
    $script:TestDate = [datetime]"2026-04-09"
}

Describe "Get-SecretStatus" {
    # Unit tests for individual secret classification

    Context "Expired secrets" {
        It "marks a secret as EXPIRED when past rotation deadline" {
            # DB_PASSWORD: lastRotated=2025-12-01, policy=90 days
            # Deadline = 2026-03-01; today=2026-04-09 -> 39 days overdue
            $secret = @{
                name               = "DB_PASSWORD"
                lastRotated        = "2025-12-01"
                rotationPolicyDays = 90
                requiredBy         = @("api-service", "worker-service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate
            $result.Status | Should -Be "EXPIRED"
        }

        It "calculates correct days overdue for expired secrets" {
            $secret = @{
                name               = "DB_PASSWORD"
                lastRotated        = "2025-12-01"
                rotationPolicyDays = 90
                requiredBy         = @("api-service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate
            # Deadline=2026-03-01, today=2026-04-09, overdue=39 days
            $result.DaysOverdue | Should -Be 39
        }

        It "marks a secret expired on the exact deadline day" {
            # lastRotated=2026-01-09, policy=90 -> deadline=2026-04-09 (today = deadline)
            $secret = @{
                name               = "DEADLINE_TODAY"
                lastRotated        = "2026-01-09"
                rotationPolicyDays = 90
                requiredBy         = @()
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate
            # On the deadline day, it should be EXPIRED (0 days remaining means it must rotate now)
            $result.Status | Should -Be "EXPIRED"
        }
    }

    Context "Warning secrets" {
        It "marks a secret as WARNING when within warning window" {
            # API_KEY_STRIPE: lastRotated=2026-03-20, policy=30 days
            # Deadline = 2026-04-19; today=2026-04-09 -> 10 days until expiry (within 14-day window)
            $secret = @{
                name               = "API_KEY_STRIPE"
                lastRotated        = "2026-03-20"
                rotationPolicyDays = 30
                requiredBy         = @("payment-service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate -WarningWindowDays 14
            $result.Status | Should -Be "WARNING"
        }

        It "calculates correct days remaining for warning secrets" {
            $secret = @{
                name               = "API_KEY_STRIPE"
                lastRotated        = "2026-03-20"
                rotationPolicyDays = 30
                requiredBy         = @()
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate -WarningWindowDays 14
            $result.DaysRemaining | Should -Be 10
        }

        It "marks JWT_SECRET as WARNING with 2 days remaining" {
            # JWT_SECRET: lastRotated=2026-03-28, policy=14 days
            # Deadline = 2026-04-11; today=2026-04-09 -> 2 days remaining
            $secret = @{
                name               = "JWT_SECRET"
                lastRotated        = "2026-03-28"
                rotationPolicyDays = 14
                requiredBy         = @("auth-service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate -WarningWindowDays 14
            $result.Status | Should -Be "WARNING"
            $result.DaysRemaining | Should -Be 2
        }
    }

    Context "OK secrets" {
        It "marks a secret as OK when well within rotation period" {
            # SMTP_PASSWORD: lastRotated=2026-04-01, policy=60 days
            # Deadline = 2026-05-31; today=2026-04-09 -> 52 days remaining
            $secret = @{
                name               = "SMTP_PASSWORD"
                lastRotated        = "2026-04-01"
                rotationPolicyDays = 60
                requiredBy         = @("notification-service")
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate -WarningWindowDays 14
            $result.Status | Should -Be "OK"
        }

        It "calculates correct days remaining for OK secrets" {
            $secret = @{
                name               = "SMTP_PASSWORD"
                lastRotated        = "2026-04-01"
                rotationPolicyDays = 60
                requiredBy         = @()
            }
            $result = Get-SecretStatus -Secret $secret -ReferenceDate $script:TestDate -WarningWindowDays 14
            $result.DaysRemaining | Should -Be 52
        }
    }
}

Describe "Get-RotationReport" {
    BeforeAll {
        $script:Fixture = Get-Content "$PSScriptRoot/fixtures/secrets-fixture.json" -Raw | ConvertFrom-Json
    }

    It "returns a report object with grouped secrets" {
        $report = Get-RotationReport -Config $script:Fixture -ReferenceDate $script:TestDate
        $report | Should -Not -BeNullOrEmpty
        $report.Expired | Should -Not -BeNullOrEmpty
        $report.Warning | Should -Not -BeNullOrEmpty
        $report.OK | Should -Not -BeNullOrEmpty
    }

    It "correctly classifies 1 expired, 2 warning, 1 ok from fixture" {
        $report = Get-RotationReport -Config $script:Fixture -ReferenceDate $script:TestDate
        $report.Expired.Count | Should -Be 1
        $report.Warning.Count | Should -Be 2
        $report.OK.Count | Should -Be 1
    }

    It "puts DB_PASSWORD in Expired group" {
        $report = Get-RotationReport -Config $script:Fixture -ReferenceDate $script:TestDate
        $report.Expired[0].Name | Should -Be "DB_PASSWORD"
    }

    It "puts SMTP_PASSWORD in OK group" {
        $report = Get-RotationReport -Config $script:Fixture -ReferenceDate $script:TestDate
        $report.OK[0].Name | Should -Be "SMTP_PASSWORD"
    }

    It "includes required-by services in the report" {
        $report = Get-RotationReport -Config $script:Fixture -ReferenceDate $script:TestDate
        $expired = $report.Expired[0]
        $expired.RequiredBy | Should -Contain "api-service"
        $expired.RequiredBy | Should -Contain "worker-service"
    }
}

Describe "Format-RotationReportMarkdown" {
    BeforeAll {
        $fixture = Get-Content "$PSScriptRoot/fixtures/secrets-fixture.json" -Raw | ConvertFrom-Json
        $script:Report = Get-RotationReport -Config $fixture -ReferenceDate $script:TestDate
    }

    It "produces output containing markdown table header" {
        $md = Format-RotationReportMarkdown -Report $script:Report
        $md | Should -Match "\| Name \|"
        $md | Should -Match "\| Status \|"
    }

    It "includes EXPIRED section heading" {
        $md = Format-RotationReportMarkdown -Report $script:Report
        $md | Should -Match "## .*Expired"
    }

    It "includes WARNING section heading" {
        $md = Format-RotationReportMarkdown -Report $script:Report
        $md | Should -Match "## .*Warning"
    }

    It "includes OK section heading" {
        $md = Format-RotationReportMarkdown -Report $script:Report
        $md | Should -Match "## .*OK|## .*Ok"
    }

    It "contains DB_PASSWORD in expired section" {
        $md = Format-RotationReportMarkdown -Report $script:Report
        $md | Should -Match "DB_PASSWORD"
    }

    It "contains SMTP_PASSWORD in ok section" {
        $md = Format-RotationReportMarkdown -Report $script:Report
        $md | Should -Match "SMTP_PASSWORD"
    }
}

Describe "Format-RotationReportJson" {
    BeforeAll {
        $fixture = Get-Content "$PSScriptRoot/fixtures/secrets-fixture.json" -Raw | ConvertFrom-Json
        $script:Report = Get-RotationReport -Config $fixture -ReferenceDate $script:TestDate
    }

    It "produces valid JSON output" {
        $json = Format-RotationReportJson -Report $script:Report
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON contains expired array with 1 item" {
        $json = Format-RotationReportJson -Report $script:Report
        $obj = $json | ConvertFrom-Json
        $obj.expired.Count | Should -Be 1
    }

    It "JSON contains warning array with 2 items" {
        $json = Format-RotationReportJson -Report $script:Report
        $obj = $json | ConvertFrom-Json
        $obj.warning.Count | Should -Be 2
    }

    It "JSON contains ok array with 1 item" {
        $json = Format-RotationReportJson -Report $script:Report
        $obj = $json | ConvertFrom-Json
        $obj.ok.Count | Should -Be 1
    }

    It "JSON summary has correct total count" {
        $json = Format-RotationReportJson -Report $script:Report
        $obj = $json | ConvertFrom-Json
        $obj.summary.total | Should -Be 4
        $obj.summary.expiredCount | Should -Be 1
        $obj.summary.warningCount | Should -Be 2
        $obj.summary.okCount | Should -Be 1
    }
}

Describe "Invoke-SecretRotationValidator (main entry point)" {
    It "accepts a config file path and returns report" {
        $result = Invoke-SecretRotationValidator `
            -ConfigPath "$PSScriptRoot/fixtures/secrets-fixture.json" `
            -OutputFormat "JSON" `
            -ReferenceDate $script:TestDate
        $result | Should -Not -BeNullOrEmpty
    }

    It "defaults to markdown output format" {
        $result = Invoke-SecretRotationValidator `
            -ConfigPath "$PSScriptRoot/fixtures/secrets-fixture.json" `
            -ReferenceDate $script:TestDate
        $result | Should -Match "\|"
    }

    It "throws a meaningful error for missing config file" {
        { Invoke-SecretRotationValidator -ConfigPath "/nonexistent/path.json" } |
            Should -Throw "*not found*"
    }
}

Describe "Workflow Structure Tests" {
    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/secret-rotation-validator.yml"
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow file is valid YAML (actionlint passes)" {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It "workflow has push trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "workflow_dispatch"
    }

    It "workflow references SecretRotationValidator.ps1" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "SecretRotationValidator"
    }

    It "script file SecretRotationValidator.ps1 exists" {
        Test-Path "$PSScriptRoot/SecretRotationValidator.ps1" | Should -Be $true
    }

    It "fixture file exists" {
        Test-Path "$PSScriptRoot/fixtures/secrets-fixture.json" | Should -Be $true
    }
}

Describe "Act Integration Tests" {
    # These tests run the workflow via act and verify output
    # They write to act-result.txt in the working directory

    BeforeAll {
        $script:ActResultFile = "$PSScriptRoot/act-result.txt"
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "secret-rotation-test-$(Get-Random)"
    }

    It "act workflow runs successfully and produces expected output" {
        # Set up temp git repo
        New-Item -ItemType Directory -Path $script:TempRepo -Force | Out-Null
        $projectRoot = $PSScriptRoot

        # Copy all project files to temp repo
        $filesToCopy = @(
            "SecretRotationValidator.ps1",
            "fixtures"
        )
        foreach ($item in $filesToCopy) {
            $src = Join-Path $projectRoot $item
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $script:TempRepo -Recurse -Force
            }
        }

        # Copy workflow file
        $wfDir = Join-Path $script:TempRepo ".github/workflows"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item -Path (Join-Path $projectRoot ".github/workflows/secret-rotation-validator.yml") `
            -Destination $wfDir -Force

        # Initialize git repo
        Push-Location $script:TempRepo
        try {
            & git init -b main 2>&1 | Out-Null
            & git config user.email "test@example.com" 2>&1 | Out-Null
            & git config user.name "Test" 2>&1 | Out-Null
            & git add -A 2>&1 | Out-Null
            & git commit -m "test: secret rotation validator" 2>&1 | Out-Null

            # Run act
            $actOutput = & act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-22.04 2>&1
            $actExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        # Save output to act-result.txt
        $delimiter = "=" * 60
        $resultContent = @"
$delimiter
TEST CASE: fixture secrets-fixture.json (reference date 2026-04-09)
$delimiter
$($actOutput -join "`n")
$delimiter
Exit code: $actExitCode
$delimiter
"@
        Add-Content -Path $script:ActResultFile -Value $resultContent

        # Assert act succeeded
        $actExitCode | Should -Be 0

        # Assert job succeeded
        $actOutput -join "`n" | Should -Match "Job succeeded"

        # Assert exact expected values in output
        $outputStr = $actOutput -join "`n"
        $outputStr | Should -Match "DB_PASSWORD"
        $outputStr | Should -Match "EXPIRED"
        $outputStr | Should -Match "expiredCount.*1|expired_count.*1|Expired.*1"
        $outputStr | Should -Match "warningCount.*2|warning_count.*2|Warning.*2"
    }

    AfterAll {
        # Clean up temp repo
        if (Test-Path $script:TempRepo) {
            Remove-Item -Path $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
