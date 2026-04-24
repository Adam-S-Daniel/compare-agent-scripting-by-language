# PR Label Assigner - Pester Test Suite
# TDD progression: each Describe/Context was written before its implementation.
# Round 1: glob regex for docs/** pattern (RED -> GREEN)
# Round 2: glob regex for **/*.test.* pattern
# Round 3: glob regex for no-slash patterns (*.md -> match any depth)
# Round 4: Get-PRLabels basic label assignment
# Round 5: multiple labels and deduplication
# Round 6: priority ordering
# Round 7: error handling
# Round 8: workflow structure + actionlint
# Round 9: act integration (runs act, produces act-result.txt)

BeforeAll {
    # Dot-source the implementation to import functions for testing
    . "$PSScriptRoot/Invoke-PRLabelAssigner.ps1"
}

# ─── Round 1-3: Glob pattern matching ────────────────────────────────────────

Describe "Convert-GlobToRegex" {

    Context "double-star (docs/**) patterns" {

        It "matches docs/** against docs/readme.md" {
            # First failing test - written before Convert-GlobToRegex existed
            $regex = Convert-GlobToRegex "docs/**"
            "docs/readme.md" | Should -Match $regex
        }

        It "matches docs/** against nested docs/api/v1/spec.md" {
            $regex = Convert-GlobToRegex "docs/**"
            "docs/api/v1/spec.md" | Should -Match $regex
        }

        It "does not match docs/** against docs_extra/readme.md" {
            $regex = Convert-GlobToRegex "docs/**"
            "docs_extra/readme.md" | Should -Not -Match $regex
        }

        It "matches src/api/** against src/api/users.ts" {
            $regex = Convert-GlobToRegex "src/api/**"
            "src/api/users.ts" | Should -Match $regex
        }

        It "does not match src/api/** against src/components/Button.tsx" {
            $regex = Convert-GlobToRegex "src/api/**"
            "src/components/Button.tsx" | Should -Not -Match $regex
        }
    }

    Context "double-star-slash (**/*.test.*) patterns" {

        It "matches **/*.test.* against users.test.ts (no directory)" {
            $regex = Convert-GlobToRegex "**/*.test.*"
            "users.test.ts" | Should -Match $regex
        }

        It "matches **/*.test.* against src/api/users.test.ts (with directory)" {
            $regex = Convert-GlobToRegex "**/*.test.*"
            "src/api/users.test.ts" | Should -Match $regex
        }

        It "matches **/*.test.* against test/unit.test.js" {
            $regex = Convert-GlobToRegex "**/*.test.*"
            "test/unit.test.js" | Should -Match $regex
        }

        It "does not match **/*.test.* against users.ts (no .test. in name)" {
            $regex = Convert-GlobToRegex "**/*.test.*"
            "users.ts" | Should -Not -Match $regex
        }

        It "matches **/*.spec.* against src/Button.spec.tsx" {
            $regex = Convert-GlobToRegex "**/*.spec.*"
            "src/Button.spec.tsx" | Should -Match $regex
        }
    }

    Context "no-slash patterns (*.md) — match at any depth" {

        It "matches *.md against readme.md (root level)" {
            $regex = Convert-GlobToRegex "*.md"
            "readme.md" | Should -Match $regex
        }

        It "matches *.md against docs/readme.md (nested)" {
            $regex = Convert-GlobToRegex "*.md"
            "docs/readme.md" | Should -Match $regex
        }

        It "matches *.md against docs/api/reference.md (deeply nested)" {
            $regex = Convert-GlobToRegex "*.md"
            "docs/api/reference.md" | Should -Match $regex
        }

        It "does not match *.md against readme.ts" {
            $regex = Convert-GlobToRegex "*.md"
            "readme.ts" | Should -Not -Match $regex
        }
    }

    Context "question mark patterns" {

        It "matches src/?.ts against src/a.ts" {
            $regex = Convert-GlobToRegex "src/?.ts"
            "src/a.ts" | Should -Match $regex
        }

        It "does not match src/?.ts against src/ab.ts (? is one char only)" {
            $regex = Convert-GlobToRegex "src/?.ts"
            "src/ab.ts" | Should -Not -Match $regex
        }
    }
}

# ─── Round 4-6: Label assignment logic ───────────────────────────────────────

Describe "Get-PRLabels" {

    BeforeAll {
        # Config object used for unit tests (no file I/O needed)
        $script:TestConfig = [PSCustomObject]@{
            rules = @(
                [PSCustomObject]@{ pattern = "docs/**";      label = "documentation"; priority = 10 },
                [PSCustomObject]@{ pattern = "**/*.md";      label = "documentation"; priority = 15 },
                [PSCustomObject]@{ pattern = "src/api/**";   label = "api";           priority = 20 },
                [PSCustomObject]@{ pattern = "**/*.test.*";  label = "tests";         priority = 30 },
                [PSCustomObject]@{ pattern = "**/*.spec.*";  label = "tests";         priority = 30 },
                [PSCustomObject]@{ pattern = ".github/**";   label = "ci/cd";         priority = 40 }
            )
        }
    }

    It "assigns documentation label to a docs file" {
        $labels = Get-PRLabels -ChangedFiles @("docs/README.md") -Config $script:TestConfig
        $labels | Should -Contain "documentation"
    }

    It "assigns api label to a src/api file" {
        $labels = Get-PRLabels -ChangedFiles @("src/api/users.ts") -Config $script:TestConfig
        $labels | Should -Contain "api"
    }

    It "assigns tests label to a .test. file" {
        $labels = Get-PRLabels -ChangedFiles @("src/api/users.test.ts") -Config $script:TestConfig
        $labels | Should -Contain "tests"
    }

    It "assigns multiple labels when a file matches multiple rules (api + tests)" {
        $labels = Get-PRLabels -ChangedFiles @("src/api/users.test.ts") -Config $script:TestConfig
        $labels | Should -Contain "api"
        $labels | Should -Contain "tests"
    }

    It "deduplicates labels — docs/README.md matches docs/** and **/*.md but gives one 'documentation' label" {
        $labels = Get-PRLabels -ChangedFiles @("docs/README.md") -Config $script:TestConfig
        ($labels | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
    }

    It "accumulates labels across multiple files" {
        $files = @("docs/README.md", "src/api/users.ts", "test/unit.test.js")
        $labels = Get-PRLabels -ChangedFiles $files -Config $script:TestConfig
        $labels | Should -Contain "documentation"
        $labels | Should -Contain "api"
        $labels | Should -Contain "tests"
    }

    It "returns labels sorted alphabetically" {
        $files = @("docs/README.md", "src/api/users.ts", "test/unit.test.js")
        $labels = Get-PRLabels -ChangedFiles $files -Config $script:TestConfig
        $sorted = $labels | Sort-Object
        $labels | Should -Be $sorted
    }

    It "returns empty array when no files match any rule" {
        $labels = Get-PRLabels -ChangedFiles @("random/unknown.xyz") -Config $script:TestConfig
        $labels | Should -BeNullOrEmpty
    }

    It "returns empty array for an empty file list" {
        $labels = Get-PRLabels -ChangedFiles @() -Config $script:TestConfig
        $labels | Should -BeNullOrEmpty
    }

    It "assigns ci/cd label to .github files" {
        $labels = Get-PRLabels -ChangedFiles @(".github/workflows/ci.yml") -Config $script:TestConfig
        $labels | Should -Contain "ci/cd"
    }

    # Round 7: error handling
    It "throws a meaningful error when ConfigPath is missing and Config is null" {
        { Get-PRLabels -ChangedFiles @("readme.md") -ConfigPath "" } |
            Should -Throw -ExpectedMessage "*Either ConfigPath or Config must be provided*"
    }

    It "throws a meaningful error when config file does not exist" {
        { Get-PRLabels -ChangedFiles @("readme.md") -ConfigPath "nonexistent.json" } |
            Should -Throw -ExpectedMessage "*Config file not found*"
    }

    It "loads config from a JSON file on disk" {
        $labels = Get-PRLabels -ChangedFiles @("docs/README.md") -ConfigPath "$PSScriptRoot/config.json"
        $labels | Should -Contain "documentation"
    }
}

# ─── Round 8: Workflow structure + actionlint ─────────────────────────────────

Describe "Workflow Structure Tests" {

    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/pr-label-assigner.yml"
        $script:WorkflowContent = $null
        if (Test-Path $script:WorkflowPath) {
            $script:WorkflowContent = Get-Content $script:WorkflowPath -Raw
        }
    }

    It "workflow file exists at .github/workflows/pr-label-assigner.yml" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "workflow has pull_request trigger" {
        $script:WorkflowContent | Should -Match "pull_request:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "workflow references Invoke-PRLabelAssigner.ps1" {
        $script:WorkflowContent | Should -Match "Invoke-PRLabelAssigner\.ps1"
    }

    It "workflow references config.json" {
        $script:WorkflowContent | Should -Match "config\.json"
    }

    It "workflow uses shell: pwsh for run steps" {
        $script:WorkflowContent | Should -Match "shell:\s*pwsh"
    }

    It "Invoke-PRLabelAssigner.ps1 script file exists" {
        Test-Path "$PSScriptRoot/Invoke-PRLabelAssigner.ps1" | Should -Be $true
    }

    It "config.json file exists" {
        Test-Path "$PSScriptRoot/config.json" | Should -Be $true
    }

    It "fixture files exist (fixture-1.json through fixture-4.json)" {
        Test-Path "$PSScriptRoot/fixture-1.json" | Should -Be $true
        Test-Path "$PSScriptRoot/fixture-2.json" | Should -Be $true
        Test-Path "$PSScriptRoot/fixture-3.json" | Should -Be $true
        Test-Path "$PSScriptRoot/fixture-4.json" | Should -Be $true
    }

    It "passes actionlint validation (exit code 0)" {
        $actionlintCmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            Set-ItResult -Skipped -Because "actionlint is not installed in this environment"
            return
        }
        $result = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint reported: $($result -join '; ')"
    }
}

# ─── Round 9: Act integration tests ──────────────────────────────────────────
# These tests set up a temp git repo, run `act push --rm`, save output to
# act-result.txt, then assert on exact expected label values per fixture.

Describe "Act Integration Tests" -Tag "ActIntegration" {

    BeforeAll {
        $script:OriginalDir    = $PSScriptRoot
        $script:ActResultFile  = Join-Path $PSScriptRoot "act-result.txt"

        # Helper: parse act output to find the LABELS value after a FIXTURE line.
        # Act prefixes run-step output lines with "[workflow/job] | actual content".
        function script:Get-FixtureLabelFromActOutput {
            param([string]$ActOutput, [string]$FixtureName)

            $lines = $ActOutput -split "`r?`n"
            # Strip the act job prefix (e.g. "[PR Label Assigner/label-assigner] | ")
            $stripped = $lines | ForEach-Object { $_ -replace '^\[.*?\]\s*\|\s*', '' }

            $foundFixture = $false
            foreach ($line in $stripped) {
                $trimmed = $line.Trim()
                if ($trimmed -match "^FIXTURE:\s*$([regex]::Escape($FixtureName))$") {
                    $foundFixture = $true
                } elseif ($foundFixture -and $trimmed -match "^LABELS:\s*(.+)$") {
                    return $Matches[1].Trim()
                } elseif ($foundFixture -and $trimmed -match "^FIXTURE:") {
                    break  # Reached next fixture without a LABELS line
                }
            }
            return $null
        }

        # Create isolated temp directory for the act run
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pr-label-act-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

        # Files to copy into the temp repo
        $filesToCopy = @(
            "Invoke-PRLabelAssigner.ps1",
            "PRLabelAssigner.Tests.ps1",
            "config.json",
            "fixture-1.json",
            "fixture-2.json",
            "fixture-3.json",
            "fixture-4.json",
            ".actrc"
        )
        foreach ($f in $filesToCopy) {
            $src = Join-Path $PSScriptRoot $f
            if (Test-Path $src) {
                Copy-Item $src -Destination $script:TempDir
            }
        }

        # Copy .github directory (contains workflow)
        $githubSrc = Join-Path $PSScriptRoot ".github"
        if (Test-Path $githubSrc) {
            Copy-Item $githubSrc -Destination $script:TempDir -Recurse
        }

        # Initialize git repo in temp dir
        Push-Location $script:TempDir
        git init 2>&1 | Out-Null
        git config user.email "test@test.com" 2>&1 | Out-Null
        git config user.name "Test User" 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "test: act integration run" 2>&1 | Out-Null

        # Run act — one push for all 4 fixtures (they're all in the repo)
        Write-Host "Running act push --rm (this may take 30-90 seconds)..."
        $script:ActOutput = & act push --rm 2>&1
        $script:ActExitCode = $LASTEXITCODE
        $script:ActOutputStr = $script:ActOutput -join "`n"
        Pop-Location

        # Save full act output to act-result.txt
        $sep = "=" * 70
        $header = @"
$sep
PR Label Assigner - Act Integration Test Run
Timestamp : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Exit Code : $($script:ActExitCode)
$sep
"@
        Set-Content -Path $script:ActResultFile -Value ($header + "`n" + $script:ActOutputStr)
        Write-Host "Act output saved to act-result.txt"
    }

    AfterAll {
        # Clean up temp directory
        if ($script:TempDir -and (Test-Path $script:TempDir)) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "act-result.txt was created" {
        Test-Path $script:ActResultFile | Should -Be $true
    }

    It "act exits with code 0" {
        $script:ActExitCode | Should -Be 0 -Because "act output:`n$($script:ActOutputStr)"
    }

    It "job label-assigner shows 'Job succeeded'" {
        $script:ActOutputStr | Should -Match "Job succeeded"
    }

    # Helper: extract the LABELS line that follows a given FIXTURE line in act output
    # Act prefixes each output line with "[workflow/job] | "
    # We strip the prefix and look for FIXTURE:/LABELS: pairs.

    It "fixture-1 (docs/README.md) produces exactly 'documentation'" {
        $labels = Get-FixtureLabelFromActOutput -ActOutput $script:ActOutputStr -FixtureName "fixture-1.json"
        $labels | Should -Be "documentation"
    }

    It "fixture-2 (src/api/users.ts) produces exactly 'api'" {
        $labels = Get-FixtureLabelFromActOutput -ActOutput $script:ActOutputStr -FixtureName "fixture-2.json"
        $labels | Should -Be "api"
    }

    It "fixture-3 (src/api/users.test.ts) produces exactly 'api,tests'" {
        $labels = Get-FixtureLabelFromActOutput -ActOutput $script:ActOutputStr -FixtureName "fixture-3.json"
        $labels | Should -Be "api,tests"
    }

    It "fixture-4 (docs/README.md + src/api/users.ts + test/unit.test.js) produces exactly 'api,documentation,tests'" {
        $labels = Get-FixtureLabelFromActOutput -ActOutput $script:ActOutputStr -FixtureName "fixture-4.json"
        $labels | Should -Be "api,documentation,tests"
    }
}

