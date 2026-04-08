# ArtifactCleanup.ps1
# Applies retention policies to CI/CD artifacts and generates deletion plans.
# Supports: max age, max total size, keep-latest-N per workflow, and dry-run mode.

function New-RetentionPolicy {
    <#
    .SYNOPSIS
        Creates a retention policy object that governs which artifacts to keep or delete.
    .PARAMETER MaxAgeDays
        Artifacts older than this many days are candidates for deletion. Default: 30.
    .PARAMETER MaxTotalSizeMB
        If total artifact size exceeds this, oldest artifacts are deleted until under budget.
    .PARAMETER KeepLatestN
        Always keep at least the N most recent artifacts per workflow run ID. Default: 1.
    #>
    [CmdletBinding()]
    param(
        [int]$MaxAgeDays = 30,
        [object]$MaxTotalSizeMB = $null,
        [int]$KeepLatestN = 1
    )

    if ($MaxAgeDays -lt 0) {
        throw "MaxAgeDays must be a positive integer. Got: $MaxAgeDays"
    }
    if ($KeepLatestN -lt 0) {
        throw "KeepLatestN must be a non-negative integer. Got: $KeepLatestN"
    }
    if ($null -ne $MaxTotalSizeMB -and $MaxTotalSizeMB -lt 0) {
        throw "MaxTotalSizeMB must be a positive number. Got: $MaxTotalSizeMB"
    }

    [PSCustomObject]@{
        MaxAgeDays     = $MaxAgeDays
        MaxTotalSizeMB = $MaxTotalSizeMB
        KeepLatestN    = $KeepLatestN
    }
}

function Get-DeletionPlan {
    <#
    .SYNOPSIS
        Evaluates artifacts against a retention policy and produces a deletion plan.

    .DESCRIPTION
        Policy evaluation order:
          1. KeepLatestN — for each WorkflowRunId, the N newest artifacts are protected.
          2. MaxAge      — among unprotected artifacts, any older than MaxAgeDays is marked for deletion.
          3. MaxTotalSize — if remaining retained set exceeds MaxTotalSizeMB, the oldest
                           unprotected artifacts are trimmed until under budget.

        KeepLatestN is always enforced, even if it means exceeding the size budget.

    .PARAMETER Artifacts
        Array of artifact objects with Name, SizeMB, CreatedDate, WorkflowRunId properties.
    .PARAMETER Policy
        A retention policy object from New-RetentionPolicy.
    .PARAMETER ReferenceDate
        The "now" timestamp used for age calculations. Defaults to current time.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [object]$Policy,

        [datetime]$ReferenceDate = (Get-Date)
    )

    if ($null -eq $Artifacts -or $Artifacts.Count -eq 0) {
        return [PSCustomObject]@{
            ToRetain = @()
            ToDelete = @()
            Summary  = [PSCustomObject]@{
                RetainedCount    = 0
                DeletedCount     = 0
                SpaceReclaimedMB = 0
                RetainedSizeMB   = 0
            }
        }
    }

    # Step 1: Identify protected artifacts (KeepLatestN per workflow).
    # Group by WorkflowRunId, sort each group newest-first, protect the top N.
    $protected = @{}  # key = artifact identity string, value = $true
    $groups = $Artifacts | Group-Object -Property WorkflowRunId
    foreach ($group in $groups) {
        $sorted = $group.Group | Sort-Object -Property CreatedDate -Descending
        $keepCount = [Math]::Min($Policy.KeepLatestN, $sorted.Count)
        for ($i = 0; $i -lt $keepCount; $i++) {
            $key = "$($sorted[$i].WorkflowRunId)|$($sorted[$i].Name)|$($sorted[$i].CreatedDate.Ticks)|$($sorted[$i].SizeMB)"
            $protected[$key] = $true
        }
    }

    # Helper to get an artifact's identity key
    $getKey = {
        param($a)
        "$($a.WorkflowRunId)|$($a.Name)|$($a.CreatedDate.Ticks)|$($a.SizeMB)"
    }

    # Step 2: Apply MaxAge — mark unprotected artifacts older than MaxAgeDays for deletion.
    $toDelete = [System.Collections.Generic.List[object]]::new()
    $toRetain = [System.Collections.Generic.List[object]]::new()

    foreach ($artifact in $Artifacts) {
        $key = & $getKey $artifact
        $ageDays = ($ReferenceDate - $artifact.CreatedDate).TotalDays

        if ($protected.ContainsKey($key)) {
            # Protected by KeepLatestN — always retained
            $toRetain.Add($artifact)
        }
        elseif ($ageDays -gt $Policy.MaxAgeDays) {
            # Too old and unprotected — delete
            $toDelete.Add($artifact)
        }
        else {
            # Within age limit — tentatively retain (may be trimmed by size policy)
            $toRetain.Add($artifact)
        }
    }

    # Step 3: Apply MaxTotalSize — if retained set exceeds budget, trim oldest unprotected.
    if ($null -ne $Policy.MaxTotalSizeMB) {
        $currentSize = ($toRetain | Measure-Object -Property SizeMB -Sum).Sum
        if ($currentSize -gt $Policy.MaxTotalSizeMB) {
            # Sort retained artifacts: unprotected first (candidates), then by age descending (oldest first)
            $retainedWithMeta = $toRetain | ForEach-Object {
                [PSCustomObject]@{
                    Artifact    = $_
                    IsProtected = $protected.ContainsKey((& $getKey $_))
                    AgeDays     = ($ReferenceDate - $_.CreatedDate).TotalDays
                }
            }
            # Candidates for trimming: unprotected, sorted oldest-first
            $candidates = $retainedWithMeta |
                Where-Object { -not $_.IsProtected } |
                Sort-Object -Property AgeDays -Descending

            foreach ($candidate in $candidates) {
                if ($currentSize -le $Policy.MaxTotalSizeMB) { break }
                $currentSize -= $candidate.Artifact.SizeMB
                $toDelete.Add($candidate.Artifact)
                $toRetain.Remove($candidate.Artifact) | Out-Null
            }
        }
    }

    # Build summary
    $deletedSize  = if ($toDelete.Count -gt 0) { ($toDelete | Measure-Object -Property SizeMB -Sum).Sum } else { 0 }
    $retainedSize = if ($toRetain.Count -gt 0) { ($toRetain | Measure-Object -Property SizeMB -Sum).Sum } else { 0 }

    [PSCustomObject]@{
        ToRetain = @($toRetain)
        ToDelete = @($toDelete)
        Summary  = [PSCustomObject]@{
            RetainedCount    = $toRetain.Count
            DeletedCount     = $toDelete.Count
            SpaceReclaimedMB = $deletedSize
            RetainedSizeMB   = $retainedSize
        }
    }
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Orchestrates artifact cleanup: builds a deletion plan and optionally executes it.

    .DESCRIPTION
        In dry-run mode (default), only produces the plan and report without deleting anything.
        When DryRun is $false, calls DeleteAction for each artifact marked for deletion.

    .PARAMETER DeleteAction
        A scriptblock called with each artifact to delete. Allows callers to plug in
        their own deletion logic (e.g., API calls, file removal).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [object]$Policy,

        [switch]$DryRun,

        [scriptblock]$DeleteAction = $null,

        [datetime]$ReferenceDate = (Get-Date)
    )

    $plan = Get-DeletionPlan -Artifacts $Artifacts -Policy $Policy -ReferenceDate $ReferenceDate

    $deletedArtifacts = @()

    if (-not $DryRun -and $plan.ToDelete.Count -gt 0) {
        $deletedList = [System.Collections.Generic.List[object]]::new()
        foreach ($artifact in $plan.ToDelete) {
            try {
                if ($null -ne $DeleteAction) {
                    & $DeleteAction $artifact
                }
                $deletedList.Add($artifact)
            }
            catch {
                Write-Error "Failed to delete artifact '$($artifact.Name)' (workflow $($artifact.WorkflowRunId)): $_"
            }
        }
        $deletedArtifacts = @($deletedList)
    }

    [PSCustomObject]@{
        DryRun           = [bool]$DryRun
        Plan             = $plan
        DeletedArtifacts = $deletedArtifacts
    }
}

function Format-DeletionReport {
    <#
    .SYNOPSIS
        Formats a deletion plan into a human-readable report string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [switch]$DryRun
    )

    $sb = [System.Text.StringBuilder]::new()

    if ($DryRun) {
        [void]$sb.AppendLine("=== ARTIFACT CLEANUP REPORT (DRY RUN) ===")
    }
    else {
        [void]$sb.AppendLine("=== ARTIFACT CLEANUP REPORT ===")
    }
    [void]$sb.AppendLine()

    # Deletion list
    if ($Plan.ToDelete.Count -gt 0) {
        [void]$sb.AppendLine("--- TO DELETE ($($Plan.ToDelete.Count) artifacts) ---")
        foreach ($a in $Plan.ToDelete) {
            [void]$sb.AppendLine("  DELETE  $($a.Name)  | $($a.SizeMB) MB | Workflow $($a.WorkflowRunId) | Created $($a.CreatedDate.ToString('yyyy-MM-dd'))")
        }
    }
    else {
        [void]$sb.AppendLine("--- No artifacts to delete ---")
    }
    [void]$sb.AppendLine()

    # Retention list
    if ($Plan.ToRetain.Count -gt 0) {
        [void]$sb.AppendLine("--- TO RETAIN ($($Plan.ToRetain.Count) artifacts) ---")
        foreach ($a in $Plan.ToRetain) {
            [void]$sb.AppendLine("  RETAIN  $($a.Name)  | $($a.SizeMB) MB | Workflow $($a.WorkflowRunId) | Created $($a.CreatedDate.ToString('yyyy-MM-dd'))")
        }
    }
    [void]$sb.AppendLine()

    # Summary
    [void]$sb.AppendLine("--- SUMMARY ---")
    [void]$sb.AppendLine("  Artifacts retained:   $($Plan.Summary.RetainedCount)")
    [void]$sb.AppendLine("  Artifacts deleted:    $($Plan.Summary.DeletedCount)")
    [void]$sb.AppendLine("  Space reclaimed:      $($Plan.Summary.SpaceReclaimedMB) MB")
    [void]$sb.AppendLine("  Space retained:       $($Plan.Summary.RetainedSizeMB) MB")

    $sb.ToString()
}
