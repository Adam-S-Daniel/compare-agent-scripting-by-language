# Invoke-PRLabelAssigner.Tests.ps1
# Unit tests for the PR Label Assigner script using Pester.
#
# TDD progression (Red -> Green cycles):
#   Iteration 1: ConvertTo-GlobRegex basic patterns
#   Iteration 2: Get-PRLabels basic single-rule match
#   Iteration 3: Multiple files / deduplication
#   Iteration 4: ** glob pattern matching
#   Iteration 5: Multiple labels per file (multi-rule match)
#   Iteration 6: Priority ordering
#   Iteration 7: Error handling / edge cases

BeforeAll {
    # Dot-source the script to load functions without executing the entry point.
    . "$PSScriptRoot/Invoke-PRLabelAssigner.ps1"
}

# ---------------------------------------------------------------------------
# TDD Iteration 1 (Red first): ConvertTo-GlobRegex
# ---------------------------------------------------------------------------
Describe "ConvertTo-GlobRegex" {
    Context "docs/** pattern" {
        It "matches docs/README.md" {
            $regex = ConvertTo-GlobRegex -Pattern "docs/**"
            "docs/README.md" | Should -Match $regex
        }

        It "matches docs/sub/file.md (nested)" {
            $regex = ConvertTo-GlobRegex -Pattern "docs/**"
            "docs/sub/file.md" | Should -Match $regex
        }

        It "does not match src/README.md" {
            $regex = ConvertTo-GlobRegex -Pattern "docs/**"
            "src/README.md" | Should -Not -Match $regex
        }
    }

    Context "src/api/** pattern" {
        It "matches src/api/endpoint.js" {
            $regex = ConvertTo-GlobRegex -Pattern "src/api/**"
            "src/api/endpoint.js" | Should -Match $regex
        }

        It "does not match src/utils.js" {
            $regex = ConvertTo-GlobRegex -Pattern "src/api/**"
            "src/utils.js" | Should -Not -Match $regex
        }
    }

    Context "*.test.* pattern (root-only)" {
        It "matches utils.test.js at root" {
            $regex = ConvertTo-GlobRegex -Pattern "*.test.*"
            "utils.test.js" | Should -Match $regex
        }

        It "does not match src/utils.test.js (nested)" {
            $regex = ConvertTo-GlobRegex -Pattern "*.test.*"
            "src/utils.test.js" | Should -Not -Match $regex
        }
    }

    Context "**/*.test.* pattern (any depth)" {
        It "matches utils.test.js at root" {
            $regex = ConvertTo-GlobRegex -Pattern "**/*.test.*"
            "utils.test.js" | Should -Match $regex
        }

        It "matches src/utils.test.js" {
            $regex = ConvertTo-GlobRegex -Pattern "**/*.test.*"
            "src/utils.test.js" | Should -Match $regex
        }

        It "matches deeply nested a/b/c/api.test.ts" {
            $regex = ConvertTo-GlobRegex -Pattern "**/*.test.*"
            "a/b/c/api.test.ts" | Should -Match $regex
        }

        It "does not match src/utils.js" {
            $regex = ConvertTo-GlobRegex -Pattern "**/*.test.*"
            "src/utils.js" | Should -Not -Match $regex
        }
    }

    Context "? single-character wildcard" {
        It "matches src/v1/api.js with src/v?/api.js" {
            $regex = ConvertTo-GlobRegex -Pattern "src/v?/api.js"
            "src/v1/api.js" | Should -Match $regex
        }

        It "does not match src/v10/api.js with src/v?/api.js" {
            $regex = ConvertTo-GlobRegex -Pattern "src/v?/api.js"
            "src/v10/api.js" | Should -Not -Match $regex
        }
    }

    Context "Regex special characters are escaped" {
        It "matches file.js literally (dot is not a regex wildcard)" {
            $regex = ConvertTo-GlobRegex -Pattern "src/file.js"
            "src/fileXjs" | Should -Not -Match $regex
        }

        It "matches src/file.js correctly" {
            $regex = ConvertTo-GlobRegex -Pattern "src/file.js"
            "src/file.js" | Should -Match $regex
        }
    }
}

# ---------------------------------------------------------------------------
# TDD Iteration 2 (Red first): Get-PRLabels basic match
# ---------------------------------------------------------------------------
Describe "Get-PRLabels" {
    Context "Basic single-rule match" {
        It "returns 'documentation' for docs/README.md" {
            $files = @("docs/README.md")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "documentation"
        }

        It "returns 'api' for src/api/endpoint.js" {
            $files = @("src/api/endpoint.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "api"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "api"
        }

        It "returns empty collection when no rule matches" {
            $files = @("src/main.py")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels.Count | Should -Be 0
        }
    }

    # ---------------------------------------------------------------------------
    # TDD Iteration 3: Multiple files and deduplication
    # ---------------------------------------------------------------------------
    Context "Multiple files" {
        It "returns labels for all matched files" {
            $files = @("docs/README.md", "src/api/endpoint.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"; Priority = 1},
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "api"; Priority = 2}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "documentation"
            $labels | Should -Contain "api"
        }

        It "deduplicates labels when multiple files match the same rule" {
            $files = @("docs/README.md", "docs/API.md")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            ($labels | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
        }
    }

    # ---------------------------------------------------------------------------
    # TDD Iteration 4: ** glob pattern
    # ---------------------------------------------------------------------------
    Context "Glob patterns with **" {
        It "matches nested test files with **/*.test.* pattern" {
            $files = @("src/utils.test.js", "src/api/api.test.ts")
            $rules = @(
                [PSCustomObject]@{Pattern = "**/*.test.*"; Label = "tests"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "tests"
        }

        It "does not label non-test files with **/*.test.* pattern" {
            $files = @("src/utils.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "**/*.test.*"; Label = "tests"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Not -Contain "tests"
        }
    }

    # ---------------------------------------------------------------------------
    # TDD Iteration 5: Multiple labels per file (multi-rule)
    # ---------------------------------------------------------------------------
    Context "Multiple labels per file" {
        It "applies both 'api' and 'tests' labels to src/api/api.test.ts" {
            $files = @("src/api/api.test.ts")
            $rules = @(
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "api"; Priority = 2},
                [PSCustomObject]@{Pattern = "**/*.test.*"; Label = "tests"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "api"
            $labels | Should -Contain "tests"
        }

        It "applies all three labels when file matches three rules" {
            $files = @("src/api/endpoint.test.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "src/**"; Label = "backend"; Priority = 5},
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "api"; Priority = 10},
                [PSCustomObject]@{Pattern = "**/*.test.*"; Label = "tests"; Priority = 3}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "backend"
            $labels | Should -Contain "api"
            $labels | Should -Contain "tests"
        }
    }

    # ---------------------------------------------------------------------------
    # TDD Iteration 6: Priority ordering
    # ---------------------------------------------------------------------------
    Context "Priority ordering" {
        It "returns labels sorted by priority (highest first)" {
            $files = @("src/api/endpoint.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "src/**"; Label = "backend"; Priority = 5},
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "api"; Priority = 10}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels[0] | Should -Be "api"     # priority=10 first
            $labels[1] | Should -Be "backend" # priority=5 second
        }

        It "returns all labels regardless of priority ordering" {
            $files = @("src/api/endpoint.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "src/**"; Label = "backend"; Priority = 5},
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "api"; Priority = 10}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels.Count | Should -Be 2
        }

        It "uses highest priority when same label matched by multiple rules" {
            $files = @("src/api/endpoint.js")
            $rules = @(
                [PSCustomObject]@{Pattern = "src/**"; Label = "backend"; Priority = 5},
                [PSCustomObject]@{Pattern = "src/api/**"; Label = "backend"; Priority = 10}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            ($labels | Where-Object { $_ -eq "backend" }).Count | Should -Be 1
        }

        It "uses 0 as default priority when Priority property is missing" {
            $files = @("docs/README.md")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"}
            )
            { Get-PRLabels -ChangedFiles $files -Rules $rules } | Should -Not -Throw
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "documentation"
        }
    }

    # ---------------------------------------------------------------------------
    # TDD Iteration 7: Error handling and edge cases
    # ---------------------------------------------------------------------------
    Context "Error handling" {
        It "handles empty file list gracefully" {
            $files = @()
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels.Count | Should -Be 0
        }

        It "handles empty rules list gracefully" {
            $files = @("docs/README.md")
            $rules = @()
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels.Count | Should -Be 0
        }

        It "throws a meaningful error for rule missing Pattern property" {
            $files = @("docs/README.md")
            $rules = @(
                [PSCustomObject]@{Label = "documentation"; Priority = 1}
            )
            { Get-PRLabels -ChangedFiles $files -Rules $rules } | Should -Throw "*Pattern*"
        }

        It "throws a meaningful error for rule missing Label property" {
            $files = @("docs/README.md")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Priority = 1}
            )
            { Get-PRLabels -ChangedFiles $files -Rules $rules } | Should -Throw "*Label*"
        }

        It "handles Windows-style backslash path separators" {
            $files = @("docs\README.md")
            $rules = @(
                [PSCustomObject]@{Pattern = "docs/**"; Label = "documentation"; Priority = 1}
            )
            $labels = Get-PRLabels -ChangedFiles $files -Rules $rules
            $labels | Should -Contain "documentation"
        }
    }
}
