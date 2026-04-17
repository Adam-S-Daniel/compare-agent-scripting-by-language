# ArtifactCleanup.psm1
# Module implementing GitHub Actions artifact retention policies.
#
# Policies applied (union — if any policy selects an artifact for deletion,
# it is deleted):
#   1. MaxAgeDays       — delete artifacts older than N days.
#   2. MaxTotalSizeBytes — delete oldest artifacts until the retained total
#                         size is at or below the cap.
#   3. KeepLatestN      — per workflow run, keep only the N newest artifacts.
#
# KeepLatestN is an override: within each workflow it *protects* the newest
# N from deletion, but artifacts pruned by MaxAgeDays / MaxTotalSizeBytes are
# still deleted regardless. This matches typical CI cleanup semantics — you
# never want to keep a 2-year-old artifact just because it was the only one
# for that run.

Set-StrictMode -Version Latest

function Get-ArtifactList {
    <#
    .SYNOPSIS
      Load and validate an artifact fixture from a JSON file.
    .DESCRIPTION
      Expects a JSON document with an 'artifacts' array. Each element must
      have: id (int|string), name (string), sizeBytes (long), createdAt
      (ISO-8601 UTC string), workflowRunId (int|string).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Fixture file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $doc = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON in fixture '$Path': $($_.Exception.Message)"
    }

    if (-not $doc.PSObject.Properties.Name.Contains('artifacts')) {
        throw "Fixture '$Path' is missing the required 'artifacts' array."
    }

    $required = 'id','name','sizeBytes','createdAt','workflowRunId'
    $normalised = New-Object System.Collections.Generic.List[object]
    foreach ($a in $doc.artifacts) {
        foreach ($r in $required) {
            if (-not $a.PSObject.Properties.Name.Contains($r)) {
                throw "Artifact is missing required field '$r': $($a | ConvertTo-Json -Compress)"
            }
        }
        # Normalise createdAt to a [DateTime] in UTC for deterministic comparisons.
        $created = [DateTime]::Parse($a.createdAt, [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
            [System.Globalization.DateTimeStyles]::AdjustToUniversal)

        $normalised.Add([pscustomobject]@{
            Id            = $a.id
            Name          = [string]$a.name
            SizeBytes     = [long]$a.sizeBytes
            CreatedAt     = $created
            WorkflowRunId = $a.workflowRunId
        })
    }
    return ,([object[]]$normalised.ToArray())
}

function Find-ArtifactsExceedingAge {
    <#
    .SYNOPSIS
      Return artifacts older than MaxAgeDays relative to ReferenceDate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][int]$MaxAgeDays,
        [Parameter(Mandatory)][DateTime]$ReferenceDate
    )
    if ($MaxAgeDays -le 0) { return @() }
    $cutoff = $ReferenceDate.ToUniversalTime().AddDays(-$MaxAgeDays)
    # A strict < comparison: an artifact exactly at the cutoff boundary is
    # retained. This matches GitHub's own retention semantics.
    return @($Artifacts | Where-Object { $_.CreatedAt.ToUniversalTime() -lt $cutoff })
}

function Find-ArtifactsExceedingTotalSize {
    <#
    .SYNOPSIS
      When total retained size exceeds MaxTotalSizeBytes, mark oldest
      artifacts for deletion until the cap is met.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][long]$MaxTotalSizeBytes,
        [object[]]$AlreadyDeletedIds = @()
    )
    if ($MaxTotalSizeBytes -le 0) { return @() }

    # Only consider artifacts not already queued for deletion by another policy.
    $alreadySet = @{}
    foreach ($id in $AlreadyDeletedIds) { $alreadySet[[string]$id] = $true }

    $remaining = @($Artifacts | Where-Object { -not $alreadySet.ContainsKey([string]$_.Id) })
    $currentSize = ($remaining | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $currentSize) { $currentSize = 0 }
    if ($currentSize -le $MaxTotalSizeBytes) { return @() }

    # Delete oldest first (ascending CreatedAt) until under the cap.
    $toDelete = New-Object System.Collections.Generic.List[object]
    $sorted = $remaining | Sort-Object CreatedAt
    foreach ($a in $sorted) {
        if ($currentSize -le $MaxTotalSizeBytes) { break }
        $toDelete.Add($a) | Out-Null
        $currentSize -= $a.SizeBytes
    }
    return ,([object[]]$toDelete.ToArray())
}

function Find-ArtifactsExceedingKeepLatestN {
    <#
    .SYNOPSIS
      Identify artifacts to delete per workflow, keeping only the newest N.
    .DESCRIPTION
      Per workflowRunId, keep the N newest artifacts by CreatedAt; delete
      the rest. Ties on timestamp broken by Id (desc) for determinism.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [Parameter(Mandatory)][int]$KeepLatestN
    )
    if ($KeepLatestN -le 0) { return @() }

    $toDelete = New-Object System.Collections.Generic.List[object]
    $groups = $Artifacts | Group-Object -Property WorkflowRunId
    foreach ($g in $groups) {
        $ordered = @($g.Group | Sort-Object @{Expression='CreatedAt';Descending=$true}, @{Expression='Id';Descending=$true})
        if ($ordered.Count -le $KeepLatestN) { continue }
        for ($i = $KeepLatestN; $i -lt $ordered.Count; $i++) {
            $toDelete.Add($ordered[$i]) | Out-Null
        }
    }
    return ,([object[]]$toDelete.ToArray())
}

function New-CleanupPlan {
    <#
    .SYNOPSIS
      Apply all retention policies and return a deletion plan.
    .OUTPUTS
      A [pscustomobject] with:
        Delete   — array of artifacts to delete (with a DeletionReasons field)
        Keep     — array of artifacts to retain
        Summary  — @{ DeletedCount, RetainedCount, ReclaimedBytes, RetainedBytes,
                     Reasons = @{ MaxAge=n; MaxTotalSize=n; KeepLatestN=n } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Artifacts,
        [int]$MaxAgeDays = 0,
        [long]$MaxTotalSizeBytes = 0,
        [int]$KeepLatestN = 0,
        [DateTime]$ReferenceDate = [DateTime]::UtcNow
    )

    # Track each artifact's deletion reasons (multiple policies may flag one).
    $reasonsById = @{}
    function _Flag($id, $reason) {
        $key = [string]$id
        if (-not $reasonsById.ContainsKey($key)) {
            $reasonsById[$key] = New-Object System.Collections.Generic.List[string]
        }
        $reasonsById[$key].Add($reason)
    }

    $agePicks = Find-ArtifactsExceedingAge -Artifacts $Artifacts -MaxAgeDays $MaxAgeDays -ReferenceDate $ReferenceDate
    foreach ($a in $agePicks) { _Flag $a.Id 'MaxAgeDays' }

    $latestPicks = Find-ArtifactsExceedingKeepLatestN -Artifacts $Artifacts -KeepLatestN $KeepLatestN
    foreach ($a in $latestPicks) { _Flag $a.Id 'KeepLatestN' }

    $alreadyIds = @($reasonsById.Keys)
    $sizePicks = Find-ArtifactsExceedingTotalSize -Artifacts $Artifacts -MaxTotalSizeBytes $MaxTotalSizeBytes -AlreadyDeletedIds $alreadyIds
    foreach ($a in $sizePicks) { _Flag $a.Id 'MaxTotalSizeBytes' }

    # Partition the full set.
    $delete = New-Object System.Collections.Generic.List[object]
    $keep   = New-Object System.Collections.Generic.List[object]
    foreach ($a in $Artifacts) {
        $key = [string]$a.Id
        if ($reasonsById.ContainsKey($key)) {
            $withReasons = $a.PSObject.Copy()
            Add-Member -InputObject $withReasons -MemberType NoteProperty -Name DeletionReasons -Value @($reasonsById[$key])
            $delete.Add($withReasons) | Out-Null
        } else {
            $keep.Add($a) | Out-Null
        }
    }

    # Aggregate reason counts for the summary.
    $reasonCounts = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 0; KeepLatestN = 0 }
    foreach ($v in $reasonsById.Values) {
        foreach ($r in $v) { $reasonCounts[$r] += 1 }
    }

    $reclaimed = 0L
    foreach ($a in $delete) { $reclaimed += [long]$a.SizeBytes }
    $retained = 0L
    foreach ($a in $keep)   { $retained  += [long]$a.SizeBytes }

    return [pscustomobject]@{
        Delete  = [object[]]$delete.ToArray()
        Keep    = [object[]]$keep.ToArray()
        Summary = [pscustomobject]@{
            DeletedCount   = $delete.Count
            RetainedCount  = $keep.Count
            ReclaimedBytes = [long]$reclaimed
            RetainedBytes  = [long]$retained
            Reasons        = $reasonCounts
        }
    }
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
      End-to-end: load fixture, build plan, print summary, optionally
      "execute" deletions (in this mock tool, execution is a log line).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ArtifactsPath,
        [int]$MaxAgeDays = 0,
        [long]$MaxTotalSizeBytes = 0,
        [int]$KeepLatestN = 0,
        [switch]$DryRun,
        [DateTime]$ReferenceDate = [DateTime]::UtcNow
    )

    $artifacts = Get-ArtifactList -Path $ArtifactsPath
    $plan = New-CleanupPlan -Artifacts $artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestN $KeepLatestN `
        -ReferenceDate $ReferenceDate

    Add-Member -InputObject $plan -MemberType NoteProperty -Name DryRun -Value ([bool]$DryRun)
    Add-Member -InputObject $plan -MemberType NoteProperty -Name ExecutedDeletions `
        -Value (@($plan.Delete | ForEach-Object { if (-not $DryRun) { $_.Id } }) | Where-Object { $_ })

    return $plan
}

Export-ModuleMember -Function Get-ArtifactList, Find-ArtifactsExceedingAge, `
    Find-ArtifactsExceedingTotalSize, Find-ArtifactsExceedingKeepLatestN, `
    New-CleanupPlan, Invoke-ArtifactCleanup
