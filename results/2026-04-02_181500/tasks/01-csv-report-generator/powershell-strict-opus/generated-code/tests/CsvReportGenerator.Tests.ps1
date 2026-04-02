# Pester tests for CsvReportGenerator module
# TDD approach: each Describe block was written as a failing test first,
# then the minimum implementation was added to make it pass, then refactored.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test from src/
$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '../src/CsvReportGenerator.psm1'
Import-Module -Name $ModulePath -Force

# Path to test fixtures
$FixturePath = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures/employees.csv'

# ============================================================================
# RED/GREEN CYCLE 1: Import CSV — read a CSV file and return typed rows
# ============================================================================
Describe 'Import-EmployeeCsv' {
    Context 'when given a valid CSV file' {
        It 'should import all 12 rows from the fixture' {
            [PSCustomObject[]]$result = @(Import-EmployeeCsv -Path $FixturePath)
            $result.Count | Should -Be 12
        }

        It 'should return objects with the expected properties' {
            [PSCustomObject[]]$result = @(Import-EmployeeCsv -Path $FixturePath)
            [PSCustomObject]$first = $result[0]
            $first.name | Should -Be 'Alice Johnson'
            $first.department | Should -Be 'Engineering'
            $first.salary | Should -Be '95000'
            $first.hire_date | Should -Be '2020-01-15'
            $first.status | Should -Be 'active'
        }
    }

    Context 'when given a non-existent file' {
        It 'should throw a meaningful error' {
            { Import-EmployeeCsv -Path 'nonexistent.csv' } |
                Should -Throw '*not found*'
        }
    }

    Context 'when CSV is missing required columns' {
        It 'should throw identifying the missing column' {
            # Create a temp CSV missing the salary column
            [string]$tmpFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'bad_cols.csv'
            'name,department,hire_date,status' | Set-Content -Path $tmpFile
            'Alice,Eng,2020-01-01,active' | Add-Content -Path $tmpFile
            try {
                { Import-EmployeeCsv -Path $tmpFile } | Should -Throw '*salary*'
            }
            finally {
                Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ============================================================================
# RED/GREEN CYCLE 2: Filter to active employees only
# ============================================================================
Describe 'Select-ActiveEmployees' {
    BeforeAll {
        [PSCustomObject[]]$script:MockEmployees = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Eng'; salary = '90000'; hire_date = '2020-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Bob'; department = 'Eng'; salary = '80000'; hire_date = '2019-01-01'; status = 'inactive' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Sales'; salary = '70000'; hire_date = '2021-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Dave'; department = 'Sales'; salary = '75000'; hire_date = '2022-01-01'; status = 'Active' }
        )
    }

    It 'should return only employees with active status (case-insensitive)' {
        [PSCustomObject[]]$result = @(Select-ActiveEmployees -Employees $script:MockEmployees)
        $result.Count | Should -Be 3
    }

    It 'should include Dave whose status is capitalized Active' {
        [PSCustomObject[]]$result = @(Select-ActiveEmployees -Employees $script:MockEmployees)
        [string[]]$names = @($result | ForEach-Object { [string]$_.name })
        $names | Should -Contain 'Dave'
    }

    It 'should return empty array when no active employees exist' {
        [PSCustomObject[]]$inactive = @(
            [PSCustomObject]@{ name = 'X'; department = 'D'; salary = '1'; hire_date = '2020-01-01'; status = 'inactive' }
        )
        [PSCustomObject[]]$result = @(Select-ActiveEmployees -Employees $inactive)
        $result.Count | Should -Be 0
    }
}

# ============================================================================
# RED/GREEN CYCLE 3: Average salary by department
# ============================================================================
Describe 'Get-AverageSalaryByDepartment' {
    BeforeAll {
        [PSCustomObject[]]$script:ActiveEmps = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Engineering'; salary = '100000'; hire_date = '2020-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Bob'; department = 'Engineering'; salary = '80000'; hire_date = '2019-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Marketing'; salary = '70000'; hire_date = '2021-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Dave'; department = 'Marketing'; salary = '60000'; hire_date = '2022-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Eve'; department = 'Marketing'; salary = '75000'; hire_date = '2020-06-01'; status = 'active' }
        )
    }

    It 'should return a hashtable with one key per department' {
        [hashtable]$result = Get-AverageSalaryByDepartment -Employees $script:ActiveEmps
        $result.Keys.Count | Should -Be 2
    }

    It 'should compute correct average for Engineering: (100000+80000)/2 = 90000' {
        [hashtable]$result = Get-AverageSalaryByDepartment -Employees $script:ActiveEmps
        $result['Engineering'] | Should -Be 90000
    }

    It 'should compute correct average for Marketing: (70000+60000+75000)/3 = 68333.33' {
        [hashtable]$result = Get-AverageSalaryByDepartment -Employees $script:ActiveEmps
        $result['Marketing'] | Should -Be 68333.33
    }
}

# ============================================================================
# RED/GREEN CYCLE 4: Headcount by department
# ============================================================================
Describe 'Get-HeadcountByDepartment' {
    BeforeAll {
        [PSCustomObject[]]$script:ActiveEmps = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Engineering'; salary = '100000'; hire_date = '2020-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Bob'; department = 'Engineering'; salary = '80000'; hire_date = '2019-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Marketing'; salary = '70000'; hire_date = '2021-01-01'; status = 'active' }
        )
    }

    It 'should return correct headcount for each department' {
        [hashtable]$result = Get-HeadcountByDepartment -Employees $script:ActiveEmps
        $result['Engineering'] | Should -Be 2
        $result['Marketing'] | Should -Be 1
    }

    It 'should handle empty input' {
        [PSCustomObject[]]$empty = @()
        [hashtable]$result = Get-HeadcountByDepartment -Employees $empty
        $result.Keys.Count | Should -Be 0
    }
}

# ============================================================================
# RED/GREEN CYCLE 5: Overall statistics
# ============================================================================
Describe 'Get-OverallStatistics' {
    BeforeAll {
        [PSCustomObject[]]$script:ActiveEmps = @(
            [PSCustomObject]@{ name = 'Alice'; department = 'Eng'; salary = '100000'; hire_date = '2020-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Bob'; department = 'Eng'; salary = '80000'; hire_date = '2019-01-01'; status = 'active' }
            [PSCustomObject]@{ name = 'Carol'; department = 'Sales'; salary = '60000'; hire_date = '2021-01-01'; status = 'active' }
        )
    }

    It 'should return correct total employee count' {
        [hashtable]$stats = Get-OverallStatistics -Employees $script:ActiveEmps
        $stats.TotalEmployees | Should -Be 3
    }

    It 'should return correct average salary: (100000+80000+60000)/3 = 80000' {
        [hashtable]$stats = Get-OverallStatistics -Employees $script:ActiveEmps
        $stats.AverageSalary | Should -Be 80000
    }

    It 'should return correct min and max salary' {
        [hashtable]$stats = Get-OverallStatistics -Employees $script:ActiveEmps
        $stats.MinSalary | Should -Be 60000
        $stats.MaxSalary | Should -Be 100000
    }

    It 'should return correct total payroll' {
        [hashtable]$stats = Get-OverallStatistics -Employees $script:ActiveEmps
        $stats.TotalPayroll | Should -Be 240000
    }

    It 'should handle empty employee list gracefully' {
        [PSCustomObject[]]$empty = @()
        [hashtable]$stats = Get-OverallStatistics -Employees $empty
        $stats.TotalEmployees | Should -Be 0
        $stats.AverageSalary | Should -Be 0
        $stats.TotalPayroll | Should -Be 0
    }
}

# ============================================================================
# RED/GREEN CYCLE 6: Format the summary report as a readable text string
# ============================================================================
Describe 'Format-SummaryReport' {
    BeforeAll {
        [hashtable]$script:AvgSalary = @{
            'Engineering' = [double]90000.00
            'Marketing'   = [double]68333.33
        }
        [hashtable]$script:Headcount = @{
            'Engineering' = [int]2
            'Marketing'   = [int]3
        }
        [hashtable]$script:Overall = @{
            TotalEmployees = [int]5
            AverageSalary  = [double]77000.00
            MinSalary      = [double]60000.00
            MaxSalary      = [double]100000.00
            TotalPayroll   = [double]385000.00
        }
    }

    It 'should return a non-empty string' {
        [string]$report = Format-SummaryReport -AverageSalary $script:AvgSalary -Headcount $script:Headcount -OverallStats $script:Overall
        $report | Should -Not -BeNullOrEmpty
    }

    It 'should include a report header' {
        [string]$report = Format-SummaryReport -AverageSalary $script:AvgSalary -Headcount $script:Headcount -OverallStats $script:Overall
        $report | Should -Match 'EMPLOYEE SUMMARY REPORT'
    }

    It 'should include department names sorted alphabetically' {
        [string]$report = Format-SummaryReport -AverageSalary $script:AvgSalary -Headcount $script:Headcount -OverallStats $script:Overall
        $report | Should -Match 'Engineering'
        $report | Should -Match 'Marketing'
        # Engineering should appear before Marketing
        [int]$engIdx = $report.IndexOf('Engineering')
        [int]$mktIdx = $report.IndexOf('Marketing')
        $engIdx | Should -BeLessThan $mktIdx
    }

    It 'should include overall statistics section' {
        [string]$report = Format-SummaryReport -AverageSalary $script:AvgSalary -Headcount $script:Headcount -OverallStats $script:Overall
        $report | Should -Match 'OVERALL STATISTICS'
        $report | Should -Match '5'
    }

    It 'should include dollar-formatted salary figures' {
        [string]$report = Format-SummaryReport -AverageSalary $script:AvgSalary -Headcount $script:Headcount -OverallStats $script:Overall
        $report | Should -Match '\$'
    }
}

# ============================================================================
# RED/GREEN CYCLE 7: Export report to file
# ============================================================================
Describe 'Export-SummaryReport' {
    BeforeAll {
        $script:TestOutputDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pester_export_$(Get-Random)"
        [void](New-Item -Path $script:TestOutputDir -ItemType Directory -Force)
    }

    AfterAll {
        if (Test-Path -Path $script:TestOutputDir) {
            Remove-Item -Path $script:TestOutputDir -Recurse -Force
        }
    }

    It 'should write content to the specified file' {
        [string]$outPath = Join-Path -Path $script:TestOutputDir -ChildPath 'report.txt'
        Export-SummaryReport -Report 'Hello Report' -OutputPath $outPath
        Test-Path -Path $outPath | Should -BeTrue
        [string]$content = Get-Content -Path $outPath -Raw
        $content | Should -Match 'Hello Report'
    }

    It 'should create parent directories if they do not exist' {
        [string]$outPath = Join-Path -Path $script:TestOutputDir -ChildPath 'subdir/nested_report.txt'
        Export-SummaryReport -Report 'Nested' -OutputPath $outPath
        Test-Path -Path $outPath | Should -BeTrue
    }
}

# ============================================================================
# RED/GREEN CYCLE 8: End-to-end integration — Invoke-CsvReportGenerator
# ============================================================================
Describe 'Invoke-CsvReportGenerator (Integration)' {
    BeforeAll {
        $script:TestOutputDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pester_integration_$(Get-Random)"
        [void](New-Item -Path $script:TestOutputDir -ItemType Directory -Force)
        $script:OutputFile = Join-Path -Path $script:TestOutputDir -ChildPath 'report.txt'
    }

    AfterAll {
        if (Test-Path -Path $script:TestOutputDir) {
            Remove-Item -Path $script:TestOutputDir -Recurse -Force
        }
    }

    It 'should generate a report file from the CSV fixture' {
        [string]$report = Invoke-CsvReportGenerator -CsvPath $FixturePath -OutputPath $script:OutputFile
        Test-Path -Path $script:OutputFile | Should -BeTrue
        $report | Should -Not -BeNullOrEmpty
    }

    It 'should contain all four active departments in the output' {
        [string]$report = Get-Content -Path $script:OutputFile -Raw
        $report | Should -Match 'Engineering'
        $report | Should -Match 'Marketing'
        $report | Should -Match 'Sales'
        $report | Should -Match 'HR'
    }

    It 'should reflect the correct active headcount of 9' {
        # Fixture has 12 employees, 3 inactive → 9 active
        [string]$report = Get-Content -Path $script:OutputFile -Raw
        $report | Should -Match 'Total Active Employees\s*:\s*9'
    }

    It 'should throw for a missing CSV file' {
        { Invoke-CsvReportGenerator -CsvPath 'missing.csv' -OutputPath $script:OutputFile } |
            Should -Throw '*not found*'
    }

    It 'should throw when all employees are inactive' {
        [string]$tmpCsv = Join-Path -Path $script:TestOutputDir -ChildPath 'all_inactive.csv'
        @'
name,department,salary,hire_date,status
X,Dept,50000,2020-01-01,inactive
'@ | Set-Content -Path $tmpCsv
        { Invoke-CsvReportGenerator -CsvPath $tmpCsv -OutputPath $script:OutputFile } |
            Should -Throw '*No active employees*'
    }
}
