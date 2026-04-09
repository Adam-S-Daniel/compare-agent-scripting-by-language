<#
.SYNOPSIS
    Artifact cleanup script that applies retention policies to a list of artifacts.

.DESCRIPTION
    Given mock artifact metadata (name, size, creation date, workflow run ID),
    applies retention policies:
      - Max age (days): delete artifacts older than N days
      - Max total size (bytes): delete oldest artifacts until total size fits
      - Keep-latest-N per workflow: retain only N most recent artifacts per workflow run ID
    Generates a deletion plan with summary (space reclaimed, retained vs deleted).
    Supports dry-run mode.

.PARAMETER ArtifactsJson
    JSON string containing an array of artifact objects with keys:
    name, size, createdAt, workflowRunId

.PARAMETER MaxAgeDays
    Maximum age in days. Artifacts older than this are marked for deletion.

.PARAMETER MaxTotalSizeBytes
    Maximum total size in bytes. Oldest artifacts are deleted until the total fits.

.PARAMETER KeepLatestN
    Number of most recent artifacts to keep per workflow run ID.

.PARAMETER DryRun
    If set, outputs the deletion plan without actually deleting anything.

.PARAMETER ReferenceDate
    Optional reference date for age calculations (defaults to current date).
    Useful for deterministic testing.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactsJson,

    [Parameter(Mandatory = $false)]
    [int]$MaxAgeDays = -1,

    [Parameter(Mandatory = $false)]
    [long]$MaxTotalSizeBytes = -1,

    [Parameter(Mandatory = $false)]
    [int]$KeepLatestN = -1,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$ReferenceDate = ""
)

# Parse artifacts from JSON input
function Parse-Artifacts {
    param([string]$Json)

    try {
        $parsed = $Json | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse artifacts JSON: $_"
        return @()
    }

    if ($null -eq $parsed) {
        return @()
    }

    # Normalize to array
    if ($parsed -isnot [System.Array]) {
        $parsed = @($parsed)
    }

    # Validate required fields
    $valid = @()
    foreach ($item in $parsed) {
        if (-not $item.name -or -not $item.createdAt -or -not $item.workflowRunId) {
            Write-Warning "Skipping artifact with missing required fields: $($item | ConvertTo-Json -Compress)"
            continue
        }
        if ($null -eq $item.size -or $item.size -lt 0) {
            Write-Warning "Skipping artifact with invalid size: $($item.name)"
            continue
        }
        $valid += [PSCustomObject]@{
            Name          = [string]$item.name
            Size          = [long]$item.size
            CreatedAt     = [datetime]::Parse($item.createdAt)
            WorkflowRunId = [string]$item.workflowRunId
            MarkedForDeletion = $false
            DeletionReason    = ""
        }
    }
    return $valid
}

# Apply max-age policy: mark artifacts older than MaxAgeDays for deletion
function Apply-MaxAgePolicy {
    param(
        [array]$Artifacts,
        [int]$MaxAgeDays,
        [datetime]$ReferenceDate
    )

    if ($MaxAgeDays -lt 0) { return $Artifacts }

    foreach ($artifact in $Artifacts) {
        $age = ($ReferenceDate - $artifact.CreatedAt).TotalDays
        if ($age -gt $MaxAgeDays) {
            $artifact.MarkedForDeletion = $true
            if ($artifact.DeletionReason -eq "") {
                $artifact.DeletionReason = "{0:F1} days old (max: $MaxAgeDays)" -f $age
            }
            else {
                $artifact.DeletionReason += "; {0:F1} days old (max: $MaxAgeDays)" -f $age
            }
        }
    }
    return $Artifacts
}

# Apply keep-latest-N policy: per workflow run ID, keep only N most recent
function Apply-KeepLatestNPolicy {
    param(
        [array]$Artifacts,
        [int]$KeepLatestN
    )

    if ($KeepLatestN -lt 0) { return $Artifacts }

    # Group by workflow run ID
    $groups = $Artifacts | Group-Object -Property WorkflowRunId

    foreach ($group in $groups) {
        # Sort by creation date descending (newest first)
        $sorted = $group.Group | Sort-Object -Property CreatedAt -Descending
        $count = 0
        foreach ($artifact in $sorted) {
            $count++
            if ($count -gt $KeepLatestN) {
                $artifact.MarkedForDeletion = $true
                if ($artifact.DeletionReason -eq "") {
                    $artifact.DeletionReason = "Exceeds keep-latest-$KeepLatestN for workflow $($artifact.WorkflowRunId)"
                }
                else {
                    $artifact.DeletionReason += "; exceeds keep-latest-$KeepLatestN for workflow $($artifact.WorkflowRunId)"
                }
            }
        }
    }
    return $Artifacts
}

# Apply max-total-size policy: delete oldest artifacts until total size fits
function Apply-MaxTotalSizePolicy {
    param(
        [array]$Artifacts,
        [long]$MaxTotalSizeBytes
    )

    if ($MaxTotalSizeBytes -lt 0) { return $Artifacts }

    # Calculate current total size of non-deleted artifacts
    $currentSize = ($Artifacts | Where-Object { -not $_.MarkedForDeletion } | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $currentSize) { $currentSize = 0 }

    if ($currentSize -le $MaxTotalSizeBytes) { return $Artifacts }

    # Sort non-deleted artifacts by creation date ascending (oldest first) for eviction
    $candidates = $Artifacts | Where-Object { -not $_.MarkedForDeletion } | Sort-Object -Property CreatedAt

    foreach ($artifact in $candidates) {
        if ($currentSize -le $MaxTotalSizeBytes) { break }
        $artifact.MarkedForDeletion = $true
        if ($artifact.DeletionReason -eq "") {
            $artifact.DeletionReason = "Total size $currentSize exceeds max $MaxTotalSizeBytes"
        }
        else {
            $artifact.DeletionReason += "; total size exceeds max $MaxTotalSizeBytes"
        }
        $currentSize -= $artifact.Size
    }
    return $Artifacts
}

# Generate the deletion plan summary
function Get-DeletionPlan {
    param([array]$Artifacts, [bool]$IsDryRun)

    $toDelete = @($Artifacts | Where-Object { $_.MarkedForDeletion })
    $toRetain = @($Artifacts | Where-Object { -not $_.MarkedForDeletion })

    $spaceReclaimed = ($toDelete | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceReclaimed) { $spaceReclaimed = 0 }

    $spaceRetained = ($toRetain | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $spaceRetained) { $spaceRetained = 0 }

    $plan = [PSCustomObject]@{
        DryRun          = $IsDryRun
        TotalArtifacts  = $Artifacts.Count
        ArtifactsToDelete = $toDelete.Count
        ArtifactsToRetain = $toRetain.Count
        SpaceReclaimed  = [long]$spaceReclaimed
        SpaceRetained   = [long]$spaceRetained
        DeletedArtifacts = $toDelete | ForEach-Object {
            [PSCustomObject]@{
                Name          = $_.Name
                Size          = $_.Size
                CreatedAt     = $_.CreatedAt.ToString("yyyy-MM-dd")
                WorkflowRunId = $_.WorkflowRunId
                Reason        = $_.DeletionReason
            }
        }
        RetainedArtifacts = $toRetain | ForEach-Object {
            [PSCustomObject]@{
                Name          = $_.Name
                Size          = $_.Size
                CreatedAt     = $_.CreatedAt.ToString("yyyy-MM-dd")
                WorkflowRunId = $_.WorkflowRunId
            }
        }
    }
    return $plan
}

# --- Main execution ---

# Determine reference date
if ($ReferenceDate -ne "") {
    try {
        $refDate = [datetime]::Parse($ReferenceDate)
    }
    catch {
        Write-Error "Invalid ReferenceDate: $ReferenceDate"
        exit 1
    }
}
else {
    $refDate = Get-Date
}

# Parse input
$artifacts = Parse-Artifacts -Json $ArtifactsJson
if ($artifacts.Count -eq 0) {
    Write-Output "No valid artifacts to process."
    $emptyPlan = [PSCustomObject]@{
        DryRun = [bool]$DryRun
        TotalArtifacts = 0
        ArtifactsToDelete = 0
        ArtifactsToRetain = 0
        SpaceReclaimed = 0
        SpaceRetained = 0
        DeletedArtifacts = @()
        RetainedArtifacts = @()
    }
    Write-Output "JSON_PLAN_START"
    $emptyPlan | ConvertTo-Json -Depth 5
    Write-Output "JSON_PLAN_END"
    exit 0
}

# Apply policies in order: max-age, keep-latest-N, then max-total-size
$artifacts = Apply-MaxAgePolicy -Artifacts $artifacts -MaxAgeDays $MaxAgeDays -ReferenceDate $refDate
$artifacts = Apply-KeepLatestNPolicy -Artifacts $artifacts -KeepLatestN $KeepLatestN
$artifacts = Apply-MaxTotalSizePolicy -Artifacts $artifacts -MaxTotalSizeBytes $MaxTotalSizeBytes

# Generate and output the deletion plan
$plan = Get-DeletionPlan -Artifacts $artifacts -IsDryRun ([bool]$DryRun)

if ($DryRun) {
    Write-Output "=== DRY RUN MODE ==="
}
else {
    Write-Output "=== EXECUTION MODE ==="
}

Write-Output "Deletion Plan Summary:"
Write-Output "  Total artifacts: $($plan.TotalArtifacts)"
Write-Output "  To delete: $($plan.ArtifactsToDelete)"
Write-Output "  To retain: $($plan.ArtifactsToRetain)"
Write-Output "  Space reclaimed: $($plan.SpaceReclaimed) bytes"
Write-Output "  Space retained: $($plan.SpaceRetained) bytes"

if ($plan.ArtifactsToDelete -gt 0) {
    Write-Output ""
    Write-Output "Artifacts to delete:"
    foreach ($a in $plan.DeletedArtifacts) {
        Write-Output "  - $($a.Name) (size: $($a.Size), created: $($a.CreatedAt), workflow: $($a.WorkflowRunId)) — Reason: $($a.Reason)"
    }
}

if ($plan.ArtifactsToRetain -gt 0) {
    Write-Output ""
    Write-Output "Artifacts retained:"
    foreach ($a in $plan.RetainedArtifacts) {
        Write-Output "  - $($a.Name) (size: $($a.Size), created: $($a.CreatedAt), workflow: $($a.WorkflowRunId))"
    }
}

Write-Output ""
Write-Output "JSON_PLAN_START"
$plan | ConvertTo-Json -Depth 5
Write-Output "JSON_PLAN_END"
