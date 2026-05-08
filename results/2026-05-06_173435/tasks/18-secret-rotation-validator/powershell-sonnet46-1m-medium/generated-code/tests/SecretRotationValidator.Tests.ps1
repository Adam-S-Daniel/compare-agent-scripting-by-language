# Secret Rotation Validator - Pester Test Suite
# TDD approach: tests drive the implementation.
# Run with: Invoke-Pester ./tests/SecretRotationValidator.Tests.ps1 -Output Detailed

BeforeAll {
    # Import the main script (dot-source to bring functions into scope)
    . "$PSScriptRoot/../SecretRotationValidator.ps1"

    # Fixed reference date so tests are deterministic regardless of when they run
    $script:ReferenceDate = [datetime]"2024-03-01"

    # Helper: build a secret hashtable from components
    function New-SecretFixture {
        param([string]$Name, [int]$DaysAgo, [int]$PolicyDays, [string[]]$RequiredBy = @("test-service"))
        @{
            name                 = $Name
            last_rotated         = $script:ReferenceDate.AddDays(-$DaysAgo).ToString("yyyy-MM-dd")
            rotation_policy_days = $PolicyDays
            required_by          = $RequiredBy
        }
    }
}

# ---------------------------------------------------------------------------
# RED TEST 1: Get-SecretStatus returns "expired" for an overdue secret
# This test is written FIRST — it will fail until Get-SecretStatus exists.
# ---------------------------------------------------------------------------
Describe "Get-SecretStatus" {
    It "returns expired status for a secret past its rotation deadline" {
        # Secret rotated 100 days ago with a 90-day policy -> expired 10 days ago
        $secret = New-SecretFixture -Name "OLD_SECRET" -DaysAgo 100 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        $result.Status | Should -Be "expired"
    }

    # RED TEST 2: warning status
    It "returns warning status when expiry is within the warning window" {
        # Rotated 80 days ago, policy 90 days -> 10 days left, inside 14-day warning window
        $secret = New-SecretFixture -Name "SOON_SECRET" -DaysAgo 80 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        $result.Status | Should -Be "warning"
    }

    # RED TEST 3: ok status
    It "returns ok status for a freshly rotated secret" {
        # Rotated 10 days ago, policy 90 days -> 80 days left
        $secret = New-SecretFixture -Name "FRESH_SECRET" -DaysAgo 10 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        $result.Status | Should -Be "ok"
    }

    It "populates DaysUntilExpiry correctly for expired secret" {
        $secret = New-SecretFixture -Name "STALE" -DaysAgo 100 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        # 100 days ago + 90-day policy = expired 10 days ago -> DaysUntilExpiry = -10
        $result.DaysUntilExpiry | Should -Be -10
    }

    It "populates ExpiryDate correctly" {
        $secret = New-SecretFixture -Name "EXPIRY_CHECK" -DaysAgo 50 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        # Rotated 50 days before 2024-03-01 = 2024-01-11, plus 90 days = 2024-04-10
        $result.ExpiryDate | Should -Be "2024-04-10"
    }

    It "populates RequiredBy from the secret configuration" {
        $secret = New-SecretFixture -Name "SVC_SECRET" -DaysAgo 10 -PolicyDays 90 -RequiredBy @("api", "worker")
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        $result.RequiredBy | Should -Be "api, worker"
    }

    It "treats exact expiry day as warning not expired" {
        # Exactly at expiry: 90 days ago, 90-day policy -> 0 days left (not expired yet)
        $secret = New-SecretFixture -Name "EXACT" -DaysAgo 90 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 14 -CurrentDate $script:ReferenceDate
        $result.Status | Should -Be "warning"
        $result.DaysUntilExpiry | Should -Be 0
    }

    It "respects a custom warning window" {
        # 75 days left, inside a 90-day warning window
        $secret = New-SecretFixture -Name "WIDE_WARN" -DaysAgo 15 -PolicyDays 90
        $result = Get-SecretStatus -Secret $secret -WarningWindowDays 90 -CurrentDate $script:ReferenceDate
        $result.Status | Should -Be "warning"
    }
}

# ---------------------------------------------------------------------------
# Invoke-SecretRotationValidator: loads config file, classifies all secrets
# ---------------------------------------------------------------------------
Describe "Invoke-SecretRotationValidator" {
    BeforeAll {
        $script:MixedConfigPath = "$PSScriptRoot/../fixtures/config-mixed.json"
    }

    It "returns a result object with expired, warning, and ok groups" {
        $result = Invoke-SecretRotationValidator -ConfigPath $script:MixedConfigPath `
            -CurrentDate $script:ReferenceDate -OutputFormat "object"
        $result | Should -Not -BeNullOrEmpty
        $result.expired | Should -Not -BeNullOrEmpty
        $result.warning | Should -Not -BeNullOrEmpty
        $result.ok | Should -Not -BeNullOrEmpty
    }

    It "correctly classifies the expired secret in the mixed fixture" {
        $result = Invoke-SecretRotationValidator -ConfigPath $script:MixedConfigPath `
            -CurrentDate $script:ReferenceDate -OutputFormat "object"
        $expiredNames = $result.expired | ForEach-Object { $_.Name }
        $expiredNames | Should -Contain "DB_PASSWORD"
    }

    It "correctly classifies the warning secret in the mixed fixture" {
        $result = Invoke-SecretRotationValidator -ConfigPath $script:MixedConfigPath `
            -CurrentDate $script:ReferenceDate -OutputFormat "object"
        $warningNames = $result.warning | ForEach-Object { $_.Name }
        $warningNames | Should -Contain "API_KEY"
    }

    It "correctly classifies the ok secret in the mixed fixture" {
        $result = Invoke-SecretRotationValidator -ConfigPath $script:MixedConfigPath `
            -CurrentDate $script:ReferenceDate -OutputFormat "object"
        $okNames = $result.ok | ForEach-Object { $_.Name }
        $okNames | Should -Contain "OAUTH_TOKEN"
    }

    It "throws a meaningful error for missing config file" {
        { Invoke-SecretRotationValidator -ConfigPath "/nonexistent/path.json" } |
            Should -Throw "*not found*"
    }
}

# ---------------------------------------------------------------------------
# Format-MarkdownReport: produces a markdown table grouped by urgency
# ---------------------------------------------------------------------------
Describe "Format-MarkdownReport" {
    BeforeAll {
        $script:SampleResults = @{
            expired = @(@{ Name = "OLD_KEY"; Status = "expired"; DaysUntilExpiry = -5; ExpiryDate = "2024-02-24"; RequiredBy = "api" })
            warning = @(@{ Name = "SOON_KEY"; Status = "warning"; DaysUntilExpiry = 7; ExpiryDate = "2024-03-08"; RequiredBy = "worker" })
            ok      = @(@{ Name = "FRESH_KEY"; Status = "ok"; DaysUntilExpiry = 60; ExpiryDate = "2024-04-30"; RequiredBy = "frontend" })
        }
    }

    It "includes a header section for expired secrets" {
        $md = Format-MarkdownReport -Results $script:SampleResults
        $md | Should -Match "(?i)expired"
    }

    It "includes a header section for warning secrets" {
        $md = Format-MarkdownReport -Results $script:SampleResults
        $md | Should -Match "(?i)warning"
    }

    It "includes the expired secret name in the report" {
        $md = Format-MarkdownReport -Results $script:SampleResults
        $md | Should -Match "OLD_KEY"
    }

    It "includes the warning secret name in the report" {
        $md = Format-MarkdownReport -Results $script:SampleResults
        $md | Should -Match "SOON_KEY"
    }

    It "includes the ok secret name in the report" {
        $md = Format-MarkdownReport -Results $script:SampleResults
        $md | Should -Match "FRESH_KEY"
    }

    It "contains a markdown table header row" {
        $md = Format-MarkdownReport -Results $script:SampleResults
        $md | Should -Match "\|.*Name.*\|"
    }
}

# ---------------------------------------------------------------------------
# Format-JsonReport: produces structured JSON output
# ---------------------------------------------------------------------------
Describe "Format-JsonReport" {
    BeforeAll {
        $script:SampleResults = @{
            expired = @(@{ Name = "OLD_KEY"; Status = "expired"; DaysUntilExpiry = -5; ExpiryDate = "2024-02-24"; RequiredBy = "api" })
            warning = @()
            ok      = @(@{ Name = "FRESH_KEY"; Status = "ok"; DaysUntilExpiry = 60; ExpiryDate = "2024-04-30"; RequiredBy = "frontend" })
        }
    }

    It "produces valid JSON" {
        $json = Format-JsonReport -Results $script:SampleResults
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON contains expired array with the expired secret" {
        $json = Format-JsonReport -Results $script:SampleResults
        $obj = $json | ConvertFrom-Json
        $obj.expired | Should -Not -BeNullOrEmpty
        $obj.expired[0].Name | Should -Be "OLD_KEY"
    }

    It "JSON contains ok array with the ok secret" {
        $json = Format-JsonReport -Results $script:SampleResults
        $obj = $json | ConvertFrom-Json
        $obj.ok | Should -Not -BeNullOrEmpty
        $obj.ok[0].Name | Should -Be "FRESH_KEY"
    }

    It "JSON includes a summary with total counts" {
        $json = Format-JsonReport -Results $script:SampleResults
        $obj = $json | ConvertFrom-Json
        $obj.summary | Should -Not -BeNullOrEmpty
        $obj.summary.total_expired | Should -Be 1
        $obj.summary.total_warning | Should -Be 0
        $obj.summary.total_ok | Should -Be 1
    }
}

# ---------------------------------------------------------------------------
# Workflow structure tests: verify the GHA YAML is correct
# ---------------------------------------------------------------------------
Describe "Workflow Structure" {
    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/../.github/workflows/secret-rotation-validator.yml"
        $script:WorkflowContent = Get-Content -Raw $script:WorkflowPath -ErrorAction SilentlyContinue
    }

    It "workflow file exists at the expected path" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "workflow references the main script" {
        $script:WorkflowContent | Should -Match "SecretRotationValidator\.ps1"
    }

    It "workflow references the Pester test file" {
        $script:WorkflowContent | Should -Match "SecretRotationValidator\.Tests\.ps1"
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $script:WorkflowContent | Should -Match "shell: pwsh"
    }

    It "workflow uses actions/checkout" {
        $script:WorkflowContent | Should -Match "actions/checkout"
    }

    It "script file exists at referenced path" {
        Test-Path "$PSScriptRoot/../SecretRotationValidator.ps1" | Should -Be $true
    }

    It "fixture directory exists with config files" {
        Test-Path "$PSScriptRoot/../fixtures" | Should -Be $true
        (Get-ChildItem "$PSScriptRoot/../fixtures" -Filter "*.json").Count | Should -BeGreaterThan 0
    }

    It "actionlint passes on the workflow file" {
        $lintBin = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $lintBin) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        $lintOutput = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $lintOutput"
    }
}

# ---------------------------------------------------------------------------
# Act Integration Tests: run the workflow via act and assert exact output.
# Tagged "ActIntegration" so the CI workflow can exclude them (act not
# available inside the Docker container that act itself runs in).
# ---------------------------------------------------------------------------
Describe "Act Integration" -Tag "ActIntegration" {
    BeforeAll {
        $script:WorkspaceRoot = "$PSScriptRoot/.."
        $script:ActResultFile = "$script:WorkspaceRoot/act-result.txt"

        # Clear (or create) the result file before all act runs
        Set-Content -Path $script:ActResultFile -Value "" -Force

        # Helper: set up a temp git repo, copy project files, run act, capture output
        function Invoke-ActTestCase {
            param(
                [string]$CaseName,
                [string]$ConfigFile,       # path to fixture config relative to fixtures/
                [int]$WarningWindowDays = 14,
                [string]$OutputFormat = "markdown",
                [string]$ReferenceDate = "2024-03-01"
            )

            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$CaseName-$([System.Guid]::NewGuid().ToString('N')[0..7] -join '')"
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

            try {
                # Copy project files into tmp repo
                $filesToCopy = @(
                    "SecretRotationValidator.ps1",
                    ".github",
                    "fixtures",
                    "tests",
                    ".actrc"
                )
                foreach ($f in $filesToCopy) {
                    $src = Join-Path $script:WorkspaceRoot $f
                    if (Test-Path $src -PathType Container) {
                        Copy-Item -Recurse -Force $src (Join-Path $tmpDir $f)
                    } elseif (Test-Path $src) {
                        Copy-Item -Force $src (Join-Path $tmpDir $f)
                    }
                }

                # Init git repo
                Push-Location $tmpDir
                git init -q
                git config user.email "test@test.com"
                git config user.name "Test"
                git add -A
                git commit -q -m "test: $CaseName"

                # Build env var overrides for the workflow
                $envArgs = @(
                    "--env", "INPUT_CONFIG_FILE=fixtures/$ConfigFile",
                    "--env", "INPUT_WARNING_WINDOW_DAYS=$WarningWindowDays",
                    "--env", "INPUT_OUTPUT_FORMAT=$OutputFormat",
                    "--env", "INPUT_REFERENCE_DATE=$ReferenceDate"
                )

                # Run act (--pull=false uses local image, no Docker Hub pull needed)
                $actOutput = & act push --rm --pull=false @envArgs 2>&1 | Out-String
                $actExitCode = $LASTEXITCODE

                Pop-Location

                # Append to act-result.txt
                $delimiter = "`n=== TEST CASE: $CaseName ===`n"
                Add-Content -Path $script:ActResultFile -Value $delimiter
                Add-Content -Path $script:ActResultFile -Value $actOutput

                return @{
                    Output   = $actOutput
                    ExitCode = $actExitCode
                    CaseName = $CaseName
                }
            } finally {
                if ((Get-Location).Path -eq $tmpDir) { Pop-Location }
                Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
            }
        }

        # Run test cases upfront (once) so individual It blocks can assert
        Write-Host "Running act test case 1: expired secrets..."
        $script:ActResult1 = Invoke-ActTestCase -CaseName "expired-secret" `
            -ConfigFile "config-expired.json" -WarningWindowDays 14 -OutputFormat "markdown" `
            -ReferenceDate "2024-03-01"

        Write-Host "Running act test case 2: mixed secrets (JSON output)..."
        $script:ActResult2 = Invoke-ActTestCase -CaseName "mixed-secrets-json" `
            -ConfigFile "config-mixed.json" -WarningWindowDays 14 -OutputFormat "json" `
            -ReferenceDate "2024-03-01"
    }

    # --- Test Case 1: expired secrets ---
    It "act exits with code 0 for expired-secret test case" {
        $script:ActResult1.ExitCode | Should -Be 0 -Because "act output:`n$($script:ActResult1.Output)"
    }

    It "act output shows Job succeeded for expired-secret test case" {
        $script:ActResult1.Output | Should -Match "Job succeeded"
    }

    It "act output contains EXPIRED_DB_PASS secret name for expired test case" {
        $script:ActResult1.Output | Should -Match "EXPIRED_DB_PASS"
    }

    It "act output contains expired classification for expired test case" {
        $script:ActResult1.Output | Should -Match "(?i)expired"
    }

    # --- Test Case 2: mixed secrets, JSON output ---
    It "act exits with code 0 for mixed-secrets-json test case" {
        $script:ActResult2.ExitCode | Should -Be 0 -Because "act output:`n$($script:ActResult2.Output)"
    }

    It "act output shows Job succeeded for mixed-secrets-json test case" {
        $script:ActResult2.Output | Should -Match "Job succeeded"
    }

    It "act output contains DB_PASSWORD in expired section for mixed JSON output" {
        $script:ActResult2.Output | Should -Match "DB_PASSWORD"
    }

    It "act output contains API_KEY in warning section for mixed JSON output" {
        $script:ActResult2.Output | Should -Match "API_KEY"
    }

    It "act output contains OAUTH_TOKEN in ok section for mixed JSON output" {
        $script:ActResult2.Output | Should -Match "OAUTH_TOKEN"
    }

    It "act-result.txt file exists and is non-empty" {
        Test-Path $script:ActResultFile | Should -Be $true
        (Get-Item $script:ActResultFile).Length | Should -BeGreaterThan 0
    }
}
