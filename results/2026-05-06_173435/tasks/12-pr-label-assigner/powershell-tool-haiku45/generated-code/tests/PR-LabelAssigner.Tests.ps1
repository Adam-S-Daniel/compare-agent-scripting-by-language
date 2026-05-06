# PR Label Assigner Tests - TDD approach
# Test fixtures and tests for the label assignment functionality

Describe "PR Label Assigner" {
    # Load the script under test
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot ".." "src" "PR-LabelAssigner.ps1"
        . $scriptPath
    }

    Describe "Test 1: Basic file to single label mapping" {
        It "should assign 'documentation' label to docs/README.md" {
            $rules = @(
                @{ pattern = "docs/**"; labels = @("documentation") }
            )

            $changedFiles = @("docs/README.md")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result | Should -Contain "documentation"
            $result.Count | Should -Be 1
        }
    }

    Describe "Test 2: Multiple labels per file" {
        It "should assign multiple labels when a file matches multiple rules" {
            $rules = @(
                @{ pattern = "src/**"; labels = @("code") }
                @{ pattern = "src/api/**"; labels = @("api") }
            )

            $changedFiles = @("src/api/users.ps1")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result | Should -Contain "code"
            $result | Should -Contain "api"
            $result.Count | Should -Be 2
        }
    }

    Describe "Test 3: Glob pattern with asterisk" {
        It "should match test files with *.test.ps1 pattern" {
            $rules = @(
                @{ pattern = "*.test.ps1"; labels = @("tests") }
            )

            $changedFiles = @("unit.test.ps1", "integration.test.ps1")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result | Should -Contain "tests"
            $result.Count | Should -Be 1
        }
    }

    Describe "Test 4: Multiple files with mixed matches" {
        It "should assign labels to multiple files correctly" {
            $rules = @(
                @{ pattern = "docs/**"; labels = @("documentation") }
                @{ pattern = "src/api/**"; labels = @("api") }
                @{ pattern = "*.test.ps1"; labels = @("tests") }
            )

            $changedFiles = @("docs/README.md", "src/api/handler.ps1", "unit.test.ps1")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result | Should -Contain "documentation"
            $result | Should -Contain "api"
            $result | Should -Contain "tests"
            $result.Count | Should -Be 3
        }
    }

    Describe "Test 5: Overlapping rules with priority" {
        It "should use first-match priority when rules overlap" {
            $rules = @(
                @{ pattern = "src/**"; labels = @("code"); priority = 1 }
                @{ pattern = "src/api/**"; labels = @("api"); priority = 2 }
            )

            $changedFiles = @("src/api/users.ps1")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules -UsePriority $true

            # With priority, both rules should still match (priority only affects order of evaluation)
            $result | Should -Contain "code"
            $result | Should -Contain "api"
        }
    }

    Describe "Test 6: No matching rules" {
        It "should return empty set when no rules match" {
            $rules = @(
                @{ pattern = "docs/**"; labels = @("documentation") }
            )

            $changedFiles = @("src/unknown.ps1")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result.Count | Should -Be 0
        }
    }

    Describe "Test 7: Empty changed files list" {
        It "should return empty set when no files changed" {
            $rules = @(
                @{ pattern = "docs/**"; labels = @("documentation") }
            )

            $changedFiles = @()
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result.Count | Should -Be 0
        }
    }

    Describe "Test 8: Deeply nested paths" {
        It "should match deeply nested files with ** pattern" {
            $rules = @(
                @{ pattern = "src/**"; labels = @("code") }
            )

            $changedFiles = @("src/components/forms/inputs/button.ps1")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result | Should -Contain "code"
        }
    }

    Describe "Test 9: Case sensitivity" {
        It "should handle case-insensitive matching" {
            $rules = @(
                @{ pattern = "Docs/**"; labels = @("documentation") }
            )

            $changedFiles = @("docs/README.md")
            $result = Get-AssignedLabels -ChangedFiles $changedFiles -LabelRules $rules

            $result | Should -Contain "documentation"
        }
    }
}
