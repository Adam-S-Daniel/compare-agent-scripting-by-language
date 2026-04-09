# Invoke-PRLabelAssigner.Tests.ps1
# Pester tests for the PR Label Assigner script.
# TDD approach: each Describe block was written as a failing test first,
# then the corresponding code was implemented.

BeforeAll {
    . "$PSScriptRoot/Invoke-PRLabelAssigner.ps1"
}

Describe "Convert-GlobToRegex" {
    It "converts simple wildcard pattern" {
        $regex = Convert-GlobToRegex -Glob "*.js"
        "app.js" | Should -Match $regex
        "src/app.js" | Should -Not -Match $regex
    }

    It "converts double-star pattern for directory traversal" {
        $regex = Convert-GlobToRegex -Glob "docs/**"
        "docs/readme.md" | Should -Match $regex
        "docs/api/endpoints.md" | Should -Match $regex
    }

    It "converts double-star with suffix" {
        $regex = Convert-GlobToRegex -Glob "src/**/*.ts"
        "src/index.ts" | Should -Match $regex
        "src/api/handler.ts" | Should -Match $regex
        "lib/index.ts" | Should -Not -Match $regex
    }

    It "handles dot in extension patterns" {
        $regex = Convert-GlobToRegex -Glob "*.test.*"
        "app.test.js" | Should -Match $regex
        "app.test.ts" | Should -Match $regex
        "app.js" | Should -Not -Match $regex
    }
}

Describe "Test-GlobMatch" {
    It "matches docs/** pattern" {
        Test-GlobMatch -Path "docs/readme.md" -Pattern "docs/**" | Should -BeTrue
        Test-GlobMatch -Path "docs/api/v1.md" -Pattern "docs/**" | Should -BeTrue
        Test-GlobMatch -Path "src/docs/readme.md" -Pattern "docs/**" | Should -BeFalse
    }

    It "matches src/api/** pattern" {
        Test-GlobMatch -Path "src/api/handler.ts" -Pattern "src/api/**" | Should -BeTrue
        Test-GlobMatch -Path "src/api/v2/handler.ts" -Pattern "src/api/**" | Should -BeTrue
        Test-GlobMatch -Path "src/web/handler.ts" -Pattern "src/api/**" | Should -BeFalse
    }

    It "matches *.test.* pattern for test files" {
        Test-GlobMatch -Path "app.test.js" -Pattern "*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "utils.test.ts" -Pattern "*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "app.js" -Pattern "*.test.*" | Should -BeFalse
    }
}

Describe "Get-PRLabels" {
    Context "basic label assignment" {
        It "assigns a single label for a matching file" {
            $rules = @(
                [PSCustomObject]@{ pattern = "docs/**"; label = "documentation"; priority = 1 }
            )
            $files = @("docs/readme.md")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "documentation"
            $result.Count | Should -Be 1
        }

        It "assigns multiple labels when multiple rules match" {
            $rules = @(
                [PSCustomObject]@{ pattern = "src/**"; label = "source"; priority = 1 },
                [PSCustomObject]@{ pattern = "src/api/**"; label = "api"; priority = 2 }
            )
            $files = @("src/api/handler.ts")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "source"
            $result | Should -Contain "api"
            $result.Count | Should -Be 2
        }

        It "assigns labels from multiple files" {
            $rules = @(
                [PSCustomObject]@{ pattern = "docs/**"; label = "documentation"; priority = 1 },
                [PSCustomObject]@{ pattern = "src/**"; label = "source"; priority = 2 }
            )
            $files = @("docs/readme.md", "src/index.ts")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "documentation"
            $result | Should -Contain "source"
            $result.Count | Should -Be 2
        }
    }

    Context "deduplication" {
        It "deduplicates labels when multiple files match the same rule" {
            $rules = @(
                [PSCustomObject]@{ pattern = "docs/**"; label = "documentation"; priority = 1 }
            )
            $files = @("docs/readme.md", "docs/guide.md", "docs/api/ref.md")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "documentation"
            $result.Count | Should -Be 1
        }
    }

    Context "priority ordering" {
        It "evaluates higher priority rules first" {
            # Priority determines evaluation order; all matching labels are still collected
            $rules = @(
                [PSCustomObject]@{ pattern = "src/**"; label = "source"; priority = 10 },
                [PSCustomObject]@{ pattern = "src/api/**"; label = "api-critical"; priority = 1 }
            )
            $files = @("src/api/handler.ts")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            # Both labels should be present since both patterns match
            $result | Should -Contain "api-critical"
            $result | Should -Contain "source"
        }
    }

    Context "test file patterns" {
        It "labels test files correctly with glob *.test.*" {
            $rules = @(
                [PSCustomObject]@{ pattern = "*.test.*"; label = "tests"; priority = 1 }
            )
            $files = @("app.test.js")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "tests"
        }
    }

    Context "error handling" {
        It "returns empty array for no files" {
            $rules = @(
                [PSCustomObject]@{ pattern = "docs/**"; label = "documentation"; priority = 1 }
            )
            $result = Get-PRLabels -ChangedFiles @() -Rules $rules 3>$null
            $result.Count | Should -Be 0
        }

        It "returns empty array for no rules" {
            $result = Get-PRLabels -ChangedFiles @("docs/readme.md") -Rules @() 3>$null
            $result.Count | Should -Be 0
        }

        It "returns empty when no files match any rules" {
            $rules = @(
                [PSCustomObject]@{ pattern = "docs/**"; label = "documentation"; priority = 1 }
            )
            $files = @("src/index.ts")
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result.Count | Should -Be 0
        }
    }

    Context "complex scenario" {
        It "handles a realistic PR with multiple file types" {
            $rules = @(
                [PSCustomObject]@{ pattern = "docs/**"; label = "documentation"; priority = 1 },
                [PSCustomObject]@{ pattern = "src/api/**"; label = "api"; priority = 2 },
                [PSCustomObject]@{ pattern = "*.test.*"; label = "tests"; priority = 3 },
                [PSCustomObject]@{ pattern = "src/**"; label = "source"; priority = 10 },
                [PSCustomObject]@{ pattern = "*.md"; label = "markdown"; priority = 5 }
            )
            $files = @(
                "docs/guide.md",
                "src/api/handler.ts",
                "app.test.js",
                "src/utils/helper.ts",
                "README.md"
            )
            $result = Get-PRLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "documentation"
            $result | Should -Contain "api"
            $result | Should -Contain "tests"
            $result | Should -Contain "source"
            $result | Should -Contain "markdown"
            $result.Count | Should -Be 5
        }
    }
}
