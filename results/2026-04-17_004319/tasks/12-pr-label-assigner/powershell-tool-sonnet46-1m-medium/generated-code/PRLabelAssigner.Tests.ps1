#Requires -Modules Pester

# TDD test suite for PR Label Assigner
# Red/Green cycle: write failing test, implement minimum code, refactor

BeforeAll {
    . "$PSScriptRoot/PRLabelAssigner.ps1"
}

Describe "Convert-GlobToRegex" {
    # RED: First failing test - basic glob to regex conversion
    It "converts literal path to regex" {
        $result = Convert-GlobToRegex "README.md"
        "README.md" | Should -Match $result
        "README.txt" | Should -Not -Match $result
    }

    It "converts * wildcard (no path separator)" {
        $result = Convert-GlobToRegex "*.md"
        "README.md" | Should -Match $result
        "docs/README.md" | Should -Not -Match $result
    }

    It "converts ** wildcard (any path)" {
        $result = Convert-GlobToRegex "docs/**"
        "docs/README.md" | Should -Match $result
        "docs/api/index.md" | Should -Match $result
        "src/index.ts" | Should -Not -Match $result
    }

    It "converts ** at root" {
        $result = Convert-GlobToRegex "**/*.test.*"
        "src/foo.test.ts" | Should -Match $result
        "foo.test.js" | Should -Match $result
        "src/api/bar.test.py" | Should -Match $result
        "src/foo.ts" | Should -Not -Match $result
    }

    It "converts ? wildcard (single char, no separator)" {
        $result = Convert-GlobToRegex "src/?.ts"
        "src/a.ts" | Should -Match $result
        "src/ab.ts" | Should -Not -Match $result
        "src/a/b.ts" | Should -Not -Match $result
    }

    It "escapes regex special characters in literal portions" {
        $result = Convert-GlobToRegex "src/api/v1.ts"
        "src/api/v1.ts" | Should -Match $result
        "src/api/v1Xts" | Should -Not -Match $result
    }
}

Describe "Test-GlobMatch" {
    It "matches simple filename glob" {
        Test-GlobMatch -Path "README.md" -Pattern "*.md" | Should -BeTrue
    }

    It "does not match across directories with single *" {
        Test-GlobMatch -Path "docs/README.md" -Pattern "*.md" | Should -BeFalse
    }

    It "matches docs/** pattern" {
        Test-GlobMatch -Path "docs/guide/intro.md" -Pattern "docs/**" | Should -BeTrue
    }

    It "matches src/api/** pattern" {
        Test-GlobMatch -Path "src/api/users.ts" -Pattern "src/api/**" | Should -BeTrue
        Test-GlobMatch -Path "src/lib/utils.ts" -Pattern "src/api/**" | Should -BeFalse
    }

    It "matches *.test.* pattern for test files" {
        Test-GlobMatch -Path "foo.test.ts" -Pattern "*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "foo.spec.ts" -Pattern "*.test.*" | Should -BeFalse
    }

    It "matches **/*.test.* across any directory depth" {
        Test-GlobMatch -Path "src/api/users.test.ts" -Pattern "**/*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "src/api/users.ts" -Pattern "**/*.test.*" | Should -BeFalse
    }
}

Describe "Get-PRLabels" {
    BeforeAll {
        # Mock label rules configuration
        $script:TestRules = @(
            @{ Pattern = "docs/**";       Label = "documentation"; Priority = 10 },
            @{ Pattern = "**/*.md";       Label = "documentation"; Priority = 10 },
            @{ Pattern = "src/api/**";    Label = "api";           Priority = 20 },
            @{ Pattern = "**/*.test.*";   Label = "tests";         Priority = 30 },
            @{ Pattern = "**/*.spec.*";   Label = "tests";         Priority = 30 },
            @{ Pattern = "src/**";        Label = "source";        Priority = 5  },
            @{ Pattern = ".github/**";    Label = "ci/cd";         Priority = 40 },
            @{ Pattern = "*.config.*";    Label = "config";        Priority = 15 }
        )
    }

    It "returns documentation label for docs files" {
        $files = @("docs/guide/intro.md", "docs/api/reference.md")
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        $labels | Should -Contain "documentation"
    }

    It "returns api label for src/api files" {
        $files = @("src/api/users.ts", "src/api/orders.ts")
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        $labels | Should -Contain "api"
    }

    It "returns tests label for test files" {
        $files = @("src/utils.test.ts", "src/api/users.spec.ts")
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        $labels | Should -Contain "tests"
    }

    It "returns multiple labels when multiple rules match" {
        # src/api/users.test.ts matches both api and tests
        $files = @("src/api/users.test.ts")
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        $labels | Should -Contain "api"
        $labels | Should -Contain "tests"
        $labels | Should -Contain "source"
    }

    It "returns unique labels (no duplicates)" {
        $files = @("docs/guide.md", "docs/api.md", "docs/intro.md")
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        ($labels | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
    }

    It "returns empty array when no rules match" {
        $files = @("random-file.xyz")
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        $labels | Should -BeNullOrEmpty
    }

    It "handles mixed file types and returns all applicable labels" {
        $files = @(
            "docs/README.md",
            "src/api/endpoint.ts",
            "src/api/endpoint.test.ts",
            ".github/workflows/ci.yml"
        )
        $labels = Get-PRLabels -Files $files -Rules $script:TestRules
        $labels | Should -Contain "documentation"
        $labels | Should -Contain "api"
        $labels | Should -Contain "tests"
        $labels | Should -Contain "ci/cd"
        $labels | Should -Contain "source"
    }

    It "handles empty file list" {
        $labels = Get-PRLabels -Files @() -Rules $script:TestRules
        $labels | Should -BeNullOrEmpty
    }
}

Describe "Priority Ordering" {
    It "returns labels sorted by priority descending" {
        $rules = @(
            @{ Pattern = "src/**";     Label = "source";  Priority = 5  },
            @{ Pattern = "src/api/**"; Label = "api";     Priority = 20 },
            @{ Pattern = "**/*.test.*"; Label = "tests";  Priority = 30 }
        )
        $files = @("src/api/users.test.ts")
        $labels = Get-PRLabels -Files $files -Rules $rules -SortByPriority
        # Higher priority labels should come first
        $labels[0] | Should -Be "tests"
        $labels[1] | Should -Be "api"
        $labels[2] | Should -Be "source"
    }
}

Describe "Get-PRLabels with mock file list" {
    # Mock file list simulating a real PR's changed files
    BeforeAll {
        $script:MockPRFiles = @(
            "src/api/v1/users.ts",
            "src/api/v1/orders.ts",
            "src/api/v1/users.test.ts",
            "src/lib/utils.ts",
            "docs/api/users.md",
            "docs/setup.md",
            ".github/workflows/ci.yml",
            "jest.config.ts",
            "README.md"
        )

        $script:DefaultRules = @(
            @{ Pattern = "docs/**";      Label = "documentation"; Priority = 10 },
            @{ Pattern = "**/*.md";      Label = "documentation"; Priority = 10 },
            @{ Pattern = "src/api/**";   Label = "api";           Priority = 20 },
            @{ Pattern = "**/*.test.*";  Label = "tests";         Priority = 30 },
            @{ Pattern = "**/*.spec.*";  Label = "tests";         Priority = 30 },
            @{ Pattern = "src/**";       Label = "source";        Priority = 5  },
            @{ Pattern = ".github/**";   Label = "ci/cd";         Priority = 40 },
            @{ Pattern = "*.config.*";   Label = "config";        Priority = 15 }
        )
    }

    It "correctly labels a realistic PR with mixed changes" {
        $labels = Get-PRLabels -Files $script:MockPRFiles -Rules $script:DefaultRules
        $labels | Should -Contain "documentation"
        $labels | Should -Contain "api"
        $labels | Should -Contain "tests"
        $labels | Should -Contain "source"
        $labels | Should -Contain "ci/cd"
        $labels | Should -Contain "config"
    }

    It "produces exactly the expected label set for the mock PR" {
        $labels = Get-PRLabels -Files $script:MockPRFiles -Rules $script:DefaultRules
        $labels.Count | Should -Be 6
        $labels | Sort-Object | Should -Be @("api", "ci/cd", "config", "documentation", "source", "tests")
    }
}

Describe "Error Handling" {
    It "throws meaningful error when Rules parameter is null" {
        { Get-PRLabels -Files @("src/foo.ts") -Rules $null } | Should -Throw
    }

    It "handles files with special regex characters in path" {
        $rules = @(
            @{ Pattern = "src/api/**"; Label = "api"; Priority = 10 }
        )
        # Path with dots should not confuse glob matching
        $files = @("src/api/v1.2.3/endpoint.ts")
        $labels = Get-PRLabels -Files $files -Rules $rules
        $labels | Should -Contain "api"
    }
}
