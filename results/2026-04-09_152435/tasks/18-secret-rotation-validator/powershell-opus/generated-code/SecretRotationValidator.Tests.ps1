# SecretRotationValidator.Tests.ps1
#
# TDD approach: These tests were written FIRST as failing ("red") tests,
# then SecretRotationValidator.ps1 was implemented to make them pass ("green"),
# then the code was refactored while keeping tests green.
#
# Test structure:
#   1. Workflow Structure Tests - validate YAML structure, triggers, paths, actionlint
#   2. Act Integration - Mixed Config - run workflow with expired+warning+ok secrets
#   3. Act Integration - All OK Config - run workflow with all-ok secrets
#
# Each act integration test case:
#   - Creates a temp git repo with project files + fixture data
#   - Runs `act push --rm` to execute the workflow
#   - Captures output to act-result.txt
#   - Asserts exact expected values from the deterministic test data

Describe "Secret Rotation Validator" {
    BeforeAll {
        $script:ProjectRoot = $PSScriptRoot
        $script:WorkflowPath = Join-Path $script:ProjectRoot ".github" "workflows" "secret-rotation-validator.yml"
        $script:ScriptPath = Join-Path $script:ProjectRoot "SecretRotationValidator.ps1"
        $script:ActResultPath = Join-Path $script:ProjectRoot "act-result.txt"

        # Initialize act-result.txt (required artifact)
        Set-Content -Path $script:ActResultPath -Value ""

        # Helper: sets up an isolated git repo with project files + fixture, runs act, returns output
        function Invoke-ActTest {
            param(
                [string]$FixturePath,
                [string]$TestLabel
            )

            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$([Guid]::NewGuid().ToString('N'))"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            $origDir = Get-Location

            try {
                # Copy project files into the temp repo
                Copy-Item $script:ScriptPath (Join-Path $tempDir "SecretRotationValidator.ps1")
                Copy-Item $FixturePath (Join-Path $tempDir "secrets-config.json")
                Copy-Item (Join-Path $script:ProjectRoot ".actrc") (Join-Path $tempDir ".actrc")

                # Copy workflow
                $wfDir = Join-Path $tempDir ".github" "workflows"
                New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
                Copy-Item $script:WorkflowPath (Join-Path $wfDir "secret-rotation-validator.yml")

                # Initialize a git repo (act requires a git repo)
                Set-Location $tempDir
                git init --initial-branch=main 2>&1 | Out-Null
                git config user.email "test@test.com" 2>&1 | Out-Null
                git config user.name "Test" 2>&1 | Out-Null
                git add -A 2>&1 | Out-Null
                git commit -m "test commit" 2>&1 | Out-Null

                # Run act push to simulate a push event
                $rawOutput = & act push --rm --pull=false 2>&1
                $exitCode = $LASTEXITCODE

                Set-Location $origDir

                # Convert output to string array and join
                $outputLines = $rawOutput | ForEach-Object { $_.ToString() }
                $outputStr = $outputLines -join "`n"

                # Append to act-result.txt (required artifact)
                Add-Content -Path $script:ActResultPath -Value "===== TEST CASE: $TestLabel ====="
                Add-Content -Path $script:ActResultPath -Value $outputStr
                Add-Content -Path $script:ActResultPath -Value "===== END: $TestLabel ====="
                Add-Content -Path $script:ActResultPath -Value ""

                return @{
                    Output   = $outputStr
                    ExitCode = $exitCode
                }
            } catch {
                Set-Location $origDir -ErrorAction SilentlyContinue
                throw
            } finally {
                Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
            }
        }
    }

    # =========================================================================
    # Workflow Structure Tests (local, fast - no act needed)
    # =========================================================================
    Describe "Workflow Structure" {
        BeforeAll {
            $script:workflowContent = Get-Content -Path $script:WorkflowPath -Raw
        }

        It "workflow YAML file exists" {
            Test-Path $script:WorkflowPath | Should -BeTrue
        }

        It "has push trigger" {
            $script:workflowContent | Should -Match "on:[\s\S]*push:"
        }

        It "has pull_request trigger" {
            $script:workflowContent | Should -Match "pull_request"
        }

        It "has schedule trigger with cron expression" {
            $script:workflowContent | Should -Match "schedule:"
            $script:workflowContent | Should -Match "cron:"
        }

        It "has workflow_dispatch trigger" {
            $script:workflowContent | Should -Match "workflow_dispatch"
        }

        It "defines validate-secrets job" {
            $script:workflowContent | Should -Match "validate-secrets:"
        }

        It "job runs on ubuntu-latest" {
            $script:workflowContent | Should -Match "runs-on:\s*ubuntu-latest"
        }

        It "uses actions/checkout@v4" {
            $script:workflowContent | Should -Match "actions/checkout@v4"
        }

        It "uses shell: pwsh for run steps" {
            $script:workflowContent | Should -Match "shell:\s*pwsh"
        }

        It "references SecretRotationValidator.ps1 script" {
            $script:workflowContent | Should -Match "SecretRotationValidator\.ps1"
        }

        It "references secrets-config.json" {
            $script:workflowContent | Should -Match "secrets-config\.json"
        }

        It "script file exists at referenced path" {
            Test-Path $script:ScriptPath | Should -BeTrue
        }

        It "passes actionlint validation with exit code 0" {
            $lintOutput = actionlint $script:WorkflowPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    # =========================================================================
    # Act Integration: Mixed Config (1 expired, 1 warning, 1 ok)
    # Reference date: 2026-04-10, Warning window: 14 days
    #
    # Expected results:
    #   DB_PASSWORD: expired 2025-04-01, 374 days overdue
    #   API_KEY:     warning, expires 2026-04-19, 9 days until expiry
    #   TLS_CERT:    ok, expires 2027-04-01, 356 days until expiry
    # =========================================================================
    Describe "Act Integration - Mixed Config" {
        BeforeAll {
            $fixturePath = Join-Path $script:ProjectRoot "test-fixtures" "mixed-config.json"
            $script:mixedResult = Invoke-ActTest -FixturePath $fixturePath -TestLabel "mixed-config"
        }

        It "act exits with code 0" {
            $script:mixedResult.ExitCode | Should -Be 0
        }

        It "job completed successfully" {
            $script:mixedResult.Output | Should -Match "succeeded"
        }

        # --- Markdown format exact value assertions ---

        It "markdown: report header shows reference date 2026-04-10" {
            $script:mixedResult.Output | Should -Match "Reference Date: 2026-04-10"
        }

        It "markdown: shows exactly 1 expired secret" {
            $script:mixedResult.Output | Should -Match "EXPIRED \(1\)"
        }

        It "markdown: DB_PASSWORD expired with expiry 2025-04-01 and 374 days overdue" {
            $script:mixedResult.Output | Should -Match "DB_PASSWORD.*2025-01-01.*90.*2025-04-01.*374"
        }

        It "markdown: DB_PASSWORD required by api-service and worker-service" {
            $script:mixedResult.Output | Should -Match "DB_PASSWORD.*api-service, worker-service"
        }

        It "markdown: shows exactly 1 warning secret" {
            $script:mixedResult.Output | Should -Match "WARNING \(1\)"
        }

        It "markdown: API_KEY warning with expiry 2026-04-19 and 9 days remaining" {
            $script:mixedResult.Output | Should -Match "API_KEY.*2026-03-20.*30.*2026-04-19.*9"
        }

        It "markdown: shows exactly 1 ok secret" {
            $script:mixedResult.Output | Should -Match "## OK \(1\)"
        }

        It "markdown: TLS_CERT ok with expiry 2027-04-01 and 356 days remaining" {
            $script:mixedResult.Output | Should -Match "TLS_CERT.*2026-04-01.*365.*2027-04-01.*356"
        }

        It "markdown: summary line shows 1 expired, 1 warning, 1 ok" {
            $script:mixedResult.Output | Should -Match "Summary: 1 expired, 1 warning, 1 ok"
        }

        # --- JSON format exact value assertions ---

        It "JSON: referenceDate is 2026-04-10" {
            $script:mixedResult.Output | Should -Match '"referenceDate":\s*"2026-04-10"'
        }

        It "JSON: DB_PASSWORD daysUntilExpiry is exactly -374" {
            $script:mixedResult.Output | Should -Match '"daysUntilExpiry":\s*-374'
        }

        It "JSON: API_KEY daysUntilExpiry is exactly 9" {
            $script:mixedResult.Output | Should -Match '"daysUntilExpiry":\s*9\b'
        }

        It "JSON: TLS_CERT daysUntilExpiry is exactly 356" {
            $script:mixedResult.Output | Should -Match '"daysUntilExpiry":\s*356'
        }

        It "JSON: summary expired count is 1" {
            $script:mixedResult.Output | Should -Match '"expired":\s*1'
        }

        It "JSON: summary warning count is 1" {
            $script:mixedResult.Output | Should -Match '"warning":\s*1'
        }

        It "JSON: summary ok count is 1" {
            # Match specifically the summary ok count (followed by newline, not array)
            $script:mixedResult.Output | Should -Match '"ok":\s*1'
        }
    }

    # =========================================================================
    # Act Integration: All OK Config (0 expired, 0 warning, 2 ok)
    # Reference date: 2026-04-10, Warning window: 7 days
    #
    # Expected results:
    #   SESSION_SECRET:  ok, expires 2026-07-04, 85 days until expiry
    #   ENCRYPTION_KEY:  ok, expires 2026-09-28, 171 days until expiry
    # =========================================================================
    Describe "Act Integration - All OK Config" {
        BeforeAll {
            $fixturePath = Join-Path $script:ProjectRoot "test-fixtures" "all-ok-config.json"
            $script:okResult = Invoke-ActTest -FixturePath $fixturePath -TestLabel "all-ok-config"
        }

        It "act exits with code 0" {
            $script:okResult.ExitCode | Should -Be 0
        }

        It "job completed successfully" {
            $script:okResult.Output | Should -Match "succeeded"
        }

        # --- Markdown format exact value assertions ---

        It "markdown: shows 0 expired secrets" {
            $script:okResult.Output | Should -Match "EXPIRED \(0\)"
        }

        It "markdown: shows no expired secrets message" {
            $script:okResult.Output | Should -Match "No expired secrets"
        }

        It "markdown: shows 0 warning secrets" {
            $script:okResult.Output | Should -Match "WARNING \(0\)"
        }

        It "markdown: shows no warning secrets message" {
            $script:okResult.Output | Should -Match "No secrets in warning state"
        }

        It "markdown: shows exactly 2 ok secrets" {
            $script:okResult.Output | Should -Match "OK \(2\)"
        }

        It "markdown: SESSION_SECRET ok with expiry 2026-07-04 and 85 days remaining" {
            $script:okResult.Output | Should -Match "SESSION_SECRET.*2026-04-05.*90.*2026-07-04.*85"
        }

        It "markdown: ENCRYPTION_KEY ok with expiry 2026-09-28 and 171 days remaining" {
            $script:okResult.Output | Should -Match "ENCRYPTION_KEY.*2026-04-01.*180.*2026-09-28.*171"
        }

        It "markdown: summary line shows 0 expired, 0 warning, 2 ok" {
            $script:okResult.Output | Should -Match "Summary: 0 expired, 0 warning, 2 ok"
        }

        # --- JSON format exact value assertions ---

        It "JSON: summary expired count is 0" {
            $script:okResult.Output | Should -Match '"expired":\s*0'
        }

        It "JSON: summary warning count is 0" {
            $script:okResult.Output | Should -Match '"warning":\s*0'
        }

        It "JSON: summary ok count is 2" {
            $script:okResult.Output | Should -Match '"ok":\s*2'
        }

        It "JSON: SESSION_SECRET daysUntilExpiry is exactly 85" {
            $script:okResult.Output | Should -Match '"daysUntilExpiry":\s*85'
        }

        It "JSON: ENCRYPTION_KEY daysUntilExpiry is exactly 171" {
            $script:okResult.Output | Should -Match '"daysUntilExpiry":\s*171'
        }

        It "JSON: warning window is 7 days" {
            $script:okResult.Output | Should -Match '"warningWindowDays":\s*7'
        }
    }
}
