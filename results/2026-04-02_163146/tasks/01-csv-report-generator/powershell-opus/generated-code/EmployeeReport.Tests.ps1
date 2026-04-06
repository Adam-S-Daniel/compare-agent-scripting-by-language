# EmployeeReport.Tests.ps1
# Pester tests for the EmployeeReport module.
#
# TDD Methodology: Each Describe block represents a TDD cycle.
# Tests were written FIRST (RED), then the minimum implementation was added
# to make them pass (GREEN), then refactored as needed.

BeforeAll {
    # Dot-source the module under test
    . "$PSScriptRoot/EmployeeReport.ps1"

    # Path to test fixture CSV
    $script:FixturePath = "$PSScriptRoot/fixtures/employees.csv"
}

# =============================================================================
# TDD CYCLE 1: Read CSV and filter to active employees only
# RED:   Tests fail because Get-ActiveEmployees doesn't exist yet
# GREEN: Implement Get-ActiveEmployees to read CSV and filter by status='active'
# =============================================================================
Describe 'Get-ActiveEmployees' {

    Context 'When given a valid CSV file' {
        BeforeAll {
            $script:result = Get-ActiveEmployees -Path $script:FixturePath
        }

        It 'Should return only active employees' {
            # Fixture has 9 active out of 12 total records
            $script:result.Count | Should -Be 9
        }

        It 'Should not include any inactive employees' {
            $script:result | Where-Object { $_.status -eq 'inactive' } |
                Should -BeNullOrEmpty
        }

        It 'Should preserve all CSV columns' {
            $first = $script:result[0]
            $first.PSObject.Properties.Name | Should -Contain 'name'
            $first.PSObject.Properties.Name | Should -Contain 'department'
            $first.PSObject.Properties.Name | Should -Contain 'salary'
            $first.PSObject.Properties.Name | Should -Contain 'hire_date'
            $first.PSObject.Properties.Name | Should -Contain 'status'
        }

        It 'Should include known active employee Alice Johnson' {
            $script:result | Where-Object { $_.name -eq 'Alice Johnson' } |
                Should -Not -BeNullOrEmpty
        }

        It 'Should exclude known inactive employee Carol White' {
            $script:result | Where-Object { $_.name -eq 'Carol White' } |
                Should -BeNullOrEmpty
        }
    }

    Context 'When given a file that does not exist' {
        It 'Should throw a meaningful error' {
            { Get-ActiveEmployees -Path 'nonexistent.csv' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'When given an empty CSV (headers only)' {
        BeforeAll {
            $script:emptyPath = Join-Path $TestDrive 'empty.csv'
            Set-Content -Path $script:emptyPath -Value 'name,department,salary,hire_date,status'
        }

        It 'Should return an empty collection' {
            $result = Get-ActiveEmployees -Path $script:emptyPath
            $result | Should -BeNullOrEmpty
        }
    }
}

# =============================================================================
# TDD CYCLE 2: Compute department-level aggregates
# RED:   Tests fail because Get-DepartmentAggregates doesn't exist yet
# GREEN: Implement Get-DepartmentAggregates to group by department and compute
#        average salary and headcount
# =============================================================================
Describe 'Get-DepartmentAggregates' {

    Context 'When given active employees from the fixture' {
        BeforeAll {
            $active = Get-ActiveEmployees -Path $script:FixturePath
            $script:deptAgg = Get-DepartmentAggregates -Employees $active
        }

        It 'Should return aggregates for all departments with active employees' {
            # Engineering(2), Sales(2), HR(2), Marketing(3) = 4 departments
            $script:deptAgg.Count | Should -Be 4
        }

        It 'Should compute correct headcount for Engineering' {
            $eng = $script:deptAgg | Where-Object { $_.Department -eq 'Engineering' }
            $eng.Headcount | Should -Be 2
        }

        It 'Should compute correct average salary for Engineering' {
            # Alice=95000, Bob=105000 -> avg=100000
            $eng = $script:deptAgg | Where-Object { $_.Department -eq 'Engineering' }
            $eng.AverageSalary | Should -Be 100000
        }

        It 'Should compute correct headcount for Sales' {
            $sales = $script:deptAgg | Where-Object { $_.Department -eq 'Sales' }
            $sales.Headcount | Should -Be 2
        }

        It 'Should compute correct average salary for Sales' {
            # David=72000, Eve=68000 -> avg=70000
            $sales = $script:deptAgg | Where-Object { $_.Department -eq 'Sales' }
            $sales.AverageSalary | Should -Be 70000
        }

        It 'Should compute correct headcount for HR' {
            $hr = $script:deptAgg | Where-Object { $_.Department -eq 'HR' }
            $hr.Headcount | Should -Be 2
        }

        It 'Should compute correct average salary for HR' {
            # Grace=65000, Henry=70000 -> avg=67500
            $hr = $script:deptAgg | Where-Object { $_.Department -eq 'HR' }
            $hr.AverageSalary | Should -Be 67500
        }

        It 'Should compute correct headcount for Marketing' {
            $mkt = $script:deptAgg | Where-Object { $_.Department -eq 'Marketing' }
            $mkt.Headcount | Should -Be 3
        }

        It 'Should compute correct average salary for Marketing' {
            # Jack=78000, Karen=82000, Leo=71000 -> avg=77000
            $mkt = $script:deptAgg | Where-Object { $_.Department -eq 'Marketing' }
            $mkt.AverageSalary | Should -Be 77000
        }
    }

    Context 'When given an empty employee list' {
        It 'Should return an empty collection' {
            $result = Get-DepartmentAggregates -Employees @()
            $result | Should -BeNullOrEmpty
        }
    }
}

# =============================================================================
# TDD CYCLE 3: Compute overall statistics
# RED:   Tests fail because Get-OverallStatistics doesn't exist yet
# GREEN: Implement Get-OverallStatistics to compute total headcount, average,
#        min, and max salary across all active employees
# =============================================================================
Describe 'Get-OverallStatistics' {

    Context 'When given active employees from the fixture' {
        BeforeAll {
            $active = Get-ActiveEmployees -Path $script:FixturePath
            $script:stats = Get-OverallStatistics -Employees $active
        }

        It 'Should compute total active headcount' {
            $script:stats.TotalEmployees | Should -Be 9
        }

        It 'Should compute overall average salary' {
            # Sum: 95000+105000+72000+68000+65000+70000+78000+82000+71000 = 706000
            # Average: 706000 / 9 ≈ 78444.44
            [math]::Round($script:stats.AverageSalary, 2) |
                Should -Be ([math]::Round(706000 / 9, 2))
        }

        It 'Should find the minimum salary' {
            # Grace Lee = 65000
            $script:stats.MinSalary | Should -Be 65000
        }

        It 'Should find the maximum salary' {
            # Bob Smith = 105000
            $script:stats.MaxSalary | Should -Be 105000
        }

        It 'Should compute total salary sum' {
            $script:stats.TotalSalary | Should -Be 706000
        }
    }

    Context 'When given an empty employee list' {
        It 'Should return zero-value statistics' {
            $result = Get-OverallStatistics -Employees @()
            $result.TotalEmployees | Should -Be 0
            $result.AverageSalary | Should -Be 0
            $result.MinSalary | Should -Be 0
            $result.MaxSalary | Should -Be 0
            $result.TotalSalary | Should -Be 0
        }
    }
}

# =============================================================================
# TDD CYCLE 4: Generate formatted summary report
# RED:   Tests fail because New-EmployeeReport doesn't exist yet
# GREEN: Implement New-EmployeeReport to write a formatted text report file
# =============================================================================
Describe 'New-EmployeeReport' {

    Context 'When generating a report from fixture data' {
        BeforeAll {
            $script:reportPath = Join-Path $TestDrive 'report.txt'
            New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:reportPath
            $script:reportContent = Get-Content -Path $script:reportPath -Raw
            $script:reportLines = Get-Content -Path $script:reportPath
        }

        It 'Should create the output file' {
            Test-Path $script:reportPath | Should -BeTrue
        }

        It 'Should include a report title' {
            $script:reportContent | Should -Match 'Employee Summary Report'
        }

        It 'Should include overall statistics section' {
            $script:reportContent | Should -Match 'Overall Statistics'
        }

        It 'Should include total active employee count' {
            $script:reportContent | Should -Match '9'
        }

        It 'Should include department breakdown section' {
            $script:reportContent | Should -Match 'Department Breakdown'
        }

        It 'Should list all four departments' {
            $script:reportContent | Should -Match 'Engineering'
            $script:reportContent | Should -Match 'Sales'
            $script:reportContent | Should -Match 'HR'
            $script:reportContent | Should -Match 'Marketing'
        }

        It 'Should include average salary for Engineering (100000)' {
            $script:reportContent | Should -Match '100,000'
        }

        It 'Should include the minimum salary (65000)' {
            $script:reportContent | Should -Match '65,000'
        }

        It 'Should include the maximum salary (105000)' {
            $script:reportContent | Should -Match '105,000'
        }

        It 'Should not be empty' {
            $script:reportContent.Length | Should -BeGreaterThan 100
        }
    }

    Context 'When given a non-existent CSV file' {
        It 'Should throw a meaningful error' {
            { New-EmployeeReport -CsvPath 'nonexistent.csv' -OutputPath (Join-Path $TestDrive 'out.txt') } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'When all employees are inactive' {
        BeforeAll {
            $script:inactivePath = Join-Path $TestDrive 'inactive.csv'
            @(
                'name,department,salary,hire_date,status'
                'Test User,Dept,50000,2020-01-01,inactive'
            ) | Set-Content -Path $script:inactivePath

            $script:inactiveReportPath = Join-Path $TestDrive 'inactive_report.txt'
            New-EmployeeReport -CsvPath $script:inactivePath -OutputPath $script:inactiveReportPath
            $script:inactiveReportContent = Get-Content -Path $script:inactiveReportPath -Raw
        }

        It 'Should still generate a report file' {
            Test-Path $script:inactiveReportPath | Should -BeTrue
        }

        It 'Should indicate zero active employees' {
            $script:inactiveReportContent | Should -Match '0'
        }
    }
}
