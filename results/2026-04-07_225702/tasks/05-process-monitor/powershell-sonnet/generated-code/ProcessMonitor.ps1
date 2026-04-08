# ProcessMonitor.ps1
# A process monitoring module that supports pluggable data providers (mockable)
# and generates alert reports based on configurable resource thresholds.
#
# Design:
#   Get-ProcessData        – ingests raw process data via a provider scriptblock
#   Invoke-ProcessFilter   – filters by CPU / memory thresholds (OR logic)
#   Get-TopConsumers       – sorts and returns the top N resource consumers
#   New-AlertReport        – formats the results as a human-readable report
#   Invoke-ProcessMonitor  – orchestrates the full pipeline

# ---------------------------------------------------------------------------
# Feature 1 – Ingest process data
# ---------------------------------------------------------------------------
function Get-ProcessData {
    <#
    .SYNOPSIS
        Retrieves process data by calling the supplied provider scriptblock.
    .PARAMETER DataProvider
        A scriptblock that returns a collection of PSCustomObjects, each with:
        PID, Name, CPU (percent), MemoryMB properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$DataProvider
    )

    # Invoke the provider and return whatever it yields (may be empty)
    $data = & $DataProvider
    if ($null -eq $data) { return @() }
    return @($data)
}

# ---------------------------------------------------------------------------
# Feature 2 – Filter by resource thresholds
# ---------------------------------------------------------------------------
function Invoke-ProcessFilter {
    <#
    .SYNOPSIS
        Filters a process list, keeping entries that exceed either threshold.
    .PARAMETER Processes
        Collection returned by Get-ProcessData.
    .PARAMETER CpuThreshold
        Minimum CPU % that triggers inclusion (0 = include all on CPU axis).
    .PARAMETER MemoryMBThreshold
        Minimum MemoryMB that triggers inclusion (0 = include all on memory axis).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Processes,

        [Parameter(Mandatory)]
        [double]$CpuThreshold,

        [Parameter(Mandatory)]
        [double]$MemoryMBThreshold
    )

    # Threshold = 0 means "this axis is disabled" (don't filter on it).
    # A process is included when it breaches at least one *active* threshold.
    return @($Processes | Where-Object {
        ($CpuThreshold      -gt 0 -and $_.CPU      -gt $CpuThreshold)      -or
        ($MemoryMBThreshold -gt 0 -and $_.MemoryMB -gt $MemoryMBThreshold)
    })
}

# ---------------------------------------------------------------------------
# Feature 3 – Identify top N resource consumers
# ---------------------------------------------------------------------------
function Get-TopConsumers {
    <#
    .SYNOPSIS
        Sorts the process list descending by the chosen property and returns
        the first N entries.
    .PARAMETER Processes
        Collection to sort.
    .PARAMETER Top
        Maximum number of processes to return.
    .PARAMETER SortBy
        Property name to sort on; must be one of: CPU, MemoryMB.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Processes,

        [Parameter(Mandatory)]
        [int]$Top,

        [Parameter(Mandatory)]
        [string]$SortBy
    )

    # Validate the sort property before attempting Sort-Object
    $validProperties = @("CPU", "MemoryMB")
    if ($SortBy -notin $validProperties) {
        throw "'$SortBy' is not a valid sort property. Valid options: $($validProperties -join ', ')"
    }

    return @($Processes | Sort-Object -Property $SortBy -Descending | Select-Object -First $Top)
}

# ---------------------------------------------------------------------------
# Feature 4 – Generate the alert report
# ---------------------------------------------------------------------------
function New-AlertReport {
    <#
    .SYNOPSIS
        Formats the supplied process list as a plain-text alert report.
    .PARAMETER Processes
        The (already filtered / ranked) list of processes to report on.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Processes
    )

    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $header    = @(
        "=" * 60
        "  PROCESS ALERT REPORT"
        "  Generated: $timestamp"
        "=" * 60
    ) -join "`n"

    if ($Processes.Count -eq 0) {
        return "$header`nNo processes exceeded the configured thresholds.`n"
    }

    # Column header
    $colHeader = "{0,-8} {1,-24} {2,8} {3,12}" -f "PID", "Name", "CPU %", "Memory (MB)"
    $separator = "-" * 60

    $rows = $Processes | ForEach-Object {
        "{0,-8} {1,-24} {2,8:F1} {3,12:F0}" -f $_.PID, $_.Name, $_.CPU, $_.MemoryMB
    }

    $body = (@($colHeader, $separator) + @($rows)) -join "`n"

    return "$header`n$body`n"
}

# ---------------------------------------------------------------------------
# Feature 5 – Orchestration pipeline
# ---------------------------------------------------------------------------
function Invoke-ProcessMonitor {
    <#
    .SYNOPSIS
        End-to-end pipeline: ingest → filter → rank → report.
    .PARAMETER DataProvider
        Scriptblock that supplies process data (mockable in tests).
    .PARAMETER CpuThreshold
        CPU % threshold for alerting.
    .PARAMETER MemoryMBThreshold
        Memory (MB) threshold for alerting.
    .PARAMETER Top
        How many top consumers to include in the report.
    .PARAMETER SortBy
        Property to rank by (CPU or MemoryMB).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$DataProvider,

        [double]$CpuThreshold      = 80,
        [double]$MemoryMBThreshold = 512,
        [int]   $Top               = 10,
        [string]$SortBy            = "CPU"
    )

    # Wrap each stage in @() so single-element results stay arrays (not scalars)
    [object[]]$all      = @(Get-ProcessData -DataProvider $DataProvider)
    [object[]]$filtered = @(Invoke-ProcessFilter -Processes $all `
                                                 -CpuThreshold $CpuThreshold `
                                                 -MemoryMBThreshold $MemoryMBThreshold)
    [object[]]$top      = @(Get-TopConsumers -Processes $filtered `
                                              -Top $Top `
                                              -SortBy $SortBy)
    return New-AlertReport -Processes $top
}
