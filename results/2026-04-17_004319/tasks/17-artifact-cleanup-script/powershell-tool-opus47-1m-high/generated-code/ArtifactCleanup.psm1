# ArtifactCleanup module.
#
# Approach: retention is expressed as a set of policies that each *mark* artifacts
# for deletion. We iterate artifacts once per policy, add matches to a shared set
# keyed by (Name, WorkflowRunId), then split input into ToDelete/ToRetain. This
# avoids double-counting when multiple policies target the same artifact and makes
# each policy easy to test in isolation.
#
# Get-ArtifactCleanupPlan is pure: it takes data in and returns a plan. Side
# effects (actually deleting) live in Invoke-ArtifactCleanup, which takes a
# script block as the delete action so tests can inject a mock.

Set-StrictMode -Version Latest

function Assert-Artifact {
    param([Parameter(Mandatory)] $Artifact)

    foreach ($field in @('Name', 'SizeBytes', 'CreatedAt', 'WorkflowRunId')) {
        $match = @($Artifact.PSObject.Properties.Match($field))
        if ($match.Count -eq 0) {
            throw "Artifact is missing required field '$field'"
        }
    }
}

function Get-SafeSum {
    param($Items, [string]$Property)
    # Wraps Measure-Object so strict mode is happy on empty input.
    $arr = @($Items)
    if ($arr.Count -eq 0) { return [long]0 }
    $m = $arr | Measure-Object -Property $Property -Sum
    if ($null -eq $m.Sum) { return [long]0 }
    [long]$m.Sum
}

function Get-ArtifactKey {
    param($Artifact)
    # Two artifacts with the same name across different workflows are distinct.
    "$($Artifact.WorkflowRunId)::$($Artifact.Name)"
}

function Get-ArtifactCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Artifacts,

        [int]      $MaxAgeDays = 0,
        [long]     $MaxTotalSizeBytes = 0,
        [int]      $KeepLatestPerWorkflow = 0,

        # Injected so tests (and callers that want determinism) can fix "now".
        [datetime] $Now = [datetime]::UtcNow
    )

    foreach ($a in $Artifacts) { Assert-Artifact -Artifact $a }

    # Keyed set of artifacts scheduled for deletion, with reasons accumulated.
    $toDelete = @{}

    function Mark([object]$Artifact, [string]$Reason) {
        $key = Get-ArtifactKey $Artifact
        if (-not $toDelete.ContainsKey($key)) {
            $toDelete[$key] = [pscustomobject]@{
                Artifact = $Artifact
                Reasons  = [System.Collections.Generic.List[string]]::new()
            }
        }
        $toDelete[$key].Reasons.Add($Reason)
    }

    # Policy 1: MaxAgeDays — any artifact older than the cutoff.
    if ($MaxAgeDays -gt 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($a in $Artifacts) {
            if ($a.CreatedAt -lt $cutoff) {
                Mark $a "MaxAgeDays ($MaxAgeDays)"
            }
        }
    }

    # Policy 2: KeepLatestPerWorkflow — group by WorkflowRunId, keep newest N.
    if ($KeepLatestPerWorkflow -gt 0) {
        $groups = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $ordered = $g.Group | Sort-Object -Property CreatedAt -Descending
            if ($ordered.Count -gt $KeepLatestPerWorkflow) {
                foreach ($stale in $ordered[$KeepLatestPerWorkflow..($ordered.Count - 1)]) {
                    Mark $stale "KeepLatestPerWorkflow ($KeepLatestPerWorkflow)"
                }
            }
        }
    }

    # Policy 3: MaxTotalSizeBytes — if the currently-retained set exceeds the cap,
    # delete oldest-first until the remainder fits. Runs last so it can account
    # for artifacts the prior policies already marked.
    if ($MaxTotalSizeBytes -gt 0) {
        $stillRetained = @($Artifacts | Where-Object { -not $toDelete.ContainsKey((Get-ArtifactKey $_)) })
        $retainedBytes = Get-SafeSum -Items $stillRetained -Property SizeBytes

        if ($retainedBytes -gt $MaxTotalSizeBytes) {
            $candidates = $stillRetained | Sort-Object -Property CreatedAt
            foreach ($a in $candidates) {
                if ($retainedBytes -le $MaxTotalSizeBytes) { break }
                Mark $a "MaxTotalSizeBytes ($MaxTotalSizeBytes)"
                $retainedBytes -= $a.SizeBytes
            }
        }
    }

    # Materialize the plan. PowerShell unwraps single-element arrays on return, so
    # callers that expect .Count must either wrap in @() or check for $null.
    $deletedKeys = $toDelete.Keys
    $deleteList = foreach ($a in $Artifacts) {
        if ($deletedKeys -contains (Get-ArtifactKey $a)) {
            $entry = $toDelete[(Get-ArtifactKey $a)]
            [pscustomobject]@{
                Name          = $a.Name
                SizeBytes     = $a.SizeBytes
                CreatedAt     = $a.CreatedAt
                WorkflowRunId = $a.WorkflowRunId
                Reason        = ($entry.Reasons -join '; ')
            }
        }
    }
    $retainList = foreach ($a in $Artifacts) {
        if (-not ($deletedKeys -contains (Get-ArtifactKey $a))) {
            [pscustomobject]@{
                Name          = $a.Name
                SizeBytes     = $a.SizeBytes
                CreatedAt     = $a.CreatedAt
                WorkflowRunId = $a.WorkflowRunId
            }
        }
    }

    # Force arrays so .Count is always defined even with 0 or 1 element.
    $deleteArr = @($deleteList)
    $retainArr = @($retainList)

    $bytesReclaimed = Get-SafeSum -Items $deleteArr -Property SizeBytes
    $bytesRetained  = Get-SafeSum -Items $retainArr -Property SizeBytes

    [pscustomobject]@{
        ToDelete       = $deleteArr
        ToRetain       = $retainArr
        BytesReclaimed = [long]$bytesReclaimed
        Summary        = [pscustomobject]@{
            TotalArtifacts = $Artifacts.Count
            DeletedCount   = $deleteArr.Count
            RetainedCount  = $retainArr.Count
            BytesReclaimed = [long]$bytesReclaimed
            BytesRetained  = [long]$bytesRetained
        }
    }
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Artifacts,

        [int]       $MaxAgeDays = 0,
        [long]      $MaxTotalSizeBytes = 0,
        [int]       $KeepLatestPerWorkflow = 0,
        [datetime]  $Now = [datetime]::UtcNow,
        [switch]    $DryRun,

        # Injected so tests can observe invocations and simulate failures without
        # touching a real artifact store.
        [scriptblock] $DeleteAction = { param($artifact) }
    )

    $plan = Get-ArtifactCleanupPlan -Artifacts $Artifacts `
                                    -MaxAgeDays $MaxAgeDays `
                                    -MaxTotalSizeBytes $MaxTotalSizeBytes `
                                    -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
                                    -Now $Now

    $failures = @()
    if (-not $DryRun) {
        foreach ($a in $plan.ToDelete) {
            try {
                & $DeleteAction $a
            } catch {
                $failures += [pscustomobject]@{
                    Name          = $a.Name
                    WorkflowRunId = $a.WorkflowRunId
                    Error         = $_.Exception.Message
                }
            }
        }
    }

    # Attach execution metadata to the returned plan. Cast to bool first — passing
    # `[bool]$DryRun` directly to -NotePropertyValue is parsed as a string.
    $isDryRun = [bool]$DryRun
    $plan | Add-Member -NotePropertyName DryRun   -NotePropertyValue $isDryRun   -Force
    $plan | Add-Member -NotePropertyName Failures -NotePropertyValue @($failures) -Force
    $plan
}

Export-ModuleMember -Function Get-ArtifactCleanupPlan, Invoke-ArtifactCleanup
