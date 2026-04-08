# ProcessMonitor.psm1
# Process Monitor module — reads process info, filters by resource thresholds,
# identifies top N consumers, and generates an alert report.
#
# Design decisions:
#   - All process data is represented as [PSCustomObject] so tests can inject
#     mock records without touching the real OS (Get-Process is never called
#     inside the core functions).
#   - The public entry point Invoke-ProcessMonitor accepts -Processes, making
#     it trivially mockable in tests.
#   - Strict mode is enforced throughout to catch uninitialized variables,
#     implicit type coercions, and other common bugs early.

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# New-ProcessRecord
# Factory function that creates a validated process data object.
# RED→GREEN: tests in Section 1.
# ---------------------------------------------------------------------------
function New-ProcessRecord {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][int]    $Pid,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][double] $CpuPercent,
        [Parameter(Mandatory)][double] $MemoryMB
    )

    # Validate inputs — strict mode won't catch semantic errors, so we do it.
    if ($CpuPercent -lt 0.0) {
        throw "CpuPercent must be >= 0 but got $CpuPercent"
    }
    if ($MemoryMB -lt 0.0) {
        throw "MemoryMB must be >= 0 but got $MemoryMB"
    }

    [PSCustomObject]@{
        Pid        = $Pid
        Name       = $Name
        CpuPercent = $CpuPercent
        MemoryMB   = $MemoryMB
    }
}

# ---------------------------------------------------------------------------
# Test-ProcessThreshold
# Returns $true if the process exceeds at least one configured threshold.
# RED→GREEN: tests in Section 2.
# ---------------------------------------------------------------------------
function Test-ProcessThreshold {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][PSCustomObject] $ProcessRecord,
        [Parameter(Mandatory)][hashtable]      $Thresholds
    )

    # Validate that the caller supplied both required threshold keys.
    if (-not $Thresholds.ContainsKey('CpuPercent')) {
        throw "Thresholds hashtable must contain 'CpuPercent' key"
    }
    if (-not $Thresholds.ContainsKey('MemoryMB')) {
        throw "Thresholds hashtable must contain 'MemoryMB' key"
    }

    $cpuLimit = [double]$Thresholds['CpuPercent']
    $memLimit = [double]$Thresholds['MemoryMB']

    ($ProcessRecord.CpuPercent -gt $cpuLimit) -or ($ProcessRecord.MemoryMB -gt $memLimit)
}

# ---------------------------------------------------------------------------
# Get-FilteredProcesses
# Applies threshold filtering to a list of process records.
# RED→GREEN: tests in Section 3.
# ---------------------------------------------------------------------------
function Get-FilteredProcesses {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Processes,
        [Parameter(Mandatory)][hashtable]        $Thresholds
    )

    # Filter using the single-record predicate; wrap result to ensure array type.
    [PSCustomObject[]]@(
        $Processes | Where-Object { Test-ProcessThreshold -ProcessRecord $_ -Thresholds $Thresholds }
    )
}

# ---------------------------------------------------------------------------
# Get-TopProcesses
# Returns the top N processes sorted by the given field, descending.
# RED→GREEN: tests in Section 4.
# ---------------------------------------------------------------------------
function Get-TopProcesses {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        # AllowEmptyCollection: callers may legitimately pass @() when no processes qualify.
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Processes,
        [Parameter(Mandatory)][int]              $TopN,
        [Parameter(Mandatory)][string]           $SortBy
    )

    # Validate SortBy against the known fields on a process record.
    $validFields = @('CpuPercent', 'MemoryMB', 'Pid', 'Name')
    if ($SortBy -notin $validFields) {
        throw "SortBy must be one of: $($validFields -join ', '). Got: '$SortBy'"
    }

    if ($Processes.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    [PSCustomObject[]]@(
        $Processes | Sort-Object -Property $SortBy -Descending | Select-Object -First $TopN
    )
}

# ---------------------------------------------------------------------------
# New-AlertReport
# Generates a human-readable alert report from a list of alert processes.
# RED→GREEN: tests in Section 5.
# ---------------------------------------------------------------------------
function New-AlertReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # AllowEmptyCollection: report should still render when nothing exceeded thresholds.
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $AlertProcesses,
        [Parameter(Mandatory)][hashtable]        $Thresholds,
        [Parameter(Mandatory)][string]           $GeneratedAt
    )

    $cpuLimit = [double]$Thresholds['CpuPercent']
    $memLimit = [double]$Thresholds['MemoryMB']

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('===================================================')
    [void]$sb.AppendLine('       PROCESS MONITOR ALERT REPORT                ')
    [void]$sb.AppendLine('===================================================')
    [void]$sb.AppendLine("Generated At : $GeneratedAt")
    [void]$sb.AppendLine("Thresholds   : CPU > ${cpuLimit}%  |  Memory > ${memLimit} MB")
    [void]$sb.AppendLine('---------------------------------------------------')

    if ($AlertProcesses.Count -eq 0) {
        [void]$sb.AppendLine('No processes exceeded the configured thresholds.')
    }
    else {
        [void]$sb.AppendLine(('PID').PadRight(8) + ('Name').PadRight(20) + ('CPU%').PadRight(10) + 'Memory(MB)')
        [void]$sb.AppendLine('-' * 50)

        foreach ($proc in $AlertProcesses) {
            $pid  = [string]$proc.Pid
            $name = [string]$proc.Name
            $cpu  = '{0:F1}' -f [double]$proc.CpuPercent
            $mem  = '{0:F1}' -f [double]$proc.MemoryMB

            [void]$sb.AppendLine($pid.PadRight(8) + $name.PadRight(20) + $cpu.PadRight(10) + $mem)
        }
    }

    [void]$sb.AppendLine('===================================================')

    [string]$sb.ToString()
}

# ---------------------------------------------------------------------------
# Invoke-ProcessMonitor
# End-to-end orchestrator.  Accepts a mock-friendly -Processes parameter so
# callers never have to touch the real OS during testing.
# RED→GREEN: tests in Section 6.
# ---------------------------------------------------------------------------
function Invoke-ProcessMonitor {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Injected process list — pass mock data in tests, real data in production.
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Processes,

        # Threshold configuration.
        [Parameter(Mandatory)][hashtable] $Thresholds,

        # How many top CPU consumers to include in the report.
        [Parameter(Mandatory)][int] $TopN
    )

    # 1. Filter to processes that exceed at least one threshold.
    [PSCustomObject[]]$filtered = Get-FilteredProcesses -Processes $Processes -Thresholds $Thresholds

    # 2. Rank by CPU (primary metric for the alert report).
    [PSCustomObject[]]$top = Get-TopProcesses -Processes $filtered -TopN $TopN -SortBy 'CpuPercent'

    # 3. Build and return the report.
    [string]$timestamp = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    New-AlertReport -AlertProcesses $top -Thresholds $Thresholds -GeneratedAt $timestamp
}

# Export all public functions.
Export-ModuleMember -Function New-ProcessRecord, Test-ProcessThreshold,
                               Get-FilteredProcesses, Get-TopProcesses,
                               New-AlertReport, Invoke-ProcessMonitor
