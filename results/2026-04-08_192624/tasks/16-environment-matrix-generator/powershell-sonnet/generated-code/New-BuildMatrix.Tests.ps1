# New-BuildMatrix.Tests.ps1
# Pester test suite for the Environment Matrix Generator
#
# TDD METHODOLOGY:
#   RED:    Each test block defines expected behavior before implementation exists
#   GREEN:  Implementation written to make tests pass
#   REFACTOR: Code cleaned up while keeping tests green
#
# ALL MATRIX GENERATION TESTS RUN THROUGH ACT:
#   - Each test case creates a temp git repo with the fixture config
#   - Runs `act push --rm` to execute the GitHub Actions workflow
#   - Asserts on exact expected values from the workflow output
#
# WORKFLOW STRUCTURE TESTS:
#   - Verify YAML structure (triggers, jobs, steps)
#   - Verify script file references exist
#   - Verify actionlint passes

BeforeAll {
    $script:ProjectDir  = $PSScriptRoot
    $script:ResultFile  = Join-Path $PSScriptRoot "act-result.txt"
    $script:WorkflowFile = Join-Path $PSScriptRoot ".github/workflows/environment-matrix-generator.yml"
    $script:ScriptFile  = Join-Path $PSScriptRoot "New-BuildMatrix.ps1"

    # Initialise (or reset) the act-result artefact
    Set-Content -Path $script:ResultFile -Value "# act-result.txt`n# Environment Matrix Generator - Act Test Results`n# Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')`n"

    # ----------------------------------------------------------------
    # Helper: spin up a temp git repo, copy project files + fixture,
    # run `act push --rm`, capture output → act-result.txt, return result
    # ----------------------------------------------------------------
    function script:Invoke-ActTest {
        param(
            [Parameter(Mandatory)][string]$TestName,
            [Parameter(Mandatory)][object]$Config
        )

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "matrix-test-$(New-Guid)"
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        try {
            Push-Location $tempDir

            # Init bare git repo
            & git init -b main 2>&1 | Out-Null
            & git config user.email "test@example.com" 2>&1 | Out-Null
            & git config user.name "Test Runner"     2>&1 | Out-Null

            # Copy project files
            Copy-Item $script:ScriptFile .
            New-Item -ItemType Directory -Path ".github/workflows" -Force | Out-Null
            Copy-Item $script:WorkflowFile ".github/workflows/"

            # Write fixture as matrix-config.json
            $Config | ConvertTo-Json -Depth 10 | Set-Content "matrix-config.json"

            # Commit everything so actions/checkout@v4 can work
            & git add -A 2>&1 | Out-Null
            & git commit -m "test: $TestName" 2>&1 | Out-Null

            # Run act; redirect stderr to stdout so we capture everything
            $actOutput = & act push --rm 2>&1
            $exitCode  = $LASTEXITCODE

            # ---- append to act-result.txt ----
            $sep = "=" * 70
            $block = @"
$sep
TEST CASE : $TestName
EXIT CODE : $exitCode
TIMESTAMP : $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
$sep
$($actOutput -join "`n")
$sep

"@
            Add-Content -Path $script:ResultFile -Value $block

            return @{
                ExitCode = $exitCode
                Output   = ($actOutput -join "`n")
            }
        }
        finally {
            Pop-Location
            if (Test-Path $tempDir) {
                Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
            }
        }
    }

    # ----------------------------------------------------------------
    # Helper: extract the strategy JSON from act output
    # The script writes "MATRIX_OUTPUT: <compact-json>" to stdout
    # ----------------------------------------------------------------
    function script:Get-MatrixFromOutput {
        param([string]$Output)
        foreach ($line in ($Output -split "`n")) {
            if ($line -match 'MATRIX_OUTPUT:\s*(\{.+\})') {
                return ($Matches[1] | ConvertFrom-Json)
            }
        }
        return $null
    }
}

# ===========================================================================
# PHASE 1 — Workflow Structure Tests  (no act required)
# TDD RED: written before the workflow file was created
# ===========================================================================
Describe "Workflow Structure" {

    It "Workflow YAML file exists" {
        # RED: fails until .github/workflows/environment-matrix-generator.yml is created
        Test-Path $script:WorkflowFile | Should -Be $true
    }

    It "Script file New-BuildMatrix.ps1 exists" {
        Test-Path $script:ScriptFile | Should -Be $true
    }

    It "Workflow has a push trigger" {
        $content = Get-Content $script:WorkflowFile -Raw
        $content | Should -Match "push"
    }

    It "Workflow has a workflow_dispatch trigger" {
        $content = Get-Content $script:WorkflowFile -Raw
        $content | Should -Match "workflow_dispatch"
    }

    It "Workflow references New-BuildMatrix.ps1" {
        $content = Get-Content $script:WorkflowFile -Raw
        $content | Should -Match "New-BuildMatrix\.ps1"
    }

    It "Workflow references matrix-config.json" {
        $content = Get-Content $script:WorkflowFile -Raw
        $content | Should -Match "matrix-config\.json"
    }

    It "actionlint passes with exit code 0" {
        $out = & actionlint $script:WorkflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $($out -join ', ')"
    }
}

# ===========================================================================
# PHASE 2 — Matrix Generation Tests  (all via act)
# TDD RED: each Context was written before the corresponding script logic
# ===========================================================================
Describe "Matrix Generation via Act" {

    # -----------------------------------------------------------------------
    # Test 1: Basic OS-only matrix
    # RED: written first — expects matrix.os to contain both OS entries
    # GREEN: New-BuildMatrix handles 'os' key
    # -----------------------------------------------------------------------
    Context "Basic OS-only matrix" {
        BeforeAll {
            $script:basicResult = script:Invoke-ActTest -TestName "basic-os-matrix" -Config @{
                os = @("ubuntu-latest", "windows-latest")
            }
        }

        It "act exits with code 0" {
            $script:basicResult.ExitCode | Should -Be 0
        }

        It "output contains Job succeeded" {
            $script:basicResult.Output | Should -Match "Job succeeded"
        }

        It "output contains MATRIX_OUTPUT marker" {
            $script:basicResult.Output | Should -Match "MATRIX_OUTPUT:"
        }

        It "matrix.os contains ubuntu-latest" {
            $m = script:Get-MatrixFromOutput $script:basicResult.Output
            $m | Should -Not -BeNullOrEmpty
            $m.matrix.os | Should -Contain "ubuntu-latest"
        }

        It "matrix.os contains windows-latest" {
            $m = script:Get-MatrixFromOutput $script:basicResult.Output
            $m.matrix.os | Should -Contain "windows-latest"
        }

        It "matrix.os has exactly 2 entries" {
            $m = script:Get-MatrixFromOutput $script:basicResult.Output
            @($m.matrix.os) | Should -HaveCount 2
        }
    }

    # -----------------------------------------------------------------------
    # Test 2: Language versions become matrix dimensions
    # RED: expects matrix.node with versions 16, 18, 20
    # GREEN: New-BuildMatrix handles 'languageVersions' key
    # -----------------------------------------------------------------------
    Context "OS plus language versions" {
        BeforeAll {
            $script:langResult = script:Invoke-ActTest -TestName "language-versions" -Config @{
                os = @("ubuntu-latest")
                languageVersions = @{
                    node = @("16", "18", "20")
                }
            }
        }

        It "act exits with code 0" {
            $script:langResult.ExitCode | Should -Be 0
        }

        It "matrix.node contains version 16" {
            $m = script:Get-MatrixFromOutput $script:langResult.Output
            $m.matrix.node | Should -Contain "16"
        }

        It "matrix.node contains version 18" {
            $m = script:Get-MatrixFromOutput $script:langResult.Output
            $m.matrix.node | Should -Contain "18"
        }

        It "matrix.node contains version 20" {
            $m = script:Get-MatrixFromOutput $script:langResult.Output
            $m.matrix.node | Should -Contain "20"
        }

        It "matrix.node has exactly 3 entries" {
            $m = script:Get-MatrixFromOutput $script:langResult.Output
            @($m.matrix.node) | Should -HaveCount 3
        }
    }

    # -----------------------------------------------------------------------
    # Test 3: Feature flags become matrix dimensions
    # RED: expects matrix.experimental with true/false
    # GREEN: New-BuildMatrix handles 'featureFlags' key
    # -----------------------------------------------------------------------
    Context "Feature flags as matrix dimensions" {
        BeforeAll {
            $script:flagsResult = script:Invoke-ActTest -TestName "feature-flags" -Config @{
                os = @("ubuntu-latest")
                featureFlags = @{
                    experimental = @($true, $false)
                }
            }
        }

        It "act exits with code 0" {
            $script:flagsResult.ExitCode | Should -Be 0
        }

        It "matrix.experimental exists" {
            $m = script:Get-MatrixFromOutput $script:flagsResult.Output
            $m.matrix.experimental | Should -Not -BeNullOrEmpty
        }

        It "matrix.experimental has exactly 2 entries" {
            $m = script:Get-MatrixFromOutput $script:flagsResult.Output
            @($m.matrix.experimental) | Should -HaveCount 2
        }
    }

    # -----------------------------------------------------------------------
    # Test 4: Include rules pass through to matrix output
    # RED: expects matrix.include with the specified extra combination
    # GREEN: New-BuildMatrix passes 'include' through
    # -----------------------------------------------------------------------
    Context "Include rules" {
        BeforeAll {
            $script:includeResult = script:Invoke-ActTest -TestName "include-rules" -Config @{
                os = @("ubuntu-latest")
                languageVersions = @{ python = @("3.10", "3.11") }
                include = @(
                    @{ os = "macos-latest"; python = "3.12"; experimental = $true }
                )
            }
        }

        It "act exits with code 0" {
            $script:includeResult.ExitCode | Should -Be 0
        }

        It "matrix.include exists" {
            $m = script:Get-MatrixFromOutput $script:includeResult.Output
            $m.matrix.include | Should -Not -BeNullOrEmpty
        }

        It "matrix.include has exactly 1 entry" {
            $m = script:Get-MatrixFromOutput $script:includeResult.Output
            @($m.matrix.include) | Should -HaveCount 1
        }

        It "matrix.include entry has os macos-latest" {
            $m = script:Get-MatrixFromOutput $script:includeResult.Output
            $m.matrix.include[0].os | Should -Be "macos-latest"
        }
    }

    # -----------------------------------------------------------------------
    # Test 5: Exclude rules pass through to matrix output
    # RED: expects matrix.exclude with the specified excluded combination
    # GREEN: New-BuildMatrix passes 'exclude' through
    # -----------------------------------------------------------------------
    Context "Exclude rules" {
        BeforeAll {
            $script:excludeResult = script:Invoke-ActTest -TestName "exclude-rules" -Config @{
                os = @("ubuntu-latest", "windows-latest")
                languageVersions = @{ node = @("16", "18") }
                exclude = @(
                    @{ os = "windows-latest"; node = "16" }
                )
            }
        }

        It "act exits with code 0" {
            $script:excludeResult.ExitCode | Should -Be 0
        }

        It "matrix.exclude exists" {
            $m = script:Get-MatrixFromOutput $script:excludeResult.Output
            $m.matrix.exclude | Should -Not -BeNullOrEmpty
        }

        It "matrix.exclude has exactly 1 entry" {
            $m = script:Get-MatrixFromOutput $script:excludeResult.Output
            @($m.matrix.exclude) | Should -HaveCount 1
        }

        It "matrix.exclude entry has os windows-latest" {
            $m = script:Get-MatrixFromOutput $script:excludeResult.Output
            $m.matrix.exclude[0].os | Should -Be "windows-latest"
        }

        It "matrix.exclude entry has node 16" {
            $m = script:Get-MatrixFromOutput $script:excludeResult.Output
            $m.matrix.exclude[0].node | Should -Be "16"
        }
    }

    # -----------------------------------------------------------------------
    # Test 6: max-parallel and fail-fast configuration
    # RED: expects max-parallel=3 and fail-fast=false at strategy level
    # GREEN: New-BuildMatrix handles 'maxParallel' and 'failFast' keys
    # -----------------------------------------------------------------------
    Context "max-parallel and fail-fast" {
        BeforeAll {
            $script:parallelResult = script:Invoke-ActTest -TestName "max-parallel-fail-fast" -Config @{
                os = @("ubuntu-latest", "windows-latest")
                languageVersions = @{ python = @("3.10", "3.11") }
                maxParallel = 3
                failFast    = $false
            }
        }

        It "act exits with code 0" {
            $script:parallelResult.ExitCode | Should -Be 0
        }

        It "strategy has max-parallel = 3" {
            $m = script:Get-MatrixFromOutput $script:parallelResult.Output
            $m.'max-parallel' | Should -Be 3
        }

        It "strategy has fail-fast = false" {
            $m = script:Get-MatrixFromOutput $script:parallelResult.Output
            $m.'fail-fast' | Should -Be $false
        }
    }

    # -----------------------------------------------------------------------
    # Test 7: Matrix exceeds configured max size → workflow fails
    # RED: expects act exit code != 0 and MATRIX_ERROR in output
    # GREEN: New-BuildMatrix throws when combination count > maxMatrixSize
    # -----------------------------------------------------------------------
    Context "Matrix size exceeds maximum (expects failure)" {
        BeforeAll {
            # 3 OS x 4 node x 2 experimental x 2 coverage = 48 > maxMatrixSize:10
            $script:maxSizeResult = script:Invoke-ActTest -TestName "exceeds-max-size" -Config @{
                os = @("ubuntu-latest", "windows-latest", "macos-latest")
                languageVersions = @{ node = @("16", "18", "20", "22") }
                featureFlags = @{
                    experimental = @($true, $false)
                    coverage     = @($true, $false)
                }
                maxMatrixSize = 10
            }
        }

        It "act exits with non-zero code" {
            $script:maxSizeResult.ExitCode | Should -Not -Be 0
        }

        It "output contains MATRIX_ERROR" {
            $script:maxSizeResult.Output | Should -Match "MATRIX_ERROR"
        }

        It "output mentions exceeds maximum" {
            $script:maxSizeResult.Output | Should -Match "exceeds maximum"
        }
    }
}
