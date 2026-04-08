# ArtifactCleanup.Tests.ps1
# Pester tests for artifact retention policy engine
# TDD approach: tests are written first (red), then implementation makes them pass (green)
#
# Test order follows the TDD cycle:
#   1. Artifact data model
#   2. Retention policy data model
#   3. Max-age policy evaluation
#   4. Max-total-size policy evaluation
#   5. Keep-latest-N-per-workflow policy evaluation
#   6. Combined policy / deletion plan generation
#   7. Dry-run mode

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module under test (will fail until the module exists)
$ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
Import-Module $ModulePath -Force

Describe 'New-Artifact' {
    It 'creates an artifact with all required properties' {
        $createdAt = [datetime]'2026-01-15T10:00:00'
        $artifact = New-Artifact -Name 'build-output.zip' -SizeBytes 1048576 -CreatedAt $createdAt -WorkflowRunId 'run-001'

        $artifact.Name        | Should -Be 'build-output.zip'
        $artifact.SizeBytes   | Should -Be 1048576
        $artifact.CreatedAt   | Should -Be $createdAt
        $artifact.WorkflowRunId | Should -Be 'run-001'
    }

    It 'rejects negative size' {
        { New-Artifact -Name 'bad.zip' -SizeBytes -1 -CreatedAt ([datetime]::Now) -WorkflowRunId 'run-x' } |
            Should -Throw
    }

    It 'rejects empty name' {
        { New-Artifact -Name '' -SizeBytes 100 -CreatedAt ([datetime]::Now) -WorkflowRunId 'run-x' } |
            Should -Throw
    }
}

Describe 'New-RetentionPolicy' {
    It 'creates a policy with default values when no parameters given' {
        $policy = New-RetentionPolicy
        $policy.MaxAgeDays            | Should -BeGreaterThan 0
        $policy.MaxTotalSizeBytes     | Should -BeGreaterThan 0
        $policy.KeepLatestPerWorkflow | Should -BeGreaterThan 0
    }

    It 'accepts explicit parameter values' {
        $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 104857600 -KeepLatestPerWorkflow 5
        $policy.MaxAgeDays            | Should -Be 30
        $policy.MaxTotalSizeBytes     | Should -Be 104857600
        $policy.KeepLatestPerWorkflow | Should -Be 5
    }

    It 'rejects zero MaxAgeDays' {
        { New-RetentionPolicy -MaxAgeDays 0 } | Should -Throw
    }

    It 'rejects zero KeepLatestPerWorkflow' {
        { New-RetentionPolicy -KeepLatestPerWorkflow 0 } | Should -Throw
    }
}

Describe 'Invoke-AgePolicy' {
    BeforeEach {
        # Reference "now" pinned so tests are deterministic
        $Script:ReferenceDate = [datetime]'2026-03-01T00:00:00'

        $Script:Artifacts = @(
            New-Artifact -Name 'old-artifact.zip'    -SizeBytes 500   -CreatedAt ([datetime]'2025-12-01') -WorkflowRunId 'run-1'
            New-Artifact -Name 'recent-artifact.zip' -SizeBytes 300   -CreatedAt ([datetime]'2026-02-28') -WorkflowRunId 'run-2'
            New-Artifact -Name 'ancient-artifact.zip'-SizeBytes 1000  -CreatedAt ([datetime]'2025-01-01') -WorkflowRunId 'run-3'
        )
    }

    It 'marks artifacts older than MaxAgeDays as candidates for deletion' {
        # 30-day max age: 2026-03-01 minus 30 days = 2026-01-30 cutoff
        # old-artifact    (2025-12-01) -> DELETE
        # recent-artifact (2026-02-28) -> KEEP
        # ancient-artifact(2025-01-01) -> DELETE
        $toDelete = Invoke-AgePolicy -Artifacts $Script:Artifacts -MaxAgeDays 30 -ReferenceDate $Script:ReferenceDate

        $toDelete.Count | Should -Be 2
        $toDelete.Name  | Should -Contain 'old-artifact.zip'
        $toDelete.Name  | Should -Contain 'ancient-artifact.zip'
        $toDelete.Name  | Should -Not -Contain 'recent-artifact.zip'
    }

    It 'returns empty array when nothing exceeds max age' {
        $toDelete = Invoke-AgePolicy -Artifacts $Script:Artifacts -MaxAgeDays 3650 -ReferenceDate $Script:ReferenceDate
        $toDelete | Should -HaveCount 0
    }

    It 'returns all artifacts when all exceed max age' {
        $toDelete = Invoke-AgePolicy -Artifacts $Script:Artifacts -MaxAgeDays 1 -ReferenceDate $Script:ReferenceDate
        $toDelete | Should -HaveCount 3
    }

    It 'returns empty array for an empty artifact list' {
        $toDelete = Invoke-AgePolicy -Artifacts @() -MaxAgeDays 30 -ReferenceDate $Script:ReferenceDate
        $toDelete | Should -HaveCount 0
    }
}

Describe 'Invoke-SizePolicy' {
    BeforeEach {
        # Total = 100 + 200 + 300 + 400 + 500 = 1500 bytes
        # Sorted newest-first for eviction (oldest evicted first to get under limit)
        $Script:Artifacts = @(
            New-Artifact -Name 'a1.zip' -SizeBytes 100 -CreatedAt ([datetime]'2026-02-01') -WorkflowRunId 'run-1'
            New-Artifact -Name 'a2.zip' -SizeBytes 200 -CreatedAt ([datetime]'2026-01-20') -WorkflowRunId 'run-2'
            New-Artifact -Name 'a3.zip' -SizeBytes 300 -CreatedAt ([datetime]'2026-01-10') -WorkflowRunId 'run-3'
            New-Artifact -Name 'a4.zip' -SizeBytes 400 -CreatedAt ([datetime]'2025-12-15') -WorkflowRunId 'run-4'
            New-Artifact -Name 'a5.zip' -SizeBytes 500 -CreatedAt ([datetime]'2025-11-01') -WorkflowRunId 'run-5'
        )
    }

    It 'marks oldest artifacts for deletion until total size is within limit' {
        # Limit = 800, total = 1500, need to free >= 700
        # Evict oldest first: a5 (500) -> 1000 remaining, still over
        # Evict a4 (400) -> 600 remaining, now under 800
        # So delete a5 and a4
        $toDelete = Invoke-SizePolicy -Artifacts $Script:Artifacts -MaxTotalSizeBytes 800

        $toDelete | Should -HaveCount 2
        $toDelete.Name | Should -Contain 'a5.zip'
        $toDelete.Name | Should -Contain 'a4.zip'
    }

    It 'returns empty array when total size is within limit' {
        $toDelete = Invoke-SizePolicy -Artifacts $Script:Artifacts -MaxTotalSizeBytes 2000
        $toDelete | Should -HaveCount 0
    }

    It 'returns empty array for an empty artifact list' {
        $toDelete = Invoke-SizePolicy -Artifacts @() -MaxTotalSizeBytes 100
        $toDelete | Should -HaveCount 0
    }

    It 'deletes all if even one artifact exceeds limit' {
        # Limit = 50, smallest artifact is 100 bytes so everything must go
        $toDelete = Invoke-SizePolicy -Artifacts $Script:Artifacts -MaxTotalSizeBytes 50
        $toDelete | Should -HaveCount 5
    }
}

Describe 'Invoke-KeepLatestPolicy' {
    BeforeEach {
        # workflow-A has 4 runs, workflow-B has 2 runs
        $Script:Artifacts = @(
            New-Artifact -Name 'wa-run4.zip' -SizeBytes 100 -CreatedAt ([datetime]'2026-02-20') -WorkflowRunId 'workflow-A'
            New-Artifact -Name 'wa-run3.zip' -SizeBytes 100 -CreatedAt ([datetime]'2026-02-10') -WorkflowRunId 'workflow-A'
            New-Artifact -Name 'wa-run2.zip' -SizeBytes 100 -CreatedAt ([datetime]'2026-01-25') -WorkflowRunId 'workflow-A'
            New-Artifact -Name 'wa-run1.zip' -SizeBytes 100 -CreatedAt ([datetime]'2026-01-10') -WorkflowRunId 'workflow-A'
            New-Artifact -Name 'wb-run2.zip' -SizeBytes 200 -CreatedAt ([datetime]'2026-02-15') -WorkflowRunId 'workflow-B'
            New-Artifact -Name 'wb-run1.zip' -SizeBytes 200 -CreatedAt ([datetime]'2026-01-05') -WorkflowRunId 'workflow-B'
        )
    }

    It 'keeps only the N most recent artifacts per workflow run ID' {
        # Keep 2 per workflow:
        #   workflow-A keeps wa-run4, wa-run3; deletes wa-run2, wa-run1
        #   workflow-B has only 2 so nothing deleted
        $toDelete = Invoke-KeepLatestPolicy -Artifacts $Script:Artifacts -KeepLatestPerWorkflow 2

        $toDelete | Should -HaveCount 2
        $toDelete.Name | Should -Contain 'wa-run2.zip'
        $toDelete.Name | Should -Contain 'wa-run1.zip'
        $toDelete.Name | Should -Not -Contain 'wa-run4.zip'
        $toDelete.Name | Should -Not -Contain 'wa-run3.zip'
    }

    It 'returns empty array when all workflows have N or fewer artifacts' {
        $toDelete = Invoke-KeepLatestPolicy -Artifacts $Script:Artifacts -KeepLatestPerWorkflow 10
        $toDelete | Should -HaveCount 0
    }

    It 'returns all but the newest when KeepLatestPerWorkflow is 1' {
        $toDelete = Invoke-KeepLatestPolicy -Artifacts $Script:Artifacts -KeepLatestPerWorkflow 1
        # workflow-A: keep wa-run4, delete wa-run3, wa-run2, wa-run1
        # workflow-B: keep wb-run2, delete wb-run1
        $toDelete | Should -HaveCount 4
    }

    It 'returns empty array for empty input' {
        $toDelete = Invoke-KeepLatestPolicy -Artifacts @() -KeepLatestPerWorkflow 3
        $toDelete | Should -HaveCount 0
    }
}

Describe 'New-DeletionPlan' {
    BeforeEach {
        # Mix of old, large, and excess-per-workflow artifacts
        $Script:ReferenceDate = [datetime]'2026-03-01T00:00:00'

        $Script:Artifacts = @(
            # Old artifact (>30 days) belonging to workflow-A
            New-Artifact -Name 'old-wa.zip'    -SizeBytes 1000 -CreatedAt ([datetime]'2025-10-01') -WorkflowRunId 'workflow-A'
            # Recent artifact belonging to workflow-A
            New-Artifact -Name 'new-wa.zip'    -SizeBytes  500 -CreatedAt ([datetime]'2026-02-25') -WorkflowRunId 'workflow-A'
            # Recent artifact belonging to workflow-B
            New-Artifact -Name 'b1.zip'        -SizeBytes  800 -CreatedAt ([datetime]'2026-02-20') -WorkflowRunId 'workflow-B'
            # Another recent for workflow-B
            New-Artifact -Name 'b2.zip'        -SizeBytes  300 -CreatedAt ([datetime]'2026-02-10') -WorkflowRunId 'workflow-B'
        )

        $Script:Policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 5000 -KeepLatestPerWorkflow 5
    }

    It 'returns a deletion plan object with all required properties' {
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true

        $plan | Should -Not -BeNullOrEmpty
        $plan.PSObject.Properties.Name | Should -Contain 'ArtifactsToDelete'
        $plan.PSObject.Properties.Name | Should -Contain 'ArtifactsToRetain'
        $plan.PSObject.Properties.Name | Should -Contain 'TotalSpaceReclaimedBytes'
        $plan.PSObject.Properties.Name | Should -Contain 'IsDryRun'
        $plan.PSObject.Properties.Name | Should -Contain 'Summary'
    }

    It 'correctly identifies artifacts to delete via age policy' {
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true

        # old-wa.zip is 152 days old (> 30 days max age) -> should be deleted
        $plan.ArtifactsToDelete.Name | Should -Contain 'old-wa.zip'
        $plan.ArtifactsToRetain.Name | Should -Not -Contain 'old-wa.zip'
    }

    It 'calculates total space reclaimed correctly' {
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true

        # old-wa.zip = 1000 bytes deleted
        $plan.TotalSpaceReclaimedBytes | Should -Be 1000
    }

    It 'sets IsDryRun flag correctly' {
        $dryPlan  = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true
        $realPlan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $false

        $dryPlan.IsDryRun  | Should -Be $true
        $realPlan.IsDryRun | Should -Be $false
    }

    It 'produces a non-empty summary string' {
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true
        $plan.Summary | Should -Not -BeNullOrEmpty
    }

    It 'summary includes retained and deleted counts' {
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true
        $plan.Summary | Should -Match 'retain'
        $plan.Summary | Should -Match 'delete'
    }

    It 'applies all three policies and deduplicates candidates' {
        # Use a tight size policy to force size-based deletions too
        $tightPolicy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 600 -KeepLatestPerWorkflow 5
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $tightPolicy -ReferenceDate $Script:ReferenceDate -DryRun $true

        # ArtifactsToDelete should be a unique set (no duplicates even when multiple policies flag same artifact)
        $uniqueNames = $plan.ArtifactsToDelete.Name | Sort-Object -Unique
        $plan.ArtifactsToDelete.Count | Should -Be $uniqueNames.Count
    }

    It 'ArtifactsToDelete and ArtifactsToRetain are mutually exclusive' {
        $plan = New-DeletionPlan -Artifacts $Script:Artifacts -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true

        foreach ($artifact in $plan.ArtifactsToDelete) {
            $plan.ArtifactsToRetain.Name | Should -Not -Contain $artifact.Name
        }
    }

    It 'handles empty artifact list gracefully' {
        $plan = New-DeletionPlan -Artifacts @() -Policy $Script:Policy -ReferenceDate $Script:ReferenceDate -DryRun $true

        $plan.ArtifactsToDelete      | Should -HaveCount 0
        $plan.ArtifactsToRetain      | Should -HaveCount 0
        $plan.TotalSpaceReclaimedBytes | Should -Be 0
    }
}

Describe 'Format-DeletionPlanSummary' {
    It 'produces human-readable output containing key metrics' {
        $artifacts = @(
            New-Artifact -Name 'keep.zip'   -SizeBytes 2048 -CreatedAt ([datetime]'2026-02-28') -WorkflowRunId 'run-1'
            New-Artifact -Name 'delete.zip' -SizeBytes 4096 -CreatedAt ([datetime]'2025-01-01') -WorkflowRunId 'run-2'
        )
        $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 100000 -KeepLatestPerWorkflow 5
        $plan   = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]'2026-03-01') -DryRun $true

        $output = Format-DeletionPlanSummary -Plan $plan

        $output | Should -Match 'DRY RUN'
        $output | Should -Match '4096'       # space reclaimed in bytes (or formatted)
        $output | Should -Match 'delete\.zip'
        $output | Should -Match 'keep\.zip'
    }

    It 'does not show DRY RUN label when IsDryRun is false' {
        $artifacts = @(
            New-Artifact -Name 'a.zip' -SizeBytes 100 -CreatedAt ([datetime]'2026-02-28') -WorkflowRunId 'run-1'
        )
        $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 100000 -KeepLatestPerWorkflow 5
        $plan   = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]'2026-03-01') -DryRun $false

        $output = Format-DeletionPlanSummary -Plan $plan

        $output | Should -Not -Match 'DRY RUN'
    }
}
