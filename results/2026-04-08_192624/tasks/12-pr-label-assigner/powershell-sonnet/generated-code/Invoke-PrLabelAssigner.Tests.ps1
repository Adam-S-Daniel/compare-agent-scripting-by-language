# PR Label Assigner - Pester Test Suite
# TDD approach: tests written first, implementation follows
#
# Test Coverage:
#   1. Glob pattern conversion and matching
#   2. Core label assignment (Get-PrLabels)
#   3. Multiple labels per file (file matches multiple rules)
#   4. Priority ordering (higher priority labels appear first)
#   5. Edge cases (empty inputs, no matches, Windows paths)
#   6. Workflow structure validation
#   7. Actionlint validation
#   8. Act execution tests (end-to-end via Docker)
#
# Pester 5 scoping notes:
#   - BeforeDiscovery: runs at discovery time; variables available in Describe body foreach loops
#   - BeforeAll: runs at run time before any It; $script: vars shared with It blocks
#   - Variables defined outside Describe are NOT accessible in BeforeAll
#   - Use BeforeDiscovery for test-generation data; BeforeAll for run-time setup

BeforeAll {
    # Import the implementation - will fail until file exists (RED phase)
    $scriptPath = Join-Path $PSScriptRoot "Invoke-PrLabelAssigner.ps1"
    . $scriptPath
}

# ============================================================
# UNIT TESTS - Label Assignment Logic
# ============================================================

Describe "ConvertTo-GlobRegex" {
    # TDD Iteration 1: glob pattern conversion

    It "converts a simple wildcard to regex" {
        $regex = ConvertTo-GlobRegex -Pattern "*.md"
        $regex | Should -Not -BeNullOrEmpty
        "README.md" | Should -Match $regex
        "docs/README.md" | Should -Not -Match $regex
    }

    It "converts double-star to match any path depth" {
        $regex = ConvertTo-GlobRegex -Pattern "docs/**"
        "docs/README.md" | Should -Match $regex
        "docs/sub/dir/file.md" | Should -Match $regex
        "src/README.md" | Should -Not -Match $regex
    }

    It "converts ? to single character match" {
        $regex = ConvertTo-GlobRegex -Pattern "src/?.ts"
        "src/a.ts" | Should -Match $regex
        "src/ab.ts" | Should -Not -Match $regex
    }

    It "escapes literal dots" {
        $regex = ConvertTo-GlobRegex -Pattern "*.test.js"
        "foo.test.js" | Should -Match $regex
        "footestjs" | Should -Not -Match $regex
    }
}

Describe "Test-GlobMatch" {
    # TDD Iteration 2: file path matching

    It "matches docs files with docs/** pattern" {
        Test-GlobMatch -Path "docs/README.md" -Pattern "docs/**" | Should -BeTrue
    }

    It "matches nested docs files with docs/** pattern" {
        Test-GlobMatch -Path "docs/guides/getting-started.md" -Pattern "docs/**" | Should -BeTrue
    }

    It "does not match non-docs files with docs/** pattern" {
        Test-GlobMatch -Path "src/main.js" -Pattern "docs/**" | Should -BeFalse
    }

    It "matches API files with src/api/** pattern" {
        Test-GlobMatch -Path "src/api/server.js" -Pattern "src/api/**" | Should -BeTrue
        Test-GlobMatch -Path "src/api/v2/routes.js" -Pattern "src/api/**" | Should -BeTrue
    }

    It "does not match non-API src files with src/api/** pattern" {
        Test-GlobMatch -Path "src/utils/helper.js" -Pattern "src/api/**" | Should -BeFalse
    }

    It "matches test files with *.test.* pattern at root" {
        Test-GlobMatch -Path "app.test.js" -Pattern "*.test.*" | Should -BeTrue
    }

    It "does not match test files in subdirectories with bare *.test.* pattern" {
        # * does NOT match path separators
        Test-GlobMatch -Path "src/app.test.js" -Pattern "*.test.*" | Should -BeFalse
    }

    It "matches test files anywhere with **/*.test.* pattern" {
        Test-GlobMatch -Path "src/app.test.js" -Pattern "**/*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "tests/unit/foo.test.ts" -Pattern "**/*.test.*" | Should -BeTrue
    }

    It "matches exact paths" {
        Test-GlobMatch -Path "package.json" -Pattern "package.json" | Should -BeTrue
        Test-GlobMatch -Path "other.json" -Pattern "package.json" | Should -BeFalse
    }
}

Describe "Get-PrLabels" {
    # TDD Iteration 3: core label assignment function

    BeforeAll {
        $script:DefaultRules = @(
            @{ Pattern = "docs/**"; Label = "documentation"; Priority = 10 }
            @{ Pattern = "src/api/**"; Label = "api"; Priority = 20 }
            @{ Pattern = "**/*.test.*"; Label = "tests"; Priority = 15 }
            @{ Pattern = "src/**"; Label = "backend"; Priority = 5 }
            @{ Pattern = "*.md"; Label = "documentation"; Priority = 8 }
        )
    }

    It "returns empty array for empty file list" {
        $result = Get-PrLabels -Files @() -Rules $script:DefaultRules
        $result | Should -BeNullOrEmpty
    }

    It "returns empty array when no rules match" {
        $result = Get-PrLabels -Files @("completely/random/path.xyz") -Rules $script:DefaultRules
        $result | Should -BeNullOrEmpty
    }

    It "returns documentation label for docs files" {
        $result = Get-PrLabels -Files @("docs/README.md") -Rules $script:DefaultRules
        $result | Should -Contain "documentation"
    }

    It "returns api label for src/api files" {
        $result = Get-PrLabels -Files @("src/api/server.js") -Rules $script:DefaultRules
        $result | Should -Contain "api"
    }

    It "returns tests label for test files" {
        $result = Get-PrLabels -Files @("src/app.test.js") -Rules $script:DefaultRules
        $result | Should -Contain "tests"
    }

    It "returns multiple labels when multiple rules match different files" {
        $result = Get-PrLabels -Files @("docs/README.md", "src/api/server.js") -Rules $script:DefaultRules
        $result | Should -Contain "documentation"
        $result | Should -Contain "api"
    }

    It "returns multiple labels when a single file matches multiple rules" {
        # src/api/server.test.js matches: src/api/** (api), **/*.test.* (tests), src/** (backend)
        $result = Get-PrLabels -Files @("src/api/server.test.js") -Rules $script:DefaultRules
        $result | Should -Contain "api"
        $result | Should -Contain "tests"
        $result | Should -Contain "backend"
    }

    It "deduplicates labels when multiple files match the same rule" {
        $result = Get-PrLabels -Files @("docs/README.md", "docs/guide.md") -Rules $script:DefaultRules
        ($result | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
    }

    It "orders labels by priority (highest priority first)" {
        # api (20) > tests (15) > documentation (10) > backend (5)
        $result = Get-PrLabels -Files @("src/api/server.test.js", "docs/README.md") -Rules $script:DefaultRules

        $apiIdx    = [Array]::IndexOf($result, "api")
        $testsIdx  = [Array]::IndexOf($result, "tests")
        $docsIdx   = [Array]::IndexOf($result, "documentation")
        $backendIdx = [Array]::IndexOf($result, "backend")

        $apiIdx    | Should -BeLessThan $testsIdx
        $testsIdx  | Should -BeLessThan $docsIdx
        $docsIdx   | Should -BeLessThan $backendIdx
    }

    It "handles rules with no priority field (defaults to 0)" {
        $rules = @(@{ Pattern = "src/**"; Label = "code" })
        $result = Get-PrLabels -Files @("src/main.ps1") -Rules $rules
        $result | Should -Contain "code"
    }

    It "returns results as an array" {
        $result = Get-PrLabels -Files @("src/main.js") -Rules $script:DefaultRules
        $result | Should -Not -BeNullOrEmpty
        @($result).GetType().IsArray | Should -BeTrue
    }
}

Describe "Get-PrLabels - Priority Conflict Resolution" {
    # TDD Iteration 4: priority conflict tests

    It "deduplicates label when same label matched by multiple rules" {
        $rules = @(
            @{ Pattern = "src/**"; Label = "backend"; Priority = 5 }
            @{ Pattern = "src/core/**"; Label = "backend"; Priority = 50 }
        )
        $result = Get-PrLabels -Files @("src/core/engine.js") -Rules $rules
        ($result | Where-Object { $_ -eq "backend" }).Count | Should -Be 1
        $result | Should -Contain "backend"
    }

    It "alphabetical tiebreak when priorities are equal" {
        $rules = @(
            @{ Pattern = "src/**"; Label = "backend"; Priority = 10 }
            @{ Pattern = "src/**"; Label = "code"; Priority = 10 }
        )
        $result = Get-PrLabels -Files @("src/main.js") -Rules $rules
        $result | Should -Contain "backend"
        $result | Should -Contain "code"
        [Array]::IndexOf($result, "backend") | Should -BeLessThan ([Array]::IndexOf($result, "code"))
    }
}

Describe "Get-PrLabels - Edge Cases" {
    # TDD Iteration 5: edge cases

    It "handles null files parameter gracefully" {
        { Get-PrLabels -Files $null -Rules @(@{ Pattern = "src/**"; Label = "code"; Priority = 1 }) } | Should -Not -Throw
    }

    It "handles null rules parameter gracefully" {
        { Get-PrLabels -Files @("src/main.js") -Rules $null } | Should -Not -Throw
    }

    It "handles empty rules array" {
        $result = Get-PrLabels -Files @("src/main.js") -Rules @()
        $result | Should -BeNullOrEmpty
    }

    It "handles Windows-style path separators" {
        $rules = @(@{ Pattern = "src/**"; Label = "backend"; Priority = 10 })
        $result = Get-PrLabels -Files @("src\main.js") -Rules $rules
        $result | Should -Contain "backend"
    }
}

# ============================================================
# WORKFLOW STRUCTURE TESTS
# ============================================================

Describe "GitHub Actions Workflow Structure" {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot ".github/workflows/pr-label-assigner.yml"
        $script:WorkflowContent = if (Test-Path $script:WorkflowPath) {
            Get-Content $script:WorkflowPath -Raw
        } else { $null }
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "workflow YAML is valid (parseable)" {
        $script:WorkflowContent | Should -Not -BeNullOrEmpty
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "workflow has at least one job" {
        $script:WorkflowContent | Should -Match "jobs:"
    }

    It "workflow uses actions/checkout@v4" {
        $script:WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "workflow references the script file" {
        $script:WorkflowContent | Should -Match "Invoke-PrLabelAssigner"
    }

    It "script file referenced in workflow actually exists" {
        Test-Path (Join-Path $PSScriptRoot "Invoke-PrLabelAssigner.ps1") | Should -BeTrue
    }

    It "passes actionlint validation" {
        $actionlintCmd = Get-Command "actionlint" -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            Set-ItResult -Skipped -Because "actionlint not installed"
            return
        }
        $result = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $result"
    }
}

# ============================================================
# ACT EXECUTION TESTS (End-to-end via Docker)
# ============================================================
#
# Pester 5 scoping pattern used here:
#   BeforeDiscovery  -> populates $script:ActCases for foreach test generation
#   BeforeAll        -> re-defines test cases locally, runs act, caches results
#   It blocks        -> read from $script:ActResultCache

BeforeDiscovery {
    # Test case definitions for dynamic It generation.
    # Must be in BeforeDiscovery so they are available during the Discovery phase
    # when Pester evaluates the foreach loops inside Describe.
    $script:ActCases = @(
        @{
            Name           = "docs-only"
            Description    = "Documentation files get documentation label"
            ChangedFiles   = @("docs/README.md", "docs/guide.md")
            ExpectedLabels = @("documentation")
            NotExpected    = @("api", "tests")
        },
        @{
            Name           = "api-files"
            Description    = "API source files get api and backend labels"
            ChangedFiles   = @("src/api/server.js", "src/api/routes.js")
            ExpectedLabels = @("api", "backend")
            NotExpected    = @("documentation", "tests")
        },
        @{
            Name           = "test-files"
            Description    = "Test files get tests and backend labels"
            ChangedFiles   = @("src/app.test.js", "src/utils.test.ts")
            ExpectedLabels = @("tests", "backend")
            NotExpected    = @("documentation", "api")
        },
        @{
            Name           = "mixed-changes"
            Description    = "Mixed PR gets multiple labels"
            ChangedFiles   = @("docs/README.md", "src/api/server.js", "src/api/server.test.js")
            ExpectedLabels = @("api", "tests", "documentation", "backend")
            NotExpected    = @()
        },
        @{
            Name           = "no-matches"
            Description    = "Unmatched files produce no labels"
            ChangedFiles   = @("random/unknown/file.xyz")
            ExpectedLabels = @()
            NotExpected    = @("documentation", "api", "tests", "backend")
        }
    )
}

Describe "Act Execution Tests" {
    BeforeAll {
        $script:ActPath = (Get-Command "act" -ErrorAction SilentlyContinue)?.Source
        $script:ActResultFile = Join-Path $PSScriptRoot "act-result.txt"
        $script:ActResultCache = @{}

        # Ensure act-result.txt exists as required artifact
        if (Test-Path $script:ActResultFile) { Remove-Item $script:ActResultFile -Force }
        New-Item -ItemType File -Path $script:ActResultFile -Force | Out-Null

        # Run one test case through act, return result hashtable {ExitCode, Output}
        function Invoke-ActTestCase {
            param([hashtable]$TestCase)

            $projectRoot = $PSScriptRoot
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pla-$($TestCase.Name)-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                # Copy project files into isolated temp directory
                # Note: Use Test-Path -PathType Container (not Get-Item) to check for directories,
                # because Get-Item can fail for dotfile directories (e.g. .github) on Linux.
                foreach ($item in @("Invoke-PrLabelAssigner.ps1", "label-rules.json", ".github")) {
                    $src = Join-Path $projectRoot $item
                    if (Test-Path $src -PathType Container) {
                        Copy-Item -Recurse -Path $src -Destination $tempDir
                    } elseif (Test-Path $src) {
                        Copy-Item -Path $src -Destination $tempDir
                    }
                }

                # Write fixture: changed-files.json
                $TestCase.ChangedFiles | ConvertTo-Json | Set-Content (Join-Path $tempDir "changed-files.json")

                # Initialize git repo (act push event requires a git repo)
                Push-Location $tempDir
                & git init -b main 2>&1 | Out-Null
                & git config user.email "test@example.com" 2>&1 | Out-Null
                & git config user.name "Test Runner" 2>&1 | Out-Null
                & git add -A 2>&1 | Out-Null
                & git commit -m "test: $($TestCase.Name)" 2>&1 | Out-Null
                Pop-Location

                # Run act - capture combined stdout+stderr
                $actOutput = & act push --rm `
                    --directory $tempDir `
                    -W "$tempDir/.github/workflows/pr-label-assigner.yml" `
                    --no-cache-server `
                    2>&1 | Out-String
                $actExitCode = $LASTEXITCODE

                # Append to act-result.txt with clear delimiters
                $bar = "=" * 60
                Add-Content -Path $script:ActResultFile -Value @"

$bar
TEST CASE: $($TestCase.Name)
DESCRIPTION: $($TestCase.Description)
CHANGED FILES: $($TestCase.ChangedFiles -join ', ')
$bar
$actOutput
EXIT CODE: $actExitCode
$bar

"@
                return @{ ExitCode = $actExitCode; Output = $actOutput }

            } finally {
                Pop-Location -ErrorAction SilentlyContinue
                if ($tempDir -and (Test-Path $tempDir)) {
                    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
                }
            }
        }

        # Re-define test cases here (BeforeAll cannot access BeforeDiscovery variables)
        # These must match $script:ActCases defined in BeforeDiscovery.
        $runCases = @(
            @{ Name = "docs-only";     ChangedFiles = @("docs/README.md", "docs/guide.md"); Description = "Documentation files" }
            @{ Name = "api-files";     ChangedFiles = @("src/api/server.js", "src/api/routes.js"); Description = "API source files" }
            @{ Name = "test-files";    ChangedFiles = @("src/app.test.js", "src/utils.test.ts"); Description = "Test files" }
            @{ Name = "mixed-changes"; ChangedFiles = @("docs/README.md", "src/api/server.js", "src/api/server.test.js"); Description = "Mixed PR changes" }
            @{ Name = "no-matches";    ChangedFiles = @("random/unknown/file.xyz"); Description = "Unmatched files" }
        )

        if ($script:ActPath) {
            foreach ($tc in $runCases) {
                Write-Host "  [act] Running: $($tc.Name) ..."
                $script:ActResultCache[$tc.Name] = Invoke-ActTestCase -TestCase $tc
                Write-Host "  [act] Done: $($tc.Name) (exit=$($script:ActResultCache[$tc.Name].ExitCode))"
            }
        } else {
            Write-Warning "act binary not found - Act Execution Tests will be skipped"
        }
    }

    It "act binary is available" {
        $script:ActPath | Should -Not -BeNullOrEmpty -Because "act must be installed"
    }

    # Dynamic test generation using $script:ActCases from BeforeDiscovery
    foreach ($tc in $script:ActCases) {
        It "act: $($tc.Name) - exits with code 0" -TestCases @{ tcName = $tc.Name } {
            param($tcName)
            if (-not $script:ActPath) { Set-ItResult -Skipped -Because "act not installed"; return }
            $r = $script:ActResultCache[$tcName]
            $r | Should -Not -BeNullOrEmpty -Because "result for '$tcName' must be cached"
            $r.ExitCode | Should -Be 0 -Because "act exit code for '$tcName'. Output:`n$($r.Output)"
        }

        It "act: $($tc.Name) - job succeeded" -TestCases @{ tcName = $tc.Name } {
            param($tcName)
            if (-not $script:ActPath) { Set-ItResult -Skipped -Because "act not installed"; return }
            $r = $script:ActResultCache[$tcName]
            $r.Output | Should -Match "Job succeeded" -Because "job must succeed for '$tcName'"
        }

        foreach ($expectedLabel in $tc.ExpectedLabels) {
            It "act: $($tc.Name) - contains label '$expectedLabel'" `
                -TestCases @{ tcName = $tc.Name; lbl = $expectedLabel } {
                param($tcName, $lbl)
                if (-not $script:ActPath) { Set-ItResult -Skipped -Because "act not installed"; return }
                $r = $script:ActResultCache[$tcName]
                $r.Output | Should -Match "LABEL: $lbl" -Because "output for '$tcName' should contain label '$lbl'"
            }
        }

        foreach ($notExpected in $tc.NotExpected) {
            It "act: $($tc.Name) - does NOT contain label '$notExpected'" `
                -TestCases @{ tcName = $tc.Name; lbl = $notExpected } {
                param($tcName, $lbl)
                if (-not $script:ActPath) { Set-ItResult -Skipped -Because "act not installed"; return }
                $r = $script:ActResultCache[$tcName]
                $r.Output | Should -Not -Match "LABEL: $lbl" -Because "output for '$tcName' should NOT have label '$lbl'"
            }
        }
    }

    It "act-result.txt file exists" {
        Test-Path $script:ActResultFile | Should -BeTrue -Because "act-result.txt is a required artifact"
    }
}
