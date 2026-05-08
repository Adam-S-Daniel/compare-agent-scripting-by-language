BeforeAll {
    # Import the module/script
    . $PSScriptRoot/../PrLabelAssigner.ps1
}

Describe "PR Label Assigner - Basic Functionality" {

    Context "Single file with single matching rule" {
        It "should apply documentation label to docs/* files" {
            $rules = @(
                @{
                    pattern = "docs/**"
                    labels = @("documentation")
                    priority = 1
                }
            )

            $files = @("docs/README.md")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "documentation"
        }
    }

    Context "Single file with multiple matching rules" {
        It "should apply all matching labels" {
            $rules = @(
                @{
                    pattern = "src/**"
                    labels = @("source")
                    priority = 1
                },
                @{
                    pattern = "src/api/**"
                    labels = @("api")
                    priority = 2
                }
            )

            $files = @("src/api/endpoints.ps1")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "source"
            $result | Should -Contain "api"
        }
    }

    Context "Multiple files" {
        It "should apply labels to all files and return unique set" {
            $rules = @(
                @{
                    pattern = "docs/**"
                    labels = @("documentation")
                    priority = 1
                },
                @{
                    pattern = "src/**"
                    labels = @("source")
                    priority = 1
                }
            )

            $files = @("docs/README.md", "src/app.ps1", "docs/INSTALL.md")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "documentation"
            $result | Should -Contain "source"
            $result.Count | Should -Be 2  # Only 2 unique labels
        }
    }

    Context "Priority handling" {
        It "should respect priority when rules conflict" {
            $rules = @(
                @{
                    pattern = "*.test.ps1"
                    labels = @("low-priority")
                    priority = 1
                },
                @{
                    pattern = "*.test.ps1"
                    labels = @("high-priority")
                    priority = 10
                }
            )

            $files = @("app.test.ps1")

            $result = Get-PrLabels -Files $files -Rules $rules

            # For same file and conflicting labels, highest priority should win
            $result | Should -Contain "high-priority"
            $result | Should -Not -Contain "low-priority"
        }
    }

    Context "No matching rules" {
        It "should return empty set when file matches no rules" {
            $rules = @(
                @{
                    pattern = "docs/**"
                    labels = @("documentation")
                    priority = 1
                }
            )

            $files = @("random-file.txt")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result.Count | Should -Be 0
        }
    }

    Context "Glob pattern matching" {
        It "should match single wildcard patterns" {
            $rules = @(
                @{
                    pattern = "*.md"
                    labels = @("markdown")
                    priority = 1
                }
            )

            $files = @("README.md", "CHANGELOG.md", "docs/guide.md")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "markdown"
        }

        It "should match double wildcard patterns" {
            $rules = @(
                @{
                    pattern = "src/**/*.ps1"
                    labels = @("powershell-source")
                    priority = 1
                }
            )

            $files = @("src/app.ps1", "src/utils/helpers.ps1", "test/unit.ps1")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "powershell-source"
            $result.Count | Should -Be 1
        }
    }

    Context "Multiple labels per rule" {
        It "should apply all labels from a rule" {
            $rules = @(
                @{
                    pattern = "*.test.ps1"
                    labels = @("tests", "ci", "automated")
                    priority = 1
                }
            )

            $files = @("unit.test.ps1")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "tests"
            $result | Should -Contain "ci"
            $result | Should -Contain "automated"
            $result.Count | Should -Be 3
        }
    }

    Context "Empty input handling" {
        It "should handle empty files list" {
            $rules = @(
                @{
                    pattern = "docs/**"
                    labels = @("documentation")
                    priority = 1
                }
            )

            $files = @()

            $result = Get-PrLabels -Files $files -Rules $rules

            $result.Count | Should -Be 0
        }

        It "should handle empty rules list" {
            $files = @("docs/README.md", "src/app.ps1")

            $result = Get-PrLabels -Files $files -Rules @()

            $result.Count | Should -Be 0
        }
    }

    Context "Case sensitivity" {
        It "should match patterns case-sensitively" {
            $rules = @(
                @{
                    pattern = "Docs/**"
                    labels = @("documentation")
                    priority = 1
                }
            )

            $files = @("docs/readme.md")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result.Count | Should -Be 0  # Should not match because case differs
        }
    }

    Context "Complex glob patterns" {
        It "should handle nested directory patterns" {
            $rules = @(
                @{
                    pattern = "src/**/*.ps1"
                    labels = @("powershell-src")
                    priority = 1
                }
            )

            $files = @("src/utils/helpers.ps1", "src/module.ps1", "test/unit.ps1")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "powershell-src"
            $result.Count | Should -Be 1  # Only one unique label
        }

        It "should handle question mark wildcards" {
            $rules = @(
                @{
                    pattern = "file?.txt"
                    labels = @("text-file")
                    priority = 1
                }
            )

            $files = @("file1.txt", "file2.txt", "file10.txt", "file.txt")

            $result = Get-PrLabels -Files $files -Rules $rules

            $result | Should -Contain "text-file"
            # file1.txt and file2.txt match, but file10.txt and file.txt don't
        }
    }
}
