# TDD: Artifact cleanup retention policy tests
# Written BEFORE the implementation — these will fail first (red), then pass (green)

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"
}

Describe "Get-ArtifactsToDelete - MaxAge policy" {
    It "flags artifacts older than MaxAgeDays" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="old-artifact"; SizeMB=10; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="run-1" },
            [PSCustomObject]@{ Name="new-artifact"; SizeMB=5;  CreatedAt=[datetime]"2024-01-08"; WorkflowRunId="run-2" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=7; MaxTotalSizeMB=$null; KeepLatestN=$null }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "old-artifact"
    }

    It "retains artifacts within MaxAgeDays" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="recent"; SizeMB=5; CreatedAt=[datetime]"2024-01-05"; WorkflowRunId="run-1" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=7; MaxTotalSizeMB=$null; KeepLatestN=$null }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 0
    }
}

Describe "Get-ArtifactsToDelete - MaxTotalSizeMB policy" {
    It "removes oldest artifacts when total size exceeds limit" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="oldest"; SizeMB=20; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="run-1" },
            [PSCustomObject]@{ Name="middle"; SizeMB=20; CreatedAt=[datetime]"2024-01-05"; WorkflowRunId="run-2" },
            [PSCustomObject]@{ Name="newest"; SizeMB=20; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="run-3" }
        )
        # 45MB limit: deleting "oldest" (20MB) brings total from 60→40 which fits
        $policy = [PSCustomObject]@{ MaxAgeDays=$null; MaxTotalSizeMB=45; KeepLatestN=$null }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "oldest"
    }

    It "retains all when total size is within limit" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="a"; SizeMB=10; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="run-1" },
            [PSCustomObject]@{ Name="b"; SizeMB=10; CreatedAt=[datetime]"2024-01-05"; WorkflowRunId="run-2" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=$null; MaxTotalSizeMB=50; KeepLatestN=$null }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 0
    }
}

Describe "Get-ArtifactsToDelete - KeepLatestN policy" {
    It "keeps only the N most recent artifacts per workflow" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="run1-art"; SizeMB=5; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="wf-A" },
            [PSCustomObject]@{ Name="run2-art"; SizeMB=5; CreatedAt=[datetime]"2024-01-05"; WorkflowRunId="wf-A" },
            [PSCustomObject]@{ Name="run3-art"; SizeMB=5; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="wf-A" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=$null; MaxTotalSizeMB=$null; KeepLatestN=2 }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "run1-art"
    }

    It "does not delete if artifact count is within KeepLatestN" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="run1"; SizeMB=5; CreatedAt=[datetime]"2024-01-08"; WorkflowRunId="wf-B" },
            [PSCustomObject]@{ Name="run2"; SizeMB=5; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="wf-B" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=$null; MaxTotalSizeMB=$null; KeepLatestN=3 }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 0
    }

    It "handles multiple workflows independently" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="wfA-old"; SizeMB=5; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="wf-A" },
            [PSCustomObject]@{ Name="wfA-new"; SizeMB=5; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="wf-A" },
            [PSCustomObject]@{ Name="wfB-old"; SizeMB=5; CreatedAt=[datetime]"2024-01-02"; WorkflowRunId="wf-B" },
            [PSCustomObject]@{ Name="wfB-new"; SizeMB=5; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="wf-B" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=$null; MaxTotalSizeMB=$null; KeepLatestN=1 }
        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $now
        $result.Count | Should -Be 2
        ($result | Where-Object { $_.Name -eq "wfA-old" }) | Should -Not -BeNullOrEmpty
        ($result | Where-Object { $_.Name -eq "wfB-old" }) | Should -Not -BeNullOrEmpty
    }
}

Describe "New-DeletionPlan" {
    It "produces correct summary counts" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="old"; SizeMB=15; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="run-1" },
            [PSCustomObject]@{ Name="new"; SizeMB=10; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="run-2" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=7; MaxTotalSizeMB=$null; KeepLatestN=$null }
        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now -DryRun $false
        $plan.TotalArtifacts     | Should -Be 2
        $plan.DeletedCount       | Should -Be 1
        $plan.RetainedCount      | Should -Be 1
        $plan.SpaceReclaimedMB   | Should -Be 15
        $plan.IsDryRun           | Should -Be $false
    }

    It "dry-run mode marks plan as dry run and does not indicate real deletion" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="old"; SizeMB=20; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="run-1" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=7; MaxTotalSizeMB=$null; KeepLatestN=$null }
        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now -DryRun $true
        $plan.IsDryRun         | Should -Be $true
        $plan.DeletedCount     | Should -Be 1
        $plan.SpaceReclaimedMB | Should -Be 20
    }

    It "returns zero space reclaimed when nothing is deleted" {
        $now = [datetime]"2024-01-10"
        $artifacts = @(
            [PSCustomObject]@{ Name="recent"; SizeMB=5; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="run-1" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=7; MaxTotalSizeMB=$null; KeepLatestN=$null }
        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now -DryRun $false
        $plan.SpaceReclaimedMB | Should -Be 0
        $plan.DeletedCount     | Should -Be 0
        $plan.RetainedCount    | Should -Be 1
    }
}

Describe "New-DeletionPlan - combined policies" {
    It "applies multiple policies and unions the deletions" {
        $now = [datetime]"2024-01-10"
        # old-big: older than 7 days AND exceeds size budget
        # old-small: older than 7 days but would fit in size budget alone
        # new-extra: within age, but size policy pushes total over limit
        $artifacts = @(
            [PSCustomObject]@{ Name="old-big";   SizeMB=30; CreatedAt=[datetime]"2024-01-01"; WorkflowRunId="wf-X" },
            [PSCustomObject]@{ Name="old-small"; SizeMB=5;  CreatedAt=[datetime]"2024-01-02"; WorkflowRunId="wf-X" },
            [PSCustomObject]@{ Name="new-keep";  SizeMB=10; CreatedAt=[datetime]"2024-01-09"; WorkflowRunId="wf-X" }
        )
        $policy = [PSCustomObject]@{ MaxAgeDays=7; MaxTotalSizeMB=20; KeepLatestN=$null }
        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now -DryRun $false
        # Both old-big and old-small are over 7 days old; new-keep survives both policies
        $plan.DeletedCount   | Should -BeGreaterOrEqual 2
        $plan.RetainedCount  | Should -Be ($plan.TotalArtifacts - $plan.DeletedCount)
    }
}

Describe "Format-DeletionPlanSummary" {
    It "outputs a summary string with expected keywords" {
        $plan = [PSCustomObject]@{
            TotalArtifacts   = 5
            DeletedCount     = 2
            RetainedCount    = 3
            SpaceReclaimedMB = 40
            IsDryRun         = $false
            ToDelete         = @()
            ToRetain         = @()
        }
        $summary = Format-DeletionPlanSummary -Plan $plan
        $summary | Should -Match "Total artifacts"
        $summary | Should -Match "5"
        $summary | Should -Match "Delete"
        $summary | Should -Match "2"
        $summary | Should -Match "Retain"
        $summary | Should -Match "3"
        $summary | Should -Match "40"
    }

    It "includes DRY RUN label when applicable" {
        $plan = [PSCustomObject]@{
            TotalArtifacts   = 3
            DeletedCount     = 1
            RetainedCount    = 2
            SpaceReclaimedMB = 10
            IsDryRun         = $true
            ToDelete         = @()
            ToRetain         = @()
        }
        $summary = Format-DeletionPlanSummary -Plan $plan
        $summary | Should -Match "DRY.RUN"
    }
}
