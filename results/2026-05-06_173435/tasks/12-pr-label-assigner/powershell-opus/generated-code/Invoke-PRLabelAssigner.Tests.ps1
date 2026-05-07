BeforeAll {
    . $PSScriptRoot/Invoke-PRLabelAssigner.ps1
}

Describe "ConvertTo-LikePattern" {
    It "converts ** to * for recursive matching" {
        ConvertTo-LikePattern -GlobPattern "docs/**" | Should -Be "docs/*"
    }

    It "converts **/ in mid-path to *" {
        ConvertTo-LikePattern -GlobPattern "src/**/test.js" | Should -Be "src/*test.js"
    }

    It "leaves simple patterns unchanged" {
        ConvertTo-LikePattern -GlobPattern "*.js" | Should -Be "*.js"
    }
}

Describe "Get-PRLabels" {
    Context "Basic glob matching" {
        It "matches docs/** to documentation label" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("docs/readme.md") -Rules $rules)
            $result | Should -Contain "documentation"
            $result.Count | Should -Be 1
        }

        It "matches src/api/** to api label" {
            $rules = @(
                @{ Pattern = "src/api/**"; Label = "api"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("src/api/index.js") -Rules $rules)
            $result | Should -Contain "api"
        }

        It "matches *.test.* to tests label" {
            $rules = @(
                @{ Pattern = "*.test.*"; Label = "tests"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("app.test.js") -Rules $rules)
            $result | Should -Contain "tests"
        }

        It "matches deep nested paths with **" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("docs/api/v2/reference/endpoint.md") -Rules $rules)
            $result | Should -Contain "documentation"
        }

        It "matches extension-only patterns across directories" {
            $rules = @(
                @{ Pattern = "*.js"; Label = "javascript"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("src/utils/helper.js") -Rules $rules)
            $result | Should -Contain "javascript"
        }
    }

    Context "Multiple labels per file" {
        It "assigns multiple labels when a file matches multiple rules" {
            $rules = @(
                @{ Pattern = "src/**"; Label = "source"; Priority = 1 },
                @{ Pattern = "src/api/**"; Label = "api"; Priority = 2 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("src/api/index.js") -Rules $rules)
            $result | Should -Contain "source"
            $result | Should -Contain "api"
            $result.Count | Should -Be 2
        }
    }

    Context "Priority ordering" {
        It "returns labels ordered by priority descending" {
            $rules = @(
                @{ Pattern = "src/**"; Label = "source"; Priority = 1 },
                @{ Pattern = "*.test.*"; Label = "tests"; Priority = 3 },
                @{ Pattern = "src/api/**"; Label = "api"; Priority = 2 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("src/api/handler.test.js") -Rules $rules)
            $result[0] | Should -Be "tests"
            $result[1] | Should -Be "api"
            $result[2] | Should -Be "source"
        }
    }

    Context "No matching rules" {
        It "returns empty when no rules match" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("src/app.js") -Rules $rules)
            $result.Count | Should -Be 0
        }
    }

    Context "Empty file list" {
        It "returns empty for empty file list" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @() -Rules $rules)
            $result.Count | Should -Be 0
        }
    }

    Context "Label deduplication" {
        It "does not duplicate labels when multiple files match the same rule" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 1 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("docs/readme.md", "docs/guide.md") -Rules $rules)
            $result.Count | Should -Be 1
            $result[0] | Should -Be "documentation"
        }
    }

    Context "Error handling" {
        It "throws when rule is missing Pattern key" {
            $rules = @(
                @{ Label = "test"; Priority = 1 }
            )
            { Get-PRLabels -ChangedFiles @("test.js") -Rules $rules } | Should -Throw "*Pattern*"
        }

        It "throws when rule is missing Label key" {
            $rules = @(
                @{ Pattern = "*.js"; Priority = 1 }
            )
            { Get-PRLabels -ChangedFiles @("test.js") -Rules $rules } | Should -Throw "*Label*"
        }
    }

    Context "Default priority" {
        It "defaults priority to 0 when not specified" {
            $rules = @(
                @{ Pattern = "*.js"; Label = "javascript" }
            )
            $result = @(Get-PRLabels -ChangedFiles @("app.js") -Rules $rules)
            $result | Should -Contain "javascript"
        }
    }

    Context "Multiple files with different rules" {
        It "collects labels from all matching files" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 1 },
                @{ Pattern = "src/**"; Label = "source"; Priority = 2 },
                @{ Pattern = "*.test.*"; Label = "tests"; Priority = 3 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("docs/readme.md", "src/app.js", "util.test.js") -Rules $rules)
            $result | Should -Contain "documentation"
            $result | Should -Contain "source"
            $result | Should -Contain "tests"
            $result.Count | Should -Be 3
        }
    }
}

Describe "Invoke-PRLabelAssigner" {
    BeforeAll {
        $testConfigDir = Join-Path $TestDrive "configs"
        New-Item -ItemType Directory -Path $testConfigDir -Force | Out-Null
    }

    It "reads config from JSON file and returns labels" {
        $configPath = Join-Path $testConfigDir "test-config.json"
        @{
            rules = @(
                @{ pattern = "docs/**"; label = "documentation"; priority = 1 }
            )
        } | ConvertTo-Json -Depth 3 | Set-Content $configPath

        $result = @(Invoke-PRLabelAssigner -ConfigPath $configPath -ChangedFiles @("docs/readme.md"))
        $result | Should -Contain "documentation"
    }

    It "throws for missing config file" {
        { Invoke-PRLabelAssigner -ConfigPath "/nonexistent/config.json" -ChangedFiles @("test.js") } |
            Should -Throw "*not found*"
    }

    It "throws for config with empty rules array" {
        $configPath = Join-Path $testConfigDir "empty-config.json"
        @{ rules = @() } | ConvertTo-Json | Set-Content $configPath

        { Invoke-PRLabelAssigner -ConfigPath $configPath -ChangedFiles @("test.js") } |
            Should -Throw "*rules*"
    }

    It "handles config with multiple rules and priorities" {
        $configPath = Join-Path $testConfigDir "multi-config.json"
        @{
            rules = @(
                @{ pattern = "src/**"; label = "source"; priority = 10 },
                @{ pattern = "*.test.*"; label = "tests"; priority = 20 }
            )
        } | ConvertTo-Json -Depth 3 | Set-Content $configPath

        $result = @(Invoke-PRLabelAssigner -ConfigPath $configPath -ChangedFiles @("src/app.test.js"))
        $result[0] | Should -Be "tests"
        $result[1] | Should -Be "source"
    }
}

Describe "Workflow structure" {
    BeforeAll {
        $workflowPath = Join-Path $PSScriptRoot ".github/workflows/pr-label-assigner.yml"
    }

    It "workflow file exists" {
        $workflowPath | Should -Exist
    }

    It "has push trigger" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'push'
    }

    It "has jobs section" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'jobs:'
    }

    It "has steps section" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'steps:'
    }

    It "uses actions/checkout" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'actions/checkout'
    }

    It "uses shell pwsh" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'shell:\s*pwsh'
    }

    It "references the main script" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'Invoke-PRLabelAssigner\.ps1'
        Join-Path $PSScriptRoot "Invoke-PRLabelAssigner.ps1" | Should -Exist
    }

    It "references the test file" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'Invoke-PRLabelAssigner\.Tests\.ps1'
        Join-Path $PSScriptRoot "Invoke-PRLabelAssigner.Tests.ps1" | Should -Exist
    }

    It "passes actionlint validation" {
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not available in this environment"
            return
        }
        & actionlint $workflowPath 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
