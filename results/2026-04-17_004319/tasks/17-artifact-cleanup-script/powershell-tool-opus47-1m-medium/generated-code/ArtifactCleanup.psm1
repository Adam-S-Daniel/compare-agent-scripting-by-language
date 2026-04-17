Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Build a deletion plan for CI artifacts.
#
# Retention policy evaluation order:
#   1. MaxAgeDays          - drop anything older than the cutoff.
#   2. KeepLatestNPerWorkflow - within each WorkflowRunId, keep only the N newest.
#   3. MaxTotalSizeBytes   - if survivors still exceed the cap, evict oldest first.
#
# The returned plan is a pure data object; no IO is performed. Callers (CI
# harness, script entry point) are responsible for acting on Deleted entries.
# DryRun is recorded on the plan so downstream code can skip destructive calls.

function Get-ArtifactCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Artifacts,
        [int]      $MaxAgeDays              = 0,
        [int]      $KeepLatestNPerWorkflow  = 0,
        [long]     $MaxTotalSizeBytes       = 0,
        [datetime] $Now                     = (Get-Date),
        [switch]   $DryRun
    )

    $required = 'Name','SizeBytes','CreatedAt','WorkflowRunId'
    foreach ($a in $Artifacts) {
        foreach ($p in $required) {
            if (-not $a.PSObject.Properties.Name.Contains($p)) {
                throw "Artifact is missing required property '$p'."
            }
        }
    }

    # Normalise CreatedAt to [datetime] so sorting/age math is consistent
    # even if the JSON loader handed us strings.
    $items = foreach ($a in $Artifacts) {
        [pscustomobject]@{
            Name          = [string]$a.Name
            SizeBytes     = [long]$a.SizeBytes
            CreatedAt     = [datetime]$a.CreatedAt
            WorkflowRunId = [string]$a.WorkflowRunId
        }
    }

    $toDelete = [System.Collections.Generic.HashSet[string]]::new()

    # 1. Age policy.
    if ($MaxAgeDays -gt 0) {
        $cutoff = $Now.AddDays(-$MaxAgeDays)
        foreach ($i in $items) {
            if ($i.CreatedAt -lt $cutoff) { [void]$toDelete.Add($i.Name) }
        }
    }

    # 2. Keep-latest-N per workflow (only considers artifacts not already doomed).
    if ($KeepLatestNPerWorkflow -gt 0) {
        $groups = $items | Where-Object { -not $toDelete.Contains($_.Name) } |
                  Group-Object -Property WorkflowRunId
        foreach ($g in $groups) {
            $sorted = $g.Group | Sort-Object CreatedAt -Descending
            if ($sorted.Count -gt $KeepLatestNPerWorkflow) {
                foreach ($extra in $sorted[$KeepLatestNPerWorkflow..($sorted.Count - 1)]) {
                    [void]$toDelete.Add($extra.Name)
                }
            }
        }
    }

    # 3. Size cap: evict oldest survivors until the total fits.
    if ($MaxTotalSizeBytes -gt 0) {
        $survivors = @($items | Where-Object { -not $toDelete.Contains($_.Name) } |
                       Sort-Object CreatedAt)  # oldest first
        $total = [long]0
        foreach ($s in $survivors) { $total += [long]$s.SizeBytes }
        $idx = 0
        while ($total -gt $MaxTotalSizeBytes -and $idx -lt $survivors.Count) {
            [void]$toDelete.Add($survivors[$idx].Name)
            $total -= $survivors[$idx].SizeBytes
            $idx++
        }
    }

    $deleted  = @($items | Where-Object {     $toDelete.Contains($_.Name) })
    $retained = @($items | Where-Object { -not $toDelete.Contains($_.Name) })
    $reclaimed = [long]0
    foreach ($d in $deleted) { $reclaimed += [long]$d.SizeBytes }

    [pscustomobject]@{
        Retained            = $retained
        Deleted             = $deleted
        TotalRetained       = $retained.Count
        TotalDeleted        = $deleted.Count
        SpaceReclaimedBytes = [long]$reclaimed
        DryRun              = [bool]$DryRun
    }
}

Export-ModuleMember -Function Get-ArtifactCleanupPlan
