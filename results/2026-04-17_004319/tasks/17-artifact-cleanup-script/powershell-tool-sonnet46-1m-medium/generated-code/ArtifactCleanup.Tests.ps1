# ArtifactCleanup.Tests.ps1
# TDD tests for artifact cleanup script using Pester
# Written BEFORE the implementation — these tests drive the design.

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    # Helper: build a test artifact object
    function New-TestArtifact {
        param(
            [string]$Name,
            [double]$SizeMB,
            [DateTime]$CreatedAt,
            [string]$WorkflowRunId
        )
        [PSCustomObject]@{
            Name          = $Name
            SizeMB        = $SizeMB
            CreatedAt     = $CreatedAt
            WorkflowRunId = $WorkflowRunId
        }
    }
}

Describe "Get-ArtifactsToDelete - MaxAgeDays policy" {
    It "marks artifacts older than MaxAgeDays for deletion" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "old"    -SizeMB 10 -CreatedAt $now.AddDays(-40) -WorkflowRunId "run-1"
            New-TestArtifact -Name "recent" -SizeMB 10 -CreatedAt $now.AddDays(-5)  -WorkflowRunId "run-2"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy

        $result.ToDelete.Name | Should -Contain "old"
        $result.ToDelete.Name | Should -Not -Contain "recent"
    }

    It "retains all artifacts when none exceed MaxAgeDays" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "a" -SizeMB 10 -CreatedAt $now.AddDays(-5)  -WorkflowRunId "run-1"
            New-TestArtifact -Name "b" -SizeMB 10 -CreatedAt $now.AddDays(-10) -WorkflowRunId "run-2"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy

        $result.ToDelete | Should -HaveCount 0
        $result.ToKeep   | Should -HaveCount 2
    }
}

Describe "Get-ArtifactsToDelete - KeepLatestN policy" {
    It "keeps only the N most recent artifacts per workflow" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "w1-r1" -SizeMB 5 -CreatedAt $now.AddDays(-1) -WorkflowRunId "wf-A"
            New-TestArtifact -Name "w1-r2" -SizeMB 5 -CreatedAt $now.AddDays(-2) -WorkflowRunId "wf-A"
            New-TestArtifact -Name "w1-r3" -SizeMB 5 -CreatedAt $now.AddDays(-3) -WorkflowRunId "wf-A"
            New-TestArtifact -Name "w1-r4" -SizeMB 5 -CreatedAt $now.AddDays(-4) -WorkflowRunId "wf-A"
        )
        $policy = @{ MaxAgeDays = 9999; MaxTotalSizeMB = 9999; KeepLatestN = 2 }

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy

        # Oldest two should be deleted
        $result.ToDelete.Name | Should -Contain "w1-r3"
        $result.ToDelete.Name | Should -Contain "w1-r4"
        $result.ToKeep.Name   | Should -Contain "w1-r1"
        $result.ToKeep.Name   | Should -Contain "w1-r2"
    }

    It "applies KeepLatestN independently per workflow run ID" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "wfA-1" -SizeMB 5 -CreatedAt $now.AddDays(-1) -WorkflowRunId "wf-A"
            New-TestArtifact -Name "wfA-2" -SizeMB 5 -CreatedAt $now.AddDays(-2) -WorkflowRunId "wf-A"
            New-TestArtifact -Name "wfA-3" -SizeMB 5 -CreatedAt $now.AddDays(-3) -WorkflowRunId "wf-A"
            New-TestArtifact -Name "wfB-1" -SizeMB 5 -CreatedAt $now.AddDays(-1) -WorkflowRunId "wf-B"
            New-TestArtifact -Name "wfB-2" -SizeMB 5 -CreatedAt $now.AddDays(-2) -WorkflowRunId "wf-B"
        )
        $policy = @{ MaxAgeDays = 9999; MaxTotalSizeMB = 9999; KeepLatestN = 1 }

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy

        # Only newest per workflow kept
        $result.ToKeep.Name | Should -Contain "wfA-1"
        $result.ToKeep.Name | Should -Contain "wfB-1"
        $result.ToDelete | Should -HaveCount 3
    }
}

Describe "Get-ArtifactsToDelete - MaxTotalSizeMB policy" {
    It "removes oldest artifacts when total size exceeds limit" {
        $now = [DateTime]::UtcNow
        # Total = 400 MB, limit = 250 MB → must delete oldest to get under limit
        $artifacts = @(
            New-TestArtifact -Name "newest" -SizeMB 100 -CreatedAt $now.AddDays(-1) -WorkflowRunId "run-1"
            New-TestArtifact -Name "middle" -SizeMB 150 -CreatedAt $now.AddDays(-5) -WorkflowRunId "run-2"
            New-TestArtifact -Name "oldest" -SizeMB 150 -CreatedAt $now.AddDays(-10) -WorkflowRunId "run-3"
        )
        $policy = @{ MaxAgeDays = 9999; MaxTotalSizeMB = 250; KeepLatestN = 99 }

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy

        $result.ToDelete.Name | Should -Contain "oldest"
        $result.ToKeep.Name   | Should -Contain "newest"
    }
}

Describe "Get-ArtifactsToDelete - combined policies" {
    It "applies all three policies and unions the delete set" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            # Too old
            New-TestArtifact -Name "stale"  -SizeMB 10 -CreatedAt $now.AddDays(-60) -WorkflowRunId "wf-A"
            # Exceeds KeepLatestN=1 for wf-B
            New-TestArtifact -Name "wfB-old" -SizeMB 10 -CreatedAt $now.AddDays(-3) -WorkflowRunId "wf-B"
            New-TestArtifact -Name "wfB-new" -SizeMB 10 -CreatedAt $now.AddDays(-1) -WorkflowRunId "wf-B"
            # Fine
            New-TestArtifact -Name "fresh"  -SizeMB 10 -CreatedAt $now.AddDays(-1)  -WorkflowRunId "wf-A"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 1 }

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy

        $result.ToDelete.Name | Should -Contain "stale"
        $result.ToDelete.Name | Should -Contain "wfB-old"
        $result.ToKeep.Name   | Should -Contain "fresh"
        $result.ToKeep.Name   | Should -Contain "wfB-new"
    }
}

Describe "New-DeletionPlan - summary generation" {
    It "calculates total space reclaimed correctly" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "a" -SizeMB 100 -CreatedAt $now.AddDays(-40) -WorkflowRunId "run-1"
            New-TestArtifact -Name "b" -SizeMB 200 -CreatedAt $now.AddDays(-2)  -WorkflowRunId "run-2"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.Summary.SpaceReclaimedMB | Should -Be 100
        $plan.Summary.ArtifactsDeleted | Should -Be 1
        $plan.Summary.ArtifactsRetained | Should -Be 1
    }

    It "reports zero deletions when all artifacts are within policy" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "a" -SizeMB 50 -CreatedAt $now.AddDays(-5) -WorkflowRunId "run-1"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.Summary.SpaceReclaimedMB | Should -Be 0
        $plan.Summary.ArtifactsDeleted  | Should -Be 0
        $plan.Summary.ArtifactsRetained | Should -Be 1
    }

    It "includes the list of artifacts to delete in the plan" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "old" -SizeMB 75 -CreatedAt $now.AddDays(-35) -WorkflowRunId "run-1"
            New-TestArtifact -Name "new" -SizeMB 25 -CreatedAt $now.AddDays(-2)  -WorkflowRunId "run-2"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $plan = New-DeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete | Should -HaveCount 1
        $plan.ToDelete[0].Name | Should -Be "old"
    }
}

Describe "Invoke-ArtifactCleanup - dry-run mode" {
    It "returns a plan without performing deletions in dry-run mode" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "old" -SizeMB 50 -CreatedAt $now.AddDays(-60) -WorkflowRunId "run-1"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -DryRun

        $result.DryRun | Should -Be $true
        $result.Plan.ToDelete | Should -HaveCount 1
        # No deletion action taken — DeletedArtifacts should be empty
        $result.DeletedArtifacts | Should -HaveCount 0
    }

    It "executes deletions when not in dry-run mode" {
        $now = [DateTime]::UtcNow
        $artifacts = @(
            New-TestArtifact -Name "old" -SizeMB 50 -CreatedAt $now.AddDays(-60) -WorkflowRunId "run-1"
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }

        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy -DryRun:$false

        $result.DryRun | Should -Be $false
        $result.DeletedArtifacts | Should -HaveCount 1
        $result.DeletedArtifacts[0].Name | Should -Be "old"
    }
}

Describe "Invoke-ArtifactCleanup - error handling" {
    It "throws a meaningful error when Artifacts is null" {
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeMB = 9999; KeepLatestN = 99 }
        { Invoke-ArtifactCleanup -Artifacts $null -Policy $policy } | Should -Throw "*Artifacts*"
    }

    It "throws a meaningful error when Policy is missing required keys" {
        $now = [DateTime]::UtcNow
        $artifacts = @(New-TestArtifact -Name "a" -SizeMB 5 -CreatedAt $now -WorkflowRunId "r1")
        $badPolicy = @{ MaxAgeDays = 30 }   # missing MaxTotalSizeMB and KeepLatestN
        { Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $badPolicy } | Should -Throw "*Policy*"
    }
}
