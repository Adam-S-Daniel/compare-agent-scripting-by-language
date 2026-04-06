# ArtifactCleanup.ps1
# Artifact retention policy engine.
#
# Functions:
#   Get-MockArtifacts          – Returns sample artifact data for testing / demo
#   Invoke-MaxAgePolicy        – Marks artifacts older than MaxAgeDays for deletion
#   Invoke-MaxSizePolicy       – Marks oldest artifacts for deletion until total size ≤ limit
#   Invoke-KeepLatestNPolicy   – Marks excess artifacts per workflow for deletion
#   Invoke-RetentionPolicies   – Applies all three policies in sequence
#   New-DeletionPlan           – Builds a structured plan + summary from marked artifacts
#   Invoke-ArtifactCleanup     – Top-level entry point with dry-run support

# ---------------------------------------------------------------------------
# CYCLE 1 — Mock data
# ---------------------------------------------------------------------------

function Get-MockArtifacts {
    <#
    .SYNOPSIS
        Returns a list of mock artifact objects for development and testing.
    #>
    $now = [datetime]::UtcNow

    return @(
        [PSCustomObject]@{
            Name          = "build-output-main-v1"
            SizeBytes     = 120MB
            CreatedAt     = $now.AddDays(-60)
            WorkflowRunId = "workflow-build"
        }
        [PSCustomObject]@{
            Name          = "build-output-main-v2"
            SizeBytes     = 135MB
            CreatedAt     = $now.AddDays(-45)
            WorkflowRunId = "workflow-build"
        }
        [PSCustomObject]@{
            Name          = "build-output-main-v3"
            SizeBytes     = 128MB
            CreatedAt     = $now.AddDays(-20)
            WorkflowRunId = "workflow-build"
        }
        [PSCustomObject]@{
            Name          = "build-output-main-v4"
            SizeBytes     = 142MB
            CreatedAt     = $now.AddDays(-3)
            WorkflowRunId = "workflow-build"
        }
        [PSCustomObject]@{
            Name          = "deploy-package-v1"
            SizeBytes     = 80MB
            CreatedAt     = $now.AddDays(-90)
            WorkflowRunId = "workflow-deploy"
        }
        [PSCustomObject]@{
            Name          = "deploy-package-v2"
            SizeBytes     = 85MB
            CreatedAt     = $now.AddDays(-30)
            WorkflowRunId = "workflow-deploy"
        }
        [PSCustomObject]@{
            Name          = "deploy-package-v3"
            SizeBytes     = 88MB
            CreatedAt     = $now.AddDays(-7)
            WorkflowRunId = "workflow-deploy"
        }
        [PSCustomObject]@{
            Name          = "test-results-latest"
            SizeBytes     = 15MB
            CreatedAt     = $now.AddDays(-1)
            WorkflowRunId = "workflow-test"
        }
    )
}

# ---------------------------------------------------------------------------
# INTERNAL HELPER — ensure artifact is a PSCustomObject with required fields
# ---------------------------------------------------------------------------

function ConvertTo-ArtifactObject {
    param($Artifact)

    # Accept both hashtables and PSCustomObjects
    if ($Artifact -is [hashtable]) {
        $obj = [PSCustomObject]$Artifact
    } else {
        $obj = $Artifact
    }

    # Ensure the MarkedForDeletion and DeletionReasons properties exist
    if (-not ($obj.PSObject.Properties.Name -contains "MarkedForDeletion")) {
        $obj | Add-Member -NotePropertyName MarkedForDeletion -NotePropertyValue $false -Force
    }
    if (-not ($obj.PSObject.Properties.Name -contains "DeletionReasons")) {
        $obj | Add-Member -NotePropertyName DeletionReasons -NotePropertyValue @() -Force
    }

    return $obj
}

# ---------------------------------------------------------------------------
# CYCLE 2 — Max-age policy
# ---------------------------------------------------------------------------

function Invoke-MaxAgePolicy {
    <#
    .SYNOPSIS
        Marks artifacts older than MaxAgeDays for deletion.
    .PARAMETER Artifacts
        Array of artifact objects (hashtables or PSCustomObjects).
    .PARAMETER MaxAgeDays
        Artifacts created more than this many days ago are marked for deletion.
    .PARAMETER ReferenceTime
        The point-in-time used as "now". Defaults to [datetime]::UtcNow.
        Inject a fixed value in tests to avoid timing flakiness.
    #>
    param(
        [Parameter(Mandatory)]
        $Artifacts,

        [Parameter(Mandatory)]
        [int]$MaxAgeDays,

        [Parameter()]
        [datetime]$ReferenceTime = [datetime]::UtcNow
    )

    # Use the injected reference time so tests are deterministic
    $cutoff = $ReferenceTime.AddDays(-$MaxAgeDays)

    $result = foreach ($a in $Artifacts) {
        $obj = ConvertTo-ArtifactObject $a

        # Strict greater-than: artifact created BEFORE the cutoff is too old
        if ($obj.CreatedAt -lt $cutoff) {
            $obj.MarkedForDeletion = $true
            $reasons = [System.Collections.Generic.List[string]] $obj.DeletionReasons
            if (-not $reasons.Contains("MaxAge")) { $reasons.Add("MaxAge") }
            $obj.DeletionReasons = $reasons.ToArray()
        }

        $obj
    }

    return $result
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Max total-size policy
# ---------------------------------------------------------------------------

function Invoke-MaxSizePolicy {
    <#
    .SYNOPSIS
        Marks the oldest un-deleted artifacts for deletion until the total
        remaining size is at or below MaxTotalSizeBytes.
    .PARAMETER Artifacts
        Array of artifact objects.
    .PARAMETER MaxTotalSizeBytes
        Maximum allowed total size in bytes.
    #>
    param(
        [Parameter(Mandatory)]
        $Artifacts,

        [Parameter(Mandatory)]
        [long]$MaxTotalSizeBytes
    )

    # Convert all items to PSCustomObjects with the deletion fields
    $objs = foreach ($a in $Artifacts) { ConvertTo-ArtifactObject $a }

    # Compute current "live" total (artifacts NOT already marked for deletion)
    $liveArtifacts = $objs | Where-Object { -not $_.MarkedForDeletion }
    $totalSize     = ($liveArtifacts | Measure-Object -Property SizeBytes -Sum).Sum
    if (-not $totalSize) { $totalSize = 0 }

    if ($totalSize -le $MaxTotalSizeBytes) {
        # Already within limit — nothing to do
        return $objs
    }

    # Sort live artifacts oldest-first; delete them one by one until under limit
    $sorted = $liveArtifacts | Sort-Object CreatedAt

    foreach ($candidate in $sorted) {
        if ($totalSize -le $MaxTotalSizeBytes) { break }

        $candidate.MarkedForDeletion = $true
        $reasons = [System.Collections.Generic.List[string]] $candidate.DeletionReasons
        if (-not $reasons.Contains("MaxSize")) { $reasons.Add("MaxSize") }
        $candidate.DeletionReasons = $reasons.ToArray()

        $totalSize -= $candidate.SizeBytes
    }

    return $objs
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Keep-latest-N per workflow policy
# ---------------------------------------------------------------------------

function Invoke-KeepLatestNPolicy {
    <#
    .SYNOPSIS
        Within each workflow (grouped by WorkflowRunId), keeps only the N
        most-recent artifacts and marks older ones for deletion.
    .PARAMETER Artifacts
        Array of artifact objects.
    .PARAMETER KeepLatestN
        Number of most-recent artifacts to retain per workflow run ID.
    #>
    param(
        [Parameter(Mandatory)]
        $Artifacts,

        [Parameter(Mandatory)]
        [int]$KeepLatestN
    )

    # Convert all items
    $objs = foreach ($a in $Artifacts) { ConvertTo-ArtifactObject $a }

    # Group by WorkflowRunId
    $groups = $objs | Group-Object -Property WorkflowRunId

    foreach ($group in $groups) {
        # Sort newest-first
        $sortedGroup = $group.Group | Sort-Object CreatedAt -Descending

        # Everything beyond index KeepLatestN-1 is excess
        for ($i = $KeepLatestN; $i -lt $sortedGroup.Count; $i++) {
            $excess = $sortedGroup[$i]
            $excess.MarkedForDeletion = $true
            $reasons = [System.Collections.Generic.List[string]] $excess.DeletionReasons
            if (-not $reasons.Contains("KeepLatestN")) { $reasons.Add("KeepLatestN") }
            $excess.DeletionReasons = $reasons.ToArray()
        }
    }

    return $objs
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Combined policy application
# ---------------------------------------------------------------------------

function Invoke-RetentionPolicies {
    <#
    .SYNOPSIS
        Applies MaxAge, MaxSize, and KeepLatestN policies in sequence.
    .PARAMETER Artifacts
        Array of artifact objects.
    .PARAMETER Policy
        Hashtable with keys: MaxAgeDays, MaxTotalSizeBytes, KeepLatestN.
    .PARAMETER ReferenceTime
        The point-in-time used as "now" for age calculations. Defaults to UtcNow.
    #>
    param(
        [Parameter(Mandatory)]
        $Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [Parameter()]
        [datetime]$ReferenceTime = [datetime]::UtcNow
    )

    Confirm-Policy $Policy

    $result = Invoke-MaxAgePolicy      -Artifacts $Artifacts -MaxAgeDays       $Policy.MaxAgeDays -ReferenceTime $ReferenceTime
    $result = Invoke-MaxSizePolicy     -Artifacts $result    -MaxTotalSizeBytes $Policy.MaxTotalSizeBytes
    $result = Invoke-KeepLatestNPolicy -Artifacts $result    -KeepLatestN      $Policy.KeepLatestN

    return $result
}

# ---------------------------------------------------------------------------
# INTERNAL — policy validation
# ---------------------------------------------------------------------------

function Confirm-Policy {
    param([hashtable]$Policy)

    $required = @("MaxAgeDays", "MaxTotalSizeBytes", "KeepLatestN")
    $missing  = $required | Where-Object { -not $Policy.ContainsKey($_) }

    if ($missing) {
        throw "Policy is missing required keys: $($missing -join ', '). " +
              "Required keys are: MaxAgeDays, MaxTotalSizeBytes, KeepLatestN."
    }
}

# ---------------------------------------------------------------------------
# CYCLE 6 — Deletion plan / summary
# ---------------------------------------------------------------------------

function New-DeletionPlan {
    <#
    .SYNOPSIS
        Builds a structured deletion plan from a list of marked artifacts.
    .PARAMETER Artifacts
        Array of artifact objects with MarkedForDeletion set.
    #>
    param(
        [Parameter(Mandatory)]
        $Artifacts
    )

    $toDelete = @($Artifacts | Where-Object { $_.MarkedForDeletion -eq $true })
    $toRetain = @($Artifacts | Where-Object { $_.MarkedForDeletion -ne $true })

    $spaceReclaimed = ($toDelete | Measure-Object -Property SizeBytes -Sum).Sum
    if (-not $spaceReclaimed) { $spaceReclaimed = 0 }

    $reclaimedMB = [math]::Round($spaceReclaimed / 1MB, 2)
    $totalMB     = [math]::Round(($Artifacts | Measure-Object -Property SizeBytes -Sum).Sum / 1MB, 2)

    $summary = (
        "Deletion plan: {0} artifact(s) to delete ({1} MB reclaimed), " +
        "{2} artifact(s) to retain. " +
        "Total original size: {3} MB."
    ) -f $toDelete.Count, $reclaimedMB, $toRetain.Count, $totalMB

    return [PSCustomObject]@{
        ArtifactsToDelete  = $toDelete
        ArtifactsToRetain  = $toRetain
        SpaceReclaimedBytes = $spaceReclaimed
        Summary            = $summary
    }
}

# ---------------------------------------------------------------------------
# CYCLE 7 — Top-level entry point with dry-run support
# ---------------------------------------------------------------------------

function Invoke-ArtifactCleanup {
    <#
    .SYNOPSIS
        Applies retention policies to artifacts and generates a deletion plan.
    .PARAMETER Artifacts
        Array of artifact objects to evaluate.
    .PARAMETER Policy
        Hashtable with keys: MaxAgeDays, MaxTotalSizeBytes, KeepLatestN.
    .PARAMETER DryRun
        When $true the plan is generated but no deletion callbacks are invoked.
    .PARAMETER ReferenceTime
        Point-in-time used as "now" for age calculations. Defaults to UtcNow.
    .OUTPUTS
        PSCustomObject with ArtifactsToDelete, ArtifactsToRetain,
        SpaceReclaimedBytes, Summary, and IsDryRun.
    #>
    param(
        [Parameter(Mandatory)]
        $Artifacts,

        [Parameter(Mandatory)]
        [hashtable]$Policy,

        [Parameter(Mandatory)]
        [bool]$DryRun,

        [Parameter()]
        [datetime]$ReferenceTime = [datetime]::UtcNow
    )

    # Validate policy up front so errors are surfaced immediately
    Confirm-Policy $Policy

    # Apply all retention policies
    $markedArtifacts = Invoke-RetentionPolicies -Artifacts $Artifacts -Policy $Policy -ReferenceTime $ReferenceTime

    # Build the deletion plan
    $plan = New-DeletionPlan -Artifacts $markedArtifacts

    # Attach the dry-run flag so callers can inspect it
    $plan | Add-Member -NotePropertyName IsDryRun -NotePropertyValue $DryRun -Force

    if (-not $DryRun) {
        # In a real implementation this is where you would call the GitHub API
        # (or another deletion endpoint) for each artifact in $plan.ArtifactsToDelete.
        # For this script the "deletion" is a no-op because all data is mock.
        Write-Verbose "Dry-run is OFF — in a real environment, $($plan.ArtifactsToDelete.Count) artifact(s) would be deleted."
    } else {
        Write-Verbose "Dry-run mode: no artifacts will be deleted."
    }

    return $plan
}
