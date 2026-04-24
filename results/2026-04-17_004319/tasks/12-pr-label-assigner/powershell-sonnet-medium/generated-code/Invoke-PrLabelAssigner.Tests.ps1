# PR Label Assigner - Pester Tests
# TDD approach: tests written first, then implementation

BeforeAll {
    . "$PSScriptRoot/Invoke-PrLabelAssigner.ps1"
}

Describe "ConvertGlobToRegex" {
    It "converts ** to match any path segment" {
        $regex = ConvertGlobToRegex "docs/**"
        "docs/README.md" | Should -Match $regex
        "docs/api/getting-started.md" | Should -Match $regex
        "src/main.ps1" | Should -Not -Match $regex
    }

    It "converts single * to match within a path segment" {
        $regex = ConvertGlobToRegex "src/*.ps1"
        "src/main.ps1" | Should -Match $regex
        "src/utils.ps1" | Should -Match $regex
        "src/sub/main.ps1" | Should -Not -Match $regex
    }

    It "converts ? to match a single character" {
        $regex = ConvertGlobToRegex "src/?.ps1"
        "src/a.ps1" | Should -Match $regex
        "src/ab.ps1" | Should -Not -Match $regex
    }

    It "handles *.test.* pattern for test files" {
        $regex = ConvertGlobToRegex "*.test.*"
        "main.test.ps1" | Should -Match $regex
        "utils.test.js" | Should -Match $regex
        "main.ps1" | Should -Not -Match $regex
    }

    It "handles patterns with directory prefix and wildcard extension" {
        $regex = ConvertGlobToRegex "src/api/**"
        "src/api/routes.ps1" | Should -Match $regex
        "src/api/v2/endpoints.ps1" | Should -Match $regex
        "src/core/utils.ps1" | Should -Not -Match $regex
    }
}

Describe "Get-MatchingLabels" {
    BeforeAll {
        $script:rules = @(
            @{ Pattern = "docs/**";     Label = "documentation"; Priority = 10 },
            @{ Pattern = "src/api/**";  Label = "api";           Priority = 20 },
            @{ Pattern = "*.test.*";    Label = "tests";         Priority = 30 },
            @{ Pattern = "src/**";      Label = "source";        Priority = 5  },
            @{ Pattern = "*.md";        Label = "documentation"; Priority = 10 }
        )
    }

    It "returns documentation label for docs/ files" {
        $labels = Get-MatchingLabels -FilePaths @("docs/README.md") -Rules $script:rules
        $labels | Should -Contain "documentation"
    }

    It "returns api label for src/api/ files" {
        $labels = Get-MatchingLabels -FilePaths @("src/api/routes.ps1") -Rules $script:rules
        $labels | Should -Contain "api"
    }

    It "returns tests label for test files" {
        $labels = Get-MatchingLabels -FilePaths @("utils.test.ps1") -Rules $script:rules
        $labels | Should -Contain "tests"
    }

    It "returns multiple labels when multiple rules match" {
        # src/api/routes.test.ps1 matches api AND tests AND source
        $labels = Get-MatchingLabels -FilePaths @("src/api/routes.test.ps1") -Rules $script:rules
        $labels | Should -Contain "api"
        $labels | Should -Contain "tests"
        $labels | Should -Contain "source"
    }

    It "returns deduplicated labels across multiple files" {
        $files = @("docs/README.md", "docs/api-guide.md")
        $labels = Get-MatchingLabels -FilePaths $files -Rules $script:rules
        # Should have documentation only once
        ($labels | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
    }

    It "returns labels sorted by highest priority first" {
        # tests(30) > api(20) > documentation(10)
        $files = @("src/api/routes.test.ps1", "docs/README.md")
        $labels = Get-MatchingLabels -FilePaths $files -Rules $script:rules
        $labels[0] | Should -Be "tests"
        $labels[1] | Should -Be "api"
    }

    It "returns empty array when no rules match" {
        $labels = Get-MatchingLabels -FilePaths @("unknown/file.xyz") -Rules $script:rules
        $labels | Should -BeNullOrEmpty
    }

    It "handles empty file list" {
        $labels = Get-MatchingLabels -FilePaths @() -Rules $script:rules
        $labels | Should -BeNullOrEmpty
    }
}

Describe "Invoke-PrLabelAssigner" {
    BeforeAll {
        $script:defaultRules = @(
            @{ Pattern = "docs/**";    Label = "documentation"; Priority = 10 },
            @{ Pattern = "src/api/**"; Label = "api";           Priority = 20 },
            @{ Pattern = "*.test.*";   Label = "tests";         Priority = 30 },
            @{ Pattern = "src/**";     Label = "source";        Priority = 5  }
        )
        $script:mockFiles = @(
            "docs/README.md",
            "src/api/routes.ps1",
            "src/core/utils.ps1",
            "src/api/auth.test.ps1"
        )
    }

    It "returns correct labels for mock PR file list" {
        $result = Invoke-PrLabelAssigner -FilePaths $script:mockFiles -Rules $script:defaultRules
        $result.Labels | Should -Contain "documentation"
        $result.Labels | Should -Contain "api"
        $result.Labels | Should -Contain "tests"
        $result.Labels | Should -Contain "source"
    }

    It "returns a result object with Labels and MatchedFiles properties" {
        $result = Invoke-PrLabelAssigner -FilePaths $script:mockFiles -Rules $script:defaultRules
        $result.PSObject.Properties.Name | Should -Contain "Labels"
        $result.PSObject.Properties.Name | Should -Contain "MatchedFiles"
    }

    It "includes file-to-label mapping in MatchedFiles" {
        $result = Invoke-PrLabelAssigner -FilePaths $script:mockFiles -Rules $script:defaultRules
        $result.MatchedFiles | Should -Not -BeNullOrEmpty
        $result.MatchedFiles["docs/README.md"] | Should -Contain "documentation"
    }

    It "throws meaningful error when Rules parameter is null" {
        { Invoke-PrLabelAssigner -FilePaths @("file.ps1") -Rules $null } |
            Should -Throw "*Rules*"
    }

    It "throws meaningful error when FilePaths is null" {
        { Invoke-PrLabelAssigner -FilePaths $null -Rules $script:defaultRules } |
            Should -Throw "*FilePaths*"
    }
}

Describe "Invoke-PrLabelAssigner with JSON config" {
    BeforeAll {
        $script:configJson = @'
[
  { "Pattern": "docs/**",    "Label": "documentation", "Priority": 10 },
  { "Pattern": "src/api/**", "Label": "api",           "Priority": 20 },
  { "Pattern": "*.test.*",   "Label": "tests",         "Priority": 30 }
]
'@
    }

    It "accepts JSON string as rules config" {
        $rules = ConvertFrom-LabelRulesJson -Json $script:configJson
        $rules | Should -HaveCount 3
        $rules[0].Pattern | Should -Not -BeNullOrEmpty
        $rules[0].Label   | Should -Not -BeNullOrEmpty
        $rules[0].Priority | Should -BeGreaterThan 0
    }

    It "assigns correct labels using JSON-parsed rules" {
        $rules = ConvertFrom-LabelRulesJson -Json $script:configJson
        $result = Invoke-PrLabelAssigner -FilePaths @("docs/guide.md", "src/api/v2.ps1") -Rules $rules
        $result.Labels | Should -Contain "documentation"
        $result.Labels | Should -Contain "api"
    }
}
