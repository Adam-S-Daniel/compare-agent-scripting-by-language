# Artifact cleanup script: applies retention policies to a list of artifacts
# and produces a deletion plan with summary statistics.

param(
    [Parameter(Mandatory = $false)]
    [string]$ArtifactJson,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactFile,

    [Parameter(Mandatory = $false)]
    [int]$MaxAgeDays = -1,

    [Parameter(Mandatory = $false)]
    [long]$MaxTotalSizeBytes = -1,

    [Parameter(Mandatory = $false)]
    [int]$KeepLatestN = -1,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [datetime]$ReferenceDate
)

function Get-DeletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Artifacts,

        [int]$MaxAgeDays = -1,

        [long]$MaxTotalSizeBytes = -1,

        [int]$KeepLatestN = -1,

        [bool]$DryRun = $false,

        [datetime]$ReferenceDate = (Get-Date)
    )

    if ($Artifacts.Count -eq 0) {
        return @{
            ToDelete       = @()
            ToRetain       = @()
            SpaceReclaimed = 0
            SpaceRetained  = 0
            DryRun         = $DryRun
            Summary        = "No artifacts to process."
        }
    }

    # Validate artifact structure
    foreach ($art in $Artifacts) {
        if (-not $art.Name -or -not $art.PSObject.Properties['Size'] -or
            -not $art.CreationDate -or -not $art.WorkflowRunId) {
            throw "Invalid artifact: each artifact must have Name, Size, CreationDate, and WorkflowRunId properties."
        }
    }

    # Normalize artifacts: parse dates and ensure numeric sizes
    $normalized = $Artifacts | ForEach-Object {
        [PSCustomObject]@{
            Name          = $_.Name
            Size          = [long]$_.Size
            CreationDate  = [datetime]$_.CreationDate
            WorkflowRunId = [string]$_.WorkflowRunId
            MarkedDelete  = $false
            DeleteReason  = @()
        }
    }

    # Policy 1: Max age — delete artifacts older than MaxAgeDays
    if ($MaxAgeDays -ge 0) {
        $cutoffDate = $ReferenceDate.AddDays(-$MaxAgeDays)
        foreach ($art in $normalized) {
            if ($art.CreationDate -lt $cutoffDate) {
                $art.MarkedDelete = $true
                $art.DeleteReason += "exceeded max age ($MaxAgeDays days)"
            }
        }
    }

    # Policy 2: Keep-latest-N per workflow — within each workflow run ID,
    # keep only the N most recent artifacts
    if ($KeepLatestN -ge 0) {
        $grouped = $normalized | Group-Object -Property WorkflowRunId
        foreach ($group in $grouped) {
            $sorted = $group.Group | Sort-Object -Property CreationDate -Descending
            $toTrim = $sorted | Select-Object -Skip $KeepLatestN
            foreach ($art in $toTrim) {
                if (-not $art.MarkedDelete) {
                    $art.MarkedDelete = $true
                }
                $art.DeleteReason += "exceeded keep-latest-$KeepLatestN per workflow"
            }
        }
    }

    # Policy 3: Max total size — if retained artifacts exceed MaxTotalSizeBytes,
    # delete the oldest retained artifacts first until under the limit
    if ($MaxTotalSizeBytes -ge 0) {
        $retained = $normalized | Where-Object { -not $_.MarkedDelete }
        $totalRetained = ($retained | Measure-Object -Property Size -Sum).Sum
        if ($null -eq $totalRetained) { $totalRetained = 0 }

        if ($totalRetained -gt $MaxTotalSizeBytes) {
            # Sort retained by creation date ascending (oldest first) so we
            # delete the oldest until we're under the limit
            $sortedRetained = $retained | Sort-Object -Property CreationDate
            foreach ($art in $sortedRetained) {
                if ($totalRetained -le $MaxTotalSizeBytes) { break }
                $art.MarkedDelete = $true
                $art.DeleteReason += "exceeded max total size ($MaxTotalSizeBytes bytes)"
                $totalRetained -= $art.Size
            }
        }
    }

    $toDelete = @($normalized | Where-Object { $_.MarkedDelete })
    $toRetain = @($normalized | Where-Object { -not $_.MarkedDelete })

    $spaceReclaimed = ($toDelete | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }

    $spaceRetained = ($toRetain | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceRetained) { $spaceRetained = 0 }

    $modeLabel = if ($DryRun) { "DRY RUN" } else { "LIVE" }
    $summary = @(
        "=== Artifact Cleanup Plan ($modeLabel) ==="
        "Total artifacts: $($normalized.Count)"
        "Artifacts to delete: $($toDelete.Count)"
        "Artifacts to retain: $($toRetain.Count)"
        "Space reclaimed: $spaceReclaimed bytes"
        "Space retained: $spaceRetained bytes"
    ) -join "`n"

    if ($toDelete.Count -gt 0) {
        $deleteDetails = $toDelete | ForEach-Object {
            "  - $($_.Name) ($(($_.DeleteReason -join '; ')))"
        }
        $summary += "`n`nDeletion list:`n" + ($deleteDetails -join "`n")
    }

    if ($toRetain.Count -gt 0) {
        $retainDetails = $toRetain | ForEach-Object {
            "  - $($_.Name)"
        }
        $summary += "`n`nRetained:`n" + ($retainDetails -join "`n")
    }

    return @{
        ToDelete       = $toDelete
        ToRetain       = $toRetain
        SpaceReclaimed = [long]$spaceReclaimed
        SpaceRetained  = [long]$spaceRetained
        DryRun         = $DryRun
        Summary        = $summary
    }
}

# CLI entry point — only runs when the script is invoked directly
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch 'Import-Module|InModuleScope') {
    $artifacts = @()

    if ($ArtifactFile -and (Test-Path $ArtifactFile)) {
        $artifacts = Get-Content $ArtifactFile -Raw | ConvertFrom-Json
    }
    elseif ($ArtifactJson) {
        $artifacts = $ArtifactJson | ConvertFrom-Json
    }
    else {
        Write-Error "Provide either -ArtifactJson or -ArtifactFile with valid artifact data."
        exit 1
    }

    if (-not $ReferenceDate) {
        $ReferenceDate = Get-Date
    }

    $plan = Get-DeletionPlan -Artifacts $artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestN $KeepLatestN `
        -DryRun $DryRun.IsPresent `
        -ReferenceDate $ReferenceDate

    Write-Output $plan.Summary

    if (-not $DryRun -and $plan.ToDelete.Count -gt 0) {
        Write-Output "`n[LIVE MODE] Would execute deletion of $($plan.ToDelete.Count) artifacts."
    }
}
