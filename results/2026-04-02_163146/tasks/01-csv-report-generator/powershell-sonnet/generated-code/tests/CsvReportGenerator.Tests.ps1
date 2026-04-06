# CsvReportGenerator.Tests.ps1
# TDD tests for the CSV Report Generator
# Run with: Invoke-Pester ./tests/CsvReportGenerator.Tests.ps1

BeforeAll {
    # Import the module under test. This will fail until the module is created (RED phase).
    . "$PSScriptRoot/../src/CsvReportGenerator.ps1"
}

Describe "Read-EmployeeCsv" {
    # --- RED: This test will fail until Read-EmployeeCsv is implemented ---

    It "reads all records from a valid CSV file" {
        $csvPath = "$PSScriptRoot/../fixtures/employees.csv"
        $records = Read-EmployeeCsv -Path $csvPath
        $records.Count | Should -Be 12
    }

    It "returns objects with the expected properties" {
        $csvPath = "$PSScriptRoot/../fixtures/employees.csv"
        $records = Read-EmployeeCsv -Path $csvPath
        $first = $records[0]
        $first.PSObject.Properties.Name | Should -Contain "name"
        $first.PSObject.Properties.Name | Should -Contain "department"
        $first.PSObject.Properties.Name | Should -Contain "salary"
        $first.PSObject.Properties.Name | Should -Contain "hire_date"
        $first.PSObject.Properties.Name | Should -Contain "status"
    }

    It "throws a meaningful error for a missing file" {
        { Read-EmployeeCsv -Path "nonexistent.csv" } | Should -Throw "*not found*"
    }
}

Describe "Get-ActiveEmployees" {
    # --- RED: Will fail until Get-ActiveEmployees is implemented ---

    BeforeAll {
        $csvPath = "$PSScriptRoot/../fixtures/employees.csv"
        $script:AllEmployees = Read-EmployeeCsv -Path $csvPath
    }

    It "returns only employees with status 'active'" {
        $active = Get-ActiveEmployees -Employees $script:AllEmployees
        $active | ForEach-Object { $_.status | Should -Be "active" }
    }

    It "filters out inactive employees" {
        $active = Get-ActiveEmployees -Employees $script:AllEmployees
        # Fixture has 12 total; David Brown, Frank Miller, Jack Anderson are inactive => 9 active
        $active.Count | Should -Be 9
    }

    It "returns empty array when no active employees exist" {
        $allInactive = @(
            [PSCustomObject]@{ name = "X"; department = "A"; salary = 50000; hire_date = "2020-01-01"; status = "inactive" }
        )
        $active = Get-ActiveEmployees -Employees $allInactive
        $active.Count | Should -Be 0
    }
}

Describe "Get-DepartmentStats" {
    # --- RED: Will fail until Get-DepartmentStats is implemented ---

    BeforeAll {
        $csvPath = "$PSScriptRoot/../fixtures/employees.csv"
        $allEmployees = Read-EmployeeCsv -Path $csvPath
        $script:ActiveEmployees = Get-ActiveEmployees -Employees $allEmployees
    }

    It "returns a result for each department" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        $depts = $stats | Select-Object -ExpandProperty Department
        $depts | Should -Contain "Engineering"
        $depts | Should -Contain "Marketing"
        $depts | Should -Contain "HR"
    }

    It "computes correct headcount per department" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        # Active: Engineering: Alice(95k), Carol(105k), Iris(112k), Kate(98k) = 4
        #         Marketing:   Bob(72k), Eve(78k), Henry(65k), Liam(75k) = 4
        #         HR:          Grace(71k) = 1
        $engStats = $stats | Where-Object { $_.Department -eq "Engineering" }
        $engStats.Headcount | Should -Be 4

        $mktStats = $stats | Where-Object { $_.Department -eq "Marketing" }
        $mktStats.Headcount | Should -Be 4

        $hrStats = $stats | Where-Object { $_.Department -eq "HR" }
        $hrStats.Headcount | Should -Be 1
    }

    It "computes correct average salary per department" {
        $stats = Get-DepartmentStats -Employees $script:ActiveEmployees
        # Engineering avg: (95000+105000+112000+98000)/4 = 410000/4 = 102500
        $engStats = $stats | Where-Object { $_.Department -eq "Engineering" }
        $engStats.AverageSalary | Should -Be 102500

        # HR avg: 71000/1 = 71000
        $hrStats = $stats | Where-Object { $_.Department -eq "HR" }
        $hrStats.AverageSalary | Should -Be 71000
    }
}

Describe "Get-OverallStats" {
    # --- RED: Will fail until Get-OverallStats is implemented ---

    BeforeAll {
        $csvPath = "$PSScriptRoot/../fixtures/employees.csv"
        $allEmployees = Read-EmployeeCsv -Path $csvPath
        $script:ActiveEmployees = Get-ActiveEmployees -Employees $allEmployees
    }

    It "returns total active headcount" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.TotalHeadcount | Should -Be 9
    }

    It "returns correct overall average salary" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        # Sum of active salaries: 95000+72000+105000+78000+71000+65000+112000+75000+98000 = 771000
        # Average: 771000/9 = 85666.67 (rounded to 2dp)
        # Pester 5 BeApproximately: pipe actual value, first positional arg is expected, -Tolerance sets delta
        $stats.AverageSalary | Should -BeApproximately 85666.67 -Tolerance 0.01
    }

    It "returns correct min and max salary" {
        $stats = Get-OverallStats -Employees $script:ActiveEmployees
        $stats.MinSalary | Should -Be 65000
        $stats.MaxSalary | Should -Be 112000
    }
}

Describe "Write-SummaryReport" {
    # --- RED: Will fail until Write-SummaryReport is implemented ---

    BeforeAll {
        $csvPath = "$PSScriptRoot/../fixtures/employees.csv"
        $allEmployees = Read-EmployeeCsv -Path $csvPath
        $script:ActiveEmployees = Get-ActiveEmployees -Employees $allEmployees
        $script:DeptStats       = Get-DepartmentStats -Employees $script:ActiveEmployees
        $script:OverallStats    = Get-OverallStats    -Employees $script:ActiveEmployees

        $script:ReportPath = [System.IO.Path]::GetTempFileName()
        Write-SummaryReport `
            -DepartmentStats $script:DeptStats `
            -OverallStats    $script:OverallStats `
            -OutputPath      $script:ReportPath
    }

    AfterAll {
        if (Test-Path $script:ReportPath) { Remove-Item $script:ReportPath -Force }
    }

    It "creates the output file" {
        Test-Path $script:ReportPath | Should -BeTrue
    }

    It "report contains a department-level section" {
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "Department"
    }

    It "report contains Engineering statistics" {
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "Engineering"
    }

    It "report contains overall statistics section" {
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "Overall"
    }

    It "report contains total headcount" {
        $content = Get-Content $script:ReportPath -Raw
        $content | Should -Match "9"
    }
}
