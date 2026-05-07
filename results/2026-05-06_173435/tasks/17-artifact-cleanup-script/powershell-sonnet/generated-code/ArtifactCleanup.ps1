# ArtifactCleanup.ps1
#
# Applies retention policies to a list of artifact metadata objects and
# produces a deletion plan with a summary (space reclaimed, artifact counts).
# Supports dry-run mode: the plan is generated but no mutations occur.
#
# Retention policies (all optional; union of all flagged artifacts is deleted):
#   MaxAgeDays              — delete artifacts older than N days
#   KeepLatestNPerWorkflow  — per WorkflowRunId, keep only the N newest
#   MaxTotalSizeMB          — after age/count policies, delete oldest remaining
#                             until retained total <= this limit
#
# TDD progression (tests in ArtifactCleanup.Tests.ps1):
#   Iter 1: New-Artifact — creates typed PSCustomObject
#   Iter 2: Get-DeletionPlan MaxAgeDays branch
#   Iter 3: Get-DeletionPlan MaxTotalSizeMB branch
#   Iter 4: Get-DeletionPlan KeepLatestNPerWorkflow branch
#   Iter 5: Combined policy union
#   Iter 6: DryRun flag propagated to plan
#   Iter 7: Invoke-ArtifactCleanup wrapper + IsDeleted mutation

# ---------------------------------------------------------------------------
# New-Artifact
# Iter 1 green: minimal factory function for artifact metadata objects.
# ---------------------------------------------------------------------------
function New-Artifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$SizeMB,

        [Parameter(Mandatory)]
        [DateTime]$CreatedAt,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkflowRunId
    )

    [PSCustomObject]@{
        PSTypeName    = 'ArtifactCleanup.Artifact'
        Name          = $Name
        SizeMB        = $SizeMB
        CreatedAt     = $CreatedAt
        WorkflowRunId = $WorkflowRunId
        IsDeleted     = $false
    }
}

# ---------------------------------------------------------------------------
# Get-DeletionPlan
# Iters 2–6: core policy engine. Returns an immutable plan object.
# ---------------------------------------------------------------------------
function Get-DeletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [DateTime]$ReferenceDate = (Get-Date),

        [switch]$DryRun
    )

    # Empty-input fast path (Iter 8 edge-case)
    if (-not $Artifacts -or $Artifacts.Count -eq 0) {
        return [PSCustomObject]@{
            ArtifactsToDelete = @()
            ArtifactsToRetain = @()
            IsDryRun          = $DryRun.IsPresent
            Summary           = [PSCustomObject]@{
                TotalArtifacts    = 0
                ArtifactsDeleted  = 0
                ArtifactsRetained = 0
                SpaceReclaimedMB  = 0.0
                SpaceRetainedMB   = 0.0
            }
        }
    }

    # Accumulate names to delete; using a HashSet for O(1) look-ups and
    # automatic deduplication when multiple policies flag the same artifact.
    $toDelete = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    # ------------------------------------------------------------------
    # Policy: MaxAgeDays (Iter 2)
    # Delete any artifact whose CreatedAt is strictly before the cutoff.
    # ------------------------------------------------------------------
    if ($Policy.ContainsKey('MaxAgeDays') -and
        $null -ne $Policy.MaxAgeDays -and
        $Policy.MaxAgeDays -gt 0) {

        $cutoff = $ReferenceDate.AddDays(-$Policy.MaxAgeDays)
        foreach ($artifact in $Artifacts) {
            if ($artifact.CreatedAt -lt $cutoff) {
                [void]$toDelete.Add($artifact.Name)
            }
        }
    }

    # ------------------------------------------------------------------
    # Policy: KeepLatestNPerWorkflow (Iter 4)
    # Within each WorkflowRunId group, sort newest-first and flag
    # everything beyond position N for deletion.
    # ------------------------------------------------------------------
    if ($Policy.ContainsKey('KeepLatestNPerWorkflow') -and
        $null -ne $Policy.KeepLatestNPerWorkflow -and
        $Policy.KeepLatestNPerWorkflow -gt 0) {

        $groups = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($group in $groups) {
            $sortedDesc = $group.Group | Sort-Object -Property CreatedAt -Descending
            $excess = $sortedDesc | Select-Object -Skip $Policy.KeepLatestNPerWorkflow
            foreach ($artifact in $excess) {
                [void]$toDelete.Add($artifact.Name)
            }
        }
    }

    # ------------------------------------------------------------------
    # Policy: MaxTotalSizeMB (Iter 3)
    # Applied AFTER age and count policies so we only measure what would
    # actually be retained. Delete oldest-first until total <= limit.
    # ------------------------------------------------------------------
    if ($Policy.ContainsKey('MaxTotalSizeMB') -and
        $null -ne $Policy.MaxTotalSizeMB -and
        $Policy.MaxTotalSizeMB -gt 0) {

        $remaining = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) })
        $currentMB = if ($remaining.Count -gt 0) {
            ($remaining | Measure-Object -Property SizeMB -Sum).Sum
        } else { 0 }

        if ($currentMB -gt $Policy.MaxTotalSizeMB) {
            # Sort oldest-first so we evict the least-valuable artifacts first
            $byAge = $remaining | Sort-Object -Property CreatedAt
            foreach ($artifact in $byAge) {
                if ($currentMB -le $Policy.MaxTotalSizeMB) { break }
                [void]$toDelete.Add($artifact.Name)
                $currentMB -= $artifact.SizeMB
            }
        }
    }

    # ------------------------------------------------------------------
    # Build result arrays and compute summary metrics
    # ------------------------------------------------------------------
    $artifactsToDelete = @($Artifacts | Where-Object { $toDelete.Contains($_.Name) })
    $artifactsToRetain = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) })

    $spaceReclaimedMB = if ($artifactsToDelete.Count -gt 0) {
        ($artifactsToDelete | Measure-Object -Property SizeMB -Sum).Sum
    } else { 0.0 }

    $spaceRetainedMB = if ($artifactsToRetain.Count -gt 0) {
        ($artifactsToRetain | Measure-Object -Property SizeMB -Sum).Sum
    } else { 0.0 }

    [PSCustomObject]@{
        ArtifactsToDelete = $artifactsToDelete
        ArtifactsToRetain = $artifactsToRetain
        IsDryRun          = $DryRun.IsPresent
        Summary           = [PSCustomObject]@{
            TotalArtifacts    = $Artifacts.Count
            ArtifactsDeleted  = $artifactsToDelete.Count
            ArtifactsRetained = $artifactsToRetain.Count
            SpaceReclaimedMB  = $spaceReclaimedMB
            SpaceRetainedMB   = $spaceRetainedMB
        }
    }
}

# ---------------------------------------------------------------------------
# Invoke-ArtifactCleanup  (Iter 7)
# Wrapper that obtains a plan and, when not in dry-run, mutates each artifact
# by setting IsDeleted=true. Returns the plan regardless of dry-run state.
# ---------------------------------------------------------------------------
function Invoke-ArtifactCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [DateTime]$ReferenceDate = (Get-Date),

        [switch]$DryRun
    )

    $plan = Get-DeletionPlan -Artifacts $Artifacts -Policy $Policy `
        -ReferenceDate $ReferenceDate -DryRun:$DryRun

    if (-not $DryRun) {
        foreach ($artifact in $plan.ArtifactsToDelete) {
            if ($PSCmdlet.ShouldProcess($artifact.Name, "Delete artifact")) {
                $artifact.IsDeleted = $true
            }
        }
    }

    return $plan
}

# ---------------------------------------------------------------------------
# Format-DeletionPlanSummary
# Returns a human-readable summary string for the plan (used in workflow demo).
# ---------------------------------------------------------------------------
function Format-DeletionPlanSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Plan
    )

    $tag = if ($Plan.IsDryRun) { ' [DRY RUN]' } else { '' }
    $deleteLines = $Plan.ArtifactsToDelete | ForEach-Object {
        "  - $($_.Name)  ($($_.SizeMB) MB, created $($_.CreatedAt.ToString('yyyy-MM-dd')), run $($_.WorkflowRunId))"
    }

    @"
Artifact Cleanup Plan$tag
==============================
Total artifacts:     $($Plan.Summary.TotalArtifacts)
Artifacts to delete: $($Plan.Summary.ArtifactsDeleted)
Artifacts to retain: $($Plan.Summary.ArtifactsRetained)
Space to reclaim:    $($Plan.Summary.SpaceReclaimedMB) MB
Space retained:      $($Plan.Summary.SpaceRetainedMB) MB

Marked for deletion:
$($deleteLines -join "`n")
"@
}
