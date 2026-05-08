# ArtifactCleanup.psm1
# Core retention-policy functions for artifact cleanup.
# Exported for direct use in ArtifactCleanup.ps1 and for Pester testing.

# ─── FILE I/O ────────────────────────────────────────────────────────────────

function Get-ArtifactsFromFile {
    <#
    .SYNOPSIS Reads an artifacts JSON file and returns typed objects.
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Artifacts file not found: $Path"
    }

    $raw = Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json

    foreach ($artifact in $raw) {
        # Ensure createdDate is a [datetime] regardless of JSON parser version
        if ($artifact.createdDate -isnot [datetime]) {
            $artifact | Add-Member -MemberType NoteProperty -Name createdDate `
                -Value ([datetime]::Parse($artifact.createdDate)) -Force
        }
    }

    return $raw
}

function Get-PolicyFromFile {
    <#
    .SYNOPSIS Reads a retention-policy JSON file.
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Policy file not found: $Path"
    }

    return Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json
}

# ─── POLICY EVALUATION ───────────────────────────────────────────────────────

function Get-ArtifactsToDelete {
    <#
    .SYNOPSIS
        Applies retention policies to a list of artifacts.

    .DESCRIPTION
        Evaluates three policies independently and unions the results:
          1. maxAgeDays       – delete any artifact older than N days
          2. keepLatestN      – per workflow, keep only the N most recent
          3. maxTotalSizeMB   – after age/keepLatestN, delete oldest until
                                remaining total is within the size cap

        Returns a hashtable:
          ToDelete  – array of @{Artifact=...; Reason=...} decision objects
    #>
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][object]$Policy,
        [Parameter(Mandatory)][datetime]$ReferenceDate
    )

    # Track deletions as a name->reason hashtable to avoid duplicates
    $deletionMap = @{}

    # 1. Max-age policy
    if ($null -ne $Policy.maxAgeDays) {
        foreach ($artifact in $Artifacts) {
            $ageDays = ($ReferenceDate.Date - $artifact.createdDate.Date).Days
            if ($ageDays -gt $Policy.maxAgeDays) {
                $deletionMap[$artifact.name] = "exceeded max age ($ageDays days > $($Policy.maxAgeDays) days)"
            }
        }
    }

    # 2. Keep-latest-N policy (per workflow)
    if ($null -ne $Policy.keepLatestNPerWorkflow) {
        $byWorkflow = $Artifacts | Group-Object -Property workflowRunId
        foreach ($group in $byWorkflow) {
            $sorted = $group.Group | Sort-Object -Property createdDate -Descending
            if ($sorted.Count -gt $Policy.keepLatestNPerWorkflow) {
                $excess = $sorted | Select-Object -Skip $Policy.keepLatestNPerWorkflow
                foreach ($artifact in $excess) {
                    if (-not $deletionMap.ContainsKey($artifact.name)) {
                        $deletionMap[$artifact.name] = "exceeds keep-latest-$($Policy.keepLatestNPerWorkflow) for workflow '$($artifact.workflowRunId)'"
                    }
                }
            }
        }
    }

    # 3. Max-total-size policy (applied to artifacts not yet marked for deletion)
    if ($null -ne $Policy.maxTotalSizeMB) {
        $remaining = $Artifacts | Where-Object { -not $deletionMap.ContainsKey($_.name) }
        $totalMB   = ($remaining | Measure-Object -Property sizeMB -Sum).Sum
        if ($totalMB -gt $Policy.maxTotalSizeMB) {
            # Delete oldest first until within limit
            $sorted = $remaining | Sort-Object -Property createdDate
            foreach ($artifact in $sorted) {
                if ($totalMB -le $Policy.maxTotalSizeMB) { break }
                $deletionMap[$artifact.name] = "total size ($([math]::Round($totalMB,2)) MB) exceeds max $($Policy.maxTotalSizeMB) MB"
                $totalMB -= $artifact.sizeMB
            }
        }
    }

    # Build the structured decision list
    $toDelete = foreach ($artifact in $Artifacts) {
        if ($deletionMap.ContainsKey($artifact.name)) {
            [PSCustomObject]@{
                Artifact = $artifact
                Reason   = $deletionMap[$artifact.name]
            }
        }
    }

    return @{
        ToDelete = @($toDelete)
    }
}

# ─── DELETION PLAN ───────────────────────────────────────────────────────────

function New-DeletionPlan {
    <#
    .SYNOPSIS Assembles a structured deletion plan object from the policy results.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][object[]]$DeletionDecisions,
        [switch]$DryRun
    )

    $deleteNames  = $DeletionDecisions | ForEach-Object { $_.Artifact.name }
    $retained     = $Artifacts | Where-Object { $deleteNames -notcontains $_.name }
    $spaceReclaim = ($DeletionDecisions | Measure-Object -Property { $_.Artifact.sizeMB } -Sum).Sum
    if ($null -eq $spaceReclaim) { $spaceReclaim = 0.0 }

    return [PSCustomObject]@{
        TotalCount        = $Artifacts.Count
        DeleteCount       = $DeletionDecisions.Count
        RetainCount       = @($retained).Count
        SpaceReclaimedMB  = [double]$spaceReclaim
        DeletionDecisions = $DeletionDecisions
        RetainedArtifacts = @($retained)
        IsDryRun          = [bool]$DryRun
    }
}

# ─── OUTPUT FORMATTING ───────────────────────────────────────────────────────

function Format-DeletionPlan {
    <#
    .SYNOPSIS Formats a deletion plan as a human-readable text block.
    #>
    param(
        [Parameter(Mandatory)][object]$Plan
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    $header = if ($Plan.IsDryRun) {
        "=== ARTIFACT CLEANUP PLAN (DRY RUN) ==="
    } else {
        "=== ARTIFACT CLEANUP PLAN ==="
    }
    $lines.Add($header)
    $lines.Add("")

    if ($Plan.DeleteCount -eq 0) {
        $lines.Add("No artifacts meet the deletion criteria.")
    } else {
        $lines.Add("Artifacts to delete ($($Plan.DeleteCount)):")
        foreach ($decision in $Plan.DeletionDecisions) {
            $a = $decision.Artifact
            $lines.Add("  - $($a.name) ($([math]::Round($a.sizeMB,2)) MB, workflow: $($a.workflowRunId))")
            $lines.Add("    Reason: $($decision.Reason)")
        }
    }

    $lines.Add("")
    if ($Plan.RetainCount -eq 0) {
        $lines.Add("Artifacts to retain (0): none")
    } else {
        $lines.Add("Artifacts to retain ($($Plan.RetainCount)):")
        foreach ($a in $Plan.RetainedArtifacts) {
            $lines.Add("  - $($a.name) ($([math]::Round($a.sizeMB,2)) MB, workflow: $($a.workflowRunId))")
        }
    }

    $lines.Add("")
    $lines.Add("Summary:")
    $lines.Add("  Total artifacts processed: $($Plan.TotalCount)")
    $lines.Add("  Artifacts to delete: $($Plan.DeleteCount)")
    $lines.Add("  Artifacts to retain: $($Plan.RetainCount)")
    $lines.Add("  Space to reclaim: $([math]::Round($Plan.SpaceReclaimedMB,2).ToString('F2')) MB")

    if ($Plan.IsDryRun) {
        $lines.Add("")
        $lines.Add("[DRY RUN] No changes were made.")
    }

    return $lines -join "`n"
}

Export-ModuleMember -Function `
    Get-ArtifactsFromFile, `
    Get-PolicyFromFile, `
    Get-ArtifactsToDelete, `
    New-DeletionPlan, `
    Format-DeletionPlan
