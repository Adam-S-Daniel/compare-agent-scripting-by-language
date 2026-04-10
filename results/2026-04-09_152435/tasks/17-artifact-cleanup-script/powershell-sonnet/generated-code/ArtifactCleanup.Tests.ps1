# Pester tests for ArtifactCleanup.ps1
# TDD: tests written first, then implementation added to make them pass
#
# Pester 5 note: helper functions and shared variables MUST be inside BeforeAll
# so they are available during the run phase (not just discovery phase).

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    # Reference date for deterministic tests
    $script:BaseDate = [datetime]"2026-04-10T00:00:00Z"

    # Helper to create mock artifact objects
    function script:New-MockArtifact {
        param(
            [string]   $Name,
            [long]     $SizeBytes,
            [datetime] $CreatedAt,
            [string]   $WorkflowRunId
        )
        [PSCustomObject]@{
            Name          = $Name
            SizeBytes     = $SizeBytes
            CreatedAt     = $CreatedAt
            WorkflowRunId = $WorkflowRunId
        }
    }
}

Describe "Get-ArtifactsExceedingMaxAge" {
    It "Returns artifacts older than max age days" {
        $artifacts = @(
            New-MockArtifact -Name "old-artifact" -SizeBytes 1000 -CreatedAt $script:BaseDate.AddDays(-31) -WorkflowRunId "run-1"
            New-MockArtifact -Name "new-artifact" -SizeBytes 500  -CreatedAt $script:BaseDate.AddDays(-5)  -WorkflowRunId "run-2"
        )
        $result = Get-ArtifactsExceedingMaxAge -Artifacts $artifacts -MaxAgeDays 30 -ReferenceDate $script:BaseDate
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "old-artifact"
    }

    It "Returns empty when no artifacts exceed max age" {
        $artifacts = @(
            New-MockArtifact -Name "fresh" -SizeBytes 100 -CreatedAt $script:BaseDate.AddDays(-1) -WorkflowRunId "run-1"
        )
        $result = Get-ArtifactsExceedingMaxAge -Artifacts $artifacts -MaxAgeDays 30 -ReferenceDate $script:BaseDate
        $result | Should -BeNullOrEmpty
    }

    It "Treats artifact exactly at boundary as not expired" {
        $artifacts = @(
            New-MockArtifact -Name "boundary" -SizeBytes 100 -CreatedAt $script:BaseDate.AddDays(-30) -WorkflowRunId "run-1"
        )
        $result = Get-ArtifactsExceedingMaxAge -Artifacts $artifacts -MaxAgeDays 30 -ReferenceDate $script:BaseDate
        $result | Should -BeNullOrEmpty
    }
}

Describe "Get-ArtifactsExceedingTotalSize" {
    It "Returns oldest artifacts that push total over limit" {
        $artifacts = @(
            New-MockArtifact -Name "art-newest" -SizeBytes 200MB -CreatedAt $script:BaseDate.AddDays(-1)  -WorkflowRunId "run-3"
            New-MockArtifact -Name "art-middle" -SizeBytes 200MB -CreatedAt $script:BaseDate.AddDays(-10) -WorkflowRunId "run-2"
            New-MockArtifact -Name "art-oldest" -SizeBytes 200MB -CreatedAt $script:BaseDate.AddDays(-20) -WorkflowRunId "run-1"
        )
        # Max 350MB: newest fits (200MB); middle+newest = 400MB > 350MB, so middle and oldest are excess
        $result = Get-ArtifactsExceedingTotalSize -Artifacts $artifacts -MaxTotalSizeBytes (350MB)
        $result.Count | Should -Be 2
        ($result | Where-Object Name -eq "art-oldest").Name | Should -Be "art-oldest"
        ($result | Where-Object Name -eq "art-middle").Name | Should -Be "art-middle"
    }

    It "Returns empty when total size is within limit" {
        $artifacts = @(
            New-MockArtifact -Name "small" -SizeBytes 10MB -CreatedAt $script:BaseDate -WorkflowRunId "run-1"
        )
        $result = Get-ArtifactsExceedingTotalSize -Artifacts $artifacts -MaxTotalSizeBytes (100MB)
        $result | Should -BeNullOrEmpty
    }
}

Describe "Get-ArtifactsBeyondKeepLatestN" {
    It "Removes artifacts beyond keep-latest-N per workflow" {
        $artifacts = @(
            New-MockArtifact -Name "wf1-run3" -SizeBytes 100 -CreatedAt $script:BaseDate.AddDays(-1)  -WorkflowRunId "wf1"
            New-MockArtifact -Name "wf1-run2" -SizeBytes 100 -CreatedAt $script:BaseDate.AddDays(-2)  -WorkflowRunId "wf1"
            New-MockArtifact -Name "wf1-run1" -SizeBytes 100 -CreatedAt $script:BaseDate.AddDays(-3)  -WorkflowRunId "wf1"
            New-MockArtifact -Name "wf2-run1" -SizeBytes 100 -CreatedAt $script:BaseDate.AddDays(-1)  -WorkflowRunId "wf2"
        )
        $result = Get-ArtifactsBeyondKeepLatestN -Artifacts $artifacts -KeepLatestN 2
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "wf1-run1"
    }

    It "Keeps all artifacts when count is within limit" {
        $artifacts = @(
            New-MockArtifact -Name "only-one" -SizeBytes 100 -CreatedAt $script:BaseDate -WorkflowRunId "wf1"
        )
        $result = Get-ArtifactsBeyondKeepLatestN -Artifacts $artifacts -KeepLatestN 3
        $result | Should -BeNullOrEmpty
    }
}

Describe "New-DeletionPlan" {
    It "Combines all retention policies and deduplicates" {
        $artifacts = @(
            New-MockArtifact -Name "expired-and-excess" -SizeBytes 500MB -CreatedAt $script:BaseDate.AddDays(-60) -WorkflowRunId "wf1"
            New-MockArtifact -Name "just-expired"       -SizeBytes 10MB  -CreatedAt $script:BaseDate.AddDays(-40) -WorkflowRunId "wf1"
            New-MockArtifact -Name "fresh-keeper"       -SizeBytes 5MB   -CreatedAt $script:BaseDate.AddDays(-2)  -WorkflowRunId "wf1"
        )
        $policy = [PSCustomObject]@{
            MaxAgeDays        = 30
            MaxTotalSizeBytes = 400MB
            KeepLatestN       = 2
        }
        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $script:BaseDate
        $plan.ToDelete.Name | Should -Contain "expired-and-excess"
        $plan.ToDelete.Name | Should -Contain "just-expired"
        $plan.ToDelete.Name | Should -Not -Contain "fresh-keeper"
    }

    It "Reports correct space reclaimed and retention counts" {
        $artifacts = @(
            New-MockArtifact -Name "del1"  -SizeBytes 100MB -CreatedAt $script:BaseDate.AddDays(-50) -WorkflowRunId "wf1"
            New-MockArtifact -Name "keep1" -SizeBytes 50MB  -CreatedAt $script:BaseDate.AddDays(-1)  -WorkflowRunId "wf1"
        )
        $policy = [PSCustomObject]@{ MaxAgeDays = 30; MaxTotalSizeBytes = 1GB; KeepLatestN = 10 }
        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $script:BaseDate
        $plan.SpaceReclaimedBytes | Should -Be 100MB
        $plan.RetainedCount       | Should -Be 1
        $plan.DeletedCount        | Should -Be 1
    }
}

Describe "Invoke-ArtifactCleanup (dry-run)" {
    It "Does not delete anything in dry-run mode and returns summary" {
        $artifacts = @(
            New-MockArtifact -Name "old" -SizeBytes 50MB -CreatedAt $script:BaseDate.AddDays(-60) -WorkflowRunId "wf1"
            New-MockArtifact -Name "new" -SizeBytes 10MB -CreatedAt $script:BaseDate.AddDays(-1)  -WorkflowRunId "wf1"
        )
        $policy = [PSCustomObject]@{ MaxAgeDays = 30; MaxTotalSizeBytes = 1GB; KeepLatestN = 10 }
        $output = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -DryRun -ReferenceDate $script:BaseDate
        $output.DryRun              | Should -Be $true
        $output.DeletedCount        | Should -Be 1
        $output.RetainedCount       | Should -Be 1
        $output.SpaceReclaimedBytes | Should -Be 50MB
    }

    It "Returns deletion plan with artifact names in dry-run" {
        $artifacts = @(
            New-MockArtifact -Name "stale" -SizeBytes 20MB -CreatedAt $script:BaseDate.AddDays(-45) -WorkflowRunId "wf1"
        )
        $policy = [PSCustomObject]@{ MaxAgeDays = 30; MaxTotalSizeBytes = 1GB; KeepLatestN = 10 }
        $output = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -DryRun -ReferenceDate $script:BaseDate
        $output.Plan.ToDelete[0].Name | Should -Be "stale"
    }
}

Describe "Format-CleanupSummary" {
    It "Produces human-readable summary with expected fields" {
        $plan = [PSCustomObject]@{
            ToDelete            = @( [PSCustomObject]@{ Name = "art1"; SizeBytes = 100MB; CreatedAt = $script:BaseDate.AddDays(-40) } )
            ToRetain            = @( [PSCustomObject]@{ Name = "art2"; SizeBytes = 50MB;  CreatedAt = $script:BaseDate.AddDays(-2)  } )
            SpaceReclaimedBytes = 100MB
            DeletedCount        = 1
            RetainedCount       = 1
            DryRun              = $true
        }
        $summary = Format-CleanupSummary -Plan $plan
        $summary | Should -Match "DRY RUN"
        $summary | Should -Match "Artifacts to delete:\s+1"
        $summary | Should -Match "Artifacts to retain:\s+1"
        $summary | Should -Match "Space reclaimed:"
    }
}

Describe "Workflow structure" {
    It "Workflow file exists at expected path" {
        $wfPath = "$PSScriptRoot/.github/workflows/artifact-cleanup-script.yml"
        $wfPath | Should -Exist
    }

    It "Workflow references correct script file" {
        $wfPath = "$PSScriptRoot/.github/workflows/artifact-cleanup-script.yml"
        $content = Get-Content $wfPath -Raw
        $content | Should -Match "ArtifactCleanup.ps1"
    }

    It "Workflow has push trigger" {
        $wfPath = "$PSScriptRoot/.github/workflows/artifact-cleanup-script.yml"
        $content = Get-Content $wfPath -Raw
        $content | Should -Match "push"
    }

    It "Main script file exists" {
        "$PSScriptRoot/ArtifactCleanup.ps1" | Should -Exist
    }
}
