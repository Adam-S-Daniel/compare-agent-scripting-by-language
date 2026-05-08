<#
.SYNOPSIS
    Artifact cleanup script with retention policy enforcement

.DESCRIPTION
    Applies retention policies to artifacts and generates a deletion plan.
    Supports dry-run mode for safe preview of cleanup actions.

.EXAMPLE
    $policies = @{
        MaxAgeInDays = 30
        MaxTotalSizeInMB = 1000
        KeepLatestPerWorkflow = 5
    }
    $plan = Get-DeletionPlan -Artifacts $artifacts -Policies $policies -DryRun $true
#>

function Validate-Artifact {
    <#
    .SYNOPSIS
        Validates that an artifact has all required properties
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Artifact
    )

    $requiredProps = @('Name', 'Size', 'CreatedDate', 'WorkflowRunId')
    foreach ($prop in $requiredProps) {
        if (-not $Artifact.ContainsKey($prop)) {
            throw "Artifact missing required property: $prop"
        }
    }
}

function Get-DeletionPlan {
    <#
    .SYNOPSIS
        Generates a deletion plan based on retention policies

    .PARAMETER Artifacts
        Array of artifact objects with Name, Size, CreatedDate, WorkflowRunId

    .PARAMETER Policies
        Hashtable with retention policy rules:
        - MaxAgeInDays: Delete artifacts older than N days
        - MaxTotalSizeInMB: Keep total artifact size under N MB
        - KeepLatestPerWorkflow: Keep at least N latest artifacts per workflow

    .PARAMETER DryRun
        If $true, don't actually delete artifacts
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Artifacts,

        [Parameter(Mandatory = $true)]
        [hashtable]$Policies,

        [Parameter(Mandatory = $false)]
        [bool]$DryRun = $true
    )

    # Validate inputs
    if ($Artifacts.Count -eq 0) {
        throw "No artifacts provided"
    }

    if ($Policies.Count -eq 0) {
        throw "No policies provided"
    }

    # Validate each artifact
    foreach ($artifact in $Artifacts) {
        Validate-Artifact $artifact
    }

    # Initialize deletion candidates and retained sets
    [System.Collections.Generic.HashSet[int]] $deleteIndices = @()
    [System.Collections.Generic.HashSet[int]] $retainIndices = @()
    for ($i = 0; $i -lt $Artifacts.Count; $i++) {
        $retainIndices.Add($i) | Out-Null
    }

    # Apply Max Age policy
    if ($Policies.ContainsKey('MaxAgeInDays')) {
        $maxAge = $Policies['MaxAgeInDays']
        $cutoffDate = (Get-Date).AddDays(-$maxAge)

        for ($i = 0; $i -lt $Artifacts.Count; $i++) {
            if ($Artifacts[$i].CreatedDate -lt $cutoffDate) {
                $deleteIndices.Add($i) | Out-Null
                $retainIndices.Remove($i) | Out-Null
            }
        }
    }

    # Apply Keep Latest Per Workflow policy
    if ($Policies.ContainsKey('KeepLatestPerWorkflow')) {
        $keepLatest = $Policies['KeepLatestPerWorkflow']
        $workflowGroups = @{}

        for ($i = 0; $i -lt $Artifacts.Count; $i++) {
            if ($retainIndices.Contains($i)) {
                $wfId = $Artifacts[$i].WorkflowRunId
                if (-not $workflowGroups.ContainsKey($wfId)) {
                    $workflowGroups[$wfId] = @()
                }
                $workflowGroups[$wfId] += $i
            }
        }

        foreach ($wfId in $workflowGroups.Keys) {
            $indices = $workflowGroups[$wfId]
            $sorted = $indices | ForEach-Object {
                [PSCustomObject]@{ Index = $_; Date = $Artifacts[$_].CreatedDate }
            } | Sort-Object -Property Date -Descending

            for ($i = $keepLatest; $i -lt $sorted.Count; $i++) {
                $idx = $sorted[$i].Index
                $deleteIndices.Add($idx) | Out-Null
                $retainIndices.Remove($idx) | Out-Null
            }
        }
    }

    # Apply Max Total Size policy
    if ($Policies.ContainsKey('MaxTotalSizeInMB')) {
        $maxSizeBytes = $Policies['MaxTotalSizeInMB'] * 1MB
        $retainedArtifacts = @()
        $totalSize = 0

        $sortedIndices = $retainIndices | ForEach-Object {
            [PSCustomObject]@{ Index = $_; Date = $Artifacts[$_].CreatedDate }
        } | Sort-Object -Property Date -Descending | ForEach-Object { $_.Index }

        foreach ($idx in $sortedIndices) {
            $size = $Artifacts[$idx].Size
            if ($totalSize + $size -le $maxSizeBytes) {
                $totalSize += $size
            }
            else {
                $deleteIndices.Add($idx) | Out-Null
                $retainIndices.Remove($idx) | Out-Null
            }
        }
    }

    # Build result sets
    $toDelete = @()
    $toRetain = @()

    for ($i = 0; $i -lt $Artifacts.Count; $i++) {
        if ($deleteIndices.Contains($i)) {
            $toDelete += $Artifacts[$i]
        }
        else {
            $toRetain += $Artifacts[$i]
        }
    }

    # Calculate summary
    $totalSpaceReclaimed = ($toDelete | Measure-Object -Property Size -Sum).Sum
    if ($null -eq $totalSpaceReclaimed) { $totalSpaceReclaimed = 0 }

    $summary = [PSCustomObject]@{
        ArtifactsDeleted        = $toDelete.Count
        ArtifactsRetained       = $toRetain.Count
        TotalSpaceReclaimedBytes = $totalSpaceReclaimed
        TotalSpaceReclaimedMB    = [math]::Round($totalSpaceReclaimed / 1MB, 2)
        ToString                 = "Summary: Delete $($toDelete.Count) artifacts, Retain $($toRetain.Count), Reclaim $([math]::Round($totalSpaceReclaimed / 1MB, 2)) MB"
    }

    # Return result object
    return [PSCustomObject]@{
        ToDelete = $toDelete
        ToRetain = $toRetain
        Summary  = $summary
        DryRun   = $DryRun
    }
}
