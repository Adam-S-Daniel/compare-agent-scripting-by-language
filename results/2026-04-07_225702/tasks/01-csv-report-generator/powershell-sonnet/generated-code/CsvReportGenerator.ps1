# CsvReportGenerator.ps1
# Employee CSV Report Generator
# GREEN phase: minimum code to make all Pester tests pass

# ============================================================
# Feature 1: Import-EmployeeCsv
# Loads employee records from a CSV file and ensures salary is numeric
# ============================================================
function Import-EmployeeCsv {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "CSV file not found: $Path"
    }

    $rows = Import-Csv -Path $Path

    # Convert salary to decimal so callers can do arithmetic without casting
    $employees = $rows | ForEach-Object {
        $_.salary = [decimal]$_.salary
        $_
    }

    return $employees
}

# ============================================================
# Feature 2: Get-ActiveEmployees
# Returns only employees whose status is "active"
# ============================================================
function Get-ActiveEmployees {
    param(
        [object[]]$Employees
    )

    # Wrap in @() to guarantee an array even when zero or one match
    return @($Employees | Where-Object { $_.status -eq "active" })
}

# ============================================================
# Feature 3: Get-DepartmentStats
# Groups active employees by department and computes per-department metrics
# ============================================================
function Get-DepartmentStats {
    param(
        [object[]]$Employees
    )

    $grouped = $Employees | Group-Object -Property department

    $stats = $grouped | ForEach-Object {
        $salaries = $_.Group | ForEach-Object { [decimal]$_.salary }
        $measure  = $salaries | Measure-Object -Average -Sum

        [PSCustomObject]@{
            Department    = $_.Name
            Headcount     = $_.Count
            AverageSalary = [Math]::Round([decimal]$measure.Average, 2)
            TotalPayroll  = [decimal]$measure.Sum
        }
    }

    # Sort alphabetically so output is deterministic
    return @($stats | Sort-Object -Property Department)
}

# ============================================================
# Feature 4: Get-OverallStats
# Computes aggregate statistics across all supplied employees
# ============================================================
function Get-OverallStats {
    param(
        [object[]]$Employees
    )

    $salaries = $Employees | ForEach-Object { [decimal]$_.salary }
    $measure  = $salaries | Measure-Object -Average -Sum -Minimum -Maximum

    return [PSCustomObject]@{
        TotalEmployees = $Employees.Count
        AverageSalary  = [Math]::Round([decimal]$measure.Average, 2)
        MinSalary      = [decimal]$measure.Minimum
        MaxSalary      = [decimal]$measure.Maximum
        TotalPayroll   = [decimal]$measure.Sum
    }
}

# ============================================================
# Feature 5: Write-SummaryReport
# Formats and writes the report to a text file
# ============================================================
function Write-SummaryReport {
    param(
        [object[]]$DepartmentStats,
        [object]$OverallStats,
        [string]$OutputPath
    )

    $sep  = "=" * 60
    $dash = "-" * 40

    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add($sep)
    $lines.Add("EMPLOYEE SUMMARY REPORT")
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add($sep)
    $lines.Add("")

    # --- Overall statistics ---
    $lines.Add("OVERALL STATISTICS")
    $lines.Add($dash)
    $lines.Add("Total Employees:  $($OverallStats.TotalEmployees)")
    $lines.Add("Average Salary:   `$$($OverallStats.AverageSalary)")
    $lines.Add("Min Salary:       `$$($OverallStats.MinSalary)")
    $lines.Add("Max Salary:       `$$($OverallStats.MaxSalary)")
    $lines.Add("Total Payroll:    `$$($OverallStats.TotalPayroll)")
    $lines.Add("")

    # --- Per-department breakdown ---
    $lines.Add("DEPARTMENT BREAKDOWN")
    $lines.Add($dash)

    foreach ($dept in $DepartmentStats) {
        $lines.Add("")
        $lines.Add("Department: $($dept.Department)")
        $lines.Add("  Headcount:      $($dept.Headcount)")
        $lines.Add("  Average Salary: `$$($dept.AverageSalary)")
        $lines.Add("  Total Payroll:  `$$($dept.TotalPayroll)")
    }

    $lines.Add("")
    $lines.Add($sep)

    # Ensure the parent directory exists
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }

    $lines | Set-Content -Path $OutputPath
}
