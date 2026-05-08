# Invoke-ArtifactCleanup.ps1
# Compute a deletion plan for CI/CD artifacts based on retention policies.
# Policies (all optional, but at least one is expected):
#   -MaxAgeDays N             : delete artifacts older than N days
#   -MaxTotalSize N           : after other rules, delete oldest until total <= N bytes
#   -KeepLatestNPerWorkflow N : per workflow run id, keep newest N, delete the rest
# -DryRun makes the summary advertise dry-run; the plan itself is identical.

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ArtifactCleanupPlan {
    [CmdletBinding()]
    param(
        # Each element must have: Name (string), Size (long, bytes),
        # CreatedAt (datetime), WorkflowRunId (string/int).
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Nullable[int]]$MaxAgeDays = $null,
        [Nullable[long]]$MaxTotalSize = $null,
        [Nullable[int]]$KeepLatestNPerWorkflow = $null,

        [datetime]$Now = (Get-Date),

        [switch]$DryRun
    )

    # Validate input rows up-front so callers get a clear error.
    foreach ($a in $Artifacts) {
        foreach ($prop in 'Name', 'Size', 'CreatedAt', 'WorkflowRunId') {
            if (-not ($a.PSObject.Properties.Name -contains $prop)) {
                throw "Artifact is missing required property '$prop': $($a | ConvertTo-Json -Compress)"
            }
        }
        if ($a.Size -lt 0) {
            throw "Artifact '$($a.Name)' has negative Size: $($a.Size)"
        }
    }

    # Track deletion state and reason on a clone so we don't mutate caller data.
    $items = foreach ($a in $Artifacts) {
        [pscustomobject]@{
            Name          = $a.Name
            Size          = [long]$a.Size
            CreatedAt     = [datetime]$a.CreatedAt
            WorkflowRunId = "$($a.WorkflowRunId)"
            Delete        = $false
            Reason        = $null
        }
    }

    # Rule 1: max age. Anything older than the cutoff is marked.
    if ($null -ne $MaxAgeDays) {
        $cutoff = $Now.AddDays(-[int]$MaxAgeDays)
        foreach ($i in $items) {
            if (-not $i.Delete -and $i.CreatedAt -lt $cutoff) {
                $i.Delete = $true
                $i.Reason = "older than $MaxAgeDays days"
            }
        }
    }

    # Rule 2: keep latest N per workflow. Group by workflow, sort newest first,
    # everything past index N is marked. Operates on rows that survived rule 1.
    if ($null -ne $KeepLatestNPerWorkflow) {
        $n = [int]$KeepLatestNPerWorkflow
        $groups = $items | Where-Object { -not $_.Delete } | Group-Object WorkflowRunId
        foreach ($g in $groups) {
            $sorted = $g.Group | Sort-Object CreatedAt -Descending
            for ($idx = $n; $idx -lt $sorted.Count; $idx++) {
                $sorted[$idx].Delete = $true
                $sorted[$idx].Reason = "keep-latest-$n per workflow"
            }
        }
    }

    # Rule 3: max total size. Delete oldest survivors until retained <= cap.
    # NOTE: avoid `Measure-Object -Property` here — under StrictMode it errors
    # on empty input because no property is present in the pipeline.
    if ($null -ne $MaxTotalSize) {
        $cap = [long]$MaxTotalSize
        $survivors = @($items | Where-Object { -not $_.Delete } | Sort-Object CreatedAt)
        $retainedSize = 0L
        foreach ($s in $survivors) { $retainedSize += $s.Size }
        $i = 0
        while ($retainedSize -gt $cap -and $i -lt $survivors.Count) {
            $survivors[$i].Delete = $true
            $survivors[$i].Reason = "total size cap $cap bytes"
            $retainedSize -= $survivors[$i].Size
            $i++
        }
    }

    $toDelete = @($items | Where-Object { $_.Delete })
    $toRetain = @($items | Where-Object { -not $_.Delete })
    $reclaimed = 0L
    foreach ($d in $toDelete) { $reclaimed += $d.Size }

    [pscustomobject]@{
        ToDelete = $toDelete
        ToRetain = $toRetain
        Summary  = [pscustomobject]@{
            DeletedCount    = $toDelete.Count
            RetainedCount   = $toRetain.Count
            SpaceReclaimed  = [long]$reclaimed
            DryRun          = [bool]$DryRun
        }
    }
}

function Format-CleanupPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Plan)

    $lines = @()
    $lines += "=== Artifact Cleanup Plan ==="
    $lines += "DryRun:         $($Plan.Summary.DryRun)"
    $lines += "DeletedCount:   $($Plan.Summary.DeletedCount)"
    $lines += "RetainedCount:  $($Plan.Summary.RetainedCount)"
    $lines += "SpaceReclaimed: $($Plan.Summary.SpaceReclaimed) bytes"
    $lines += "--- To delete ---"
    foreach ($d in $Plan.ToDelete) {
        $lines += "DELETE name=$($d.Name) size=$($d.Size) wf=$($d.WorkflowRunId) reason='$($d.Reason)'"
    }
    $lines += "--- To retain ---"
    foreach ($r in $Plan.ToRetain) {
        $lines += "KEEP   name=$($r.Name) size=$($r.Size) wf=$($r.WorkflowRunId)"
    }
    $lines -join [Environment]::NewLine
}

function Invoke-FromCli {
    param(
        [string]$FixturePath,
        [Nullable[int]]$MaxAgeDays,
        [Nullable[long]]$MaxTotalSize,
        [Nullable[int]]$KeepLatestNPerWorkflow,
        [datetime]$Now = (Get-Date),
        [switch]$DryRun
    )
    if (-not (Test-Path $FixturePath)) {
        throw "Fixture file not found: $FixturePath"
    }
    $raw = Get-Content -Raw -Path $FixturePath | ConvertFrom-Json
    # CreatedAt arrives as ISO-8601 string from JSON; coerce to [datetime].
    $artifacts = foreach ($a in $raw) {
        [pscustomobject]@{
            Name          = $a.Name
            Size          = [long]$a.Size
            CreatedAt     = [datetime]::Parse($a.CreatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            WorkflowRunId = "$($a.WorkflowRunId)"
        }
    }
    $params = @{ Artifacts = @($artifacts); Now = $Now; DryRun = $DryRun }
    if ($null -ne $MaxAgeDays)             { $params.MaxAgeDays             = $MaxAgeDays }
    if ($null -ne $MaxTotalSize)           { $params.MaxTotalSize           = $MaxTotalSize }
    if ($null -ne $KeepLatestNPerWorkflow) { $params.KeepLatestNPerWorkflow = $KeepLatestNPerWorkflow }
    Get-ArtifactCleanupPlan @params
}
