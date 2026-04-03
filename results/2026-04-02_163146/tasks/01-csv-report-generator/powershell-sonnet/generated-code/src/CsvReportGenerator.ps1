# CsvReportGenerator.ps1
# Implementation of CSV employee report generator.
# TDD approach: each function was written to pass the corresponding failing test.

# ---------------------------------------------------------------------------
# Read-EmployeeCsv
# Reads employee records from a CSV file and returns an array of PSCustomObject.
# Throws a meaningful error if the file does not exist.
# ---------------------------------------------------------------------------
function Read-EmployeeCsv {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "CSV file not found: '$Path'. Please provide a valid path."
    }

    # Import-Csv automatically maps header columns to object properties.
    $records = Import-Csv -Path $Path

    # Cast salary to a numeric type so arithmetic works downstream.
    # NOTE: Assignment statements produce no pipeline output, so this is safe.
    $records | ForEach-Object {
        $_.salary = [double]$_.salary
    }

    return $records
}

# ---------------------------------------------------------------------------
# Get-ActiveEmployees
# Filters an array of employee records to those with status == 'active'.
# Case-insensitive comparison to be robust against data inconsistencies.
# ---------------------------------------------------------------------------
function Get-ActiveEmployees {
    param(
        [object[]]$Employees
    )

    return @($Employees | Where-Object { $_.status -ieq "active" })
}

# ---------------------------------------------------------------------------
# Get-DepartmentStats
# Groups active employees by department and computes:
#   - Headcount
#   - AverageSalary (rounded to 2 decimal places)
# Returns an array of PSCustomObject with Department, Headcount, AverageSalary.
# ---------------------------------------------------------------------------
function Get-DepartmentStats {
    param(
        [object[]]$Employees
    )

    $grouped = $Employees | Group-Object -Property department

    $stats = $grouped | ForEach-Object {
        $dept      = $_.Name
        $count     = $_.Count
        $avgSalary = [Math]::Round(($_.Group | Measure-Object -Property salary -Average).Average, 2)

        [PSCustomObject]@{
            Department    = $dept
            Headcount     = $count
            AverageSalary = $avgSalary
        }
    }

    return @($stats)
}

# ---------------------------------------------------------------------------
# Get-OverallStats
# Computes company-wide aggregates across all supplied (active) employees:
#   - TotalHeadcount
#   - AverageSalary (rounded to 2 decimal places)
#   - MinSalary
#   - MaxSalary
# Returns a single PSCustomObject.
# ---------------------------------------------------------------------------
function Get-OverallStats {
    param(
        [object[]]$Employees
    )

    if ($Employees.Count -eq 0) {
        return [PSCustomObject]@{
            TotalHeadcount = 0
            AverageSalary  = 0
            MinSalary      = 0
            MaxSalary      = 0
        }
    }

    $measure = $Employees | Measure-Object -Property salary -Average -Minimum -Maximum

    return [PSCustomObject]@{
        TotalHeadcount = $Employees.Count
        AverageSalary  = [Math]::Round($measure.Average, 2)
        MinSalary      = $measure.Minimum
        MaxSalary      = $measure.Maximum
    }
}

# ---------------------------------------------------------------------------
# Write-SummaryReport
# Formats the department and overall statistics into a human-readable text
# report and writes it to the specified output file.
# ---------------------------------------------------------------------------
function Write-SummaryReport {
    param(
        [object[]]$DepartmentStats,
        [object]  $OverallStats,
        [string]  $OutputPath
    )

    $separator = "=" * 60
    $lines = @()

    $lines += $separator
    $lines += "  EMPLOYEE SALARY SUMMARY REPORT"
    $lines += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += $separator
    $lines += ""

    # --- Overall Statistics ---
    $lines += "OVERALL STATISTICS"
    $lines += "-" * 40
    $lines += "  Total Active Headcount : $($OverallStats.TotalHeadcount)"
    $lines += "  Average Salary         : `$$($OverallStats.AverageSalary.ToString('N2'))"
    $lines += "  Minimum Salary         : `$$($OverallStats.MinSalary.ToString('N2'))"
    $lines += "  Maximum Salary         : `$$($OverallStats.MaxSalary.ToString('N2'))"
    $lines += ""

    # --- Department Breakdown ---
    $lines += "DEPARTMENT BREAKDOWN"
    $lines += "-" * 40

    # Header row
    $lines += "  {0,-20} {1,10} {2,16}" -f "Department", "Headcount", "Avg Salary"
    $lines += "  {0,-20} {1,10} {2,16}" -f ("-" * 20), ("-" * 10), ("-" * 16)

    foreach ($dept in ($DepartmentStats | Sort-Object Department)) {
        $lines += "  {0,-20} {1,10} {2,16}" -f `
            $dept.Department, `
            $dept.Headcount, `
            ("`${0}" -f $dept.AverageSalary.ToString('N2'))
    }

    $lines += ""
    $lines += $separator

    # Write all lines to the output file (creates or overwrites).
    $lines | Set-Content -Path $OutputPath -Encoding UTF8

    Write-Host "Report written to: $OutputPath"
}
