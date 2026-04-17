# ArtifactCleanup.psm1
#
# Applies retention policies to a list of artifacts and produces a deletion plan.
#
# Public functions:
#   Get-ArtifactCleanupPlan  - pure planner; no side effects
#   Invoke-ArtifactCleanup   - planner + optional deletion (injected action)
#   Read-ArtifactsFromJson   - load artifact metadata from a JSON file
#
# The planner is pure so it can be unit-tested without touching any real
# artifact store. Invoke-ArtifactCleanup takes a -DeleteAction scriptblock,
# which real callers would bind to `gh api --method DELETE` (or similar).
# Tests pass in a stub scriptblock to verify invocation behaviour.

Set-StrictMode -Version 3.0

# Helper: sum a property across a collection, returning 0 on empty input.
# StrictMode rejects .Sum when Measure-Object's result has no Sum property
# (empty input case), so we use an explicit loop instead.
function Get-SizeSum {
    param([System.Collections.IEnumerable]$Items)
    [long]$total = 0
    if ($null -eq $Items) { return $total }
    foreach ($i in $Items) { $total += [long]$i.SizeBytes }
    return $total
}

function Assert-ArtifactShape {
    param([pscustomobject]$Artifact)

    foreach ($field in 'Id', 'Name', 'SizeBytes', 'CreatedAt', 'WorkflowId') {
        if (-not ($Artifact.PSObject.Properties.Name -contains $field)) {
            throw "Artifact is missing required field '$field'."
        }
    }
}

function Get-ArtifactCleanupPlan {
    <#
    .SYNOPSIS
    Build a retention plan from a list of artifacts and policy parameters.

    .DESCRIPTION
    Applies the following policies (in this conceptual order):
      1. KeepLatestNPerWorkflow: protects the newest N artifacts per workflow
         from any deletion.
      2. MaxAgeDays: artifacts older than this are candidates for deletion.
      3. MaxTotalSizeBytes: if the retained set still exceeds this cap,
         delete additional oldest artifacts until the cap is met.
    KeepLatestN always wins, so it cannot be violated by any other rule.

    .PARAMETER Artifacts
    An array of artifact objects. Each must have Id, Name, SizeBytes,
    CreatedAt (datetime) and WorkflowId properties.

    .PARAMETER MaxAgeDays
    Artifacts older than this many days are candidates for deletion.

    .PARAMETER MaxTotalSizeBytes
    Optional cap on the total retained size. 0 (or unset) means "no cap".

    .PARAMETER KeepLatestNPerWorkflow
    Always retain the newest N artifacts per workflow. 0 means "no floor".

    .PARAMETER Now
    Optional "now" reference; defaults to the current UTC time. Tests pass
    a fixed value to keep assertions deterministic.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [long]$MaxTotalSizeBytes = 0,

        [int]$KeepLatestNPerWorkflow = 0,

        [datetime]$Now = (Get-Date).ToUniversalTime()
    )

    if ($MaxAgeDays -lt 0) {
        throw [System.ArgumentOutOfRangeException]::new('MaxAgeDays', 'MaxAgeDays must be >= 0.')
    }
    if ($MaxTotalSizeBytes -lt 0) {
        throw [System.ArgumentOutOfRangeException]::new('MaxTotalSizeBytes', 'MaxTotalSizeBytes must be >= 0.')
    }
    if ($KeepLatestNPerWorkflow -lt 0) {
        throw [System.ArgumentOutOfRangeException]::new('KeepLatestNPerWorkflow', 'KeepLatestNPerWorkflow must be >= 0.')
    }

    foreach ($a in $Artifacts) { Assert-ArtifactShape -Artifact $a }

    # Build a "protected by KeepLatestN" lookup: set of artifact IDs that
    # no policy is allowed to delete. Per-workflow, newest-first, take N.
    $protectedIds = New-Object 'System.Collections.Generic.HashSet[object]'
    if ($KeepLatestNPerWorkflow -gt 0 -and $Artifacts.Count -gt 0) {
        $grouped = $Artifacts | Group-Object -Property WorkflowId
        foreach ($g in $grouped) {
            $sorted = $g.Group | Sort-Object -Property CreatedAt -Descending
            $sorted | Select-Object -First $KeepLatestNPerWorkflow | ForEach-Object {
                [void]$protectedIds.Add($_.Id)
            }
        }
    }

    $ageThreshold = $Now.AddDays(-$MaxAgeDays)

    # Pass 1: age policy. An artifact is a candidate for deletion if it is
    # older than the threshold AND not protected.
    $deleted  = New-Object System.Collections.Generic.List[object]
    $retained = New-Object System.Collections.Generic.List[object]
    foreach ($a in $Artifacts) {
        $created = [datetime]$a.CreatedAt
        if ($created -lt $ageThreshold -and -not $protectedIds.Contains($a.Id)) {
            $deleted.Add($a)
        } else {
            $retained.Add($a)
        }
    }

    # Pass 2: size policy. If retained total still exceeds cap, delete
    # additional oldest non-protected artifacts until cap is met (or no
    # more are eligible).
    if ($MaxTotalSizeBytes -gt 0) {
        $totalSize = Get-SizeSum -Items $retained
        if ($totalSize -gt $MaxTotalSizeBytes) {
            # Order retained oldest-first so we peel off the oldest first,
            # but skip protected artifacts.
            $eligible = $retained | Where-Object { -not $protectedIds.Contains($_.Id) } |
                Sort-Object -Property CreatedAt
            foreach ($a in $eligible) {
                if ($totalSize -le $MaxTotalSizeBytes) { break }
                [void]$retained.Remove($a)
                $deleted.Add($a)
                $totalSize -= [long]$a.SizeBytes
            }
        }
    }

    $reclaimed = Get-SizeSum -Items $deleted
    $kept      = Get-SizeSum -Items $retained

    [pscustomobject]@{
        Retained = $retained.ToArray()
        Deleted  = $deleted.ToArray()
        Summary  = [pscustomobject]@{
            RetainedCount       = $retained.Count
            DeletedCount        = $deleted.Count
            SpaceReclaimedBytes = [long]$reclaimed
            RetainedSizeBytes   = [long]$kept
            TotalSizeBytes      = [long]($reclaimed + $kept)
        }
    }
}

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
    Build a plan then (optionally) execute deletions via an injected action.

    .PARAMETER DeleteAction
    A scriptblock invoked once per artifact scheduled for deletion. In
    production this would call `gh api --method DELETE`. In tests it is a
    stub that records calls so assertions can verify behaviour without
    performing real deletions.

    .PARAMETER DryRun
    If set, the plan is returned but DeleteAction is not invoked.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [long]$MaxTotalSizeBytes = 0,
        [int]$KeepLatestNPerWorkflow = 0,
        [datetime]$Now = (Get-Date).ToUniversalTime(),
        [switch]$DryRun,
        [scriptblock]$DeleteAction = { param($a) }
    )

    $plan = Get-ArtifactCleanupPlan `
        -Artifacts $Artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestNPerWorkflow $KeepLatestNPerWorkflow `
        -Now $Now

    $errors = New-Object System.Collections.Generic.List[object]

    if (-not $DryRun) {
        foreach ($a in $plan.Deleted) {
            try {
                & $DeleteAction $a
            } catch {
                # Capture, report, and continue — a transient failure on one
                # artifact must not stop the rest of the cleanup.
                $errors.Add([pscustomobject]@{ Artifact = $a; Error = $_.Exception.Message })
                Write-Error "Failed to delete artifact $($a.Id) ($($a.Name)): $($_.Exception.Message)"
            }
        }
    }

    # Attach execution metadata to the plan and return it.
    [pscustomobject]@{
        Retained = $plan.Retained
        Deleted  = $plan.Deleted
        Summary  = $plan.Summary
        DryRun   = [bool]$DryRun
        Errors   = $errors.ToArray()
    }
}

function Read-ArtifactsFromJson {
    <#
    .SYNOPSIS
    Read artifact metadata from a JSON file and coerce fields to strict types.

    .DESCRIPTION
    Accepts a JSON array of objects with keys: id, name, sizeBytes, createdAt,
    workflowId. Casting is explicit so downstream arithmetic and date
    comparisons are safe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Artifacts JSON file not found at path: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $data = $raw | ConvertFrom-Json

    # Tolerate either a top-level array or an object with an "artifacts" key.
    if ($data.PSObject.Properties.Name -contains 'artifacts') {
        $data = $data.artifacts
    }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($r in $data) {
        $out.Add([pscustomobject]@{
            Id         = $r.id
            Name       = [string]$r.name
            SizeBytes  = [long]$r.sizeBytes
            CreatedAt  = ([datetime]$r.createdAt).ToUniversalTime()
            WorkflowId = [string]$r.workflowId
        })
    }
    return ,$out.ToArray()
}

Export-ModuleMember -Function Get-ArtifactCleanupPlan, Invoke-ArtifactCleanup, Read-ArtifactsFromJson
