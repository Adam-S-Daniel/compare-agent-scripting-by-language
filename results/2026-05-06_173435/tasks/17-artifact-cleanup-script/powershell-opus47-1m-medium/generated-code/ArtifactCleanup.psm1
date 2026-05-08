# ArtifactCleanup.psm1
#
# Pure-logic module: takes artifact metadata + retention policies and produces a
# deletion plan. No I/O, no HTTP — that's the caller's job. This separation
# makes the policy decisions easy to test, and lets a real GitHub deleter be
# injected into Invoke-ArtifactCleanup.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DeletionPlan {
    <#
    .SYNOPSIS
        Compute which artifacts to delete given retention policies.
    .PARAMETER Artifacts
        Array of objects with: Name, SizeBytes, CreatedAt (DateTime), WorkflowRunId.
    .PARAMETER MaxAgeDays
        Delete artifacts whose CreatedAt is older than this many days.
    .PARAMETER MaxTotalSizeBytes
        Cap on total retained size. Oldest retained artifacts are dropped first.
    .PARAMETER KeepLatestPerWorkflow
        Per workflow run id, keep only the N newest artifacts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Artifacts,
        [Nullable[int]]$MaxAgeDays,
        [Nullable[long]]$MaxTotalSizeBytes,
        [Nullable[int]]$KeepLatestPerWorkflow
    )

    if (-not $MaxAgeDays -and -not $MaxTotalSizeBytes -and -not $KeepLatestPerWorkflow) {
        throw "Get-DeletionPlan requires at least one retention policy (MaxAgeDays, MaxTotalSizeBytes, or KeepLatestPerWorkflow)."
    }

    # Track delete decisions in a hashset of names. Names are assumed unique;
    # if duplicates ever appear we'd need a different identity.
    $toDelete = [System.Collections.Generic.HashSet[string]]::new()
    $cutoff   = if ($MaxAgeDays) { (Get-Date).AddDays(-$MaxAgeDays) } else { $null }

    foreach ($a in $Artifacts) {
        if ($cutoff -and $a.CreatedAt -lt $cutoff) { [void]$toDelete.Add($a.Name) }
    }

    if ($KeepLatestPerWorkflow) {
        $groups = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $sorted = $g.Group | Sort-Object -Property CreatedAt -Descending
            # Skip the first N (newest); the rest get marked for deletion.
            foreach ($a in ($sorted | Select-Object -Skip $KeepLatestPerWorkflow)) {
                [void]$toDelete.Add($a.Name)
            }
        }
    }

    if ($MaxTotalSizeBytes) {
        # Of what's still retained, drop oldest until we fit. Newest artifacts
        # are most valuable, so age order is the natural eviction order.
        $retainedSorted = $Artifacts |
            Where-Object { -not $toDelete.Contains($_.Name) } |
            Sort-Object -Property CreatedAt  # oldest first
        $totalSize = ($retainedSorted | Measure-Object -Property SizeBytes -Sum).Sum
        foreach ($a in $retainedSorted) {
            if ($totalSize -le $MaxTotalSizeBytes) { break }
            [void]$toDelete.Add($a.Name)
            $totalSize -= $a.SizeBytes
        }
    }

    $delete = @($Artifacts | Where-Object { $toDelete.Contains($_.Name) })
    $retain = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) })

    # Sum SizeBytes by hand: Measure-Object on an empty list under StrictMode
    # returns an object whose .Sum property doesn't exist.
    $sumSize = {
        param($items)
        $total = [long]0
        foreach ($i in $items) { $total += [long]$i.SizeBytes }
        $total
    }

    [pscustomobject]@{
        Delete  = $delete
        Retain  = $retain
        Summary = [pscustomobject]@{
            DeletedCount        = $delete.Count
            RetainedCount       = $retain.Count
            SpaceReclaimedBytes = & $sumSize $delete
            RetainedSizeBytes   = & $sumSize $retain
        }
    }
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Compute a plan and execute it via the supplied -Deleter scriptblock.
        In -DryRun mode the deleter is never called.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Artifacts,
        [Nullable[int]]$MaxAgeDays,
        [Nullable[long]]$MaxTotalSizeBytes,
        [Nullable[int]]$KeepLatestPerWorkflow,
        [switch]$DryRun,
        [scriptblock]$Deleter = { param($a) }
    )

    $plan = Get-DeletionPlan -Artifacts $Artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow

    if (-not $DryRun) {
        foreach ($a in $plan.Delete) {
            try {
                & $Deleter $a
            } catch {
                Write-Error "Failed to delete artifact '$($a.Name)': $($_.Exception.Message)"
            }
        }
    }

    $plan | Add-Member -NotePropertyName DryRun -NotePropertyValue ([bool]$DryRun) -PassThru
}

Export-ModuleMember -Function Get-DeletionPlan, Invoke-ArtifactCleanup
