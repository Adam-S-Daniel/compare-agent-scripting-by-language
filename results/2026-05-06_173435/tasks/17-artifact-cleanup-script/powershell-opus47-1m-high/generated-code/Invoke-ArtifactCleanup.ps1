<#
.SYNOPSIS
    Apply retention policies to a list of CI artifacts and emit a deletion plan.

.DESCRIPTION
    Loads artifact metadata (name, size_bytes, created_at, workflow_name,
    workflow_run_id) and a policy document, then produces a deletion plan.
    Supports three retention policies that are applied in this order:

      1. MaxAgeDays              - delete artifacts older than N days
      2. KeepLatestNPerWorkflow  - keep the N most-recent artifacts per
                                   workflow_name and delete the rest
      3. MaxTotalSizeBytes       - if survivors exceed the cap, evict the
                                   oldest until total is at or below the cap

    Each deletion is annotated with the policy reason that triggered it.
    Dry-run mode produces the same plan but tags the summary so the caller
    knows nothing should be physically removed.

.PARAMETER ArtifactsPath
    Path to JSON containing an array of artifact metadata objects. Used by
    Invoke-ArtifactCleanupFromFile.

.PARAMETER PolicyPath
    Path to JSON containing the policy document.

.PARAMETER DryRun
    Tags the resulting plan as dry-run; no behavior change otherwise since
    this script never deletes artifacts itself - it only generates plans.

.NOTES
    Built TDD-first against Invoke-ArtifactCleanup.Tests.ps1.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CleanupArtifact {
    # Normalize an input record (PSCustomObject from JSON or hashtable from
    # tests) into a plain object with consistent field names + a parsed
    # creation timestamp. Validation happens here so the policy engine can
    # assume well-formed inputs.
    param([Parameter(Mandatory)] $Raw)

    # Accept hashtable or PSCustomObject uniformly.
    $get = {
        param($key)
        if ($Raw -is [hashtable]) { return $Raw[$key] }
        $prop = $Raw.PSObject.Properties[$key]
        if ($null -ne $prop) { return $prop.Value }
        return $null
    }

    foreach ($required in 'name', 'size_bytes', 'created_at', 'workflow_name', 'workflow_run_id') {
        if ($null -eq (& $get $required)) {
            throw "Artifact missing required field '$required'."
        }
    }

    $createdRaw = & $get 'created_at'
    try {
        $created = [datetimeoffset]::Parse($createdRaw).UtcDateTime
    } catch {
        throw "Artifact '$(& $get 'name')' has invalid created_at '$createdRaw': $($_.Exception.Message)"
    }

    [pscustomobject]@{
        name            = [string](& $get 'name')
        size_bytes      = [long](& $get 'size_bytes')
        created_at      = $created
        workflow_name   = [string](& $get 'workflow_name')
        workflow_run_id = [long](& $get 'workflow_run_id')
    }
}

function Get-ArtifactCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] $Artifacts,
        [Parameter(Mandatory)] [hashtable] $Policy,
        [datetime] $Now = ([datetime]::UtcNow),
        [switch]   $DryRun
    )

    # Normalize once. After this we operate on uniform pscustomobjects.
    $items = @()
    foreach ($a in $Artifacts) {
        $items += ,(ConvertTo-CleanupArtifact -Raw $a)
    }

    # Track surviving items + a parallel list of deletions with reasons.
    # Using ArrayList to allow mutation.
    $survivors = [System.Collections.Generic.List[object]]::new()
    foreach ($i in $items) { [void]$survivors.Add($i) }
    $deletions = [System.Collections.Generic.List[object]]::new()

    function Move-ToDeleted {
        param($Item, [string] $Reason, $SurvivorList, $DeletionList)
        [void]$SurvivorList.Remove($Item)
        [void]$DeletionList.Add([pscustomobject]@{
            name            = $Item.name
            size_bytes      = $Item.size_bytes
            created_at      = $Item.created_at
            workflow_name   = $Item.workflow_name
            workflow_run_id = $Item.workflow_run_id
            reason          = $Reason
        })
    }

    # 1. MaxAgeDays: anything older than the cutoff goes.
    if ($Policy.ContainsKey('MaxAgeDays') -and $null -ne $Policy.MaxAgeDays) {
        $maxAge = [int]$Policy.MaxAgeDays
        if ($maxAge -lt 0) { throw "MaxAgeDays must be non-negative; got $maxAge." }
        $cutoff = $Now.AddDays(-$maxAge)
        # Snapshot so we can mutate while iterating.
        $snapshot = @($survivors)
        foreach ($item in $snapshot) {
            if ($item.created_at -lt $cutoff) {
                Move-ToDeleted -Item $item -Reason 'max-age' -SurvivorList $survivors -DeletionList $deletions
            }
        }
    }

    # 2. KeepLatestNPerWorkflow: per workflow_name, keep N newest survivors.
    if ($Policy.ContainsKey('KeepLatestNPerWorkflow') -and $null -ne $Policy.KeepLatestNPerWorkflow) {
        $keepN = [int]$Policy.KeepLatestNPerWorkflow
        if ($keepN -lt 0) { throw "KeepLatestNPerWorkflow must be non-negative; got $keepN." }
        $byWorkflow = @{}
        foreach ($item in $survivors) {
            if (-not $byWorkflow.ContainsKey($item.workflow_name)) {
                $byWorkflow[$item.workflow_name] = [System.Collections.Generic.List[object]]::new()
            }
            [void]$byWorkflow[$item.workflow_name].Add($item)
        }
        foreach ($wf in $byWorkflow.Keys) {
            $sorted = $byWorkflow[$wf] | Sort-Object -Property created_at -Descending
            if ($sorted.Count -gt $keepN) {
                $toDelete = $sorted | Select-Object -Skip $keepN
                foreach ($item in $toDelete) {
                    Move-ToDeleted -Item $item -Reason 'keep-latest-n' -SurvivorList $survivors -DeletionList $deletions
                }
            }
        }
    }

    # 3. MaxTotalSizeBytes: if total exceeds cap, evict oldest until under.
    if ($Policy.ContainsKey('MaxTotalSizeBytes') -and $null -ne $Policy.MaxTotalSizeBytes) {
        $cap = [long]$Policy.MaxTotalSizeBytes
        if ($cap -lt 0) { throw "MaxTotalSizeBytes must be non-negative; got $cap." }
        $total = 0L
        foreach ($s in $survivors) { $total += [long]$s.size_bytes }
        if ($total -gt $cap) {
            $byAge = @($survivors | Sort-Object -Property created_at)  # oldest first
            $idx = $byAge.Count - 1
            # Evict from the oldest end.
            $oldestFirst = @($survivors | Sort-Object -Property created_at)
            foreach ($item in $oldestFirst) {
                if ($total -le $cap) { break }
                Move-ToDeleted -Item $item -Reason 'max-total-size' -SurvivorList $survivors -DeletionList $deletions
                $total -= $item.size_bytes
            }
        }
    }

    # Stable ordering: retained newest-first, deletions in the order the
    # policies marked them (preserves reason narrative).
    $retainedSorted = @($survivors | Sort-Object -Property created_at -Descending)
    $bytesReclaimed = 0L
    foreach ($d in $deletions) { $bytesReclaimed += [long]$d.size_bytes }

    [pscustomobject]@{
        TotalArtifacts  = $items.Count
        ToDelete        = @($deletions)
        ToRetain        = $retainedSorted
        BytesReclaimed  = [long]$bytesReclaimed
        DryRun          = [bool]$DryRun
        GeneratedAt     = $Now
    }
}

function Format-ArtifactCleanupSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Plan)

    $sb = [System.Text.StringBuilder]::new()
    if ($Plan.DryRun) { [void]$sb.AppendLine('=== Artifact Cleanup Plan (DRY-RUN) ===') }
    else              { [void]$sb.AppendLine('=== Artifact Cleanup Plan ===') }
    [void]$sb.AppendLine("Total artifacts: $($Plan.TotalArtifacts)")
    [void]$sb.AppendLine("Retained: $(@($Plan.ToRetain).Count)")
    [void]$sb.AppendLine("Deleted: $(@($Plan.ToDelete).Count)")
    [void]$sb.AppendLine("Reclaimed: $($Plan.BytesReclaimed) bytes")

    if (@($Plan.ToDelete).Count -gt 0) {
        [void]$sb.AppendLine('By reason:')
        $byReason = @{}
        foreach ($d in $Plan.ToDelete) {
            if (-not $byReason.ContainsKey($d.reason)) { $byReason[$d.reason] = 0 }
            $byReason[$d.reason] = $byReason[$d.reason] + 1
        }
        foreach ($key in ($byReason.Keys | Sort-Object)) {
            [void]$sb.AppendLine(("  {0}: {1}" -f $key, $byReason[$key]))
        }
    }
    return $sb.ToString().TrimEnd()
}

function Invoke-ArtifactCleanupFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ArtifactsPath,
        [Parameter(Mandatory)] [string] $PolicyPath,
        [datetime] $Now = ([datetime]::UtcNow)
    )

    if (-not (Test-Path -LiteralPath $ArtifactsPath)) {
        throw "Artifacts file not found: $ArtifactsPath"
    }
    if (-not (Test-Path -LiteralPath $PolicyPath)) {
        throw "Policy file not found: $PolicyPath"
    }

    try {
        $rawArtifactsJson = Get-Content -LiteralPath $ArtifactsPath -Raw
        $artifacts = $rawArtifactsJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse artifacts JSON ($ArtifactsPath): $($_.Exception.Message)"
    }
    if ($null -eq $artifacts) { $artifacts = @() }
    if ($artifacts -isnot [array]) { $artifacts = @($artifacts) }

    try {
        $policyRaw = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse policy JSON ($PolicyPath): $($_.Exception.Message)"
    }

    # Convert PSCustomObject policy to a hashtable so the engine can use
    # ContainsKey checks consistently.
    $policy = @{}
    foreach ($prop in $policyRaw.PSObject.Properties) {
        $policy[$prop.Name] = $prop.Value
    }

    $isDryRun = $false
    if ($policy.ContainsKey('DryRun')) { $isDryRun = [bool]$policy['DryRun'] }

    $plan = if ($isDryRun) {
        Get-ArtifactCleanupPlan -Artifacts $artifacts -Policy $policy -Now $Now -DryRun
    } else {
        Get-ArtifactCleanupPlan -Artifacts $artifacts -Policy $policy -Now $Now
    }
    $summary = Format-ArtifactCleanupSummary -Plan $plan
    [pscustomobject]@{
        Plan    = $plan
        Summary = $summary
    }
}

# When invoked as a script (not dot-sourced), run the CLI with the supplied
# parameters. This branch is what the GitHub Actions workflow exercises.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # Allow positional CLI form:
        #   pwsh ./Invoke-ArtifactCleanup.ps1 -ArtifactsPath ... -PolicyPath ...
        # Routed via param block at end below.
    }
}

# CLI entry point. Activated only when the script is run directly with
# -ArtifactsPath supplied, so dot-sourcing for tests does not trigger it.
$invokedDirectly = ($MyInvocation.MyCommand.Path -and $MyInvocation.InvocationName -ne '.')
if ($invokedDirectly -and $args.Count -gt 0) {
    # Parse simple -Key Value pairs without re-declaring a top-level param
    # block (which would shadow the inner functions when dot-sourced).
    $cliArgs = @{}
    for ($i = 0; $i -lt $args.Count; $i++) {
        $tok = $args[$i]
        if ($tok -is [string] -and $tok.StartsWith('-')) {
            $key = $tok.TrimStart('-')
            $val = if ($i + 1 -lt $args.Count) { $args[$i + 1] } else { $true }
            $cliArgs[$key] = $val
            $i++
        }
    }
    if (-not $cliArgs.ContainsKey('ArtifactsPath') -or -not $cliArgs.ContainsKey('PolicyPath')) {
        throw 'Usage: Invoke-ArtifactCleanup.ps1 -ArtifactsPath <path> -PolicyPath <path>'
    }
    # ARTIFACT_CLEANUP_NOW lets CI fix the reference clock so fixture-based
    # tests are deterministic. Without it the script uses the real UtcNow.
    $now = if ($env:ARTIFACT_CLEANUP_NOW) {
        [datetimeoffset]::Parse($env:ARTIFACT_CLEANUP_NOW).UtcDateTime
    } else {
        [datetime]::UtcNow
    }
    $result = Invoke-ArtifactCleanupFromFile -ArtifactsPath $cliArgs['ArtifactsPath'] -PolicyPath $cliArgs['PolicyPath'] -Now $now
    Write-Output $result.Summary
    Write-Output '--- PLAN-JSON-BEGIN ---'
    Write-Output ($result.Plan | ConvertTo-Json -Depth 6)
    Write-Output '--- PLAN-JSON-END ---'
}
