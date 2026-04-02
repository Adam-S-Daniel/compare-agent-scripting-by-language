Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ==========================================================================
# EmployeeReport Module
# Reads employee CSV data, filters active employees, computes aggregates,
# and generates a formatted summary report.
# ==========================================================================

function Import-EmployeeData {
    <#
    .SYNOPSIS
        Reads and parses a CSV file of employee records.
    .DESCRIPTION
        Imports employee data from a CSV with columns: name, department,
        salary, hire_date, status. Casts salary to [decimal] for accurate
        arithmetic. Returns an empty array when the CSV has only headers.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists — fail fast with a clear message
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "CSV file '$Path' does not exist."
    }

    # Import-Csv returns nothing for header-only files, so we guard
    [PSCustomObject[]]$rows = @(Import-Csv -LiteralPath $Path)

    if ($rows.Count -eq 0) {
        return @()
    }

    # Cast salary from string to decimal explicitly (strict mode)
    foreach ($row in $rows) {
        $row.salary = [decimal]$row.salary
    }

    return $rows
}

function Select-ActiveEmployees {
    <#
    .SYNOPSIS
        Filters employee records to only those with status "active".
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Employees
    )

    [PSCustomObject[]]$active = @($Employees | Where-Object { $_.status -eq 'active' })
    return $active
}

function Get-DepartmentStatistics {
    <#
    .SYNOPSIS
        Computes per-department aggregates: headcount, average salary, total salary.
    .DESCRIPTION
        Groups employees by department and calculates aggregate metrics.
        Returns a hashtable keyed by department name. Each value is a
        PSCustomObject with Headcount, AverageSalary, and TotalSalary.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Employees
    )

    [hashtable]$stats = @{}

    # Group employees by department
    $groups = $Employees | Group-Object -Property department

    foreach ($group in $groups) {
        [string]$deptName     = $group.Name
        [int]$headcount       = $group.Count
        [decimal]$totalSalary = [decimal]0

        foreach ($emp in $group.Group) {
            $totalSalary += [decimal]$emp.salary
        }

        [decimal]$avgSalary = $totalSalary / [decimal]$headcount

        $stats[$deptName] = [PSCustomObject]@{
            Headcount     = $headcount
            AverageSalary = $avgSalary
            TotalSalary   = $totalSalary
        }
    }

    return $stats
}

function Get-OverallStatistics {
    <#
    .SYNOPSIS
        Computes overall statistics across all provided employees.
    .DESCRIPTION
        Returns a hashtable with TotalHeadcount, AverageSalary, MinSalary,
        MaxSalary, and TotalSalary for the given set of employees.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Employees
    )

    [int]$count         = $Employees.Count
    [decimal]$total     = [decimal]0
    [decimal]$minSalary = [decimal]::MaxValue
    [decimal]$maxSalary = [decimal]0

    foreach ($emp in $Employees) {
        [decimal]$sal = [decimal]$emp.salary
        $total       += $sal
        if ($sal -lt $minSalary) { $minSalary = $sal }
        if ($sal -gt $maxSalary) { $maxSalary = $sal }
    }

    [decimal]$avg = $total / [decimal]$count

    [hashtable]$result = @{
        TotalHeadcount = $count
        AverageSalary  = $avg
        MinSalary      = $minSalary
        MaxSalary      = $maxSalary
        TotalSalary    = $total
    }

    return $result
}

function Format-SummaryReport {
    <#
    .SYNOPSIS
        Formats department and overall statistics into a human-readable report.
    .DESCRIPTION
        Builds a multi-section text report with a title, per-department
        breakdowns sorted alphabetically, and an overall statistics section.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$DepartmentStats,

        [Parameter(Mandatory)]
        [hashtable]$OverallStats
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Title
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine('       Employee Summary Report')
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine()

    # Department sections (alphabetical order for deterministic output)
    [string[]]$sortedDepts = $DepartmentStats.Keys | Sort-Object

    [void]$sb.AppendLine('--- Department Breakdown ---')
    [void]$sb.AppendLine()

    foreach ($dept in $sortedDepts) {
        $d = $DepartmentStats[$dept]
        [string]$avgFmt   = '{0:N2}' -f [decimal]$d.AverageSalary
        [string]$totalFmt = '{0:N2}' -f [decimal]$d.TotalSalary
        [void]$sb.AppendLine("  Department: $dept")
        [void]$sb.AppendLine("    Headcount      : $($d.Headcount)")
        [void]$sb.AppendLine("    Average Salary  : `$$avgFmt")
        [void]$sb.AppendLine("    Total Salary    : `$$totalFmt")
        [void]$sb.AppendLine()
    }

    # Overall statistics
    [string]$oAvg   = '{0:N2}' -f [decimal]$OverallStats.AverageSalary
    [string]$oMin   = '{0:N2}' -f [decimal]$OverallStats.MinSalary
    [string]$oMax   = '{0:N2}' -f [decimal]$OverallStats.MaxSalary
    [string]$oTotal = '{0:N2}' -f [decimal]$OverallStats.TotalSalary
    [void]$sb.AppendLine('--- Overall Statistics ---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("  Total Headcount  : $($OverallStats.TotalHeadcount)")
    [void]$sb.AppendLine("  Average Salary   : `$$oAvg")
    [void]$sb.AppendLine("  Min Salary       : `$$oMin")
    [void]$sb.AppendLine("  Max Salary       : `$$oMax")
    [void]$sb.AppendLine("  Total Salary     : `$$oTotal")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('========================================')

    return $sb.ToString()
}

function Export-SummaryReport {
    <#
    .SYNOPSIS
        Writes report content to a text file.
    .DESCRIPTION
        Validates that the parent directory exists, then writes the report
        string to the specified output path.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$ReportContent,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    [string]$parentDir = Split-Path -Parent $OutputPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        throw "Output directory '$parentDir' does not exist."
    }

    Set-Content -LiteralPath $OutputPath -Value $ReportContent -Encoding UTF8
}

function New-EmployeeSummaryReport {
    <#
    .SYNOPSIS
        End-to-end orchestration: CSV -> filter -> aggregate -> report file.
    .DESCRIPTION
        Reads employee data from the given CSV, filters to active employees,
        computes department and overall statistics, formats the report, and
        writes it to the specified output file.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    # Step 1: Read CSV
    [PSCustomObject[]]$allEmployees = Import-EmployeeData -Path $CsvPath

    # Step 2: Filter active employees
    [PSCustomObject[]]$active = Select-ActiveEmployees -Employees $allEmployees

    if ($active.Count -eq 0) {
        throw 'No active employees found in the data.'
    }

    # Step 3: Compute statistics
    [hashtable]$deptStats    = Get-DepartmentStatistics -Employees $active
    [hashtable]$overallStats = Get-OverallStatistics -Employees $active

    # Step 4: Format report
    [string]$report = Format-SummaryReport -DepartmentStats $deptStats -OverallStats $overallStats

    # Step 5: Write to file
    Export-SummaryReport -ReportContent $report -OutputPath $OutputPath
}

# Export all public functions
Export-ModuleMember -Function @(
    'Import-EmployeeData'
    'Select-ActiveEmployees'
    'Get-DepartmentStatistics'
    'Get-OverallStatistics'
    'Format-SummaryReport'
    'Export-SummaryReport'
    'New-EmployeeSummaryReport'
)
