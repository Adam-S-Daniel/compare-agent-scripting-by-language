<#
.SYNOPSIS
    Applies retention policies to a list of CI artifacts and produces a deletion plan.

.DESCRIPTION
    Reads artifact metadata (name, size, creation date, workflow run ID) and applies
    three independent retention policies:
      - MaxAgeDays:         delete artifacts older than N days
      - KeepLatestN:        per workflow run ID, keep only the N newest
      - MaxTotalSizeBytes:  if total size exceeds the limit, delete oldest first

    An artifact is deleted if ANY active policy marks it for deletion.
    Supports dry-run mode: prints the plan without taking any action.

.PARAMETER ArtifactsFile
    Path to a JSON file containing an array of artifact objects.
    Each object must have: Name, SizeBytes, CreatedAt, WorkflowRunId.

.PARAMETER PolicyFile
    Path to a JSON file with policy settings:
    MaxAgeDays, MaxTotalSizeBytes, KeepLatestN (0 = disabled for each).

.PARAMETER MaxAgeDays
    Inline policy override: delete artifacts older than this many days (0 = disabled).

.PARAMETER MaxTotalSizeBytes
    Inline policy override: maximum total retained size in bytes (0 = disabled).

.PARAMETER KeepLatestN
    Inline policy override: keep only the N newest per workflow run ID (0 = disabled).

.PARAMETER DryRun
    When set, prints the deletion plan but does not modify anything.
#>

[CmdletBinding()]
param(
    [string] $ArtifactsFile,
    [string] $PolicyFile,
    [int]    $MaxAgeDays        = 0,
    [long]   $MaxTotalSizeBytes = 0,
    [int]    $KeepLatestN       = 0,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────
# Core function: compute which artifacts to delete
# ─────────────────────────────────────────────────────────────
function Get-ArtifactDeletionPlan {
    <#
    .SYNOPSIS
        Returns a plan object describing which artifacts to delete under the given policy.
    .PARAMETER Artifacts
        Array of artifact objects (Name, SizeBytes, CreatedAt, WorkflowRunId).
    .PARAMETER Policy
        Hashtable with keys: MaxAgeDays, MaxTotalSizeBytes, KeepLatestN (0 = disabled).
    .PARAMETER DryRun
        Tag the plan as dry-run (informational only, does not affect selection).
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Artifacts,
        [Parameter(Mandatory)] [hashtable] $Policy,
        [switch] $DryRun
    )

    $deleteSet = [System.Collections.Generic.HashSet[string]]::new()

    # ── Policy 1: max age ──────────────────────────────────────
    if ($Policy.MaxAgeDays -gt 0) {
        $cutoff = (Get-Date).AddDays(-$Policy.MaxAgeDays)
        foreach ($artifact in $Artifacts) {
            if ([datetime]$artifact.CreatedAt -lt $cutoff) {
                [void]$deleteSet.Add($artifact.Name)
            }
        }
    }

    # ── Policy 2: keep-latest-N per workflow ───────────────────
    if ($Policy.KeepLatestN -gt 0) {
        # Group by WorkflowRunId, sort newest-first, mark extras for deletion
        $groups = $Artifacts | Group-Object -Property WorkflowRunId
        foreach ($group in $groups) {
            $sorted = $group.Group | Sort-Object { [datetime]$_.CreatedAt } -Descending
            $extras  = $sorted | Select-Object -Skip $Policy.KeepLatestN
            foreach ($artifact in $extras) {
                [void]$deleteSet.Add($artifact.Name)
            }
        }
    }

    # ── Policy 3: max total size ───────────────────────────────
    if ($Policy.MaxTotalSizeBytes -gt 0) {
        # Candidates for deletion from this policy = all artifacts not already marked
        # Sort all by oldest first; greedily delete until total fits
        $candidates  = $Artifacts | Sort-Object { [datetime]$_.CreatedAt }
        $sizeMeasure = $Artifacts | Measure-Object -Property SizeBytes -Sum
        $currentSize = if ($sizeMeasure.Count -gt 0 -and $null -ne $sizeMeasure.Sum) { [long]$sizeMeasure.Sum } else { 0L }
        foreach ($artifact in $candidates) {
            if ($currentSize -le $Policy.MaxTotalSizeBytes) { break }
            [void]$deleteSet.Add($artifact.Name)
            $currentSize -= $artifact.SizeBytes
        }
    }

    # ── Build final plan ───────────────────────────────────────
    $toDelete = @($Artifacts | Where-Object { $deleteSet.Contains($_.Name) })
    $toRetain = @($Artifacts | Where-Object { -not $deleteSet.Contains($_.Name) })
    $reclMeasure = $toDelete | Measure-Object -Property SizeBytes -Sum
    $reclaimed   = if ($reclMeasure.Count -gt 0 -and $null -ne $reclMeasure.Sum) { [long]$reclMeasure.Sum } else { 0L }

    return [PSCustomObject]@{
        ToDelete            = $toDelete
        ToRetain            = $toRetain
        SpaceReclaimedBytes = [long]$reclaimed
        DryRun              = [bool]$DryRun
    }
}

# ─────────────────────────────────────────────────────────────
# Formatting function
# ─────────────────────────────────────────────────────────────
function Format-CleanupPlan {
    <#
    .SYNOPSIS
        Formats a deletion plan as a human-readable string with a machine-readable summary line.
    #>
    param(
        [Parameter(Mandatory)] [PSCustomObject] $Plan
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("")
    $lines.Add("=== ARTIFACT CLEANUP PLAN ===")

    $modeLabel = if ($Plan.DryRun) { "DRY-RUN (no changes will be made)" } else { "LIVE" }
    $lines.Add("Mode: $modeLabel")

    # Deleted section
    $lines.Add("--- Artifacts to DELETE ($($Plan.ToDelete.Count)) ---")
    foreach ($a in $Plan.ToDelete) {
        $ageDays = [int]((Get-Date) - [datetime]$a.CreatedAt).TotalDays
        $sizeMB  = [math]::Round($a.SizeBytes / 1MB, 2)
        $lines.Add("  - $($a.Name) ($sizeMB MB) [$ageDays days old, workflow: $($a.WorkflowRunId)]")
    }

    # Retained section
    $lines.Add("--- Artifacts to RETAIN ($($Plan.ToRetain.Count)) ---")
    foreach ($a in $Plan.ToRetain) {
        $ageDays = [int]((Get-Date) - [datetime]$a.CreatedAt).TotalDays
        $sizeMB  = [math]::Round($a.SizeBytes / 1MB, 2)
        $lines.Add("  - $($a.Name) ($sizeMB MB) [$ageDays days old, workflow: $($a.WorkflowRunId)]")
    }

    # Summary
    $reclaimedMB = [math]::Round($Plan.SpaceReclaimedBytes / 1MB, 2)
    $lines.Add("=== SUMMARY ===")
    $lines.Add("Total artifacts    : $($Plan.ToDelete.Count + $Plan.ToRetain.Count)")
    $lines.Add("Artifacts to delete: $($Plan.ToDelete.Count)")
    $lines.Add("Artifacts to retain: $($Plan.ToRetain.Count)")
    $lines.Add("Space reclaimed    : $reclaimedMB MB ($($Plan.SpaceReclaimedBytes) bytes)")

    # Machine-readable marker (parsed by integration tests)
    $lines.Add("CLEANUP_RESULT: deleted=$($Plan.ToDelete.Count) retained=$($Plan.ToRetain.Count) reclaimed_bytes=$($Plan.SpaceReclaimedBytes)")
    $lines.Add("=== END PLAN ===")
    $lines.Add("")

    return $lines -join "`n"
}

# ─────────────────────────────────────────────────────────────
# CLI entry point (only runs when ArtifactsFile is provided)
# ─────────────────────────────────────────────────────────────
if ($ArtifactsFile) {
    # Validate inputs
    if (-not (Test-Path $ArtifactsFile)) {
        Write-Error "Artifacts file not found: $ArtifactsFile"
        exit 1
    }

    # Load artifacts
    $artifactsRaw = Get-Content $ArtifactsFile -Raw | ConvertFrom-Json
    # Normalise to array (ConvertFrom-Json can return a single object)
    if ($artifactsRaw -isnot [array]) { $artifactsRaw = @($artifactsRaw) }

    # Build policy from file or inline params
    $policy = @{ MaxAgeDays = $MaxAgeDays; MaxTotalSizeBytes = $MaxTotalSizeBytes; KeepLatestN = $KeepLatestN }

    if ($PolicyFile) {
        if (-not (Test-Path $PolicyFile)) {
            Write-Error "Policy file not found: $PolicyFile"
            exit 1
        }
        $policyRaw = Get-Content $PolicyFile -Raw | ConvertFrom-Json
        if ($null -ne $policyRaw.MaxAgeDays)        { $policy.MaxAgeDays        = [int]$policyRaw.MaxAgeDays }
        if ($null -ne $policyRaw.MaxTotalSizeBytes)  { $policy.MaxTotalSizeBytes  = [long]$policyRaw.MaxTotalSizeBytes }
        if ($null -ne $policyRaw.KeepLatestN)        { $policy.KeepLatestN        = [int]$policyRaw.KeepLatestN }
    }

    # Inline params override file values when explicitly provided
    if ($MaxAgeDays        -gt 0) { $policy.MaxAgeDays        = $MaxAgeDays }
    if ($MaxTotalSizeBytes -gt 0) { $policy.MaxTotalSizeBytes  = $MaxTotalSizeBytes }
    if ($KeepLatestN       -gt 0) { $policy.KeepLatestN        = $KeepLatestN }

    $plan = Get-ArtifactDeletionPlan -Artifacts $artifactsRaw -Policy $policy -DryRun:$DryRun

    $output = Format-CleanupPlan -Plan $plan
    Write-Host $output

    if (-not $DryRun -and $plan.ToDelete.Count -gt 0) {
        Write-Host "Live mode: would delete $($plan.ToDelete.Count) artifact(s). (Mock — no real API calls.)"
    }
}
