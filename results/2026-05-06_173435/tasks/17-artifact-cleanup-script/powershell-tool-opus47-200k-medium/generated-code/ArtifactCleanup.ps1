# ArtifactCleanup.ps1
# Apply retention policies to artifact metadata and produce a deletion plan.
#
# Approach: pure functions over arrays of artifact records (PSCustomObject).
# Each artifact: Name (string), Size (long, bytes), CreatedAt (DateTime),
# WorkflowRunId (string|int). Policies are independent filters; an artifact
# is deleted if ANY policy marks it for deletion.

$ErrorActionPreference = 'Stop'

function Get-ArtifactsToDelete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Artifacts,
        [object]   $MaxAgeDays    = $null,
        [object]   $MaxTotalBytes = $null,
        [object]   $KeepLatestPerWorkflow = $null,
        [DateTime] $Now = [DateTime]::UtcNow
    )

    foreach ($a in $Artifacts) {
        foreach ($p in 'Name','Size','CreatedAt','WorkflowRunId') {
            if (-not $a.PSObject.Properties[$p]) {
                throw "Artifact missing required property '$p'"
            }
        }
        if ($a.Size -lt 0) { throw "Artifact '$($a.Name)' has negative Size" }
    }

    $toDelete = [System.Collections.Generic.HashSet[string]]::new()

    # Policy 1: max age
    if ($null -ne $MaxAgeDays) {
        $cutoff = $Now.AddDays(-[int]$MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ($a.CreatedAt -lt $cutoff) { [void]$toDelete.Add($a.Name) }
        }
    }

    # Policy 2: keep latest N per workflow run id (delete the rest)
    if ($null -ne $KeepLatestPerWorkflow) {
        $keepN = [int]$KeepLatestPerWorkflow
        $groups = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $sorted = @($g.Group | Sort-Object -Property CreatedAt -Descending)
            if ($sorted.Count -gt $keepN) {
                foreach ($extra in ($sorted | Select-Object -Skip $keepN)) {
                    [void]$toDelete.Add($extra.Name)
                }
            }
        }
    }

    # Policy 3: max total size — keep newest first; once cumulative size
    # exceeds the cap, mark the rest (older) for deletion.
    if ($null -ne $MaxTotalBytes) {
        $cap = [long]$MaxTotalBytes
        $survivors = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) } |
            Sort-Object -Property CreatedAt -Descending)
        $running = [long]0
        foreach ($a in $survivors) {
            $running += [long]$a.Size
            if ($running -gt $cap) {
                [void]$toDelete.Add($a.Name)
            }
        }
    }

    return ,@($Artifacts | Where-Object { $toDelete.Contains($_.Name) })
}

function New-DeletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Artifacts,
        [object]   $MaxAgeDays    = $null,
        [object]   $MaxTotalBytes = $null,
        [object]   $KeepLatestPerWorkflow = $null,
        [switch]   $DryRun,
        [DateTime] $Now = [DateTime]::UtcNow
    )

    $deleted = Get-ArtifactsToDelete -Artifacts $Artifacts `
        -MaxAgeDays $MaxAgeDays -MaxTotalBytes $MaxTotalBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow -Now $Now

    $deletedNames = @($deleted | ForEach-Object { $_.Name })
    $retained = @($Artifacts | Where-Object { $deletedNames -notcontains $_.Name })

    $reclaimed = [long]0
    foreach ($d in $deleted) { $reclaimed += [long]$d.Size }

    [PSCustomObject]@{
        DryRun           = [bool]$DryRun
        TotalArtifacts   = $Artifacts.Count
        DeletedCount     = $deleted.Count
        RetainedCount    = $retained.Count
        BytesReclaimed   = $reclaimed
        Deleted          = $deleted
        Retained         = $retained
    }
}

function Format-PlanSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Plan)
    $mode = if ($Plan.DryRun) { 'DRY-RUN' } else { 'EXECUTE' }
    $lines = @(
        "Mode: $mode",
        "Total artifacts: $($Plan.TotalArtifacts)",
        "Deleted: $($Plan.DeletedCount)",
        "Retained: $($Plan.RetainedCount)",
        "Bytes reclaimed: $($Plan.BytesReclaimed)"
    )
    foreach ($d in $Plan.Deleted) { $lines += "DELETE: $($d.Name) ($($d.Size) bytes)" }
    foreach ($r in $Plan.Retained) { $lines += "KEEP:   $($r.Name) ($($r.Size) bytes)" }
    return ($lines -join "`n")
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $FixturePath,
        [object]   $MaxAgeDays    = $null,
        [object]   $MaxTotalBytes = $null,
        [object]   $KeepLatestPerWorkflow = $null,
        [switch]   $DryRun,
        [DateTime] $Now = [DateTime]::UtcNow
    )
    if (-not (Test-Path $FixturePath)) {
        throw "Fixture file not found: $FixturePath"
    }
    $raw = Get-Content -Raw -Path $FixturePath | ConvertFrom-Json
    $artifacts = foreach ($a in $raw) {
        [PSCustomObject]@{
            Name          = [string]$a.Name
            Size          = [long]$a.Size
            CreatedAt     = [DateTime]::Parse($a.CreatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            WorkflowRunId = [string]$a.WorkflowRunId
        }
    }
    $plan = New-DeletionPlan -Artifacts @($artifacts) `
        -MaxAgeDays $MaxAgeDays -MaxTotalBytes $MaxTotalBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow -DryRun:$DryRun -Now $Now
    Write-Output (Format-PlanSummary -Plan $plan)
    return $plan
}
