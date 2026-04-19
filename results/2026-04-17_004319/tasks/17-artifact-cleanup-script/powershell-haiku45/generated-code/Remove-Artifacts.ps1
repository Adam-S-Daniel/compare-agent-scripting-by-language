function Get-DeletionPlan {
    <#
    .SYNOPSIS
    Creates a deletion plan based on retention policies.

    .PARAMETER Artifacts
    Array of artifact objects with Name, Size, CreatedDate, and WorkflowRunId properties.

    .PARAMETER MaxAgeInDays
    Delete artifacts older than this many days.

    .PARAMETER MaxTotalSizeInMB
    Delete oldest artifacts until total size is below this limit (in MB).

    .PARAMETER KeepLatestN
    Keep only the N most recent artifacts per workflow.

    .OUTPUTS
    PSCustomObject with properties: ToDelete, ToRetain, SpaceReclaimedMB, RetainedCount, DeletedCount
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [int]$MaxAgeInDays = [int]::MaxValue,
        [double]$MaxTotalSizeInMB = [double]::MaxValue,
        [int]$KeepLatestN = [int]::MaxValue
    )

    # Validate inputs
    if ($null -eq $Artifacts) {
        throw "Artifacts cannot be null"
    }
    if ($MaxAgeInDays -lt 0) {
        throw "MaxAgeInDays must be non-negative"
    }
    if ($MaxTotalSizeInMB -le 0 -and $MaxTotalSizeInMB -ne [double]::MaxValue) {
        throw "MaxTotalSizeInMB must be positive"
    }
    if ($KeepLatestN -lt 1 -and $KeepLatestN -ne [int]::MaxValue) {
        throw "KeepLatestN must be at least 1"
    }

    $now = Get-Date
    $toDelete = @()
    $toRetain = @()

    # Handle empty artifacts
    if ($Artifacts.Count -eq 0) {
        return @{
            ToDelete         = @()
            ToRetain         = @()
            SpaceReclaimedMB = 0
            RetainedCount    = 0
            DeletedCount     = 0
        }
    }

    # Convert to array if single object
    if ($Artifacts -is [object] -and $Artifacts -isnot [array]) {
        $Artifacts = @($Artifacts)
    }

    # Apply policies: start with all artifacts as candidates to retain
    $candidates = $Artifacts | ForEach-Object {
        $_ | Add-Member -NotePropertyName AgeInDays -NotePropertyValue (($now - $_.CreatedDate).Days) -PassThru
    }

    # Policy 1: Max age
    if ($MaxAgeInDays -lt [int]::MaxValue) {
        $candidates | ForEach-Object {
            if ($_.AgeInDays -gt $MaxAgeInDays) {
                $toDelete += $_
            } else {
                $toRetain += $_
            }
        }
    } else {
        $toRetain = $candidates
    }

    # Policy 2: Max total size (sizes are in KB) - keep newest artifacts
    if ($MaxTotalSizeInMB -lt [double]::MaxValue) {
        $toDelete = @()
        $toRetain = @()

        # Sort by age ascending (newest first, smallest age first) to keep recent artifacts
        $sorted = $candidates | Sort-Object -Property AgeInDays

        $currentSizeMB = 0
        $sorted | ForEach-Object {
            $sizeInMB = $_.Size / 1024
            if ($currentSizeMB + $sizeInMB -le $MaxTotalSizeInMB) {
                $currentSizeMB += $sizeInMB
                $toRetain += $_
            } else {
                $toDelete += $_
            }
        }
    }

    # Policy 3: Keep latest N per workflow
    if ($KeepLatestN -lt [int]::MaxValue) {
        $toDelete = @()
        $toRetain = @()

        $grouped = $candidates | Group-Object -Property WorkflowRunId

        $grouped | ForEach-Object {
            $workflowArtifacts = $_.Group | Sort-Object -Property CreatedDate -Descending
            $workflowArtifacts | ForEach-Object -Begin { $count = 0 } {
                $count++
                if ($count -le $KeepLatestN) {
                    $toRetain += $_
                } else {
                    $toDelete += $_
                }
            }
        }
    }

    # Calculate space reclaimed (sizes are in KB, convert to MB)
    $spaceReclaimedKB = ($toDelete | Measure-Object -Property Size -Sum).Sum
    $spaceReclaimedMB = if ($spaceReclaimedKB) { $spaceReclaimedKB / 1024 } else { 0 }

    return @{
        ToDelete         = $toDelete
        ToRetain         = $toRetain
        SpaceReclaimedMB = [double]$spaceReclaimedMB
        RetainedCount    = $toRetain.Count
        DeletedCount     = $toDelete.Count
    }
}

function Invoke-CleanupPlan {
    <#
    .SYNOPSIS
    Executes a deletion plan.

    .PARAMETER Plan
    The deletion plan object from Get-DeletionPlan.

    .PARAMETER DryRun
    If true, does not actually delete, but reports what would be deleted.

    .OUTPUTS
    PSCustomObject with execution results.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Plan,

        [switch]$DryRun
    )

    if ($DryRun) {
        return @{
            ExecutedCount    = 0
            WouldDeleteCount = $Plan.DeletedCount
            DryRunMode       = $true
        }
    }

    # In real execution, delete files here
    return @{
        ExecutedCount    = $Plan.DeletedCount
        WouldDeleteCount = 0
        DryRunMode       = $false
    }
}

function Format-DeletionSummary {
    <#
    .SYNOPSIS
    Formats the deletion plan into a human-readable summary.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Plan
    )

    $summary = @"
Artifact Cleanup Summary
========================
Artifacts to delete: $($Plan.DeletedCount)
Artifacts to retain: $($Plan.RetainedCount)
Space to reclaim:   $([Math]::Round($Plan.SpaceReclaimedMB, 2)) MB
"@

    return $summary
}
