<#
.SYNOPSIS
    Pester tests for the Environment Matrix Generator.
    All test cases execute through the GitHub Actions workflow via act.
    Workflow structure tests validate YAML, actionlint, and file references.
#>

BeforeAll {
    # Paths
    $script:ProjectDir = $PSScriptRoot
    $script:WorkflowPath = Join-Path $ProjectDir '.github' 'workflows' 'environment-matrix-generator.yml'
    $script:ActResultFile = Join-Path $ProjectDir 'act-result.txt'
    $script:ActImage = 'catthehacker/ubuntu:act-latest'

    # Clear previous results
    if (Test-Path $script:ActResultFile) {
        Remove-Item $script:ActResultFile -Force
    }

    # Helper: set up a temp git repo with project files, run act, return output
    function Invoke-ActRun {
        param(
            [string]$TestLabel
        )

        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-matrix-$TestLabel-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

        try {
            # Copy project files into temp repo
            Copy-Item -Path (Join-Path $script:ProjectDir '.github') -Destination $tmpDir -Recurse
            Copy-Item -Path (Join-Path $script:ProjectDir 'Generate-Matrix.ps1') -Destination $tmpDir
            Copy-Item -Path (Join-Path $script:ProjectDir 'fixtures') -Destination $tmpDir -Recurse

            # Init git repo (act requires it)
            Push-Location $tmpDir
            git init --initial-branch=main 2>&1 | Out-Null
            git add -A 2>&1 | Out-Null
            git commit -m "test setup for $TestLabel" 2>&1 | Out-Null

            # Run act
            $actOutput = & act push --rm -P "ubuntu-latest=$script:ActImage" 2>&1 | Out-String
            $actExitCode = $LASTEXITCODE

            Pop-Location
        }
        finally {
            # Clean up temp dir
            if (Test-Path $tmpDir) {
                Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        return @{
            Output   = $actOutput
            ExitCode = $actExitCode
            Label    = $TestLabel
        }
    }

    # Run act once for all test cases (they all run in the same workflow)
    $script:ActRun = Invoke-ActRun -TestLabel 'all-tests'

    # Write act output to result file (append with delimiters)
    $header = "===== ACT RUN: all-tests ====="
    $footer = "===== END ACT RUN: all-tests ====="
    "$header`n$($script:ActRun.Output)`n$footer`n" | Out-File -FilePath $script:ActResultFile -Encoding utf8 -Append
}

# --- Workflow Structure Tests ---
Describe 'Workflow Structure Tests' {

    It 'Workflow YAML file exists' {
        $script:WorkflowPath | Should -Exist
    }

    It 'Workflow YAML is valid and parseable' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Not -BeNullOrEmpty
        # PowerShell can parse YAML via ConvertFrom-Yaml if available, but we rely on actionlint
        $content | Should -Match 'name:'
        $content | Should -Match 'jobs:'
    }

    It 'Workflow has correct triggers (push, pull_request, workflow_dispatch)' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Match 'push:'
        $content | Should -Match 'pull_request:'
        $content | Should -Match 'workflow_dispatch:'
    }

    It 'Workflow has a generate-matrix job' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Match 'generate-matrix:'
    }

    It 'Workflow references Generate-Matrix.ps1 script' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Match 'Generate-Matrix\.ps1'
        # Verify the referenced script actually exists
        Join-Path $script:ProjectDir 'Generate-Matrix.ps1' | Should -Exist
    }

    It 'Workflow references fixture files that exist' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $fixtures = @('basic-matrix.json', 'with-exclude.json', 'with-include.json',
                      'feature-flags.json', 'single-dimension.json', 'too-large.json')
        foreach ($f in $fixtures) {
            $content | Should -Match $f
            Join-Path $script:ProjectDir 'fixtures' $f | Should -Exist
        }
    }

    It 'Workflow uses actions/checkout@v4' {
        $content = Get-Content -Path $script:WorkflowPath -Raw
        $content | Should -Match 'actions/checkout@v4'
    }

    It 'actionlint passes with exit code 0' {
        $result = & actionlint $script:WorkflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should pass: $result"
    }
}

# --- Act Execution Tests ---
Describe 'Act Pipeline Execution' {

    It 'act exited with code 0' {
        $script:ActRun.ExitCode | Should -Be 0 -Because "act should succeed. Output: $($script:ActRun.Output.Substring(0, [Math]::Min(500, $script:ActRun.Output.Length)))"
    }

    It 'Job succeeded message appears' {
        $script:ActRun.Output | Should -Match 'Job succeeded'
    }
}

# --- Basic Matrix Test ---
Describe 'Basic Matrix Generation (2 OS x 2 Node)' {

    It 'Produces output for basic-matrix test' {
        $script:ActRun.Output | Should -Match '=== TEST: basic-matrix ==='
        $script:ActRun.Output | Should -Match '=== END: basic-matrix ==='
    }

    It 'Contains exactly 4 total combinations' {
        $script:ActRun.Output | Should -Match '"totalCombinations":\s*4'
    }

    It 'Has fail-fast set to false' {
        # Match "fail-fast": false in the basic-matrix output section
        $script:ActRun.Output | Should -Match '"fail-fast":\s*false'
    }

    It 'Includes os dimension with ubuntu-latest and windows-latest' {
        $script:ActRun.Output | Should -Match '"ubuntu-latest"'
        $script:ActRun.Output | Should -Match '"windows-latest"'
    }

    It 'Includes node dimension with 18 and 20' {
        $script:ActRun.Output | Should -Match '"18"'
        $script:ActRun.Output | Should -Match '"20"'
    }
}

# --- Exclude Rules Test ---
Describe 'Matrix with Exclude Rules (3 OS x 3 Python - 2 excludes = 7)' {

    It 'Produces output for with-exclude test' {
        $script:ActRun.Output | Should -Match '=== TEST: with-exclude ==='
        $script:ActRun.Output | Should -Match '=== END: with-exclude ==='
    }

    It 'Contains exactly 7 total combinations after excludes' {
        $script:ActRun.Output | Should -Match '"totalCombinations":\s*7'
    }

    It 'Has fail-fast set to true' {
        $script:ActRun.Output | Should -Match '"fail-fast":\s*true'
    }

    It 'Has max-parallel set to 4' {
        $script:ActRun.Output | Should -Match '"max-parallel":\s*4'
    }

    It 'Contains exclude rules in output' {
        $script:ActRun.Output | Should -Match '"exclude"'
    }
}

# --- Include Rules Test ---
Describe 'Matrix with Include Rules (1 OS x 2 Node + includes = 3)' {

    It 'Produces output for with-include test' {
        $script:ActRun.Output | Should -Match '=== TEST: with-include ==='
        $script:ActRun.Output | Should -Match '=== END: with-include ==='
    }

    It 'Contains exactly 3 total combinations with includes' {
        $script:ActRun.Output | Should -Match '"totalCombinations":\s*3'
    }

    It 'Contains include rules in output' {
        $script:ActRun.Output | Should -Match '"include"'
    }

    It 'Include adds experimental flag' {
        $script:ActRun.Output | Should -Match '"experimental"'
    }

    It 'Include adds macos-latest as extra combination' {
        $script:ActRun.Output | Should -Match '"macos-latest"'
    }
}

# --- Feature Flags Test ---
Describe 'Feature Flags Matrix (1 OS x 2 Rust x 2 Feature = 4)' {

    It 'Produces output for feature-flags test' {
        $script:ActRun.Output | Should -Match '=== TEST: feature-flags ==='
        $script:ActRun.Output | Should -Match '=== END: feature-flags ==='
    }

    It 'Contains exactly 4 total combinations' {
        # This is the second occurrence of totalCombinations: 4, but it appears in the output
        # We extract the feature-flags section to verify
        $section = ($script:ActRun.Output -split '=== TEST: feature-flags ===' )[1]
        $section = ($section -split '=== END: feature-flags ===' )[0]
        $section | Should -Match '"totalCombinations":\s*4'
    }

    It 'Has fail-fast set to false' {
        $section = ($script:ActRun.Output -split '=== TEST: feature-flags ===' )[1]
        $section = ($section -split '=== END: feature-flags ===' )[0]
        $section | Should -Match '"fail-fast":\s*false'
    }

    It 'Has max-parallel set to 2' {
        $script:ActRun.Output | Should -Match '"max-parallel":\s*2'
    }

    It 'Contains rust dimension with stable and nightly' {
        $script:ActRun.Output | Should -Match '"stable"'
        $script:ActRun.Output | Should -Match '"nightly"'
    }

    It 'Contains feature dimension with default and experimental' {
        $script:ActRun.Output | Should -Match '"default"'
        $script:ActRun.Output | Should -Match '"experimental"'
    }
}

# --- Single Dimension Test ---
Describe 'Single Dimension Matrix (3 OS)' {

    It 'Produces output for single-dimension test' {
        $script:ActRun.Output | Should -Match '=== TEST: single-dimension ==='
        $script:ActRun.Output | Should -Match '=== END: single-dimension ==='
    }

    It 'Contains exactly 3 total combinations' {
        $section = ($script:ActRun.Output -split '=== TEST: single-dimension ===' )[1]
        $section = ($section -split '=== END: single-dimension ===' )[0]
        $section | Should -Match '"totalCombinations":\s*3'
    }

    It 'Has only os as dimension' {
        $section = ($script:ActRun.Output -split '=== TEST: single-dimension ===' )[1]
        $section = ($section -split '=== END: single-dimension ===' )[0]
        $section | Should -Match '"dimensions"'
        $section | Should -Match '"os"'
    }
}

# --- Error Handling: Too Large Matrix ---
Describe 'Too Large Matrix Error Handling' {

    It 'Produces output for too-large test' {
        $script:ActRun.Output | Should -Match '=== TEST: too-large ==='
        $script:ActRun.Output | Should -Match '=== END: too-large ==='
    }

    It 'Reports matrix size exceeds maximum' {
        $script:ActRun.Output | Should -Match 'Matrix size \(625\) exceeds maximum allowed \(100\)'
    }

    It 'Reports correct rejection' {
        $script:ActRun.Output | Should -Match 'PASS: Correctly rejected oversized matrix'
    }
}

# --- Error Handling: Missing File ---
Describe 'Missing File Error Handling' {

    It 'Produces output for missing-file test' {
        $script:ActRun.Output | Should -Match '=== TEST: missing-file ==='
        $script:ActRun.Output | Should -Match '=== END: missing-file ==='
    }

    It 'Reports configuration file not found' {
        $script:ActRun.Output | Should -Match 'Configuration file not found: nonexistent\.json'
    }

    It 'Reports correct rejection' {
        $script:ActRun.Output | Should -Match 'PASS: Correctly reported missing file'
    }
}

# --- Result File Test ---
Describe 'Act Result File' {

    It 'act-result.txt exists' {
        $script:ActResultFile | Should -Exist
    }

    It 'act-result.txt is not empty' {
        (Get-Content -Path $script:ActResultFile -Raw).Length | Should -BeGreaterThan 0
    }

    It 'act-result.txt contains act run output' {
        $content = Get-Content -Path $script:ActResultFile -Raw
        $content | Should -Match '===== ACT RUN: all-tests ====='
        $content | Should -Match '===== END ACT RUN: all-tests ====='
    }
}
