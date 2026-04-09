# ArtifactCleanup.ps1
# Artifact retention policy engine
#
# Design approach:
#   1. New-ArtifactRecord   – creates typed artifact objects
#   2. Get-Artifacts*       – pure filter functions (one per policy rule)
#   3. Invoke-ArtifactCleanup – orchestrates all rules, builds deletion plan
#   4. Format-CleanupReport – renders human-readable output
#
# All functions are side-effect-free (no actual deletions).
# DryRun flag is preserved in the plan so callers can gate real deletions.

# ---------------------------------------------------------------------------
# New-ArtifactRecord
#   Factory for a typed artifact record.
# ---------------------------------------------------------------------------
function New-ArtifactRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]   $Name,
        [Parameter(Mandatory)] [long]     $SizeBytes,
        [Parameter(Mandatory)] [datetime] $CreatedAt,
        [Parameter(Mandatory)] [string]   $WorkflowRunId
    )

    [PSCustomObject]@{
        Name          = $Name
        SizeBytes     = $SizeBytes
        CreatedAt     = $CreatedAt
        WorkflowRunId = $WorkflowRunId
    }
}

# ---------------------------------------------------------------------------
# Get-ArtifactsExceedingMaxAge
#   Returns artifacts whose age (days since CreatedAt) exceeds MaxAgeDays.
#   ReferenceDate defaults to today; supply it for deterministic tests.
# ---------------------------------------------------------------------------
function Get-ArtifactsExceedingMaxAge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)] [int]              $MaxAgeDays,
        [datetime] $ReferenceDate = (Get-Date)
    )

    $Artifacts | Where-Object {
        ($ReferenceDate - $_.CreatedAt).TotalDays -gt $MaxAgeDays
    }
}

# ---------------------------------------------------------------------------
# Get-ArtifactsExceedingTotalSize
#   Keeps the newest artifacts until the total size budget is consumed, then
#   flags every remaining (older) artifact for deletion.
#
#   Strategy: sort descending by CreatedAt, accumulate size, once the running
#   total would exceed MaxTotalSizeBytes mark the artifact for deletion.
# ---------------------------------------------------------------------------
function Get-ArtifactsExceedingTotalSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)] [long]             $MaxTotalSizeBytes
    )

    # Sort newest first so we always keep the most recent artifacts.
    $sorted = $Artifacts | Sort-Object CreatedAt -Descending

    $accumulated = 0L
    $toDelete    = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($artifact in $sorted) {
        if (($accumulated + $artifact.SizeBytes) -le $MaxTotalSizeBytes) {
            $accumulated += $artifact.SizeBytes
        } else {
            $toDelete.Add($artifact)
        }
    }

    $toDelete.ToArray()
}

# ---------------------------------------------------------------------------
# Get-ArtifactsExceedingKeepLatestN
#   Within each WorkflowRunId group, keeps the N most-recent artifacts and
#   flags all older ones for deletion.
# ---------------------------------------------------------------------------
function Get-ArtifactsExceedingKeepLatestN {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)] [int]              $KeepLatestN
    )

    $toDelete = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Group by workflow run ID
    $groups = $Artifacts | Group-Object WorkflowRunId

    foreach ($group in $groups) {
        # Sort newest first, skip the first N (kept), flag the rest
        $sorted = $group.Group | Sort-Object CreatedAt -Descending
        if ($sorted.Count -gt $KeepLatestN) {
            $sorted | Select-Object -Skip $KeepLatestN | ForEach-Object { $toDelete.Add($_) }
        }
    }

    $toDelete.ToArray()
}

# ---------------------------------------------------------------------------
# Invoke-ArtifactCleanup
#   Orchestrates all retention-policy functions.  Takes the union of all
#   flagged artifacts as the deletion set (an artifact is deleted if ANY
#   policy flags it).
#
#   Returns a plan object:
#     { DryRun, ToDelete[], ToRetain[], Summary }
#
#   In DryRun mode the plan is returned but no side-effects are performed
#   (this function never deletes anything; the caller must act on the plan).
# ---------------------------------------------------------------------------
function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)] [hashtable]        $Policy,
        [bool]     $DryRun        = $true,
        [datetime] $ReferenceDate = (Get-Date)
    )

    # Collect all artifact names flagged by any policy
    $flaggedNames = [System.Collections.Generic.HashSet[string]]::new()

    if ($Policy.ContainsKey('MaxAgeDays')) {
        $aged = Get-ArtifactsExceedingMaxAge -Artifacts $Artifacts -MaxAgeDays $Policy.MaxAgeDays -ReferenceDate $ReferenceDate
        foreach ($a in $aged) { $null = $flaggedNames.Add($a.Name) }
    }

    if ($Policy.ContainsKey('MaxTotalSizeBytes')) {
        $oversized = Get-ArtifactsExceedingTotalSize -Artifacts $Artifacts -MaxTotalSizeBytes $Policy.MaxTotalSizeBytes
        foreach ($a in $oversized) { $null = $flaggedNames.Add($a.Name) }
    }

    if ($Policy.ContainsKey('KeepLatestN')) {
        $excess = Get-ArtifactsExceedingKeepLatestN -Artifacts $Artifacts -KeepLatestN $Policy.KeepLatestN
        foreach ($a in $excess) { $null = $flaggedNames.Add($a.Name) }
    }

    $toDelete = $Artifacts | Where-Object { $flaggedNames.Contains($_.Name) }
    $toRetain = $Artifacts | Where-Object { -not $flaggedNames.Contains($_.Name) }

    # Compute summary
    $spaceReclaimed = ($toDelete | Measure-Object SizeBytes -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0L }

    $summary = [PSCustomObject]@{
        SpaceReclaimedBytes = $spaceReclaimed
        ArtifactsDeleted   = @($toDelete).Count
        ArtifactsRetained  = @($toRetain).Count
    }

    [PSCustomObject]@{
        DryRun   = $DryRun
        ToDelete = @($toDelete)
        ToRetain = @($toRetain)
        Summary  = $summary
    }
}

# ---------------------------------------------------------------------------
# Format-CleanupReport
#   Renders the deletion plan as a human-readable string.
# ---------------------------------------------------------------------------
function Format-CleanupReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject] $Plan
    )

    $sb = [System.Text.StringBuilder]::new()

    # Header
    if ($Plan.DryRun) {
        [void]$sb.AppendLine("=== ARTIFACT CLEANUP REPORT [DRY RUN] ===")
    } else {
        [void]$sb.AppendLine("=== ARTIFACT CLEANUP REPORT ===")
    }
    [void]$sb.AppendLine("")

    # Summary block
    $reclaimedMB = [math]::Round($Plan.Summary.SpaceReclaimedBytes / 1MB, 2)
    [void]$sb.AppendLine("SUMMARY")
    [void]$sb.AppendLine("  Artifacts to delete : $($Plan.Summary.ArtifactsDeleted)")
    [void]$sb.AppendLine("  Artifacts to retain : $($Plan.Summary.ArtifactsRetained)")
    [void]$sb.AppendLine("  Space reclaimed     : $reclaimedMB MB ($($Plan.Summary.SpaceReclaimedBytes) bytes)")
    [void]$sb.AppendLine("")

    # Deletion list
    [void]$sb.AppendLine("ARTIFACTS SCHEDULED FOR DELETION")
    if (@($Plan.ToDelete).Count -eq 0) {
        [void]$sb.AppendLine("  (none)")
    } else {
        foreach ($artifact in $Plan.ToDelete) {
            $ageMB = [math]::Round($artifact.SizeBytes / 1MB, 2)
            [void]$sb.AppendLine("  - $($artifact.Name)  [$($artifact.WorkflowRunId)]  $ageMB MB  created $($artifact.CreatedAt.ToString('yyyy-MM-dd'))")
        }
    }
    [void]$sb.AppendLine("")

    # Retained list
    [void]$sb.AppendLine("ARTIFACTS RETAINED")
    if (@($Plan.ToRetain).Count -eq 0) {
        [void]$sb.AppendLine("  (none)")
    } else {
        foreach ($artifact in $Plan.ToRetain) {
            $ageMB = [math]::Round($artifact.SizeBytes / 1MB, 2)
            [void]$sb.AppendLine("  + $($artifact.Name)  [$($artifact.WorkflowRunId)]  $ageMB MB  created $($artifact.CreatedAt.ToString('yyyy-MM-dd'))")
        }
    }

    $sb.ToString()
}
