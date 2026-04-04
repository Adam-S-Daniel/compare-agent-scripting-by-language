# ProcessMonitor.ps1
# Process Monitor: reads process info, filters by thresholds,
# identifies top N resource consumers, and generates an alert report.
#
# Design principle: all data acquisition is injected/mockable — the
# core functions never call Get-Process directly, making the entire
# pipeline unit-testable without live system state.

# ---------------------------------------------------------------------------
# FUNCTION: Get-MockProcessData
# Purpose:  Provides realistic-looking process data for testing and demos.
#           Returns a fixed array of [PSCustomObject] with PID, Name, CPU,
#           and MemoryMB fields.
# ---------------------------------------------------------------------------
function Get-MockProcessData {
    [CmdletBinding()]
    param()

    return @(
        [PSCustomObject]@{ PID = 1;    Name = 'System';        CPU = [double]0.1;  MemoryMB = [double]8.0    }
        [PSCustomObject]@{ PID = 4;    Name = 'svchost';       CPU = [double]2.5;  MemoryMB = [double]45.0   }
        [PSCustomObject]@{ PID = 812;  Name = 'explorer';      CPU = [double]3.2;  MemoryMB = [double]120.0  }
        [PSCustomObject]@{ PID = 2048; Name = 'chrome';        CPU = [double]55.0; MemoryMB = [double]900.0  }
        [PSCustomObject]@{ PID = 3100; Name = 'node';          CPU = [double]82.3; MemoryMB = [double]512.0  }
        [PSCustomObject]@{ PID = 4200; Name = 'sqlservr';      CPU = [double]15.0; MemoryMB = [double]2048.0 }
        [PSCustomObject]@{ PID = 5000; Name = 'antivirus';     CPU = [double]90.1; MemoryMB = [double]256.0  }
        [PSCustomObject]@{ PID = 6100; Name = 'backup-agent';  CPU = [double]71.0; MemoryMB = [double]3200.0 }
        [PSCustomObject]@{ PID = 7200; Name = 'indexer';       CPU = [double]44.0; MemoryMB = [double]180.0  }
        [PSCustomObject]@{ PID = 8300; Name = 'idle-svc';      CPU = [double]0.0;  MemoryMB = [double]5.0    }
    )
}

# ---------------------------------------------------------------------------
# FUNCTION: Get-FilteredProcesses
# Purpose:  Filters a list of process objects, keeping only those that
#           exceed the CPU threshold OR the memory threshold (OR logic).
#           Passing 0.0 for a threshold effectively disables that filter.
#
# Parameters:
#   -Processes         Array of process objects (PID, Name, CPU, MemoryMB)
#   -CpuThreshold      Minimum CPU% to flag a process (double, 0-100)
#   -MemoryThresholdMB Minimum memory in MB to flag a process (double)
# ---------------------------------------------------------------------------
function Get-FilteredProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Processes,

        [Parameter(Mandatory)]
        [double]$CpuThreshold,

        [Parameter(Mandatory)]
        [double]$MemoryThresholdMB
    )

    # Filter: keep processes that exceed either threshold (OR logic).
    # A threshold of 0.0 means "disabled" for that dimension — only non-zero
    # thresholds are evaluated, preventing false matches when callers pass 0.
    $filtered = $Processes | Where-Object {
        $exceedsCpu = ($CpuThreshold    -gt 0.0) -and ($_.CPU       -gt $CpuThreshold)
        $exceedsMem = ($MemoryThresholdMB -gt 0.0) -and ($_.MemoryMB -gt $MemoryThresholdMB)
        $exceedsCpu -or $exceedsMem
    }

    # Ensure we always return an array (not $null when nothing matches)
    if ($null -eq $filtered) {
        return @()
    }

    # Force array return (single-element Where-Object may return a scalar)
    return @($filtered)
}

# ---------------------------------------------------------------------------
# FUNCTION: Get-TopResourceConsumers
# Purpose:  Sorts a list of process objects by the specified field and
#           returns the top N entries (descending order).
#
# Parameters:
#   -Processes  Array of process objects
#   -TopN       How many entries to return
#   -SortBy     Field name to sort by — must be 'CPU' or 'MemoryMB'
# ---------------------------------------------------------------------------
function Get-TopResourceConsumers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Processes,

        [Parameter(Mandatory)]
        [int]$TopN,

        [Parameter(Mandatory)]
        [string]$SortBy
    )

    # Validate SortBy — only allow known numeric fields to prevent unexpected
    # sort behaviour on string fields like Name.
    $allowedFields = @('CPU', 'MemoryMB')
    if ($SortBy -notin $allowedFields) {
        throw "Invalid SortBy value '$SortBy'. Allowed values: $($allowedFields -join ', ')"
    }

    # Sort descending, then take the top N entries
    $sorted = $Processes | Sort-Object -Property $SortBy -Descending

    # Select-Object -First handles the case where TopN > count gracefully
    return @($sorted | Select-Object -First $TopN)
}

# ---------------------------------------------------------------------------
# FUNCTION: New-AlertReport
# Purpose:  Generates a human-readable alert report string from a list of
#           flagged processes and the thresholds that triggered the alerts.
#
# Parameters:
#   -Processes   Array of process objects that exceeded thresholds
#   -Thresholds  Hashtable with keys CpuThreshold and MemoryThresholdMB
# ---------------------------------------------------------------------------
function New-AlertReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Processes,

        [Parameter(Mandatory)]
        [hashtable]$Thresholds
    )

    # Normalise: treat $null the same as an empty collection
    if ($null -eq $Processes) { $Processes = @() }

    $lines = [System.Collections.Generic.List[string]]::new()

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $lines.Add("========================================")
    $lines.Add("  PROCESS MONITOR ALERT REPORT")
    $lines.Add("  Generated: $timestamp")
    $lines.Add("========================================")
    $lines.Add("Thresholds: CPU > $($Thresholds.CpuThreshold)%  |  Memory > $($Thresholds.MemoryThresholdMB) MB")
    $lines.Add("")

    if ($Processes.Count -eq 0) {
        $lines.Add("No alerts: all processes are within configured thresholds.")
        return $lines -join "`n"
    }

    $lines.Add("ALERT: $($Processes.Count) process(es) exceeded resource thresholds:")
    $lines.Add("")

    # Column header
    $lines.Add(("{0,-8} {1,-20} {2,8} {3,12}" -f 'PID', 'Name', 'CPU%', 'Memory(MB)'))
    $lines.Add(("-" * 52))

    foreach ($proc in $Processes) {
        $lines.Add(("{0,-8} {1,-20} {2,8:F1} {3,12:F1}" -f $proc.PID, $proc.Name, $proc.CPU, $proc.MemoryMB))
    }

    $lines.Add("")
    $lines.Add("========================================")

    return $lines -join "`n"
}

# ---------------------------------------------------------------------------
# FUNCTION: Invoke-ProcessMonitor
# Purpose:  Main entry-point — orchestrates the full pipeline:
#             1. Acquire process data (mock or real)
#             2. Filter by thresholds
#             3. Identify top N consumers
#             4. Generate and return the alert report
#
# Parameters:
#   -ProcessData        (optional) Inject mock process data; if omitted,
#                       Get-MockProcessData is used as the default source.
#   -CpuThreshold       CPU% threshold (default 80.0)
#   -MemoryThresholdMB  Memory threshold in MB (default 1024.0)
#   -TopN               Number of top consumers to highlight (default 10)
#   -SortBy             Sort field for top consumers: 'CPU' or 'MemoryMB'
# ---------------------------------------------------------------------------
function Invoke-ProcessMonitor {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$ProcessData = $null,

        [Parameter()]
        [double]$CpuThreshold = 80.0,

        [Parameter()]
        [double]$MemoryThresholdMB = 1024.0,

        [Parameter()]
        [int]$TopN = 10,

        [Parameter()]
        [string]$SortBy = 'CPU'
    )

    # Step 1: Acquire data — use injected mock data or the built-in mock source.
    # In production use, replace Get-MockProcessData with a real data provider.
    if ($null -eq $ProcessData) {
        $ProcessData = Get-MockProcessData
    }

    if ($ProcessData.Count -eq 0) {
        Write-Warning "No process data available to analyse."
        return New-AlertReport -Processes @() -Thresholds @{
            CpuThreshold      = $CpuThreshold
            MemoryThresholdMB = $MemoryThresholdMB
        }
    }

    # Step 2: Filter processes that breach at least one threshold
    $filtered = Get-FilteredProcesses -Processes $ProcessData `
                                      -CpuThreshold $CpuThreshold `
                                      -MemoryThresholdMB $MemoryThresholdMB

    # Step 3: Rank filtered processes by the chosen metric.
    # Wrap in @() to guarantee an array even when $filtered is empty —
    # PowerShell if/else can return $null through the pipeline for empty branches.
    $topConsumers = @(
        if ($filtered.Count -gt 0) {
            Get-TopResourceConsumers -Processes $filtered -TopN $TopN -SortBy $SortBy
        }
    )

    # Step 4: Produce the alert report
    $thresholds = @{
        CpuThreshold      = $CpuThreshold
        MemoryThresholdMB = $MemoryThresholdMB
    }

    return New-AlertReport -Processes $topConsumers -Thresholds $thresholds
}
