Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# EmployeeReport.ps1 — Functions for reading employee CSV data,
# computing aggregates, and generating a formatted summary report.

function Import-EmployeeCsv {
    <#
    .SYNOPSIS
        Reads employee records from a CSV file.
    .DESCRIPTION
        Imports a CSV file with columns: name, department, salary, hire_date, status.
        Throws if the file does not exist.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "CSV file not found: $Path"
    }

    [object[]]$records = Import-Csv -Path $Path
    return $records
}

function Get-ActiveEmployees {
    <#
    .SYNOPSIS
        Filters employee records to only those with status 'active'.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Employees
    )

    [object[]]$active = $Employees | Where-Object { $_.status -eq 'active' }
    return $active
}

function Get-DepartmentAggregates {
    <#
    .SYNOPSIS
        Computes per-department headcount and average salary from employee records.
    .DESCRIPTION
        Groups employees by department. For each department, computes the headcount
        and the average salary (casting from string to decimal). Returns a hashtable
        keyed by department name.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Employees
    )

    [hashtable]$result = @{}

    # Group by department and compute aggregates
    $groups = $Employees | Group-Object -Property department
    foreach ($group in $groups) {
        [string]$dept = $group.Name
        [int]$headcount = $group.Count
        [decimal[]]$salaries = $group.Group | ForEach-Object { [decimal]$_.salary }
        [decimal]$avgSalary = ($salaries | Measure-Object -Average).Average

        $result[$dept] = [PSCustomObject]@{
            Department    = $dept
            Headcount     = $headcount
            AverageSalary = $avgSalary
        }
    }

    return $result
}

function Get-OverallStatistics {
    <#
    .SYNOPSIS
        Computes overall statistics across all employees.
    .DESCRIPTION
        Returns a PSCustomObject with TotalHeadcount, AverageSalary,
        MinSalary, MaxSalary, and TotalSalary.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Employees
    )

    [decimal[]]$salaries = $Employees | ForEach-Object { [decimal]$_.salary }
    $measure = $salaries | Measure-Object -Average -Minimum -Maximum -Sum

    return [PSCustomObject]@{
        TotalHeadcount = [int]$measure.Count
        AverageSalary  = [decimal]$measure.Average
        MinSalary      = [decimal]$measure.Minimum
        MaxSalary      = [decimal]$measure.Maximum
        TotalSalary    = [decimal]$measure.Sum
    }
}

function Format-Currency {
    <#
    .SYNOPSIS
        Formats a decimal value as currency with comma separators and two decimal places.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [decimal]$Value
    )

    return $Value.ToString('N2')
}

function Export-EmployeeReport {
    <#
    .SYNOPSIS
        Generates a formatted summary report and writes it to a text file.
    .DESCRIPTION
        Takes active employee records, computes department aggregates and
        overall statistics, then writes a formatted report to the specified path.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Employees,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    [hashtable]$deptAgg = Get-DepartmentAggregates -Employees $Employees
    $overallStats = Get-OverallStatistics -Employees $Employees

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Title
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine('       Employee Summary Report')
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine('')

    # Department breakdown — sort alphabetically for consistent output
    [void]$sb.AppendLine('--- Department Breakdown ---')
    [void]$sb.AppendLine('')

    [string[]]$sortedDepts = $deptAgg.Keys | Sort-Object
    foreach ($dept in $sortedDepts) {
        $info = $deptAgg[$dept]
        [void]$sb.AppendLine("  $dept")
        [void]$sb.AppendLine("    Headcount:      $([int]$info.Headcount)")
        [void]$sb.AppendLine("    Average Salary:  $(Format-Currency -Value ([decimal]$info.AverageSalary))")
        [void]$sb.AppendLine('')
    }

    # Overall statistics
    [void]$sb.AppendLine('--- Overall Statistics ---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("  Total Active Employees: $([int]$overallStats.TotalHeadcount)")
    [void]$sb.AppendLine("  Average Salary:         $(Format-Currency -Value ([decimal]$overallStats.AverageSalary))")
    [void]$sb.AppendLine("  Minimum Salary:         $(Format-Currency -Value ([decimal]$overallStats.MinSalary))")
    [void]$sb.AppendLine("  Maximum Salary:         $(Format-Currency -Value ([decimal]$overallStats.MaxSalary))")
    [void]$sb.AppendLine("  Total Salary:           $(Format-Currency -Value ([decimal]$overallStats.TotalSalary))")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('========================================')

    [string]$report = $sb.ToString()
    Set-Content -Path $OutputPath -Value $report -Encoding utf8
}
