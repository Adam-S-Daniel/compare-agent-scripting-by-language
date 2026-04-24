# PrLabelAssigner.Tests.ps1
# TDD: These tests are written FIRST (red), then implementation is written to make them pass (green).
# Tests cover: glob-to-regex conversion, pattern matching, label assignment, and workflow structure.

BeforeAll {
    # Dot-source the library (fails until PrLabelAssigner.ps1 exists)
    . "$PSScriptRoot/PrLabelAssigner.ps1"
    $RulesFile = "$PSScriptRoot/label-rules.json"
}

Describe "ConvertGlobToRegex" {
    It "converts a simple literal pattern" {
        $regex = ConvertGlobToRegex "README.md"
        "README.md" | Should -Match $regex
        "other.md"  | Should -Not -Match $regex
    }

    It "converts single-star to non-slash wildcard" {
        $regex = ConvertGlobToRegex "src/*.ts"
        "src/foo.ts"       | Should -Match $regex
        "src/bar.ts"       | Should -Match $regex
        "src/sub/foo.ts"   | Should -Not -Match $regex
    }

    It "converts double-star at end to any-path wildcard" {
        $regex = ConvertGlobToRegex "docs/**"
        "docs/README.md"          | Should -Match $regex
        "docs/sub/page.md"        | Should -Match $regex
        "other/README.md"         | Should -Not -Match $regex
    }

    It "converts **/ prefix to optional path prefix" {
        $regex = ConvertGlobToRegex "**/*.test.ts"
        "utils.test.ts"           | Should -Match $regex
        "src/utils.test.ts"       | Should -Match $regex
        "src/deep/utils.test.ts"  | Should -Match $regex
        "src/utils.ts"            | Should -Not -Match $regex
    }

    It "converts ? to single non-slash char" {
        $regex = ConvertGlobToRegex "src/?.ts"
        "src/a.ts" | Should -Match $regex
        "src/ab.ts" | Should -Not -Match $regex
    }

    It "escapes regex special characters in literal parts" {
        $regex = ConvertGlobToRegex "src/api/v1.0/**"
        "src/api/v1.0/users.ts" | Should -Match $regex
        "src/api/v1X0/users.ts" | Should -Not -Match $regex
    }
}

Describe "Test-GlobMatch" {
    It "matches docs/** against docs files" {
        Test-GlobMatch -Path "docs/README.md"   -Pattern "docs/**" | Should -BeTrue
        Test-GlobMatch -Path "docs/sub/page.md" -Pattern "docs/**" | Should -BeTrue
        Test-GlobMatch -Path "src/README.md"    -Pattern "docs/**" | Should -BeFalse
    }

    It "matches src/api/** against api files" {
        Test-GlobMatch -Path "src/api/users.ts"        -Pattern "src/api/**" | Should -BeTrue
        Test-GlobMatch -Path "src/api/v2/endpoints.ts" -Pattern "src/api/**" | Should -BeTrue
        Test-GlobMatch -Path "src/models/user.ts"      -Pattern "src/api/**" | Should -BeFalse
    }

    It "matches **/*.test.* against test files anywhere" {
        Test-GlobMatch -Path "utils.test.ts"           -Pattern "**/*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "src/utils.test.ts"       -Pattern "**/*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "src/deep/foo.test.js"    -Pattern "**/*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "src/utils.ts"            -Pattern "**/*.test.*" | Should -BeFalse
    }

    It "matches *.test.* only at root level" {
        Test-GlobMatch -Path "utils.test.ts"     -Pattern "*.test.*" | Should -BeTrue
        Test-GlobMatch -Path "src/utils.test.ts" -Pattern "*.test.*" | Should -BeFalse
    }
}

Describe "Get-LabelsForFiles" {
    BeforeAll {
        $Rules = @(
            [PSCustomObject]@{ pattern = "docs/**";     label = "documentation"; priority = 1 }
            [PSCustomObject]@{ pattern = "src/api/**";  label = "api";           priority = 2 }
            [PSCustomObject]@{ pattern = "**/*.test.*"; label = "tests";         priority = 3 }
            [PSCustomObject]@{ pattern = "*.test.*";    label = "tests";         priority = 3 }
            [PSCustomObject]@{ pattern = "src/**";      label = "source";        priority = 4 }
            [PSCustomObject]@{ pattern = ".github/**";  label = "ci";            priority = 5 }
        )
    }

    It "returns documentation for a docs file" {
        $labels = Get-LabelsForFiles -Files @("docs/README.md") -Rules $Rules
        $labels | Should -Contain "documentation"
    }

    It "returns api and source for an API file" {
        $labels = Get-LabelsForFiles -Files @("src/api/users.ts") -Rules $Rules
        $labels | Should -Contain "api"
        $labels | Should -Contain "source"
    }

    It "returns tests and source for a test file" {
        $labels = Get-LabelsForFiles -Files @("src/utils.test.ts") -Rules $Rules
        $labels | Should -Contain "tests"
        $labels | Should -Contain "source"
    }

    It "returns multiple labels for multiple files" {
        $labels = Get-LabelsForFiles -Files @("docs/README.md", "src/api/users.ts") -Rules $Rules
        $labels | Should -Contain "documentation"
        $labels | Should -Contain "api"
        $labels | Should -Contain "source"
    }

    It "returns empty array when no files match" {
        $labels = Get-LabelsForFiles -Files @("random/unmatched.txt") -Rules $Rules
        $labels.Count | Should -Be 0
    }

    It "returns empty array for empty file list" {
        $labels = Get-LabelsForFiles -Files @() -Rules $Rules
        $labels.Count | Should -Be 0
    }

    It "deduplicates labels when multiple files match the same rule" {
        $labels = Get-LabelsForFiles -Files @("docs/README.md", "docs/GUIDE.md") -Rules $Rules
        ($labels | Where-Object { $_ -eq "documentation" }).Count | Should -Be 1
    }

    It "returns labels sorted by priority (lower number first)" {
        $labels = Get-LabelsForFiles -Files @("src/api/users.ts", "docs/README.md") -Rules $Rules
        $labels[0] | Should -Be "documentation"  # priority 1
        $labels[1] | Should -Be "api"             # priority 2
    }

    It "returns ci label for .github files" {
        $labels = Get-LabelsForFiles -Files @(".github/workflows/ci.yml") -Rules $Rules
        $labels | Should -Contain "ci"
    }
}

Describe "Import-LabelRules" {
    It "loads rules from a valid JSON file" {
        $rules = Import-LabelRules -Path $RulesFile
        $rules | Should -Not -BeNullOrEmpty
        $rules[0].pattern | Should -Not -BeNullOrEmpty
        $rules[0].label   | Should -Not -BeNullOrEmpty
        $rules[0].priority | Should -BeGreaterThan 0
    }

    It "throws a meaningful error for missing file" {
        { Import-LabelRules -Path "/nonexistent/rules.json" } | Should -Throw
    }
}

Describe "Workflow Structure" {
    BeforeAll {
        $workflowPath = "$PSScriptRoot/.github/workflows/pr-label-assigner.yml"
    }

    It "workflow file exists" {
        Test-Path $workflowPath | Should -BeTrue
    }

    It "workflow references existing script files" {
        $content = Get-Content $workflowPath -Raw
        # Extract referenced .ps1 files from the workflow
        $matches = [regex]::Matches($content, '\.\/[\w\-]+\.ps1')
        $matches.Count | Should -BeGreaterThan 0
        foreach ($m in $matches) {
            $scriptName = $m.Value -replace '^\.\/', ''
            Test-Path "$PSScriptRoot/$scriptName" | Should -BeTrue -Because "workflow references $scriptName which should exist"
        }
    }

    It "workflow passes actionlint" {
        if (-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "actionlint not found in PATH"
            return
        }
        $result = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $result"
    }

    It "workflow has push trigger" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'push:'
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'workflow_dispatch'
    }

    It "workflow uses shell: pwsh on run steps" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'shell: pwsh'
    }

    It "workflow has assign-labels job" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match 'assign-labels'
    }
}
