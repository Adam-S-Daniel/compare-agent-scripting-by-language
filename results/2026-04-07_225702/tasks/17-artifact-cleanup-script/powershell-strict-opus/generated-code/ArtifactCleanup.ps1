Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ArtifactCleanup.ps1
# Applies retention policies to CI/CD artifacts and generates a deletion plan.
# Supports: max age, max total size, keep-latest-N per workflow, and dry-run mode.

function New-ArtifactRecord {
    <#
    .SYNOPSIS
        Creates a structured artifact record (PSCustomObject) from the given metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [long]$SizeBytes,

        [Parameter(Mandatory)]
        [datetime]$CreationDate,

        [Parameter(Mandatory)]
        [string]$WorkflowRunId
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name cannot be empty"
    }
    if ($SizeBytes -lt 0) {
        throw "SizeBytes must be non-negative"
    }

    [PSCustomObject]@{
        Name          = $Name
        SizeBytes     = $SizeBytes
        CreationDate  = $CreationDate
        WorkflowRunId = $WorkflowRunId
    }
}

function New-MockArtifactSet {
    <#
    .SYNOPSIS
        Returns a realistic set of mock artifacts for testing retention policies.
        Covers multiple workflows, varying ages and sizes.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    @(
        # Workflow A — build artifacts, mixed ages
        (New-ArtifactRecord -Name 'build-A-1' -SizeBytes ([long]5242880)  -CreationDate ([datetime]'2026-01-10') -WorkflowRunId 'wf-A-run-1'),
        (New-ArtifactRecord -Name 'build-A-2' -SizeBytes ([long]4194304)  -CreationDate ([datetime]'2026-02-15') -WorkflowRunId 'wf-A-run-2'),
        (New-ArtifactRecord -Name 'build-A-3' -SizeBytes ([long]3145728)  -CreationDate ([datetime]'2026-03-20') -WorkflowRunId 'wf-A-run-3'),
        (New-ArtifactRecord -Name 'build-A-4' -SizeBytes ([long]2097152)  -CreationDate ([datetime]'2026-03-30') -WorkflowRunId 'wf-A-run-4'),

        # Workflow B — test reports
        (New-ArtifactRecord -Name 'test-B-1'  -SizeBytes ([long]1048576)  -CreationDate ([datetime]'2026-01-05') -WorkflowRunId 'wf-B-run-1'),
        (New-ArtifactRecord -Name 'test-B-2'  -SizeBytes ([long]2097152)  -CreationDate ([datetime]'2026-03-10') -WorkflowRunId 'wf-B-run-2'),
        (New-ArtifactRecord -Name 'test-B-3'  -SizeBytes ([long]1572864)  -CreationDate ([datetime]'2026-03-28') -WorkflowRunId 'wf-B-run-3'),

        # Workflow C — deploy logs
        (New-ArtifactRecord -Name 'deploy-C-1' -SizeBytes ([long]524288)   -CreationDate ([datetime]'2025-12-01') -WorkflowRunId 'wf-C-run-1'),
        (New-ArtifactRecord -Name 'deploy-C-2' -SizeBytes ([long]786432)   -CreationDate ([datetime]'2026-03-25') -WorkflowRunId 'wf-C-run-2'),
        (New-ArtifactRecord -Name 'deploy-C-3' -SizeBytes ([long]655360)   -CreationDate ([datetime]'2026-03-31') -WorkflowRunId 'wf-C-run-3')
    )
}

function Get-ArtifactsExceedingMaxAge {
    <#
    .SYNOPSIS
        Returns artifacts whose age exceeds MaxAgeDays relative to ReferenceDate.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate
    )

    if ($MaxAgeDays -lt 0) {
        throw "MaxAgeDays must be non-negative"
    }

    [datetime]$cutoff = $ReferenceDate.AddDays(-$MaxAgeDays)

    # Return artifacts created strictly before the cutoff
    [PSCustomObject[]]$expired = @($Artifacts | Where-Object { $_.CreationDate -lt $cutoff })
    return $expired
}

function Get-ArtifactsExceedingKeepLatestN {
    <#
    .SYNOPSIS
        Groups artifacts by WorkflowRunId, sorts each group by CreationDate descending,
        and returns artifacts beyond the top N per workflow (i.e., the ones to delete).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$KeepLatestN
    )

    if ($KeepLatestN -lt 0) {
        throw "KeepLatestN must be non-negative"
    }

    [System.Collections.Generic.List[PSCustomObject]]$toDelete = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Group by workflow, then sort each group by date descending and skip the top N
    [hashtable]$groups = @{}
    foreach ($artifact in $Artifacts) {
        [string]$key = $artifact.WorkflowRunId
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = [System.Collections.Generic.List[PSCustomObject]]::new()
        }
        $groups[$key].Add($artifact)
    }

    foreach ($key in $groups.Keys) {
        [PSCustomObject[]]$sorted = @($groups[$key] | Sort-Object -Property CreationDate -Descending)
        if ($sorted.Count -gt $KeepLatestN) {
            for ([int]$i = $KeepLatestN; $i -lt $sorted.Count; $i++) {
                $toDelete.Add($sorted[$i])
            }
        }
    }

    return [PSCustomObject[]]@($toDelete)
}

function Get-ArtifactsExceedingMaxTotalSize {
    <#
    .SYNOPSIS
        Sorts artifacts by CreationDate ascending (oldest first), removes oldest
        until the remaining total size fits within MaxTotalSizeBytes.
        Returns the artifacts marked for deletion.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [long]$MaxTotalSizeBytes
    )

    if ($MaxTotalSizeBytes -lt 0) {
        throw "MaxTotalSizeBytes must be non-negative"
    }

    [long]$totalSize = [long]0
    foreach ($a in $Artifacts) {
        $totalSize += [long]$a.SizeBytes
    }

    if ($totalSize -le $MaxTotalSizeBytes) {
        return [PSCustomObject[]]@()
    }

    # Sort oldest first — delete oldest until within budget
    [PSCustomObject[]]$sorted = @($Artifacts | Sort-Object -Property CreationDate)
    [System.Collections.Generic.List[PSCustomObject]]$toDelete = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($artifact in $sorted) {
        if ($totalSize -le $MaxTotalSizeBytes) {
            break
        }
        $toDelete.Add($artifact)
        $totalSize -= [long]$artifact.SizeBytes
    }

    return [PSCustomObject[]]@($toDelete)
}

function New-DeletionPlan {
    <#
    .SYNOPSIS
        Applies all three retention policies (max age, keep-latest-N, max total size)
        and produces a unified deletion plan with summary statistics.
        Policies are applied as a union — an artifact flagged by ANY policy is deleted.
        Max-total-size is re-evaluated after age and keep-latest-N removals.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [Parameter(Mandatory)]
        [int]$KeepLatestN,

        [Parameter(Mandatory)]
        [long]$MaxTotalSizeBytes,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate
    )

    # Collect names flagged for deletion from age and keep-latest-N policies
    [System.Collections.Generic.HashSet[string]]$deleteNames = [System.Collections.Generic.HashSet[string]]::new()

    # Policy 1: max age
    [PSCustomObject[]]$agedOut = @(Get-ArtifactsExceedingMaxAge -Artifacts $Artifacts -MaxAgeDays $MaxAgeDays -ReferenceDate $ReferenceDate)
    foreach ($a in $agedOut) {
        [void]$deleteNames.Add([string]$a.Name)
    }

    # Policy 2: keep-latest-N per workflow
    [PSCustomObject[]]$overflowN = @(Get-ArtifactsExceedingKeepLatestN -Artifacts $Artifacts -KeepLatestN $KeepLatestN)
    foreach ($a in $overflowN) {
        [void]$deleteNames.Add([string]$a.Name)
    }

    # Determine what remains after the first two policies, then apply size policy
    [PSCustomObject[]]$remaining = @($Artifacts | Where-Object { -not $deleteNames.Contains([string]$_.Name) })
    if ($remaining.Count -gt 0) {
        [PSCustomObject[]]$sizeExcess = @(Get-ArtifactsExceedingMaxTotalSize -Artifacts $remaining -MaxTotalSizeBytes $MaxTotalSizeBytes)
        foreach ($a in $sizeExcess) {
            [void]$deleteNames.Add([string]$a.Name)
        }
    }

    # Build final lists
    [PSCustomObject[]]$toDelete = @($Artifacts | Where-Object { $deleteNames.Contains([string]$_.Name) })
    [PSCustomObject[]]$toRetain = @($Artifacts | Where-Object { -not $deleteNames.Contains([string]$_.Name) })

    [long]$spaceReclaimed = [long]0
    foreach ($d in $toDelete) {
        $spaceReclaimed += [long]$d.SizeBytes
    }

    [PSCustomObject]@{
        ToDelete            = $toDelete
        ToRetain            = $toRetain
        TotalArtifacts      = [int]$Artifacts.Count
        DeletedCount        = [int]$toDelete.Count
        RetainedCount       = [int]$toRetain.Count
        SpaceReclaimedBytes = $spaceReclaimed
    }
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Main entry point. Builds a deletion plan and optionally executes it.
        In dry-run mode, no actual deletions occur — only the plan is returned.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [Parameter(Mandatory)]
        [int]$KeepLatestN,

        [Parameter(Mandatory)]
        [long]$MaxTotalSizeBytes,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate,

        [Parameter()]
        [switch]$DryRun
    )

    [PSCustomObject]$plan = New-DeletionPlan `
        -Artifacts $Artifacts `
        -MaxAgeDays $MaxAgeDays `
        -KeepLatestN $KeepLatestN `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -ReferenceDate $ReferenceDate

    if (-not $DryRun) {
        # In a real system, this is where we would call the artifact deletion API.
        # For this implementation, we mark each deleted artifact.
        foreach ($artifact in $plan.ToDelete) {
            $artifact | Add-Member -NotePropertyName 'Deleted' -NotePropertyValue $true -Force
        }
    }

    [PSCustomObject]@{
        DryRun = [bool]$DryRun
        Plan   = $plan
    }
}

function Format-DeletionSummary {
    <#
    .SYNOPSIS
        Produces a human-readable summary of the deletion plan.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Plan
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("=== Artifact Cleanup Deletion Plan ===")
    [void]$sb.AppendLine("Total artifacts:    $($Plan.TotalArtifacts)")
    [void]$sb.AppendLine("To delete:          $($Plan.DeletedCount)")
    [void]$sb.AppendLine("To retain:          $($Plan.RetainedCount)")
    [void]$sb.AppendLine("Space reclaimed:    $(Format-ByteSize -Bytes ([long]$Plan.SpaceReclaimedBytes))")
    [void]$sb.AppendLine("")

    if ($Plan.DeletedCount -gt 0) {
        [void]$sb.AppendLine("--- Artifacts to delete ---")
        foreach ($d in $Plan.ToDelete) {
            [void]$sb.AppendLine("  [-] $($d.Name)  ($(Format-ByteSize -Bytes ([long]$d.SizeBytes)), created $($d.CreationDate.ToString('yyyy-MM-dd')), workflow $($d.WorkflowRunId))")
        }
        [void]$sb.AppendLine("")
    }

    if ($Plan.RetainedCount -gt 0) {
        [void]$sb.AppendLine("--- Artifacts to retain ---")
        foreach ($r in $Plan.ToRetain) {
            [void]$sb.AppendLine("  [+] $($r.Name)  ($(Format-ByteSize -Bytes ([long]$r.SizeBytes)), created $($r.CreationDate.ToString('yyyy-MM-dd')), workflow $($r.WorkflowRunId))")
        }
    }

    return $sb.ToString()
}

function Format-ByteSize {
    <#
    .SYNOPSIS
        Converts a byte count to a human-readable string (B, KB, MB, GB).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )

    if ($Bytes -ge 1073741824) {
        return "{0:N2} GB" -f ([double]$Bytes / 1073741824)
    }
    elseif ($Bytes -ge 1048576) {
        return "{0:N2} MB" -f ([double]$Bytes / 1048576)
    }
    elseif ($Bytes -ge 1024) {
        return "{0:N2} KB" -f ([double]$Bytes / 1024)
    }
    else {
        return "$Bytes B"
    }
}
