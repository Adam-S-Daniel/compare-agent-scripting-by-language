# ArtifactCleanup.ps1
# Applies retention policies to a list of artifacts and generates a deletion plan.
#
# Retention policies supported:
#   - MaxAgeDays       : delete artifacts older than N days
#   - MaxTotalSizeBytes: delete oldest artifacts until total size is under the limit
#   - KeepLatestN      : per workflow run ID, keep only the N most-recent artifacts
#
# All functions are pure (no side effects) so they are easily testable.
# Actual deletion is simulated — Invoke-ArtifactCleanup returns the plan;
# callers decide whether to act on it. DryRun=$true makes that explicit in output.

# ---------------------------------------------------------------------------
# New-RetentionPolicy
# Creates a hashtable describing the retention rules to apply.
# ---------------------------------------------------------------------------
function New-RetentionPolicy {
    param(
        [int]$MaxAgeDays        = 30,
        [long]$MaxTotalSizeBytes = 1GB,
        [int]$KeepLatestN       = 3
    )

    if ($MaxAgeDays -lt 0) {
        throw "MaxAgeDays must be >= 0. Got: $MaxAgeDays"
    }
    if ($KeepLatestN -le 0) {
        throw "KeepLatestN must be >= 1. Got: $KeepLatestN"
    }
    if ($MaxTotalSizeBytes -le 0) {
        throw "MaxTotalSizeBytes must be > 0. Got: $MaxTotalSizeBytes"
    }

    return [PSCustomObject]@{
        MaxAgeDays        = $MaxAgeDays
        MaxTotalSizeBytes = $MaxTotalSizeBytes
        KeepLatestN       = $KeepLatestN
    }
}

# ---------------------------------------------------------------------------
# Get-ArtifactsByAge
# Returns artifacts whose age (days since CreatedAt) exceeds policy.MaxAgeDays.
# ---------------------------------------------------------------------------
function Get-ArtifactsByAge {
    param(
        [object[]]$Artifacts,
        [object]$Policy
    )

    $now = [DateTime]::UtcNow
    return @($Artifacts | Where-Object {
        ($now - $_.CreatedAt).TotalDays -gt $Policy.MaxAgeDays
    })
}

# ---------------------------------------------------------------------------
# Get-ArtifactsByKeepLatestN
# Groups artifacts by WorkflowRunId, sorts each group newest-first, and
# returns any artifacts beyond position KeepLatestN (i.e. the older surplus).
# ---------------------------------------------------------------------------
function Get-ArtifactsByKeepLatestN {
    param(
        [object[]]$Artifacts,
        [object]$Policy
    )

    $toDelete = [System.Collections.Generic.List[object]]::new()

    # Group by workflow
    $groups = $Artifacts | Group-Object -Property WorkflowRunId

    foreach ($group in $groups) {
        # Sort newest first
        $sorted = @($group.Group | Sort-Object -Property CreatedAt -Descending)
        if ($sorted.Count -gt $Policy.KeepLatestN) {
            # Everything after index KeepLatestN-1 is surplus
            $surplus = $sorted[$Policy.KeepLatestN..($sorted.Count - 1)]
            foreach ($a in $surplus) {
                $toDelete.Add($a)
            }
        }
    }

    return @($toDelete)
}

# ---------------------------------------------------------------------------
# Get-ArtifactsByTotalSize
# Sorts artifacts oldest-first, removes them one by one until total size
# falls within MaxTotalSizeBytes, and returns those earmarked for deletion.
# ---------------------------------------------------------------------------
function Get-ArtifactsByTotalSize {
    param(
        [object[]]$Artifacts,
        [object]$Policy
    )

    $totalBytes = ($Artifacts | Measure-Object -Property SizeBytes -Sum).Sum
    if ($totalBytes -le $Policy.MaxTotalSizeBytes) {
        return @()
    }

    # Delete oldest first until we are within the size limit
    $sorted = @($Artifacts | Sort-Object -Property CreatedAt)
    $toDelete = [System.Collections.Generic.List[object]]::new()

    foreach ($artifact in $sorted) {
        if ($totalBytes -le $Policy.MaxTotalSizeBytes) { break }
        $toDelete.Add($artifact)
        $totalBytes -= $artifact.SizeBytes
    }

    return @($toDelete)
}

# ---------------------------------------------------------------------------
# New-DeletionPlan
# Combines all policy violations, deduplicates, and builds a plan object with
# a ToDelete list, a ToRetain list, and a Summary.
# ---------------------------------------------------------------------------
function New-DeletionPlan {
    param(
        [object[]]$Artifacts,
        [object]$Policy
    )

    # Collect candidates from each policy rule
    $byAge     = Get-ArtifactsByAge        -Artifacts $Artifacts -Policy $Policy
    $byLatestN = Get-ArtifactsByKeepLatestN -Artifacts $Artifacts -Policy $Policy
    $bySize    = Get-ArtifactsByTotalSize   -Artifacts $Artifacts -Policy $Policy

    # Union by Name (deduplicate across policy rules)
    $deleteNames = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($a in ($byAge + $byLatestN + $bySize)) {
        [void]$deleteNames.Add($a.Name)
    }

    $toDelete = @($Artifacts | Where-Object { $deleteNames.Contains($_.Name) })
    $toRetain = @($Artifacts | Where-Object { -not $deleteNames.Contains($_.Name) })

    $reclaimedBytes = ($toDelete | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $reclaimedBytes) { $reclaimedBytes = 0 }

    $summary = [PSCustomObject]@{
        ArtifactsToDelete          = $toDelete.Count
        ArtifactsToRetain          = $toRetain.Count
        TotalSpaceReclaimedBytes   = $reclaimedBytes
        TotalSpaceReclaimedMB      = [Math]::Round($reclaimedBytes / 1MB, 2)
    }

    return [PSCustomObject]@{
        ToDelete = $toDelete
        ToRetain = $toRetain
        Summary  = $summary
    }
}

# ---------------------------------------------------------------------------
# Invoke-ArtifactCleanup
# Entry point: applies policies and returns a result object.
# DryRun=$true  → plan is generated but no deletions are performed (the caller
#                 is responsible for actual deletion; this function never deletes).
# DryRun=$false → same behaviour — the distinction is recorded in the result
#                 so callers/reports know what was intended.
# ---------------------------------------------------------------------------
function Invoke-ArtifactCleanup {
    param(
        [object[]]$Artifacts,
        [object]$Policy,
        [bool]$DryRun = $true
    )

    if ($null -eq $Artifacts -or $Artifacts.Count -eq 0) {
        throw "Artifacts list cannot be null or empty."
    }
    if ($null -eq $Policy) {
        throw "Policy cannot be null."
    }

    $plan = New-DeletionPlan -Artifacts $Artifacts -Policy $Policy

    return [PSCustomObject]@{
        DryRun = $DryRun
        Policy = $Policy
        Plan   = $plan
    }
}

# ---------------------------------------------------------------------------
# Format-DeletionPlanReport
# Produces a human-readable text report of the deletion plan.
# ---------------------------------------------------------------------------
function Format-DeletionPlanReport {
    param(
        [object]$Plan,
        [bool]$DryRun = $true
    )

    $sb = [System.Text.StringBuilder]::new()

    $modeLabel = if ($DryRun) { "[DRY RUN - no changes will be made]" } else { "[LIVE RUN]" }
    [void]$sb.AppendLine("========================================")
    [void]$sb.AppendLine("  Artifact Cleanup Report  $modeLabel")
    [void]$sb.AppendLine("========================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Summary")
    [void]$sb.AppendLine("-------")
    [void]$sb.AppendLine("  Artifacts to delete : $($Plan.Summary.ArtifactsToDelete)")
    [void]$sb.AppendLine("  Artifacts to retain : $($Plan.Summary.ArtifactsToRetain)")
    [void]$sb.AppendLine("  Space Reclaimed     : $($Plan.Summary.TotalSpaceReclaimedMB) MB")
    [void]$sb.AppendLine("")

    if ($Plan.ToDelete.Count -gt 0) {
        [void]$sb.AppendLine("Artifacts Scheduled for Deletion")
        [void]$sb.AppendLine("--------------------------------")
        foreach ($a in ($Plan.ToDelete | Sort-Object -Property CreatedAt)) {
            $ageDays = [Math]::Round(([DateTime]::UtcNow - $a.CreatedAt).TotalDays, 0)
            $sizeMB  = [Math]::Round($a.SizeBytes / 1MB, 2)
            [void]$sb.AppendLine("  - $($a.Name) | Workflow: $($a.WorkflowRunId) | Age: ${ageDays}d | Size: ${sizeMB} MB")
        }
        [void]$sb.AppendLine("")
    }

    if ($Plan.ToRetain.Count -gt 0) {
        [void]$sb.AppendLine("Artifacts Retained")
        [void]$sb.AppendLine("------------------")
        foreach ($a in ($Plan.ToRetain | Sort-Object -Property CreatedAt -Descending)) {
            $ageDays = [Math]::Round(([DateTime]::UtcNow - $a.CreatedAt).TotalDays, 0)
            $sizeMB  = [Math]::Round($a.SizeBytes / 1MB, 2)
            [void]$sb.AppendLine("  + $($a.Name) | Workflow: $($a.WorkflowRunId) | Age: ${ageDays}d | Size: ${sizeMB} MB")
        }
    }

    [void]$sb.AppendLine("========================================")
    return $sb.ToString()
}
