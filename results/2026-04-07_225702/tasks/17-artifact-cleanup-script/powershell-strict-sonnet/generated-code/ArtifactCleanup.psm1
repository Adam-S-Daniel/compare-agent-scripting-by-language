# ArtifactCleanup.psm1
# Artifact retention policy engine for CI/CD artifact management
#
# Design:
#   Three orthogonal policies are applied independently, then unioned (deduplicated):
#     1. Age policy    — delete anything older than MaxAgeDays
#     2. Size policy   — delete oldest artifacts until total size <= MaxTotalSizeBytes
#     3. Keep-latest   — per workflow run ID, delete all but the N most recent
#
#   New-DeletionPlan combines all three policies and produces a plan object.
#   Format-DeletionPlanSummary renders the plan as a human-readable report.
#   Dry-run mode: the plan is generated but no real deletions occur (the caller
#   decides whether to act on the plan; this module only produces the plan).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Data model helpers
# ---------------------------------------------------------------------------

function New-Artifact {
    <#
    .SYNOPSIS
        Creates a typed artifact record.
    .DESCRIPTION
        Validates inputs and returns a PSCustomObject representing one artifact.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]   $Name,
        [Parameter(Mandatory)][long]     $SizeBytes,
        [Parameter(Mandatory)][datetime] $CreatedAt,
        [Parameter(Mandatory)][string]   $WorkflowRunId
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Artifact name must not be empty."
    }
    if ($SizeBytes -lt 0) {
        throw "Artifact SizeBytes must be >= 0. Got: $SizeBytes"
    }
    if ([string]::IsNullOrWhiteSpace($WorkflowRunId)) {
        throw "WorkflowRunId must not be empty."
    }

    [PSCustomObject]@{
        Name          = $Name
        SizeBytes     = $SizeBytes
        CreatedAt     = $CreatedAt
        WorkflowRunId = $WorkflowRunId
    }
}

function New-RetentionPolicy {
    <#
    .SYNOPSIS
        Creates a retention policy configuration object.
    .DESCRIPTION
        Encapsulates the three policy knobs. All parameters have safe defaults
        that rarely delete anything — callers must tighten them explicitly.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # Maximum age in days; artifacts older than this are deleted
        [int]  $MaxAgeDays            = 90,
        # Maximum total size in bytes for all retained artifacts
        [long] $MaxTotalSizeBytes     = [long]10737418240,   # 10 GiB
        # Maximum number of artifacts to keep per workflow run ID
        [int]  $KeepLatestPerWorkflow = 10
    )

    if ($MaxAgeDays -le 0) {
        throw "MaxAgeDays must be > 0. Got: $MaxAgeDays"
    }
    if ($MaxTotalSizeBytes -le 0) {
        throw "MaxTotalSizeBytes must be > 0. Got: $MaxTotalSizeBytes"
    }
    if ($KeepLatestPerWorkflow -le 0) {
        throw "KeepLatestPerWorkflow must be > 0. Got: $KeepLatestPerWorkflow"
    }

    [PSCustomObject]@{
        MaxAgeDays            = $MaxAgeDays
        MaxTotalSizeBytes     = $MaxTotalSizeBytes
        KeepLatestPerWorkflow = $KeepLatestPerWorkflow
    }
}

# ---------------------------------------------------------------------------
# Individual policy evaluators
# ---------------------------------------------------------------------------

function Invoke-AgePolicy {
    <#
    .SYNOPSIS
        Returns artifacts that exceed the maximum age.
    .DESCRIPTION
        Compares each artifact's CreatedAt against ReferenceDate - MaxAgeDays.
        Returns the subset that should be deleted under this policy.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)][int]      $MaxAgeDays,
        [Parameter(Mandatory)][datetime] $ReferenceDate
    )

    if ($Artifacts.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    $cutoff = $ReferenceDate.AddDays(-$MaxAgeDays)

    # Use -le so an artifact whose age equals exactly MaxAgeDays is also deleted
    [PSCustomObject[]]@($Artifacts | Where-Object { $_.CreatedAt -le $cutoff })
}

function Invoke-SizePolicy {
    <#
    .SYNOPSIS
        Returns the oldest artifacts required to bring total size under the limit.
    .DESCRIPTION
        Sorts artifacts oldest-first and marks them for deletion until the
        remaining total size is at or below MaxTotalSizeBytes.
        Oldest artifacts are evicted first to preserve the most recent work.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)][long] $MaxTotalSizeBytes
    )

    if ($Artifacts.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    $totalBytes = [long]($Artifacts | Measure-Object -Property SizeBytes -Sum).Sum
    if ($totalBytes -le $MaxTotalSizeBytes) {
        return [PSCustomObject[]]@()
    }

    # Sort oldest first so we evict the least-recent artifacts
    $sorted     = @($Artifacts | Sort-Object -Property CreatedAt)
    $toDelete   = [System.Collections.Generic.List[PSCustomObject]]::new()
    $bytesFreed = [long]0

    foreach ($artifact in $sorted) {
        if (($totalBytes - $bytesFreed) -le $MaxTotalSizeBytes) {
            break
        }
        $toDelete.Add($artifact)
        $bytesFreed += [long]$artifact.SizeBytes
    }

    [PSCustomObject[]]$toDelete.ToArray()
}

function Invoke-KeepLatestPolicy {
    <#
    .SYNOPSIS
        Returns artifacts that exceed the keep-latest-N limit per workflow run ID.
    .DESCRIPTION
        Groups artifacts by WorkflowRunId, sorts each group newest-first, and
        marks the excess (beyond KeepLatestPerWorkflow) for deletion.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)][int] $KeepLatestPerWorkflow
    )

    if ($Artifacts.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    $toDelete = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Group by WorkflowRunId
    $groups = $Artifacts | Group-Object -Property WorkflowRunId

    foreach ($group in $groups) {
        # Sort newest-first within each workflow
        $sorted = @($group.Group | Sort-Object -Property CreatedAt -Descending)
        if ($sorted.Count -gt $KeepLatestPerWorkflow) {
            # Everything beyond the first N entries is excess
            $excess = $sorted[$KeepLatestPerWorkflow..($sorted.Count - 1)]
            foreach ($item in $excess) {
                $toDelete.Add([PSCustomObject]$item)
            }
        }
    }

    [PSCustomObject[]]$toDelete.ToArray()
}

# ---------------------------------------------------------------------------
# Deletion plan builder
# ---------------------------------------------------------------------------

function New-DeletionPlan {
    <#
    .SYNOPSIS
        Applies all retention policies and produces a unified deletion plan.
    .DESCRIPTION
        Runs all three policies, unions the deletion candidates (deduplication
        by artifact Name), and returns a plan object containing:
          - ArtifactsToDelete          : unique set of artifacts flagged for removal
          - ArtifactsToRetain          : artifacts that survive all policies
          - TotalSpaceReclaimedBytes   : sum of SizeBytes of deleted artifacts
          - IsDryRun                   : whether this is a simulation only
          - Summary                    : one-paragraph human-readable summary string
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]] $Artifacts,
        [Parameter(Mandatory)][PSCustomObject] $Policy,
        [Parameter(Mandatory)][datetime]       $ReferenceDate,
        [Parameter(Mandatory)][bool]           $DryRun
    )

    if ($Artifacts.Count -eq 0) {
        $emptySummary = "No artifacts to process. Retained: 0, Deleted: 0, Space reclaimed: 0 bytes."
        return [PSCustomObject]@{
            ArtifactsToDelete        = [PSCustomObject[]]@()
            ArtifactsToRetain        = [PSCustomObject[]]@()
            TotalSpaceReclaimedBytes = [long]0
            IsDryRun                 = $DryRun
            Summary                  = $emptySummary
        }
    }

    # Apply each policy independently
    $ageDeleteSet  = Invoke-AgePolicy  -Artifacts $Artifacts -MaxAgeDays            $Policy.MaxAgeDays    -ReferenceDate $ReferenceDate
    $sizeDeleteSet = Invoke-SizePolicy -Artifacts $Artifacts -MaxTotalSizeBytes      $Policy.MaxTotalSizeBytes
    $keepDeleteSet = Invoke-KeepLatestPolicy -Artifacts $Artifacts -KeepLatestPerWorkflow $Policy.KeepLatestPerWorkflow

    # Union all deletion candidates, deduplicated by Name
    $deleteNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($a in $ageDeleteSet)  { [void]$deleteNames.Add($a.Name) }
    foreach ($a in $sizeDeleteSet) { [void]$deleteNames.Add($a.Name) }
    foreach ($a in $keepDeleteSet) { [void]$deleteNames.Add($a.Name) }

    # Wrap in @() to guarantee arrays even when 0 or 1 item matches (strict mode forbids .Count on scalars)
    $toDelete = [PSCustomObject[]]@($Artifacts | Where-Object { $deleteNames.Contains($_.Name) })
    $toRetain = [PSCustomObject[]]@($Artifacts | Where-Object { -not $deleteNames.Contains($_.Name) })

    $spaceReclaimed = [long]0
    if ($toDelete.Count -gt 0) {
        $spaceReclaimed = [long]($toDelete | Measure-Object -Property SizeBytes -Sum).Sum
    }

    # Build compact summary string
    $dryRunLabel = if ($DryRun) { ' [DRY RUN]' } else { '' }
    $summary = (
        "Deletion Plan${dryRunLabel}: " +
        "retain $($toRetain.Count) artifact(s), " +
        "delete $($toDelete.Count) artifact(s), " +
        "reclaim $spaceReclaimed bytes."
    )

    [PSCustomObject]@{
        ArtifactsToDelete        = $toDelete
        ArtifactsToRetain        = $toRetain
        TotalSpaceReclaimedBytes = $spaceReclaimed
        IsDryRun                 = $DryRun
        Summary                  = $summary
    }
}

# ---------------------------------------------------------------------------
# Report formatter
# ---------------------------------------------------------------------------

function Format-DeletionPlanSummary {
    <#
    .SYNOPSIS
        Renders a deletion plan as a multi-line human-readable report string.
    .DESCRIPTION
        Produces a formatted report listing retained artifacts, artifacts
        scheduled for deletion, total space reclaimed, and (if applicable)
        the DRY RUN notice. This is intentionally a pure formatting function
        so it can be tested independently from the plan logic.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][PSCustomObject] $Plan
    )

    $sb = [System.Text.StringBuilder]::new()

    if ($Plan.IsDryRun) {
        [void]$sb.AppendLine('==============================')
        [void]$sb.AppendLine('  ARTIFACT CLEANUP — DRY RUN  ')
        [void]$sb.AppendLine('==============================')
    } else {
        [void]$sb.AppendLine('==============================')
        [void]$sb.AppendLine('  ARTIFACT CLEANUP PLAN       ')
        [void]$sb.AppendLine('==============================')
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Artifacts to RETAIN ($($Plan.ArtifactsToRetain.Count)):")
    if ($Plan.ArtifactsToRetain.Count -gt 0) {
        foreach ($a in ($Plan.ArtifactsToRetain | Sort-Object -Property CreatedAt -Descending)) {
            [void]$sb.AppendLine("  [KEEP]   $($a.Name)  ($($a.SizeBytes) bytes)  created $($a.CreatedAt.ToString('yyyy-MM-dd'))  workflow: $($a.WorkflowRunId)")
        }
    } else {
        [void]$sb.AppendLine('  (none)')
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Artifacts to DELETE ($($Plan.ArtifactsToDelete.Count)):")
    if ($Plan.ArtifactsToDelete.Count -gt 0) {
        foreach ($a in ($Plan.ArtifactsToDelete | Sort-Object -Property CreatedAt)) {
            [void]$sb.AppendLine("  [DELETE] $($a.Name)  ($($a.SizeBytes) bytes)  created $($a.CreatedAt.ToString('yyyy-MM-dd'))  workflow: $($a.WorkflowRunId)")
        }
    } else {
        [void]$sb.AppendLine('  (none)')
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("Total space reclaimed: $($Plan.TotalSpaceReclaimedBytes) bytes")

    [string]$sb.ToString()
}
