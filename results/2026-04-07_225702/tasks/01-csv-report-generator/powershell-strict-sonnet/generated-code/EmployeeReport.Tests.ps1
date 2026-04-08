# TDD test suite for Employee Report Generator
# Red/Green cycle: each Describe block covers one piece of functionality.
# Tests were written BEFORE the implementation in EmployeeReport.psm1.
#
# STRICT MODE applied at script level; also required by the module itself.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test.
    # $PSScriptRoot is correctly set inside BeforeAll in Pester 5.
    $ModulePath = Join-Path $PSScriptRoot 'EmployeeReport.psm1'
    Import-Module $ModulePath -Force

    # Shared fixture path used by most tests.
    $script:FixturePath = Join-Path $PSScriptRoot 'fixtures' 'employees.csv'
}

# ---------------------------------------------------------------------------
# CYCLE 1 — Read-EmployeeCsv
# RED: this test block was written before Read-EmployeeCsv existed.
# ---------------------------------------------------------------------------
Describe 'Read-EmployeeCsv' {

    It 'returns a non-empty collection when given a valid CSV path' {
        $result = Read-EmployeeCsv -Path $script:FixturePath
        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns objects with the expected property names' {
        $result = Read-EmployeeCsv -Path $script:FixturePath
        $first = $result[0]
        $first.PSObject.Properties.Name | Should -Contain 'name'
        $first.PSObject.Properties.Name | Should -Contain 'department'
        $first.PSObject.Properties.Name | Should -Contain 'salary'
        $first.PSObject.Properties.Name | Should -Contain 'hire_date'
        $first.PSObject.Properties.Name | Should -Contain 'status'
    }

    It 'throws a meaningful error for a missing file' {
        { Read-EmployeeCsv -Path 'nonexistent.csv' } | Should -Throw '*not found*'
    }

    It 'salary property is cast to [decimal]' {
        $result = Read-EmployeeCsv -Path $script:FixturePath
        $result[0].salary | Should -BeOfType [decimal]
    }

    It 'returns all 15 rows from the fixture' {
        $result = Read-EmployeeCsv -Path $script:FixturePath
        $result.Count | Should -Be 15
    }
}

# ---------------------------------------------------------------------------
# CYCLE 2 — Get-ActiveEmployees
# RED: written before Get-ActiveEmployees existed.
# ---------------------------------------------------------------------------
Describe 'Get-ActiveEmployees' {

    It 'returns only employees whose status is Active' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $active | ForEach-Object { $_.status | Should -Be 'Active' }
    }

    It 'returns the correct count of active employees (12 from fixture)' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $active.Count | Should -Be 12
    }

    It 'returns an empty array (Count 0) when no employees are Active' {
        [System.Object[]]$none   = @(
            [pscustomobject]@{ name='X'; department='IT'; salary=[decimal]50000; hire_date='2020-01-01'; status='Inactive' }
        )
        [System.Object[]]$result = Get-ActiveEmployees -Employees $none
        $result.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Get-AverageSalaryByDepartment
# RED: written before Get-AverageSalaryByDepartment existed.
# ---------------------------------------------------------------------------
Describe 'Get-AverageSalaryByDepartment' {

    It 'returns a hashtable keyed by department name' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-AverageSalaryByDepartment -Employees $active
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain 'Engineering'
    }

    It 'calculates the correct average for Engineering (4 active: 95000+88000+105000+91000 = 94750)' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-AverageSalaryByDepartment -Employees $active
        $result['Engineering'] | Should -Be ([decimal]94750)
    }

    It 'calculates the correct average for HR (3 active: 61000+58000+65000 / 3 = 61333.33...)' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-AverageSalaryByDepartment -Employees $active
        [math]::Round([double]$result['HR'], 2) | Should -Be 61333.33
    }

    It 'returns an empty hashtable when no employees match' {
        # Build a 1-element inactive list, filter it → 0 active → empty hashtable
        [System.Object[]]$none   = @(
            [pscustomobject]@{ name='X'; department='IT'; salary=[decimal]50000; hire_date='2020-01-01'; status='Inactive' }
        )
        [System.Object[]]$active = Get-ActiveEmployees -Employees $none
        $result = Get-AverageSalaryByDepartment -Employees $active
        $result.Keys.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Get-HeadcountByDepartment
# RED: written before Get-HeadcountByDepartment existed.
# ---------------------------------------------------------------------------
Describe 'Get-HeadcountByDepartment' {

    It 'returns a hashtable keyed by department' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-HeadcountByDepartment -Employees $active
        $result | Should -BeOfType [hashtable]
    }

    It 'counts 4 active employees in Engineering' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-HeadcountByDepartment -Employees $active
        $result['Engineering'] | Should -Be 4
    }

    It 'counts 3 active employees in HR' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-HeadcountByDepartment -Employees $active
        $result['HR'] | Should -Be 3
    }

    It 'counts 2 active employees in Marketing' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-HeadcountByDepartment -Employees $active
        $result['Marketing'] | Should -Be 2
    }

    It 'counts 3 active employees in Finance' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-HeadcountByDepartment -Employees $active
        $result['Finance'] | Should -Be 3
    }
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Get-OverallStats
# RED: written before Get-OverallStats existed.
# ---------------------------------------------------------------------------
Describe 'Get-OverallStats' {

    It 'returns a hashtable with all expected keys' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-OverallStats -AllEmployees $all -ActiveEmployees $active
        $result | Should -BeOfType [hashtable]
        $result.Keys | Should -Contain 'TotalEmployees'
        $result.Keys | Should -Contain 'TotalActive'
        $result.Keys | Should -Contain 'TotalInactive'
        $result.Keys | Should -Contain 'OverallAverageSalary'
        $result.Keys | Should -Contain 'HighestSalary'
        $result.Keys | Should -Contain 'LowestSalary'
    }

    It 'TotalEmployees is 15' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-OverallStats -AllEmployees $all -ActiveEmployees $active
        $result['TotalEmployees'] | Should -Be 15
    }

    It 'TotalActive is 12' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-OverallStats -AllEmployees $all -ActiveEmployees $active
        $result['TotalActive'] | Should -Be 12
    }

    It 'TotalInactive is 3' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-OverallStats -AllEmployees $all -ActiveEmployees $active
        $result['TotalInactive'] | Should -Be 3
    }

    It 'HighestSalary among active employees is 105000' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-OverallStats -AllEmployees $all -ActiveEmployees $active
        $result['HighestSalary'] | Should -Be ([decimal]105000)
    }

    It 'LowestSalary among active employees is 58000' {
        [System.Object[]]$all    = Read-EmployeeCsv -Path $script:FixturePath
        [System.Object[]]$active = Get-ActiveEmployees -Employees $all
        $result = Get-OverallStats -AllEmployees $all -ActiveEmployees $active
        $result['LowestSalary'] | Should -Be ([decimal]58000)
    }
}

# ---------------------------------------------------------------------------
# CYCLE 6 — New-EmployeeReport (integration + file output)
# RED: written before New-EmployeeReport existed.
# ---------------------------------------------------------------------------
Describe 'New-EmployeeReport' {

    BeforeEach {
        # Each test gets its own temp output file to avoid cross-test side effects.
        $script:TempReport = Join-Path $TestDrive 'report.txt'
    }

    It 'creates the output file' {
        New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:TempReport
        Test-Path $script:TempReport | Should -BeTrue
    }

    It 'report file is not empty' {
        New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:TempReport
        (Get-Item $script:TempReport).Length | Should -BeGreaterThan 0
    }

    It 'report contains a Department Summary section' {
        New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:TempReport
        $content = Get-Content $script:TempReport -Raw
        $content | Should -Match 'Department Summary'
    }

    It 'report contains an Overall Statistics section' {
        New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:TempReport
        $content = Get-Content $script:TempReport -Raw
        $content | Should -Match 'Overall Statistics'
    }

    It 'report lists every department present in the active employees' {
        New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:TempReport
        $content = Get-Content $script:TempReport -Raw
        $content | Should -Match 'Engineering'
        $content | Should -Match 'Marketing'
        $content | Should -Match 'HR'
        $content | Should -Match 'Finance'
    }

    It 'report contains the correct headcount for Engineering (4)' {
        New-EmployeeReport -CsvPath $script:FixturePath -OutputPath $script:TempReport
        $content = Get-Content $script:TempReport -Raw
        # Matches a line like: Engineering              4  $94,750.00
        $content | Should -Match 'Engineering\s+4'
    }

    It 'throws when the CSV path does not exist' {
        { New-EmployeeReport -CsvPath 'missing.csv' -OutputPath $script:TempReport } |
            Should -Throw '*not found*'
    }
}
