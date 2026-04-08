# Employee CSV Report Generator
# Reads employee CSV data, filters active employees, computes aggregates,
# and outputs a formatted summary report.

function New-SampleEmployeeData {
    # Creates a sample CSV file with employee records for testing and demonstration.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $records = @(
        [PSCustomObject]@{ name = "Alice Johnson";   department = "Engineering"; salary = 95000;  hire_date = "2020-03-15"; status = "active" }
        [PSCustomObject]@{ name = "Bob Smith";        department = "Engineering"; salary = 105000; hire_date = "2019-07-01"; status = "active" }
        [PSCustomObject]@{ name = "Carol Davis";      department = "Engineering"; salary = 88000;  hire_date = "2022-01-10"; status = "inactive" }
        [PSCustomObject]@{ name = "Dan Wilson";       department = "Marketing";   salary = 72000;  hire_date = "2021-06-20"; status = "active" }
        [PSCustomObject]@{ name = "Eve Martinez";     department = "Marketing";   salary = 78000;  hire_date = "2020-11-03"; status = "active" }
        [PSCustomObject]@{ name = "Frank Lee";        department = "Marketing";   salary = 68000;  hire_date = "2023-02-14"; status = "inactive" }
        [PSCustomObject]@{ name = "Grace Kim";        department = "Sales";       salary = 65000;  hire_date = "2021-09-01"; status = "active" }
        [PSCustomObject]@{ name = "Hank Brown";       department = "Sales";       salary = 70000;  hire_date = "2020-04-22"; status = "active" }
        [PSCustomObject]@{ name = "Iris Patel";       department = "Sales";       salary = 62000;  hire_date = "2022-08-30"; status = "active" }
        [PSCustomObject]@{ name = "Jack Chen";        department = "HR";          salary = 80000;  hire_date = "2019-12-05"; status = "active" }
        [PSCustomObject]@{ name = "Karen White";      department = "HR";          salary = 75000;  hire_date = "2021-03-18"; status = "inactive" }
        [PSCustomObject]@{ name = "Leo Garcia";       department = "HR";          salary = 82000;  hire_date = "2023-05-07"; status = "active" }
    )

    $records | Export-Csv -Path $Path -NoTypeInformation
}

function Get-ActiveEmployees {
    # Reads a CSV file and returns only rows where status is "active".
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "CSV file '$Path' does not exist."
    }

    Import-Csv $Path | Where-Object { $_.status -eq "active" }
}

function Get-DepartmentAggregates {
    # Groups employees by department and computes headcount and average salary.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Employees
    )

    if ($null -eq $Employees -or $Employees.Count -eq 0) {
        throw "No employee data provided."
    }

    $Employees | Group-Object -Property department | ForEach-Object {
        [PSCustomObject]@{
            Department    = $_.Name
            Headcount     = $_.Count
            AverageSalary = [math]::Round(($_.Group | Measure-Object -Property salary -Average).Average, 2)
        }
    }
}

function Get-OverallStatistics {
    # Computes summary statistics across all provided employees.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Employees
    )

    $salaryStats = $Employees | Measure-Object -Property salary -Average -Minimum -Maximum

    [PSCustomObject]@{
        TotalHeadcount  = $Employees.Count
        AverageSalary   = [math]::Round($salaryStats.Average, 2)
        MinSalary       = $salaryStats.Minimum
        MaxSalary       = $salaryStats.Maximum
        DepartmentCount = ($Employees | Select-Object -Property department -Unique).Count
    }
}

function Export-EmployeeReport {
    # Orchestrates the full pipeline: reads CSV, filters active employees,
    # computes aggregates, and writes a formatted text report.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath,

        [Parameter(Mandatory)]
        [string]$ReportPath
    )

    # Get active employees (this validates the file exists)
    $activeEmployees = Get-ActiveEmployees -Path $CsvPath

    # Compute aggregates
    $deptAggregates = Get-DepartmentAggregates -Employees $activeEmployees
    $overallStats   = Get-OverallStatistics   -Employees $activeEmployees

    # Build the formatted report
    $separator = "=" * 60
    $subSeparator = "-" * 60
    $report = @()

    $report += $separator
    $report += "  Employee Summary Report"
    $report += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "  Source:    $CsvPath"
    $report += $separator
    $report += ""

    # Department breakdown section
    $report += "  Department Breakdown"
    $report += $subSeparator
    $report += ""

    foreach ($dept in $deptAggregates | Sort-Object Department) {
        $report += "  Department:      $($dept.Department)"
        $report += "    Headcount:     $($dept.Headcount)"
        $report += "    Avg Salary:    `${0:N2}" -f $dept.AverageSalary
        $report += ""
    }

    # Overall statistics section
    $report += $subSeparator
    $report += "  Overall Statistics"
    $report += $subSeparator
    $report += ""
    $report += "  Total Active Employees: $($overallStats.TotalHeadcount)"
    $report += "  Departments:            $($overallStats.DepartmentCount)"
    $report += "  Average Salary:         `${0:N2}" -f $overallStats.AverageSalary
    $report += "  Min Salary:             `${0:N2}" -f $overallStats.MinSalary
    $report += "  Max Salary:             `${0:N2}" -f $overallStats.MaxSalary
    $report += ""
    $report += $separator

    # Write the report to the output file
    $report | Out-File -FilePath $ReportPath -Encoding utf8
}
