# Artifact Cleanup Script with Retention Policies
# Applies multiple retention policies to determine which artifacts to delete
# Supports dry-run mode for safe testing

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
    Applies retention policies to artifacts and generates a deletion plan.

    .DESCRIPTION
    This function analyzes artifacts against multiple retention policies:
    - Maximum age (delete artifacts older than N days)
    - Maximum total size (keep newest artifacts until under size limit)
    - Keep latest N per workflow (retain only most recent N per workflow ID)

    Returns a deletion plan with summary statistics.

    .PARAMETER Artifacts
    Array of artifact objects with properties: Name, Size (MB), CreatedDate, WorkflowRunId

    .PARAMETER MaxAgeInDays
    Delete artifacts older than this many days

    .PARAMETER MaxTotalSizeInMB
    Maximum total size to retain; oldest artifacts are deleted to stay under this

    .PARAMETER KeepLatestPerWorkflow
    Retain only this many newest artifacts per workflow ID

    .PARAMETER DryRun
    If true, generate plan but don't delete (always false in this version - plan only)

    .EXAMPLE
    $artifacts = @(
        @{ Name = "build-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run1" }
    )
    $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 2
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts = @(),

        [Parameter(Mandatory = $true)]
        [int]$MaxAgeInDays,

        [Parameter(Mandatory = $true)]
        [int]$MaxTotalSizeInMB,

        [Parameter(Mandatory = $true)]
        [int]$KeepLatestPerWorkflow,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    # Initialize tracking
    $toDelete = @()
    $toRetain = @()
    $now = Get-Date

    # Handle empty input
    if (-not $Artifacts -or $Artifacts.Count -eq 0) {
        return [PSCustomObject]@{
            DeletionPlan = @()
            Summary = [PSCustomObject]@{
                TotalInputArtifacts = 0
                ArtifactsToDelete = 0
                ArtifactsToRetain = 0
                SpaceReclaimedMB = 0
            }
            DryRun = $DryRun.IsPresent
        }
    }

    # Normalize artifacts to ensure consistent object structure
    $normalizedArtifacts = @()
    foreach ($artifact in $Artifacts) {
        $normalizedArtifacts += [PSCustomObject]@{
            Name = $artifact.Name
            Size = [int]$artifact.Size
            CreatedDate = $artifact.CreatedDate -as [datetime]
            WorkflowRunId = $artifact.WorkflowRunId
            MarkedForDeletion = $false
            DeletionReason = ""
        }
    }

    # Apply Policy 1: Maximum Age
    foreach ($artifact in $normalizedArtifacts) {
        $ageInDays = ($now - $artifact.CreatedDate).TotalDays
        if ($ageInDays -gt $MaxAgeInDays) {
            $artifact.MarkedForDeletion = $true
            $artifact.DeletionReason += "Age (${ageInDays:F0} days > $MaxAgeInDays days); "
        }
    }

    # Apply Policy 2: Keep Latest N Per Workflow
    # Group by workflow and mark older ones for deletion if exceeding limit
    $byWorkflow = $normalizedArtifacts | Group-Object -Property WorkflowRunId
    foreach ($workflowGroup in $byWorkflow) {
        if ($workflowGroup.Count -gt $KeepLatestPerWorkflow) {
            # Sort by date, keep latest N
            $sorted = $workflowGroup.Group | Sort-Object -Property CreatedDate -Descending
            $toDeleteInGroup = $sorted | Select-Object -Skip $KeepLatestPerWorkflow

            foreach ($artifact in $toDeleteInGroup) {
                $artifact.MarkedForDeletion = $true
                $artifact.DeletionReason += "Exceeds keep-latest-per-workflow limit ($KeepLatestPerWorkflow); "
            }
        }
    }

    # Apply Policy 3: Maximum Total Size
    # Calculate current size with marked deletions removed
    $retainedArtifacts = $normalizedArtifacts | Where-Object { -not $_.MarkedForDeletion }
    $currentSize = ($retainedArtifacts | Measure-Object -Property Size -Sum).Sum

    if ($currentSize -gt $MaxTotalSizeInMB) {
        # Sort retained artifacts by date (oldest first) and delete oldest until under limit
        $retainedSorted = $retainedArtifacts | Sort-Object -Property CreatedDate

        foreach ($artifact in $retainedSorted) {
            if ($currentSize -le $MaxTotalSizeInMB) {
                break
            }

            # Only delete if not already marked by age policy
            if (-not $artifact.MarkedForDeletion) {
                $artifact.MarkedForDeletion = $true
                $artifact.DeletionReason += "Total size exceeds limit (${currentSize} MB > $MaxTotalSizeInMB MB); "
                $currentSize -= $artifact.Size
            }
        }
    }

    # Separate marked artifacts from those to retain
    $deletionPlan = @($normalizedArtifacts | Where-Object { $_.MarkedForDeletion })
    $retained = @($normalizedArtifacts | Where-Object { -not $_.MarkedForDeletion })

    # Calculate summary
    $spaceReclaimed = ($deletionPlan | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }

    # Return result object
    return [PSCustomObject]@{
        DeletionPlan = @($deletionPlan | Select-Object -Property Name, Size, CreatedDate, WorkflowRunId, DeletionReason)
        Summary = [PSCustomObject]@{
            TotalInputArtifacts = $normalizedArtifacts.Count
            ArtifactsToDelete = $deletionPlan.Count
            ArtifactsToRetain = $retained.Count
            SpaceReclaimedMB = $spaceReclaimed
        }
        DryRun = $DryRun.IsPresent
    }
}
