# CsvReportGenerator.Tests.ps1
# TDD tests for CSV employee report generator
# RED phase: Write failing tests first, then implement code to make them pass

BeforeAll {
    # Dot-source the implementation file (will fail initially since it doesn't exist yet)
    . "$PSScriptRoot/CsvReportGenerator.ps1"

    # Create fixtures directory for test data
    $script:FixturesPath = "$PSScriptRoot/fixtures"
    if (-not (Test-Path $script:FixturesPath)) {
        New-Item -ItemType Directory -Path $script:FixturesPath | Out-Null
    }

    # Create sample CSV test data as a fixture
    # 10 employees: 8 active, 2 inactive across 3 departments
    $script:CsvPath = "$script:FixturesPath/employees.csv"
    @"
name,department,salary,hire_date,status
Alice Johnson,Engineering,95000,2020-01-15,active
Bob Smith,Engineering,85000,2019-03-22,active
Carol Davis,Marketing,72000,2021-06-01,inactive
Dave Wilson,Engineering,105000,2018-11-10,active
Eve Martinez,Marketing,68000,2022-02-14,active
Frank Brown,HR,62000,2020-09-30,active
Grace Lee,HR,58000,2023-01-05,inactive
Henry Taylor,Marketing,75000,2021-08-20,active
Iris Chen,Engineering,92000,2022-04-12,active
Jack Thompson,HR,65000,2019-07-18,active
"@ | Set-Content -Path $script:CsvPath
}

# ============================================================
# Feature 1: Import-EmployeeCsv
# RED: These tests will fail until Import-EmployeeCsv is implemented
# ============================================================
Describe "Import-EmployeeCsv" {
    It "should load all employee records from a CSV file" {
        $employees = Import-EmployeeCsv -Path $script:CsvPath
        $employees | Should -Not -BeNullOrEmpty
        $employees.Count | Should -Be 10
    }

    It "should parse employee fields correctly" {
        $employees = Import-EmployeeCsv -Path $script:CsvPath
        $first = $employees[0]
        $first.name       | Should -Be "Alice Johnson"
        $first.department | Should -Be "Engineering"
        $first.salary     | Should -Be 95000
        $first.hire_date  | Should -Be "2020-01-15"
        $first.status     | Should -Be "active"
    }

    It "should parse salary as a numeric type" {
        $employees = Import-EmployeeCsv -Path $script:CsvPath
        $employees[0].salary | Should -BeOfType [decimal]
    }

    It "should throw a meaningful error for a non-existent file" {
        { Import-EmployeeCsv -Path "/nonexistent/employees.csv" } | Should -Throw "*not found*"
    }
}

# ============================================================
# Feature 2: Get-ActiveEmployees
# RED: These tests will fail until Get-ActiveEmployees is implemented
# ============================================================
Describe "Get-ActiveEmployees" {
    BeforeAll {
        $script:AllEmployees = Import-EmployeeCsv -Path $script:CsvPath
    }

    It "should return only employees with status 'active'" {
        $active = Get-ActiveEmployees -Employees $script:AllEmployees
        $active | Should -Not -BeNullOrEmpty
        $active | ForEach-Object { $_.status | Should -Be "active" }
    }

    It "should return 8 active employees from the test fixture" {
        $active = Get-ActiveEmployees -Employees $script:AllEmployees
        $active.Count | Should -Be 8
    }

    It "should exclude inactive employees" {
        $active = Get-ActiveEmployees -Employees $script:AllEmployees
        $inactive = $active | Where-Object { $_.status -ne "active" }
        $inactive | Should -BeNullOrEmpty
    }

    It "should return an empty array when no employees are active" {
        $onlyInactive = @(
            [PSCustomObject]@{ name = "Test"; status = "inactive"; salary = [decimal]50000; department = "X"; hire_date = "2020-01-01" }
        )
        $result = Get-ActiveEmployees -Employees $onlyInactive
        $result.Count | Should -Be 0
    }
}

# ============================================================
# Feature 3: Get-DepartmentStats
# RED: These tests will fail until Get-DepartmentStats is implemented
# Active Engineering: Alice(95k) + Bob(85k) + Dave(105k) + Iris(92k) = 377k / 4 = 94250
# Active Marketing:   Eve(68k) + Henry(75k) = 143k / 2 = 71500
# Active HR:          Frank(62k) + Jack(65k) = 127k / 2 = 63500
# ============================================================
Describe "Get-DepartmentStats" {
    BeforeAll {
        $script:AllEmployees    = Import-EmployeeCsv -Path $script:CsvPath
        $script:ActiveEmployees = Get-ActiveEmployees -Employees $script:AllEmployees
    }

    It "should return stats for all 3 departments" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $stats.Count | Should -Be 3
    }

    It "should compute correct headcount for Engineering" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $eng = $stats | Where-Object { $_.Department -eq "Engineering" }
        $eng.Headcount | Should -Be 4
    }

    It "should compute correct headcount for Marketing" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $mkt = $stats | Where-Object { $_.Department -eq "Marketing" }
        $mkt.Headcount | Should -Be 2
    }

    It "should compute correct headcount for HR" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $hr = $stats | Where-Object { $_.Department -eq "HR" }
        $hr.Headcount | Should -Be 2
    }

    It "should compute correct average salary for Engineering" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $eng = $stats | Where-Object { $_.Department -eq "Engineering" }
        $eng.AverageSalary | Should -Be 94250
    }

    It "should compute correct average salary for Marketing" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $mkt = $stats | Where-Object { $_.Department -eq "Marketing" }
        $mkt.AverageSalary | Should -Be 71500
    }

    It "should include TotalPayroll per department" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $eng = $stats | Where-Object { $_.Department -eq "Engineering" }
        $eng.TotalPayroll | Should -Be 377000
    }
}

# ============================================================
# Feature 4: Get-OverallStats
# RED: These tests will fail until Get-OverallStats is implemented
# Active total payroll: 95k+85k+105k+68k+62k+75k+92k+65k = 647k
# Average: 647000 / 8 = 80875
# ============================================================
Describe "Get-OverallStats" {
    BeforeAll {
        $script:AllEmployees    = Import-EmployeeCsv -Path $script:CsvPath
        $script:ActiveEmployees = Get-ActiveEmployees -Employees $script:AllEmployees
    }

    It "should compute total active employee count" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.TotalEmployees | Should -Be 8
    }

    It "should compute overall average salary" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.AverageSalary | Should -Be 80875
    }

    It "should compute minimum salary across all active employees" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.MinSalary | Should -Be 62000
    }

    It "should compute maximum salary across all active employees" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.MaxSalary | Should -Be 105000
    }

    It "should compute total payroll across all active employees" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.TotalPayroll | Should -Be 647000
    }
}

# ============================================================
# Feature 5: Write-SummaryReport
# RED: These tests will fail until Write-SummaryReport is implemented
# ============================================================
Describe "Write-SummaryReport" {
    BeforeAll {
        $script:AllEmployees    = Import-EmployeeCsv -Path $script:CsvPath
        $script:ActiveEmployees = Get-ActiveEmployees -Employees $script:AllEmployees
        $script:DeptStats       = Get-DepartmentStats -Employees $script:ActiveEmployees
        $script:OverallStats    = Get-OverallStats -Employees $script:ActiveEmployees
        $script:ReportPath      = "$PSScriptRoot/fixtures/report.txt"
    }

    It "should create a report file at the specified path" {
        Write-SummaryReport -DepartmentStats $script:DeptStats -OverallStats $script:OverallStats -OutputPath $script:ReportPath
        Test-Path $script:ReportPath | Should -Be $true
    }

    It "should include department names in the report" {
        Write-SummaryReport -DepartmentStats $script:DeptStats -OverallStats $script:OverallStats -OutputPath $script:ReportPath
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "Engineering"
        $content | Should -Match "Marketing"
        $content | Should -Match "HR"
    }

    It "should include overall statistics labels in the report" {
        Write-SummaryReport -DepartmentStats $script:DeptStats -OverallStats $script:OverallStats -OutputPath $script:ReportPath
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "Total Employees"
        $content | Should -Match "Average Salary"
    }

    It "should include the correct employee count in the report" {
        Write-SummaryReport -DepartmentStats $script:DeptStats -OverallStats $script:OverallStats -OutputPath $script:ReportPath
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "8"
    }

    It "should include salary figures in the report" {
        Write-SummaryReport -DepartmentStats $script:DeptStats -OverallStats $script:OverallStats -OutputPath $script:ReportPath
        $content = Get-Content $script:ReportPath -Raw
        # Check that some salary numbers appear
        $content | Should -Match "80875|80,875"
    }

    AfterAll {
        if (Test-Path $script:ReportPath) {
            Remove-Item $script:ReportPath -Force
        }
    }
}
