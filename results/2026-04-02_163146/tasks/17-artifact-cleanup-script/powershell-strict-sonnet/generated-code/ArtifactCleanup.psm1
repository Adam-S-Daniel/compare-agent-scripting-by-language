# ArtifactCleanup.psm1
# Artifact retention-policy engine with dry-run support.
#
# TDD approach followed:
#   RED   – ArtifactCleanup.Tests.ps1 was written first; every test failed
#           because this file did not exist.
#   GREEN – Minimum implementation added function by function until all tests
#           pass.
#   REFACTOR – Types, error handling, and helper functions tidied up without
#              breaking any tests.
#
# Strict-mode requirements enforced:
#   • Set-StrictMode -Latest at module scope
#   • $ErrorActionPreference = 'Stop' at module scope
#   • [CmdletBinding()] on every function
#   • [OutputType()] on every function
#   • All parameters explicitly typed
#   • Explicit casts wherever numeric promotion could be implicit

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
# Data-model constructors
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Creates a new artifact record (mock data object).

.DESCRIPTION
    Represents a single CI/CD artifact with the metadata needed to evaluate
    retention policies.  SizeBytes is stored as [long] so files larger than
    2 GB are handled correctly.
#>
function New-ArtifactRecord {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # Human-readable artifact name (unique within a workflow run)
        [Parameter(Mandatory)]
        [string]$Name,

        # Size on disk in bytes; use [long] to support files > 2 GB
        [Parameter(Mandatory)]
        [long]$SizeBytes,

        # Timestamp when the artifact was created / uploaded
        [Parameter(Mandatory)]
        [datetime]$CreatedAt,

        # ID of the workflow run that produced this artifact
        [Parameter(Mandatory)]
        [string]$WorkflowRunId
    )

    [PSCustomObject]@{
        Name          = [string]$Name
        SizeBytes     = [long]$SizeBytes
        CreatedAt     = [datetime]$CreatedAt
        WorkflowRunId = [string]$WorkflowRunId
    }
}

<#
.SYNOPSIS
    Creates a retention policy descriptor.

.DESCRIPTION
    All three parameters are optional and independently nullable.
    When a parameter is omitted the corresponding constraint is disabled
    (i.e. the policy is unconstrained in that dimension).

    Combining multiple constraints applies them as a union: an artifact is
    flagged for deletion if it violates ANY enabled constraint.

.PARAMETER MaxAgeDays
    Delete artifacts whose age exceeds this many days.

.PARAMETER MaxTotalSizeBytes
    Delete the oldest artifacts (one by one) until the total size of the
    remaining set is at or below this threshold.

.PARAMETER KeepLatestN
    Per workflow-run ID, keep only the N most-recently-created artifacts and
    delete any older ones.
#>
function New-RetentionPolicy {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [Nullable[int]]$MaxAgeDays = $null,

        [Parameter()]
        [Nullable[long]]$MaxTotalSizeBytes = $null,

        [Parameter()]
        [Nullable[int]]$KeepLatestN = $null
    )

    [PSCustomObject]@{
        MaxAgeDays        = $MaxAgeDays
        MaxTotalSizeBytes = $MaxTotalSizeBytes
        KeepLatestN       = $KeepLatestN
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Core retention logic
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Evaluates a retention policy against a list of artifacts and returns the
    subset that should be deleted.

.DESCRIPTION
    Each enabled policy constraint is evaluated independently.  An artifact is
    included in the returned "to-delete" list if it violates at least one
    constraint (union / OR semantics, no duplicates).

    The function is referentially transparent: it never modifies the input
    array or the artifact objects.

.PARAMETER Artifacts
    All known artifacts.  May be an empty collection.

.PARAMETER Policy
    Retention policy produced by New-RetentionPolicy.

.PARAMETER ReferenceDate
    The "now" anchor for age calculations.  Defaults to the current wall-clock
    time but can be supplied explicitly for reproducible unit tests.
#>
function Get-ArtifactsToDelete {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [PSCustomObject]$Policy,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date)
    )

    # Short-circuit: nothing to evaluate
    if ($Artifacts.Count -eq 0) {
        return [PSCustomObject[]]@()
    }

    # Accumulate candidates using a HashSet keyed on object reference so that
    # the same artifact object is never added twice regardless of which
    # constraints flag it.
    $toDeleteSet = [System.Collections.Generic.HashSet[object]]::new(
        [System.Collections.Generic.EqualityComparer[object]]::Default
    )

    # ── Constraint 1: MaxAgeDays ───────────────────────────────────────────
    # An artifact is "too old" when its CreatedAt is strictly before the
    # cutoff date.  An artifact created exactly MaxAgeDays ago (to the second)
    # is NOT deleted (boundary is exclusive on the old side).
    if ($null -ne $Policy.MaxAgeDays) {
        [datetime]$cutoff = $ReferenceDate.AddDays(-[double][int]$Policy.MaxAgeDays)

        foreach ($artifact in $Artifacts) {
            if ([datetime]$artifact.CreatedAt -lt $cutoff) {
                [void]$toDeleteSet.Add($artifact)
            }
        }
    }

    # ── Constraint 2: MaxTotalSizeBytes ───────────────────────────────────
    # Sum all artifact sizes.  If the sum exceeds the limit, delete the oldest
    # artifacts one by one (oldest-first order) until the remaining total would
    # be within the limit.
    if ($null -ne $Policy.MaxTotalSizeBytes) {
        [long]$totalBytes = [long]0
        foreach ($artifact in $Artifacts) {
            $totalBytes += [long]$artifact.SizeBytes
        }

        [long]$maxBytes = [long]$Policy.MaxTotalSizeBytes

        if ($totalBytes -gt $maxBytes) {
            [long]$mustReclaim   = $totalBytes - $maxBytes
            [long]$accumulated   = [long]0

            # Sort a copy oldest-first; the original $Artifacts order is untouched
            [PSCustomObject[]]$byAge = @($Artifacts | Sort-Object -Property CreatedAt)

            foreach ($artifact in $byAge) {
                # Stop as soon as we have reclaimed enough space
                if ($accumulated -ge $mustReclaim) {
                    break
                }
                [void]$toDeleteSet.Add($artifact)
                $accumulated += [long]$artifact.SizeBytes
            }
        }
    }

    # ── Constraint 3: KeepLatestN ─────────────────────────────────────────
    # Group artifacts by workflow-run ID.  Within each group keep the N newest;
    # mark all older ones for deletion.
    if ($null -ne $Policy.KeepLatestN) {
        [int]$keepCount = [int]$Policy.KeepLatestN

        $groups = $Artifacts | Group-Object -Property WorkflowRunId

        foreach ($group in $groups) {
            # Sort descending so index 0 = newest
            [PSCustomObject[]]$sorted = @($group.Group | Sort-Object -Property CreatedAt -Descending)

            if ($sorted.Count -gt $keepCount) {
                # Skip the $keepCount newest; add the rest (older) to the delete set
                [PSCustomObject[]]$tail = @($sorted | Select-Object -Skip $keepCount)
                foreach ($old in $tail) {
                    [void]$toDeleteSet.Add($old)
                }
            }
        }
    }

    # Return the filtered list in the original input order
    [PSCustomObject[]]@($Artifacts | Where-Object { $toDeleteSet.Contains($_) })
}

# ─────────────────────────────────────────────────────────────────────────────
# Plan generation helpers
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Formats a byte count as a human-readable string (B / KB / MB / GB).
#>
function Format-ByteSize {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )

    [long]$gbThreshold = [long]1073741824  # 1 GB
    [long]$mbThreshold = [long]1048576     # 1 MB
    [long]$kbThreshold = [long]1024        # 1 KB

    if ($Bytes -ge $gbThreshold) {
        return '{0:N2} GB' -f ([double]$Bytes / [double]$gbThreshold)
    }
    elseif ($Bytes -ge $mbThreshold) {
        return '{0:N2} MB' -f ([double]$Bytes / [double]$mbThreshold)
    }
    elseif ($Bytes -ge $kbThreshold) {
        return '{0:N2} KB' -f ([double]$Bytes / [double]$kbThreshold)
    }
    else {
        return "$Bytes B"
    }
}

<#
.SYNOPSIS
    Builds a deletion plan with full summary statistics.

.DESCRIPTION
    Given the complete artifact list and the pre-computed subset to delete,
    calculates:
      • ArtifactsToDelete  – the artifacts that should be removed
      • ArtifactsToRetain  – the artifacts that survive
      • TotalSpaceReclaimedBytes – total bytes freed by the deletion
      • Summary – human-readable one-liner

.PARAMETER AllArtifacts
    Every known artifact (both kept and to-be-deleted).

.PARAMETER ArtifactsToDelete
    The subset returned by Get-ArtifactsToDelete.
#>
function New-DeletionPlan {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$AllArtifacts,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$ArtifactsToDelete
    )

    # Build a reference-equality set for O(1) membership tests
    $deleteSet = [System.Collections.Generic.HashSet[object]]::new(
        [System.Collections.Generic.EqualityComparer[object]]::Default
    )
    foreach ($artifact in $ArtifactsToDelete) {
        [void]$deleteSet.Add($artifact)
    }

    # Partition
    [PSCustomObject[]]$toRetain = @($AllArtifacts | Where-Object { -not $deleteSet.Contains($_) })

    # Aggregate reclaimed space
    [long]$reclaimed = [long]0
    foreach ($artifact in $ArtifactsToDelete) {
        $reclaimed += [long]$artifact.SizeBytes
    }

    [string]$reclaimedFormatted = Format-ByteSize -Bytes $reclaimed
    [string]$summary = (
        "Deletion plan: $($ArtifactsToDelete.Count) artifact(s) to delete " +
        "($reclaimedFormatted reclaimed), " +
        "$($toRetain.Count) artifact(s) to retain."
    )

    [PSCustomObject]@{
        ArtifactsToDelete        = $ArtifactsToDelete
        ArtifactsToRetain        = $toRetain
        TotalSpaceReclaimedBytes = $reclaimed
        Summary                  = $summary
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Main entry point
# ─────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Applies retention policies to a list of artifacts and optionally executes
    the deletion.

.DESCRIPTION
    In dry-run mode (-DryRun) the function computes and returns the deletion
    plan without touching any data.  In live mode it "executes" the deletions
    (simulated for mock data — a real implementation would call the storage
    API here) and returns a plan augmented with ArtifactsDeleted.

    Return object properties:
      DryRun                   [bool]             – Whether this was a dry run
      ArtifactsToDelete        [PSCustomObject[]] – Artifacts flagged for deletion
      ArtifactsToRetain        [PSCustomObject[]] – Artifacts that survive
      ArtifactsDeleted         [PSCustomObject[]] – Confirmed deletions (live mode)
                                                    or empty array (dry-run mode)
      TotalSpaceReclaimedBytes [long]             – Bytes freed
      Summary                  [string]           – Human-readable summary line

.PARAMETER Artifacts
    All known artifacts to evaluate.

.PARAMETER Policy
    The retention policy to apply (from New-RetentionPolicy).

.PARAMETER DryRun
    When present, only computes the plan; does not delete anything.

.PARAMETER ReferenceDate
    Anchor date for age calculations; defaults to now (overridable for tests).
#>
function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Artifacts,

        [Parameter(Mandatory)]
        [PSCustomObject]$Policy,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date)
    )

    # Step 1 – determine what should be deleted
    [PSCustomObject[]]$toDelete = Get-ArtifactsToDelete `
        -Artifacts     $Artifacts `
        -Policy        $Policy `
        -ReferenceDate $ReferenceDate

    # Step 2 – build the plan (stats + summary)
    $plan = New-DeletionPlan -AllArtifacts $Artifacts -ArtifactsToDelete $toDelete

    if ([bool]$DryRun) {
        # ── Dry-run mode ──────────────────────────────────────────────────
        # Report what WOULD happen; do not modify anything.
        return [PSCustomObject]@{
            DryRun                   = $true
            ArtifactsToDelete        = $plan.ArtifactsToDelete
            ArtifactsToRetain        = $plan.ArtifactsToRetain
            ArtifactsDeleted         = [PSCustomObject[]]@()
            TotalSpaceReclaimedBytes = $plan.TotalSpaceReclaimedBytes
            Summary                  = '[DRY RUN] ' + $plan.Summary
        }
    }
    else {
        # ── Live mode ─────────────────────────────────────────────────────
        # Simulate deletion.  In a real implementation each artifact would be
        # removed via an API call here.  We collect confirmed deletions so the
        # caller can distinguish "planned" from "executed".
        [System.Collections.Generic.List[PSCustomObject]]$deleted =
            [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($artifact in $plan.ArtifactsToDelete) {
            [string]$sizeLabel = Format-ByteSize -Bytes ([long]$artifact.SizeBytes)
            [string]$logMsg    = "Deleting artifact '$($artifact.Name)' " +
                                 "(run: $($artifact.WorkflowRunId), size: $sizeLabel)"
            Write-Verbose $logMsg

            # ← real implementation: Remove-ArtifactFromStorage -Artifact $artifact
            [void]$deleted.Add($artifact)
        }

        return [PSCustomObject]@{
            DryRun                   = $false
            ArtifactsToDelete        = $plan.ArtifactsToDelete
            ArtifactsToRetain        = $plan.ArtifactsToRetain
            ArtifactsDeleted         = [PSCustomObject[]]($deleted.ToArray())
            TotalSpaceReclaimedBytes = $plan.TotalSpaceReclaimedBytes
            Summary                  = $plan.Summary
        }
    }
}
