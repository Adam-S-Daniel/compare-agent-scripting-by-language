# ArtifactCleanup.ps1
# Applies retention policies to a list of artifacts and produces a deletion plan.
#
# Retention policies (hashtable keys):
#   MaxAgeDays       - delete artifacts older than this many days
#   MaxTotalSizeMB   - if total size exceeds this, delete oldest first until under limit
#   KeepLatestN      - keep only the N most-recent artifacts per WorkflowRunId
#
# Usage:
#   $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy
#   $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy [-DryRun]

function Assert-PolicyValid {
    param([hashtable]$Policy)
    $required = @('MaxAgeDays', 'MaxTotalSizeMB', 'KeepLatestN')
    foreach ($key in $required) {
        if (-not $Policy.ContainsKey($key)) {
            throw "Policy is missing required key: '$key'. Required keys: $($required -join ', ')"
        }
    }
}

# Returns @{ ToDelete = [...]; ToKeep = [...] }
function Get-ArtifactsToDelete {
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][hashtable]$Policy
    )

    Assert-PolicyValid -Policy $Policy

    $now       = [DateTime]::UtcNow
    $cutoff    = $now.AddDays(-$Policy.MaxAgeDays)
    $deleteSet = [System.Collections.Generic.HashSet[string]]::new()

    # Policy 1: MaxAgeDays — mark artifacts older than cutoff
    foreach ($a in $Artifacts) {
        if ($a.CreatedAt -lt $cutoff) {
            [void]$deleteSet.Add($a.Name)
        }
    }

    # Policy 2: KeepLatestN — per WorkflowRunId, keep only the N newest
    $byWorkflow = $Artifacts | Group-Object -Property WorkflowRunId
    foreach ($group in $byWorkflow) {
        $sorted = $group.Group | Sort-Object -Property CreatedAt -Descending
        if ($sorted.Count -gt $Policy.KeepLatestN) {
            $toRemove = $sorted | Select-Object -Skip $Policy.KeepLatestN
            foreach ($a in $toRemove) {
                [void]$deleteSet.Add($a.Name)
            }
        }
    }

    # Policy 3: MaxTotalSizeMB — if remaining total exceeds limit, delete oldest first
    # Work on the set not already marked for deletion
    $candidates = $Artifacts | Where-Object { -not $deleteSet.Contains($_.Name) } |
                  Sort-Object -Property CreatedAt   # oldest first

    $totalMB = ($candidates | Measure-Object -Property SizeMB -Sum).Sum
    if ($null -eq $totalMB) { $totalMB = 0 }

    foreach ($a in $candidates) {
        if ($totalMB -le $Policy.MaxTotalSizeMB) { break }
        [void]$deleteSet.Add($a.Name)
        $totalMB -= $a.SizeMB
    }

    $toDelete = $Artifacts | Where-Object { $deleteSet.Contains($_.Name) }
    $toKeep   = $Artifacts | Where-Object { -not $deleteSet.Contains($_.Name) }

    return [PSCustomObject]@{
        ToDelete = @($toDelete)
        ToKeep   = @($toKeep)
    }
}

# Builds a deletion plan with summary
function New-DeletionPlan {
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][hashtable]$Policy
    )

    $decision = Get-ArtifactsToDelete -Artifacts $Artifacts -Policy $Policy

    $spaceReclaimed = ($decision.ToDelete | Measure-Object -Property SizeMB -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }

    return [PSCustomObject]@{
        ToDelete = $decision.ToDelete
        ToKeep   = $decision.ToKeep
        Summary  = [PSCustomObject]@{
            ArtifactsDeleted  = $decision.ToDelete.Count
            ArtifactsRetained = $decision.ToKeep.Count
            SpaceReclaimedMB  = $spaceReclaimed
        }
    }
}

# Executes (or simulates) the deletion plan.
# In dry-run mode no deletions are recorded; outside dry-run the ToDelete list
# is treated as "deleted" (in a real system this would call an API).
function Invoke-ArtifactCleanup {
    param(
        [Parameter(Mandatory)][AllowNull()][object[]]$Artifacts,
        [Parameter(Mandatory)][hashtable]$Policy,
        [switch]$DryRun
    )

    if ($null -eq $Artifacts) {
        throw "Artifacts parameter must not be null. Provide an array of artifact objects."
    }

    Assert-PolicyValid -Policy $Policy

    $plan    = New-DeletionPlan -Artifacts $Artifacts -Policy $Policy
    $deleted = @()

    if (-not $DryRun) {
        # In a real implementation this would call the GitHub Actions API.
        # Here we simply record which artifacts were "deleted".
        $deleted = $plan.ToDelete
    }

    return [PSCustomObject]@{
        DryRun           = $DryRun.IsPresent
        Plan             = $plan
        DeletedArtifacts = @($deleted)
    }
}
