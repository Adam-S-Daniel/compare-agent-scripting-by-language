# ArtifactCleanup.psm1
# Retention policy engine for CI artifacts.
#
# Policies (an artifact is deleted if ANY marks it, unless rescued by KeepLatestPerWorkflow):
#   MaxAgeDays            - delete if older than N days (0 = disabled)
#   MaxTotalSizeBytes     - delete oldest-first until under budget (0 = disabled)
#   KeepLatestPerWorkflow - always retain the N newest artifacts per workflow run ID (0 = disabled)

function New-ArtifactCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Artifacts,

        [int]    $MaxAgeDays = 0,
        [long]   $MaxTotalSizeBytes = 0,
        [int]    $KeepLatestPerWorkflow = 0,

        [datetime] $Now = (Get-Date),

        [switch] $DryRun
    )

    if ($null -eq $Artifacts) { throw "Artifacts parameter cannot be null." }

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

    # Wrap each artifact in a tracking item
    $items = @($Artifacts | ForEach-Object {
        [pscustomobject]@{
            Artifact  = $_
            Delete    = $false
            Protected = $false   # rescued by KeepLatestPerWorkflow
            Reasons   = [System.Collections.Generic.List[string]]::new()
        }
    })

    # Step 1: mark the newest N per workflow as protected (KeepLatestPerWorkflow rescue)
    if ($KeepLatestPerWorkflow -gt 0) {
        $byWorkflow = $items | Group-Object { $_.Artifact.WorkflowRunId }
        foreach ($g in $byWorkflow) {
            $sorted = @($g.Group | Sort-Object { $_.Artifact.CreationDate } -Descending)
            for ($i = 0; $i -lt [Math]::Min($KeepLatestPerWorkflow, $sorted.Count); $i++) {
                $sorted[$i].Protected = $true
            }
        }
    }

    # Policy 1: MaxAgeDays — delete unprotected artifacts older than the cutoff
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

    # Policy 2: MaxTotalSizeBytes — delete oldest survivors until under budget
    if ($MaxTotalSizeBytes -gt 0) {
        $survivors = @($items | Where-Object { -not $_.Delete })
        $currentSize = ($survivors | Measure-Object -Property { $_.Artifact.Size } -Sum).Sum
        if ($null -eq $currentSize) { $currentSize = 0L }

        if ($currentSize -gt $MaxTotalSizeBytes) {
            $oldestFirst = @($survivors | Sort-Object { $_.Artifact.CreationDate })
            foreach ($item in $oldestFirst) {
                if ($currentSize -le $MaxTotalSizeBytes) { break }
                if ($item.Protected) { continue }
                $item.Delete = $true
                $item.Reasons.Add("total size > $MaxTotalSizeBytes bytes") | Out-Null
                $currentSize -= [long]$item.Artifact.Size
            }
        }
    }

    $toDelete = @($items | Where-Object { $_.Delete }    | ForEach-Object { $_.Artifact })
    $toRetain = @($items | Where-Object { -not $_.Delete } | ForEach-Object { $_.Artifact })
    $reclaimed = ($toDelete | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $reclaimed) { $reclaimed = 0L }

    [pscustomobject]@{
        ToDelete = $toDelete
        ToRetain = $toRetain
        Summary  = [pscustomobject]@{
            TotalArtifacts  = $items.Count
            DeletedCount    = $toDelete.Count
            RetainedCount   = $toRetain.Count
            SpaceReclaimed  = [long]$reclaimed
            DryRun          = [bool]$DryRun
        }
        Reasons = $items | ForEach-Object {
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
        [int]      $MaxAgeDays = 0,
        [long]     $MaxTotalSizeBytes = 0,
        [int]      $KeepLatestPerWorkflow = 0,
        [datetime] $Now = (Get-Date),
        [switch]   $DryRun
    )

    $plan = New-ArtifactCleanupPlan -Artifacts $Artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
        -Now $Now `
        -DryRun:$DryRun

    $mode = if ($DryRun) { 'DRY-RUN' } else { 'EXECUTE' }
    Write-Host "[$mode] Total: $($plan.Summary.TotalArtifacts) artifacts | Delete: $($plan.Summary.DeletedCount) | Retain: $($plan.Summary.RetainedCount)"
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
