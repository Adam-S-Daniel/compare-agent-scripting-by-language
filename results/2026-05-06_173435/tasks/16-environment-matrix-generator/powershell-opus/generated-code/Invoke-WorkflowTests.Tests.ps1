# Outer test harness — validates workflow structure and runs act.
# This file runs OUTSIDE act; it orchestrates the act execution and parses results.

Describe 'Workflow Structure' {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/environment-matrix-generator.yml'
        $script:ProjectRoot = $PSScriptRoot

        # Parse YAML via Python (pyyaml) — returns a PowerShell object
        $jsonStr = Get-Content -Path $script:WorkflowPath -Raw |
            python3 -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))"
        $script:Workflow = $jsonStr | ConvertFrom-Json
    }

    It 'workflow file exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'has push trigger' {
        # YAML on: key parses as boolean True via pyyaml
        $triggers = $script:Workflow.true
        if (-not $triggers) { $triggers = $script:Workflow.on }
        $triggers.PSObject.Properties.Name | Should -Contain 'push'
    }

    It 'has pull_request trigger' {
        $triggers = $script:Workflow.true
        if (-not $triggers) { $triggers = $script:Workflow.on }
        $triggers.PSObject.Properties.Name | Should -Contain 'pull_request'
    }

    It 'has workflow_dispatch trigger' {
        $triggers = $script:Workflow.true
        if (-not $triggers) { $triggers = $script:Workflow.on }
        $triggers.PSObject.Properties.Name | Should -Contain 'workflow_dispatch'
    }

    It 'has test-and-generate job' {
        $script:Workflow.jobs.PSObject.Properties.Name | Should -Contain 'test-and-generate'
    }

    It 'job runs on ubuntu-latest' {
        $script:Workflow.jobs.'test-and-generate'.'runs-on' | Should -Be 'ubuntu-latest'
    }

    It 'first step is actions/checkout@v4' {
        $steps = @($script:Workflow.jobs.'test-and-generate'.steps)
        $steps[0].uses | Should -Be 'actions/checkout@v4'
    }

    It 'has at least 5 steps (checkout + pester + 3 demos + validation)' {
        $steps = @($script:Workflow.jobs.'test-and-generate'.steps)
        $steps.Count | Should -BeGreaterOrEqual 5
    }

    It 'references New-EnvironmentMatrix.ps1 in workflow steps' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Match 'New-EnvironmentMatrix\.ps1'
    }

    It 'references New-EnvironmentMatrix.Tests.ps1 in workflow steps' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Match 'New-EnvironmentMatrix\.Tests\.ps1'
    }

    It 'script file exists on disk' {
        Test-Path (Join-Path $script:ProjectRoot 'New-EnvironmentMatrix.ps1') | Should -BeTrue
    }

    It 'test file exists on disk' {
        Test-Path (Join-Path $script:ProjectRoot 'New-EnvironmentMatrix.Tests.ps1') | Should -BeTrue
    }

    It 'fixtures directory exists' {
        Test-Path (Join-Path $script:ProjectRoot 'fixtures') | Should -BeTrue
    }

    It 'actionlint passes with exit code 0' {
        actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Act Execution' {
    BeforeAll {
        $script:ProjectRoot = $PSScriptRoot
        $script:ActResultFile = Join-Path $script:ProjectRoot 'act-result.txt'

        # Create isolated temp repo
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "matrix-gen-act-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Copy project files
        foreach ($item in @(
            'New-EnvironmentMatrix.ps1',
            'New-EnvironmentMatrix.Tests.ps1',
            '.actrc'
        )) {
            $src = Join-Path $script:ProjectRoot $item
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination (Join-Path $tempDir $item)
            }
        }
        Copy-Item -Path (Join-Path $script:ProjectRoot 'fixtures') -Destination (Join-Path $tempDir 'fixtures') -Recurse
        Copy-Item -Path (Join-Path $script:ProjectRoot '.github') -Destination (Join-Path $tempDir '.github') -Recurse

        # Init git repo inside temp dir
        Push-Location $tempDir
        git init --quiet 2>&1 | Out-Null
        git config user.email 'test@test.com'
        git config user.name 'Test'
        git add -A
        git commit --quiet -m 'test' 2>&1 | Out-Null

        # Run act — single invocation covers all test cases
        $script:ActOutput = & act push --rm --pull=false 2>&1 | Out-String
        $script:ActExitCode = $LASTEXITCODE

        Pop-Location

        # Write act output to required artifact file (append-friendly delimiters)
        $header = "===ACT RUN $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')==="
        "$header`n$($script:ActOutput)" | Set-Content -Path $script:ActResultFile -Force

        # Clean up temp dir
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

        # Helper: extract text between markers from act output (strips act line prefixes)
        function script:Get-MarkerContent {
            param([string]$StartMarker, [string]$EndMarker)
            $lines = $script:ActOutput -split "`n"
            $collecting = $false
            $collected = @()
            foreach ($line in $lines) {
                # Strip act prefix: [job/step]   | content
                $clean = ($line -replace '^\[.*?\]\s+\|\s?', '').TrimEnd()
                if ($clean -match [regex]::Escape($StartMarker)) {
                    $collecting = $true
                    continue
                }
                if ($clean -match [regex]::Escape($EndMarker)) {
                    $collecting = $false
                    continue
                }
                if ($collecting) { $collected += $clean }
            }
            return ($collected -join "`n")
        }
    }

    It 'act exits with code 0' {
        $script:ActExitCode | Should -Be 0
    }

    It 'act-result.txt exists' {
        Test-Path $script:ActResultFile | Should -BeTrue
    }

    It 'output contains Job succeeded' {
        $script:ActOutput | Should -Match 'Job succeeded'
    }

    It 'all 30 Pester tests passed' {
        $script:ActOutput | Should -Match 'PESTER_PASSED=30'
    }

    It 'zero Pester tests failed' {
        $script:ActOutput | Should -Match 'PESTER_FAILED=0'
    }

    Context 'Basic matrix output' {
        BeforeAll {
            $json = Get-MarkerContent '===BASIC_MATRIX_START===' '===BASIC_MATRIX_END==='
            $script:BasicMatrix = $json | ConvertFrom-Json
        }

        It 'has os dimension with ubuntu-latest and windows-latest' {
            $script:BasicMatrix.matrix.os | Should -Be @('ubuntu-latest', 'windows-latest')
        }

        It 'has node dimension with 18 and 20' {
            $script:BasicMatrix.matrix.node | Should -Be @('18', '20')
        }

        It 'fail-fast is false' {
            $script:BasicMatrix.'fail-fast' | Should -BeFalse
        }

        It 'max-parallel is 2' {
            $script:BasicMatrix.'max-parallel' | Should -Be 2
        }

        It 'effective-size is exactly 4' {
            $script:BasicMatrix.'effective-size' | Should -Be 4
        }
    }

    Context 'Include-exclude matrix output' {
        BeforeAll {
            $json = Get-MarkerContent '===INCLUDE_EXCLUDE_MATRIX_START===' '===INCLUDE_EXCLUDE_MATRIX_END==='
            $script:IEMatrix = $json | ConvertFrom-Json
        }

        It 'has 3 OS values' {
            $script:IEMatrix.matrix.os | Should -HaveCount 3
        }

        It 'has 3 python versions' {
            $script:IEMatrix.matrix.python | Should -HaveCount 3
        }

        It 'has exactly 1 include rule' {
            $script:IEMatrix.matrix.include | Should -HaveCount 1
        }

        It 'include rule sets experimental to true' {
            $script:IEMatrix.matrix.include[0].experimental | Should -BeTrue
        }

        It 'has exactly 1 exclude rule' {
            $script:IEMatrix.matrix.exclude | Should -HaveCount 1
        }

        It 'fail-fast is true' {
            $script:IEMatrix.'fail-fast' | Should -BeTrue
        }

        It 'effective-size is exactly 8' {
            $script:IEMatrix.'effective-size' | Should -Be 8
        }
    }

    Context 'Feature-flags matrix output' {
        BeforeAll {
            $json = Get-MarkerContent '===FEATURE_FLAGS_MATRIX_START===' '===FEATURE_FLAGS_MATRIX_END==='
            $script:FFMatrix = $json | ConvertFrom-Json
        }

        It 'has features dimension with 3 values' {
            $script:FFMatrix.matrix.features | Should -Be @('default', 'experimental', 'legacy')
        }

        It 'include adds windows-latest as new combo' {
            $script:FFMatrix.matrix.include[0].os | Should -Be 'windows-latest'
        }

        It 'effective-size is exactly 7' {
            $script:FFMatrix.'effective-size' | Should -Be 7
        }
    }

    Context 'Oversized matrix validation' {
        It 'output confirms oversized matrix was rejected' {
            $script:ActOutput | Should -Match '===OVERSIZED_VALIDATED==='
        }

        It 'error message mentions size 96 exceeding max 10' {
            $script:ActOutput | Should -Match '96.*exceeds maximum.*10'
        }
    }
}
