# ArtifactCleanup.psm1
# Implements artifact retention policy evaluation and a dry-run-capable cleanup driver.
# Approach: pure functions for policy evaluation produce a "plan"; an orchestrator
# function applies (or skips) the plan via an injectable DeleteAction scriptblock.
# All time math uses an injectable -Now to keep tests deterministic.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Artifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][long]$SizeBytes,
        [Parameter(Mandatory)][string]$CreatedAt,
        [Parameter(Mandatory)][string]$WorkflowRunId
    )
    [pscustomobject]@{
        Name          = $Name
        SizeBytes     = $SizeBytes
        CreatedAt     = [datetime]::Parse($CreatedAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
        WorkflowRunId = $WorkflowRunId
    }
}

function New-CleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Artifacts,
        [int]$MaxAgeDays = -1,
        [long]$MaxTotalSizeBytes = -1,
        [int]$KeepLatestPerWorkflow = -1,
        [datetime]$Now = (Get-Date).ToUniversalTime()
    )

    if ($PSBoundParameters.ContainsKey('MaxAgeDays') -and $MaxAgeDays -lt 0) {
        throw "MaxAgeDays must be >= 0 (got $MaxAgeDays)"
    }
    if ($PSBoundParameters.ContainsKey('KeepLatestPerWorkflow') -and $KeepLatestPerWorkflow -lt 0) {
        throw "KeepLatestPerWorkflow must be >= 0 (got $KeepLatestPerWorkflow)"
    }

    $toDelete = New-Object 'System.Collections.Generic.HashSet[string]'

    # Policy 1: age
    if ($MaxAgeDays -ge 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ($a.CreatedAt -lt $cutoff) { [void]$toDelete.Add($a.Name) }
        }
    }

    # Policy 2: keep latest N per workflow
    if ($KeepLatestPerWorkflow -ge 0) {
        $byWorkflow = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($g in $byWorkflow) {
            $sorted = $g.Group | Sort-Object -Property CreatedAt -Descending
            if ($sorted.Count -gt $KeepLatestPerWorkflow) {
                foreach ($a in $sorted | Select-Object -Skip $KeepLatestPerWorkflow) {
                    [void]$toDelete.Add($a.Name)
                }
            }
        }
    }

    # Policy 3: max total size — delete oldest first until under cap.
    # Considers only currently-retained artifacts (ones not already marked).
    if ($MaxTotalSizeBytes -ge 0) {
        $remaining = $Artifacts | Where-Object { -not $toDelete.Contains($_.Name) } |
            Sort-Object -Property CreatedAt
        $totalSize = ($remaining | Measure-Object -Property SizeBytes -Sum).Sum
        if (-not $totalSize) { $totalSize = 0 }
        $i = 0
        while ($totalSize -gt $MaxTotalSizeBytes -and $i -lt $remaining.Count) {
            $victim = $remaining[$i]
            [void]$toDelete.Add($victim.Name)
            $totalSize -= $victim.SizeBytes
            $i++
        }
    }

    $delete = @($Artifacts | Where-Object { $toDelete.Contains($_.Name) })
    $retain = @($Artifacts | Where-Object { -not $toDelete.Contains($_.Name) })
    $reclaimed = 0L
    if ($delete.Count -gt 0) {
        $reclaimed = [long](($delete | Measure-Object -Property SizeBytes -Sum).Sum)
    }

    [pscustomobject]@{
        Delete  = $delete
        Retain  = $retain
        Summary = [pscustomobject]@{
            DeletedCount   = $delete.Count
            RetainedCount  = $retain.Count
            BytesReclaimed = [long]$reclaimed
        }
        DryRun  = $false
    }
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Artifacts,
        [int]$MaxAgeDays = -1,
        [long]$MaxTotalSizeBytes = -1,
        [int]$KeepLatestPerWorkflow = -1,
        [datetime]$Now = (Get-Date).ToUniversalTime(),
        [switch]$DryRun,
        [scriptblock]$DeleteAction = { param($a) }
    )

    # Forward only the policy params the caller actually set, so New-CleanupPlan's
    # validation (which uses $PSBoundParameters) doesn't reject our internal -1 sentinel.
    $forward = @{ Artifacts = $Artifacts; Now = $Now }
    if ($PSBoundParameters.ContainsKey('MaxAgeDays'))            { $forward.MaxAgeDays = $MaxAgeDays }
    if ($PSBoundParameters.ContainsKey('MaxTotalSizeBytes'))     { $forward.MaxTotalSizeBytes = $MaxTotalSizeBytes }
    if ($PSBoundParameters.ContainsKey('KeepLatestPerWorkflow')) { $forward.KeepLatestPerWorkflow = $KeepLatestPerWorkflow }
    $plan = New-CleanupPlan @forward
    $plan.DryRun = [bool]$DryRun

    if (-not $DryRun) {
        foreach ($a in $plan.Delete) {
            try { & $DeleteAction $a }
            catch { Write-Error "Failed to delete '$($a.Name)': $($_.Exception.Message)" }
        }
    }

    return $plan
}

function Format-CleanupPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan)
    $mode = if ($Plan.DryRun) { 'DRY-RUN' } else { 'APPLIED' }
    "[$mode] Deleted=$($Plan.Summary.DeletedCount) Retained=$($Plan.Summary.RetainedCount) BytesReclaimed=$($Plan.Summary.BytesReclaimed)"
}

Export-ModuleMember -Function New-Artifact, New-CleanupPlan, Invoke-ArtifactCleanup, Format-CleanupPlan
