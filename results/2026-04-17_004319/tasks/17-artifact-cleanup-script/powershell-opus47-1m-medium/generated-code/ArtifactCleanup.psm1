# ArtifactCleanup.psm1
# Retention policy engine for CI artifacts.
#
# Policies applied (an artifact is deleted if ANY policy marks it for deletion,
# except that KeepLatestPerWorkflow is an *exception* that rescues artifacts):
#   - MaxAgeDays: delete artifacts older than this many days
#   - MaxTotalSizeBytes: if remaining artifacts exceed this, delete oldest first
#   - KeepLatestPerWorkflow: always retain the N newest artifacts per workflow
#
# Returns a plan object describing which artifacts to delete vs retain, plus a
# summary. DryRun mode is the default behaviour of this planner — actual
# deletion is delegated to the caller, who may pass -Execute to simulate it.

function New-ArtifactCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Artifacts,

        [int] $MaxAgeDays = 0,              # 0 = disabled
        [long] $MaxTotalSizeBytes = 0,      # 0 = disabled
        [int] $KeepLatestPerWorkflow = 0,   # 0 = disabled

        [datetime] $Now = (Get-Date),

        [switch] $DryRun
    )

    # Validate
    if ($null -eq $Artifacts) {
        throw "Artifacts parameter cannot be null."
    }
    foreach ($a in $Artifacts) {
        foreach ($prop in 'Name','Size','CreationDate','WorkflowRunId') {
            if (-not ($a.PSObject.Properties.Name -contains $prop)) {
                throw "Artifact is missing required property '$prop'."
            }
        }
        if ($a.Size -lt 0) {
            throw "Artifact '$($a.Name)' has negative Size."
        }
    }

    # Start by marking everything for retention.
    $items = @()
    foreach ($a in $Artifacts) {
        $items += [pscustomobject]@{
            Artifact = $a
            Delete   = $false
            Reasons  = [System.Collections.Generic.List[string]]::new()
            Protected = $false   # rescued by keep-latest-N
        }
    }

    # Rescue: keep latest N per workflow (newest first).
    if ($KeepLatestPerWorkflow -gt 0) {
        $byWorkflow = $items | Group-Object { $_.Artifact.WorkflowRunId }
        foreach ($g in $byWorkflow) {
            $sorted = $g.Group | Sort-Object { $_.Artifact.CreationDate } -Descending
            for ($i = 0; $i -lt [Math]::Min($KeepLatestPerWorkflow, $sorted.Count); $i++) {
                $sorted[$i].Protected = $true
            }
        }
    }

    # Policy 1: max age
    if ($MaxAgeDays -gt 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($item in $items) {
            if ($item.Protected) { continue }
            if ($item.Artifact.CreationDate -lt $cutoff) {
                $item.Delete = $true
                $item.Reasons.Add("age > $MaxAgeDays days") | Out-Null
            }
        }
    }

    # Policy 2: max total size — delete oldest survivors until under budget.
    if ($MaxTotalSizeBytes -gt 0) {
        $survivors = @($items | Where-Object { -not $_.Delete })
        $currentSize = 0L
        foreach ($s in $survivors) { $currentSize += [long]$s.Artifact.Size }
        if ($currentSize -gt $MaxTotalSizeBytes) {
            $oldestFirst = $survivors | Sort-Object { $_.Artifact.CreationDate }
            foreach ($item in $oldestFirst) {
                if ($currentSize -le $MaxTotalSizeBytes) { break }
                if ($item.Protected) { continue }
                $item.Delete = $true
                $item.Reasons.Add("total size > $MaxTotalSizeBytes bytes") | Out-Null
                $currentSize -= [long]$item.Artifact.Size
            }
        }
    }

    $toDelete = @($items | Where-Object { $_.Delete } | ForEach-Object { $_.Artifact })
    $toRetain = @($items | Where-Object { -not $_.Delete } | ForEach-Object { $_.Artifact })
    $reclaimed = 0L
    foreach ($a in $toDelete) { $reclaimed += [long]$a.Size }

    [pscustomobject]@{
        ToDelete = $toDelete
        ToRetain = $toRetain
        Summary  = [pscustomobject]@{
            TotalArtifacts   = $items.Count
            DeletedCount     = $toDelete.Count
            RetainedCount    = $toRetain.Count
            SpaceReclaimed   = $reclaimed
            DryRun           = [bool]$DryRun
        }
        Reasons  = $items | ForEach-Object {
            [pscustomobject]@{
                Name    = $_.Artifact.Name
                Delete  = $_.Delete
                Reasons = @($_.Reasons)
            }
        }
    }
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]] $Artifacts,
        [int] $MaxAgeDays = 0,
        [long] $MaxTotalSizeBytes = 0,
        [int] $KeepLatestPerWorkflow = 0,
        [datetime] $Now = (Get-Date),
        [switch] $DryRun
    )
    $plan = New-ArtifactCleanupPlan -Artifacts $Artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
        -Now $Now `
        -DryRun:$DryRun

    $mode = if ($DryRun) { 'DRY-RUN' } else { 'EXECUTE' }
    Write-Host "[$mode] Artifacts: $($plan.Summary.TotalArtifacts) total, $($plan.Summary.DeletedCount) to delete, $($plan.Summary.RetainedCount) to retain"
    Write-Host "[$mode] Space to reclaim: $($plan.Summary.SpaceReclaimed) bytes"
    foreach ($a in $plan.ToDelete) {
        Write-Host "  DELETE  $($a.Name)  ($($a.Size) bytes, workflow $($a.WorkflowRunId))"
    }
    foreach ($a in $plan.ToRetain) {
        Write-Host "  KEEP    $($a.Name)  ($($a.Size) bytes, workflow $($a.WorkflowRunId))"
    }
    if (-not $DryRun) {
        Write-Host "[$mode] (actual deletion would be performed here)"
    }
    return $plan
}

Export-ModuleMember -Function New-ArtifactCleanupPlan, Invoke-ArtifactCleanup
