# Cleanup-Artifacts.ps1
# Computes a deletion plan for build artifacts based on retention policies.
#
# Policies (applied in order):
#   1. MaxAgeDays              -> delete artifacts older than N days
#   2. KeepLatestPerWorkflow   -> within each WorkflowRunId, keep only the N newest
#   3. MaxTotalSizeBytes       -> if remaining set still exceeds budget, delete
#                                 oldest first until under budget
#
# An artifact marked for deletion by ANY policy ends up deleted.
# Dry-run mode produces the plan without "performing" the delete (no side effects
# either way; this script is pure planning + reporting on mock data).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ArtifactDeletionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Artifacts,
        [int]      $MaxAgeDays            = 0,   # 0 = disabled
        [long]     $MaxTotalSizeBytes     = 0,   # 0 = disabled
        [int]      $KeepLatestPerWorkflow = 0,   # 0 = disabled
        [datetime] $Now                   = (Get-Date)
    )

    if ($null -eq $Artifacts) { $Artifacts = @() }

    # Validate / normalise input. Each artifact must have Name, SizeBytes,
    # CreatedAt (datetime or parseable string), WorkflowRunId.
    $normalised = foreach ($a in $Artifacts) {
        foreach ($f in 'Name','SizeBytes','CreatedAt','WorkflowRunId') {
            if (-not $a.PSObject.Properties.Name.Contains($f)) {
                throw "Artifact is missing required field '$f'."
            }
        }
        [pscustomobject]@{
            Name          = [string]$a.Name
            SizeBytes     = [long]$a.SizeBytes
            CreatedAt     = [datetime]$a.CreatedAt
            WorkflowRunId = [string]$a.WorkflowRunId
            Reasons       = New-Object System.Collections.Generic.List[string]
        }
    }
    $normalised = @($normalised)

    # Policy 1: max age
    if ($MaxAgeDays -gt 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($a in $normalised) {
            if ($a.CreatedAt -lt $cutoff) {
                [void]$a.Reasons.Add("age>$MaxAgeDays`d")
            }
        }
    }

    # Policy 2: keep-latest-N per workflow run
    if ($KeepLatestPerWorkflow -gt 0) {
        $groups = $normalised | Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $sorted = $g.Group | Sort-Object -Property CreatedAt -Descending
            for ($i = $KeepLatestPerWorkflow; $i -lt $sorted.Count; $i++) {
                [void]$sorted[$i].Reasons.Add("not-in-latest-$KeepLatestPerWorkflow")
            }
        }
    }

    # Policy 3: max total size — applied to artifacts NOT already deleted by 1+2.
    # Drop oldest first until under budget.
    if ($MaxTotalSizeBytes -gt 0) {
        $survivors = @($normalised | Where-Object { $_.Reasons.Count -eq 0 })
        $sum = $survivors | Measure-Object -Property SizeBytes -Sum
        $total = if ($sum) { [long]$sum.Sum } else { 0L }
        if ($total -gt $MaxTotalSizeBytes) {
            $oldestFirst = $survivors | Sort-Object -Property CreatedAt
            foreach ($a in $oldestFirst) {
                if ($total -le $MaxTotalSizeBytes) { break }
                [void]$a.Reasons.Add("over-size-budget")
                $total -= $a.SizeBytes
            }
        }
    }

    $delete = @($normalised | Where-Object { $_.Reasons.Count -gt 0 })
    $retain = @($normalised | Where-Object { $_.Reasons.Count -eq 0 })

    $rsum = $delete | Measure-Object -Property SizeBytes -Sum
    $reclaimed = if ($rsum) { [long]$rsum.Sum } else { 0L }

    [pscustomobject]@{
        Delete                = $delete
        Retain                = $retain
        TotalReclaimedBytes   = [long]$reclaimed
        DeletedCount          = $delete.Count
        RetainedCount         = $retain.Count
    }
}

function Format-CleanupSummary {
    param(
        [Parameter(Mandatory)] $Plan,
        [switch] $DryRun
    )
    $mode = if ($DryRun) { 'DRY-RUN' } else { 'EXECUTE' }
    $lines = @()
    $lines += "=== Artifact Cleanup Plan ($mode) ==="
    $lines += "Artifacts to delete : $($Plan.DeletedCount)"
    $lines += "Artifacts to retain : $($Plan.RetainedCount)"
    $lines += "Space reclaimed     : $($Plan.TotalReclaimedBytes) bytes"
    if ($Plan.DeletedCount -gt 0) {
        $lines += "--- Deletions ---"
        foreach ($a in $Plan.Delete) {
            $lines += ("  DELETE {0,-30} {1,12} bytes  run={2}  [{3}]" -f `
                $a.Name, $a.SizeBytes, $a.WorkflowRunId, ($a.Reasons -join ','))
        }
    }
    $lines -join "`n"
}

function Invoke-ArtifactCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $InputPath,
        [int]    $MaxAgeDays            = 0,
        [long]   $MaxTotalSizeBytes     = 0,
        [int]    $KeepLatestPerWorkflow = 0,
        [switch] $DryRun
    )
    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input file not found: $InputPath"
    }
    $raw = Get-Content -LiteralPath $InputPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Input file is empty: $InputPath"
    }
    try {
        $artifacts = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$InputPath': $($_.Exception.Message)"
    }
    if ($artifacts -isnot [System.Collections.IEnumerable] -or $artifacts -is [string]) {
        $artifacts = @($artifacts)
    }

    $plan = Get-ArtifactDeletionPlan `
        -Artifacts $artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow

    Write-Host (Format-CleanupSummary -Plan $plan -DryRun:$DryRun)
    return $plan
}

# Allow running as a script (not just dot-sourcing for tests)
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\. ') {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # Parameter binding handled by param block below when invoked directly
    }
}
