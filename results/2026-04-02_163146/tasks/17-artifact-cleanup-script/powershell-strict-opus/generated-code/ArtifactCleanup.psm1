# ArtifactCleanup module
# Applies retention policies to CI/CD artifacts and generates deletion plans.
#
# Policies supported:
#   - MaxAgeDays:        delete artifacts older than N days
#   - KeepLatestN:       keep only the N most recent artifacts per artifact Name
#   - MaxTotalSizeBytes: delete oldest artifacts until total size fits within budget
#
# All policies are combined via union — an artifact flagged by ANY policy is deleted.
# Supports dry-run mode for safe preview.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ── Cycle 1: Artifact record factory ────────────────────────────────────────

function New-ArtifactRecord {
    <#
    .SYNOPSIS
        Creates a hashtable representing a single artifact with metadata.
    .DESCRIPTION
        Validates inputs and returns a structured hashtable with Name, SizeBytes,
        CreatedDate, and WorkflowRunId fields.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [long]$SizeBytes,

        [Parameter(Mandatory)]
        [datetime]$CreatedDate,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WorkflowRunId
    )

    # Validate inputs with meaningful error messages
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'Name must not be empty.'
    }
    if ($SizeBytes -lt 0) {
        throw 'SizeBytes must be non-negative.'
    }
    if ([string]::IsNullOrWhiteSpace($WorkflowRunId)) {
        throw 'WorkflowRunId must not be empty.'
    }

    [hashtable]$record = @{
        Name          = [string]$Name
        SizeBytes     = [long]$SizeBytes
        CreatedDate   = [datetime]$CreatedDate
        WorkflowRunId = [string]$WorkflowRunId
    }

    return $record
}

# ── Cycle 2: Max-age retention policy ───────────────────────────────────────

function Get-ArtifactsExceedingMaxAge {
    <#
    .SYNOPSIS
        Returns WorkflowRunIds of artifacts older than MaxAgeDays.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate
    )

    if ($MaxAgeDays -le 0) {
        throw 'MaxAgeDays must be positive.'
    }

    [datetime]$cutoff = $ReferenceDate.AddDays(-$MaxAgeDays)

    [System.Collections.Generic.List[string]]$toDelete = [System.Collections.Generic.List[string]]::new()

    foreach ($artifact in $Artifacts) {
        [datetime]$created = [datetime]$artifact.CreatedDate
        if ($created -lt $cutoff) {
            $toDelete.Add([string]$artifact.WorkflowRunId)
        }
    }

    # Comma operator prevents PowerShell from unrolling empty arrays to $null
    return ,[string[]]$toDelete.ToArray()
}

# ── Cycle 3: Keep-latest-N per workflow name ────────────────────────────────

function Get-ArtifactsExceedingKeepLatestN {
    <#
    .SYNOPSIS
        Returns WorkflowRunIds of artifacts that exceed the keep-latest-N limit
        per artifact Name (grouped by Name, sorted by CreatedDate descending).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$KeepLatestN
    )

    if ($KeepLatestN -le 0) {
        throw 'KeepLatestN must be positive.'
    }

    # Group artifacts by Name
    [hashtable]$groups = @{}
    foreach ($artifact in $Artifacts) {
        [string]$name = [string]$artifact.Name
        if (-not $groups.ContainsKey($name)) {
            $groups[$name] = [System.Collections.Generic.List[hashtable]]::new()
        }
        ([System.Collections.Generic.List[hashtable]]$groups[$name]).Add($artifact)
    }

    [System.Collections.Generic.List[string]]$toDelete = [System.Collections.Generic.List[string]]::new()

    foreach ($name in $groups.Keys) {
        # Sort by CreatedDate descending (newest first)
        [System.Collections.Generic.List[hashtable]]$group = [System.Collections.Generic.List[hashtable]]$groups[$name]
        [hashtable[]]$sorted = $group | Sort-Object -Property { [datetime]$_.CreatedDate } -Descending

        # Skip the first N (the ones we keep), flag the rest for deletion
        if ($sorted.Count -gt $KeepLatestN) {
            for ([int]$i = $KeepLatestN; $i -lt $sorted.Count; $i++) {
                $toDelete.Add([string]$sorted[$i].WorkflowRunId)
            }
        }
    }

    return ,[string[]]$toDelete.ToArray()
}

# ── Cycle 4: Max total size policy ──────────────────────────────────────────

function Get-ArtifactsExceedingMaxTotalSize {
    <#
    .SYNOPSIS
        Returns WorkflowRunIds of oldest artifacts that must be deleted
        so the total remaining size fits within MaxTotalSizeBytes.
    .DESCRIPTION
        Sorts all artifacts oldest-first, then removes them one by one
        until the remaining total is within budget.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]]$Artifacts,

        [Parameter(Mandatory)]
        [long]$MaxTotalSizeBytes
    )

    if ($MaxTotalSizeBytes -le 0) {
        throw 'MaxTotalSizeBytes must be positive.'
    }

    # Calculate current total size
    [long]$totalSize = [long]0
    foreach ($artifact in $Artifacts) {
        $totalSize += [long]$artifact.SizeBytes
    }

    # Already within budget
    if ($totalSize -le $MaxTotalSizeBytes) {
        return ,[string[]]@()
    }

    # Sort oldest first (ascending by CreatedDate)
    [hashtable[]]$sorted = $Artifacts | Sort-Object -Property { [datetime]$_.CreatedDate }

    [System.Collections.Generic.List[string]]$toDelete = [System.Collections.Generic.List[string]]::new()
    [long]$remaining = $totalSize

    foreach ($artifact in $sorted) {
        if ($remaining -le $MaxTotalSizeBytes) {
            break
        }
        $toDelete.Add([string]$artifact.WorkflowRunId)
        $remaining -= [long]$artifact.SizeBytes
    }

    return ,[string[]]$toDelete.ToArray()
}

# ── Cycle 9: Byte formatting helper ────────────────────────────────────────

function Format-ByteSize {
    <#
    .SYNOPSIS
        Formats a byte count into a human-readable string (B, KB, MB, GB).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )

    if ($Bytes -lt [long]1024) {
        return "$Bytes B"
    }
    elseif ($Bytes -lt [long]1048576) {
        [double]$kb = [double]$Bytes / 1024.0
        return '{0:F2} KB' -f $kb
    }
    elseif ($Bytes -lt [long]1073741824) {
        [double]$mb = [double]$Bytes / 1048576.0
        return '{0:F2} MB' -f $mb
    }
    else {
        [double]$gb = [double]$Bytes / 1073741824.0
        return '{0:F2} GB' -f $gb
    }
}

# ── Cycle 5 + 6 + 7: Deletion plan generation (combined policies + dry-run) ─

function New-DeletionPlan {
    <#
    .SYNOPSIS
        Applies all retention policies and returns a deletion plan with summary.
    .DESCRIPTION
        Unions the deletion sets from MaxAge, KeepLatestN, and MaxTotalSize
        policies. After the first two policies are applied, max-total-size is
        evaluated against the remaining artifacts to decide if more must go.
        Returns a hashtable with deleted/retained lists, counts, reclaimed space,
        dry-run flag, and a human-readable summary.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]]$Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate,

        [Parameter(Mandatory)]
        [bool]$DryRun
    )

    # Collect workflow run IDs to delete (union across policies)
    [System.Collections.Generic.HashSet[string]]$deleteSet = [System.Collections.Generic.HashSet[string]]::new()

    # Apply max-age policy
    if ($Policy.ContainsKey('MaxAgeDays')) {
        [string[]]$ageDeletes = Get-ArtifactsExceedingMaxAge `
            -Artifacts $Artifacts `
            -MaxAgeDays ([int]$Policy['MaxAgeDays']) `
            -ReferenceDate $ReferenceDate

        foreach ($id in $ageDeletes) {
            [void]$deleteSet.Add([string]$id)
        }
    }

    # Apply keep-latest-N policy
    if ($Policy.ContainsKey('KeepLatestN')) {
        [string[]]$keepNDeletes = Get-ArtifactsExceedingKeepLatestN `
            -Artifacts $Artifacts `
            -KeepLatestN ([int]$Policy['KeepLatestN'])

        foreach ($id in $keepNDeletes) {
            [void]$deleteSet.Add([string]$id)
        }
    }

    # Apply max-total-size policy on remaining artifacts (after age + keepN removals)
    if ($Policy.ContainsKey('MaxTotalSizeBytes')) {
        # Build a list of artifacts that survived the first two policies
        [System.Collections.Generic.List[hashtable]]$remaining = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($artifact in $Artifacts) {
            if (-not $deleteSet.Contains([string]$artifact.WorkflowRunId)) {
                $remaining.Add($artifact)
            }
        }

        [string[]]$sizeDeletes = Get-ArtifactsExceedingMaxTotalSize `
            -Artifacts $remaining `
            -MaxTotalSizeBytes ([long]$Policy['MaxTotalSizeBytes'])

        foreach ($id in $sizeDeletes) {
            [void]$deleteSet.Add([string]$id)
        }
    }

    # Partition artifacts into deleted and retained
    [System.Collections.Generic.List[hashtable]]$deletedArtifacts = [System.Collections.Generic.List[hashtable]]::new()
    [System.Collections.Generic.List[hashtable]]$retainedArtifacts = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($artifact in $Artifacts) {
        if ($deleteSet.Contains([string]$artifact.WorkflowRunId)) {
            $deletedArtifacts.Add($artifact)
        }
        else {
            $retainedArtifacts.Add($artifact)
        }
    }

    # Calculate space reclaimed
    [long]$spaceReclaimed = [long]0
    foreach ($artifact in $deletedArtifacts) {
        $spaceReclaimed += [long]$artifact.SizeBytes
    }

    # Build human-readable summary
    [string]$formattedReclaimed = Format-ByteSize -Bytes $spaceReclaimed
    [string]$prefix = if ($DryRun) { '[DRY RUN] ' } else { '' }
    [string]$summary = "${prefix}Artifact cleanup: $($deletedArtifacts.Count) deleted, " +
        "$($retainedArtifacts.Count) retained, ${formattedReclaimed} reclaimed."

    [hashtable]$plan = @{
        TotalArtifacts      = [int]$Artifacts.Count
        DeletedCount        = [int]$deletedArtifacts.Count
        RetainedCount       = [int]$retainedArtifacts.Count
        SpaceReclaimedBytes = [long]$spaceReclaimed
        DeletedArtifacts    = $deletedArtifacts
        RetainedArtifacts   = $retainedArtifacts
        DryRun              = [bool]$DryRun
        Summary             = [string]$summary
    }

    return $plan
}

# ── Cycle 8: Main entry point ──────────────────────────────────────────────

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Main entry point: applies retention policies to artifacts and returns
        a deletion plan with summary.
    .DESCRIPTION
        Wraps New-DeletionPlan with a convenient switch-based DryRun parameter.
        This is the public API consumers should call.
    .EXAMPLE
        $plan = Invoke-ArtifactCleanup -Artifacts $list -Policy $policy -DryRun
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[hashtable]]$Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [Parameter()]
        [datetime]$ReferenceDate = [datetime]::UtcNow,

        [Parameter()]
        [switch]$DryRun
    )

    [bool]$isDryRun = [bool]$DryRun.IsPresent

    [hashtable]$plan = New-DeletionPlan `
        -Artifacts $Artifacts `
        -Policy $Policy `
        -ReferenceDate $ReferenceDate `
        -DryRun $isDryRun

    return $plan
}

# Export public functions
Export-ModuleMember -Function @(
    'New-ArtifactRecord'
    'Get-ArtifactsExceedingMaxAge'
    'Get-ArtifactsExceedingKeepLatestN'
    'Get-ArtifactsExceedingMaxTotalSize'
    'Format-ByteSize'
    'New-DeletionPlan'
    'Invoke-ArtifactCleanup'
)
