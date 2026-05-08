Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Artifact-cleanup module.
#
# Public surface:
#   New-Artifact            - normalize a single artifact record (test fixture builder).
#   Get-CleanupPlan         - apply retention policies and return { Keep; Delete; Summary }.
#   Format-CleanupPlanText  - render a plan as a stable, greppable text report.
#   Invoke-ArtifactCleanup  - end-to-end entry: read fixture JSON, run plan, print report.
#
# Policy semantics (composable; an artifact lands in Delete if any rule fires):
#   age   : artifact older than -MaxAgeDays from -Now (default: utcnow).
#   count : within each WorkflowRunId, only the -KeepLatestPerWorkflow most recent
#           survive this rule. Older ones in the group are marked 'count'.
#   size  : if the kept-set total still exceeds -MaxTotalSizeBytes after the above,
#           drop the oldest kept artifacts until it fits.
#
# The Reasons array on each deleted artifact carries every rule that fired, so
# downstream tooling can audit *why* something was scheduled for deletion. An
# artifact with no reasons is kept; an artifact never appears in both lists.

function New-Artifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [long]   $Size,
        [Parameter(Mandatory)] [string] $CreatedAt,
        [Parameter(Mandatory)] [string] $WorkflowRunId
    )
    [pscustomobject]@{
        Name          = $Name
        Size          = [long]$Size
        # Always normalize to UTC so day-arithmetic with -Now is timezone-agnostic.
        CreatedAt     = [datetime]::Parse($CreatedAt, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
        WorkflowRunId = $WorkflowRunId
    }
}

function Get-CleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Artifacts,
        [int]      $MaxAgeDays = 0,
        [long]     $MaxTotalSizeBytes = 0,
        [int]      $KeepLatestPerWorkflow = 0,
        [datetime] $Now = ([datetime]::UtcNow),
        [switch]   $DryRun
    )

    # Build a working set of records that carries a Reasons list per artifact.
    # Using ArrayList keeps the list mutable per-record without rebuilding objects.
    $records = foreach ($a in $Artifacts) {
        [pscustomobject]@{
            Name          = $a.Name
            Size          = [long]$a.Size
            CreatedAt     = [datetime]$a.CreatedAt
            WorkflowRunId = $a.WorkflowRunId
            Reasons       = [System.Collections.ArrayList]::new()
        }
    }

    # Rule 1: age. An artifact older than the cutoff is marked but stays in $records;
    # later rules can layer additional reasons on top.
    if ($MaxAgeDays -gt 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($r in $records) {
            if ($r.CreatedAt -lt $cutoff) { [void]$r.Reasons.Add('age') }
        }
    }

    # Rule 2: keep-latest-N per workflow. Group by run id, sort by date desc, mark
    # everything past the Nth.
    if ($KeepLatestPerWorkflow -gt 0) {
        $groups = $records | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $sorted = @($g.Group | Sort-Object -Property CreatedAt -Descending)
            for ($i = $KeepLatestPerWorkflow; $i -lt $sorted.Count; $i++) {
                if ('count' -notin $sorted[$i].Reasons) { [void]$sorted[$i].Reasons.Add('count') }
            }
        }
    }

    # Rule 3: max total size on the *kept* set. Compute current kept-set size; if
    # it overshoots, evict oldest-first until it fits. We add 'size' to the
    # eviction's Reasons even if 'age' or 'count' already applied.
    if ($MaxTotalSizeBytes -gt 0) {
        $kept = @($records | Where-Object { $_.Reasons.Count -eq 0 } | Sort-Object -Property CreatedAt)
        # Measure-Object on an empty pipeline returns an object whose Sum property
        # is absent under StrictMode 3, so guard with a manual fold.
        $currentSize = 0
        foreach ($k in $kept) { $currentSize += [long]$k.Size }
        $i = 0
        while ($currentSize -gt $MaxTotalSizeBytes -and $i -lt $kept.Count) {
            $victim = $kept[$i]
            [void]$victim.Reasons.Add('size')
            $currentSize -= $victim.Size
            $i++
        }
    }

    $delete = @($records | Where-Object { $_.Reasons.Count -gt 0 })
    $keep   = @($records | Where-Object { $_.Reasons.Count -eq 0 })

    $reclaimed = 0
    foreach ($d in $delete) { $reclaimed += [long]$d.Size }

    [pscustomobject]@{
        Keep    = $keep
        Delete  = $delete
        Summary = [pscustomobject]@{
            TotalArtifacts       = $records.Count
            KeptCount            = $keep.Count
            DeletedCount         = $delete.Count
            TotalReclaimedBytes  = [long]$reclaimed
            DryRun               = [bool]$DryRun
            Now                  = $Now
            Policies             = [pscustomobject]@{
                MaxAgeDays            = $MaxAgeDays
                MaxTotalSizeBytes     = $MaxTotalSizeBytes
                KeepLatestPerWorkflow = $KeepLatestPerWorkflow
            }
        }
    }
}

function Format-CleanupPlanText {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object] $Plan)

    $lines = [System.Collections.Generic.List[string]]::new()
    $s = $Plan.Summary

    $lines.Add('=== ARTIFACT-CLEANUP-SUMMARY ===')
    $lines.Add("TotalArtifacts=$($s.TotalArtifacts)")
    $lines.Add("KeptCount=$($s.KeptCount)")
    $lines.Add("DeletedCount=$($s.DeletedCount)")
    $lines.Add("TotalReclaimedBytes=$($s.TotalReclaimedBytes)")
    $lines.Add("DryRun=$($s.DryRun)")
    $lines.Add("Policy.MaxAgeDays=$($s.Policies.MaxAgeDays)")
    $lines.Add("Policy.MaxTotalSizeBytes=$($s.Policies.MaxTotalSizeBytes)")
    $lines.Add("Policy.KeepLatestPerWorkflow=$($s.Policies.KeepLatestPerWorkflow)")

    $lines.Add('--- DELETE ---')
    foreach ($d in ($Plan.Delete | Sort-Object Name)) {
        $reasons = ($d.Reasons -join '+')
        $lines.Add("DELETE name=$($d.Name) size=$($d.Size) workflow=$($d.WorkflowRunId) reasons=$reasons")
    }
    $lines.Add('--- KEEP ---')
    foreach ($k in ($Plan.Keep | Sort-Object Name)) {
        $lines.Add("KEEP name=$($k.Name) size=$($k.Size) workflow=$($k.WorkflowRunId)")
    }
    $lines.Add('=== END-ARTIFACT-CLEANUP-SUMMARY ===')

    return ($lines -join [Environment]::NewLine)
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputPath,
        [int]      $MaxAgeDays = 0,
        [long]     $MaxTotalSizeBytes = 0,
        [int]      $KeepLatestPerWorkflow = 0,
        [datetime] $Now = ([datetime]::UtcNow),
        [switch]   $DryRun
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Artifact fixture not found at path: $InputPath"
    }

    $raw = Get-Content -LiteralPath $InputPath -Raw -ErrorAction Stop
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$InputPath': $($_.Exception.Message)"
    }

    # Allow either the bare array form or a wrapper object that carries
    # policy overrides alongside the artifacts list.
    $artifactList = if ($parsed -is [System.Array]) { $parsed }
                    elseif ($parsed.PSObject.Properties.Name -contains 'artifacts') { $parsed.artifacts }
                    else { throw "Input JSON must be an array or an object with an 'artifacts' field." }

    if ($parsed -isnot [System.Array]) {
        if ($parsed.PSObject.Properties.Name -contains 'maxAgeDays' -and $MaxAgeDays -eq 0) {
            $MaxAgeDays = [int]$parsed.maxAgeDays
        }
        if ($parsed.PSObject.Properties.Name -contains 'maxTotalSizeBytes' -and $MaxTotalSizeBytes -eq 0) {
            $MaxTotalSizeBytes = [long]$parsed.maxTotalSizeBytes
        }
        if ($parsed.PSObject.Properties.Name -contains 'keepLatestPerWorkflow' -and $KeepLatestPerWorkflow -eq 0) {
            $KeepLatestPerWorkflow = [int]$parsed.keepLatestPerWorkflow
        }
        if ($parsed.PSObject.Properties.Name -contains 'now') {
            $Now = [datetime]::Parse($parsed.now, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
        }
        if ($parsed.PSObject.Properties.Name -contains 'dryRun' -and -not $DryRun) {
            $DryRun = [bool]$parsed.dryRun
        }
    }

    $artifacts = foreach ($a in $artifactList) {
        New-Artifact -Name $a.name -Size $a.size -CreatedAt $a.createdAt -WorkflowRunId $a.workflowRunId
    }

    $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
        -Now $Now -DryRun:$DryRun

    return $plan
}

Export-ModuleMember -Function New-Artifact, Get-CleanupPlan, Format-CleanupPlanText, Invoke-ArtifactCleanup
