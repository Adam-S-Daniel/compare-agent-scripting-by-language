# ProcessMonitor.ps1
# Process monitoring script that reads process info, filters by thresholds,
# identifies top N consumers, and generates alert reports.
# All functions accept mock data for testability.

function Get-ProcessInfo {
    <#
    .SYNOPSIS
        Normalizes raw process data into a uniform format with CPU%, MemoryMB, PID, and Name.
    .PARAMETER ProcessData
        Array of process objects (e.g. from Get-Process). When omitted, reads live system data.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$ProcessData
    )

    begin {
        # If no data piped or passed, fetch live processes
        if (-not $ProcessData) {
            $ProcessData = Get-Process
        }
    }

    process {
        foreach ($proc in $ProcessData) {
            [PSCustomObject]@{
                PID        = $proc.Id
                Name       = $proc.ProcessName
                CPUPercent = [math]::Round($proc.CPU, 2)
                MemoryMB   = [math]::Round($proc.WorkingSet64 / 1MB, 0)
            }
        }
    }
}

function Get-FilteredProcesses {
    <#
    .SYNOPSIS
        Filters normalized process list by CPU and/or memory thresholds.
        Returns processes exceeding EITHER threshold (OR logic).
    .PARAMETER Processes
        Array of normalized process objects (output of Get-ProcessInfo).
    .PARAMETER CPUThreshold
        CPU usage percentage threshold. Processes at or above this are included.
    .PARAMETER MemoryThresholdMB
        Memory usage threshold in MB. Processes at or above this are included.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Processes,

        [double]$CPUThreshold = [double]::MaxValue,

        [double]$MemoryThresholdMB = [double]::MaxValue
    )

    $Processes | Where-Object {
        $_.CPUPercent -ge $CPUThreshold -or $_.MemoryMB -ge $MemoryThresholdMB
    }
}

function Get-TopConsumers {
    <#
    .SYNOPSIS
        Returns the top N resource-consuming processes, sorted by CPU or Memory.
    .PARAMETER SortBy
        Sort criterion: "CPU" (default) or "Memory".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Processes,

        [int]$TopN = 5,

        [ValidateSet("CPU", "Memory")]
        [string]$SortBy = "CPU"
    )

    $sortProperty = if ($SortBy -eq "Memory") { "MemoryMB" } else { "CPUPercent" }

    $Processes |
        Sort-Object -Property $sortProperty -Descending |
        Select-Object -First $TopN
}

function New-AlertReport {
    <#
    .SYNOPSIS
        Generates a formatted alert report for processes exceeding thresholds.
    .PARAMETER Processes
        Array of normalized process objects to include in the report.
    .PARAMETER CPUThreshold
        CPU threshold used (shown in report header).
    .PARAMETER MemoryThresholdMB
        Memory threshold used (shown in report header).
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Processes,

        [double]$CPUThreshold = 0,

        [double]$MemoryThresholdMB = 0
    )

    if ($Processes.Count -eq 0) {
        return "No processes exceed the configured thresholds (CPU >= $CPUThreshold%, Memory >= ${MemoryThresholdMB} MB)."
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("=== PROCESS ALERT REPORT ===")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("Thresholds: CPU >= $CPUThreshold% | Memory >= $MemoryThresholdMB MB")
    [void]$sb.AppendLine("Alerts: $($Processes.Count) process(es)")
    [void]$sb.AppendLine("----------------------------")
    [void]$sb.AppendLine(("{0,-8} {1,-20} {2,-12} {3,-12}" -f "PID", "Name", "CPU%", "Memory(MB)"))
    [void]$sb.AppendLine(("{0,-8} {1,-20} {2,-12} {3,-12}" -f "---", "----", "----", "----------"))

    foreach ($proc in $Processes) {
        [void]$sb.AppendLine(("{0,-8} {1,-20} {2,-12} {3,-12}" -f $proc.PID, $proc.Name, $proc.CPUPercent, $proc.MemoryMB))
    }

    [void]$sb.AppendLine("============================")
    $sb.ToString()
}

function Invoke-ProcessMonitor {
    <#
    .SYNOPSIS
        Main orchestration function: reads processes, filters by thresholds,
        picks top N consumers, and generates an alert report.
    .PARAMETER ProcessData
        Raw process objects (e.g. from Get-Process). Pass mock data for testing.
    .PARAMETER CPUThreshold
        CPU percentage threshold for alerting.
    .PARAMETER MemoryThresholdMB
        Memory threshold in MB for alerting.
    .PARAMETER TopN
        Number of top consumers to include in the report.
    .OUTPUTS
        PSCustomObject with .Report (string) and .AlertedProcesses (array).
    #>
    [CmdletBinding()]
    param(
        [object[]]$ProcessData,

        [double]$CPUThreshold = 80,

        [double]$MemoryThresholdMB = 512,

        [int]$TopN = 5
    )

    try {
        # Step 1: Normalize raw process data, treating null CPU as 0
        $normalized = foreach ($p in $ProcessData) {
            [PSCustomObject]@{
                PID        = $p.Id
                Name       = $p.ProcessName
                CPUPercent = if ($null -ne $p.CPU) { [math]::Round($p.CPU, 2) } else { 0 }
                MemoryMB   = [math]::Round($p.WorkingSet64 / 1MB, 0)
            }
        }

        # Step 2: Filter by thresholds
        $filtered = @($normalized | Where-Object {
            $_.CPUPercent -ge $CPUThreshold -or $_.MemoryMB -ge $MemoryThresholdMB
        })

        # Step 3: Get top N consumers from the filtered set
        $topConsumers = @($filtered |
            Sort-Object -Property CPUPercent -Descending |
            Select-Object -First $TopN)

        # Step 4: Generate the report
        $report = New-AlertReport -Processes $topConsumers -CPUThreshold $CPUThreshold -MemoryThresholdMB $MemoryThresholdMB

        [PSCustomObject]@{
            Report           = $report
            AlertedProcesses = $topConsumers
        }
    }
    catch {
        Write-Error "Process monitoring failed: $_"
        [PSCustomObject]@{
            Report           = "ERROR: Process monitoring failed — $_"
            AlertedProcesses = @()
        }
    }
}
