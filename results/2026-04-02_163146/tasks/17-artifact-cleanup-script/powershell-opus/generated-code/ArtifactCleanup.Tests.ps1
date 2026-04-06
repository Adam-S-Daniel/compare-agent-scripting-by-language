# ArtifactCleanup.Tests.ps1
# Pester tests for the artifact cleanup/retention module.
# Written using red/green TDD: each Describe block was written BEFORE
# the corresponding implementation in ArtifactCleanup.ps1.

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"
}

# ============================================================================
# TDD Round 1 (RED then GREEN): Artifact data creation helper
# ============================================================================
Describe 'New-ArtifactData' {
    It 'creates an artifact object with all required properties' {
        $artifact = New-ArtifactData -Name 'build-log' `
            -SizeMB 50 `
            -CreationDate ([datetime]'2026-03-01') `
            -WorkflowRunId 'run-100'

        $artifact.Name          | Should -Be 'build-log'
        $artifact.SizeMB        | Should -Be 50
        $artifact.CreationDate  | Should -Be ([datetime]'2026-03-01')
        $artifact.WorkflowRunId | Should -Be 'run-100'
    }

    It 'defaults SizeMB to 0 when not specified' {
        $artifact = New-ArtifactData -Name 'empty' `
            -CreationDate ([datetime]'2026-01-01') `
            -WorkflowRunId 'run-1'
        $artifact.SizeMB | Should -Be 0
    }
}

# ============================================================================
# TDD Round 2 (RED then GREEN): Age-based retention policy
# ============================================================================
Describe 'Get-ArtifactsExceedingMaxAge' {
    BeforeAll {
        # Reference date: 2026-04-01. MaxAge = 30 days => cutoff = 2026-03-02
        $script:refDate = [datetime]'2026-04-01'

        $script:artifacts = @(
            (New-ArtifactData -Name 'recent'    -SizeMB 10 -CreationDate ([datetime]'2026-03-20') -WorkflowRunId 'run-1')
            (New-ArtifactData -Name 'borderline' -SizeMB 20 -CreationDate ([datetime]'2026-03-02') -WorkflowRunId 'run-2')
            (New-ArtifactData -Name 'old'       -SizeMB 30 -CreationDate ([datetime]'2026-02-15') -WorkflowRunId 'run-3')
            (New-ArtifactData -Name 'ancient'   -SizeMB 40 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'run-4')
        )
    }

    It 'returns only artifacts older than MaxAgeDays' {
        $result = @(Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays 30 -ReferenceDate $script:refDate)
        # cutoff = 2026-03-02; "old" (Feb 15) and "ancient" (Jan 1) are older
        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'old'
        $result.Name  | Should -Contain 'ancient'
    }

    It 'returns nothing when all artifacts are within age limit' {
        $result = @(Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays 365 -ReferenceDate $script:refDate)
        $result.Count | Should -Be 0
    }

    It 'returns all artifacts when MaxAgeDays is 1 and all are older than 1 day' {
        $result = @(Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays 1 -ReferenceDate $script:refDate)
        $result.Count | Should -Be 4
    }

    It 'does not include artifacts exactly at the cutoff boundary' {
        # MaxAgeDays=30, ref=2026-04-01 => cutoff=2026-03-02
        # "borderline" was created on 2026-03-02 which is NOT strictly less than cutoff
        $result = @(Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays 30 -ReferenceDate $script:refDate)
        $result.Name | Should -Not -Contain 'borderline'
    }
}

# ============================================================================
# TDD Round 3 (RED then GREEN): Max total size retention policy
# ============================================================================
Describe 'Get-ArtifactsExceedingMaxSize' {
    BeforeAll {
        # Total size = 10+20+30+40 = 100 MB
        $script:artifacts = @(
            (New-ArtifactData -Name 'oldest'  -SizeMB 40 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'run-1')
            (New-ArtifactData -Name 'old'     -SizeMB 30 -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'run-2')
            (New-ArtifactData -Name 'mid'     -SizeMB 20 -CreationDate ([datetime]'2026-03-01') -WorkflowRunId 'run-3')
            (New-ArtifactData -Name 'newest'  -SizeMB 10 -CreationDate ([datetime]'2026-04-01') -WorkflowRunId 'run-4')
        )
    }

    It 'deletes oldest artifacts when total exceeds budget' {
        # Budget = 50 MB. Newest(10)+Mid(20)+Old(30)=60 > 50, so Old gets cut.
        # Newest(10)+Mid(20)=30 <= 50, keep those. Delete Old(30) and Oldest(40).
        $result = @(Get-ArtifactsExceedingMaxSize -Artifacts $script:artifacts -MaxTotalSizeMB 50)
        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'oldest'
        $result.Name  | Should -Contain 'old'
    }

    It 'returns nothing when total is within budget' {
        $result = @(Get-ArtifactsExceedingMaxSize -Artifacts $script:artifacts -MaxTotalSizeMB 200)
        $result.Count | Should -Be 0
    }

    It 'deletes all but the newest when budget is very small' {
        # Budget = 10 MB — only "newest" (10 MB) fits
        $result = @(Get-ArtifactsExceedingMaxSize -Artifacts $script:artifacts -MaxTotalSizeMB 10)
        $result.Count | Should -Be 3
        $result.Name  | Should -Not -Contain 'newest'
    }

    It 'deletes everything when budget is 0' {
        $result = @(Get-ArtifactsExceedingMaxSize -Artifacts $script:artifacts -MaxTotalSizeMB 0)
        $result.Count | Should -Be 4
    }
}

# ============================================================================
# TDD Round 4 (RED then GREEN): Keep-latest-N per workflow
# ============================================================================
Describe 'Get-ArtifactsExceedingKeepLatest' {
    BeforeAll {
        # Two workflows, each with multiple artifacts
        $script:artifacts = @(
            (New-ArtifactData -Name 'wf1-old'    -SizeMB 10 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'workflow-A')
            (New-ArtifactData -Name 'wf1-mid'    -SizeMB 10 -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'workflow-A')
            (New-ArtifactData -Name 'wf1-new'    -SizeMB 10 -CreationDate ([datetime]'2026-03-01') -WorkflowRunId 'workflow-A')
            (New-ArtifactData -Name 'wf2-old'    -SizeMB 10 -CreationDate ([datetime]'2026-01-15') -WorkflowRunId 'workflow-B')
            (New-ArtifactData -Name 'wf2-new'    -SizeMB 10 -CreationDate ([datetime]'2026-03-15') -WorkflowRunId 'workflow-B')
        )
    }

    It 'keeps only the N newest per workflow and deletes the rest' {
        # Keep 1 per workflow => delete wf1-old, wf1-mid, wf2-old
        $result = @(Get-ArtifactsExceedingKeepLatest -Artifacts $script:artifacts -KeepLatestN 1)
        $result.Count | Should -Be 3
        $result.Name  | Should -Contain 'wf1-old'
        $result.Name  | Should -Contain 'wf1-mid'
        $result.Name  | Should -Contain 'wf2-old'
    }

    It 'returns nothing when all workflows have N or fewer artifacts' {
        # Keep 5 per workflow — no workflow has more than 3
        $result = @(Get-ArtifactsExceedingKeepLatest -Artifacts $script:artifacts -KeepLatestN 5)
        $result.Count | Should -Be 0
    }

    It 'keeps exactly N newest artifacts per workflow' {
        # Keep 2 per workflow => workflow-A keeps wf1-new + wf1-mid, deletes wf1-old
        # workflow-B keeps both (only 2 total)
        $result = @(Get-ArtifactsExceedingKeepLatest -Artifacts $script:artifacts -KeepLatestN 2)
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'wf1-old'
    }
}

# ============================================================================
# TDD Round 5 (RED then GREEN): Combined policies & deletion plan
# ============================================================================
Describe 'Invoke-RetentionPolicy' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-01'
        $script:artifacts = @(
            (New-ArtifactData -Name 'a1' -SizeMB 10 -CreationDate ([datetime]'2026-03-25') -WorkflowRunId 'wf-1')
            (New-ArtifactData -Name 'a2' -SizeMB 20 -CreationDate ([datetime]'2026-03-10') -WorkflowRunId 'wf-1')
            (New-ArtifactData -Name 'a3' -SizeMB 30 -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'wf-2')
            (New-ArtifactData -Name 'a4' -SizeMB 40 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-2')
        )
    }

    It 'returns a plan object with correct structure' {
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 90 `
            -ReferenceDate $script:refDate

        $plan.PSObject.Properties.Name | Should -Contain 'DryRun'
        $plan.PSObject.Properties.Name | Should -Contain 'TotalArtifacts'
        $plan.PSObject.Properties.Name | Should -Contain 'ArtifactsToDelete'
        $plan.PSObject.Properties.Name | Should -Contain 'ArtifactsToRetain'
        $plan.PSObject.Properties.Name | Should -Contain 'DeleteCount'
        $plan.PSObject.Properties.Name | Should -Contain 'RetainCount'
        $plan.PSObject.Properties.Name | Should -Contain 'SpaceReclaimedMB'
        $plan.PSObject.Properties.Name | Should -Contain 'SpaceRetainedMB'
    }

    It 'deletes artifacts based on age policy alone' {
        # MaxAge=30 => cutoff 2026-03-02 => a3 (Feb 1) and a4 (Jan 1) are too old
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 30 `
            -ReferenceDate $script:refDate

        $plan.DeleteCount | Should -Be 2
        $plan.RetainCount | Should -Be 2
        $plan.ArtifactsToDelete.Name | Should -Contain 'a3'
        $plan.ArtifactsToDelete.Name | Should -Contain 'a4'
    }

    It 'combines multiple policies — union of flagged artifacts' {
        # Age=60 => cutoff 2026-01-31 => only a4 (Jan 1) is too old
        # KeepLatest=1 per workflow => wf-1 keeps a1, deletes a2; wf-2 keeps a3, deletes a4
        # Union: a2 (keep-latest) + a4 (age + keep-latest) => delete a2, a4
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 60 `
            -KeepLatestPerWorkflow 1 `
            -ReferenceDate $script:refDate

        $plan.DeleteCount | Should -Be 2
        $plan.ArtifactsToDelete.Name | Should -Contain 'a2'
        $plan.ArtifactsToDelete.Name | Should -Contain 'a4'
    }

    It 'calculates correct space reclaimed and retained' {
        # Delete a3 (30) + a4 (40) = 70 reclaimed, retain a1 (10) + a2 (20) = 30 retained
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 30 `
            -ReferenceDate $script:refDate

        $plan.SpaceReclaimedMB | Should -Be 70
        $plan.SpaceRetainedMB  | Should -Be 30
    }

    It 'throws when no policy is specified' {
        { Invoke-RetentionPolicy -Artifacts $script:artifacts -ReferenceDate $script:refDate } |
            Should -Throw '*At least one retention policy*'
    }

    It 'retains all artifacts when none violate any policy' {
        # Age=365, Size=1000, KeepLatest=10 — nothing should be deleted
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 365 `
            -MaxTotalSizeMB 1000 `
            -KeepLatestPerWorkflow 10 `
            -ReferenceDate $script:refDate

        $plan.DeleteCount | Should -Be 0
        $plan.RetainCount | Should -Be 4
        $plan.SpaceReclaimedMB | Should -Be 0
    }
}

# ============================================================================
# TDD Round 6 (RED then GREEN): Dry-run mode
# ============================================================================
Describe 'Dry-run mode' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-01'
        $script:artifacts = @(
            (New-ArtifactData -Name 'keep-me'   -SizeMB 5  -CreationDate ([datetime]'2026-03-28') -WorkflowRunId 'wf-1')
            (New-ArtifactData -Name 'delete-me'  -SizeMB 50 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-1')
        )
    }

    It 'sets DryRun flag to true when -DryRun is passed' {
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 30 `
            -ReferenceDate $script:refDate `
            -DryRun

        $plan.DryRun | Should -BeTrue
    }

    It 'sets DryRun flag to false when -DryRun is not passed' {
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 30 `
            -ReferenceDate $script:refDate

        $plan.DryRun | Should -BeFalse
    }

    It 'still produces the same deletion plan regardless of DryRun flag' {
        $livePlan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 30 -ReferenceDate $script:refDate

        $dryPlan  = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 30 -ReferenceDate $script:refDate -DryRun

        $dryPlan.DeleteCount      | Should -Be $livePlan.DeleteCount
        $dryPlan.RetainCount      | Should -Be $livePlan.RetainCount
        $dryPlan.SpaceReclaimedMB | Should -Be $livePlan.SpaceReclaimedMB
    }
}

# ============================================================================
# TDD Round 7 (RED then GREEN): Human-readable plan formatting
# ============================================================================
Describe 'Format-DeletionPlan' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-01'
        $artifacts = @(
            (New-ArtifactData -Name 'keep-this'  -SizeMB 10 -CreationDate ([datetime]'2026-03-28') -WorkflowRunId 'wf-1')
            (New-ArtifactData -Name 'remove-this' -SizeMB 25 -CreationDate ([datetime]'2026-01-15') -WorkflowRunId 'wf-2')
        )
        $script:plan = Invoke-RetentionPolicy -Artifacts $artifacts `
            -MaxAgeDays 30 -ReferenceDate $script:refDate -DryRun
    }

    It 'includes DRY RUN label when in dry-run mode' {
        $output = Format-DeletionPlan -Plan $script:plan
        $output | Should -Match 'DRY RUN'
    }

    It 'includes summary counts' {
        $output = Format-DeletionPlan -Plan $script:plan
        $output | Should -Match 'Total artifacts evaluated:\s+2'
        $output | Should -Match 'Artifacts to delete:\s+1'
        $output | Should -Match 'Artifacts to retain:\s+1'
    }

    It 'includes space reclaimed' {
        $output = Format-DeletionPlan -Plan $script:plan
        $output | Should -Match 'Space reclaimed:\s+25 MB'
    }

    It 'lists artifacts marked for deletion' {
        $output = Format-DeletionPlan -Plan $script:plan
        $output | Should -Match '\[DELETE\].*remove-this'
    }

    It 'lists artifacts marked for retention' {
        $output = Format-DeletionPlan -Plan $script:plan
        $output | Should -Match '\[KEEP\].*keep-this'
    }

    It 'includes dry-run disclaimer' {
        $output = Format-DeletionPlan -Plan $script:plan
        $output | Should -Match 'no artifacts were actually deleted'
    }

    It 'shows LIVE label when not in dry-run mode' {
        $artifacts = @(
            (New-ArtifactData -Name 'x' -SizeMB 5 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-1')
        )
        $livePlan = Invoke-RetentionPolicy -Artifacts $artifacts `
            -MaxAgeDays 30 -ReferenceDate $script:refDate
        $output = Format-DeletionPlan -Plan $livePlan
        $output | Should -Match 'LIVE'
        $output | Should -Not -Match 'DRY RUN'
    }
}

# ============================================================================
# TDD Round 8 (RED then GREEN): Error handling and edge cases
# ============================================================================
Describe 'Error handling' {
    It 'throws when Name is missing from New-ArtifactData' {
        { New-ArtifactData -SizeMB 10 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'r1' } |
            Should -Throw
    }

    It 'throws when CreationDate is missing from New-ArtifactData' {
        { New-ArtifactData -Name 'x' -SizeMB 10 -WorkflowRunId 'r1' } |
            Should -Throw
    }

    It 'throws when WorkflowRunId is missing from New-ArtifactData' {
        { New-ArtifactData -Name 'x' -SizeMB 10 -CreationDate ([datetime]'2026-01-01') } |
            Should -Throw
    }
}

# ============================================================================
# TDD Round 9: Integration test — realistic scenario with all policies
# ============================================================================
Describe 'Integration: realistic scenario with all policies' {
    BeforeAll {
        $script:refDate = [datetime]'2026-04-01'

        # Simulate a CI system with two workflows over several months
        $script:artifacts = @(
            # Workflow "build" — 5 artifacts
            (New-ArtifactData -Name 'build-v1'   -SizeMB 100 -CreationDate ([datetime]'2025-10-01') -WorkflowRunId 'build')
            (New-ArtifactData -Name 'build-v2'   -SizeMB 120 -CreationDate ([datetime]'2025-12-01') -WorkflowRunId 'build')
            (New-ArtifactData -Name 'build-v3'   -SizeMB 110 -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'build')
            (New-ArtifactData -Name 'build-v4'   -SizeMB 130 -CreationDate ([datetime]'2026-03-15') -WorkflowRunId 'build')
            (New-ArtifactData -Name 'build-v5'   -SizeMB 105 -CreationDate ([datetime]'2026-03-28') -WorkflowRunId 'build')

            # Workflow "test" — 3 artifacts
            (New-ArtifactData -Name 'test-v1'    -SizeMB 50  -CreationDate ([datetime]'2025-11-01') -WorkflowRunId 'test')
            (New-ArtifactData -Name 'test-v2'    -SizeMB 55  -CreationDate ([datetime]'2026-02-15') -WorkflowRunId 'test')
            (New-ArtifactData -Name 'test-v3'    -SizeMB 60  -CreationDate ([datetime]'2026-03-20') -WorkflowRunId 'test')
        )
        # Total size: 100+120+110+130+105+50+55+60 = 730 MB
    }

    It 'applies all three policies and generates a correct plan' {
        # Policies:
        #   MaxAge = 60 days (cutoff 2026-01-31) => deletes build-v1, build-v2, test-v1
        #   MaxTotalSize = 500 MB => after sorting newest-first:
        #     build-v4(130)+build-v3(110)+build-v5(105)+test-v3(60)+test-v2(55) = 460 <= 500
        #     +build-v2(120) = 580 > 500, so build-v2 deleted, then build-v1(100) and test-v1(50) too
        #   KeepLatest = 3 per workflow => build has 5, delete build-v1 + build-v2; test has 3, keep all
        #
        # Union of all deletions: build-v1, build-v2, test-v1

        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 60 `
            -MaxTotalSizeMB 500 `
            -KeepLatestPerWorkflow 3 `
            -ReferenceDate $script:refDate `
            -DryRun

        $plan.DryRun | Should -BeTrue
        $plan.TotalArtifacts | Should -Be 8

        # These three should be deleted
        $plan.ArtifactsToDelete.Name | Should -Contain 'build-v1'
        $plan.ArtifactsToDelete.Name | Should -Contain 'build-v2'
        $plan.ArtifactsToDelete.Name | Should -Contain 'test-v1'

        # These should be retained
        $plan.ArtifactsToRetain.Name | Should -Contain 'build-v3'
        $plan.ArtifactsToRetain.Name | Should -Contain 'build-v4'
        $plan.ArtifactsToRetain.Name | Should -Contain 'build-v5'
        $plan.ArtifactsToRetain.Name | Should -Contain 'test-v2'
        $plan.ArtifactsToRetain.Name | Should -Contain 'test-v3'

        # Space reclaimed = 100+120+50 = 270 MB
        $plan.SpaceReclaimedMB | Should -Be 270

        # Space retained = 110+130+105+55+60 = 460 MB
        $plan.SpaceRetainedMB | Should -Be 460
    }

    It 'produces formatted output with all sections' {
        $plan = Invoke-RetentionPolicy -Artifacts $script:artifacts `
            -MaxAgeDays 60 `
            -MaxTotalSizeMB 500 `
            -KeepLatestPerWorkflow 3 `
            -ReferenceDate $script:refDate `
            -DryRun

        $output = Format-DeletionPlan -Plan $plan

        # Spot-check key parts of the formatted output
        $output | Should -Match 'DRY RUN'
        $output | Should -Match 'Total artifacts evaluated:\s+8'
        $output | Should -Match '\[DELETE\].*build-v1'
        $output | Should -Match '\[KEEP\].*build-v5'
        $output | Should -Match 'Space reclaimed:\s+270 MB'
    }
}
