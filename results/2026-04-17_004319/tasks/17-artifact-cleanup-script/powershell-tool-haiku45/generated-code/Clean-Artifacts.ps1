<#
.SYNOPSIS
Artifact cleanup script with retention policies and dry-run support.

.DESCRIPTION
Manages artifacts based on retention policies:
- Max age: delete artifacts older than N days
- Max total size: delete oldest artifacts until under limit
- Keep latest N per workflow: ensure at least N recent artifacts per workflow

.PARAMETER Artifacts
Array of artifact objects with properties: Name, Size, CreatedAt, WorkflowId

.PARAMETER MaxAgeDays
Maximum age in days. Artifacts older are marked for deletion.

.PARAMETER MaxTotalSizeMB
Maximum total size in MB. Oldest artifacts deleted until under limit.

.PARAMETER KeepLatestPerWorkflow
Minimum number of recent artifacts to retain per workflow.

.PARAMETER DryRun
If $true, generate plan but don't delete. Default: $true

.EXAMPLE
$artifacts = @(
    @{ Name = "build-1"; Size = 100; CreatedAt = (Get-Date).AddDays(-15); WorkflowId = "main" }
)
$plan = Invoke-CleanupPlan -Artifacts $artifacts -MaxAgeDays 7 -MaxTotalSizeMB 500
#>

function Invoke-CleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Artifacts,

        [Parameter(Mandatory = $false)]
        [int]$MaxAgeDays = 30,

        [Parameter(Mandatory = $false)]
        [int]$MaxTotalSizeMB = 1000,

        [Parameter(Mandatory = $false)]
        [int]$KeepLatestPerWorkflow = 3
    )

    $now = Get-Date
    $toDelete = @()
    $toKeep = @()

    # Apply max age policy
    $byAge = @{
        Delete = @()
        Keep = @()
    }

    foreach ($artifact in $Artifacts) {
        if (($now - $artifact.CreatedAt).Days -gt $MaxAgeDays) {
            $byAge.Delete += $artifact
        }
        else {
            $byAge.Keep += $artifact
        }
    }

    # Apply keep-latest-N per workflow policy
    $byWorkflow = $byAge.Keep | Group-Object WorkflowId
    $afterKeepLatest = @()

    foreach ($wfGroup in $byWorkflow) {
        $sorted = $wfGroup.Group | Sort-Object CreatedAt -Descending
        if ($sorted.Count -gt $KeepLatestPerWorkflow) {
            $keep = $sorted | Select-Object -First $KeepLatestPerWorkflow
            $delete = $sorted | Select-Object -Skip $KeepLatestPerWorkflow
            $toDelete += $delete
            $afterKeepLatest += $keep
        }
        else {
            $afterKeepLatest += $sorted
        }
    }

    $toDelete += $byAge.Delete
    $toKeep = $afterKeepLatest

    # Apply max total size policy
    $totalSize = ($toKeep | Measure-Object -Property Size -Sum).Sum
    if ($totalSize -gt ($MaxTotalSizeMB * 1MB)) {
        # Sort toKeep by creation date (newest first), move excess to delete
        $sorted = $toKeep | Sort-Object CreatedAt
        $excess = @()

        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $totalSize -= $sorted[$i].Size
            $excess += $sorted[$i]

            if ($totalSize -le ($MaxTotalSizeMB * 1MB)) {
                break
            }
        }

        $toDelete += $excess
        $toKeep = $toKeep | Where-Object { $_ -notin $excess }
    }

    $spaceSaved = ($toDelete | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceSaved) {
        $spaceSaved = 0
    }

    return @{
        ToDelete = @($toDelete)
        ToKeep = @($toKeep)
        TotalSpaceReclaimed = $spaceSaved
        DeleteCount = $toDelete.Count
        KeepCount = $toKeep.Count
    }
}

function Format-CleanupSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Plan
    )

    $spaceMB = [math]::Round($Plan.TotalSpaceReclaimed / 1MB, 2)
    $deleteCount = $Plan.ToDelete.Count
    $keepCount = $Plan.ToKeep.Count

    $summary = @"
=== Artifact Cleanup Summary ===
Artifacts to delete: $deleteCount
Artifacts to retain: $keepCount
Space reclaimed: $($spaceMB)MB
"@

    return $summary
}

function Invoke-Cleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Plan,

        [Parameter(Mandatory = $false)]
        [bool]$DryRun = $true
    )

    if ($DryRun) {
        Write-Host "DRY RUN MODE: No artifacts will be deleted"
    }
    else {
        Write-Host "DELETION MODE: Deleting artifacts"
    }

    foreach ($artifact in $Plan.ToDelete) {
        if ($DryRun) {
            Write-Host "[DRY-RUN] Would delete: $($artifact.Name) ($($artifact.Size / 1MB)MB)"
        }
        else {
            Write-Host "Deleting: $($artifact.Name)"
            # In a real scenario, we'd delete the artifact here
            # Remove-Item -Path $artifact.Path -Force
        }
    }

    return $DryRun
}

