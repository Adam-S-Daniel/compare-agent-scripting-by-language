# EmployeeReport.psm1 — Employee CSV Report Generator
#
# TDD approach:
#   CYCLE 1: Read-EmployeeCsv                 — parse + validate CSV
#   CYCLE 2: Get-ActiveEmployees              — filter by status
#   CYCLE 3: Get-AverageSalaryByDepartment    — aggregate averages
#   CYCLE 4: Get-HeadcountByDepartment        — aggregate counts
#   CYCLE 5: Get-OverallStats                 — overall statistics
#   CYCLE 6: New-EmployeeReport               — compose and write report
#
# STRICT MODE: every function uses CmdletBinding, typed parameters, OutputType.
# NOTE on returning arrays:
#   In PowerShell, returning an empty @() through the pipeline gives the caller
#   $null. Use the comma operator (,@()) to preserve the array wrapper, ensuring
#   callers always receive an [System.Object[]], even when empty.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# CYCLE 1 — Read-EmployeeCsv
# Validates the path, reads the CSV, and strongly types the salary column.
# ---------------------------------------------------------------------------
function Read-EmployeeCsv {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "File not found: '$Path'"
    }

    $raw = Import-Csv -Path $Path

    # Build a typed list; explicitly cast every field to prevent implicit coercion
    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($row in $raw) {
        $result.Add([pscustomobject]@{
            name       = [string]$row.name
            department = [string]$row.department
            salary     = [decimal]$row.salary
            hire_date  = [string]$row.hire_date
            status     = [string]$row.status
        })
    }

    # Use the comma operator so PowerShell does NOT unroll the array;
    # callers receive a proper [System.Object[]] regardless of count.
    return ,[System.Object[]]$result.ToArray()
}

# ---------------------------------------------------------------------------
# CYCLE 2 — Get-ActiveEmployees
# ---------------------------------------------------------------------------
function Get-ActiveEmployees {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Object[]]$Employees
    )

    # @() around Where-Object result guarantees an array even when nothing matches.
    # Comma operator ensures the empty array is not swallowed by the pipeline.
    [System.Object[]]$active = @($Employees | Where-Object { $_.status -eq 'Active' })
    return ,$active
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Get-AverageSalaryByDepartment
# ---------------------------------------------------------------------------
function Get-AverageSalaryByDepartment {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Object[]]$Employees
    )

    [hashtable]$result = @{}

    if ($Employees.Count -eq 0) {
        return $result
    }

    $groups = $Employees | Group-Object -Property department
    foreach ($group in $groups) {
        [decimal]$sum  = [decimal]($group.Group | Measure-Object -Property salary -Sum).Sum
        [int]$count    = [int]$group.Count
        $result[[string]$group.Name] = [decimal]($sum / [decimal]$count)
    }

    return $result
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Get-HeadcountByDepartment
# ---------------------------------------------------------------------------
function Get-HeadcountByDepartment {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Object[]]$Employees
    )

    [hashtable]$result = @{}

    if ($Employees.Count -eq 0) {
        return $result
    }

    $groups = $Employees | Group-Object -Property department
    foreach ($group in $groups) {
        $result[[string]$group.Name] = [int]$group.Count
    }

    return $result
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Get-OverallStats
# ---------------------------------------------------------------------------
function Get-OverallStats {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Object[]]$AllEmployees,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Object[]]$ActiveEmployees
    )

    [int]$totalAll      = [int]$AllEmployees.Count
    [int]$totalActive   = [int]$ActiveEmployees.Count
    [int]$totalInactive = $totalAll - $totalActive

    if ($totalActive -gt 0) {
        $measure         = $ActiveEmployees | Measure-Object -Property salary -Sum -Maximum -Minimum
        [decimal]$avg    = [decimal]$measure.Sum / [decimal]$totalActive
        [decimal]$high   = [decimal]$measure.Maximum
        [decimal]$low    = [decimal]$measure.Minimum
    }
    else {
        [decimal]$avg  = [decimal]0
        [decimal]$high = [decimal]0
        [decimal]$low  = [decimal]0
    }

    return @{
        TotalEmployees       = $totalAll
        TotalActive          = $totalActive
        TotalInactive        = $totalInactive
        OverallAverageSalary = $avg
        HighestSalary        = $high
        LowestSalary         = $low
    }
}

# ---------------------------------------------------------------------------
# CYCLE 6 — New-EmployeeReport
# Composes all prior functions and writes the formatted report to disk.
# ---------------------------------------------------------------------------
function New-EmployeeReport {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][string]$CsvPath,
        [Parameter(Mandatory)][string]$OutputPath
    )

    # Errors from lower-level functions propagate automatically due to
    # $ErrorActionPreference = 'Stop' set at module scope.
    [System.Object[]]$all    = Read-EmployeeCsv -Path $CsvPath
    [System.Object[]]$active = Get-ActiveEmployees -Employees $all
    [hashtable]$avgByDept    = Get-AverageSalaryByDepartment -Employees $active
    [hashtable]$cntByDept    = Get-HeadcountByDepartment     -Employees $active
    [hashtable]$stats        = Get-OverallStats -AllEmployees $all -ActiveEmployees $active

    $divider = '=' * 60
    $subline = '-' * 60

    [System.Collections.Generic.List[string]]$lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add($divider)
    $lines.Add('  EMPLOYEE SUMMARY REPORT')
    $lines.Add("  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add($divider)
    $lines.Add('')

    # Overall Statistics section
    $lines.Add('Overall Statistics')
    $lines.Add($subline)
    $lines.Add("  Total Employees    : $($stats['TotalEmployees'])")
    $lines.Add("  Active             : $($stats['TotalActive'])")
    $lines.Add("  Inactive           : $($stats['TotalInactive'])")
    [double]$avgD = [double]$stats['OverallAverageSalary']
    $lines.Add("  Avg Salary (active): `$$([math]::Round($avgD, 2).ToString('N2'))")
    $lines.Add("  Highest Salary     : `$$([double]$stats['HighestSalary'] | ForEach-Object { ([decimal]$_).ToString('N0') })")
    $lines.Add("  Lowest Salary      : `$$([double]$stats['LowestSalary']  | ForEach-Object { ([decimal]$_).ToString('N0') })")
    $lines.Add('')

    # Department Summary section (sorted alphabetically for determinism)
    $lines.Add('Department Summary')
    $lines.Add($subline)
    $lines.Add(("{0,-20} {1,10} {2,15}" -f 'Department', 'Headcount', 'Avg Salary'))
    $lines.Add(("{0,-20} {1,10} {2,15}" -f ('-' * 20), ('-' * 10), ('-' * 15)))

    [string[]]$depts = [string[]]($cntByDept.Keys | Sort-Object)
    foreach ($dept in $depts) {
        [int]$hc        = [int]$cntByDept[$dept]
        [double]$avgVal = [double]$avgByDept[$dept]
        [string]$avgFmt = "`$$([math]::Round($avgVal, 2).ToString('N2'))"
        $lines.Add(("{0,-20} {1,10} {2,15}" -f $dept, $hc, $avgFmt))
    }

    $lines.Add('')
    $lines.Add($divider)

    [string]$content = $lines -join [System.Environment]::NewLine
    [System.IO.File]::WriteAllText($OutputPath, $content, [System.Text.Encoding]::UTF8)
}

Export-ModuleMember -Function Read-EmployeeCsv, Get-ActiveEmployees,
                               Get-AverageSalaryByDepartment, Get-HeadcountByDepartment,
                               Get-OverallStats, New-EmployeeReport
