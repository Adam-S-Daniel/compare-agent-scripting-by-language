# ArtifactCleanup.psm1
# PowerShell module for applying retention policies to CI/CD artifacts.
# Supports: max age, max total size, keep-latest-N per workflow, dry-run mode.

function Get-ArtifactDeletionPlan {
    <#
    .SYNOPSIS
        Determines which artifacts to delete based on retention policies.
    .PARAMETER Artifacts
        Array of artifact objects with: Name, SizeBytes, CreatedDate, WorkflowRunId
    .PARAMETER MaxAgeDays
        Delete artifacts older than this many days. 0 = no age limit.
    .PARAMETER MaxTotalSizeBytes
        Maximum total size to retain. Oldest artifacts are deleted first to fit.
        0 = no size limit.
    .PARAMETER KeepLatestPerWorkflow
        Keep at least this many of the most recent artifacts per workflow run ID.
        0 = no per-workflow minimum.
    .PARAMETER ReferenceDate
        Date to calculate age against. Defaults to current date.
    .PARAMETER DryRun
        If set, no deletions are performed — plan is generated only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Artifacts,

        [int]$MaxAgeDays = 0,

        [long]$MaxTotalSizeBytes = 0,

        [int]$KeepLatestPerWorkflow = 0,

        [datetime]$ReferenceDate = (Get-Date),

        [switch]$DryRun
    )

    # Validate inputs
    if ($MaxAgeDays -lt 0) {
        throw "MaxAgeDays must be non-negative, got $MaxAgeDays"
    }
    if ($MaxTotalSizeBytes -lt 0) {
        throw "MaxTotalSizeBytes must be non-negative, got $MaxTotalSizeBytes"
    }
    if ($KeepLatestPerWorkflow -lt 0) {
        throw "KeepLatestPerWorkflow must be non-negative, got $KeepLatestPerWorkflow"
    }

    # Track which artifacts are marked for deletion and the reason
    $deletionSet = @{}  # key = artifact Name, value = reason string

    # --- Policy 1: Max Age ---
    if ($MaxAgeDays -gt 0) {
        $cutoffDate = $ReferenceDate.AddDays(-$MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ($a.CreatedDate -lt $cutoffDate) {
                $deletionSet[$a.Name] = "exceeded max age of $MaxAgeDays days"
            }
        }
    }

    # --- Policy 2: Keep-latest-N per workflow ---
    # Protect the N most recent artifacts per WorkflowRunId from deletion,
    # and mark extras for deletion if they aren't already marked by age.
    if ($KeepLatestPerWorkflow -gt 0) {
        $grouped = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($group in $grouped) {
            # Sort descending by date (newest first)
            $sorted = $group.Group | Sort-Object -Property CreatedDate -Descending
            # Mark artifacts beyond the keep count for deletion
            if ($sorted.Count -gt $KeepLatestPerWorkflow) {
                $extras = $sorted | Select-Object -Skip $KeepLatestPerWorkflow
                foreach ($a in $extras) {
                    if (-not $deletionSet.ContainsKey($a.Name)) {
                        $deletionSet[$a.Name] = "exceeds keep-latest-$KeepLatestPerWorkflow for workflow $($a.WorkflowRunId)"
                    }
                }
            }
            # Protect the latest N from age-based deletion
            $protected = $sorted | Select-Object -First $KeepLatestPerWorkflow
            foreach ($a in $protected) {
                if ($deletionSet.ContainsKey($a.Name)) {
                    $deletionSet.Remove($a.Name)
                }
            }
        }
    }

    # --- Policy 3: Max Total Size ---
    # After applying age and per-workflow rules, if the retained set exceeds
    # the size budget, remove oldest retained artifacts until it fits.
    if ($MaxTotalSizeBytes -gt 0) {
        $retained = $Artifacts | Where-Object { -not $deletionSet.ContainsKey($_.Name) }
        $totalRetainedSize = ($retained | Measure-Object -Property SizeBytes -Sum).Sum
        if ($null -eq $totalRetainedSize) { $totalRetainedSize = 0 }

        if ($totalRetainedSize -gt $MaxTotalSizeBytes) {
            # Sort retained by date ascending (oldest first) to trim oldest
            $retainedSorted = $retained | Sort-Object -Property CreatedDate
            foreach ($a in $retainedSorted) {
                if ($totalRetainedSize -le $MaxTotalSizeBytes) { break }
                $deletionSet[$a.Name] = "exceeded max total size budget of $MaxTotalSizeBytes bytes"
                $totalRetainedSize -= $a.SizeBytes
            }
        }
    }

    # Build result lists
    $toDelete = [System.Collections.ArrayList]::new()
    $toRetain = [System.Collections.ArrayList]::new()

    foreach ($a in $Artifacts) {
        if ($deletionSet.ContainsKey($a.Name)) {
            [void]$toDelete.Add([PSCustomObject]@{
                Name          = $a.Name
                SizeBytes     = $a.SizeBytes
                CreatedDate   = $a.CreatedDate
                WorkflowRunId = $a.WorkflowRunId
                Reason        = $deletionSet[$a.Name]
            })
        } else {
            [void]$toRetain.Add([PSCustomObject]@{
                Name          = $a.Name
                SizeBytes     = $a.SizeBytes
                CreatedDate   = $a.CreatedDate
                WorkflowRunId = $a.WorkflowRunId
            })
        }
    }

    $spaceReclaimed = ($toDelete | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }
    $spaceRetained = ($toRetain | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $spaceRetained) { $spaceRetained = 0 }

    return [PSCustomObject]@{
        DryRun          = [bool]$DryRun
        TotalArtifacts  = $Artifacts.Count
        DeleteCount     = $toDelete.Count
        RetainCount     = $toRetain.Count
        SpaceReclaimed  = [long]$spaceReclaimed
        SpaceRetained   = [long]$spaceRetained
        ToDelete        = $toDelete
        ToRetain        = $toRetain
    }
}

function Format-DeletionPlan {
    <#
    .SYNOPSIS
        Formats a deletion plan as human-readable text output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Plan
    )

    $lines = [System.Collections.ArrayList]::new()

    $modeLabel = if ($Plan.DryRun) { "DRY RUN" } else { "LIVE" }
    [void]$lines.Add("=== Artifact Cleanup Plan ($modeLabel) ===")
    [void]$lines.Add("")
    [void]$lines.Add("Total artifacts:  $($Plan.TotalArtifacts)")
    [void]$lines.Add("To delete:        $($Plan.DeleteCount)")
    [void]$lines.Add("To retain:        $($Plan.RetainCount)")
    [void]$lines.Add("Space reclaimed:  $($Plan.SpaceReclaimed) bytes")
    [void]$lines.Add("Space retained:   $($Plan.SpaceRetained) bytes")

    if ($Plan.ToDelete.Count -gt 0) {
        [void]$lines.Add("")
        [void]$lines.Add("--- Artifacts to DELETE ---")
        foreach ($a in $Plan.ToDelete) {
            [void]$lines.Add("  [DELETE] $($a.Name) | $($a.SizeBytes) bytes | $($a.CreatedDate.ToString('yyyy-MM-dd')) | Workflow: $($a.WorkflowRunId) | Reason: $($a.Reason)")
        }
    }

    if ($Plan.ToRetain.Count -gt 0) {
        [void]$lines.Add("")
        [void]$lines.Add("--- Artifacts to RETAIN ---")
        foreach ($a in $Plan.ToRetain) {
            [void]$lines.Add("  [RETAIN] $($a.Name) | $($a.SizeBytes) bytes | $($a.CreatedDate.ToString('yyyy-MM-dd')) | Workflow: $($a.WorkflowRunId)")
        }
    }

    return $lines -join "`n"
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Main entry point: loads artifacts from JSON, applies policies, outputs plan.
    .PARAMETER ArtifactsJsonPath
        Path to a JSON file containing the artifact list.
    .PARAMETER MaxAgeDays
        Max age policy in days. 0 = disabled.
    .PARAMETER MaxTotalSizeBytes
        Max total size policy in bytes. 0 = disabled.
    .PARAMETER KeepLatestPerWorkflow
        Keep-latest-N per workflow policy. 0 = disabled.
    .PARAMETER ReferenceDate
        Date for age calculations. Defaults to today.
    .PARAMETER DryRun
        If set, only generate the plan without performing deletions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtifactsJsonPath,

        [int]$MaxAgeDays = 0,

        [long]$MaxTotalSizeBytes = 0,

        [int]$KeepLatestPerWorkflow = 0,

        [datetime]$ReferenceDate = (Get-Date),

        [switch]$DryRun
    )

    if (-not (Test-Path $ArtifactsJsonPath)) {
        throw "Artifacts JSON file not found: $ArtifactsJsonPath"
    }

    $rawJson = Get-Content -Path $ArtifactsJsonPath -Raw
    $rawArtifacts = $rawJson | ConvertFrom-Json

    # Normalize into objects with typed properties
    $artifacts = foreach ($r in $rawArtifacts) {
        [PSCustomObject]@{
            Name          = [string]$r.Name
            SizeBytes     = [long]$r.SizeBytes
            CreatedDate   = [datetime]$r.CreatedDate
            WorkflowRunId = [string]$r.WorkflowRunId
        }
    }

    $plan = Get-ArtifactDeletionPlan `
        -Artifacts $artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
        -ReferenceDate $ReferenceDate `
        -DryRun:$DryRun

    $output = Format-DeletionPlan -Plan $plan
    Write-Output $output

    return $plan
}

Export-ModuleMember -Function Get-ArtifactDeletionPlan, Format-DeletionPlan, Invoke-ArtifactCleanup
