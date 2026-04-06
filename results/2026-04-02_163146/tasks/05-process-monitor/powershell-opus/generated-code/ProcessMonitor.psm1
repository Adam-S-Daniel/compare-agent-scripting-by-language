# ProcessMonitor.psm1
# A module for monitoring process resource usage, filtering by configurable
# thresholds, identifying top N resource consumers, and generating alert reports.
#
# Design: All process data acquisition goes through a -DataSource scriptblock
# parameter, making the entire module fully testable with mock data.
#
# Note: The unary comma operator (,) is used throughout to prevent PowerShell
# from unwrapping arrays during function return — this ensures callers always
# receive an array, even when it's empty or contains a single element.

# --- TDD Cycle 1: Get-ProcessData ---
# Retrieves process information. Accepts an optional -DataSource scriptblock
# so tests can inject mock data instead of reading live system state.
function Get-ProcessData {
    [CmdletBinding()]
    param(
        # A scriptblock that returns process objects with PID, Name, CPUPercent, MemoryMB.
        # Defaults to reading live system processes via Get-Process.
        [ScriptBlock]$DataSource = {
            # Default data source: read real system processes.
            # Uses try/catch per process because on Linux, some properties
            # (CPU, StartTime) may be unavailable for privileged processes.
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -ne 0 } |
                ForEach-Object {
                    try {
                        $cpuPercent = 0.0
                        if ($null -ne $_.StartTime -and $null -ne $_.CPU) {
                            $elapsed = ((Get-Date) - $_.StartTime).TotalSeconds
                            if ($elapsed -gt 0) {
                                $cpuPercent = [math]::Round(($_.CPU / $elapsed * 100), 1)
                            }
                        }
                        [PSCustomObject]@{
                            PID        = $_.Id
                            Name       = $_.ProcessName
                            CPUPercent = $cpuPercent
                            MemoryMB   = [math]::Round($_.WorkingSet64 / 1MB, 1)
                        }
                    }
                    catch {
                        # Skip processes we can't inspect (system/privileged)
                    }
                }
        }
    )

    try {
        # @(...) forces pipeline output into an array; the leading comma
        # prevents PowerShell from unwrapping the array on return.
        $result = @(& $DataSource)
        , $result
    }
    catch {
        throw "Failed to retrieve process data: $($_.Exception.Message)"
    }
}

# --- TDD Cycle 2: Filter-ProcessByThreshold ---
# Filters processes that exceed EITHER the CPU or memory threshold (union).
# Defaults to threshold of 0 (returns all processes).
function Filter-ProcessByThreshold {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Processes,

        # CPU usage percentage threshold — processes above this are included
        [double]$CPUThreshold = 0,

        # Memory usage threshold in MB — processes above this are included
        [double]$MemoryThresholdMB = 0
    )

    # Validate thresholds are non-negative
    if ($CPUThreshold -lt 0) {
        throw "CPU threshold cannot be negative (got $CPUThreshold)"
    }
    if ($MemoryThresholdMB -lt 0) {
        throw "Memory threshold cannot be negative (got $MemoryThresholdMB)"
    }

    if ($Processes.Count -eq 0) {
        return , @()
    }

    # Determine which thresholds are actively filtering (> 0).
    # When both are 0, return all processes (no filtering).
    # When one is set, filter by that criterion only.
    # When both are set, include processes exceeding EITHER (union).
    $cpuActive = $CPUThreshold -gt 0
    $memActive = $MemoryThresholdMB -gt 0

    if (-not $cpuActive -and -not $memActive) {
        return , @($Processes)
    }

    $filtered = @($Processes | Where-Object {
        ($cpuActive -and $_.CPUPercent -gt $CPUThreshold) -or
        ($memActive -and $_.MemoryMB -gt $MemoryThresholdMB)
    })
    , $filtered
}

# --- TDD Cycle 3: Get-TopConsumers ---
# Returns the top N processes sorted by CPU (default) or Memory, descending.
function Get-TopConsumers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Processes,

        # Number of top consumers to return (default: 5)
        [int]$TopN = 5,

        # Sort criterion: 'CPU' (default) or 'Memory'
        [string]$SortBy = "CPU"
    )

    # Validate TopN
    if ($TopN -le 0) {
        throw "TopN must be a positive integer (got $TopN)"
    }

    # Validate SortBy
    if ($SortBy -notin @("CPU", "Memory")) {
        throw "SortBy must be 'CPU' or 'Memory' (got '$SortBy')"
    }

    if ($Processes.Count -eq 0) {
        return , @()
    }

    # Pick the sort property based on SortBy parameter
    $sortProperty = if ($SortBy -eq "CPU") { "CPUPercent" } else { "MemoryMB" }

    # Sort descending and take top N
    $top = @($Processes | Sort-Object -Property $sortProperty -Descending | Select-Object -First $TopN)
    , $top
}

# --- TDD Cycle 4: New-AlertReport ---
# Generates a formatted alert report showing processes that exceed thresholds.
# Combines filtering and top-N selection into one convenient output.
function New-AlertReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Processes,

        # CPU threshold percentage for alerting
        [double]$CPUThreshold = 0,

        # Memory threshold in MB for alerting
        [double]$MemoryThresholdMB = 0,

        # Maximum number of processes to include in report (default: 5)
        [int]$TopN = 5,

        # Sort criterion for top consumers: 'CPU' or 'Memory'
        [string]$SortBy = "CPU"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $separator = "=" * 60

    # Build the report header
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($separator)
    $lines.Add("  PROCESS MONITOR ALERT REPORT")
    $lines.Add("  Generated: $timestamp")
    $lines.Add($separator)
    $lines.Add("")
    $lines.Add("  Configuration:")
    $lines.Add("    CPU Threshold:    ${CPUThreshold}%")
    $lines.Add("    Memory Threshold: $MemoryThresholdMB MB")
    $lines.Add("    Top N:            $TopN")
    $lines.Add("    Sort By:          $SortBy")
    $lines.Add("")

    # Filter and select top consumers
    $filtered = Filter-ProcessByThreshold -Processes $Processes -CPUThreshold $CPUThreshold -MemoryThresholdMB $MemoryThresholdMB
    $alertCount = @($filtered).Count

    if ($alertCount -eq 0) {
        $lines.Add("  No processes exceed the configured thresholds.")
        $lines.Add("")
        $lines.Add($separator)
        return ($lines -join "`n")
    }

    $topProcesses = Get-TopConsumers -Processes $filtered -TopN $TopN -SortBy $SortBy

    $lines.Add("  $alertCount process(es) exceed the configured thresholds.")
    $lines.Add("  Showing top $(@($topProcesses).Count):")
    $lines.Add("")

    # Table header
    $lines.Add(("  {0,-8} {1,-20} {2,10} {3,12}" -f "PID", "Name", "CPU %", "Memory MB"))
    $lines.Add(("  {0,-8} {1,-20} {2,10} {3,12}" -f "--------", "--------------------", "----------", "------------"))

    # Table rows — one line per alerting process
    foreach ($proc in $topProcesses) {
        $lines.Add(("  {0,-8} {1,-20} {2,10:F1} {3,12:F1}" -f $proc.PID, $proc.Name, $proc.CPUPercent, $proc.MemoryMB))
    }

    $lines.Add("")
    $lines.Add($separator)

    ($lines -join "`n")
}

# Export all public functions
Export-ModuleMember -Function Get-ProcessData, Filter-ProcessByThreshold, Get-TopConsumers, New-AlertReport
