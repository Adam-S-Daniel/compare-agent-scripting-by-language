#Requires -Modules Pester
# TDD Note: This test file was written BEFORE the implementation.
# Tests are written to define the expected behavior, then the implementation
# is written to satisfy these tests (red → green → refactor).
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module "$PSScriptRoot/ArtifactCleanup.psm1" -Force
}

# ─────────────────────────────────────────────
# RED PHASE 1: Define artifact data model
# ─────────────────────────────────────────────
Describe 'New-ArtifactRecord' {
    Context 'Creates valid artifacts' {
        It 'creates an artifact with all required fields' {
            [datetime]$date = [datetime]'2026-01-15'
            $artifact = New-ArtifactRecord `
                -Name         'build-output' `
                -SizeBytes    ([long]1048576) `
                -CreatedAt    $date `
                -WorkflowRunId 'run-123'

            $artifact.Name          | Should -Be 'build-output'
            $artifact.SizeBytes     | Should -Be ([long]1048576)
            $artifact.CreatedAt     | Should -Be $date
            $artifact.WorkflowRunId | Should -Be 'run-123'
        }

        It 'stores SizeBytes as a long (supports files > 2 GB)' {
            # 5 GB exceeds int32 max — must be stored as long
            [long]$fiveGb = [long]5 * [long]1073741824
            $artifact = New-ArtifactRecord `
                -Name          'large-artifact' `
                -SizeBytes     $fiveGb `
                -CreatedAt     (Get-Date) `
                -WorkflowRunId 'run-456'

            $artifact.SizeBytes | Should -Be $fiveGb
        }
    }
}

# ─────────────────────────────────────────────
# RED PHASE 2: Define retention policy model
# ─────────────────────────────────────────────
Describe 'New-RetentionPolicy' {
    Context 'Default policy (no constraints)' {
        It 'creates a policy with null defaults when no parameters supplied' {
            $policy = New-RetentionPolicy

            $policy.MaxAgeDays        | Should -Be $null
            $policy.MaxTotalSizeBytes | Should -Be $null
            $policy.KeepLatestN       | Should -Be $null
        }
    }

    Context 'Single-constraint policies' {
        It 'creates a policy with only MaxAgeDays set' {
            $policy = New-RetentionPolicy -MaxAgeDays 30

            $policy.MaxAgeDays        | Should -Be 30
            $policy.MaxTotalSizeBytes | Should -Be $null
            $policy.KeepLatestN       | Should -Be $null
        }

        It 'creates a policy with only MaxTotalSizeBytes set' {
            [long]$limit = [long]1073741824  # 1 GB
            $policy = New-RetentionPolicy -MaxTotalSizeBytes $limit

            $policy.MaxAgeDays        | Should -Be $null
            $policy.MaxTotalSizeBytes | Should -Be $limit
            $policy.KeepLatestN       | Should -Be $null
        }

        It 'creates a policy with only KeepLatestN set' {
            $policy = New-RetentionPolicy -KeepLatestN 5

            $policy.MaxAgeDays        | Should -Be $null
            $policy.MaxTotalSizeBytes | Should -Be $null
            $policy.KeepLatestN       | Should -Be 5
        }
    }

    Context 'Combined policy' {
        It 'stores all three constraints when all are specified' {
            [long]$limit = [long]1073741824
            $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes $limit -KeepLatestN 5

            $policy.MaxAgeDays        | Should -Be 30
            $policy.MaxTotalSizeBytes | Should -Be $limit
            $policy.KeepLatestN       | Should -Be 5
        }
    }
}

# ─────────────────────────────────────────────
# RED PHASE 3: MaxAgeDays retention logic
# ─────────────────────────────────────────────
Describe 'Get-ArtifactsToDelete - MaxAgeDays policy' {
    BeforeAll {
        [datetime]$Script:Ref = [datetime]'2026-04-06'

        # Five artifacts across two workflows at different ages
        $Script:Fixtures = @(
            (New-ArtifactRecord -Name 'wf1-old' -SizeBytes ([long]104857600)  -CreatedAt $Script:Ref.AddDays(-60) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-mid' -SizeBytes ([long]104857600)  -CreatedAt $Script:Ref.AddDays(-20) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-new' -SizeBytes ([long]104857600)  -CreatedAt $Script:Ref.AddDays(-5)  -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf2-old' -SizeBytes ([long]209715200)  -CreatedAt $Script:Ref.AddDays(-45) -WorkflowRunId 'wf2')
            (New-ArtifactRecord -Name 'wf2-new' -SizeBytes ([long]209715200)  -CreatedAt $Script:Ref.AddDays(-10) -WorkflowRunId 'wf2')
        )
    }

    It 'marks artifacts older than MaxAgeDays for deletion' {
        $policy = New-RetentionPolicy -MaxAgeDays 30

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:Fixtures `
            -Policy        $policy `
            -ReferenceDate $Script:Ref

        $result                | Should -HaveCount 2
        $result.Name           | Should -Contain 'wf1-old'
        $result.Name           | Should -Contain 'wf2-old'
    }

    It 'does not mark artifacts within the age limit' {
        $policy = New-RetentionPolicy -MaxAgeDays 30

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:Fixtures `
            -Policy        $policy `
            -ReferenceDate $Script:Ref

        $result.Name | Should -Not -Contain 'wf1-mid'
        $result.Name | Should -Not -Contain 'wf1-new'
        $result.Name | Should -Not -Contain 'wf2-new'
    }

    It 'returns an empty array when all artifacts are within the age limit' {
        $policy = New-RetentionPolicy -MaxAgeDays 365

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:Fixtures `
            -Policy        $policy `
            -ReferenceDate $Script:Ref

        $result | Should -HaveCount 0
    }

    It 'treats an artifact exactly at the cutoff boundary as retained' {
        # Artifact created exactly MaxAgeDays ago (not strictly older) should be kept
        $policy = New-RetentionPolicy -MaxAgeDays 30
        [PSCustomObject[]]$boundary = @(
            (New-ArtifactRecord -Name 'boundary' -SizeBytes ([long]1024) `
                -CreatedAt $Script:Ref.AddDays(-30) -WorkflowRunId 'wf1')
        )

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $boundary `
            -Policy        $policy `
            -ReferenceDate $Script:Ref

        $result | Should -HaveCount 0
    }
}

# ─────────────────────────────────────────────
# RED PHASE 4: MaxTotalSizeBytes retention logic
# ─────────────────────────────────────────────
Describe 'Get-ArtifactsToDelete - MaxTotalSizeBytes policy' {
    BeforeAll {
        [datetime]$Script:SizeRef = [datetime]'2026-04-06'

        # Total size = 3×100 MB + 2×200 MB = 700 MB
        $Script:SizeFixtures = @(
            (New-ArtifactRecord -Name 'wf1-old' -SizeBytes ([long]104857600)  -CreatedAt $Script:SizeRef.AddDays(-60) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-mid' -SizeBytes ([long]104857600)  -CreatedAt $Script:SizeRef.AddDays(-20) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-new' -SizeBytes ([long]104857600)  -CreatedAt $Script:SizeRef.AddDays(-5)  -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf2-old' -SizeBytes ([long]209715200)  -CreatedAt $Script:SizeRef.AddDays(-45) -WorkflowRunId 'wf2')
            (New-ArtifactRecord -Name 'wf2-new' -SizeBytes ([long]209715200)  -CreatedAt $Script:SizeRef.AddDays(-10) -WorkflowRunId 'wf2')
        )
    }

    It 'deletes oldest artifacts until total size is within the limit' {
        # Limit = 500 MB; total = 700 MB; need to reclaim ≥ 200 MB
        # Delete order (oldest first): wf1-old (100 MB) → running total 100 MB
        # Still need more → wf2-old (200 MB) → running total 300 MB ≥ 200 MB → stop
        [long]$limitBytes = [long]524288000  # 500 MB

        $policy = New-RetentionPolicy -MaxTotalSizeBytes $limitBytes

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:SizeFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:SizeRef

        $result      | Should -HaveCount 2
        $result.Name | Should -Contain 'wf1-old'
        $result.Name | Should -Contain 'wf2-old'
    }

    It 'returns empty array when total size is already within limit' {
        # Limit larger than total (700 MB) — nothing to delete
        [long]$totalSize = [long]0
        foreach ($a in $Script:SizeFixtures) { $totalSize += [long]$a.SizeBytes }
        $policy = New-RetentionPolicy -MaxTotalSizeBytes ($totalSize + [long]1)

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:SizeFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:SizeRef

        $result | Should -HaveCount 0
    }
}

# ─────────────────────────────────────────────
# RED PHASE 5: KeepLatestN retention logic
# ─────────────────────────────────────────────
Describe 'Get-ArtifactsToDelete - KeepLatestN policy' {
    BeforeAll {
        [datetime]$Script:NRef = [datetime]'2026-04-06'

        # wf1: 3 artifacts, wf2: 2 artifacts
        $Script:NFixtures = @(
            (New-ArtifactRecord -Name 'wf1-old' -SizeBytes ([long]104857600)  -CreatedAt $Script:NRef.AddDays(-60) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-mid' -SizeBytes ([long]104857600)  -CreatedAt $Script:NRef.AddDays(-20) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-new' -SizeBytes ([long]104857600)  -CreatedAt $Script:NRef.AddDays(-5)  -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf2-old' -SizeBytes ([long]209715200)  -CreatedAt $Script:NRef.AddDays(-45) -WorkflowRunId 'wf2')
            (New-ArtifactRecord -Name 'wf2-new' -SizeBytes ([long]209715200)  -CreatedAt $Script:NRef.AddDays(-10) -WorkflowRunId 'wf2')
        )
    }

    It 'deletes all but the N newest artifacts per workflow (N=1)' {
        # wf1 keeps wf1-new, deletes wf1-old + wf1-mid
        # wf2 keeps wf2-new, deletes wf2-old
        $policy = New-RetentionPolicy -KeepLatestN 1

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:NFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:NRef

        $result      | Should -HaveCount 3
        $result.Name | Should -Contain 'wf1-old'
        $result.Name | Should -Contain 'wf1-mid'
        $result.Name | Should -Contain 'wf2-old'
        $result.Name | Should -Not -Contain 'wf1-new'
        $result.Name | Should -Not -Contain 'wf2-new'
    }

    It 'deletes older artifacts when N=2' {
        # wf1 keeps wf1-new + wf1-mid, deletes wf1-old
        # wf2 keeps both (count ≤ N), deletes nothing
        $policy = New-RetentionPolicy -KeepLatestN 2

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:NFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:NRef

        $result      | Should -HaveCount 1
        $result.Name | Should -Contain 'wf1-old'
    }

    It 'returns empty array when N is >= artifact count for all workflows' {
        $policy = New-RetentionPolicy -KeepLatestN 10

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:NFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:NRef

        $result | Should -HaveCount 0
    }
}

# ─────────────────────────────────────────────
# RED PHASE 6: Combined / edge-case policies
# ─────────────────────────────────────────────
Describe 'Get-ArtifactsToDelete - Combined policies and edge cases' {
    BeforeAll {
        [datetime]$Script:CRef = [datetime]'2026-04-06'

        $Script:CFixtures = @(
            (New-ArtifactRecord -Name 'wf1-old' -SizeBytes ([long]104857600)  -CreatedAt $Script:CRef.AddDays(-60) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-mid' -SizeBytes ([long]104857600)  -CreatedAt $Script:CRef.AddDays(-20) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf1-new' -SizeBytes ([long]104857600)  -CreatedAt $Script:CRef.AddDays(-5)  -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'wf2-old' -SizeBytes ([long]209715200)  -CreatedAt $Script:CRef.AddDays(-45) -WorkflowRunId 'wf2')
            (New-ArtifactRecord -Name 'wf2-new' -SizeBytes ([long]209715200)  -CreatedAt $Script:CRef.AddDays(-10) -WorkflowRunId 'wf2')
        )
    }

    It 'unions results from MaxAgeDays and KeepLatestN (no duplicates)' {
        # MaxAgeDays=30 marks: wf1-old, wf2-old
        # KeepLatestN=1  marks: wf1-old, wf1-mid, wf2-old
        # Union (deduped): wf1-old, wf1-mid, wf2-old → 3 artifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:CFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:CRef

        $result      | Should -HaveCount 3
        $result.Name | Should -Contain 'wf1-old'
        $result.Name | Should -Contain 'wf1-mid'
        $result.Name | Should -Contain 'wf2-old'
    }

    It 'returns empty array for an empty artifact list' {
        $policy = New-RetentionPolicy -MaxAgeDays 30

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     ([PSCustomObject[]]@()) `
            -Policy        $policy `
            -ReferenceDate $Script:CRef

        $result | Should -HaveCount 0
    }

    It 'returns empty array when policy has no constraints' {
        $policy = New-RetentionPolicy   # all-null policy

        [PSCustomObject[]]$result = Get-ArtifactsToDelete `
            -Artifacts     $Script:CFixtures `
            -Policy        $policy `
            -ReferenceDate $Script:CRef

        $result | Should -HaveCount 0
    }
}

# ─────────────────────────────────────────────
# RED PHASE 7: Deletion plan generation
# ─────────────────────────────────────────────
Describe 'New-DeletionPlan' {
    BeforeAll {
        [datetime]$Script:PlanRef = [datetime]'2026-04-06'

        $Script:AllPlanArtifacts = @(
            (New-ArtifactRecord -Name 'keep-1'   -SizeBytes ([long]52428800)   -CreatedAt $Script:PlanRef.AddDays(-5)  -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'keep-2'   -SizeBytes ([long]78643200)   -CreatedAt $Script:PlanRef.AddDays(-10) -WorkflowRunId 'wf2')
            (New-ArtifactRecord -Name 'delete-1' -SizeBytes ([long]104857600)  -CreatedAt $Script:PlanRef.AddDays(-40) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'delete-2' -SizeBytes ([long]209715200)  -CreatedAt $Script:PlanRef.AddDays(-50) -WorkflowRunId 'wf2')
        )
        # delete-1 (100 MB) + delete-2 (200 MB) = 300 MB
        $Script:ToDeletePlan = @($Script:AllPlanArtifacts[2], $Script:AllPlanArtifacts[3])
    }

    It 'reports the correct count of artifacts to delete' {
        $plan = New-DeletionPlan -AllArtifacts $Script:AllPlanArtifacts -ArtifactsToDelete $Script:ToDeletePlan

        $plan.ArtifactsToDelete | Should -HaveCount 2
    }

    It 'reports the correct count of artifacts to retain' {
        $plan = New-DeletionPlan -AllArtifacts $Script:AllPlanArtifacts -ArtifactsToDelete $Script:ToDeletePlan

        $plan.ArtifactsToRetain | Should -HaveCount 2
    }

    It 'identifies which artifacts are retained' {
        $plan = New-DeletionPlan -AllArtifacts $Script:AllPlanArtifacts -ArtifactsToDelete $Script:ToDeletePlan

        $plan.ArtifactsToRetain.Name | Should -Contain 'keep-1'
        $plan.ArtifactsToRetain.Name | Should -Contain 'keep-2'
    }

    It 'calculates total space reclaimed correctly (300 MB)' {
        $plan = New-DeletionPlan -AllArtifacts $Script:AllPlanArtifacts -ArtifactsToDelete $Script:ToDeletePlan

        # 100 MB + 200 MB = 300 MB = 314 572 800 bytes
        $plan.TotalSpaceReclaimedBytes | Should -Be ([long]314572800)
    }

    It 'includes a human-readable summary mentioning delete and retain' {
        $plan = New-DeletionPlan -AllArtifacts $Script:AllPlanArtifacts -ArtifactsToDelete $Script:ToDeletePlan

        $plan.Summary | Should -Not -BeNullOrEmpty
        $plan.Summary | Should -Match 'delete'
        $plan.Summary | Should -Match 'retain'
    }

    It 'handles empty deletion list (nothing to delete)' {
        $plan = New-DeletionPlan -AllArtifacts $Script:AllPlanArtifacts -ArtifactsToDelete ([PSCustomObject[]]@())

        $plan.ArtifactsToDelete        | Should -HaveCount 0
        $plan.ArtifactsToRetain        | Should -HaveCount 4
        $plan.TotalSpaceReclaimedBytes | Should -Be ([long]0)
    }
}

# ─────────────────────────────────────────────
# RED PHASE 8: Main entry-point / dry-run mode
# ─────────────────────────────────────────────
Describe 'Invoke-ArtifactCleanup' {
    BeforeAll {
        [datetime]$Script:IRef = [datetime]'2026-04-06'

        $Script:IArtifacts = @(
            (New-ArtifactRecord -Name 'recent-wf1' -SizeBytes ([long]52428800)  -CreatedAt $Script:IRef.AddDays(-5)  -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'old-wf1'    -SizeBytes ([long]104857600) -CreatedAt $Script:IRef.AddDays(-40) -WorkflowRunId 'wf1')
            (New-ArtifactRecord -Name 'recent-wf2' -SizeBytes ([long]78643200)  -CreatedAt $Script:IRef.AddDays(-10) -WorkflowRunId 'wf2')
        )
        $Script:IPolicy = New-RetentionPolicy -MaxAgeDays 30
    }

    Context 'Dry-run mode (-DryRun switch)' {
        It 'returns a plan object with DryRun = $true' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $result.DryRun | Should -Be $true
        }

        It 'identifies the correct artifact to delete in dry-run mode' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $result.ArtifactsToDelete        | Should -HaveCount 1
            $result.ArtifactsToDelete[0].Name | Should -Be 'old-wf1'
        }

        It 'does not populate ArtifactsDeleted in dry-run mode' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $result.ArtifactsDeleted | Should -HaveCount 0
        }

        It 'does not alter the original artifact array in dry-run mode' {
            [int]$before = $Script:IArtifacts.Count

            Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $Script:IArtifacts.Count | Should -Be $before
        }

        It 'summary indicates dry-run mode' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $result.Summary | Should -Match 'DRY RUN'
        }
    }

    Context 'Live-run mode (no -DryRun)' {
        It 'returns a plan object with DryRun = $false' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -ReferenceDate $Script:IRef

            $result.DryRun | Should -Be $false
        }

        It 'populates ArtifactsDeleted with the removed artifact' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -ReferenceDate $Script:IRef

            $result.ArtifactsDeleted        | Should -HaveCount 1
            $result.ArtifactsDeleted[0].Name | Should -Be 'old-wf1'
        }

        It 'reports correct space reclaimed in live mode' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $Script:IPolicy `
                -ReferenceDate $Script:IRef

            # old-wf1 = 100 MB = 104 857 600 bytes
            $result.TotalSpaceReclaimedBytes | Should -Be ([long]104857600)
        }
    }

    Context 'Edge cases' {
        It 'handles an empty artifact list gracefully' {
            $result = Invoke-ArtifactCleanup `
                -Artifacts     ([PSCustomObject[]]@()) `
                -Policy        $Script:IPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $result.ArtifactsToDelete        | Should -HaveCount 0
            $result.ArtifactsDeleted         | Should -HaveCount 0
            $result.TotalSpaceReclaimedBytes | Should -Be ([long]0)
        }

        It 'handles a no-constraint policy (nothing deleted)' {
            $emptyPolicy = New-RetentionPolicy

            $result = Invoke-ArtifactCleanup `
                -Artifacts     $Script:IArtifacts `
                -Policy        $emptyPolicy `
                -DryRun `
                -ReferenceDate $Script:IRef

            $result.ArtifactsToDelete        | Should -HaveCount 0
            $result.ArtifactsToRetain        | Should -HaveCount 3
            $result.TotalSpaceReclaimedBytes | Should -Be ([long]0)
        }
    }
}
