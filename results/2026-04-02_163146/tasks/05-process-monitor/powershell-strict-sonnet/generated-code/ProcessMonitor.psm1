# ProcessMonitor.psm1
# Process Monitor Module — implemented via red/green TDD with Pester.
#
# Responsibilities:
#   1. Define process data objects  (New-ProcessEntry)
#   2. Define threshold configuration objects  (New-ResourceThreshold)
#   3. Filter processes by configurable CPU/memory thresholds  (Filter-ProcessesByThreshold)
#   4. Identify top-N resource consumers  (Get-TopNConsumers)
#   5. Generate a human-readable alert report  (New-AlertReport)
#   6. Provide a live-system data reader  (Get-LiveProcessData)
#   7. Orchestrate the full pipeline with injectable process provider  (Invoke-ProcessMonitor)
#
# Design for testability: every function that needs system data accepts a
# scriptblock $ProcessProvider so tests can inject mock data instead of reading
# from the live OS.  The module itself never calls Get-Process in the hot path;
# that is confined to Get-LiveProcessData, which is the default provider.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ── Cycle 1 & 2: New-ProcessEntry ─────────────────────────────────────────────
# FIRST TEST: creates a process entry with all required fields.
# SECOND TEST: throws on negative CPU or memory values.

<#
.SYNOPSIS
    Creates a validated process-data entry object.
.DESCRIPTION
    Factory function for the PSCustomObject shape used throughout the module.
    Throws a descriptive error if any numeric field is negative.
.OUTPUTS
    [PSCustomObject] with Name (string), PID (int), CPUPercent (double), MemoryMB (double).
#>
function New-ProcessEntry {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        # Using ProcessId to avoid shadowing the automatic $PID variable.
        [Parameter(Mandatory = $true)]
        [int]$ProcessId,

        [Parameter(Mandatory = $true)]
        [double]$CPUPercent,

        [Parameter(Mandatory = $true)]
        [double]$MemoryMB
    )

    if ($CPUPercent -lt [double]0.0) {
        throw "CPUPercent cannot be negative. Got: $CPUPercent"
    }

    if ($MemoryMB -lt [double]0.0) {
        throw "MemoryMB cannot be negative. Got: $MemoryMB"
    }

    return [PSCustomObject]@{
        Name       = [string]$Name
        PID        = [int]$ProcessId
        CPUPercent = [double]$CPUPercent
        MemoryMB   = [double]$MemoryMB
    }
}

# ── Cycle 3: New-ResourceThreshold ────────────────────────────────────────────
# TEST: creates a threshold configuration with both MinCPUPercent and MinMemoryMB.

<#
.SYNOPSIS
    Creates a resource-threshold configuration object.
.DESCRIPTION
    Encapsulates the minimum CPU% and minimum memory (MB) values used when
    filtering processes.  Both thresholds use greater-than-or-equal comparisons.
.OUTPUTS
    [PSCustomObject] with MinCPUPercent (double) and MinMemoryMB (double).
#>
function New-ResourceThreshold {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [double]$MinCPUPercent,

        [Parameter(Mandatory = $true)]
        [double]$MinMemoryMB
    )

    return [PSCustomObject]@{
        MinCPUPercent = [double]$MinCPUPercent
        MinMemoryMB   = [double]$MinMemoryMB
    }
}

# ── Cycle 4: Filter-ProcessesByThreshold ──────────────────────────────────────
# TESTS: zero thresholds keep everything; CPU-only, memory-only, combined;
#        no-match returns empty array (not $null); empty input is safe.

<#
.SYNOPSIS
    Filters a process list to entries that meet or exceed the given thresholds.
.DESCRIPTION
    A process is included when its CPUPercent >= Threshold.MinCPUPercent
    AND its MemoryMB >= Threshold.MinMemoryMB.
    Always returns an array (never $null) — safe to iterate unconditionally.
.OUTPUTS
    [PSCustomObject[]] — may be an empty array.
#>
function Filter-ProcessesByThreshold {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processes,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Threshold
    )

    # Where-Object returns $null when nothing matches; wrap in @() to normalise.
    $filtered = $Processes | Where-Object {
        $_.CPUPercent -ge $Threshold.MinCPUPercent -and
        $_.MemoryMB   -ge $Threshold.MinMemoryMB
    }

    if ($null -eq $filtered) {
        # Unary comma prevents PowerShell from collapsing an empty array to $null
        # in the pipeline: ,@() is iterated once, yielding the inner @() to the caller.
        return , ([PSCustomObject[]]@())
    }

    return [PSCustomObject[]]@($filtered)
}

# ── Cycle 5: Get-TopNConsumers ─────────────────────────────────────────────────
# TESTS: top-2 by CPU, top-2 by memory, N > list size, N = 1, empty input.

<#
.SYNOPSIS
    Returns the top N processes sorted by the specified resource metric (descending).
.DESCRIPTION
    SortBy must be 'CPU' (sorts by CPUPercent) or 'Memory' (sorts by MemoryMB).
    When TopN exceeds the number of available processes, all are returned.
    Always returns an array — never $null.
.OUTPUTS
    [PSCustomObject[]] — sorted descending, at most TopN entries.
#>
function Get-TopNConsumers {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processes,

        [Parameter(Mandatory = $true)]
        [int]$TopN,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CPU', 'Memory')]
        [string]$SortBy
    )

    if ([int]$Processes.Count -eq 0) {
        return , ([PSCustomObject[]]@())
    }

    # Map the friendly SortBy name to the object property name.
    [string]$sortProperty = switch ($SortBy) {
        'CPU'    { 'CPUPercent' }
        'Memory' { 'MemoryMB' }
    }

    # Cap the count so Select-Object never requests more than available.
    [int]$actualCount = [int][Math]::Min([int]$TopN, [int]$Processes.Count)

    $sorted = $Processes | Sort-Object -Property $sortProperty -Descending

    if ($null -eq $sorted) {
        return , ([PSCustomObject[]]@())
    }

    return [PSCustomObject[]]@($sorted | Select-Object -First $actualCount)
}

# ── Cycle 6: New-AlertReport ───────────────────────────────────────────────────
# TESTS: contains title, threshold values, process names; empty-list message.

<#
.SYNOPSIS
    Generates a formatted plain-text alert report from filtered process data.
.DESCRIPTION
    Produces a human-readable report with:
      - Report title and timestamp
      - Configured threshold values
      - A table of processes that exceeded thresholds (or a "none found" notice)
.OUTPUTS
    [string] — the complete formatted report text.
#>
function New-AlertReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processes,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Thresholds,

        [Parameter(Mandatory = $true)]
        [int]$TopN
    )

    [string]$rule    = [string]('=' * 60)
    [string]$subRule = [string]('-' * 60)
    $sb = [System.Text.StringBuilder]::new()

    # Header
    [void]$sb.AppendLine($rule)
    [void]$sb.AppendLine('Process Monitor Alert Report')
    [void]$sb.AppendLine([string]::Format('Generated : {0}', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$sb.AppendLine($rule)
    [void]$sb.AppendLine('')

    # Threshold summary
    [void]$sb.AppendLine('Configured Thresholds:')
    [void]$sb.AppendLine([string]::Format('  Minimum CPU    : {0:F1}%', $Thresholds.MinCPUPercent))
    [void]$sb.AppendLine([string]::Format('  Minimum Memory : {0:F1} MB', $Thresholds.MinMemoryMB))
    [void]$sb.AppendLine('')

    # Process table or empty notice
    if ([int]$Processes.Count -eq 0) {
        [void]$sb.AppendLine('No processes exceeded the configured thresholds.')
    }
    else {
        [void]$sb.AppendLine([string]::Format('Alert: {0} process(es) exceeded thresholds:', [int]$Processes.Count))
        [void]$sb.AppendLine($subRule)
        [void]$sb.AppendLine([string]::Format('{0,-30} {1,8} {2,10} {3,14}', 'Name', 'PID', 'CPU%', 'Memory (MB)'))
        [void]$sb.AppendLine($subRule)

        foreach ($proc in $Processes) {
            [void]$sb.AppendLine(
                [string]::Format('{0,-30} {1,8} {2,10:F1} {3,14:F1}',
                    [string]$proc.Name,
                    [int]$proc.PID,
                    [double]$proc.CPUPercent,
                    [double]$proc.MemoryMB)
            )
        }
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine($rule)

    return [string]$sb.ToString()
}

# ── Live system data provider (used as default in Invoke-ProcessMonitor) ───────

<#
.SYNOPSIS
    Reads process information from the live operating system.
.DESCRIPTION
    CPU% is not directly available from Get-Process without a sampling interval.
    This implementation returns 0.0 for CPUPercent as a placeholder; callers
    that require accurate CPU% should supply their own -ProcessProvider scriptblock
    (e.g., using WMI/CIM or a two-sample approach).
.OUTPUTS
    [PSCustomObject[]] — one entry per running process.
#>
function Get-LiveProcessData {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $procs = Get-Process | ForEach-Object {
        [PSCustomObject]@{
            Name       = [string]$_.ProcessName
            PID        = [int]$_.Id
            CPUPercent = [double]0.0
            MemoryMB   = [double][Math]::Round([double]$_.WorkingSet64 / [double](1MB), [int]2)
        }
    }

    return [PSCustomObject[]]@($procs)
}

# ── Cycle 7: Invoke-ProcessMonitor ────────────────────────────────────────────
# TESTS: end-to-end with mock provider; thresholds respected; sort order;
#        custom injected data appears in report; thresholds echoed in result.

<#
.SYNOPSIS
    Orchestrates the complete process-monitoring pipeline.
.DESCRIPTION
    Accepts an optional -ProcessProvider scriptblock for dependency injection,
    which makes the entire pipeline testable without touching the live OS.
    When -ProcessProvider is omitted, Get-LiveProcessData is used.

    Returns a result object containing:
      - AllProcesses      : all processes from the provider
      - FilteredProcesses : processes that met the thresholds
      - TopConsumers      : top N processes by the chosen sort metric
      - Thresholds        : the threshold configuration used
      - Report            : the formatted alert report string
.OUTPUTS
    [PSCustomObject]
#>
function Invoke-ProcessMonitor {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # Optional scriptblock that returns [PSCustomObject[]].
        # Inject a mock here in tests; omit to read live process data.
        [Parameter()]
        [scriptblock]$ProcessProvider = $null,

        [Parameter(Mandatory = $true)]
        [double]$MinCPUPercent,

        [Parameter(Mandatory = $true)]
        [double]$MinMemoryMB,

        [Parameter(Mandatory = $true)]
        [int]$TopN,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CPU', 'Memory')]
        [string]$SortBy
    )

    # Retrieve process data via the injected provider or the live-system fallback.
    [PSCustomObject[]]$allProcesses = if ($null -ne $ProcessProvider) {
        [PSCustomObject[]]@(& $ProcessProvider)
    }
    else {
        Get-LiveProcessData
    }

    $thresholds = New-ResourceThreshold -MinCPUPercent $MinCPUPercent -MinMemoryMB $MinMemoryMB

    [PSCustomObject[]]$filteredProcesses = Filter-ProcessesByThreshold `
        -Processes $allProcesses `
        -Threshold $thresholds

    [PSCustomObject[]]$topConsumers = Get-TopNConsumers `
        -Processes $allProcesses `
        -TopN      $TopN `
        -SortBy    $SortBy

    [string]$report = New-AlertReport `
        -Processes  $filteredProcesses `
        -Thresholds $thresholds `
        -TopN       $TopN

    return [PSCustomObject]@{
        AllProcesses      = $allProcesses
        FilteredProcesses = $filteredProcesses
        TopConsumers      = $topConsumers
        Thresholds        = $thresholds
        Report            = $report
    }
}

# ── Exports ────────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'New-ProcessEntry',
    'New-ResourceThreshold',
    'Filter-ProcessesByThreshold',
    'Get-TopNConsumers',
    'New-AlertReport',
    'Get-LiveProcessData',
    'Invoke-ProcessMonitor'
)
