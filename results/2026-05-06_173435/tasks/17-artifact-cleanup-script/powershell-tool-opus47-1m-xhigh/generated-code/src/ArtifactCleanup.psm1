# ArtifactCleanup.psm1
#
# Pure-function module that produces a cleanup plan for a list of build
# artifacts given a retention policy. The module never deletes anything on
# its own — it returns a plan, and a separate runner translates that plan
# into a destructive call (or just prints it, in dry-run mode).
#
# This file is grown via TDD. Each function is the smallest implementation
# that makes the matching Pester tests pass.

Set-StrictMode -Version Latest

function Get-CleanupPlan {
    <#
    .SYNOPSIS
    Build a deletion plan for a set of artifacts under a retention policy.

    .PARAMETER Artifacts
    An array of artifact objects (name, size, createdAt, workflowRunId).

    .PARAMETER Policy
    A hashtable with optional keys: maxAgeDays, maxTotalSize, keepLatestPerWorkflow.

    .PARAMETER DryRun
    If true (default), the plan is marked as dry-run and the runner will
    not actually invoke any deletion commands.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory = $false)]
        [hashtable]$Policy = @{},

        [bool]$DryRun = $true
    )

    # ---- Validate policy values up front --------------------------------
    if ($Policy.ContainsKey('maxAgeDays') -and [double]$Policy['maxAgeDays'] -lt 0) {
        throw "Invalid policy: maxAgeDays must be >= 0 (got $($Policy['maxAgeDays']))"
    }
    if ($Policy.ContainsKey('maxTotalSize') -and [long]$Policy['maxTotalSize'] -lt 0) {
        throw "Invalid policy: maxTotalSize must be >= 0 (got $($Policy['maxTotalSize']))"
    }
    if ($Policy.ContainsKey('keepLatestPerWorkflow') -and [int]$Policy['keepLatestPerWorkflow'] -lt 0) {
        throw "Invalid policy: keepLatestPerWorkflow must be >= 0 (got $($Policy['keepLatestPerWorkflow']))"
    }

    $now = (Get-Date).ToUniversalTime()

    # ---- Annotate artifacts with parsed createdAt + age in days ---------
    # Done once up front so each rule pass is cheap.
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($a in $Artifacts) {
        # Verify the artifact carries the fields we need; reject early with
        # a clear message rather than letting strict-mode-PropertyNotFound
        # leak from deep inside the loop.
        foreach ($field in @('name', 'size', 'createdAt', 'workflowRunId')) {
            if (-not ($a.PSObject.Properties.Match($field).Count)) {
                throw "Artifact is missing required field '$field': $($a | ConvertTo-Json -Compress)"
            }
        }
        try {
            $created = [datetime]::Parse($a.createdAt).ToUniversalTime()
        } catch {
            throw "Artifact '$($a.name)' has invalid createdAt timestamp '$($a.createdAt)': $($_.Exception.Message)"
        }
        [void]$items.Add([pscustomobject]@{
            artifact = $a
            created  = $created
            ageDays  = [math]::Floor(($now - $created).TotalDays)
            protected = $false
        })
    }

    # ---- Rule: keepLatestPerWorkflow ------------------------------------
    # For each workflow run id, the N most recent artifacts are "protected"
    # — they cannot be deleted by other rules. Anything *beyond* the top N
    # in a given workflow group is marked for deletion by this rule.
    # keepN <= 0 disables the rule entirely.
    $keepN = 0
    if ($Policy.ContainsKey('keepLatestPerWorkflow')) {
        $keepN = [int]$Policy['keepLatestPerWorkflow']
    }
    $deleteFlag = @{}
    if ($keepN -gt 0) {
        $byWorkflow = $items | Group-Object -Property { $_.artifact.workflowRunId }
        foreach ($group in $byWorkflow) {
            $sorted = @($group.Group | Sort-Object -Property created -Descending)
            for ($i = 0; $i -lt $sorted.Count; $i++) {
                if ($i -lt $keepN) {
                    $sorted[$i].protected = $true
                } else {
                    $deleteFlag[$sorted[$i].artifact.name] = $true
                }
            }
        }
    }

    # ---- Rule: maxAgeDays ------------------------------------------------
    # An artifact is "older than maxAgeDays" if its full-day age exceeds the
    # threshold. Floor-on-days avoids spurious deletions from sub-second
    # drift between the caller's "now" and ours. Protected artifacts skip.
    if ($Policy.ContainsKey('maxAgeDays')) {
        $maxAgeDays = [double]$Policy['maxAgeDays']
        foreach ($entry in $items) {
            if ($entry.protected) { continue }
            if ($entry.ageDays -gt $maxAgeDays) {
                $deleteFlag[$entry.artifact.name] = $true
            }
        }
    }

    # ---- Rule: maxTotalSize ----------------------------------------------
    # Soft cap: after the other rules have run, if the still-retained set
    # exceeds the cap, evict from the oldest non-protected end first until
    # we're under cap (or only protected items remain). Items already
    # marked for deletion don't count toward the retained total.
    if ($Policy.ContainsKey('maxTotalSize')) {
        $cap = [long]$Policy['maxTotalSize']
        $retainedBytes = [long]0
        foreach ($entry in $items) {
            if (-not $deleteFlag[$entry.artifact.name]) {
                $retainedBytes += [long]$entry.artifact.size
            }
        }
        if ($retainedBytes -gt $cap) {
            # Evict oldest first among the unprotected, undeleted items.
            $evictable = $items |
                Where-Object { -not $_.protected -and -not $deleteFlag[$_.artifact.name] } |
                Sort-Object -Property created
            foreach ($entry in $evictable) {
                if ($retainedBytes -le $cap) { break }
                $deleteFlag[$entry.artifact.name] = $true
                $retainedBytes -= [long]$entry.artifact.size
            }
        }
    }

    $toDelete = New-Object System.Collections.Generic.List[object]
    $retainList = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $items) {
        if ($deleteFlag[$entry.artifact.name]) {
            [void]$toDelete.Add($entry.artifact)
        } else {
            [void]$retainList.Add($entry.artifact)
        }
    }

    $toRetain = $retainList.ToArray()
    $toDelete = $toDelete.ToArray()

    $retainedBytes = [long]0
    foreach ($a in $toRetain) { $retainedBytes += [long]$a.size }
    $reclaimedBytes = [long]0
    foreach ($a in $toDelete) { $reclaimedBytes += [long]$a.size }

    [pscustomobject]@{
        totalArtifacts      = $Artifacts.Count
        toDelete            = [object[]]$toDelete
        toRetain            = [object[]]$toRetain
        deletedCount        = $toDelete.Count
        retainedCount       = $toRetain.Count
        totalReclaimedBytes = [long]$reclaimedBytes
        totalRetainedBytes  = [long]$retainedBytes
        dryRun              = [bool]$DryRun
        policy              = $Policy
    }
}

function Invoke-CleanupPlan {
    <#
    .SYNOPSIS
    Apply a cleanup plan, optionally honoring its dry-run flag.

    .PARAMETER Plan
    The plan object produced by Get-CleanupPlan.

    .PARAMETER DeleteAction
    A script block invoked once per artifact in plan.toDelete. The artifact
    object is passed as the first argument. In dry-run mode the action is
    NEVER called; we still report what would have been deleted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] $Plan,
        [Parameter(Mandatory = $true)] [scriptblock]$DeleteAction
    )

    $deletedActuallyCount = 0
    if (-not $Plan.dryRun) {
        foreach ($a in $Plan.toDelete) {
            try {
                & $DeleteAction $a
                $deletedActuallyCount++
            } catch {
                Write-Error "Failed to delete artifact '$($a.name)': $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject]@{
        dryRun                = [bool]$Plan.dryRun
        plannedDeleteCount    = [int]$Plan.deletedCount
        deletedActuallyCount  = [int]$deletedActuallyCount
        totalReclaimedBytes   = [long]$Plan.totalReclaimedBytes
    }
}

function Format-CleanupSummary {
    <#
    .SYNOPSIS
    Render a one-line, human-readable summary of a cleanup plan suitable
    for printing to a CI log.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] $Plan)

    $mode = if ($Plan.dryRun) { 'DRY-RUN' } else { 'COMMIT' }
    "[$mode] retained: $($Plan.retainedCount) ($($Plan.totalRetainedBytes) bytes), deleted: $($Plan.deletedCount), reclaimed: $($Plan.totalReclaimedBytes) bytes"
}

Export-ModuleMember -Function Get-CleanupPlan, Invoke-CleanupPlan, Format-CleanupSummary
