# ArtifactCleanup.psm1
#
# Pure PowerShell module that decides which CI/CD build artifacts to delete
# based on retention policies, then optionally invokes a caller-supplied
# deleter callback. The module is intentionally side-effect-free at the
# planning stage so that:
#
#   * the same plan can be inspected, dry-run, or applied by different callers
#   * tests can assert on the plan without touching any external system
#
# Policies (any combination, evaluated in this order):
#   1. MaxAgeDays               -- delete artifacts older than N days
#   2. KeepLatestPerWorkflow    -- per workflow run id, keep only the N newest
#   3. MaxTotalSizeBytes        -- after the above, evict oldest still-retained
#                                  artifacts until total size <= budget
#
# Each artifact must be a hashtable / pscustomobject with the keys:
#   id, name, sizeBytes (long), createdAt (datetime), workflowRunId (string)

Set-StrictMode -Version Latest

function Get-SafeSum {
    # Sum a property across a collection. Returns 0 when the collection is
    # empty -- avoids the StrictMode "property 'Sum' not found" trap that
    # Measure-Object hits on empty input.
    param([object[]] $Items, [string] $Property)
    if (-not $Items -or $Items.Count -eq 0) { return 0 }
    $total = 0L
    foreach ($i in $Items) {
        $v = $i.$Property
        if ($null -ne $v) { $total += [long]$v }
    }
    return $total
}

function Test-Artifact {
    # Validate that an artifact has the required fields.
    param([Parameter(Mandatory)] $Artifact)

    foreach ($field in 'name','sizeBytes','createdAt','workflowRunId') {
        if (-not ($Artifact.PSObject.Properties.Name -contains $field)) {
            throw "Artifact is missing required field '$field'."
        }
    }
}

function ConvertTo-PlanEntry {
    # Build a deletion-plan entry preserving the original artifact metadata
    # plus a 'reason' field explaining why it was selected.
    param($Artifact, [string]$Reason)

    [pscustomobject]@{
        id            = if ($Artifact.PSObject.Properties.Name -contains 'id') { $Artifact.id } else { $null }
        name          = $Artifact.name
        sizeBytes     = [long]$Artifact.sizeBytes
        createdAt     = [datetime]$Artifact.createdAt
        workflowRunId = $Artifact.workflowRunId
        reason        = $Reason
    }
}

function Get-ArtifactDeletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Artifacts,
        [int]      $MaxAgeDays            = -1,
        [int]      $KeepLatestPerWorkflow = -1,
        [long]     $MaxTotalSizeBytes     = -1,
        [datetime] $Now                   = [datetime]::UtcNow
    )

    if ($PSBoundParameters.ContainsKey('MaxAgeDays') -and $MaxAgeDays -lt 0) {
        throw "MaxAgeDays must be >= 0 (got $MaxAgeDays)."
    }
    if ($PSBoundParameters.ContainsKey('KeepLatestPerWorkflow') -and $KeepLatestPerWorkflow -lt 0) {
        throw "KeepLatestPerWorkflow must be >= 0 (got $KeepLatestPerWorkflow)."
    }
    if ($PSBoundParameters.ContainsKey('MaxTotalSizeBytes') -and $MaxTotalSizeBytes -lt 0) {
        throw "MaxTotalSizeBytes must be >= 0 (got $MaxTotalSizeBytes)."
    }

    foreach ($a in $Artifacts) { Test-Artifact -Artifact $a }

    # Track retained vs deleted by id so multiple policies can collaborate.
    # We use a hashtable keyed on the artifact's identity (id, falling back to
    # name+createdAt for fixtures that omit ids).
    function Get-Key($a) {
        if ($a.PSObject.Properties.Name -contains 'id' -and $a.id) { return [string]$a.id }
        return "{0}|{1:o}" -f $a.name, $a.createdAt
    }

    $deleteEntries = New-Object System.Collections.Generic.List[object]
    $deletedKeys   = New-Object System.Collections.Generic.HashSet[string]

    # --- Policy 1: max-age -------------------------------------------------
    if ($PSBoundParameters.ContainsKey('MaxAgeDays')) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ([datetime]$a.createdAt -lt $cutoff) {
                $deleteEntries.Add((ConvertTo-PlanEntry -Artifact $a -Reason 'max-age')) | Out-Null
                [void]$deletedKeys.Add((Get-Key $a))
            }
        }
    }

    # --- Policy 2: keep-latest-per-workflow --------------------------------
    if ($PSBoundParameters.ContainsKey('KeepLatestPerWorkflow')) {
        $stillThere = $Artifacts | Where-Object { -not $deletedKeys.Contains((Get-Key $_)) }
        $byWf = $stillThere | Group-Object -Property workflowRunId
        foreach ($g in $byWf) {
            # Sort newest first; everything past index N-1 is evicted.
            $sorted = $g.Group | Sort-Object -Property createdAt -Descending
            if ($sorted.Count -gt $KeepLatestPerWorkflow) {
                $excess = $sorted | Select-Object -Skip $KeepLatestPerWorkflow
                foreach ($a in $excess) {
                    $deleteEntries.Add((ConvertTo-PlanEntry -Artifact $a -Reason 'keep-latest-per-workflow')) | Out-Null
                    [void]$deletedKeys.Add((Get-Key $a))
                }
            }
        }
    }

    # --- Policy 3: max-total-size ------------------------------------------
    if ($PSBoundParameters.ContainsKey('MaxTotalSizeBytes')) {
        $stillThere = @($Artifacts | Where-Object { -not $deletedKeys.Contains((Get-Key $_)) })
        $totalBytes = Get-SafeSum -Items $stillThere -Property 'sizeBytes'

        if ($totalBytes -gt $MaxTotalSizeBytes) {
            # Evict oldest first until we are within budget.
            $oldestFirst = $stillThere | Sort-Object -Property createdAt
            foreach ($a in $oldestFirst) {
                if ($totalBytes -le $MaxTotalSizeBytes) { break }
                $deleteEntries.Add((ConvertTo-PlanEntry -Artifact $a -Reason 'max-total-size')) | Out-Null
                [void]$deletedKeys.Add((Get-Key $a))
                $totalBytes -= [long]$a.sizeBytes
            }
        }
    }

    # Build retain list = original minus deleted.
    $retainEntries = New-Object System.Collections.Generic.List[object]
    foreach ($a in $Artifacts) {
        if (-not $deletedKeys.Contains((Get-Key $a))) {
            $retainEntries.Add((ConvertTo-PlanEntry -Artifact $a -Reason 'retained')) | Out-Null
        }
    }

    $bytesReclaimed = Get-SafeSum -Items $deleteEntries.ToArray() -Property 'sizeBytes'
    $bytesRetained  = Get-SafeSum -Items $retainEntries.ToArray() -Property 'sizeBytes'

    [pscustomobject]@{
        Delete  = $deleteEntries.ToArray()
        Retain  = $retainEntries.ToArray()
        Summary = [pscustomobject]@{
            TotalArtifacts = @($Artifacts).Count
            DeletedCount   = $deleteEntries.Count
            RetainedCount  = $retainEntries.Count
            BytesReclaimed = [long]$bytesReclaimed
            BytesRetained  = [long]$bytesRetained
            GeneratedAt    = $Now
        }
    }
}

function Invoke-ArtifactCleanup {
    # Build a plan, then either report it (DryRun) or invoke $Deleter for each
    # artifact selected for deletion. Per-artifact failures are captured rather
    # than aborting the run -- a partially-failed cleanup is more useful than
    # a no-op one.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Artifacts,
        [int]       $MaxAgeDays            = -1,
        [int]       $KeepLatestPerWorkflow = -1,
        [long]      $MaxTotalSizeBytes     = -1,
        [datetime]  $Now                   = [datetime]::UtcNow,
        [switch]    $DryRun,
        [scriptblock] $Deleter             = { param($a) }
    )

    # Forward only the policy parameters that were explicitly supplied so
    # Get-ArtifactDeletionPlan can detect them via $PSBoundParameters.
    $planArgs = @{ Artifacts = $Artifacts; Now = $Now }
    foreach ($k in 'MaxAgeDays','KeepLatestPerWorkflow','MaxTotalSizeBytes') {
        if ($PSBoundParameters.ContainsKey($k)) {
            $planArgs[$k] = $PSBoundParameters[$k]
        }
    }
    $plan = Get-ArtifactDeletionPlan @planArgs

    $succeeded = New-Object System.Collections.Generic.List[object]
    $failed    = New-Object System.Collections.Generic.List[object]

    if (-not $DryRun) {
        foreach ($entry in $plan.Delete) {
            try {
                & $Deleter $entry
                $succeeded.Add($entry) | Out-Null
            }
            catch {
                $failed.Add([pscustomobject]@{
                    Artifact = $entry
                    Error    = $_.Exception.Message
                }) | Out-Null
            }
        }
    }

    [pscustomobject]@{
        Plan             = $plan
        DryRun           = [bool]$DryRun
        DeletedSucceeded = $succeeded.ToArray()
        DeletedFailed    = $failed.ToArray()
    }
}

function Format-DeletionPlanReport {
    # Produce a fixed, parseable text report. The exact field layout is what
    # the act-based test harness asserts on -- keep it stable.
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Plan)

    $s = $Plan.Summary
    $lines = @()
    $lines += '=== Artifact Cleanup Plan ==='
    $lines += ("Total artifacts: {0}" -f $s.TotalArtifacts)
    $lines += ("Retain:          {0}" -f $s.RetainedCount)
    $lines += ("Delete:          {0}" -f $s.DeletedCount)
    $lines += ("Bytes retained:  {0}" -f $s.BytesRetained)
    $lines += ("Bytes reclaimed: {0}" -f $s.BytesReclaimed)
    $lines += '--- Deletions ---'
    foreach ($d in $Plan.Delete) {
        $lines += ("DELETE {0} ({1} bytes) reason={2}" -f $d.name, $d.sizeBytes, $d.reason)
    }
    $lines += '--- Retentions ---'
    foreach ($r in $Plan.Retain) {
        $lines += ("RETAIN {0} ({1} bytes)" -f $r.name, $r.sizeBytes)
    }
    $lines -join [Environment]::NewLine
}

Export-ModuleMember -Function Get-ArtifactDeletionPlan, Invoke-ArtifactCleanup, Format-DeletionPlanReport
