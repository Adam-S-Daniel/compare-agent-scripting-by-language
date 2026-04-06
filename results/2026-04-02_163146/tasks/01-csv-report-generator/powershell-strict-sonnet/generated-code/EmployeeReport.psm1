# EmployeeReport.psm1
# CSV Employee Report Generator — PowerShell module with strict mode
#
# TDD approach:
#   RED   — Tests were written first in EmployeeReport.Tests.ps1 (they fail
#            because this module does not exist yet).
#   GREEN — Minimum implementation added here to make each test group pass.
#   REFACTOR — Types, error messages, and output format polished after green.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helper: internal record type (PSCustomObject factory)
# ---------------------------------------------------------------------------

# TDD Cycle 1 — Import-EmployeeData
# Tests expect: array of objects with Name, Department, Salary (decimal),
# HireDate (datetime), Status.  Throws meaningful error for bad path.

function Import-EmployeeData {
    <#
    .SYNOPSIS
        Reads a CSV file of employee records and returns strongly-typed objects.
    .PARAMETER Path
        Full path to the CSV file.
    .OUTPUTS
        PSCustomObject[]  — one object per row with typed fields.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Employee CSV file not found: $Path"
    }

    $rows = Import-Csv -LiteralPath $Path

    # @() ensures we always return an array even for a single-row CSV
    [PSCustomObject[]] $records = @(foreach ($row in $rows) {
        # Explicit casts — no implicit conversion allowed in strict mode
        [PSCustomObject] @{
            Name       = [string]   $row.name
            Department = [string]   $row.department
            Salary     = [decimal]  $row.salary
            HireDate   = [datetime] $row.hire_date
            Status     = [string]   $row.status
        }
    })

    return $records
}

# ---------------------------------------------------------------------------
# TDD Cycle 2 — Get-ActiveEmployees
# Tests expect: only records where Status -eq 'Active'; returns empty array
# (not $null) when none match.
# ---------------------------------------------------------------------------

function Get-ActiveEmployees {
    <#
    .SYNOPSIS
        Filters an employee array to Active status only.
    .PARAMETER Employees
        Array of employee PSCustomObjects (as returned by Import-EmployeeData).
    .OUTPUTS
        PSCustomObject[]  — subset of active employees; empty array if none.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]] $Employees
    )

    [PSCustomObject[]] $active = @($Employees | Where-Object { $_.Status -eq 'Active' })
    return $active
}

# ---------------------------------------------------------------------------
# TDD Cycle 3 — Get-DepartmentAggregates
# Tests expect: one result per department with Department, Headcount,
# AverageSalary, TotalSalary fields.  Average must be mathematically correct.
# ---------------------------------------------------------------------------

function Get-DepartmentAggregates {
    <#
    .SYNOPSIS
        Computes per-department headcount, total salary, and average salary.
    .PARAMETER Employees
        Array of employee PSCustomObjects (active employees only recommended).
    .OUTPUTS
        PSCustomObject[]  — one aggregate object per department, sorted by
        Department name.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]] $Employees
    )

    # Group by department, compute aggregates for each group.
    # Wrap in @() to guarantee an array even with a single department.
    [PSCustomObject[]] $results = @(
        $Employees |
            Group-Object -Property Department |
            ForEach-Object {
                [int]     $headcount     = [int] $_.Count
                [decimal] $totalSalary   = [decimal] ($_.Group | Measure-Object -Property Salary -Sum).Sum
                [decimal] $averageSalary = [Math]::Round($totalSalary / [decimal] $headcount, 2)

                [PSCustomObject] @{
                    Department    = [string]  $_.Name
                    Headcount     = $headcount
                    TotalSalary   = $totalSalary
                    AverageSalary = $averageSalary
                }
            } |
            Sort-Object -Property Department
    )

    return $results
}

# ---------------------------------------------------------------------------
# TDD Cycle 4 — Get-OverallStatistics
# Tests expect: TotalHeadcount, AverageSalary, HighestSalary, LowestSalary,
# DepartmentCount — all computed from the supplied employee array.
# ---------------------------------------------------------------------------

function Get-OverallStatistics {
    <#
    .SYNOPSIS
        Computes organisation-wide statistics from an employee array.
    .PARAMETER Employees
        Array of employee PSCustomObjects (active employees only recommended).
    .OUTPUTS
        PSCustomObject  — single statistics object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]] $Employees
    )

    if ($Employees.Count -eq 0) {
        throw 'Cannot compute statistics: no employees provided.'
    }

    $salaryStats = $Employees | Measure-Object -Property Salary -Sum -Maximum -Minimum -Average

    [int]     $totalHeadcount  = [int]     $Employees.Count
    [decimal] $averageSalary   = [Math]::Round([decimal] $salaryStats.Average, 2)
    [decimal] $highestSalary   = [decimal] $salaryStats.Maximum
    [decimal] $lowestSalary    = [decimal] $salaryStats.Minimum
    # @() ensures array even when only one department exists (scalar-unwrap protection)
    [int]     $departmentCount = [int] @($Employees | Select-Object -ExpandProperty Department -Unique).Count

    return [PSCustomObject] @{
        TotalHeadcount  = $totalHeadcount
        AverageSalary   = $averageSalary
        HighestSalary   = $highestSalary
        LowestSalary    = $lowestSalary
        DepartmentCount = $departmentCount
    }
}

# ---------------------------------------------------------------------------
# TDD Cycle 5 — Write-SummaryReport
# Tests expect: file created at OutputPath (parent dir created if needed),
# content includes "Employee Summary Report", "Department Breakdown",
# each department name, "Overall Statistics", "Total Active Employees".
# ---------------------------------------------------------------------------

function Write-SummaryReport {
    <#
    .SYNOPSIS
        Writes a formatted summary report to a text file.
    .PARAMETER DepartmentAggregates
        Array of department aggregate objects (from Get-DepartmentAggregates).
    .PARAMETER OverallStatistics
        Overall statistics object (from Get-OverallStatistics).
    .PARAMETER OutputPath
        Full path for the output text file.  Parent directory created if needed.
    .OUTPUTS
        None  — writes directly to OutputPath.
    #>
    [CmdletBinding()]
    [OutputType([System.Void])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]] $DepartmentAggregates,

        [Parameter(Mandatory)]
        [PSCustomObject]   $OverallStatistics,

        [Parameter(Mandatory)]
        [string]           $OutputPath
    )

    # Ensure the parent directory exists
    [string] $parentDir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
        $null = New-Item -ItemType Directory -Path $parentDir -Force
    }

    # Build report lines
    [string] $separator = '=' * 60
    [string] $thinSep   = '-' * 60
    [string] $generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    [System.Collections.Generic.List[string]] $lines = [System.Collections.Generic.List[string]]::new()

    # ---- Header ----
    $lines.Add($separator)
    $lines.Add('         Employee Summary Report')
    $lines.Add("         Generated: $generated")
    $lines.Add($separator)
    $lines.Add('')

    # ---- Overall Statistics ----
    $lines.Add('Overall Statistics')
    $lines.Add($thinSep)
    $lines.Add("  Total Active Employees : $($OverallStatistics.TotalHeadcount)")
    $lines.Add("  Number of Departments  : $($OverallStatistics.DepartmentCount)")
    $lines.Add("  Average Salary         : {0:C2}" -f $OverallStatistics.AverageSalary)
    $lines.Add("  Highest Salary         : {0:C2}" -f $OverallStatistics.HighestSalary)
    $lines.Add("  Lowest Salary          : {0:C2}" -f $OverallStatistics.LowestSalary)
    $lines.Add('')

    # ---- Department Breakdown ----
    $lines.Add('Department Breakdown')
    $lines.Add($thinSep)
    $lines.Add("  {0,-20} {1,10} {2,15} {3,15}" -f 'Department', 'Headcount', 'Avg Salary', 'Total Salary')
    $lines.Add("  {0,-20} {1,10} {2,15} {3,15}" -f '----------', '---------', '----------', '------------')

    foreach ($dept in $DepartmentAggregates) {
        $lines.Add(
            "  {0,-20} {1,10} {2,15:C2} {3,15:C2}" -f
            [string] $dept.Department,
            [int]    $dept.Headcount,
            [decimal]$dept.AverageSalary,
            [decimal]$dept.TotalSalary
        )
    }

    $lines.Add('')
    $lines.Add($separator)
    $lines.Add('End of Report')
    $lines.Add($separator)

    # Write to file (UTF-8 without BOM for portability)
    [System.IO.File]::WriteAllLines(
        $OutputPath,
        [string[]] $lines.ToArray(),
        [System.Text.UTF8Encoding]::new($false)
    )
}

# Export only the public API functions
Export-ModuleMember -Function Import-EmployeeData, Get-ActiveEmployees,
                               Get-DepartmentAggregates, Get-OverallStatistics,
                               Write-SummaryReport
