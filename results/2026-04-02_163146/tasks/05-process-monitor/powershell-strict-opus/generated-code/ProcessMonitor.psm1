# ProcessMonitor.psm1
# Module for monitoring process resource usage, filtering by configurable
# thresholds, identifying top consumers, and generating alert reports.
#
# Built using strict TDD — every function was written only after its
# corresponding Pester tests existed and failed (RED → GREEN → REFACTOR).
#
# Strict-mode requirements:
#   - Set-StrictMode -Version Latest
#   - $ErrorActionPreference = 'Stop'
#   - Explicit [OutputType()] on all functions
#   - [CmdletBinding()] on all functions
#   - Explicitly typed parameters

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# TDD Cycle 1 GREEN: New-ProcessInfo
# Creates a validated, typed process-information object.
# ============================================================================
function New-ProcessInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [int]$PID,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [double]$CpuPercent,

        [Parameter(Mandatory)]
        [double]$MemoryMB
    )

    # Validate inputs — throw descriptive errors on bad data
    if ($PID -lt 0) {
        throw "PID must be a non-negative integer. Got: $PID"
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'Name must not be empty or whitespace.'
    }
    if ($CpuPercent -lt 0) {
        throw "CpuPercent must be a non-negative number. Got: $CpuPercent"
    }
    if ($MemoryMB -lt 0) {
        throw "MemoryMB must be a non-negative number. Got: $MemoryMB"
    }

    # Build a typed PSCustomObject with a custom type name for identification
    [PSCustomObject]$obj = [PSCustomObject]@{
        PID        = [int]$PID
        Name       = [string]$Name
        CpuPercent = [double]$CpuPercent
        MemoryMB   = [double]$MemoryMB
    }
    $obj.PSObject.TypeNames.Insert(0, 'ProcessMonitor.ProcessInfo')
    return $obj
}

# ============================================================================
# TDD Cycle 2 GREEN: Get-ProcessInfo
# Retrieves process data and converts it into ProcessInfo objects.
# Accepts a -ProcessDataSource scriptblock so tests can inject mock data.
# ============================================================================
function Get-ProcessInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        # Scriptblock that returns raw process-like objects.
        # Default: queries the live system via Get-Process.
        [Parameter()]
        [scriptblock]$ProcessDataSource = {
            Get-Process | Where-Object { $_.Id -ne 0 } |
                Select-Object Id, ProcessName, CPU, WorkingSet64
        }
    )

    try {
        [array]$rawData = @(& $ProcessDataSource)
    }
    catch {
        throw "Failed to retrieve process data: $($_.Exception.Message)"
    }

    if ($rawData.Count -eq 0) {
        return @()
    }

    [PSCustomObject[]]$result = @(
        foreach ($item in $rawData) {
            # Convert WorkingSet64 (bytes) to megabytes
            [double]$memMB = [double]$item.WorkingSet64 / 1MB
            # CPU may be null/zero on some systems; default to 0
            [double]$cpu = if ($null -eq $item.CPU) { 0.0 } else { [double]$item.CPU }

            New-ProcessInfo `
                -PID  ([int]$item.Id) `
                -Name ([string]$item.ProcessName) `
                -CpuPercent $cpu `
                -MemoryMB   ([System.Math]::Round($memMB, 2))
        }
    )
    return $result
}

# ============================================================================
# TDD Cycle 3 GREEN: Select-ByThreshold
# Filters a list of ProcessInfo objects by CPU and/or memory thresholds.
# A process is included if it exceeds EITHER threshold (OR logic).
# When no threshold is specified, the default is MaxValue (nothing matches).
# ============================================================================
function Select-ByThreshold {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processes,

        # CPU usage percentage threshold — include processes at or above this
        [Parameter()]
        [double]$CpuThreshold = [double]::MaxValue,

        # Memory (MB) threshold — include processes at or above this
        [Parameter()]
        [double]$MemoryThreshold = [double]::MaxValue
    )

    if ($Processes.Count -eq 0) {
        return @()
    }

    [PSCustomObject[]]$filtered = @(
        foreach ($proc in $Processes) {
            [bool]$cpuExceeds = $proc.CpuPercent -ge $CpuThreshold
            [bool]$memExceeds = $proc.MemoryMB -ge $MemoryThreshold
            if ($cpuExceeds -or $memExceeds) {
                $proc
            }
        }
    )

    if ($filtered.Count -eq 0) {
        return @()
    }
    return $filtered
}

# ============================================================================
# TDD Cycle 4 GREEN: Get-TopConsumers
# Returns the top N processes sorted by the chosen metric (CPU or Memory).
# ============================================================================
function Get-TopConsumers {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processes,

        [Parameter(Mandatory)]
        [int]$TopN,

        # Sort metric: 'CPU' or 'Memory'
        [Parameter()]
        [string]$SortBy = 'CPU'
    )

    # Validate TopN
    if ($TopN -lt 1) {
        throw "TopN must be at least 1. Got: $TopN"
    }

    # Validate SortBy
    [string[]]$validSorts = @('CPU', 'Memory')
    if ($SortBy -notin $validSorts) {
        throw "SortBy must be one of: $($validSorts -join ', '). Got: $SortBy"
    }

    if ($Processes.Count -eq 0) {
        return @()
    }

    # Pick the sort property based on the metric
    [string]$sortProperty = switch ($SortBy) {
        'CPU'    { 'CpuPercent' }
        'Memory' { 'MemoryMB' }
    }

    # Sort descending and take top N
    [PSCustomObject[]]$sorted = @(
        $Processes | Sort-Object -Property $sortProperty -Descending |
            Select-Object -First $TopN
    )

    return $sorted
}

# ============================================================================
# TDD Cycle 5 GREEN: New-AlertReport
# Generates a structured alert report from a list of processes that exceeded
# thresholds. Includes timestamp, threshold config, and process details.
# ============================================================================
function New-AlertReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processes,

        [Parameter(Mandatory)]
        [double]$CpuThreshold,

        [Parameter(Mandatory)]
        [double]$MemoryThreshold
    )

    # Build alerts array from the flagged processes
    [array]$alerts = @(
        foreach ($proc in $Processes) {
            [PSCustomObject]@{
                PID        = [int]$proc.PID
                Name       = [string]$proc.Name
                CpuPercent = [double]$proc.CpuPercent
                MemoryMB   = [double]$proc.MemoryMB
            }
        }
    )

    [int]$alertCount = $alerts.Count
    # Use $null for empty alerts so Pester's Should -BeNullOrEmpty works
    if ($alertCount -eq 0) {
        $alerts = $null
    }

    [PSCustomObject]$report = [PSCustomObject]@{
        Timestamp  = [string](Get-Date -Format 'o')  # ISO 8601
        Thresholds = [PSCustomObject]@{
            CpuPercent = [double]$CpuThreshold
            MemoryMB   = [double]$MemoryThreshold
        }
        AlertCount = [int]$alertCount
        Alerts     = $alerts
    }
    $report.PSObject.TypeNames.Insert(0, 'ProcessMonitor.AlertReport')
    return $report
}

# ============================================================================
# TDD Cycle 6 GREEN: Format-AlertReport
# Renders an AlertReport as a human-readable string suitable for console
# output or log files.
# ============================================================================
function Format-AlertReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine('  PROCESS MONITOR ALERT REPORT')
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine("Timestamp : $($Report.Timestamp)")
    [void]$sb.AppendLine("Thresholds: CPU >= $($Report.Thresholds.CpuPercent)%, Memory >= $($Report.Thresholds.MemoryMB) MB")
    [void]$sb.AppendLine("Alerts    : $($Report.AlertCount)")
    [void]$sb.AppendLine('----------------------------------------')

    if ($Report.AlertCount -eq 0) {
        [void]$sb.AppendLine('No alerts — all processes within limits.')
    }
    else {
        foreach ($alert in $Report.Alerts) {
            [void]$sb.AppendLine(
                "  ALERT  PID=$($alert.PID)  Name=$($alert.Name)  " +
                "CPU=$($alert.CpuPercent)%  Memory=$($alert.MemoryMB) MB"
            )
        }
    }

    [void]$sb.AppendLine('========================================')

    return $sb.ToString()
}

# Export all public functions
Export-ModuleMember -Function @(
    'New-ProcessInfo'
    'Get-ProcessInfo'
    'Select-ByThreshold'
    'Get-TopConsumers'
    'New-AlertReport'
    'Format-AlertReport'
)
