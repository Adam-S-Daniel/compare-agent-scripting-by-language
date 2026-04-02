# CsvReportGenerator.Tests.ps1
# Pester tests for the CSV Report Generator.
# TDD approach: each test block was written BEFORE the corresponding implementation.

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/CsvReportGenerator.ps1"
}

# ============================================================================
# TDD CYCLE 1: Import CSV and filter active employees
# RED: These tests were written first, before Import-EmployeeCsv existed.
# ============================================================================
Describe "Import-EmployeeCsv" {
    Context "when given a valid CSV with mixed active/inactive employees" {
        BeforeAll {
            $script:csvPath = "$PSScriptRoot/fixtures/employees.csv"
            $script:employees = Import-EmployeeCsv -Path $script:csvPath
        }

        It "should return only active employees (no inactive)" {
            $script:employees | ForEach-Object {
                $_.status | Should -Be "active"
            }
        }

        It "should return exactly 12 active employees from the fixture" {
            # Fixture has 15 rows: 12 active, 3 inactive (Carol, Frank, Karen)
            $script:employees.Count | Should -Be 12
        }

        It "should parse salary as a numeric double type" {
            $script:employees | ForEach-Object {
                $_.salary | Should -BeOfType [double]
            }
        }

        It "should parse hire_date as a DateTime type" {
            $script:employees | ForEach-Object {
                $_.hire_date | Should -BeOfType [datetime]
            }
        }

        It "should include active employees and exclude inactive ones" {
            $names = $script:employees | ForEach-Object { $_.name }
            $names | Should -Contain "Alice Johnson"
            $names | Should -Contain "Mia Garcia"
            # These are inactive and should NOT appear
            $names | Should -Not -Contain "Carol White"
            $names | Should -Not -Contain "Frank Wilson"
            $names | Should -Not -Contain "Karen Thomas"
        }
    }

    Context "when given a non-existent file path" {
        It "should throw a meaningful error mentioning the file" {
            { Import-EmployeeCsv -Path "/no/such/file.csv" } | Should -Throw "*does not exist*"
        }
    }

    Context "when given a CSV with headers only (no data rows)" {
        BeforeAll {
            $script:emptyPath = "$PSScriptRoot/fixtures/empty_employees.csv"
            "name,department,salary,hire_date,status" | Set-Content -Path $script:emptyPath
        }

        It "should return an empty collection" {
            $result = Import-EmployeeCsv -Path $script:emptyPath
            $result.Count | Should -Be 0
        }

        AfterAll {
            Remove-Item -Path $script:emptyPath -ErrorAction SilentlyContinue
        }
    }
}
