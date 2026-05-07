# Artifact cleanup script: applies retention policies and generates deletion plans.
# Supports dry-run mode — when -DryRun is set the plan is produced but nothing is deleted.
#
# When dot-sourced by Pester (. ./ArtifactCleanup.ps1) the entry-point block is skipped
# so only the function definitions are loaded.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [int]$MaxAgeDays     = 30,
    [int]$MaxTotalSizeMB = 500,
    [int]$KeepLatestN    = 5
)

# ---- Policy application --------------------------------------------------

function Get-ArtifactsToDelete {
    <#
    .SYNOPSIS
        Returns the subset of $Artifacts that should be deleted under $Policy.
    .PARAMETER Artifacts
        Array of PSCustomObject: Name, SizeMB, CreatedAt (datetime), WorkflowRunId.
    .PARAMETER Policy
        PSCustomObject with optional fields: MaxAgeDays, MaxTotalSizeMB, KeepLatestN.
        Null fields mean "no limit for that policy axis".
    .PARAMETER ReferenceDate
        The date used as "now" for age calculations.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][PSCustomObject]$Policy,
        [datetime]$ReferenceDate = [datetime]::UtcNow
    )

    # Use a hashtable keyed by Name to collect unique artifacts to delete
    $toDeleteMap = @{}

    # --- MaxAgeDays: flag any artifact whose age exceeds the limit ---
    if ($null -ne $Policy.MaxAgeDays) {
        foreach ($a in $Artifacts) {
            $ageDays = ($ReferenceDate - $a.CreatedAt).TotalDays
            if ($ageDays -gt $Policy.MaxAgeDays) {
                $toDeleteMap[$a.Name] = $a
            }
        }
    }

    # --- MaxTotalSizeMB: remove oldest artifacts until total fits ---
    if ($null -ne $Policy.MaxTotalSizeMB) {
        $sorted  = $Artifacts | Sort-Object CreatedAt
        $totalMB = ($Artifacts | Measure-Object -Property SizeMB -Sum).Sum
        foreach ($a in $sorted) {
            if ($totalMB -le $Policy.MaxTotalSizeMB) { break }
            $toDeleteMap[$a.Name] = $a
            $totalMB -= $a.SizeMB
        }
    }

    # --- KeepLatestN: per workflow, keep only the N most recent artifacts ---
    if ($null -ne $Policy.KeepLatestN) {
        $byWorkflow = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($group in $byWorkflow) {
            # Sort newest-first; everything after index N-1 is excess
            $sorted = $group.Group | Sort-Object CreatedAt -Descending
            $excess = $sorted | Select-Object -Skip $Policy.KeepLatestN
            foreach ($a in $excess) {
                $toDeleteMap[$a.Name] = $a
            }
        }
    }

    return @($toDeleteMap.Values)
}

# ---- Deletion plan -------------------------------------------------------

function New-DeletionPlan {
    <#
    .SYNOPSIS
        Builds a deletion plan object summarising what would (or will) be deleted.
    .PARAMETER DryRun
        When $true the plan is flagged as a dry run; no side-effects occur.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][PSCustomObject]$Policy,
        [datetime]$ReferenceDate = [datetime]::UtcNow,
        [bool]$DryRun = $true
    )

    $toDelete  = Get-ArtifactsToDelete -Artifacts $Artifacts -Policy $Policy -ReferenceDate $ReferenceDate
    $deleteSet = @{}
    foreach ($a in $toDelete) { $deleteSet[$a.Name] = $true }
    $toRetain  = @($Artifacts | Where-Object { -not $deleteSet.ContainsKey($_.Name) })

    $spaceReclaimed = if ($toDelete.Count -gt 0) {
        ($toDelete | Measure-Object -Property SizeMB -Sum).Sum
    } else { 0 }

    return [PSCustomObject]@{
        TotalArtifacts   = $Artifacts.Count
        DeletedCount     = $toDelete.Count
        RetainedCount    = $toRetain.Count
        SpaceReclaimedMB = $spaceReclaimed
        IsDryRun         = $DryRun
        ToDelete         = $toDelete
        ToRetain         = $toRetain
    }
}

# ---- Formatting ----------------------------------------------------------

function Format-DeletionPlanSummary {
    <#
    .SYNOPSIS
        Returns a human-readable summary string for a deletion plan.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$Plan)

    $dryTag = if ($Plan.IsDryRun) { " [DRY RUN]" } else { "" }
    $lines = @(
        "=== Artifact Cleanup Plan$dryTag ===",
        "Total artifacts : $($Plan.TotalArtifacts)",
        "Delete          : $($Plan.DeletedCount)",
        "Retain          : $($Plan.RetainedCount)",
        "Space reclaimed : $($Plan.SpaceReclaimedMB) MB"
    )

    if ($Plan.ToDelete.Count -gt 0) {
        $lines += ""
        $lines += "Artifacts to Delete:"
        foreach ($a in ($Plan.ToDelete | Sort-Object CreatedAt)) {
            $lines += "  - $($a.Name)  [$($a.SizeMB) MB, created $($a.CreatedAt.ToString('yyyy-MM-dd')), run $($a.WorkflowRunId)]"
        }
    }

    return $lines -join "`n"
}

# ---- Entry point (skipped when dot-sourced by Pester) -------------------
# $MyInvocation.InvocationName is '.' when dot-sourced.
if ($MyInvocation.InvocationName -ne '.') {
    # Mock artifact data used when no external source is provided
    $mockArtifacts = @(
        [PSCustomObject]@{ Name="build-artifacts-v1.0"; SizeMB=120; CreatedAt=[datetime]"2024-11-01"; WorkflowRunId="wf-build" },
        [PSCustomObject]@{ Name="build-artifacts-v1.1"; SizeMB=130; CreatedAt=[datetime]"2024-11-15"; WorkflowRunId="wf-build" },
        [PSCustomObject]@{ Name="build-artifacts-v1.2"; SizeMB=140; CreatedAt=[datetime]"2024-12-01"; WorkflowRunId="wf-build" },
        [PSCustomObject]@{ Name="test-results-001";     SizeMB=20;  CreatedAt=[datetime]"2024-11-10"; WorkflowRunId="wf-test"  },
        [PSCustomObject]@{ Name="test-results-002";     SizeMB=22;  CreatedAt=[datetime]"2024-12-05"; WorkflowRunId="wf-test"  },
        [PSCustomObject]@{ Name="release-pkg-2.0";      SizeMB=200; CreatedAt=[datetime]"2024-10-01"; WorkflowRunId="wf-release" },
        [PSCustomObject]@{ Name="release-pkg-2.1";      SizeMB=210; CreatedAt=[datetime]"2024-12-10"; WorkflowRunId="wf-release" }
    )

    $policy = [PSCustomObject]@{
        MaxAgeDays     = $MaxAgeDays
        MaxTotalSizeMB = $MaxTotalSizeMB
        KeepLatestN    = $KeepLatestN
    }

    $refDate = [datetime]"2024-12-20"
    $plan    = New-DeletionPlan -Artifacts $mockArtifacts -Policy $policy -ReferenceDate $refDate -DryRun:$DryRun.IsPresent
    $summary = Format-DeletionPlanSummary -Plan $plan

    Write-Output $summary
}
