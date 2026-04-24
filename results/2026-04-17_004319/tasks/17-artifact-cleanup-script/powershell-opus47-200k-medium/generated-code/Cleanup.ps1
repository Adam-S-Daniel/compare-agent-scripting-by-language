# Cleanup.ps1 — artifact retention planner.
#
# Exposes three functions:
#   Get-CleanupPlan       — pure planner; returns ToDelete/ToKeep/Summary.
#   Invoke-ArtifactCleanup — runs a plan against a -DeleteAction scriptblock,
#                            honouring -DryRun.
#   Format-CleanupReport  — renders a plan as a human readable text block.
#
# The planner is dependency free so it is trivially unit-testable, and the
# runner takes the deletion side effect as an injected scriptblock so tests
# do not need to talk to the real GitHub API.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [datetime]$Now = [datetime]::UtcNow
    )

    # Defensive policy validation — fail fast on nonsense inputs.
    if ($Policy.ContainsKey('MaxAgeDays') -and $Policy.MaxAgeDays -lt 0) {
        throw "Policy.MaxAgeDays must be >= 0 (got $($Policy.MaxAgeDays))"
    }
    if ($Policy.ContainsKey('MaxTotalSizeBytes') -and $Policy.MaxTotalSizeBytes -lt 0) {
        throw "Policy.MaxTotalSizeBytes must be >= 0"
    }
    if ($Policy.ContainsKey('KeepLatestPerWorkflow') -and $Policy.KeepLatestPerWorkflow -lt 0) {
        throw "Policy.KeepLatestPerWorkflow must be >= 0"
    }

    $toDelete = [System.Collections.Generic.List[object]]::new()
    # Work on a live set that we can shrink as policies fire.
    $remaining = [System.Collections.Generic.List[object]]::new()
    foreach ($a in $Artifacts) { $remaining.Add($a) | Out-Null }

    # 1. Age policy: anything older than MaxAgeDays goes.
    if ($Policy.ContainsKey('MaxAgeDays')) {
        $cutoff = $Now.AddDays(-[double]$Policy.MaxAgeDays)
        $kept = [System.Collections.Generic.List[object]]::new()
        foreach ($a in $remaining) {
            if ($a.Created -lt $cutoff) { $toDelete.Add($a) } else { $kept.Add($a) }
        }
        $remaining = $kept
    }

    # 2. Per-workflow retention: keep the N newest per WorkflowRunId.
    if ($Policy.ContainsKey('KeepLatestPerWorkflow')) {
        $n = [int]$Policy.KeepLatestPerWorkflow
        $kept = [System.Collections.Generic.List[object]]::new()
        $groups = $remaining | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $ordered = $g.Group | Sort-Object Created -Descending
            $keepSlice = $ordered | Select-Object -First $n
            $dropSlice = $ordered | Select-Object -Skip $n
            foreach ($k in $keepSlice) { $kept.Add($k) }
            foreach ($d in $dropSlice) { $toDelete.Add($d) }
        }
        $remaining = $kept
    }

    # 3. Total size: while over the cap, drop the oldest remaining.
    if ($Policy.ContainsKey('MaxTotalSizeBytes')) {
        $cap = [long]$Policy.MaxTotalSizeBytes
        $ordered = [System.Collections.Generic.List[object]]::new()
        foreach ($a in ($remaining | Sort-Object Created)) { $ordered.Add($a) | Out-Null }
        $total = ($ordered | Measure-Object -Property Size -Sum).Sum
        if ($null -eq $total) { $total = 0 }
        while ($total -gt $cap -and $ordered.Count -gt 0) {
            $victim = $ordered[0]
            $ordered.RemoveAt(0)
            $toDelete.Add($victim)
            $total -= $victim.Size
        }
        $remaining = $ordered
    }

    $reclaimed = 0L
    foreach ($d in $toDelete) { $reclaimed += [long]$d.Size }

    [pscustomobject]@{
        ToDelete = @($toDelete)
        ToKeep   = @($remaining)
        Summary  = @{
            DeletedCount   = $toDelete.Count
            RetainedCount  = $remaining.Count
            FailedCount    = 0
            TotalReclaimed = [long]$reclaimed
        }
    }
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [datetime]$Now = [datetime]::UtcNow,

        # Injected so tests don't need to hit the real API.
        [scriptblock]$DeleteAction = { param($a) },

        [switch]$DryRun
    )

    if ($null -eq $Artifacts) { throw "Artifacts must not be null" }

    $plan = Get-CleanupPlan -Artifacts $Artifacts -Policy $Policy -Now $Now
    $errors = [System.Collections.Generic.List[object]]::new()

    if (-not $DryRun) {
        foreach ($artifact in $plan.ToDelete) {
            try {
                & $DeleteAction $artifact
            } catch {
                $errors.Add([pscustomobject]@{
                    Name    = $artifact.Name
                    Message = $_.Exception.Message
                }) | Out-Null
            }
        }
    }

    $plan.Summary.FailedCount = $errors.Count
    [pscustomobject]@{
        ToDelete = $plan.ToDelete
        ToKeep   = $plan.ToKeep
        Summary  = $plan.Summary
        Errors   = @($errors)
        DryRun   = [bool]$DryRun
    }
}

function Format-CleanupReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Plan
    )
    $sb = [System.Text.StringBuilder]::new()
    $header = if ($Plan.DryRun) { '=== Artifact Cleanup Plan (DRY RUN) ===' }
              else              { '=== Artifact Cleanup Result ===' }
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine(("Deleted:   {0}" -f $Plan.Summary.DeletedCount))
    [void]$sb.AppendLine(("Retained:  {0}" -f $Plan.Summary.RetainedCount))
    [void]$sb.AppendLine(("Failed:    {0}" -f $Plan.Summary.FailedCount))
    [void]$sb.AppendLine(("Reclaimed: {0} bytes" -f $Plan.Summary.TotalReclaimed))
    if ($Plan.ToDelete.Count -gt 0) {
        [void]$sb.AppendLine("Artifacts to delete:")
        foreach ($a in $Plan.ToDelete) {
            [void]$sb.AppendLine(("  - {0} ({1} bytes, run {2}, created {3:o})" -f `
                $a.Name, $a.Size, $a.WorkflowRunId, $a.Created))
        }
    }
    $sb.ToString()
}

# CLI entrypoint — used by the GitHub Actions workflow. Reads a JSON fixture
# describing artifacts + policy, runs Invoke-ArtifactCleanup with an in-memory
# deleter, and prints the rendered report plus a machine-readable summary line.
function Invoke-Cli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FixturePath,
        [switch]$DryRun
    )
    if (-not (Test-Path $FixturePath)) {
        throw "Fixture not found: $FixturePath"
    }
    $raw = Get-Content -Raw -Path $FixturePath | ConvertFrom-Json
    $artifacts = @()
    foreach ($a in $raw.artifacts) {
        $artifacts += [pscustomobject]@{
            Name          = [string]$a.name
            Size          = [long]$a.size
            Created       = [datetime]::Parse($a.created, [cultureinfo]::InvariantCulture,
                              [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                              [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            WorkflowRunId = [string]$a.workflow_run_id
        }
    }
    $policy = @{}
    if ($null -ne $raw.policy) {
        foreach ($p in $raw.policy.PSObject.Properties) { $policy[$p.Name] = $p.Value }
    }
    $now = if ($raw.PSObject.Properties['now']) {
        [datetime]::Parse($raw.now, [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
            [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    } else { [datetime]::UtcNow }

    # In-CI there is no API; record what would have been deleted.
    $deleted = [System.Collections.Generic.List[string]]::new()
    $deleter = { param($a) $deleted.Add($a.Name) | Out-Null }.GetNewClosure()

    $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -Now $now `
        -DeleteAction $deleter -DryRun:$DryRun

    Write-Host (Format-CleanupReport -Plan $result)
    # Stable parser line for downstream assertions in the test harness.
    Write-Host ("SUMMARY deleted={0} retained={1} reclaimed={2} failed={3} dry_run={4}" -f `
        $result.Summary.DeletedCount, $result.Summary.RetainedCount,
        $result.Summary.TotalReclaimed, $result.Summary.FailedCount,
        $result.DryRun.ToString().ToLower())
    return $result
}

# Run CLI when invoked as a script (not dot-sourced into tests).
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # no-op: parameters handled via wrapper script
    }
}
