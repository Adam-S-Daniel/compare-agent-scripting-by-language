# PRLabelAssigner.Tests.ps1
# Pester tests for PR Label Assigner - written FIRST (red phase of TDD)
# Tests are written before the implementation to drive the design.

BeforeAll {
    # Dot-source the module under test
    . "$PSScriptRoot/PRLabelAssigner.ps1"
}

Describe "ConvertGlobToRegex" {
    It "converts a simple extension pattern to regex that matches root-level files" {
        $regex = ConvertGlobToRegex -Pattern "*.md"
        "README.md" | Should -Match $regex
        "guide.md" | Should -Match $regex
    }

    It "does not let single * cross directory separators" {
        $regex = ConvertGlobToRegex -Pattern "src/*.js"
        "src/handler.js" | Should -Match $regex
        "src/api/handler.js" | Should -Not -Match $regex
    }

    It "converts ** to match nested directory paths" {
        $regex = ConvertGlobToRegex -Pattern "docs/**"
        "docs/guide.md" | Should -Match $regex
        "docs/api/index.md" | Should -Match $regex
    }

    It "converts **/ prefix to match anywhere in the tree" {
        $regex = ConvertGlobToRegex -Pattern "**/*.test.js"
        "app.test.js" | Should -Match $regex
        "src/app.test.js" | Should -Match $regex
        "src/components/App.test.js" | Should -Match $regex
    }

    It "returns a regex anchored at start and end" {
        $regex = ConvertGlobToRegex -Pattern "docs/**"
        # Should NOT match if prefix doesn't start at root
        "other/docs/guide.md" | Should -Not -Match $regex
    }
}

Describe "Test-GlobMatch" {
    Context "Simple patterns" {
        It "matches an exact filename" {
            Test-GlobMatch -Path "README.md" -Pattern "README.md" | Should -BeTrue
        }

        It "does not match a different filename" {
            Test-GlobMatch -Path "README.txt" -Pattern "README.md" | Should -BeFalse
        }

        It "matches wildcard extension pattern against a file" {
            Test-GlobMatch -Path "README.md" -Pattern "*.md" | Should -BeTrue
        }

        It "does not match a file with the wrong extension" {
            Test-GlobMatch -Path "script.ps1" -Pattern "*.md" | Should -BeFalse
        }
    }

    Context "Double-star patterns" {
        It "matches a file directly inside the specified directory" {
            Test-GlobMatch -Path "docs/guide.md" -Pattern "docs/**" | Should -BeTrue
        }

        It "matches a file nested several levels deep" {
            Test-GlobMatch -Path "docs/api/v2/index.md" -Pattern "docs/**" | Should -BeTrue
        }

        It "does not match a file outside the specified directory" {
            Test-GlobMatch -Path "src/guide.md" -Pattern "docs/**" | Should -BeFalse
        }

        It "matches src/api nested files" {
            Test-GlobMatch -Path "src/api/handler.js" -Pattern "src/api/**" | Should -BeTrue
        }

        It "does not match src/ files when pattern is src/api/**" {
            Test-GlobMatch -Path "src/utils.js" -Pattern "src/api/**" | Should -BeFalse
        }
    }

    Context "Test file patterns" {
        It "matches .test. files at the root level" {
            Test-GlobMatch -Path "app.test.js" -Pattern "*.test.*" | Should -BeTrue
        }

        It "matches .test. files in a subdirectory (pattern without / matches anywhere)" {
            Test-GlobMatch -Path "src/app.test.js" -Pattern "*.test.*" | Should -BeTrue
        }

        It "matches .test. files deeply nested" {
            Test-GlobMatch -Path "src/components/Button.test.tsx" -Pattern "*.test.*" | Should -BeTrue
        }

        It "does not match non-test files" {
            Test-GlobMatch -Path "app.js" -Pattern "*.test.*" | Should -BeFalse
        }
    }

    Context "Path separator normalization" {
        It "handles Windows-style backslash separators" {
            Test-GlobMatch -Path "docs\guide.md" -Pattern "docs/**" | Should -BeTrue
        }
    }

    Context "Complex patterns" {
        It "matches monorepo package paths with * in directory position" {
            Test-GlobMatch -Path "packages/core/src/index.js" -Pattern "packages/*/src/**" | Should -BeTrue
        }

        It "does not match too-deep patterns for non-** segments" {
            Test-GlobMatch -Path "packages/core/lib/index.js" -Pattern "packages/*/src/**" | Should -BeFalse
        }
    }
}

Describe "Get-PRLabels" {
    # Standard test fixture rules used across multiple tests
    $testRules = @(
        @{ Pattern = "docs/**";    Labels = @("documentation"); Priority = 1 },
        @{ Pattern = "src/api/**"; Labels = @("api");           Priority = 2 },
        @{ Pattern = "*.test.*";   Labels = @("tests");         Priority = 3 },
        @{ Pattern = "src/**";     Labels = @("source");        Priority = 4 }
    )

    Context "Empty and null inputs" {
        It "returns an empty result for an empty file list" {
            $result = Get-PRLabels -ChangedFiles @() -Rules $testRules
            $result | Should -BeNullOrEmpty
        }

        It "returns an empty result for empty rules" {
            $result = Get-PRLabels -ChangedFiles @("docs/guide.md") -Rules @()
            $result | Should -BeNullOrEmpty
        }

        It "returns an empty result when no files match any rule" {
            $result = Get-PRLabels -ChangedFiles @("unknown/file.xyz") -Rules $testRules
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Single label assignment" {
        It "assigns documentation label when only docs files changed" {
            $result = Get-PRLabels -ChangedFiles @("docs/guide.md") -Rules $testRules
            $result | Should -Contain "documentation"
            $result.Count | Should -Be 1
        }

        It "assigns api label for a file under src/api/" {
            $result = Get-PRLabels -ChangedFiles @("src/api/handler.js") -Rules $testRules
            $result | Should -Contain "api"
        }

        It "assigns tests label for a test file" {
            $result = Get-PRLabels -ChangedFiles @("app.test.js") -Rules $testRules
            $result | Should -Contain "tests"
        }
    }

    Context "Multiple labels per file" {
        It "assigns multiple labels when a single file matches multiple rules" {
            # src/api/handler.test.js matches: src/api/**, *.test.*, and src/**
            $result = Get-PRLabels -ChangedFiles @("src/api/handler.test.js") -Rules $testRules
            $result | Should -Contain "api"
            $result | Should -Contain "tests"
            $result | Should -Contain "source"
        }

        It "collects labels from multiple changed files" {
            $files = @("docs/guide.md", "src/api/handler.js")
            $result = Get-PRLabels -ChangedFiles $files -Rules $testRules
            $result | Should -Contain "documentation"
            $result | Should -Contain "api"
        }

        It "collects all labels across a diverse PR" {
            $files = @("docs/guide.md", "src/api/handler.js", "src/utils/helper.test.js")
            $result = Get-PRLabels -ChangedFiles $files -Rules $testRules
            $result | Should -Contain "documentation"
            $result | Should -Contain "api"
            $result | Should -Contain "tests"
            $result | Should -Contain "source"
        }
    }

    Context "Label deduplication" {
        It "does not produce duplicate labels when multiple files match the same rule" {
            $files = @("docs/guide.md", "docs/api.md", "docs/reference.md")
            $result = Get-PRLabels -ChangedFiles $files -Rules $testRules
            ($result | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
        }

        It "deduplicates when a label appears in multiple rules" {
            $rules = @(
                @{ Pattern = "src/**";     Labels = @("source", "backend"); Priority = 1 },
                @{ Pattern = "src/api/**"; Labels = @("api", "backend");    Priority = 2 }
            )
            $result = Get-PRLabels -ChangedFiles @("src/api/handler.js") -Rules $rules
            ($result | Where-Object { $_ -eq "backend" }).Count | Should -Be 1
        }
    }

    Context "Priority ordering" {
        It "labels from higher-priority rules appear before lower-priority rule labels" {
            # api (priority 2) must appear before source (priority 4)
            $result = @(Get-PRLabels -ChangedFiles @("src/api/handler.js") -Rules $testRules)
            $apiIndex    = [array]::IndexOf($result, "api")
            $sourceIndex = [array]::IndexOf($result, "source")
            $apiIndex | Should -BeLessThan $sourceIndex
        }

        It "when the same label is shared by two rules, position is set by the higher-priority rule" {
            $rules = @(
                @{ Pattern = "src/api/**"; Labels = @("api", "backend"); Priority = 1 },
                @{ Pattern = "src/**";     Labels = @("source", "backend"); Priority = 2 }
            )
            $result = @(Get-PRLabels -ChangedFiles @("src/api/handler.js") -Rules $rules)
            # "backend" was first seen from priority-1 rule, so it must precede "source"
            $backendIndex = [array]::IndexOf($result, "backend")
            $sourceIndex  = [array]::IndexOf($result, "source")
            $backendIndex | Should -BeLessThan $sourceIndex
        }
    }

    Context "Mock PR scenarios" {
        It "documentation-only PR gets only documentation label" {
            $prFiles = @(
                "docs/README.md",
                "docs/api/endpoints.md",
                "docs/guides/quickstart.md"
            )
            $result = Get-PRLabels -ChangedFiles $prFiles -Rules $testRules
            $result | Should -Contain "documentation"
            $result | Should -Not -Contain "api"
            $result | Should -Not -Contain "tests"
            $result | Should -Not -Contain "source"
        }

        It "API feature PR with tests gets api, tests, source, documentation labels" {
            $prFiles = @(
                "src/api/users.js",
                "src/api/users.test.js",
                "docs/api/users.md"
            )
            $result = Get-PRLabels -ChangedFiles $prFiles -Rules $testRules
            $result | Should -Contain "api"
            $result | Should -Contain "tests"
            $result | Should -Contain "documentation"
            $result | Should -Contain "source"
        }

        It "pure source code change gets only source label" {
            $prFiles = @(
                "src/utils/helper.js",
                "src/models/user.js"
            )
            $result = Get-PRLabels -ChangedFiles $prFiles -Rules $testRules
            $result | Should -Contain "source"
            $result | Should -Not -Contain "documentation"
            $result | Should -Not -Contain "api"
            $result | Should -Not -Contain "tests"
        }
    }

    Context "Custom rule configurations" {
        It "supports a rule that assigns multiple labels at once" {
            $rules = @(
                @{ Pattern = "*.config.*"; Labels = @("configuration", "infrastructure"); Priority = 1 }
            )
            $result = Get-PRLabels -ChangedFiles @("webpack.config.js") -Rules $rules
            $result | Should -Contain "configuration"
            $result | Should -Contain "infrastructure"
        }

        It "supports monorepo package path patterns" {
            $rules = @(
                @{ Pattern = "packages/*/src/**"; Labels = @("monorepo-change"); Priority = 1 }
            )
            $result = Get-PRLabels -ChangedFiles @("packages/core/src/index.js") -Rules $rules
            $result | Should -Contain "monorepo-change"
        }
    }
}
