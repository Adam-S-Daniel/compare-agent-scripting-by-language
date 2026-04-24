# ArtifactCleanup.ps1 — Artifact retention policy enforcement
#
# Exposes one public function: Get-DeletionPlan
#
# Policies applied in order:
#   1. MaxAgeDays             — artifacts older than N days are deleted first
#   2. KeepLatestNPerWorkflow — within each workflow run, keep only the N newest
#   3. MaxTotalSizeBytes      — if retained set still exceeds the size cap,
#                               delete oldest-first until under the cap
#
# None of the input objects are mutated; each deleted artifact in the output
# carries a DeleteReason field indicating which policy triggered its removal.

function Get-DeletionPlan {
    [CmdletBinding()]
    param(
        # Array of artifact hashtables: Name, Size (bytes), CreatedAt, WorkflowRunId
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Artifacts,

        # Policy hashtable; recognised keys:
        #   MaxAgeDays             [int]
        #   MaxTotalSizeBytes      [long]
        #   KeepLatestNPerWorkflow [int]
        [Parameter(Mandatory)]
        [hashtable]$Policy,

        # When set, the plan is generated but labelled as a dry run (no side effects)
        [switch]$DryRun
    )

    $toDelete = [System.Collections.Generic.List[hashtable]]::new()
    $toRetain = [System.Collections.Generic.List[hashtable]]::new()

    if (-not $Artifacts -or $Artifacts.Count -eq 0) {
        return _BuildResult $toDelete $toRetain $DryRun.IsPresent
    }

    $now = [datetime]::Now

    # ── Phase 1: MaxAge ───────────────────────────────────────
    $remaining = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($artifact in $Artifacts) {
        if ($Policy.ContainsKey('MaxAgeDays') -and $Policy.MaxAgeDays -gt 0) {
            $ageDays = ($now - $artifact.CreatedAt).TotalDays
            if ($ageDays -gt $Policy.MaxAgeDays) {
                $copy = _CopyWithReason $artifact 'MaxAge'
                $toDelete.Add($copy)
                continue
            }
        }
        $remaining.Add($artifact)
    }

    # ── Phase 2: KeepLatestNPerWorkflow ───────────────────────
    if ($Policy.ContainsKey('KeepLatestNPerWorkflow') -and $Policy.KeepLatestNPerWorkflow -gt 0) {
        $keepN      = $Policy.KeepLatestNPerWorkflow
        $byWorkflow = $remaining | Group-Object -Property WorkflowRunId
        foreach ($group in $byWorkflow) {
            # Newest first
            $sorted = @($group.Group | Sort-Object -Property CreatedAt -Descending)
            for ($i = 0; $i -lt $sorted.Count; $i++) {
                if ($i -lt $keepN) {
                    $toRetain.Add($sorted[$i])
                } else {
                    $toDelete.Add((_CopyWithReason $sorted[$i] 'KeepLatestN'))
                }
            }
        }
    } else {
        foreach ($a in $remaining) { $toRetain.Add($a) }
    }

    # ── Phase 3: MaxTotalSizeBytes ────────────────────────────
    if ($Policy.ContainsKey('MaxTotalSizeBytes') -and $Policy.MaxTotalSizeBytes -gt 0) {
        $currentSize = ($toRetain | Measure-Object -Property Size -Sum).Sum
        if ($null -eq $currentSize) { $currentSize = 0 }

        if ($currentSize -gt $Policy.MaxTotalSizeBytes) {
            # Oldest-first sort so we remove the least-recent artifacts first
            $sortedOldestFirst = @($toRetain | Sort-Object -Property CreatedAt)
            $toRetain.Clear()

            foreach ($a in $sortedOldestFirst) {
                if ($currentSize -gt $Policy.MaxTotalSizeBytes) {
                    $toDelete.Add((_CopyWithReason $a 'MaxTotalSize'))
                    $currentSize -= $a.Size
                } else {
                    $toRetain.Add($a)
                }
            }
        }
    }

    return _BuildResult $toDelete $toRetain $DryRun.IsPresent
}

# ── Private helpers ───────────────────────────────────────────

function _CopyWithReason {
    param([hashtable]$Artifact, [string]$Reason)
    $copy = $Artifact.Clone()
    $copy['DeleteReason'] = $Reason
    return $copy
}

function _BuildResult {
    param(
        [System.Collections.Generic.List[hashtable]]$ToDelete,
        [System.Collections.Generic.List[hashtable]]$ToRetain,
        [bool]$IsDryRun
    )

    $spaceReclaimed = ($ToDelete | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }

    return @{
        ArtifactsToDelete = $ToDelete.ToArray()
        ArtifactsToRetain = $ToRetain.ToArray()
        Summary           = @{
            ArtifactsDeleted         = $ToDelete.Count
            ArtifactsRetained        = $ToRetain.Count
            TotalSpaceReclaimedBytes = $spaceReclaimed
            DryRun                   = $IsDryRun
        }
    }
}
