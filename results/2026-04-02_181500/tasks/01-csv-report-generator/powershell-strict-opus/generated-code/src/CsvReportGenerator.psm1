# CsvReportGenerator.psm1
# Module for reading CSV employee data, filtering active employees,
# computing department and overall aggregates, and generating a formatted
# summary report written to a text file.
#
# Approach: Each function is a small, independently testable unit.
# Strict mode and explicit types are used throughout for safety.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Import CSV data ──────────────────────────────────────────────────────────
# Reads a CSV file and returns an array of PSCustomObject rows.
# Validates that required columns (name, department, salary, hire_date, status)
# are present; throws if the file is missing or columns are absent.
function Import-EmployeeCsv {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "CSV file not found: $Path"
    }

    [PSCustomObject[]]$rows = @(Import-Csv -LiteralPath $Path)

    # Validate required columns exist
    if ($rows.Count -gt 0) {
        [string[]]$required = @('name', 'department', 'salary', 'hire_date', 'status')
        [string[]]$columns = @($rows[0].PSObject.Properties.Name)
        foreach ($col in $required) {
            if ($col -notin $columns) {
                throw "Missing required column: $col"
            }
        }
    }

    return $rows
}

# ── Filter to active employees ───────────────────────────────────────────────
# Returns only employees whose status equals 'active' (case-insensitive).
function Select-ActiveEmployees {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Employees
    )

    [PSCustomObject[]]$active = @($Employees | Where-Object {
        [string]$_.status -ieq 'active'
    })
    return $active
}

# ── Compute average salary by department ─────────────────────────────────────
# Groups employees by department and returns a hashtable mapping
# department name → rounded average salary (2 decimal places).
function Get-AverageSalaryByDepartment {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Employees
    )

    [hashtable]$result = @{}
    if ($Employees.Count -eq 0) { return $result }

    [object[]]$groups = @($Employees | Group-Object -Property department)
    foreach ($group in $groups) {
        [double]$avg = ($group.Group | ForEach-Object { [double]$_.salary } |
            Measure-Object -Average).Average
        $result[[string]$group.Name] = [math]::Round($avg, 2)
    }
    return $result
}

# ── Compute headcount by department ──────────────────────────────────────────
# Groups employees by department and returns a hashtable mapping
# department name → integer count.
function Get-HeadcountByDepartment {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Employees
    )

    [hashtable]$result = @{}
    if ($Employees.Count -eq 0) { return $result }

    [object[]]$groups = @($Employees | Group-Object -Property department)
    foreach ($group in $groups) {
        $result[[string]$group.Name] = [int]$group.Count
    }
    return $result
}

# ── Compute overall statistics ───────────────────────────────────────────────
# Returns a hashtable with TotalEmployees, AverageSalary, MinSalary,
# MaxSalary, and TotalPayroll across all provided employees.
# Returns zeroes for an empty input list.
function Get-OverallStatistics {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Employees
    )

    if ($Employees.Count -eq 0) {
        return @{
            TotalEmployees = [int]0
            AverageSalary  = [double]0
            MinSalary      = [double]0
            MaxSalary      = [double]0
            TotalPayroll   = [double]0
        }
    }

    [double[]]$salaries = @($Employees | ForEach-Object { [double]$_.salary })
    [Microsoft.PowerShell.Commands.GenericMeasureInfo]$stats = $salaries |
        Measure-Object -Average -Minimum -Maximum -Sum

    return @{
        TotalEmployees = [int]$stats.Count
        AverageSalary  = [math]::Round([double]$stats.Average, 2)
        MinSalary      = [double]$stats.Minimum
        MaxSalary      = [double]$stats.Maximum
        TotalPayroll   = [double]$stats.Sum
    }
}

# ── Format the summary report ────────────────────────────────────────────────
# Builds a human-readable text report from the computed aggregates.
# Departments are listed in alphabetical order.
function Format-SummaryReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AverageSalary,

        [Parameter(Mandatory)]
        [hashtable]$Headcount,

        [Parameter(Mandatory)]
        [hashtable]$OverallStats
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('=' * 60)
    [void]$sb.AppendLine('          EMPLOYEE SUMMARY REPORT')
    [void]$sb.AppendLine('=' * 60)
    [void]$sb.AppendLine()

    # Overall statistics section
    [void]$sb.AppendLine('OVERALL STATISTICS')
    [void]$sb.AppendLine('-' * 40)
    [void]$sb.AppendLine("  Total Active Employees : $([int]$OverallStats.TotalEmployees)")
    [void]$sb.AppendLine(("  Average Salary         : `${0:N2}" -f [double]$OverallStats.AverageSalary))
    [void]$sb.AppendLine(("  Minimum Salary         : `${0:N2}" -f [double]$OverallStats.MinSalary))
    [void]$sb.AppendLine(("  Maximum Salary         : `${0:N2}" -f [double]$OverallStats.MaxSalary))
    [void]$sb.AppendLine(("  Total Payroll          : `${0:N2}" -f [double]$OverallStats.TotalPayroll))
    [void]$sb.AppendLine()

    # Department breakdown, sorted alphabetically
    [void]$sb.AppendLine('DEPARTMENT BREAKDOWN')
    [void]$sb.AppendLine('-' * 40)

    [string[]]$departments = @($Headcount.Keys | Sort-Object)
    foreach ($dept in $departments) {
        [void]$sb.AppendLine("  $dept")
        [void]$sb.AppendLine("    Headcount      : $([int]$Headcount[$dept])")
        [void]$sb.AppendLine(("    Average Salary : `${0:N2}" -f [double]$AverageSalary[$dept]))
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine('=' * 60)
    [void]$sb.AppendLine('          END OF REPORT')
    [void]$sb.AppendLine('=' * 60)

    return $sb.ToString()
}

# ── Write report to file ─────────────────────────────────────────────────────
# Writes the report string to the specified file path.
# Creates parent directories if they don't exist.
function Export-SummaryReport {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Report,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    [string]$parentDir = Split-Path -Parent $OutputPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        [void](New-Item -ItemType Directory -Path $parentDir -Force)
    }

    Set-Content -LiteralPath $OutputPath -Value $Report -Encoding UTF8
}

# ── Main orchestrator ────────────────────────────────────────────────────────
# Ties all steps together: read → filter → aggregate → format → write.
# Returns the formatted report string for convenience.
function Invoke-CsvReportGenerator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    # Step 1: Import CSV
    [PSCustomObject[]]$allEmployees = @(Import-EmployeeCsv -Path $CsvPath)

    # Step 2: Filter to active only
    [PSCustomObject[]]$active = @(Select-ActiveEmployees -Employees $allEmployees)

    if ($active.Count -eq 0) {
        throw 'No active employees found in the CSV data.'
    }

    # Step 3: Compute aggregates
    [hashtable]$avgSalary = Get-AverageSalaryByDepartment -Employees $active
    [hashtable]$headcount = Get-HeadcountByDepartment -Employees $active
    [hashtable]$overall   = Get-OverallStatistics -Employees $active

    # Step 4: Format report
    [string]$report = Format-SummaryReport -AverageSalary $avgSalary -Headcount $headcount -OverallStats $overall

    # Step 5: Write to file
    Export-SummaryReport -Report $report -OutputPath $OutputPath

    return $report
}

Export-ModuleMember -Function Import-EmployeeCsv,
    Select-ActiveEmployees,
    Get-AverageSalaryByDepartment,
    Get-HeadcountByDepartment,
    Get-OverallStatistics,
    Format-SummaryReport,
    Export-SummaryReport,
    Invoke-CsvReportGenerator
