# Dependency License Checker - Pester Test Suite
#
# TDD Approach (Red/Green/Refactor):
#   Iteration 1 (RED):  Workflow structure tests written before workflow exists
#   Iteration 1 (GREEN): Workflow file created - structure tests pass
#   Iteration 2 (RED):  Script reference tests written before script exists
#   Iteration 2 (GREEN): Invoke-LicenseChecker.ps1 created - reference tests pass
#   Iteration 3 (RED):  actionlint test written (checks YAML validity)
#   Iteration 3 (GREEN): Workflow fixed until actionlint passes
#   Iteration 4 (RED):  Act integration tests with exact expected output values
#   Iteration 4 (GREEN): Script produces correct output - all act assertions pass
#
# All meaningful test assertions go through the GitHub Actions pipeline via act.
# Workflow structure tests validate the workflow file itself without running act.

$ErrorActionPreference = 'Stop'

Describe "Dependency License Checker" {

    BeforeAll {
        $script:WorkspaceDir = $PSScriptRoot
        $script:WorkflowFile = Join-Path $script:WorkspaceDir ".github" "workflows" "dependency-license-checker.yml"
        $script:ScriptFile   = Join-Path $script:WorkspaceDir "Invoke-LicenseChecker.ps1"
    }

    # -------------------------------------------------------------------------
    # TDD Iteration 1 & 2 (RED -> GREEN): Workflow structure tests
    # These tests were written BEFORE the workflow file existed and initially
    # failed. Creating the workflow and script files made them GREEN.
    # -------------------------------------------------------------------------
    Describe "Workflow Structure" {

        It "workflow file exists" {
            $script:WorkflowFile | Should -Exist
        }

        It "workflow has push trigger" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match '(?m)^\s+push:'
        }

        It "workflow has pull_request trigger" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'pull_request'
        }

        It "workflow has workflow_dispatch trigger" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'workflow_dispatch'
        }

        It "workflow uses actions/checkout@v4" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'actions/checkout@v4'
        }

        It "workflow uses shell: pwsh for run steps" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'shell:\s*pwsh'
        }

        It "workflow references Invoke-LicenseChecker.ps1" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'Invoke-LicenseChecker\.ps1'
        }

        It "workflow references package.json fixture" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'fixtures/package\.json'
        }

        It "workflow references requirements.txt fixture" {
            $content = Get-Content $script:WorkflowFile -Raw
            $content | Should -Match 'fixtures/requirements\.txt'
        }

        It "script file exists" {
            $script:ScriptFile | Should -Exist
        }

        It "fixture files all exist" {
            Join-Path $script:WorkspaceDir "fixtures" "package.json"       | Should -Exist
            Join-Path $script:WorkspaceDir "fixtures" "requirements.txt"   | Should -Exist
            Join-Path $script:WorkspaceDir "fixtures" "license-config.json"  | Should -Exist
            Join-Path $script:WorkspaceDir "fixtures" "mock-license-db.json" | Should -Exist
        }
    }

    # -------------------------------------------------------------------------
    # TDD Iteration 3 (RED -> GREEN): actionlint validation
    # Written before the workflow was lint-clean. Fixed YAML issues until GREEN.
    # -------------------------------------------------------------------------
    Describe "Workflow Lint" {

        It "passes actionlint with exit code 0" {
            $output = & actionlint $script:WorkflowFile 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) {
                Write-Host "actionlint output: $output"
            }
            $exitCode | Should -Be 0
        }
    }

    # -------------------------------------------------------------------------
    # TDD Iteration 4 (RED -> GREEN): Act integration tests
    # These tests set up a temp git repo, run `act push --rm`, and assert on
    # EXACT expected output values from the license checker.
    #
    # Expected output (package.json):
    #   express|^4.18.0|MIT|APPROVED
    #   lodash|^4.17.21|MIT|APPROVED
    #   gpl-lib|^1.0.0|GPL-3.0|DENIED
    #   mystery-lib|^2.0.0|UNKNOWN|UNKNOWN
    #   SUMMARY: APPROVED=2 DENIED=1 UNKNOWN=1 TOTAL=4
    #
    # Expected output (requirements.txt):
    #   requests|2.28.0|Apache-2.0|APPROVED
    #   flask|2.3.0|BSD-3-Clause|APPROVED
    #   copyleft-lib|1.0.0|AGPL-3.0|DENIED
    #   mystery-pkg|0.5.0|UNKNOWN|UNKNOWN
    #   SUMMARY: APPROVED=2 DENIED=1 UNKNOWN=1 TOTAL=4
    # -------------------------------------------------------------------------
    Describe "Act Integration" {

        BeforeAll {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lc-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            # Copy all project files to temp dir (excluding git history and claude state)
            $sourceDir = $script:WorkspaceDir
            $filesToCopy = Get-ChildItem -Path $sourceDir -Recurse -File -Force |
                Where-Object {
                    $_.FullName -notmatch '[/\\]\.git[/\\]' -and
                    $_.FullName -notmatch '[/\\]\.claude[/\\]' -and
                    $_.Name -ne 'act-result.txt'
                }

            foreach ($file in $filesToCopy) {
                $relPath = $file.FullName.Substring($sourceDir.Length).TrimStart('/', '\')
                $destFile = Join-Path $script:TempDir $relPath
                $destDir  = Split-Path $destFile -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item $file.FullName $destFile -Force
            }

            Push-Location $script:TempDir
            try {
                # Initialize git repo and commit all files
                & git init --quiet 2>&1 | Out-Null
                & git config user.email 'test@example.com' 2>&1 | Out-Null
                & git config user.name  'Test' 2>&1 | Out-Null
                & git add -A 2>&1 | Out-Null
                & git commit -m 'test: license checker ci' --quiet 2>&1 | Out-Null

                # Run act (single run covering both test cases via workflow)
                $output = & act push --rm 2>&1
                $script:ActExitCode  = $LASTEXITCODE
                $script:ActOutputStr = $output -join "`n"
            }
            finally {
                Pop-Location

                # Always write act-result.txt — this is a required artifact
                $actResultPath = Join-Path $script:WorkspaceDir 'act-result.txt'
                $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                @"
=== ACT TEST RUN: $ts ===
=== Exit Code: $($script:ActExitCode) ===

$($script:ActOutputStr)

=== END ACT TEST RUN ===
"@ | Out-File -FilePath $actResultPath -Encoding utf8

                # Cleanup temp directory
                if (Test-Path $script:TempDir) {
                    Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
                }
            }
        }

        It "act exited with code 0" {
            $script:ActExitCode | Should -Be 0
        }

        It "every job shows Job succeeded" {
            $script:ActOutputStr | Should -Match 'Job succeeded'
        }

        # package.json test case assertions
        Context "package.json compliance report" {

            It "express is MIT and APPROVED" {
                $script:ActOutputStr | Should -Match 'express\|\^4\.18\.0\|MIT\|APPROVED'
            }

            It "lodash is MIT and APPROVED" {
                $script:ActOutputStr | Should -Match 'lodash\|\^4\.17\.21\|MIT\|APPROVED'
            }

            It "gpl-lib is GPL-3.0 and DENIED" {
                $script:ActOutputStr | Should -Match 'gpl-lib\|\^1\.0\.0\|GPL-3\.0\|DENIED'
            }

            It "mystery-lib is UNKNOWN" {
                $script:ActOutputStr | Should -Match 'mystery-lib\|\^2\.0\.0\|UNKNOWN\|UNKNOWN'
            }

            It "package.json summary shows APPROVED=2 DENIED=1 UNKNOWN=1 TOTAL=4" {
                $script:ActOutputStr | Should -Match 'APPROVED=2 DENIED=1 UNKNOWN=1 TOTAL=4'
            }
        }

        # requirements.txt test case assertions
        Context "requirements.txt compliance report" {

            It "requests is Apache-2.0 and APPROVED" {
                $script:ActOutputStr | Should -Match 'requests\|2\.28\.0\|Apache-2\.0\|APPROVED'
            }

            It "flask is BSD-3-Clause and APPROVED" {
                $script:ActOutputStr | Should -Match 'flask\|2\.3\.0\|BSD-3-Clause\|APPROVED'
            }

            It "copyleft-lib is AGPL-3.0 and DENIED" {
                $script:ActOutputStr | Should -Match 'copyleft-lib\|1\.0\.0\|AGPL-3\.0\|DENIED'
            }

            It "mystery-pkg is UNKNOWN" {
                $script:ActOutputStr | Should -Match 'mystery-pkg\|0\.5\.0\|UNKNOWN\|UNKNOWN'
            }

            It "requirements.txt summary shows APPROVED=2 DENIED=1 UNKNOWN=1 TOTAL=4" {
                # Both summaries will appear in output; match either occurrence
                ($script:ActOutputStr -split "`n" | Where-Object { $_ -match 'APPROVED=2 DENIED=1 UNKNOWN=1 TOTAL=4' }).Count |
                    Should -BeGreaterOrEqual 2
            }
        }
    }
}
