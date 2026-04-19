BeforeAll {
    # Load the module/script
    . $PSScriptRoot/../src/Assign-Labels.ps1
}

Describe "Assign-Labels basic functionality" {
    It "should return empty label set for empty file list" {
        $files = @()
        $rules = @{}
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        $result | Should -Be @()
    }

    It "should assign single label to matching file" {
        $files = @("docs/README.md")
        $rules = @{
            "docs/**" = @("documentation")
        }
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        $result | Should -Contain "documentation"
    }

    It "should assign multiple labels to same file" {
        $files = @("src/api/handler.test.ts")
        $rules = @{
            "src/api/**" = @("api")
            "*.test.*" = @("tests")
        }
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        $result | Should -Contain "api"
        $result | Should -Contain "tests"
    }

    It "should not duplicate labels" {
        $files = @("src/api/api.ts")
        $rules = @{
            "src/api/**" = @("api")
            "src/api/api.*" = @("api")
        }
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        @($result | Where-Object { $_ -eq "api" }).Count | Should -Be 1
    }

    It "should handle priority ordering when rules conflict" {
        $files = @("docs/api.ts")
        $rules = @{
            @{pattern="docs/**"; priority=1} = @("documentation")
            @{pattern="*.ts"; priority=2} = @("typescript")
        }
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        # Higher priority (lower number) wins
        $result | Should -Contain "documentation"
    }

    It "should handle glob patterns with wildcards" {
        $files = @("src/components/Button.jsx", "src/hooks/useData.js", "src/utils/helper.js")
        $rules = @{
            "src/components/**" = @("components")
            "src/hooks/**" = @("hooks")
            "src/utils/**" = @("utilities")
        }
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        $result | Should -Contain "components"
        $result | Should -Contain "hooks"
        $result | Should -Contain "utilities"
    }

    It "should match extension patterns like *.test.*" {
        $files = @("utils.test.ts", "utils.spec.ts", "utils.ts")
        $rules = @{
            "*.test.*" = @("tests")
            "*.spec.*" = @("tests")
        }
        $result = Invoke-LabelAssignment -Files $files -Rules $rules

        # Should match utils.test.ts and utils.spec.ts
        $testMatches = @($result | Where-Object { $_ -eq "tests" }).Count
        $testMatches | Should -BeGreaterOrEqual 1
    }
}

Describe "Assign-Labels error handling" {
    It "should throw meaningful error for invalid file list" {
        $rules = @{"docs/**" = @("documentation")}
        { Invoke-LabelAssignment -Files $null -Rules $rules } | Should -Throw
    }

    It "should throw meaningful error for invalid rules" {
        $files = @("docs/README.md")
        { Invoke-LabelAssignment -Files $files -Rules $null } | Should -Throw
    }

    It "should handle malformed glob patterns gracefully" {
        $files = @("src/main.ts")
        $rules = @{
            "[invalid-pattern" = @("label")
        }
        # Should either skip invalid pattern or throw with clear message
        { Invoke-LabelAssignment -Files $files -Rules $rules } | Should -Not -Throw
    }
}
