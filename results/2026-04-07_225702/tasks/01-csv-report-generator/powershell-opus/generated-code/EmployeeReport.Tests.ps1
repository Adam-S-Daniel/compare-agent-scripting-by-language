# TDD tests for Employee CSV Report Generator
# Using Pester 5.x with red/green/refactor methodology

BeforeAll {
    . "$PSScriptRoot/EmployeeReport.ps1"
}

Describe "New-SampleEmployeeData" {
    It "creates a CSV file with the expected headers" {
        $tempFile = Join-Path $TestDrive "employees.csv"
        New-SampleEmployeeData -Path $tempFile

        $tempFile | Should -Exist
        $data = Import-Csv $tempFile
        $data[0].PSObject.Properties.Name | Should -Contain "name"
        $data[0].PSObject.Properties.Name | Should -Contain "department"
        $data[0].PSObject.Properties.Name | Should -Contain "salary"
        $data[0].PSObject.Properties.Name | Should -Contain "hire_date"
        $data[0].PSObject.Properties.Name | Should -Contain "status"
    }

    It "creates records with both active and inactive employees" {
        $tempFile = Join-Path $TestDrive "employees.csv"
        New-SampleEmployeeData -Path $tempFile

        $data = Import-Csv $tempFile
        $data.status | Should -Contain "active"
        $data.status | Should -Contain "inactive"
    }

    It "creates at least 10 records" {
        $tempFile = Join-Path $TestDrive "employees.csv"
        New-SampleEmployeeData -Path $tempFile

        $data = Import-Csv $tempFile
        $data.Count | Should -BeGreaterOrEqual 10
    }
}

Describe "Get-ActiveEmployees" {
    BeforeAll {
        $script:csvPath = Join-Path $TestDrive "employees.csv"
        New-SampleEmployeeData -Path $script:csvPath
    }

    It "returns only active employees" {
        $active = Get-ActiveEmployees -Path $script:csvPath
        $active | ForEach-Object { $_.status | Should -Be "active" }
    }

    It "excludes inactive employees" {
        $active = Get-ActiveEmployees -Path $script:csvPath
        $allData = Import-Csv $script:csvPath
        $inactiveNames = ($allData | Where-Object status -eq "inactive").name
        $active.name | Should -Not -Contain $inactiveNames[0]
    }

    It "returns the correct count of active employees" {
        $active = Get-ActiveEmployees -Path $script:csvPath
        # Sample data has 9 active out of 12 total
        $active.Count | Should -Be 9
    }

    It "throws an error for a non-existent file" {
        { Get-ActiveEmployees -Path "/nonexistent/file.csv" } | Should -Throw "*does not exist*"
    }
}

Describe "Get-DepartmentAggregates" {
    BeforeAll {
        # Build a controlled fixture with known values for precise assertions
        $script:csvPath = Join-Path $TestDrive "agg_employees.csv"
        @(
            [PSCustomObject]@{ name = "A"; department = "Eng";  salary = 100000; hire_date = "2020-01-01"; status = "active" }
            [PSCustomObject]@{ name = "B"; department = "Eng";  salary = 80000;  hire_date = "2021-01-01"; status = "active" }
            [PSCustomObject]@{ name = "C"; department = "Sales"; salary = 60000; hire_date = "2022-01-01"; status = "active" }
        ) | Export-Csv -Path $script:csvPath -NoTypeInformation
        $script:employees = Import-Csv $script:csvPath
    }

    It "returns one entry per department" {
        $agg = Get-DepartmentAggregates -Employees $script:employees
        $agg.Count | Should -Be 2
    }

    It "computes correct average salary per department" {
        $agg = Get-DepartmentAggregates -Employees $script:employees
        $eng = $agg | Where-Object Department -eq "Eng"
        $eng.AverageSalary | Should -Be 90000
    }

    It "computes correct headcount per department" {
        $agg = Get-DepartmentAggregates -Employees $script:employees
        $eng = $agg | Where-Object Department -eq "Eng"
        $eng.Headcount | Should -Be 2

        $sales = $agg | Where-Object Department -eq "Sales"
        $sales.Headcount | Should -Be 1
    }

    It "throws when given an empty employee list" {
        { Get-DepartmentAggregates -Employees @() } | Should -Throw "*No employee*"
    }
}

Describe "Get-OverallStatistics" {
    BeforeAll {
        # Controlled fixture: 3 employees with known salaries (60k, 80k, 100k)
        $script:employees = @(
            [PSCustomObject]@{ name = "A"; department = "Eng";   salary = "100000"; hire_date = "2020-01-01"; status = "active" }
            [PSCustomObject]@{ name = "B"; department = "Eng";   salary = "80000";  hire_date = "2021-01-01"; status = "active" }
            [PSCustomObject]@{ name = "C"; department = "Sales"; salary = "60000";  hire_date = "2022-01-01"; status = "active" }
        )
    }

    It "returns total headcount" {
        $stats = Get-OverallStatistics -Employees $script:employees
        $stats.TotalHeadcount | Should -Be 3
    }

    It "returns correct average salary" {
        $stats = Get-OverallStatistics -Employees $script:employees
        $stats.AverageSalary | Should -Be 80000
    }

    It "returns correct min and max salary" {
        $stats = Get-OverallStatistics -Employees $script:employees
        $stats.MinSalary | Should -Be 60000
        $stats.MaxSalary | Should -Be 100000
    }

    It "returns the total number of departments" {
        $stats = Get-OverallStatistics -Employees $script:employees
        $stats.DepartmentCount | Should -Be 2
    }
}

Describe "Export-EmployeeReport" {
    BeforeAll {
        # Set up a CSV with known data, then generate the report
        $script:csvPath = Join-Path $TestDrive "report_employees.csv"
        $script:reportPath = Join-Path $TestDrive "report.txt"
        New-SampleEmployeeData -Path $script:csvPath
    }

    It "creates the output report file" {
        Export-EmployeeReport -CsvPath $script:csvPath -ReportPath $script:reportPath
        $script:reportPath | Should -Exist
    }

    It "report contains the title line" {
        Export-EmployeeReport -CsvPath $script:csvPath -ReportPath $script:reportPath
        $content = Get-Content $script:reportPath -Raw
        $content | Should -Match "Employee Summary Report"
    }

    It "report contains department breakdown section" {
        Export-EmployeeReport -CsvPath $script:csvPath -ReportPath $script:reportPath
        $content = Get-Content $script:reportPath -Raw
        $content | Should -Match "Department Breakdown"
        $content | Should -Match "Engineering"
        $content | Should -Match "Marketing"
        $content | Should -Match "Sales"
        $content | Should -Match "HR"
    }

    It "report contains overall statistics section" {
        Export-EmployeeReport -CsvPath $script:csvPath -ReportPath $script:reportPath
        $content = Get-Content $script:reportPath -Raw
        $content | Should -Match "Overall Statistics"
        $content | Should -Match "Total Active Employees"
        $content | Should -Match "Average Salary"
    }

    It "report only reflects active employees" {
        Export-EmployeeReport -CsvPath $script:csvPath -ReportPath $script:reportPath
        $content = Get-Content $script:reportPath -Raw
        # 9 active employees in sample data
        $content | Should -Match "Total Active Employees:\s+9"
    }

    It "throws for a non-existent CSV input" {
        { Export-EmployeeReport -CsvPath "/no/such/file.csv" -ReportPath $script:reportPath } | Should -Throw
    }
}
