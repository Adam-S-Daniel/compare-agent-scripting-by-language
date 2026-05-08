# ArtifactCleanup.ps1
#
# Library script that exposes three functions:
#   Get-CleanupPlan       - pure planner; given artifacts and policy knobs,
#                           returns @{ Delete; Retain; Summary } with no I/O.
#   Invoke-CleanupPlan    - executes a plan by calling -OnDelete for each
#                           item to remove (skipped under -DryRun).
#   Invoke-ArtifactCleanup- end-to-end driver: read JSON, plan, write JSON.
#
# Policy ordering (each pass adds reasons; an artifact may carry several):
#   1. MaxAgeDays              - mark artifacts older than N days.
#   2. KeepLatestPerWorkflow   - per workflow run id, keep newest N.
#   3. MaxTotalSizeBytes       - of the survivors, evict oldest until total
#                                size <= cap.
#
# Each policy parameter accepts 0/empty to mean "disabled". The summary block
# includes deleted/retained counts and total bytes reclaimed so callers (and
# our workflow output parser) can assert exact values.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Artifact {
    # Normalize a raw artifact (e.g. parsed from JSON) to the canonical shape
    # used by the planner. Tolerates string CreatedAt and various size fields.
    param([Parameter(Mandatory)] $Raw)

    $created = $Raw.CreatedAt
    if ($created -is [string]) {
        $created = [datetime]::Parse($created, [cultureinfo]::InvariantCulture).ToUniversalTime()
    } elseif ($created -is [datetime]) {
        $created = $created.ToUniversalTime()
    } else {
        throw "Artifact '$($Raw.Name)' has no parseable CreatedAt"
    }

    [pscustomobject]@{
        Name          = [string] $Raw.Name
        SizeBytes     = [long]   $Raw.SizeBytes
        CreatedAt     = $created
        WorkflowRunId = [string] $Raw.WorkflowRunId
        Reasons       = [System.Collections.Generic.List[string]]::new()
    }
}

function Get-CleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Artifacts,
        [int]      $MaxAgeDays = 0,
        [long]     $MaxTotalSizeBytes = 0,
        [int]      $KeepLatestPerWorkflow = 0,
        [datetime] $Now = (Get-Date).ToUniversalTime()
    )

    # Normalize once so downstream policies all see the same shape.
    $items = @()
    foreach ($a in $Artifacts) { $items += ConvertTo-Artifact -Raw $a }

    # Track deletion state on a parallel set so an artifact only appears in
    # one of the two output buckets even when several policies fire on it.
    $deleted = New-Object 'System.Collections.Generic.HashSet[string]'

    # --- 1) MaxAgeDays --------------------------------------------------
    if ($MaxAgeDays -gt 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($item in $items) {
            if ($item.CreatedAt -lt $cutoff) {
                [void] $item.Reasons.Add('MaxAgeDays')
                [void] $deleted.Add($item.Name)
            }
        }
    }

    # --- 2) KeepLatestPerWorkflow ---------------------------------------
    # Group survivors by workflow run; within each group, sort newest-first
    # and mark anything past index N for deletion.
    if ($KeepLatestPerWorkflow -gt 0) {
        $survivors = $items | Where-Object { -not $deleted.Contains($_.Name) }
        $groups = $survivors | Group-Object -Property WorkflowRunId
        foreach ($group in $groups) {
            $sorted = $group.Group | Sort-Object -Property CreatedAt -Descending
            for ($i = $KeepLatestPerWorkflow; $i -lt $sorted.Count; $i++) {
                $victim = $sorted[$i]
                [void] $victim.Reasons.Add('KeepLatestPerWorkflow')
                [void] $deleted.Add($victim.Name)
            }
        }
    }

    # --- 3) MaxTotalSizeBytes -------------------------------------------
    # Sum survivors. If over cap, evict from oldest until at or under cap.
    if ($MaxTotalSizeBytes -gt 0) {
        $survivors = $items | Where-Object { -not $deleted.Contains($_.Name) } |
                     Sort-Object -Property CreatedAt
        $total = ($survivors | Measure-Object -Property SizeBytes -Sum).Sum
        if ($null -eq $total) { $total = 0 }
        $idx = 0
        while ($total -gt $MaxTotalSizeBytes -and $idx -lt $survivors.Count) {
            $victim = $survivors[$idx]
            [void] $victim.Reasons.Add('MaxTotalSizeBytes')
            [void] $deleted.Add($victim.Name)
            $total -= $victim.SizeBytes
            $idx++
        }
    }

    $deleteList = @($items | Where-Object { $deleted.Contains($_.Name) })
    $retainList = @($items | Where-Object { -not $deleted.Contains($_.Name) })

    $reclaimed = 0L
    if ($deleteList.Count -gt 0) {
        $reclaimed = [long](($deleteList | Measure-Object -Property SizeBytes -Sum).Sum)
    }
    $retainedBytes = 0L
    if ($retainList.Count -gt 0) {
        $retainedBytes = [long](($retainList | Measure-Object -Property SizeBytes -Sum).Sum)
    }

    [pscustomobject]@{
        Delete  = $deleteList
        Retain  = $retainList
        Summary = [pscustomobject]@{
            DeletedCount        = $deleteList.Count
            RetainedCount       = $retainList.Count
            TotalReclaimedBytes = $reclaimed
            RetainedBytes       = $retainedBytes
        }
    }
}

function Invoke-CleanupPlan {
    # Walks Plan.Delete and invokes the supplied callback for each artifact.
    # In dry-run mode the callback is never called -- the caller still gets
    # back an executed-flag so it can log whatever happened.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Plan,
        [scriptblock] $OnDelete = { param($a) },
        [switch] $DryRun
    )
    $performed = 0
    if (-not $DryRun) {
        foreach ($artifact in $Plan.Delete) {
            & $OnDelete $artifact
            $performed++
        }
    }
    [pscustomobject]@{
        DryRun    = [bool]$DryRun
        Performed = $performed
        Planned   = $Plan.Delete.Count
    }
}

function Invoke-ArtifactCleanup {
    # End-to-end driver used by the CLI / workflow:
    #   - read input JSON (array of artifacts)
    #   - call Get-CleanupPlan
    #   - serialize the plan + summary to OutputPath (if given)
    #   - print a one-line SUMMARY: marker that the workflow harness greps
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputPath,
        [string]   $OutputPath,
        [int]      $MaxAgeDays = 0,
        [long]     $MaxTotalSizeBytes = 0,
        [int]      $KeepLatestPerWorkflow = 0,
        [datetime] $Now = (Get-Date).ToUniversalTime(),
        [switch]   $DryRun
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input file not found: $InputPath"
    }

    $raw = Get-Content -LiteralPath $InputPath -Raw
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$InputPath': $($_.Exception.Message)"
    }

    # ConvertFrom-Json returns a single object for a singleton array - normalize.
    if ($parsed -isnot [System.Collections.IEnumerable] -or $parsed -is [string]) {
        $parsed = @($parsed)
    }

    $plan = Get-CleanupPlan -Artifacts $parsed `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
        -Now $Now

    $output = [pscustomobject]@{
        DryRun  = [bool]$DryRun
        Now     = $Now.ToString('o')
        Policy  = [pscustomobject]@{
            MaxAgeDays            = $MaxAgeDays
            MaxTotalSizeBytes     = $MaxTotalSizeBytes
            KeepLatestPerWorkflow = $KeepLatestPerWorkflow
        }
        Delete  = $plan.Delete
        Retain  = $plan.Retain
        Summary = $plan.Summary
    }

    if ($OutputPath) {
        $json = $output | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
    }

    # Stable single-line markers the workflow asserts on. Keep this format
    # frozen -- the act harness regex matches it exactly.
    Write-Host ("SUMMARY: deleted={0} retained={1} reclaimed_bytes={2} dry_run={3}" -f `
        $plan.Summary.DeletedCount,
        $plan.Summary.RetainedCount,
        $plan.Summary.TotalReclaimedBytes,
        ([bool]$DryRun).ToString().ToLowerInvariant())

    return $output
}
