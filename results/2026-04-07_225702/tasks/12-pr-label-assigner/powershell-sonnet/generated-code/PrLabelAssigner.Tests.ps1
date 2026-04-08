# PrLabelAssigner.Tests.ps1
# TDD tests for PR Label Assigner using Pester
# Approach: red/green cycles - each Describe block adds new functionality

BeforeAll {
    # Import the module under test (will fail until PrLabelAssigner.ps1 exists)
    . "$PSScriptRoot/PrLabelAssigner.ps1"
}

# =============================================================================
# Cycle 1: Basic single-rule exact-ish pattern matching
# =============================================================================
Describe "Get-PRLabels - Single rule matching" {
    It "returns an empty array when no files are provided" {
        $rules = @(
            @{ Pattern = "docs/*"; Labels = @("documentation"); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @() -Rules $rules
        $result | Should -BeNullOrEmpty
    }

    It "returns an empty array when no rules are provided" {
        $result = Get-PRLabels -ChangedFiles @("src/main.ps1") -Rules @()
        $result | Should -BeNullOrEmpty
    }

    It "applies a label when a file matches a simple wildcard pattern" {
        $rules = @(
            @{ Pattern = "docs/*"; Labels = @("documentation"); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @("docs/README.md") -Rules $rules
        $result | Should -Contain "documentation"
    }

    It "does not apply a label when no file matches the pattern" {
        $rules = @(
            @{ Pattern = "docs/*"; Labels = @("documentation"); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/main.ps1") -Rules $rules
        $result | Should -Not -Contain "documentation"
    }
}

# =============================================================================
# Cycle 2: Glob pattern support — ** (recursive), *.ext.* (double-extension)
# =============================================================================
Describe "Get-PRLabels - Glob pattern support" {
    It "matches files in subdirectories with ** glob" {
        $rules = @(
            @{ Pattern = "docs/**"; Labels = @("documentation"); Priority = 1 }
        )
        $files = @(
            "docs/getting-started.md",
            "docs/api/overview.md",
            "docs/api/v2/endpoints.md"
        )
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        $result | Should -Contain "documentation"
        ($result | Measure-Object).Count | Should -Be 1
    }

    It "matches files in a nested API directory with ** glob" {
        $rules = @(
            @{ Pattern = "src/api/**"; Labels = @("api"); Priority = 1 }
        )
        $files = @("src/api/users.ts", "src/api/v2/products.ts")
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        $result | Should -Contain "api"
    }

    It "does not match files outside the pattern scope with **" {
        $rules = @(
            @{ Pattern = "src/api/**"; Labels = @("api"); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/utils/helpers.ts") -Rules $rules
        $result | Should -Not -Contain "api"
    }

    It "matches test files using *.test.* pattern anywhere in the tree" {
        $rules = @(
            @{ Pattern = "*.test.*"; Labels = @("tests"); Priority = 1 }
        )
        $files = @("src/users.test.ts", "lib/utils.test.js")
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        $result | Should -Contain "tests"
    }

    It "does not match non-test files with *.test.* pattern" {
        $rules = @(
            @{ Pattern = "*.test.*"; Labels = @("tests"); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/users.ts") -Rules $rules
        $result | Should -Not -Contain "tests"
    }

    It "matches spec files using **/*.spec.* pattern" {
        $rules = @(
            @{ Pattern = "**/*.spec.*"; Labels = @("tests"); Priority = 1 }
        )
        $files = @("src/components/Button.spec.tsx", "tests/api/users.spec.ts")
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        $result | Should -Contain "tests"
    }
}

# =============================================================================
# Cycle 3: Multiple labels per file (one file matches multiple rules)
# =============================================================================
Describe "Get-PRLabels - Multiple labels per file" {
    It "applies multiple labels when a file matches multiple rules" {
        # src/api/users.test.ts matches both api and tests rules
        $rules = @(
            @{ Pattern = "src/api/**"; Labels = @("api");   Priority = 1 }
            @{ Pattern = "*.test.*";   Labels = @("tests"); Priority = 2 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/api/users.test.ts") -Rules $rules
        $result | Should -Contain "api"
        $result | Should -Contain "tests"
    }

    It "combines labels from all matching rules across all files" {
        $rules = @(
            @{ Pattern = "docs/**";    Labels = @("documentation"); Priority = 1 }
            @{ Pattern = "src/api/**"; Labels = @("api");           Priority = 2 }
        )
        $files = @("docs/overview.md", "src/api/endpoints.ts")
        $result = Get-PRLabels -ChangedFiles $files -Rules $rules
        $result | Should -Contain "documentation"
        $result | Should -Contain "api"
    }

    It "a single rule can assign multiple labels" {
        $rules = @(
            @{ Pattern = "src/api/**"; Labels = @("api", "backend"); Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/api/users.ts") -Rules $rules
        $result | Should -Contain "api"
        $result | Should -Contain "backend"
    }
}

# =============================================================================
# Cycle 4: Deduplication — same label from multiple rules appears only once
# =============================================================================
Describe "Get-PRLabels - Label deduplication" {
    It "deduplicates labels when multiple rules produce the same label" {
        $rules = @(
            @{ Pattern = "src/**";     Labels = @("backend"); Priority = 1 }
            @{ Pattern = "src/api/**"; Labels = @("backend"); Priority = 2 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/api/users.ts") -Rules $rules
        ($result | Where-Object { $_ -eq "backend" } | Measure-Object).Count | Should -Be 1
    }

    It "returns a sorted label set" {
        $rules = @(
            @{ Pattern = "*.test.*";   Labels = @("tests");   Priority = 2 }
            @{ Pattern = "src/api/**"; Labels = @("api");     Priority = 1 }
        )
        $result = Get-PRLabels -ChangedFiles @("src/api/users.test.ts") -Rules $rules
        $result | Should -Be @("api", "tests")
    }
}

# =============================================================================
# Cycle 5: Priority ordering — higher-priority rules evaluated first
# =============================================================================
Describe "Get-PRLabels - Priority ordering" {
    It "respects priority: lower number = higher priority evaluated first" {
        # When the same file matches both, we still get both labels
        # Priority matters for conflict resolution in exclusive scenarios
        $rules = @(
            @{ Pattern = "src/**";     Labels = @("backend"); Priority = 10 }
            @{ Pattern = "src/api/**"; Labels = @("api");     Priority = 1  }
        )
        $result = Get-PRLabels -ChangedFiles @("src/api/users.ts") -Rules $rules
        # Both should be present — no conflict, just accumulate
        $result | Should -Contain "backend"
        $result | Should -Contain "api"
    }

    It "when Priority is omitted it defaults to lowest priority (999)" {
        # Rules without Priority should still work, treated as lowest priority
        $rules = @(
            @{ Pattern = "src/**"; Labels = @("backend") }
        )
        $result = Get-PRLabels -ChangedFiles @("src/main.ts") -Rules $rules
        $result | Should -Contain "backend"
    }

    It "exclusive labels: only the highest-priority matching rule's label wins when ExclusiveGroup is set" {
        # Use case: size labels — only one of small/medium/large should apply
        $rules = @(
            @{ Pattern = "src/**";     Labels = @("large");  Priority = 10; ExclusiveGroup = "size" }
            @{ Pattern = "src/api/**"; Labels = @("medium"); Priority = 5;  ExclusiveGroup = "size" }
            @{ Pattern = "src/api/**"; Labels = @("small");  Priority = 1;  ExclusiveGroup = "size" }
        )
        $result = Get-PRLabels -ChangedFiles @("src/api/users.ts") -Rules $rules
        # Only highest-priority (lowest Priority number) label per group should win
        $result | Should -Contain "small"
        $result | Should -Not -Contain "medium"
        $result | Should -Not -Contain "large"
    }
}

# =============================================================================
# Cycle 6: Mock file list + full integration scenario
# =============================================================================
Describe "Get-PRLabels - Integration with mock file list" {
    BeforeAll {
        # Mock PR file list simulating a real pull request
        $script:MockPRFiles = @(
            "docs/api/overview.md",
            "docs/contributing.md",
            "src/api/users.ts",
            "src/api/products.ts",
            "src/api/users.test.ts",
            "src/utils/helpers.ts",
            "src/components/Button.tsx",
            "src/components/Button.spec.tsx",
            ".github/workflows/ci.yml",
            "package.json"
        )

        # Configurable label rules
        $script:LabelRules = @(
            @{ Pattern = "docs/**";               Labels = @("documentation");  Priority = 1 }
            @{ Pattern = "src/api/**";             Labels = @("api");            Priority = 2 }
            @{ Pattern = "src/components/**";      Labels = @("frontend");       Priority = 3 }
            @{ Pattern = "*.test.*";               Labels = @("tests");          Priority = 4 }
            @{ Pattern = "**/*.spec.*";            Labels = @("tests");          Priority = 4 }
            @{ Pattern = ".github/**";             Labels = @("ci/cd");          Priority = 5 }
            @{ Pattern = "package.json";           Labels = @("dependencies");   Priority = 6 }
            @{ Pattern = "src/**";                 Labels = @("backend");        Priority = 7 }
        )
    }

    It "produces the correct label set for the mock PR" {
        $result = Get-PRLabels -ChangedFiles $script:MockPRFiles -Rules $script:LabelRules

        $result | Should -Contain "documentation"
        $result | Should -Contain "api"
        $result | Should -Contain "frontend"
        $result | Should -Contain "tests"
        $result | Should -Contain "ci/cd"
        $result | Should -Contain "dependencies"
        $result | Should -Contain "backend"
    }

    It "returns a sorted, deduplicated label array" {
        $result = Get-PRLabels -ChangedFiles $script:MockPRFiles -Rules $script:LabelRules
        $sorted = $result | Sort-Object
        $result | Should -Be $sorted
        ($result | Measure-Object).Count | Should -Be ($result | Select-Object -Unique | Measure-Object).Count
    }
}

# =============================================================================
# Cycle 7: Error handling
# =============================================================================
Describe "Get-PRLabels - Error handling" {
    It "throws a meaningful error when Rules is null" {
        { Get-PRLabels -ChangedFiles @("src/main.ts") -Rules $null } |
            Should -Throw "*Rules*"
    }

    It "throws a meaningful error when a rule is missing the Pattern key" {
        $badRules = @(
            @{ Labels = @("api"); Priority = 1 }
        )
        { Get-PRLabels -ChangedFiles @("src/main.ts") -Rules $badRules } |
            Should -Throw "*Pattern*"
    }

    It "throws a meaningful error when a rule is missing the Labels key" {
        $badRules = @(
            @{ Pattern = "src/**"; Priority = 1 }
        )
        { Get-PRLabels -ChangedFiles @("src/main.ts") -Rules $badRules } |
            Should -Throw "*Labels*"
    }
}

# =============================================================================
# Cycle 8: ConvertTo-GlobRegex helper (unit tests for the regex converter)
# =============================================================================
Describe "ConvertTo-GlobRegex - Pattern conversion" {
    It "converts * to match any non-separator characters" {
        $regex = ConvertTo-GlobRegex -Pattern "*.md"
        "README.md"     | Should -Match $regex
        "src/README.md" | Should -Not -Match $regex
    }

    It "converts ** to match across path separators" {
        $regex = ConvertTo-GlobRegex -Pattern "docs/**"
        "docs/readme.md"         | Should -Match $regex
        "docs/api/overview.md"   | Should -Match $regex
        "src/readme.md"          | Should -Not -Match $regex
    }

    It "converts ? to match a single non-separator character" {
        $regex = ConvertTo-GlobRegex -Pattern "src/?.ts"
        "src/a.ts" | Should -Match $regex
        "src/ab.ts" | Should -Not -Match $regex
    }

    It "escapes regex special characters in literal parts of the pattern" {
        $regex = ConvertTo-GlobRegex -Pattern "package.json"
        "package.json" | Should -Match $regex
        # Without escaping, . would match any char; verify it doesn't match packageXjson
        "packageXjson" | Should -Not -Match $regex
    }
}
