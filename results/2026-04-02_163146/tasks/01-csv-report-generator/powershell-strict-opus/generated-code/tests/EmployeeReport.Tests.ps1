Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Root-level BeforeAll ensures variables are available in all It blocks (Pester v5)
BeforeAll {
    # Import the module under test
    $modulePath = Join-Path $PSScriptRoot '..' 'EmployeeReport.psm1'
    Import-Module $modulePath -Force

    # Path to test fixtures
    $script:fixturesPath = Join-Path $PSScriptRoot 'fixtures'
    $script:testCsvPath  = Join-Path $script:fixturesPath 'employees.csv'
}

# ---------------------------------------------------------------------------
# TDD Cycle 1: Reading and parsing CSV files
# RED:  function does not exist yet -> tests fail
# GREEN: implement Import-EmployeeData -> tests pass
# ---------------------------------------------------------------------------
Describe 'Import-EmployeeData' {
    Context 'when given a valid CSV file' {
        It 'should return an array of employee objects' {
            $result = Import-EmployeeData -Path $script:testCsvPath
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 12
        }

        It 'should parse all expected columns' {
            $result = Import-EmployeeData -Path $script:testCsvPath
            $first = $result[0]
            $first.name       | Should -Be 'Alice Johnson'
            $first.department | Should -Be 'Engineering'
            $first.salary     | Should -Be 95000
            $first.hire_date  | Should -Be '2020-01-15'
            $first.status     | Should -Be 'active'
        }

        It 'should cast salary to decimal' {
            $result = Import-EmployeeData -Path $script:testCsvPath
            $result[0].salary | Should -BeOfType [decimal]
        }
    }

    Context 'when given a non-existent file' {
        It 'should throw a meaningful error' {
            { Import-EmployeeData -Path 'nonexistent.csv' } |
                Should -Throw '*does not exist*'
        }
    }

    Context 'when given an empty CSV (header only)' {
        BeforeAll {
            $script:emptyCsv = Join-Path $script:fixturesPath 'empty_employees.csv'
            Set-Content -Path $script:emptyCsv -Value 'name,department,salary,hire_date,status'
        }

        It 'should return an empty array' {
            $result = Import-EmployeeData -Path $script:emptyCsv
            $result.Count | Should -Be 0
        }

        AfterAll {
            if (Test-Path $script:emptyCsv) { Remove-Item $script:emptyCsv }
        }
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 2: Filtering active employees
# RED:  Select-ActiveEmployees does not exist -> tests fail
# GREEN: implement filter logic -> tests pass
# ---------------------------------------------------------------------------
Describe 'Select-ActiveEmployees' {
    BeforeAll {
        $script:allEmployees = Import-EmployeeData -Path $script:testCsvPath
    }

    It 'should return only employees with status "active"' {
        $active = Select-ActiveEmployees -Employees $script:allEmployees
        $active | ForEach-Object { $_.status | Should -Be 'active' }
    }

    It 'should return 9 active employees from the fixture data' {
        $active = Select-ActiveEmployees -Employees $script:allEmployees
        $active.Count | Should -Be 9
    }

    It 'should return an empty array when no employees are active' {
        [PSCustomObject[]]$inactive = @(
            [PSCustomObject]@{ name = 'X'; department = 'D'; salary = [decimal]1; hire_date = '2020-01-01'; status = 'inactive' }
        )
        $result = Select-ActiveEmployees -Employees $inactive
        $result.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 3: Computing aggregate statistics
# RED:  Get-DepartmentStatistics / Get-OverallStatistics do not exist -> fail
# GREEN: implement aggregation logic -> tests pass
# ---------------------------------------------------------------------------
Describe 'Get-DepartmentStatistics' {
    BeforeAll {
        $emps = Import-EmployeeData -Path $script:testCsvPath
        $script:activeDept = Select-ActiveEmployees -Employees $emps
    }

    It 'should return a hashtable keyed by department name' {
        $stats = Get-DepartmentStatistics -Employees $script:activeDept
        $stats | Should -BeOfType [hashtable]
        $stats.Keys | Should -Contain 'Engineering'
        $stats.Keys | Should -Contain 'Marketing'
        $stats.Keys | Should -Contain 'HR'
        $stats.Keys | Should -Contain 'Sales'
    }

    It 'should compute correct headcount per department' {
        $stats = Get-DepartmentStatistics -Employees $script:activeDept
        $stats['Engineering'].Headcount | Should -Be 2
        $stats['Marketing'].Headcount   | Should -Be 2
        $stats['HR'].Headcount           | Should -Be 2
        $stats['Sales'].Headcount        | Should -Be 3
    }

    It 'should compute correct average salary per department' {
        $stats = Get-DepartmentStatistics -Employees $script:activeDept
        # Engineering: (95000 + 105000) / 2 = 100000
        $stats['Engineering'].AverageSalary | Should -Be 100000
        # Marketing: (72000 + 68000) / 2 = 70000
        $stats['Marketing'].AverageSalary   | Should -Be 70000
        # HR: (65000 + 70000) / 2 = 67500
        $stats['HR'].AverageSalary           | Should -Be 67500
        # Sales: (80000 + 85000 + 78000) / 3 = 81000
        $stats['Sales'].AverageSalary        | Should -Be 81000
    }

    It 'should compute correct total salary per department' {
        $stats = Get-DepartmentStatistics -Employees $script:activeDept
        $stats['Engineering'].TotalSalary | Should -Be 200000
        $stats['Sales'].TotalSalary       | Should -Be 243000
    }
}

Describe 'Get-OverallStatistics' {
    BeforeAll {
        $emps = Import-EmployeeData -Path $script:testCsvPath
        $script:activeOverall = Select-ActiveEmployees -Employees $emps
    }

    It 'should return a hashtable with overall metrics' {
        $overall = Get-OverallStatistics -Employees $script:activeOverall
        $overall | Should -BeOfType [hashtable]
    }

    It 'should compute correct total headcount' {
        $overall = Get-OverallStatistics -Employees $script:activeOverall
        $overall.TotalHeadcount | Should -Be 9
    }

    It 'should compute correct overall average salary' {
        $overall = Get-OverallStatistics -Employees $script:activeOverall
        # Sum: 95000+105000+72000+68000+65000+70000+80000+85000+78000 = 718000
        # Avg: 718000 / 9 = 79777.777...
        [math]::Round([decimal]$overall.AverageSalary, 2) | Should -Be 79777.78
    }

    It 'should compute correct min and max salary' {
        $overall = Get-OverallStatistics -Employees $script:activeOverall
        $overall.MinSalary | Should -Be 65000
        $overall.MaxSalary | Should -Be 105000
    }

    It 'should compute correct total salary' {
        $overall = Get-OverallStatistics -Employees $script:activeOverall
        $overall.TotalSalary | Should -Be 718000
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 4: Report formatting and file output
# RED:  Format-SummaryReport / Export-SummaryReport do not exist -> fail
# GREEN: implement formatting and file-write logic -> tests pass
# ---------------------------------------------------------------------------
Describe 'Format-SummaryReport' {
    BeforeAll {
        $emps    = Import-EmployeeData -Path $script:testCsvPath
        $active  = Select-ActiveEmployees -Employees $emps
        $script:deptStats = Get-DepartmentStatistics -Employees $active
        $script:overallStats = Get-OverallStatistics -Employees $active
    }

    It 'should return a non-empty string' {
        $report = Format-SummaryReport -DepartmentStats $script:deptStats -OverallStats $script:overallStats
        $report | Should -Not -BeNullOrEmpty
    }

    It 'should contain the report title' {
        $report = Format-SummaryReport -DepartmentStats $script:deptStats -OverallStats $script:overallStats
        $report | Should -Match 'Employee Summary Report'
    }

    It 'should contain department sections' {
        $report = Format-SummaryReport -DepartmentStats $script:deptStats -OverallStats $script:overallStats
        $report | Should -Match 'Engineering'
        $report | Should -Match 'Marketing'
        $report | Should -Match 'HR'
        $report | Should -Match 'Sales'
    }

    It 'should contain overall statistics section' {
        $report = Format-SummaryReport -DepartmentStats $script:deptStats -OverallStats $script:overallStats
        $report | Should -Match 'Overall Statistics'
        $report | Should -Match '9'
    }
}

Describe 'Export-SummaryReport' {
    It 'should write the report to a file' {
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "test_report_$(Get-Random).txt"
        try {
            $emps    = Import-EmployeeData -Path $script:testCsvPath
            $active  = Select-ActiveEmployees -Employees $emps
            $dStats  = Get-DepartmentStatistics -Employees $active
            $oStats  = Get-OverallStatistics -Employees $active
            $report  = Format-SummaryReport -DepartmentStats $dStats -OverallStats $oStats

            Export-SummaryReport -ReportContent $report -OutputPath $tempFile

            Test-Path $tempFile | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -Match 'Employee Summary Report'
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile }
        }
    }

    It 'should throw when output directory does not exist' {
        { Export-SummaryReport -ReportContent 'test' -OutputPath '/no/such/dir/report.txt' } |
            Should -Throw '*does not exist*'
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 5: End-to-end orchestration
# RED:  New-EmployeeSummaryReport does not exist -> fail
# GREEN: implement orchestrator that ties all functions together -> pass
# ---------------------------------------------------------------------------
Describe 'New-EmployeeSummaryReport (end-to-end)' {
    It 'should produce a complete report file from a CSV input' {
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "e2e_report_$(Get-Random).txt"
        try {
            New-EmployeeSummaryReport -CsvPath $script:testCsvPath -OutputPath $tempFile

            Test-Path $tempFile | Should -BeTrue
            $content = Get-Content -Path $tempFile -Raw
            $content | Should -Match 'Employee Summary Report'
            $content | Should -Match 'Engineering'
            $content | Should -Match 'Overall Statistics'
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile }
        }
    }

    It 'should throw for a missing CSV file' {
        { New-EmployeeSummaryReport -CsvPath 'missing.csv' -OutputPath 'out.txt' } |
            Should -Throw '*does not exist*'
    }
}
