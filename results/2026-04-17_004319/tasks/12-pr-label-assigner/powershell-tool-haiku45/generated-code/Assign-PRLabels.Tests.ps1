# Test file for PR Label Assigner
# TDD approach: write failing tests first, then implement to make them pass

BeforeAll {
    . $PSScriptRoot/Assign-PRLabels.ps1
}

Describe "Assign-PRLabels - Core Functionality" {

    Context "Simple path matching" {
        It "should assign label when file matches exact path pattern" {
            $rules = @{
                "docs/README.md" = @("documentation")
            }
            $files = @("docs/README.md")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "documentation"
        }

        It "should handle glob pattern with double asterisk" {
            $rules = @{
                "docs/**" = @("documentation")
            }
            $files = @("docs/guide.md", "docs/api/endpoint.md")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "documentation"
        }

        It "should handle glob pattern with single asterisk" {
            $rules = @{
                "src/**.js" = @("javascript")
            }
            $files = @("src/app.js", "src/utils.js")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "javascript"
        }
    }

    Context "Multiple labels per file" {
        It "should assign multiple labels to same file" {
            $rules = @{
                "src/api/**" = @("backend", "api")
                "**.test.ps1" = @("tests")
            }
            $files = @("src/api/user.test.ps1")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "backend"
            $result | Should -Contain "api"
            $result | Should -Contain "tests"
        }
    }

    Context "Priority ordering" {
        It "should prioritize first matching rule when multiple rules match" {
            $rules = @(
                @{ pattern = "src/api/**"; labels = @("api"); priority = 1 }
                @{ pattern = "src/**"; labels = @("backend"); priority = 2 }
            )
            $files = @("src/api/user.ps1")

            $result = Get-PRLabels -Files $files -Rules $rules -UsePriority $true

            # With priority, api (priority 1) should be selected over backend (priority 2)
            $result | Should -Contain "api"
        }
    }

    Context "Error handling" {
        It "should throw error for invalid file path" {
            $rules = @{ "docs/**" = @("documentation") }
            $files = @($null)

            { Get-PRLabels -Files $files -Rules $rules } | Should -Throw
        }

        It "should throw error for empty rules" {
            $files = @("docs/readme.md")

            { Get-PRLabels -Files $files -Rules @{} } | Should -Throw
        }
    }

    Context "No matching rules" {
        It "should return empty set when no rules match" {
            $rules = @{
                "docs/**" = @("documentation")
            }
            $files = @("src/app.ps1")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result.Count | Should -Be 0
        }
    }

    Context "Duplicate label handling" {
        It "should deduplicate labels in final set" {
            $rules = @{
                "src/**" = @("backend")
                "src/api/**" = @("backend")
            }
            $files = @("src/api/user.ps1")

            $result = Get-PRLabels -Files $files -Rules $rules

            # Should only have one "backend" label, not duplicated
            @($result | Where-Object { $_ -eq "backend" }).Count | Should -Be 1
        }
    }
}

Describe "Assign-PRLabels - Pattern Matching Edge Cases" {

    Context "Glob pattern variations" {
        It "should match extension patterns with single asterisk" {
            $rules = @{
                "**.test.ps1" = @("tests")
            }
            $files = @("unit.test.ps1", "integration.test.ps1")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "tests"
        }

        It "should match single directory level with single asterisk" {
            $rules = @{
                "**/config/**" = @("configuration")
            }
            $files = @("src/config/app.json", "app/config/settings.json")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "configuration"
        }

        It "should handle case-insensitive matching" {
            $rules = @{
                "docs/**" = @("documentation")
            }
            $files = @("DOCS/README.MD")

            $result = Get-PRLabels -Files $files -Rules $rules

            $result | Should -Contain "documentation"
        }
    }
}

Describe "Assign-PRLabels - Mock Data Integration" {

    Context "Real-world scenario" {
        It "should correctly label a typical PR with multiple file types" {
            $rules = @{
                "docs/**" = @("documentation")
                "src/api/**" = @("api", "backend")
                "src/**" = @("backend")
                "**.test.ps1" = @("tests")
                "**.md" = @("documentation")
            }

            $files = @(
                "docs/API.md"
                "src/api/endpoints.ps1"
                "src/utils.ps1"
                "tests/unit.test.ps1"
            )

            $result = Get-PRLabels -Files $files -Rules $rules

            # Should contain all expected labels
            $result | Should -Contain "documentation"
            $result | Should -Contain "api"
            $result | Should -Contain "backend"
            $result | Should -Contain "tests"

            # Should not have duplicates (using Set semantics)
            $result.Count | Should -Be 4
        }
    }
}
