# EmployeeReport.ps1
# Module for reading employee CSV data, computing aggregates, and generating reports.
# Built using red/green TDD methodology with Pester.
#
# TDD Cycles:
#   1. Get-ActiveEmployees     - Read CSV, filter to status='active'
#   2. Get-DepartmentAggregates - Average salary & headcount per department
#   3. Get-OverallStatistics   - Total, average, min, max salary across all active
#   4. New-EmployeeReport      - Orchestrate and write formatted text report

# =============================================================================
# TDD CYCLE 1 (GREEN): Read CSV and return only active employees
# Minimum code to pass: read CSV, filter where status -eq 'active'
# =============================================================================
function Get-ActiveEmployees {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate that the CSV file exists before attempting to read
    if (-not (Test-Path -Path $Path)) {
        throw "File '$Path' does not exist."
    }

    # Import CSV and filter to active employees only
    $employees = Import-Csv -Path $Path |
        Where-Object { $_.status -eq 'active' }

    # Return as array (may be $null if no active employees)
    return $employees
}

# =============================================================================
# TDD CYCLE 2 (GREEN): Compute per-department aggregates
# Groups employees by department, computes headcount and average salary
# =============================================================================
function Get-DepartmentAggregates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Employees
    )

    # Handle empty input gracefully
    if ($Employees.Count -eq 0) {
        return $null
    }

    # Group by department, then compute headcount and average salary for each
    $aggregates = $Employees |
        Group-Object -Property department |
        ForEach-Object {
            $salaries = $_.Group | ForEach-Object { [decimal]$_.salary }
            [PSCustomObject]@{
                Department    = $_.Name
                Headcount     = $_.Count
                AverageSalary = ($salaries | Measure-Object -Average).Average
            }
        }

    return $aggregates
}

# =============================================================================
# TDD CYCLE 3 (GREEN): Compute overall statistics across all active employees
# Returns total count, average/min/max/total salary
# =============================================================================
function Get-OverallStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Employees
    )

    # Handle empty input - return zeroed stats
    if ($Employees.Count -eq 0) {
        return [PSCustomObject]@{
            TotalEmployees = 0
            AverageSalary  = 0
            MinSalary      = 0
            MaxSalary      = 0
            TotalSalary    = 0
        }
    }

    # Convert salary strings to numbers and compute aggregate measures
    $salaries = $Employees | ForEach-Object { [decimal]$_.salary }
    $measure = $salaries | Measure-Object -Average -Minimum -Maximum -Sum

    return [PSCustomObject]@{
        TotalEmployees = $measure.Count
        AverageSalary  = $measure.Average
        MinSalary      = $measure.Minimum
        MaxSalary      = $measure.Maximum
        TotalSalary    = $measure.Sum
    }
}

# =============================================================================
# TDD CYCLE 4 (GREEN): Orchestrate all steps and write formatted report
# Reads CSV, filters, computes aggregates, writes formatted text file
# =============================================================================
function New-EmployeeReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    # Step 1: Read and filter active employees
    $activeEmployees = Get-ActiveEmployees -Path $CsvPath

    # Ensure we have a proper empty array (not @($null)) when no active employees
    if (-not $activeEmployees) {
        $activeEmployees = @()
    }

    # Step 2: Compute aggregates
    $deptAggregates = Get-DepartmentAggregates -Employees $activeEmployees
    $overallStats   = Get-OverallStatistics   -Employees $activeEmployees

    # Step 3: Build the formatted report - pre-format currency values
    $report = [System.Text.StringBuilder]::new()

    # Format currency strings up-front to avoid parsing issues with -f in method args
    $fmtTotalSal = '${0:N0}' -f $overallStats.TotalSalary
    $fmtAvgSal   = '${0:N2}' -f $overallStats.AverageSalary
    $fmtMinSal   = '${0:N0}' -f $overallStats.MinSalary
    $fmtMaxSal   = '${0:N0}' -f $overallStats.MaxSalary

    [void]$report.AppendLine('========================================')
    [void]$report.AppendLine('       Employee Summary Report')
    [void]$report.AppendLine('========================================')
    [void]$report.AppendLine()

    # Overall statistics section
    [void]$report.AppendLine('--- Overall Statistics ---')
    [void]$report.AppendLine("Total Active Employees : $($overallStats.TotalEmployees)")
    [void]$report.AppendLine("Total Salary           : $fmtTotalSal")
    [void]$report.AppendLine("Average Salary         : $fmtAvgSal")
    [void]$report.AppendLine("Minimum Salary         : $fmtMinSal")
    [void]$report.AppendLine("Maximum Salary         : $fmtMaxSal")
    [void]$report.AppendLine()

    # Department breakdown section
    [void]$report.AppendLine('--- Department Breakdown ---')

    if ($deptAggregates) {
        # Sort departments alphabetically for consistent output
        $sorted = $deptAggregates | Sort-Object -Property Department
        foreach ($dept in $sorted) {
            $fmtDeptAvg = '${0:N0}' -f $dept.AverageSalary
            [void]$report.AppendLine()
            [void]$report.AppendLine("  Department     : $($dept.Department)")
            [void]$report.AppendLine("  Headcount      : $($dept.Headcount)")
            [void]$report.AppendLine("  Average Salary : $fmtDeptAvg")
        }
    }
    else {
        [void]$report.AppendLine('  No active employees found.')
    }

    [void]$report.AppendLine()
    [void]$report.AppendLine('========================================')
    [void]$report.AppendLine('            End of Report')
    [void]$report.AppendLine('========================================')

    # Step 4: Write to output file
    $report.ToString() | Set-Content -Path $OutputPath -Encoding UTF8
}
