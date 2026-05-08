# ArtifactCleanup.psm1
#
# Pure-logic module: compute a deletion plan from artifact metadata and retention
# policies. No I/O, no HTTP — testable in isolation via Pester.
#
# Exported functions:
#   Get-ArtifactDeletionPlan  — evaluate policies, return a plan object
#   Invoke-ArtifactCleanup    — apply the plan (with optional DryRun and injected Deleter)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ArtifactDeletionPlan {
    <#
    .SYNOPSIS
        Apply retention policies to a list of artifacts and return a deletion plan.
    .PARAMETER Artifacts
        Array of objects with: Name, SizeBytes, CreatedAt (DateTime), WorkflowRunId.
        At least one of the three policy parameters must be supplied.
    .PARAMETER MaxAgeDays
        Artifacts whose CreatedAt is MORE THAN this many days ago are candidates for deletion.
    .PARAMETER MaxTotalSizeBytes
        After age/keep-N filtering, evict oldest retained artifacts until the
        total retained size fits within this cap.
    .PARAMETER KeepLatestPerWorkflow
        Per WorkflowRunId, keep only the N most-recently-created artifacts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Artifacts,

        [Nullable[int]]      $MaxAgeDays,
        [Nullable[long]]     $MaxTotalSizeBytes,
        [Nullable[int]]      $KeepLatestPerWorkflow,
        [Nullable[datetime]] $ReferenceDate   # defaults to now; injectable for testing
    )

    # At least one policy is required — otherwise every artifact would be kept,
    # which is equivalent to not running cleanup at all.
    if (-not $MaxAgeDays -and -not $MaxTotalSizeBytes -and -not $KeepLatestPerWorkflow) {
        throw "Get-ArtifactDeletionPlan requires at least one retention policy " +
              "(MaxAgeDays, MaxTotalSizeBytes, or KeepLatestPerWorkflow)."
    }

    # Use a HashSet to accumulate names of artifacts marked for deletion.
    # Names are assumed unique within the list.
    $toDelete = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    # ── Policy 1: max age ────────────────────────────────────────────────────
    if ($MaxAgeDays) {
        # Use midnight of (referenceDate - MaxAgeDays) as the cutoff. Whole-day
        # granularity avoids sub-second clock-drift in tests: an artifact created
        # exactly MaxAgeDays ago is >= the cutoff midnight and is retained.
        $now    = if ($ReferenceDate) { $ReferenceDate } else { Get-Date }
        $cutoff = $now.Date.AddDays(-$MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ($a.CreatedAt -lt $cutoff) {
                [void] $toDelete.Add($a.Name)
            }
        }
    }

    # ── Policy 2: keep-latest-N per workflow ─────────────────────────────────
    if ($KeepLatestPerWorkflow) {
        $groups = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            # Sort descending so the first N are the newest.
            $sorted = $g.Group | Sort-Object -Property CreatedAt -Descending
            # Everything after the first N is excess.
            foreach ($a in ($sorted | Select-Object -Skip $KeepLatestPerWorkflow)) {
                [void] $toDelete.Add($a.Name)
            }
        }
    }

    # ── Policy 3: max total size ─────────────────────────────────────────────
    if ($MaxTotalSizeBytes) {
        # Operate only on what is still retained after the previous policies.
        # Evict oldest first (newest artifacts are most valuable).
        $retained = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) } |
                      Sort-Object -Property CreatedAt)  # ascending = oldest first

        $totalSize = [long] 0
        foreach ($a in $retained) { $totalSize += [long] $a.SizeBytes }

        foreach ($a in $retained) {
            if ($totalSize -le $MaxTotalSizeBytes) { break }
            [void] $toDelete.Add($a.Name)
            $totalSize -= [long] $a.SizeBytes
        }
    }

    # ── Build result arrays ───────────────────────────────────────────────────
    $delete = @($Artifacts | Where-Object {  $toDelete.Contains($_.Name) })
    $retain = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) })

    $reclaimedBytes = [long] 0
    foreach ($a in $delete) { $reclaimedBytes += [long] $a.SizeBytes }

    [pscustomobject] @{
        Delete  = $delete
        Retain  = $retain
        Summary = [pscustomobject] @{
            DeletedCount        = $delete.Count
            RetainedCount       = $retain.Count
            SpaceReclaimedBytes = $reclaimedBytes
        }
    }
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Apply the deletion plan, optionally dry-running.
    .PARAMETER Artifacts
        Same format as Get-ArtifactDeletionPlan.
    .PARAMETER MaxAgeDays / MaxTotalSizeBytes / KeepLatestPerWorkflow
        Forwarded to Get-ArtifactDeletionPlan.
    .PARAMETER DryRun
        When set, compute the plan but do NOT invoke the Deleter. The returned
        object carries DryRun=$true so callers can distinguish.
    .PARAMETER Deleter
        A ScriptBlock that receives a single artifact object and performs the
        actual deletion (e.g. calls the GitHub API). Defaults to a no-op so
        callers that only need the plan can omit it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Artifacts,

        [Nullable[int]]      $MaxAgeDays,
        [Nullable[long]]     $MaxTotalSizeBytes,
        [Nullable[int]]      $KeepLatestPerWorkflow,
        [Nullable[datetime]] $ReferenceDate,

        [switch]      $DryRun,
        [scriptblock] $Deleter = { param($a) }
    )

    $planParams = @{ Artifacts = $Artifacts }
    if ($MaxAgeDays)            { $planParams.MaxAgeDays            = $MaxAgeDays }
    if ($MaxTotalSizeBytes)     { $planParams.MaxTotalSizeBytes     = $MaxTotalSizeBytes }
    if ($KeepLatestPerWorkflow) { $planParams.KeepLatestPerWorkflow = $KeepLatestPerWorkflow }
    if ($ReferenceDate)         { $planParams.ReferenceDate         = $ReferenceDate }

    $plan = Get-ArtifactDeletionPlan @planParams

    if (-not $DryRun) {
        foreach ($a in $plan.Delete) {
            & $Deleter $a
        }
    }

    # Attach DryRun flag to the returned plan so callers can log it.
    $plan | Add-Member -NotePropertyName DryRun -NotePropertyValue ([bool] $DryRun) -PassThru
}

Export-ModuleMember -Function Get-ArtifactDeletionPlan, Invoke-ArtifactCleanup
