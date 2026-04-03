# EmployeeReport.Tests.ps1
# TDD test suite for the CSV Employee Report Generator
# Using Pester as the test framework with strict mode

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test (will fail until module is created)
$ModulePath = Join-Path $PSScriptRoot 'EmployeeReport.psm1'
Import-Module $ModulePath -Force

# Path to test fixture CSV
$FixturePath = Join-Path $PSScriptRoot 'fixtures' 'employees.csv'

Describe 'Import-EmployeeData' {
    # TDD Cycle 1 (RED): Test CSV reading before implementation exists
    # This test verifies we can read the CSV and get properly typed employee records

    Context 'Given a valid CSV file' {
        It 'returns an array of employee records' {
            $result = Import-EmployeeData -Path $FixturePath
            $result | Should -Not -BeNullOrEmpty
        }

        It 'returns the correct number of records' {
            $result = Import-EmployeeData -Path $FixturePath
            # 15 total employees in the fixture
            $result.Count | Should -Be 15
        }

        It 'each record has the required fields' {
            $result = Import-EmployeeData -Path $FixturePath
            $first = $result[0]
            $first.PSObject.Properties.Name | Should -Contain 'Name'
            $first.PSObject.Properties.Name | Should -Contain 'Department'
            $first.PSObject.Properties.Name | Should -Contain 'Salary'
            $first.PSObject.Properties.Name | Should -Contain 'HireDate'
            $first.PSObject.Properties.Name | Should -Contain 'Status'
        }

        It 'salary is parsed as a numeric type' {
            $result = Import-EmployeeData -Path $FixturePath
            $result[0].Salary | Should -BeOfType [decimal]
        }

        It 'hire_date is parsed as a DateTime' {
            $result = Import-EmployeeData -Path $FixturePath
            $result[0].HireDate | Should -BeOfType [datetime]
        }
    }

    Context 'Given an invalid file path' {
        It 'throws a meaningful error message' {
            { Import-EmployeeData -Path 'nonexistent.csv' } | Should -Throw -ExpectedMessage '*nonexistent.csv*'
        }
    }
}

Describe 'Get-ActiveEmployees' {
    # TDD Cycle 2 (RED): Test filtering before implementation exists

    BeforeAll {
        $Script:AllEmployees = Import-EmployeeData -Path $FixturePath
    }

    It 'returns only employees with Active status' {
        $result = Get-ActiveEmployees -Employees $Script:AllEmployees
        $result | ForEach-Object { $_.Status | Should -Be 'Active' }
    }

    It 'excludes Inactive employees' {
        $result = Get-ActiveEmployees -Employees $Script:AllEmployees
        # The fixture has 3 inactive employees (David Brown, Grace Wilson, Karen Thomas)
        $result.Count | Should -Be 12
    }

    It 'returns empty array when no active employees' {
        $inactive = $Script:AllEmployees | Where-Object { $_.Status -eq 'Inactive' }
        $result = Get-ActiveEmployees -Employees $inactive
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Get-DepartmentAggregates' {
    # TDD Cycle 3 (RED): Test department aggregations before implementation

    BeforeAll {
        $allEmployees = Import-EmployeeData -Path $FixturePath
        $Script:ActiveEmployees = Get-ActiveEmployees -Employees $allEmployees
    }

    It 'returns a result for each department that has active employees' {
        $result = Get-DepartmentAggregates -Employees $Script:ActiveEmployees
        $departments = $result | Select-Object -ExpandProperty Department
        $departments | Should -Contain 'Engineering'
        $departments | Should -Contain 'Marketing'
        $departments | Should -Contain 'HR'
        $departments | Should -Contain 'Finance'
    }

    It 'computes correct headcount per department' {
        $result = Get-DepartmentAggregates -Employees $Script:ActiveEmployees
        $engineering = $result | Where-Object { $_.Department -eq 'Engineering' }
        # Active engineering: Alice(95000), Bob(88000), Frank(102000), Liam(110000) = 4
        $engineering.Headcount | Should -Be 4
    }

    It 'computes correct average salary per department' {
        $result = Get-DepartmentAggregates -Employees $Script:ActiveEmployees
        $engineering = $result | Where-Object { $_.Department -eq 'Engineering' }
        # (95000 + 88000 + 102000 + 110000) / 4 = 98750
        $engineering.AverageSalary | Should -Be 98750
    }

    It 'each result has Department, Headcount, AverageSalary, TotalSalary fields' {
        $result = Get-DepartmentAggregates -Employees $Script:ActiveEmployees
        $first = $result[0]
        $first.PSObject.Properties.Name | Should -Contain 'Department'
        $first.PSObject.Properties.Name | Should -Contain 'Headcount'
        $first.PSObject.Properties.Name | Should -Contain 'AverageSalary'
        $first.PSObject.Properties.Name | Should -Contain 'TotalSalary'
    }
}

Describe 'Get-OverallStatistics' {
    # TDD Cycle 4 (RED): Test overall stats computation before implementation

    BeforeAll {
        $allEmployees = Import-EmployeeData -Path $FixturePath
        $Script:ActiveEmployees = Get-ActiveEmployees -Employees $allEmployees
    }

    It 'returns an object with overall statistics' {
        $result = Get-OverallStatistics -Employees $Script:ActiveEmployees
        $result | Should -Not -BeNullOrEmpty
    }

    It 'computes correct total headcount' {
        $result = Get-OverallStatistics -Employees $Script:ActiveEmployees
        $result.TotalHeadcount | Should -Be 12
    }

    It 'computes correct overall average salary' {
        $result = Get-OverallStatistics -Employees $Script:ActiveEmployees
        # Sum of active salaries / 12
        $expectedAvg = [Math]::Round(
            (95000 + 88000 + 72000 + 61000 + 102000 + 75000 + 85000 + 91000 + 110000 + 65000 + 70000 + 88000) / 12,
            2
        )
        $result.AverageSalary | Should -Be $expectedAvg
    }

    It 'identifies the highest paid employee' {
        $result = Get-OverallStatistics -Employees $Script:ActiveEmployees
        $result.HighestSalary | Should -Be 110000
    }

    It 'identifies the lowest paid employee' {
        $result = Get-OverallStatistics -Employees $Script:ActiveEmployees
        $result.LowestSalary | Should -Be 61000
    }

    It 'has correct DepartmentCount' {
        $result = Get-OverallStatistics -Employees $Script:ActiveEmployees
        $result.DepartmentCount | Should -Be 4
    }
}

Describe 'Write-SummaryReport' {
    # TDD Cycle 5 (RED): Test report generation before implementation

    BeforeAll {
        $allEmployees = Import-EmployeeData -Path $FixturePath
        $Script:ActiveEmployees = Get-ActiveEmployees -Employees $allEmployees
        $Script:DeptAggregates = Get-DepartmentAggregates -Employees $Script:ActiveEmployees
        $Script:OverallStats = Get-OverallStatistics -Employees $Script:ActiveEmployees
        $Script:ReportPath = Join-Path $PSScriptRoot 'test-output' 'report.txt'
    }

    AfterAll {
        # Clean up test output directory
        $testOutputDir = Join-Path $PSScriptRoot 'test-output'
        if (Test-Path $testOutputDir) {
            Remove-Item $testOutputDir -Recurse -Force
        }
    }

    It 'creates the output file' {
        Write-SummaryReport `
            -DepartmentAggregates $Script:DeptAggregates `
            -OverallStatistics $Script:OverallStats `
            -OutputPath $Script:ReportPath

        Test-Path $Script:ReportPath | Should -Be $true
    }

    It 'report contains a header section' {
        $content = Get-Content $Script:ReportPath -Raw
        $content | Should -Match 'Employee Summary Report'
    }

    It 'report contains department breakdown section' {
        $content = Get-Content $Script:ReportPath -Raw
        $content | Should -Match 'Department Breakdown'
        $content | Should -Match 'Engineering'
        $content | Should -Match 'Marketing'
        $content | Should -Match 'Finance'
        $content | Should -Match 'HR'
    }

    It 'report contains overall statistics section' {
        $content = Get-Content $Script:ReportPath -Raw
        $content | Should -Match 'Overall Statistics'
        $content | Should -Match 'Total Active Employees'
    }

    It 'creates parent directory if it does not exist' {
        $newPath = Join-Path $PSScriptRoot 'test-output' 'subdir' 'report2.txt'
        Write-SummaryReport `
            -DepartmentAggregates $Script:DeptAggregates `
            -OverallStatistics $Script:OverallStats `
            -OutputPath $newPath

        Test-Path $newPath | Should -Be $true
    }
}
