# ArtifactCleanup.ps1
# Artifact retention policy engine with dry-run support.
# Built incrementally via TDD — each function was added to make a failing test pass.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# TDD Round 1: Artifact data creation helper
# Test written first — expects New-ArtifactData to return a PSCustomObject
# with Name, SizeMB, CreationDate, WorkflowRunId properties.
# ============================================================================

function New-ArtifactData {
    <#
    .SYNOPSIS
        Creates a mock artifact metadata object for use in retention policy evaluation.
    .PARAMETER Name
        The artifact name (e.g. "build-log", "coverage-report").
    .PARAMETER SizeMB
        Size in megabytes. Defaults to 0.
    .PARAMETER CreationDate
        When the artifact was created.
    .PARAMETER WorkflowRunId
        The workflow run that produced this artifact.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [double]$SizeMB = 0,

        [Parameter(Mandatory)]
        [datetime]$CreationDate,

        [Parameter(Mandatory)]
        [string]$WorkflowRunId
    )

    [PSCustomObject]@{
        Name          = $Name
        SizeMB        = $SizeMB
        CreationDate  = $CreationDate
        WorkflowRunId = $WorkflowRunId
    }
}

# ============================================================================
# TDD Round 2: Age-based retention policy
# Test written first — expects Get-ArtifactsExceedingMaxAge to return only
# artifacts older than MaxAgeDays relative to a reference date.
# ============================================================================

function Get-ArtifactsExceedingMaxAge {
    <#
    .SYNOPSIS
        Returns artifacts whose age exceeds the given maximum number of days.
    .PARAMETER Artifacts
        Array of artifact objects (from New-ArtifactData).
    .PARAMETER MaxAgeDays
        Maximum allowed age in days. Must be positive.
    .PARAMETER ReferenceDate
        The date to measure age from. Defaults to now.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxAgeDays,

        [datetime]$ReferenceDate = (Get-Date)
    )

    $cutoff = $ReferenceDate.AddDays(-$MaxAgeDays)

    $Artifacts | Where-Object { $_.CreationDate -lt $cutoff }
}

# ============================================================================
# TDD Round 3: Max total size retention policy
# Test written first — expects Get-ArtifactsExceedingMaxSize to mark the
# oldest artifacts for deletion until total size is within budget.
# ============================================================================

function Get-ArtifactsExceedingMaxSize {
    <#
    .SYNOPSIS
        Returns artifacts that should be deleted to bring total size within budget.
        Keeps the newest artifacts first; oldest are deleted first.
    .PARAMETER Artifacts
        Array of artifact objects.
    .PARAMETER MaxTotalSizeMB
        Maximum total size allowed in megabytes. Must be non-negative.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$MaxTotalSizeMB
    )

    # Sort newest first — we keep newest, delete oldest when over budget
    $sorted = $Artifacts | Sort-Object CreationDate -Descending

    $runningTotal = 0.0
    $toKeep = [System.Collections.Generic.List[object]]::new()
    $toDelete = [System.Collections.Generic.List[object]]::new()

    foreach ($a in $sorted) {
        $runningTotal += $a.SizeMB
        if ($runningTotal -le $MaxTotalSizeMB) {
            $toKeep.Add($a)
        }
        else {
            $toDelete.Add($a)
        }
    }

    # Return the ones to delete
    $toDelete.ToArray()
}

# ============================================================================
# TDD Round 4: Keep-latest-N per workflow policy
# Test written first — expects Get-ArtifactsExceedingKeepLatest to return
# only excess artifacts per unique WorkflowRunId grouping.
# ============================================================================

function Get-ArtifactsExceedingKeepLatest {
    <#
    .SYNOPSIS
        For each unique WorkflowRunId, keeps only the N newest artifacts and
        returns the rest for deletion.
    .PARAMETER Artifacts
        Array of artifact objects.
    .PARAMETER KeepLatestN
        Number of newest artifacts to keep per workflow. Must be >= 1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$KeepLatestN
    )

    $toDelete = [System.Collections.Generic.List[object]]::new()

    # Group by WorkflowRunId, then within each group keep the N newest
    $grouped = $Artifacts | Group-Object WorkflowRunId

    foreach ($group in $grouped) {
        $sorted = $group.Group | Sort-Object CreationDate -Descending
        if ($sorted.Count -gt $KeepLatestN) {
            # Skip the first N (newest), mark the rest for deletion
            $excess = $sorted | Select-Object -Skip $KeepLatestN
            foreach ($item in $excess) {
                $toDelete.Add($item)
            }
        }
    }

    $toDelete.ToArray()
}

# ============================================================================
# TDD Round 5: Combined retention policy and deletion plan
# Test written first — expects Invoke-RetentionPolicy to combine all three
# policies (any one can flag an artifact for deletion) and return a plan.
# ============================================================================

function Invoke-RetentionPolicy {
    <#
    .SYNOPSIS
        Applies all configured retention policies and produces a deletion plan.
        An artifact is marked for deletion if ANY policy flags it.
    .PARAMETER Artifacts
        Array of artifact objects.
    .PARAMETER MaxAgeDays
        Optional. Maximum age in days. Artifacts older than this are deleted.
    .PARAMETER MaxTotalSizeMB
        Optional. Maximum total size in MB. Oldest artifacts are deleted first to fit.
    .PARAMETER KeepLatestPerWorkflow
        Optional. Keep only this many newest artifacts per WorkflowRunId.
    .PARAMETER ReferenceDate
        The date to measure age from. Defaults to now.
    .PARAMETER DryRun
        When set, the plan is generated but no deletions are executed.
        (Since we work with mock data, deletions are always simulated,
        but this flag is surfaced in the plan output.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Artifacts,

        [int]$MaxAgeDays = 0,

        [double]$MaxTotalSizeMB = 0,

        [int]$KeepLatestPerWorkflow = 0,

        [datetime]$ReferenceDate = (Get-Date),

        [switch]$DryRun
    )

    # Validate: at least one policy must be specified
    if ($MaxAgeDays -le 0 -and $MaxTotalSizeMB -le 0 -and $KeepLatestPerWorkflow -le 0) {
        throw 'At least one retention policy must be specified (MaxAgeDays, MaxTotalSizeMB, or KeepLatestPerWorkflow).'
    }

    # Collect artifact names flagged by each policy (union)
    $flaggedNames = [System.Collections.Generic.HashSet[string]]::new()

    # --- Age policy ---
    if ($MaxAgeDays -gt 0) {
        $aged = Get-ArtifactsExceedingMaxAge -Artifacts $Artifacts -MaxAgeDays $MaxAgeDays -ReferenceDate $ReferenceDate
        foreach ($a in $aged) {
            [void]$flaggedNames.Add($a.Name)
        }
    }

    # --- Size policy ---
    if ($MaxTotalSizeMB -gt 0) {
        $oversized = Get-ArtifactsExceedingMaxSize -Artifacts $Artifacts -MaxTotalSizeMB $MaxTotalSizeMB
        foreach ($a in $oversized) {
            [void]$flaggedNames.Add($a.Name)
        }
    }

    # --- Keep-latest-N policy ---
    if ($KeepLatestPerWorkflow -gt 0) {
        $excess = Get-ArtifactsExceedingKeepLatest -Artifacts $Artifacts -KeepLatestN $KeepLatestPerWorkflow
        foreach ($a in $excess) {
            [void]$flaggedNames.Add($a.Name)
        }
    }

    # Partition into delete / retain lists
    $toDelete  = $Artifacts | Where-Object { $flaggedNames.Contains($_.Name) }
    $toRetain  = $Artifacts | Where-Object { -not $flaggedNames.Contains($_.Name) }

    # Ensure arrays even when single/empty
    if ($null -eq $toDelete) { $toDelete = @() }
    if ($null -eq $toRetain) { $toRetain = @() }

    # Force to arrays for consistent .Count
    $toDelete = @($toDelete)
    $toRetain = @($toRetain)

    # Build summary
    $spaceReclaimed = ($toDelete | Measure-Object -Property SizeMB -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }

    $spaceRetained = ($toRetain | Measure-Object -Property SizeMB -Sum).Sum
    if ($null -eq $spaceRetained) { $spaceRetained = 0 }

    [PSCustomObject]@{
        DryRun            = [bool]$DryRun
        TotalArtifacts    = $Artifacts.Count
        ArtifactsToDelete = $toDelete
        ArtifactsToRetain = $toRetain
        DeleteCount       = $toDelete.Count
        RetainCount       = $toRetain.Count
        SpaceReclaimedMB  = [math]::Round($spaceReclaimed, 2)
        SpaceRetainedMB   = [math]::Round($spaceRetained, 2)
    }
}

# ============================================================================
# TDD Round 6: Human-readable plan formatting
# Test written first — expects Format-DeletionPlan to produce readable output.
# ============================================================================

function Format-DeletionPlan {
    <#
    .SYNOPSIS
        Formats a deletion plan (from Invoke-RetentionPolicy) as human-readable text.
    .PARAMETER Plan
        The plan object returned by Invoke-RetentionPolicy.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Plan
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    $modeLabel = if ($Plan.DryRun) { 'DRY RUN' } else { 'LIVE' }
    $lines.Add("=== Artifact Cleanup Plan ($modeLabel) ===")
    $lines.Add('')
    $lines.Add("Total artifacts evaluated: $($Plan.TotalArtifacts)")
    $lines.Add("Artifacts to delete:      $($Plan.DeleteCount)")
    $lines.Add("Artifacts to retain:      $($Plan.RetainCount)")
    $lines.Add("Space reclaimed:          $($Plan.SpaceReclaimedMB) MB")
    $lines.Add("Space retained:           $($Plan.SpaceRetainedMB) MB")

    if ($Plan.DeleteCount -gt 0) {
        $lines.Add('')
        $lines.Add('--- Artifacts to DELETE ---')
        foreach ($a in $Plan.ArtifactsToDelete) {
            $lines.Add("  [DELETE] $($a.Name)  ($($a.SizeMB) MB, created $($a.CreationDate.ToString('yyyy-MM-dd')), workflow $($a.WorkflowRunId))")
        }
    }

    if ($Plan.RetainCount -gt 0) {
        $lines.Add('')
        $lines.Add('--- Artifacts to RETAIN ---')
        foreach ($a in $Plan.ArtifactsToRetain) {
            $lines.Add("  [KEEP]   $($a.Name)  ($($a.SizeMB) MB, created $($a.CreationDate.ToString('yyyy-MM-dd')), workflow $($a.WorkflowRunId))")
        }
    }

    if ($Plan.DryRun) {
        $lines.Add('')
        $lines.Add('(Dry-run mode — no artifacts were actually deleted.)')
    }

    $lines -join "`n"
}

# ============================================================================
# TDD Round 7: Error handling for invalid inputs
# Tests written first — expects meaningful error messages for bad inputs.
# ============================================================================

# Error handling is built into parameter validation attributes above
# ([ValidateRange], [Parameter(Mandatory)]) and the explicit throw in
# Invoke-RetentionPolicy when no policy is specified.
