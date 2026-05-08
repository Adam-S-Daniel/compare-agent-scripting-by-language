#Requires -Modules Pester
<#
TDD Red/Green/Refactor narrative:
  RED:   Each Describe block was written first with no implementation.
  GREEN: Minimum code in Invoke-PrLabelAssigner.ps1 was written to pass it.
  REFACTOR: Helpers extracted; edge cases added in later Describe blocks.
#>

BeforeAll {
    # Dot-source the implementation so all functions are available in this scope.
    . "$PSScriptRoot/Invoke-PrLabelAssigner.ps1"
}

# ── RED #1: ConvertTo-GlobRegex ──────────────────────────────────────────────
Describe "ConvertTo-GlobRegex" {
    It "converts docs/** to regex anchored at docs/" {
        $regex = ConvertTo-GlobRegex "docs/**"
        $regex | Should -Be "^docs/.*$"
    }

    It "converts src/api/** to anchored regex" {
        $regex = ConvertTo-GlobRegex "src/api/**"
        $regex | Should -Be "^src/api/.*$"
    }

    It "converts **/*.test.* so ** prefix is optional path" {
        $regex = ConvertTo-GlobRegex "**/*.test.*"
        # Regex should match file at root AND nested file
        "controller.test.js" | Should -Match $regex
        "src/api/controller.test.js" | Should -Match $regex
    }

    It "converts *.config.* to match root-level config files only" {
        $regex = ConvertTo-GlobRegex "*.config.*"
        "jest.config.js" | Should -Match $regex
        "src/jest.config.js" | Should -Not -Match $regex
    }

    It "escapes literal dots in non-glob segments" {
        $regex = ConvertTo-GlobRegex "src/foo.bar/**"
        # 'foo.bar' should NOT match 'fooXbar'
        "src/fooXbar/file.js" | Should -Not -Match $regex
        "src/foo.bar/file.js" | Should -Match $regex
    }
}

# ── RED #2: Test-GlobMatch ───────────────────────────────────────────────────
Describe "Test-GlobMatch" {
    Context "docs/** pattern" {
        It "matches docs/README.md" {
            Test-GlobMatch -Path "docs/README.md" -Glob "docs/**" | Should -Be $true
        }

        It "matches nested docs/api/overview.md" {
            Test-GlobMatch -Path "docs/api/overview.md" -Glob "docs/**" | Should -Be $true
        }

        It "does not match src/api/routes.js" {
            Test-GlobMatch -Path "src/api/routes.js" -Glob "docs/**" | Should -Be $false
        }

        It "does not match documentation/README.md (prefix only match guard)" {
            Test-GlobMatch -Path "documentation/README.md" -Glob "docs/**" | Should -Be $false
        }
    }

    Context "src/api/** pattern" {
        It "matches src/api/routes.js" {
            Test-GlobMatch -Path "src/api/routes.js" -Glob "src/api/**" | Should -Be $true
        }

        It "matches deeply nested src/api/v1/controller.js" {
            Test-GlobMatch -Path "src/api/v1/controller.js" -Glob "src/api/**" | Should -Be $true
        }

        It "does not match src/frontend/app.js" {
            Test-GlobMatch -Path "src/frontend/app.js" -Glob "src/api/**" | Should -Be $false
        }
    }

    Context "**/*.test.* pattern" {
        It "matches root-level controller.test.js" {
            Test-GlobMatch -Path "controller.test.js" -Glob "**/*.test.*" | Should -Be $true
        }

        It "matches nested src/api/controller.test.js" {
            Test-GlobMatch -Path "src/api/controller.test.js" -Glob "**/*.test.*" | Should -Be $true
        }

        It "matches deeply nested src/frontend/app.test.ts" {
            Test-GlobMatch -Path "src/frontend/app.test.ts" -Glob "**/*.test.*" | Should -Be $true
        }

        It "does not match src/api/routes.js (no .test. in name)" {
            Test-GlobMatch -Path "src/api/routes.js" -Glob "**/*.test.*" | Should -Be $false
        }
    }

    Context "*.config.* pattern" {
        It "matches root-level jest.config.js" {
            Test-GlobMatch -Path "jest.config.js" -Glob "*.config.*" | Should -Be $true
        }

        It "does not match src/jest.config.js (subdirectory)" {
            Test-GlobMatch -Path "src/jest.config.js" -Glob "*.config.*" | Should -Be $false
        }
    }

    Context "backslash normalization" {
        It "treats backslash paths as forward-slash paths" {
            Test-GlobMatch -Path "src\api\routes.js" -Glob "src/api/**" | Should -Be $true
        }
    }
}

# ── RED #3: Get-PrLabels ─────────────────────────────────────────────────────
Describe "Get-PrLabels" {
    BeforeAll {
        # Load the shared rules fixture used by all test cases
        $script:rules = Get-Content "$PSScriptRoot/fixtures/rules.json" -Raw | ConvertFrom-Json
    }

    Context "Test case 1 – documentation label only" {
        It "labels docs files as documentation" {
            $files = @("docs/README.md", "docs/api/overview.md")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            $labels | Should -Be @("documentation")
        }
    }

    Context "Test case 2 – api and tests labels" {
        It "applies both api and tests labels when files match both rules" {
            $files = @("src/api/controller.test.js", "src/api/routes.js")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            $labels | Should -Contain "api"
            $labels | Should -Contain "tests"
            $labels.Count | Should -Be 2
        }

        It "outputs labels sorted by priority: api before tests" {
            $files = @("src/api/controller.test.js", "src/api/routes.js")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            $labels[0] | Should -Be "api"
            $labels[1] | Should -Be "tests"
        }
    }

    Context "Test case 3 – no matching labels" {
        It "returns empty array when no rules match" {
            $files = @("LICENSE", "Makefile")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            $labels | Should -BeNullOrEmpty
        }
    }

    Context "Test case 4 – priority ordering with multiple files" {
        It "collects all matching labels across multiple files" {
            $files = @("src/api/auth.js", "docs/contributing.md", "src/frontend/app.test.ts")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            $labels | Should -Contain "documentation"
            $labels | Should -Contain "api"
            $labels | Should -Contain "frontend"
            $labels | Should -Contain "tests"
            $labels.Count | Should -Be 4
        }

        It "orders labels by priority: documentation(1) api(2) frontend(3) tests(4)" {
            $files = @("src/api/auth.js", "docs/contributing.md", "src/frontend/app.test.ts")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            $labels | Should -Be @("documentation", "api", "frontend", "tests")
        }
    }

    Context "Priority conflict – same label from multiple rules keeps highest priority" {
        It "keeps lowest priority number when the same label matches twice" {
            # tests appears via two rules (priority 4 and a hypothetical 10); should stay 4
            $customRules = @(
                [PSCustomObject]@{pattern = "**/*.test.*"; label = "tests"; priority = 4},
                [PSCustomObject]@{pattern = "src/**";       label = "tests"; priority = 10}
            )
            $files = @("src/app.test.js")
            $labels = Get-PrLabels -Files $files -Rules $customRules
            $labels | Should -Be @("tests")
            $labels.Count | Should -Be 1
        }
    }

    Context "Edge cases" {
        It "returns empty array for empty file list" {
            $labels = Get-PrLabels -Files @() -Rules $script:rules
            $labels | Should -BeNullOrEmpty
        }

        It "returns empty array for null file list" {
            $labels = Get-PrLabels -Files $null -Rules $script:rules
            $labels | Should -BeNullOrEmpty
        }

        It "deduplicates labels when multiple files trigger the same rule" {
            $files = @("docs/README.md", "docs/contributing.md")
            $labels = Get-PrLabels -Files $files -Rules $script:rules
            ($labels | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
        }
    }
}

# ── RED #4: Workflow structure tests ─────────────────────────────────────────
Describe "Workflow Structure" {
    BeforeAll {
        $script:workflowPath = "$PSScriptRoot/.github/workflows/pr-label-assigner.yml"
        $script:workflowContent = Get-Content $script:workflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow file exists at expected path" {
        $script:workflowPath | Should -Exist
    }

    It "workflow has push trigger" {
        $script:workflowContent | Should -Match 'push:'
    }

    It "workflow has pull_request trigger" {
        $script:workflowContent | Should -Match 'pull_request:'
    }

    It "workflow has workflow_dispatch trigger" {
        $script:workflowContent | Should -Match 'workflow_dispatch:'
    }

    It "workflow references Invoke-PrLabelAssigner.ps1" {
        $script:workflowContent | Should -Match 'Invoke-PrLabelAssigner\.ps1'
    }

    It "workflow uses actions/checkout@v4" {
        $script:workflowContent | Should -Match 'actions/checkout@v4'
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $script:workflowContent | Should -Match 'shell:\s*pwsh'
    }

    It "implementation script Invoke-PrLabelAssigner.ps1 exists" {
        "$PSScriptRoot/Invoke-PrLabelAssigner.ps1" | Should -Exist
    }

    It "fixtures/rules.json exists" {
        "$PSScriptRoot/fixtures/rules.json" | Should -Exist
    }
}
