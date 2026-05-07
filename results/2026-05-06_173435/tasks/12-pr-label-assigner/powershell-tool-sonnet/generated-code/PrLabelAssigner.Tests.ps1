# PrLabelAssigner.Tests.ps1
# Pester tests for PR Label Assigner
#
# TDD red/green iterations (tests written before implementation):
#   Iteration 1 - ConvertTo-GlobRegex:  glob pattern -> regex string
#   Iteration 2 - Test-GlobMatch:       match a file path against a glob pattern
#   Iteration 3 - Get-PrLabels basic:   single rule produces correct label
#   Iteration 4 - Get-PrLabels multi:   multiple rules produce multiple labels per file
#   Iteration 5 - Get-PrLabels dedup:   same label from multiple files appears once
#   Iteration 6 - Get-PrLabels priority: priority sorts rules, all labels collected
#   Iteration 7 - Get-PrLabels empty:   graceful handling of empty inputs
#   Iteration 8 - New-LabelRule:        rule object construction helper
#   Iteration 9 - DefaultLabelRules:    default config validation
#   Iteration 10 - WorkflowStructure:   YAML structure, file existence, actionlint

BeforeAll {
    . "$PSScriptRoot/PrLabelAssigner.ps1"
}

# ---------------------------------------------------------------------------
# Iteration 1: Glob pattern to regex string
# ---------------------------------------------------------------------------
Describe "ConvertTo-GlobRegex" {
    It "converts ** to .* for recursive path matching" {
        ConvertTo-GlobRegex -GlobPattern "docs/**" | Should -Be "^docs/.*$"
    }

    It "converts * to [^/]* for within-segment matching" {
        ConvertTo-GlobRegex -GlobPattern "*.ps1" | Should -Be "^[^/]*\.ps1$"
    }

    It "converts ? to [^/] for single non-separator character" {
        ConvertTo-GlobRegex -GlobPattern "file?.ps1" | Should -Be "^file[^/]\.ps1$"
    }

    It "handles ** in the middle of a pattern" {
        ConvertTo-GlobRegex -GlobPattern "src/**/test.ps1" | Should -Be "^src/.*/test\.ps1$"
    }

    It "escapes dots and other regex special characters" {
        ConvertTo-GlobRegex -GlobPattern "*.test.*" | Should -Be "^[^/]*\.test\.[^/]*$"
    }

    It "handles literal pattern with no wildcards" {
        ConvertTo-GlobRegex -GlobPattern "README.md" | Should -Be "^README\.md$"
    }
}

# ---------------------------------------------------------------------------
# Iteration 2: File path matching against a glob pattern
# ---------------------------------------------------------------------------
Describe "Test-GlobMatch" {
    Context "patterns containing '/' are matched against the full path" {
        It "matches docs/** against docs/README.md" {
            Test-GlobMatch -Path "docs/README.md" -GlobPattern "docs/**" | Should -BeTrue
        }

        It "matches docs/** against deeply nested docs/api/v2/guide.md" {
            Test-GlobMatch -Path "docs/api/v2/guide.md" -GlobPattern "docs/**" | Should -BeTrue
        }

        It "does NOT match docs/** against src/docs/README.md" {
            Test-GlobMatch -Path "src/docs/README.md" -GlobPattern "docs/**" | Should -BeFalse
        }

        It "matches src/api/** against src/api/controllers/user.ps1" {
            Test-GlobMatch -Path "src/api/controllers/user.ps1" -GlobPattern "src/api/**" | Should -BeTrue
        }

        It "does NOT match src/api/** against src/services/payment.ps1" {
            Test-GlobMatch -Path "src/services/payment.ps1" -GlobPattern "src/api/**" | Should -BeFalse
        }

        It "matches .github/** against .github/workflows/ci.yml" {
            Test-GlobMatch -Path ".github/workflows/ci.yml" -GlobPattern ".github/**" | Should -BeTrue
        }
    }

    Context "patterns without '/' are matched against filename (basename) only" {
        It "matches *.test.* against root-level auth.test.ps1" {
            Test-GlobMatch -Path "auth.test.ps1" -GlobPattern "*.test.*" | Should -BeTrue
        }

        It "matches *.test.* against nested src/auth.test.ps1" {
            Test-GlobMatch -Path "src/auth.test.ps1" -GlobPattern "*.test.*" | Should -BeTrue
        }

        It "does NOT match *.test.* against src/auth.ps1" {
            Test-GlobMatch -Path "src/auth.ps1" -GlobPattern "*.test.*" | Should -BeFalse
        }

        It "matches *.md against root-level README.md" {
            Test-GlobMatch -Path "README.md" -GlobPattern "*.md" | Should -BeTrue
        }

        It "matches *.md against nested docs/README.md" {
            Test-GlobMatch -Path "docs/README.md" -GlobPattern "*.md" | Should -BeTrue
        }

        It "matches *.spec.ts against src/components/button.spec.ts" {
            Test-GlobMatch -Path "src/components/button.spec.ts" -GlobPattern "*.spec.ts" | Should -BeTrue
        }
    }

    Context "path separator normalization" {
        It "normalizes Windows backslashes before matching" {
            Test-GlobMatch -Path "docs\api\guide.md" -GlobPattern "docs/**" | Should -BeTrue
        }
    }
}

# ---------------------------------------------------------------------------
# Iterations 3-7: Core label assignment logic
# ---------------------------------------------------------------------------
Describe "Get-PrLabels" {
    BeforeAll {
        $script:testRules = @(
            [PSCustomObject]@{ Pattern = 'docs/**';    Label = 'documentation'; Priority = 10 }
            [PSCustomObject]@{ Pattern = 'src/api/**'; Label = 'api';           Priority = 8  }
            [PSCustomObject]@{ Pattern = '*.test.*';   Label = 'tests';         Priority = 6  }
            [PSCustomObject]@{ Pattern = 'src/**';     Label = 'source';        Priority = 4  }
        )
    }

    # Iteration 3: basic single-rule matching
    Context "basic label assignment" {
        It "assigns documentation for docs/README.md" {
            $labels = Get-PrLabels -ChangedFiles @('docs/README.md') -LabelRules $script:testRules
            $labels | Should -Contain 'documentation'
        }

        It "assigns api for src/api/user.ps1" {
            $labels = Get-PrLabels -ChangedFiles @('src/api/user.ps1') -LabelRules $script:testRules
            $labels | Should -Contain 'api'
        }

        It "assigns tests for src/auth.test.ps1" {
            $labels = Get-PrLabels -ChangedFiles @('src/auth.test.ps1') -LabelRules $script:testRules
            $labels | Should -Contain 'tests'
        }

        It "returns no labels when no rules match" {
            $noMatchRules = @(
                [PSCustomObject]@{ Pattern = 'nonexistent/**'; Label = 'never'; Priority = 1 }
            )
            $labels = Get-PrLabels -ChangedFiles @('src/file.ps1') -LabelRules $noMatchRules
            $labels | Should -HaveCount 0
        }
    }

    # Iteration 4: multiple labels from multiple matching rules
    Context "multiple labels per file" {
        It "assigns api, source, and tests for src/api/auth.test.ps1" {
            $labels = Get-PrLabels -ChangedFiles @('src/api/auth.test.ps1') -LabelRules $script:testRules
            $labels | Should -Contain 'api'
            $labels | Should -Contain 'tests'
            $labels | Should -Contain 'source'
        }

        It "assigns api and source but NOT tests for src/api/user.ps1" {
            $labels = Get-PrLabels -ChangedFiles @('src/api/user.ps1') -LabelRules $script:testRules
            $labels | Should -Contain 'api'
            $labels | Should -Contain 'source'
            $labels | Should -Not -Contain 'tests'
        }
    }

    # Iteration 5: labels aggregated from multiple files and deduplicated
    Context "deduplication and aggregation" {
        It "collects labels across multiple files" {
            $files = @('docs/README.md', 'src/api/user.ps1')
            $labels = Get-PrLabels -ChangedFiles $files -LabelRules $script:testRules
            $labels | Should -Contain 'documentation'
            $labels | Should -Contain 'api'
        }

        It "deduplicates: documentation appears once even when two docs files match" {
            $files = @('docs/README.md', 'docs/api/guide.md')
            $labels = Get-PrLabels -ChangedFiles $files -LabelRules $script:testRules
            ($labels | Where-Object { $_ -eq 'documentation' }).Count | Should -Be 1
        }

        It "returns output sorted alphabetically" {
            $files = @('docs/README.md', 'src/api/user.ps1', 'src/auth.test.ps1')
            $labels = Get-PrLabels -ChangedFiles $files -LabelRules $script:testRules
            $labels | Should -Be ($labels | Sort-Object)
        }

        It "produces the exact label set for a comprehensive file list" {
            $files = @(
                'docs/README.md'
                'docs/api/guide.md'
                'src/api/controllers/user.ps1'
                'src/auth.test.ps1'
            )
            $labels = Get-PrLabels -ChangedFiles $files -LabelRules $script:testRules
            $labels | Should -Be @('api', 'documentation', 'source', 'tests')
        }
    }

    # Iteration 6: priority controls evaluation order; all matching labels included
    Context "priority ordering" {
        It "includes labels from both high- and low-priority matching rules" {
            $labels = Get-PrLabels -ChangedFiles @('src/api/user.ps1') -LabelRules $script:testRules
            $labels | Should -Contain 'api'    # priority 8
            $labels | Should -Contain 'source' # priority 4
        }

        It "collects labels from two rules at different priorities on same pattern" {
            $conflictRules = @(
                [PSCustomObject]@{ Pattern = 'src/**'; Label = 'high-pri'; Priority = 10 }
                [PSCustomObject]@{ Pattern = 'src/**'; Label = 'low-pri';  Priority = 1  }
            )
            $labels = Get-PrLabels -ChangedFiles @('src/file.ps1') -LabelRules $conflictRules
            $labels | Should -Contain 'high-pri'
            $labels | Should -Contain 'low-pri'
        }
    }

    # Iteration 7: empty inputs handled gracefully
    Context "empty input handling" {
        It "returns empty array when ChangedFiles is empty" {
            $labels = Get-PrLabels -ChangedFiles @() -LabelRules $script:testRules
            $labels | Should -HaveCount 0
        }

        It "returns empty array when LabelRules is empty" {
            $labels = Get-PrLabels -ChangedFiles @('docs/README.md') -LabelRules @()
            $labels | Should -HaveCount 0
        }
    }
}

# ---------------------------------------------------------------------------
# Iteration 8: Rule object construction
# ---------------------------------------------------------------------------
Describe "New-LabelRule" {
    It "creates a rule with Pattern, Label, and Priority" {
        $rule = New-LabelRule -Pattern 'docs/**' -Label 'documentation' -Priority 10
        $rule.Pattern  | Should -Be 'docs/**'
        $rule.Label    | Should -Be 'documentation'
        $rule.Priority | Should -Be 10
    }

    It "defaults Priority to 0 when omitted" {
        $rule = New-LabelRule -Pattern 'src/**' -Label 'source'
        $rule.Priority | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Iteration 9: Default configuration
# ---------------------------------------------------------------------------
Describe "DefaultLabelRules" {
    It "contains at least one rule" {
        $DefaultLabelRules.Count | Should -BeGreaterThan 0
    }

    It "has a docs/** rule that maps to documentation" {
        $rule = $DefaultLabelRules | Where-Object { $_.Pattern -eq 'docs/**' }
        $rule             | Should -Not -BeNullOrEmpty
        $rule.Label       | Should -Be 'documentation'
    }

    It "has a src/api/** rule that maps to api" {
        $rule = $DefaultLabelRules | Where-Object { $_.Pattern -eq 'src/api/**' }
        $rule             | Should -Not -BeNullOrEmpty
        $rule.Label       | Should -Be 'api'
    }

    It "has a *.test.* rule that maps to tests" {
        $rule = $DefaultLabelRules | Where-Object { $_.Pattern -eq '*.test.*' }
        $rule             | Should -Not -BeNullOrEmpty
        $rule.Label       | Should -Be 'tests'
    }

    It "every rule has non-empty Pattern, Label, and a Priority property" {
        foreach ($rule in $DefaultLabelRules) {
            $rule.Pattern | Should -Not -BeNullOrEmpty
            $rule.Label   | Should -Not -BeNullOrEmpty
            $rule.PSObject.Properties.Name | Should -Contain 'Priority'
        }
    }
}

# ---------------------------------------------------------------------------
# Iteration 10: Workflow structure validation
# ---------------------------------------------------------------------------
Describe "WorkflowStructure" {
    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot ".github/workflows/pr-label-assigner.yml"
        $script:scriptPath   = Join-Path $PSScriptRoot "PrLabelAssigner.ps1"
        $script:testsPath    = Join-Path $PSScriptRoot "PrLabelAssigner.Tests.ps1"
    }

    It "workflow file exists at .github/workflows/pr-label-assigner.yml" {
        $script:workflowPath | Should -Exist
    }

    It "PrLabelAssigner.ps1 exists" {
        $script:scriptPath | Should -Exist
    }

    It "PrLabelAssigner.Tests.ps1 exists" {
        $script:testsPath | Should -Exist
    }

    It "workflow has a push trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'push:'
    }

    It "workflow has a pull_request trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'pull_request:'
    }

    It "workflow has a workflow_dispatch trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'workflow_dispatch:'
    }

    It "workflow uses actions/checkout@v4" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'actions/checkout@v4'
    }

    It "workflow uses shell: pwsh for PowerShell run steps" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'shell:\s*pwsh'
    }

    It "workflow references PrLabelAssigner.ps1" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match 'PrLabelAssigner\.ps1'
    }

    It "actionlint validates the workflow without errors" {
        $actionlint = Get-Command actionlint -ErrorAction SilentlyContinue
        if ($null -eq $actionlint) {
            Set-ItResult -Skipped -Because "actionlint not available in this container"
            return
        }
        $output = & actionlint $script:workflowPath 2>&1
        $output | ForEach-Object { Write-Host $_ }
        $LASTEXITCODE | Should -Be 0
    }
}
