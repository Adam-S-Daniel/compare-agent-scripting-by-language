# PRLabelAssigner.Tests.ps1
# Pester test suite for the PR Label Assigner
# TDD approach: tests define expected behavior before implementation

BeforeAll {
    # Dot-source the main script to load all functions into test scope
    . "$PSScriptRoot/Invoke-PRLabelAssigner.ps1"
}

# =============================================================================
# Test-GlobPattern - Tests for glob pattern matching
# =============================================================================
Describe "Test-GlobPattern" {
    Context "docs/** pattern" {
        It "matches a file directly under docs/" {
            Test-GlobPattern -Path "docs/README.md" -Pattern "docs/**" | Should -BeTrue
        }
        It "matches a file nested under docs/" {
            Test-GlobPattern -Path "docs/api/guide.md" -Pattern "docs/**" | Should -BeTrue
        }
        It "does NOT match a file outside docs/" {
            Test-GlobPattern -Path "src/main.js" -Pattern "docs/**" | Should -BeFalse
        }
    }

    Context "src/api/** pattern" {
        It "matches a file directly under src/api/" {
            Test-GlobPattern -Path "src/api/users.js" -Pattern "src/api/**" | Should -BeTrue
        }
        It "does NOT match a file under src/ but not src/api/" {
            Test-GlobPattern -Path "src/core/utils.js" -Pattern "src/api/**" | Should -BeFalse
        }
    }

    Context "*.test.* pattern (test files anywhere)" {
        It "matches a test file at repo root" {
            Test-GlobPattern -Path "utils.test.js" -Pattern "*.test.*" | Should -BeTrue
        }
        It "matches a test file in a subdirectory" {
            Test-GlobPattern -Path "src/api/users.test.js" -Pattern "*.test.*" | Should -BeTrue
        }
        It "does NOT match a non-test file" {
            Test-GlobPattern -Path "src/api/users.js" -Pattern "*.test.*" | Should -BeFalse
        }
    }

    Context "**/*.md pattern (markdown anywhere)" {
        It "matches a markdown file at repo root" {
            Test-GlobPattern -Path "README.md" -Pattern "**/*.md" | Should -BeTrue
        }
        It "matches a markdown file in a subdirectory" {
            Test-GlobPattern -Path "docs/guide.md" -Pattern "**/*.md" | Should -BeTrue
        }
        It "does NOT match a non-markdown file" {
            Test-GlobPattern -Path "src/main.js" -Pattern "**/*.md" | Should -BeFalse
        }
    }

    Context ".github/** pattern" {
        It "matches a file under .github/" {
            Test-GlobPattern -Path ".github/workflows/ci.yml" -Pattern ".github/**" | Should -BeTrue
        }
        It "does NOT match a file not under .github/" {
            Test-GlobPattern -Path "src/ci.yml" -Pattern ".github/**" | Should -BeFalse
        }
    }
}

# =============================================================================
# Get-MatchingLabels - Tests for label matching against rules
# =============================================================================
Describe "Get-MatchingLabels" {
    BeforeAll {
        # Define a shared set of rules for these tests
        $script:TestRules = @(
            [PSCustomObject]@{ Pattern = "docs/**";     Label = "documentation"; Priority = 100 }
            [PSCustomObject]@{ Pattern = "**/*.md";     Label = "documentation"; Priority = 95  }
            [PSCustomObject]@{ Pattern = "src/api/**";  Label = "api";           Priority = 90  }
            [PSCustomObject]@{ Pattern = "*.test.*";    Label = "tests";         Priority = 80  }
            [PSCustomObject]@{ Pattern = "src/**";      Label = "backend";       Priority = 70  }
            [PSCustomObject]@{ Pattern = ".github/**";  Label = "ci/cd";         Priority = 60  }
        )
    }

    It "returns 'documentation' for a docs file" {
        $result = Get-MatchingLabels -FilePaths @("docs/README.md") -Rules $script:TestRules
        $result | Should -Contain "documentation"
    }

    It "returns 'api' and 'backend' for a src/api file" {
        $result = Get-MatchingLabels -FilePaths @("src/api/users.js") -Rules $script:TestRules
        $result | Should -Contain "api"
        $result | Should -Contain "backend"
    }

    It "returns 'api', 'tests', and 'backend' for a test file in src/api" {
        $result = Get-MatchingLabels -FilePaths @("src/api/users.test.js") -Rules $script:TestRules
        $result | Should -Contain "api"
        $result | Should -Contain "tests"
        $result | Should -Contain "backend"
    }

    It "returns 'ci/cd' for a .github workflow file" {
        $result = Get-MatchingLabels -FilePaths @(".github/workflows/ci.yml") -Rules $script:TestRules
        $result | Should -Contain "ci/cd"
    }

    It "returns empty array for an unmatched file" {
        $result = Get-MatchingLabels -FilePaths @("random-file.txt") -Rules $script:TestRules
        $result | Should -BeNullOrEmpty
    }

    It "deduplicates labels when multiple rules produce the same label" {
        # docs/README.md matches both 'docs/**' and '**/*.md' -> both give 'documentation'
        $result = Get-MatchingLabels -FilePaths @("docs/README.md") -Rules $script:TestRules
        ($result | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
    }

    It "orders labels by descending priority" {
        # src/api/users.test.js: api(90) > tests(80) > backend(70)
        $result = Get-MatchingLabels -FilePaths @("src/api/users.test.js") -Rules $script:TestRules
        $apiIdx    = [Array]::IndexOf($result, "api")
        $testsIdx  = [Array]::IndexOf($result, "tests")
        $backendIdx = [Array]::IndexOf($result, "backend")
        $apiIdx | Should -BeLessThan $testsIdx
        $testsIdx | Should -BeLessThan $backendIdx
    }

    It "unions labels across multiple changed files" {
        $result = Get-MatchingLabels -FilePaths @("docs/README.md", "src/api/users.js") -Rules $script:TestRules
        $result | Should -Contain "documentation"
        $result | Should -Contain "api"
        $result | Should -Contain "backend"
    }
}

# =============================================================================
# Get-LabelRulesFromConfig - Tests for loading config from JSON
# =============================================================================
Describe "Get-LabelRulesFromConfig" {
    It "loads rules from a valid JSON config file" {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $config = @{
            rules = @(
                @{ pattern = "docs/**"; label = "documentation"; priority = 100 }
                @{ pattern = "src/**";  label = "backend";       priority = 70  }
            )
        }
        $config | ConvertTo-Json -Depth 3 | Set-Content $tmpFile

        $rules = Get-LabelRulesFromConfig -ConfigPath $tmpFile
        $rules | Should -HaveCount 2
        $rules[0].Pattern | Should -Be "docs/**"
        $rules[0].Label   | Should -Be "documentation"
        $rules[0].Priority | Should -Be 100

        Remove-Item $tmpFile -Force
    }

    It "throws a meaningful error when config file does not exist" {
        { Get-LabelRulesFromConfig -ConfigPath "/nonexistent/path/config.json" } |
            Should -Throw "*not found*"
    }

    It "throws a meaningful error when config has no rules array" {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        '{ "version": 1 }' | Set-Content $tmpFile

        { Get-LabelRulesFromConfig -ConfigPath $tmpFile } |
            Should -Throw "*rules*"

        Remove-Item $tmpFile -Force
    }
}

# =============================================================================
# Invoke-PRLabelAssigner - End-to-end tests using config file
# =============================================================================
Describe "Invoke-PRLabelAssigner" {
    BeforeAll {
        # Write a temp config file for end-to-end tests
        $script:TmpConfig = [System.IO.Path]::GetTempFileName() + ".json"
        @{
            rules = @(
                @{ pattern = "docs/**";    label = "documentation"; priority = 100 }
                @{ pattern = "src/api/**"; label = "api";           priority = 90  }
                @{ pattern = "*.test.*";   label = "tests";         priority = 80  }
                @{ pattern = "src/**";     label = "backend";       priority = 70  }
                @{ pattern = ".github/**"; label = "ci/cd";         priority = 60  }
            )
        } | ConvertTo-Json -Depth 3 | Set-Content $script:TmpConfig
    }

    AfterAll {
        Remove-Item $script:TmpConfig -Force -ErrorAction SilentlyContinue
    }

    It "returns correct labels for a docs file" {
        $result = Invoke-PRLabelAssigner -FilePaths @("docs/README.md") -ConfigPath $script:TmpConfig
        $result | Should -Contain "documentation"
    }

    It "returns correct labels for a src/api file" {
        $result = Invoke-PRLabelAssigner -FilePaths @("src/api/users.js") -ConfigPath $script:TmpConfig
        $result | Should -Be @("api", "backend")
    }

    It "returns multiple labels for src/api test file" {
        $result = Invoke-PRLabelAssigner -FilePaths @("src/api/users.test.js") -ConfigPath $script:TmpConfig
        $result | Should -Be @("api", "tests", "backend")
    }

    It "returns empty for unmatched file" {
        $result = Invoke-PRLabelAssigner -FilePaths @("random-file.txt") -ConfigPath $script:TmpConfig
        $result | Should -BeNullOrEmpty
    }
}

# =============================================================================
# Workflow Structure Tests - validate the GHA workflow file
# =============================================================================
Describe "Workflow Structure" {
    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/.github/workflows/pr-label-assigner.yml"
        $script:WorkflowContent = Get-Content $script:WorkflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow file exists" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "workflow has push trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "workflow references Invoke-PRLabelAssigner.ps1" {
        $script:WorkflowContent | Should -Match "Invoke-PRLabelAssigner\.ps1"
    }

    It "workflow references label-config.json" {
        $script:WorkflowContent | Should -Match "label-config\.json"
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $script:WorkflowContent | Should -Match "shell:\s*pwsh"
    }

    It "workflow uses actions/checkout@v4" {
        $script:WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "script file Invoke-PRLabelAssigner.ps1 exists at referenced path" {
        Test-Path "$PSScriptRoot/Invoke-PRLabelAssigner.ps1" | Should -BeTrue
    }

    It "config file label-config.json exists at referenced path" {
        Test-Path "$PSScriptRoot/label-config.json" | Should -BeTrue
    }

    It "passes actionlint validation" {
        $actionlintPath = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintPath) {
            Set-ItResult -Skipped -Because "actionlint is not installed in this environment"
            return
        }
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint should report no errors. Output: $output"
    }
}
