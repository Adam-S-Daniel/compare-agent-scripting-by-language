Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Process Monitor — functions for reading, filtering, and reporting on process resource usage.
# All process data is injectable/mockable: functions accept data as parameters rather than
# querying live system state directly.

function New-ProcessInfo {
    <#
    .SYNOPSIS
        Creates a validated process-info object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][int]$ProcessId,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][double]$CpuPercent,
        [Parameter(Mandatory)][double]$MemoryMB
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Process name cannot be empty"
    }
    if ($CpuPercent -lt 0) {
        throw "CPU percent cannot be negative: $CpuPercent"
    }
    if ($MemoryMB -lt 0) {
        throw "Memory cannot be negative: $MemoryMB"
    }

    [PSCustomObject]@{
        PSTypeName = 'ProcessInfo'
        PID        = [int]$ProcessId
        Name       = [string]$Name
        CpuPercent = [double]$CpuPercent
        MemoryMB   = [double]$MemoryMB
    }
}

function Get-FilteredProcesses {
    <#
    .SYNOPSIS
        Filters processes that exceed CPU and/or memory thresholds (OR logic).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Processes,
        [Parameter()][double]$CpuThreshold = [double]::MaxValue,
        [Parameter()][double]$MemoryThresholdMB = [double]::MaxValue
    )

    [PSCustomObject[]]$filtered = @($Processes | Where-Object {
        [double]$_.CpuPercent -ge $CpuThreshold -or [double]$_.MemoryMB -ge $MemoryThresholdMB
    })
    return $filtered
}

function Get-TopConsumers {
    <#
    .SYNOPSIS
        Returns the top N processes sorted by the chosen metric (CPU or Memory), descending.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Processes,
        [Parameter(Mandatory)][string]$SortBy,
        [Parameter(Mandatory)][int]$Count
    )

    if ($SortBy -ne 'CPU' -and $SortBy -ne 'Memory') {
        throw "SortBy must be 'CPU' or 'Memory', got: '$SortBy'"
    }
    if ($Count -lt 1) {
        throw "Count must be at least 1, got: $Count"
    }

    # Pick the property to sort on
    [string]$sortProp = if ($SortBy -eq 'CPU') { 'CpuPercent' } else { 'MemoryMB' }

    [PSCustomObject[]]$sorted = @(
        $Processes | Sort-Object -Property $sortProp -Descending | Select-Object -First $Count
    )
    return $sorted
}

function New-AlertReport {
    <#
    .SYNOPSIS
        Generates a formatted alert report string for processes exceeding thresholds.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]]$AlertProcesses,
        [Parameter(Mandatory)][double]$CpuThreshold,
        [Parameter(Mandatory)][double]$MemoryThresholdMB,
        [Parameter(Mandatory)][int]$TopN
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine('  PROCESS MONITOR ALERT REPORT')
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine("  Generated:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("  CPU Threshold:    $CpuThreshold%")
    [void]$sb.AppendLine("  Memory Threshold: $($MemoryThresholdMB) MB")
    [void]$sb.AppendLine("  Top N:            $TopN")
    [void]$sb.AppendLine('----------------------------------------')

    if ($AlertProcesses.Count -eq 0) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('  No processes exceed the configured thresholds.')
        [void]$sb.AppendLine('')
    }
    else {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine(("  {0,-8} {1,-20} {2,10} {3,12}" -f 'PID', 'Name', 'CPU%', 'Memory MB'))
        [void]$sb.AppendLine(("  {0,-8} {1,-20} {2,10} {3,12}" -f '---', '----', '----', '---------'))
        foreach ($proc in $AlertProcesses) {
            [void]$sb.AppendLine(("  {0,-8} {1,-20} {2,10:F1} {3,12:F1}" -f `
                [int]$proc.PID, [string]$proc.Name, [double]$proc.CpuPercent, [double]$proc.MemoryMB))
        }
        [void]$sb.AppendLine('')
    }

    [void]$sb.AppendLine('========================================')
    return $sb.ToString()
}

function Invoke-ProcessMonitor {
    <#
    .SYNOPSIS
        End-to-end pipeline: filter processes by thresholds, pick top N, generate alert report.
        Accepts mock process data for testability.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Processes,
        [Parameter(Mandatory)][double]$CpuThreshold,
        [Parameter(Mandatory)][double]$MemoryThresholdMB,
        [Parameter(Mandatory)][int]$TopN
    )

    # Step 1: filter by thresholds
    [PSCustomObject[]]$filtered = @(Get-FilteredProcesses -Processes $Processes `
        -CpuThreshold $CpuThreshold -MemoryThresholdMB $MemoryThresholdMB)

    # Step 2: pick top consumers (by CPU) from the filtered set
    if ($null -ne $filtered -and $filtered.Length -gt 0) {
        [PSCustomObject[]]$top = @(Get-TopConsumers -Processes $filtered -SortBy 'CPU' -Count $TopN)
    } else {
        [PSCustomObject[]]$top = [PSCustomObject[]]@()
    }

    # Step 3: generate and return the report
    [string]$report = New-AlertReport -AlertProcesses ([PSCustomObject[]]$top) `
        -CpuThreshold $CpuThreshold -MemoryThresholdMB $MemoryThresholdMB -TopN $TopN

    return $report
}

function Read-ProcessData {
    <#
    .SYNOPSIS
        Reads process data from a pluggable data source.
        The data source is a scriptblock returning objects with Id, ProcessName, CPU, WorkingSet64.
        This design makes the function fully mockable in tests.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][scriptblock]$DataSource
    )

    [object[]]$rawProcs = @(& $DataSource)

    if ($rawProcs.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    [PSCustomObject[]]$result = @(
        foreach ($p in $rawProcs) {
            [double]$memMB = [math]::Round([double]$p.WorkingSet64 / 1MB, 1)
            New-ProcessInfo -ProcessId ([int]$p.Id) -Name ([string]$p.ProcessName) `
                -CpuPercent ([double]$p.CPU) -MemoryMB $memMB
        }
    )
    return $result
}
