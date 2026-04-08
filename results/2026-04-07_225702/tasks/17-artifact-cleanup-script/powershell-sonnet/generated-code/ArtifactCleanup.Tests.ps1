# ArtifactCleanup.Tests.ps1
# TDD tests for the artifact cleanup script using Pester 5.
#
# Pester 5 scoping rules:
#   - Top-level code outside blocks runs during DISCOVERY (not test execution).
#   - Functions and variables set in BeforeAll are available inside It blocks.
#   - Use $script: scope to share state set in BeforeAll/BeforeEach with It blocks.

BeforeAll {
    # Import the module under test into this scope
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    # ---------------------------------------------------------------------------
    # Mock artifact data fixture used across all test groups.
    # Total size: 10+20+15+5+8+50 = 108 MB
    # ---------------------------------------------------------------------------
    function script:Get-MockArtifacts {
        $now = [DateTime]::UtcNow
        return @(
            # Workflow-A: 3 artifacts (ages 50d, 20d, 5d)
            [PSCustomObject]@{ Name = "build-output-1"; SizeBytes = 10MB; CreatedAt = $now.AddDays(-50); WorkflowRunId = "workflow-a" },
            [PSCustomObject]@{ Name = "build-output-2"; SizeBytes = 20MB; CreatedAt = $now.AddDays(-20); WorkflowRunId = "workflow-a" },
            [PSCustomObject]@{ Name = "build-output-3"; SizeBytes = 15MB; CreatedAt = $now.AddDays(-5);  WorkflowRunId = "workflow-a" },
            # Workflow-B: 2 artifacts (ages 40d, 2d)
            [PSCustomObject]@{ Name = "test-results-1"; SizeBytes = 5MB;  CreatedAt = $now.AddDays(-40); WorkflowRunId = "workflow-b" },
            [PSCustomObject]@{ Name = "test-results-2"; SizeBytes = 8MB;  CreatedAt = $now.AddDays(-2);  WorkflowRunId = "workflow-b" },
            # Workflow-C: 1 artifact (age 100d)
            [PSCustomObject]@{ Name = "deploy-package-1"; SizeBytes = 50MB; CreatedAt = $now.AddDays(-100); WorkflowRunId = "workflow-c" }
        )
    }
}

# ===========================================================================
# New-RetentionPolicy
# ===========================================================================
Describe "New-RetentionPolicy" {
    It "creates a retention policy with default values" {
        $policy = New-RetentionPolicy
        $policy.MaxAgeDays        | Should -Be 30
        $policy.MaxTotalSizeBytes | Should -Be 1GB
        $policy.KeepLatestN       | Should -Be 3
    }

    It "creates a retention policy with custom values" {
        $policy = New-RetentionPolicy -MaxAgeDays 7 -MaxTotalSizeBytes 500MB -KeepLatestN 2
        $policy.MaxAgeDays        | Should -Be 7
        $policy.MaxTotalSizeBytes | Should -Be 500MB
        $policy.KeepLatestN       | Should -Be 2
    }

    It "rejects negative MaxAgeDays" {
        { New-RetentionPolicy -MaxAgeDays -1 } | Should -Throw
    }

    It "rejects zero KeepLatestN" {
        { New-RetentionPolicy -KeepLatestN 0 } | Should -Throw
    }
}

# ===========================================================================
# Get-ArtifactsByAge
# ===========================================================================
Describe "Get-ArtifactsByAge" {
    It "returns artifacts older than MaxAgeDays" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30
        $expired   = Get-ArtifactsByAge -Artifacts $artifacts -Policy $policy
        # build-output-1 (50d), test-results-1 (40d), deploy-package-1 (100d)
        $expired.Count        | Should -Be 3
        $expired.Name         | Should -Contain "build-output-1"
        $expired.Name         | Should -Contain "test-results-1"
        $expired.Name         | Should -Contain "deploy-package-1"
    }

    It "returns empty list when no artifacts exceed MaxAgeDays" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 200
        $expired   = Get-ArtifactsByAge -Artifacts $artifacts -Policy $policy
        $expired.Count | Should -Be 0
    }
}

# ===========================================================================
# Get-ArtifactsByKeepLatestN
# ===========================================================================
Describe "Get-ArtifactsByKeepLatestN" {
    It "marks older artifacts for deletion keeping only latest N per workflow" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -KeepLatestN 2
        $toDelete  = Get-ArtifactsByKeepLatestN -Artifacts $artifacts -Policy $policy
        # workflow-a has 3; oldest (build-output-1) exceeds KeepLatestN=2
        $toDelete.Name | Should -Contain "build-output-1"
        # workflow-b has exactly 2 — nothing to delete
        $toDelete.Name | Should -Not -Contain "test-results-1"
        $toDelete.Name | Should -Not -Contain "test-results-2"
    }

    It "keeps all artifacts when count is within KeepLatestN limit" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -KeepLatestN 10
        $toDelete  = Get-ArtifactsByKeepLatestN -Artifacts $artifacts -Policy $policy
        $toDelete.Count | Should -Be 0
    }
}

# ===========================================================================
# Get-ArtifactsByTotalSize
# ===========================================================================
Describe "Get-ArtifactsByTotalSize" {
    It "marks oldest artifacts for deletion when total size exceeds MaxTotalSizeBytes" {
        $artifacts = Get-MockArtifacts
        # Total = 108 MB; keep under 60 MB → oldest artifacts deleted first
        $policy   = New-RetentionPolicy -MaxTotalSizeBytes 60MB
        $toDelete = Get-ArtifactsByTotalSize -Artifacts $artifacts -Policy $policy
        $toDelete.Count       | Should -BeGreaterThan 0
        $toDelete.Name        | Should -Contain "deploy-package-1"
    }

    It "returns empty list when total size is within limit" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxTotalSizeBytes 200MB
        $toDelete  = Get-ArtifactsByTotalSize -Artifacts $artifacts -Policy $policy
        $toDelete.Count | Should -Be 0
    }
}

# ===========================================================================
# New-DeletionPlan
# ===========================================================================
Describe "New-DeletionPlan" {
    It "combines all policy violations and deduplicates" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 200MB -KeepLatestN 2
        $plan      = New-DeletionPlan -Artifacts $artifacts -Policy $policy
        $plan.ToDelete | Should -Not -BeNullOrEmpty
        $plan.ToRetain | Should -Not -BeNullOrEmpty
        # No artifact should appear in both lists
        $deleteNames = $plan.ToDelete.Name
        foreach ($retained in $plan.ToRetain) {
            $deleteNames | Should -Not -Contain $retained.Name
        }
    }

    It "includes summary with space reclaimed and counts" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 200MB -KeepLatestN 2
        $plan      = New-DeletionPlan -Artifacts $artifacts -Policy $policy
        $plan.Summary                          | Should -Not -BeNullOrEmpty
        $plan.Summary.TotalSpaceReclaimedBytes | Should -BeGreaterThan 0
        $plan.Summary.ArtifactsToDelete        | Should -BeGreaterThan 0
        $plan.Summary.ArtifactsToRetain        | Should -BeGreaterThan 0
    }

    It "deletes nothing when all artifacts satisfy all policies" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 365 -MaxTotalSizeBytes 1GB -KeepLatestN 10
        $plan      = New-DeletionPlan -Artifacts $artifacts -Policy $policy
        $plan.ToDelete.Count                   | Should -Be 0
        $plan.ToRetain.Count                   | Should -Be 6
        $plan.Summary.TotalSpaceReclaimedBytes | Should -Be 0
    }
}

# ===========================================================================
# Invoke-ArtifactCleanup (dry-run / live mode)
# ===========================================================================
Describe "Invoke-ArtifactCleanup" {
    It "returns plan and marks DryRun=true when in dry-run mode" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 200MB -KeepLatestN 2
        $result    = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -DryRun $true
        $result.DryRun       | Should -Be $true
        $result.Plan         | Should -Not -BeNullOrEmpty
        $result.Plan.Summary | Should -Not -BeNullOrEmpty
    }

    It "marks DryRun=false when not in dry-run mode" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 365 -MaxTotalSizeBytes 1GB -KeepLatestN 10
        $result    = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -DryRun $false
        $result.DryRun | Should -Be $false
    }

    It "throws when Artifacts list is null" {
        $policy = New-RetentionPolicy
        { Invoke-ArtifactCleanup -Artifacts $null -Policy $policy } | Should -Throw
    }
}

# ===========================================================================
# Format-DeletionPlanReport
# ===========================================================================
Describe "Format-DeletionPlanReport" {
    It "returns a non-empty string report in dry-run mode containing DRY RUN" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 200MB -KeepLatestN 2
        $plan      = New-DeletionPlan -Artifacts $artifacts -Policy $policy
        $report    = Format-DeletionPlanReport -Plan $plan -DryRun $true
        $report    | Should -Not -BeNullOrEmpty
        $report    | Should -Match "DRY RUN"
    }

    It "includes Space Reclaimed in the report" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 200MB -KeepLatestN 2
        $plan      = New-DeletionPlan -Artifacts $artifacts -Policy $policy
        $report    = Format-DeletionPlanReport -Plan $plan -DryRun $false
        $report    | Should -Match "Space Reclaimed"
    }

    It "report lists artifact names scheduled for deletion" {
        $artifacts = Get-MockArtifacts
        $policy    = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 200MB -KeepLatestN 2
        $plan      = New-DeletionPlan -Artifacts $artifacts -Policy $policy
        $report    = Format-DeletionPlanReport -Plan $plan -DryRun $true
        foreach ($a in $plan.ToDelete) {
            $report | Should -Match $a.Name
        }
    }
}
