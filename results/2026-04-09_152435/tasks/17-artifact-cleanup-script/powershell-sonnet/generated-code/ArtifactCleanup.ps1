# ArtifactCleanup.ps1
# Applies retention policies to a list of artifacts and produces a deletion plan.
#
# Retention policies (all are applied; union of results is deleted):
#   MaxAgeDays        - delete artifacts older than N days
#   MaxTotalSizeBytes - delete oldest artifacts until total fits within limit
#   KeepLatestN       - per workflow run ID, keep only the N most recent artifacts

#region --- Core policy functions ---

# Returns artifacts whose age exceeds MaxAgeDays (strictly older, boundary = keep).
function Get-ArtifactsExceedingMaxAge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Artifacts,
        [Parameter(Mandatory)] [int]      $MaxAgeDays,
        [datetime] $ReferenceDate = [datetime]::UtcNow
    )
    $cutoff = $ReferenceDate.AddDays(-$MaxAgeDays)
    $Artifacts | Where-Object { $_.CreatedAt -lt $cutoff }
}

# Returns the oldest artifacts that cause the total size to exceed MaxTotalSizeBytes.
# Keeps the newest artifacts that fit within the limit; everything else is returned.
function Get-ArtifactsExceedingTotalSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Artifacts,
        [Parameter(Mandatory)] [long]     $MaxTotalSizeBytes
    )
    # Sort newest first so we fill the "keep" bucket from the front
    $sorted = $Artifacts | Sort-Object CreatedAt -Descending
    $running = 0L
    $toDelete = [System.Collections.Generic.List[object]]::new()

    foreach ($a in $sorted) {
        if ($running + $a.SizeBytes -le $MaxTotalSizeBytes) {
            $running += $a.SizeBytes
        } else {
            $toDelete.Add($a)
        }
    }
    $toDelete.ToArray()
}

# For each unique WorkflowRunId, keeps the N most recent artifacts; returns the rest.
function Get-ArtifactsBeyondKeepLatestN {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Artifacts,
        [Parameter(Mandatory)] [int]      $KeepLatestN
    )
    $toDelete = [System.Collections.Generic.List[object]]::new()
    $byWorkflow = $Artifacts | Group-Object WorkflowRunId

    foreach ($group in $byWorkflow) {
        $sorted = $group.Group | Sort-Object CreatedAt -Descending
        if ($sorted.Count -gt $KeepLatestN) {
            $sorted | Select-Object -Skip $KeepLatestN | ForEach-Object { $toDelete.Add($_) }
        }
    }
    $toDelete.ToArray()
}

#endregion

#region --- Deletion plan ---

# Applies all policies and returns a plan object describing what to delete/retain.
function New-DeletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]   $Artifacts,
        [Parameter(Mandatory)] [PSCustomObject] $Policy,
        [datetime] $ReferenceDate = [datetime]::UtcNow
    )

    # Collect all candidates for deletion from each policy
    $byAge  = Get-ArtifactsExceedingMaxAge   -Artifacts $Artifacts -MaxAgeDays        $Policy.MaxAgeDays        -ReferenceDate $ReferenceDate
    $bySize = Get-ArtifactsExceedingTotalSize -Artifacts $Artifacts -MaxTotalSizeBytes  $Policy.MaxTotalSizeBytes
    $byN    = Get-ArtifactsBeyondKeepLatestN  -Artifacts $Artifacts -KeepLatestN        $Policy.KeepLatestN

    # Union by name (deduplicate)
    $deleteNames = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($a in (@($byAge) + @($bySize) + @($byN))) {
        if ($null -ne $a) { [void]$deleteNames.Add($a.Name) }
    }

    $toDelete  = $Artifacts | Where-Object { $deleteNames.Contains($_.Name) }
    $toRetain  = $Artifacts | Where-Object { -not $deleteNames.Contains($_.Name) }

    $spaceReclaimed = ($toDelete | Measure-Object SizeBytes -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0L }

    [PSCustomObject]@{
        ToDelete            = @($toDelete)
        ToRetain            = @($toRetain)
        SpaceReclaimedBytes = $spaceReclaimed
        DeletedCount        = @($toDelete).Count
        RetainedCount       = @($toRetain).Count
    }
}

#endregion

#region --- Top-level entry point ---

# Runs the cleanup pipeline. In dry-run mode nothing is actually deleted.
# Returns a result object suitable for further inspection or reporting.
function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]       $Artifacts,
        [Parameter(Mandatory)] [PSCustomObject] $Policy,
        [switch]  $DryRun,
        [datetime] $ReferenceDate = [datetime]::UtcNow
    )

    $plan = New-DeletionPlan -Artifacts $Artifacts -Policy $Policy -ReferenceDate $ReferenceDate

    if (-not $DryRun) {
        # In a real implementation this is where API calls to delete each artifact would live.
        # For now, the mock data has no real backing store, so this is a no-op placeholder.
        Write-Verbose "Deleting $($plan.DeletedCount) artifact(s)..."
    }

    [PSCustomObject]@{
        DryRun              = $DryRun.IsPresent
        Plan                = $plan
        DeletedCount        = $plan.DeletedCount
        RetainedCount       = $plan.RetainedCount
        SpaceReclaimedBytes = $plan.SpaceReclaimedBytes
    }
}

#endregion

#region --- Formatting ---

# Returns a human-readable summary string for the deletion plan.
function Format-CleanupSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject] $Plan
    )

    $mode = if ($Plan.DryRun) { "[DRY RUN] " } else { "" }
    $mb   = [math]::Round($Plan.SpaceReclaimedBytes / 1MB, 2)

    $lines = @(
        "${mode}Artifact Cleanup Summary"
        "================================"
        ("Artifacts to delete:  {0}" -f $Plan.DeletedCount)
        ("Artifacts to retain:  {0}" -f $Plan.RetainedCount)
        ("Space reclaimed:      {0} MB" -f $mb)
    )

    if ($Plan.DeletedCount -gt 0) {
        $lines += ""
        $lines += "Artifacts marked for deletion:"
        foreach ($a in $Plan.ToDelete) {
            $sizeMB = [math]::Round($a.SizeBytes / 1MB, 2)
            $lines += ("  - {0} ({1} MB, created {2})" -f $a.Name, $sizeMB, $a.CreatedAt.ToString("yyyy-MM-dd"))
        }
    }

    $lines -join "`n"
}

#endregion
