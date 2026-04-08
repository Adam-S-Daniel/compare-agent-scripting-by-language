BeforeAll {
    . $PSScriptRoot/PrLabelAssigner.ps1
}

Describe "Get-PrLabels" {

    Context "Basic glob matching" {
        It "assigns a label when a file matches a simple glob pattern" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation" }
            )
            $files = @("docs/readme.md")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "documentation"
        }

        It "assigns no labels when no files match" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation" }
            )
            $files = @("src/main.ps1")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -BeNullOrEmpty
        }

        It "matches extension glob patterns like *.test.*" {
            $rules = @(
                @{ Pattern = "*.test.*"; Label = "tests" }
            )
            $files = @("src/utils.test.js")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "tests"
        }
    }

    Context "Multiple labels" {
        It "assigns multiple labels when a file matches multiple rules" {
            $rules = @(
                @{ Pattern = "src/api/**"; Label = "api" },
                @{ Pattern = "*.js"; Label = "javascript" }
            )
            $files = @("src/api/handler.js")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "api"
            $result | Should -Contain "javascript"
        }

        It "does not duplicate labels when multiple files match the same rule" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation" }
            )
            $files = @("docs/readme.md", "docs/guide.md")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -HaveCount 1
            $result | Should -Contain "documentation"
        }

        It "collects labels from different files matching different rules" {
            $rules = @(
                @{ Pattern = "docs/**"; Label = "documentation" },
                @{ Pattern = "src/**"; Label = "source" }
            )
            $files = @("docs/readme.md", "src/main.ps1")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "documentation"
            $result | Should -Contain "source"
            $result | Should -HaveCount 2
        }
    }

    Context "Priority ordering" {
        It "applies only the highest-priority label when rules conflict on the same file" {
            # Lower Priority number = higher precedence
            # When two rules match the same file and conflict, only the higher-priority wins
            $rules = @(
                @{ Pattern = "src/**"; Label = "general"; Priority = 10 },
                @{ Pattern = "src/api/**"; Label = "api"; Priority = 1 }
            )
            $files = @("src/api/handler.js")
            # With priority conflict resolution, the higher-priority (lower number) label wins
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "api"
            $result | Should -Not -Contain "general"
        }

        It "applies all labels when there is no conflict (different files)" {
            $rules = @(
                @{ Pattern = "src/api/**"; Label = "api"; Priority = 1 },
                @{ Pattern = "docs/**"; Label = "documentation"; Priority = 5 }
            )
            $files = @("src/api/handler.js", "docs/readme.md")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "api"
            $result | Should -Contain "documentation"
        }

        It "uses default priority of 0 when not specified" {
            $rules = @(
                @{ Pattern = "src/**"; Label = "source" },
                @{ Pattern = "src/api/**"; Label = "api"; Priority = 1 }
            )
            $files = @("src/api/handler.js")
            # Default priority 0 < 1, so "source" wins over "api"
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "source"
            $result | Should -Not -Contain "api"
        }
    }

    Context "Error handling and edge cases" {
        It "warns and skips rules missing the Pattern key" {
            $rules = @(
                @{ Label = "orphan" },
                @{ Pattern = "docs/**"; Label = "documentation" }
            )
            $files = @("docs/readme.md")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules 3>&1
            # Should still return the valid rule's label
            $result | Should -Contain "documentation"
        }

        It "warns and skips rules missing the Label key" {
            $rules = @(
                @{ Pattern = "src/**" },
                @{ Pattern = "docs/**"; Label = "documentation" }
            )
            $files = @("docs/readme.md")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules 3>&1
            $result | Should -Contain "documentation"
        }

        It "handles deeply nested file paths with ** pattern" {
            $rules = @(
                @{ Pattern = "src/**"; Label = "source" }
            )
            $files = @("src/a/b/c/d/deep.js")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "source"
        }

        It "handles single-character wildcard ?" {
            $rules = @(
                @{ Pattern = "src/?.js"; Label = "short-name" }
            )
            $files = @("src/a.js")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -Contain "short-name"
        }

        It "does not match ? against multi-character filenames" {
            $rules = @(
                @{ Pattern = "src/?.js"; Label = "short-name" }
            )
            $files = @("src/ab.js")
            $result = Get-PrLabels -ChangedFiles $files -Rules $rules
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Convert-GlobToRegex" {
        It "converts ** to match any path depth" {
            $regex = Convert-GlobToRegex -GlobPattern "src/**"
            "src/foo/bar.js" | Should -Match $regex
            "src/a.js" | Should -Match $regex
        }

        It "converts * to match within a single segment" {
            $regex = Convert-GlobToRegex -GlobPattern "src/*.js"
            "src/main.js" | Should -Match $regex
            "src/sub/main.js" | Should -Not -Match $regex
        }

        It "escapes regex special characters in patterns" {
            # A pattern with a literal dot should not match arbitrary characters
            $regex = Convert-GlobToRegex -GlobPattern "src/file.txt"
            "src/file.txt" | Should -Match $regex
            "src/fileXtxt" | Should -Not -Match $regex
        }
    }

    Context "Realistic integration scenario" {
        It "labels a realistic PR with mixed file changes" {
            $rules = @(
                @{ Pattern = "docs/**";       Label = "documentation"; Priority = 5 },
                @{ Pattern = "src/api/**";     Label = "api";           Priority = 1 },
                @{ Pattern = "src/**";         Label = "source";        Priority = 10 },
                @{ Pattern = "*.test.*";       Label = "tests";         Priority = 3 },
                @{ Pattern = "*.md";           Label = "markdown";      Priority = 8 },
                @{ Pattern = ".github/**";     Label = "ci";            Priority = 2 }
            )

            $files = @(
                "src/api/users.js",       # matches src/api/** (pri 1) and src/** (pri 10) -> api wins
                "src/utils/helpers.js",    # matches src/** (pri 10) only -> source
                "docs/setup.md",          # matches docs/** (pri 5) and *.md (pri 8) -> documentation wins
                "tests/api.test.js",      # matches *.test.* (pri 3) only -> tests
                ".github/workflows/ci.yml" # matches .github/** (pri 2) -> ci
            )

            $result = Get-PrLabels -ChangedFiles $files -Rules $rules

            $result | Should -Contain "api"
            $result | Should -Contain "source"
            $result | Should -Contain "documentation"
            $result | Should -Contain "tests"
            $result | Should -Contain "ci"
            # "general" from src/** should NOT appear for src/api/users.js (api has higher priority)
            # "markdown" should NOT appear for docs/setup.md (documentation has higher priority)
            $result | Should -Not -Contain "markdown"
        }
    }
}
