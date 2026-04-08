# Import the module under test
BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/EmployeeReport.ps1"
}

Describe 'CSV Parsing and Filtering' {
    BeforeAll {
        # Create test fixture CSV
        $script:FixturePath = Join-Path $TestDrive 'employees.csv'
        @"
name,department,salary,hire_date,status
Alice,Engineering,95000,2020-01-15,active
Bob,Marketing,72000,2019-06-01,inactive
Carol,Engineering,105000,2018-03-20,active
Dave,Marketing,68000,2021-09-10,active
Eve,HR,78000,2017-11-05,active
Frank,HR,82000,2022-02-14,inactive
"@ | Set-Content -Path $script:FixturePath -Encoding utf8
    }

    It 'Should import all rows from CSV' {
        [object[]]$rows = Import-EmployeeCsv -Path $script:FixturePath
        $rows.Count | Should -Be 6
    }

    It 'Should filter to active employees only' {
        [object[]]$rows = Import-EmployeeCsv -Path $script:FixturePath
        [object[]]$active = Get-ActiveEmployees -Employees $rows
        $active.Count | Should -Be 4
    }

    It 'Should exclude inactive employees' {
        [object[]]$rows = Import-EmployeeCsv -Path $script:FixturePath
        [object[]]$active = Get-ActiveEmployees -Employees $rows
        $active | ForEach-Object { $_.status | Should -Be 'active' }
    }

    It 'Should throw on missing file' {
        { Import-EmployeeCsv -Path '/nonexistent/path.csv' } | Should -Throw
    }
}

Describe 'Department Aggregates' {
    BeforeAll {
        # Build fixture data in-memory (active employees only)
        $script:ActiveEmployees = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Engineering'; salary = '95000'; hire_date = '2020-01-15'; status = 'active' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Engineering'; salary = '105000'; hire_date = '2018-03-20'; status = 'active' }
            [PSCustomObject]@{ name = 'Dave'; department = 'Marketing'; salary = '68000'; hire_date = '2021-09-10'; status = 'active' }
            [PSCustomObject]@{ name = 'Eve'; department = 'HR'; salary = '78000'; hire_date = '2017-11-05'; status = 'active' }
        )
    }

    It 'Should compute average salary per department' {
        [hashtable]$agg = Get-DepartmentAggregates -Employees $script:ActiveEmployees
        # Engineering: (95000 + 105000) / 2 = 100000
        $agg['Engineering'].AverageSalary | Should -Be 100000
        # Marketing: 68000 / 1 = 68000
        $agg['Marketing'].AverageSalary | Should -Be 68000
        # HR: 78000 / 1 = 78000
        $agg['HR'].AverageSalary | Should -Be 78000
    }

    It 'Should compute headcount per department' {
        [hashtable]$agg = Get-DepartmentAggregates -Employees $script:ActiveEmployees
        $agg['Engineering'].Headcount | Should -Be 2
        $agg['Marketing'].Headcount | Should -Be 1
        $agg['HR'].Headcount | Should -Be 1
    }

    It 'Should include all departments' {
        [hashtable]$agg = Get-DepartmentAggregates -Employees $script:ActiveEmployees
        $agg.Keys.Count | Should -Be 3
    }
}

Describe 'Overall Statistics' {
    BeforeAll {
        $script:ActiveEmployees = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Engineering'; salary = '95000'; hire_date = '2020-01-15'; status = 'active' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Engineering'; salary = '105000'; hire_date = '2018-03-20'; status = 'active' }
            [PSCustomObject]@{ name = 'Dave'; department = 'Marketing'; salary = '68000'; hire_date = '2021-09-10'; status = 'active' }
            [PSCustomObject]@{ name = 'Eve'; department = 'HR'; salary = '78000'; hire_date = '2017-11-05'; status = 'active' }
        )
    }

    It 'Should compute total headcount' {
        $stats = Get-OverallStatistics -Employees $script:ActiveEmployees
        $stats.TotalHeadcount | Should -Be 4
    }

    It 'Should compute overall average salary' {
        $stats = Get-OverallStatistics -Employees $script:ActiveEmployees
        # (95000 + 105000 + 68000 + 78000) / 4 = 86500
        $stats.AverageSalary | Should -Be 86500
    }

    It 'Should compute min and max salary' {
        $stats = Get-OverallStatistics -Employees $script:ActiveEmployees
        $stats.MinSalary | Should -Be 68000
        $stats.MaxSalary | Should -Be 105000
    }

    It 'Should compute total salary' {
        $stats = Get-OverallStatistics -Employees $script:ActiveEmployees
        $stats.TotalSalary | Should -Be 346000
    }
}

Describe 'Report Generation' {
    BeforeAll {
        $script:ActiveEmployees = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Engineering'; salary = '95000'; hire_date = '2020-01-15'; status = 'active' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Engineering'; salary = '105000'; hire_date = '2018-03-20'; status = 'active' }
            [PSCustomObject]@{ name = 'Dave'; department = 'Marketing'; salary = '68000'; hire_date = '2021-09-10'; status = 'active' }
            [PSCustomObject]@{ name = 'Eve'; department = 'HR'; salary = '78000'; hire_date = '2017-11-05'; status = 'active' }
        )
        $script:ReportPath = Join-Path $TestDrive 'report.txt'
        Export-EmployeeReport -Employees $script:ActiveEmployees -OutputPath $script:ReportPath
        $script:ReportContent = Get-Content -Path $script:ReportPath -Raw
    }

    It 'Should create the output file' {
        Test-Path -Path $script:ReportPath | Should -BeTrue
    }

    It 'Should contain a report title' {
        $script:ReportContent | Should -Match 'Employee Summary Report'
    }

    It 'Should contain department sections' {
        $script:ReportContent | Should -Match 'Engineering'
        $script:ReportContent | Should -Match 'Marketing'
        $script:ReportContent | Should -Match 'HR'
    }

    It 'Should show headcount for each department' {
        # Engineering has 2 employees
        $script:ReportContent | Should -Match '(?s)Engineering.*Headcount.*2'
    }

    It 'Should show average salary for each department' {
        # Engineering avg = 100,000
        $script:ReportContent | Should -Match '(?s)Engineering.*Average Salary.*100[,.]000'
    }

    It 'Should contain overall statistics section' {
        $script:ReportContent | Should -Match 'Overall Statistics'
        $script:ReportContent | Should -Match 'Total Active Employees.*4'
        $script:ReportContent | Should -Match 'Average Salary.*86[,.]500'
    }

    It 'Should show min and max salary in overall stats' {
        $script:ReportContent | Should -Match 'Minimum Salary.*68[,.]000'
        $script:ReportContent | Should -Match 'Maximum Salary.*105[,.]000'
    }
}

Describe 'End-to-End Integration' {
    BeforeAll {
        # Full CSV fixture with a mix of active/inactive employees
        $script:CsvPath = Join-Path $TestDrive 'integration_employees.csv'
        @"
name,department,salary,hire_date,status
Alice,Engineering,95000,2020-01-15,active
Bob,Marketing,72000,2019-06-01,inactive
Carol,Engineering,105000,2018-03-20,active
Dave,Marketing,68000,2021-09-10,active
Eve,HR,78000,2017-11-05,active
Frank,HR,82000,2022-02-14,inactive
Grace,Engineering,110000,2023-04-01,active
Hank,Sales,55000,2020-07-15,active
"@ | Set-Content -Path $script:CsvPath -Encoding utf8

        $script:ReportPath = Join-Path $TestDrive 'integration_report.txt'

        # Run the full pipeline
        [object[]]$allRows = Import-EmployeeCsv -Path $script:CsvPath
        [object[]]$activeRows = Get-ActiveEmployees -Employees $allRows
        Export-EmployeeReport -Employees $activeRows -OutputPath $script:ReportPath
        $script:ReportContent = Get-Content -Path $script:ReportPath -Raw
    }

    It 'Should only process active employees (6 out of 8)' {
        $script:ReportContent | Should -Match 'Total Active Employees.*6'
    }

    It 'Should include all 4 departments' {
        $script:ReportContent | Should -Match 'Engineering'
        $script:ReportContent | Should -Match 'Marketing'
        $script:ReportContent | Should -Match 'HR'
        $script:ReportContent | Should -Match 'Sales'
    }

    It 'Should correctly compute Engineering avg salary with 3 active employees' {
        # Engineering active: Alice 95000, Carol 105000, Grace 110000 -> avg = 103333.33
        $script:ReportContent | Should -Match '(?s)Engineering.*Average Salary.*103[,.]333'
    }

    It 'Should produce a non-empty report file' {
        (Get-Item -Path $script:ReportPath).Length | Should -BeGreaterThan 0
    }
}

Describe 'Edge Cases' {
    It 'Should handle empty CSV (headers only) gracefully' {
        [string]$emptyPath = Join-Path $TestDrive 'empty.csv'
        @"
name,department,salary,hire_date,status
"@ | Set-Content -Path $emptyPath -Encoding utf8

        # Import-Csv returns nothing for headers-only file; wrap in array for safety
        $rows = @(Import-Csv -Path $emptyPath)
        $rows.Count | Should -Be 0
    }

    It 'Should throw with a meaningful message on missing file' {
        { Import-EmployeeCsv -Path '/does/not/exist.csv' } |
            Should -Throw '*CSV file not found*'
    }
}
