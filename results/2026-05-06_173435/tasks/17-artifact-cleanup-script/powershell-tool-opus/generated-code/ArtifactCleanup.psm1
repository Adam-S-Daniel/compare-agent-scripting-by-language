# Artifact cleanup module: functions for parsing artifacts, applying retention
# policies, and generating deletion plans.

function ConvertTo-ArtifactList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    try {
        $raw = $Json | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse artifact JSON: $($_.Exception.Message)"
    }

    if ($null -eq $raw) { return }

    foreach ($item in @($raw)) {
        foreach ($field in @('Name', 'SizeBytes', 'CreatedDate', 'WorkflowRunId')) {
            if (-not $item.PSObject.Properties[$field]) {
                throw "Artifact missing required field '$field': $($item | ConvertTo-Json -Compress)"
            }
        }
        [PSCustomObject]@{
            Name          = [string]$item.Name
            SizeBytes     = [int64]$item.SizeBytes
            CreatedDate   = [datetime]$item.CreatedDate
            WorkflowRunId = [string]$item.WorkflowRunId
        }
    }
}

function New-RetentionPolicy {
    [CmdletBinding()]
    param(
        [ValidateRange(0, [int]::MaxValue)]
        [int]$MaxAgeDays = 0,

        [ValidateRange(0, [int64]::MaxValue)]
        [int64]$MaxTotalSizeBytes = 0,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$KeepLatestNPerWorkflow = 0
    )

    return [PSCustomObject]@{
        MaxAgeDays             = $MaxAgeDays
        MaxTotalSizeBytes      = $MaxTotalSizeBytes
        KeepLatestNPerWorkflow = $KeepLatestNPerWorkflow
    }
}

function Get-DeletionPlan {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$Artifacts = @(),

        [Parameter(Mandatory)]
        [object]$Policy,

        [datetime]$ReferenceDate = (Get-Date),

        [switch]$DryRun
    )

    $mode = if ($DryRun) { "DRY-RUN" } else { "LIVE" }

    # Normalize: ensure we have a proper array (handles $null from empty pipeline)
    if ($null -eq $Artifacts) { $Artifacts = @() }
    $Artifacts = @($Artifacts)

    if ($Artifacts.Count -eq 0) {
        return [PSCustomObject]@{
            Mode              = $mode
            ReferenceDate     = $ReferenceDate
            TotalArtifacts    = 0
            DeletedCount      = 0
            RetainedCount     = 0
            SpaceReclaimed    = [int64]0
            SpaceRetained     = [int64]0
            DeletedArtifacts  = @()
            RetainedArtifacts = @()
        }
    }

    $toDelete = @{}
    $retained = [ordered]@{}

    foreach ($a in $Artifacts) {
        $retained[$a.Name] = $a
    }

    # Pass 1: Remove artifacts exceeding max age
    if ($Policy.MaxAgeDays -gt 0) {
        $cutoff = $ReferenceDate.AddDays(-$Policy.MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ([datetime]$a.CreatedDate -lt $cutoff) {
                $ageDays = [math]::Floor(($ReferenceDate - [datetime]$a.CreatedDate).TotalDays)
                $toDelete[$a.Name] = "exceeded max age of $($Policy.MaxAgeDays) days ($ageDays days old)"
                $retained.Remove($a.Name)
            }
        }
    }

    # Pass 2: Keep only latest N per workflow
    if ($Policy.KeepLatestNPerWorkflow -gt 0) {
        $byWorkflow = @{}
        foreach ($a in @($retained.Values)) {
            $wfId = [string]$a.WorkflowRunId
            if (-not $byWorkflow.ContainsKey($wfId)) {
                $byWorkflow[$wfId] = [System.Collections.Generic.List[object]]::new()
            }
            $byWorkflow[$wfId].Add($a)
        }
        foreach ($wfId in @($byWorkflow.Keys)) {
            $sorted = @($byWorkflow[$wfId] | Sort-Object -Property CreatedDate -Descending)
            if ($sorted.Count -gt $Policy.KeepLatestNPerWorkflow) {
                $toRemove = @($sorted) | Select-Object -Skip $Policy.KeepLatestNPerWorkflow
                foreach ($a in @($toRemove)) {
                    $toDelete[$a.Name] = "exceeded keep-latest-$($Policy.KeepLatestNPerWorkflow) per workflow '$($a.WorkflowRunId)'"
                    $retained.Remove($a.Name)
                }
            }
        }
    }

    # Pass 3: Enforce max total size by removing oldest retained artifacts
    if ($Policy.MaxTotalSizeBytes -gt 0) {
        $retainedValues = @($retained.Values)
        if ($retainedValues.Count -gt 0) {
            $totalSize = ($retainedValues | Measure-Object -Property SizeBytes -Sum).Sum
            if ($null -eq $totalSize) { $totalSize = 0 }
            if ($totalSize -gt $Policy.MaxTotalSizeBytes) {
                $sortedByDate = $retainedValues | Sort-Object -Property CreatedDate
                foreach ($a in @($sortedByDate)) {
                    if ($totalSize -le $Policy.MaxTotalSizeBytes) { break }
                    $sizeMB = [math]::Round($Policy.MaxTotalSizeBytes / 1MB)
                    $toDelete[$a.Name] = "exceeded max total size of $sizeMB MB"
                    $retained.Remove($a.Name)
                    $totalSize -= $a.SizeBytes
                }
            }
        }
    }

    # Build result arrays sorted by name for deterministic output
    $deletedArtifacts = @()
    $retainedArtifacts = @()

    foreach ($a in ($Artifacts | Sort-Object -Property Name)) {
        if ($toDelete.ContainsKey($a.Name)) {
            $deletedArtifacts += [PSCustomObject]@{
                Name          = $a.Name
                SizeBytes     = $a.SizeBytes
                CreatedDate   = $a.CreatedDate
                WorkflowRunId = $a.WorkflowRunId
                Reason        = $toDelete[$a.Name]
            }
        }
        else {
            $retainedArtifacts += [PSCustomObject]@{
                Name          = $a.Name
                SizeBytes     = $a.SizeBytes
                CreatedDate   = $a.CreatedDate
                WorkflowRunId = $a.WorkflowRunId
            }
        }
    }

    $spaceReclaimed = ($deletedArtifacts | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }
    $spaceRetained = ($retainedArtifacts | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $spaceRetained) { $spaceRetained = 0 }

    return [PSCustomObject]@{
        Mode              = $mode
        ReferenceDate     = $ReferenceDate
        TotalArtifacts    = $Artifacts.Count
        DeletedCount      = $deletedArtifacts.Count
        RetainedCount     = $retainedArtifacts.Count
        SpaceReclaimed    = [int64]$spaceReclaimed
        SpaceRetained     = [int64]$spaceRetained
        DeletedArtifacts  = $deletedArtifacts
        RetainedArtifacts = $retainedArtifacts
    }
}

function Format-CleanupSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("=== ARTIFACT CLEANUP PLAN ===")
    $lines.Add("Mode: $($Plan.Mode)")
    $lines.Add("Reference Date: $($Plan.ReferenceDate.ToString('yyyy-MM-dd'))")
    $lines.Add("")

    $lines.Add("--- ARTIFACTS TO DELETE ---")
    if ($Plan.DeletedArtifacts.Count -eq 0) {
        $lines.Add("(none)")
    }
    else {
        foreach ($a in $Plan.DeletedArtifacts) {
            $sizeMB = [math]::Round($a.SizeBytes / 1MB, 2)
            $lines.Add("$($a.Name) | $($a.SizeBytes) bytes ($sizeMB MB) | $($a.CreatedDate.ToString('yyyy-MM-dd')) | $($a.Reason)")
        }
    }
    $lines.Add("")

    $lines.Add("--- ARTIFACTS TO RETAIN ---")
    if ($Plan.RetainedArtifacts.Count -eq 0) {
        $lines.Add("(none)")
    }
    else {
        foreach ($a in $Plan.RetainedArtifacts) {
            $sizeMB = [math]::Round($a.SizeBytes / 1MB, 2)
            $lines.Add("$($a.Name) | $($a.SizeBytes) bytes ($sizeMB MB) | $($a.CreatedDate.ToString('yyyy-MM-dd'))")
        }
    }
    $lines.Add("")

    $reclaimedMB = [math]::Round($Plan.SpaceReclaimed / 1MB, 2)
    $retainedMB = [math]::Round($Plan.SpaceRetained / 1MB, 2)

    $lines.Add("--- SUMMARY ---")
    $lines.Add("Total artifacts: $($Plan.TotalArtifacts)")
    $lines.Add("Artifacts to delete: $($Plan.DeletedCount)")
    $lines.Add("Artifacts to retain: $($Plan.RetainedCount)")
    $lines.Add("Space to reclaim: $($Plan.SpaceReclaimed) bytes ($reclaimedMB MB)")
    $lines.Add("Space retained: $($Plan.SpaceRetained) bytes ($retainedMB MB)")
    $lines.Add("===========================")

    return ($lines -join "`n")
}

Export-ModuleMember -Function ConvertTo-ArtifactList, New-RetentionPolicy, Get-DeletionPlan, Format-CleanupSummary
