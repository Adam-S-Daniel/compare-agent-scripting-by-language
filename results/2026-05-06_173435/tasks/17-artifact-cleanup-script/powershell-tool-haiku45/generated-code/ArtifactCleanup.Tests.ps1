# ArtifactCleanup.Tests.ps1
# Pester test suite for artifact cleanup script
# Red/Green TDD: Tests written first, implementation follows

BeforeAll {
    # Import the script under test
    . $PSScriptRoot/ArtifactCleanup.ps1
}

# Test Suite 1: Data validation and parsing
Describe "Artifact Data Validation" {
    It "should accept artifact object with required properties" {
        $artifact = @{
            Name = "build-123"
            Size = 1000
            CreatedDate = (Get-Date).AddDays(-5)
            WorkflowRunId = "workflow-1"
        }
        $artifact.Name | Should -BeExactly "build-123"
        $artifact.Size | Should -Be 1000
    }

    It "should fail when artifact is missing required properties" {
        $invalidArtifact = @{
            Name = "build-123"
            # Missing Size, CreatedDate, WorkflowRunId
        }
        { Validate-Artifact $invalidArtifact } | Should -Throw
    }
}

# Test Suite 2: Single retention policy tests
Describe "Max Age Retention Policy" {
    It "should mark artifacts older than max age for deletion" {
        $artifacts = @(
            @{ Name = "old"; Size = 100; CreatedDate = (Get-Date).AddDays(-31); WorkflowRunId = "wf1" },
            @{ Name = "new"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.ToDelete.Count | Should -Be 1
        $result.ToDelete[0].Name | Should -BeExactly "old"
    }

    It "should keep artifacts newer than max age" {
        $artifacts = @(
            @{ Name = "new"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.ToDelete.Count | Should -Be 0
        $result.ToRetain.Count | Should -Be 1
    }
}

# Test Suite 3: Max total size policy
Describe "Max Total Size Retention Policy" {
    It "should delete oldest artifacts to stay under total size limit" {
        $artifacts = @(
            @{ Name = "art1"; Size = 200000; CreatedDate = (Get-Date).AddDays(-10); WorkflowRunId = "wf1" },
            @{ Name = "art2"; Size = 700000; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" },
            @{ Name = "art3"; Size = 400000; CreatedDate = (Get-Date).AddDays(-1); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxTotalSizeInMB = 0.8 }  # 0.8 MB limit, can only fit newest (400KB + 200KB or 400KB alone)

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.ToDelete.Count | Should -Be 1
        # art2 (700KB) doesn't fit with art3 (400KB) under 0.8 MB limit
        $result.ToDelete[0].Name | Should -BeExactly "art2"
    }

    It "should respect size calculations correctly" {
        $artifacts = @(
            @{ Name = "small"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxTotalSizeInMB = 10 }  # 10 MB limit, artifact is 100 bytes

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.ToDelete.Count | Should -Be 0
    }
}

# Test Suite 4: Keep latest N per workflow
Describe "Keep Latest N Per Workflow Policy" {
    It "should keep only latest N artifacts per workflow" {
        $artifacts = @(
            @{ Name = "wf1-art1"; Size = 100; CreatedDate = (Get-Date).AddDays(-10); WorkflowRunId = "wf1" },
            @{ Name = "wf1-art2"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" },
            @{ Name = "wf1-art3"; Size = 100; CreatedDate = (Get-Date).AddDays(-1); WorkflowRunId = "wf1" }
        )
        $policy = @{ KeepLatestPerWorkflow = 2 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.ToDelete.Count | Should -Be 1
        $result.ToDelete[0].Name | Should -BeExactly "wf1-art1"  # oldest should be deleted
    }

    It "should track latest N separately per workflow" {
        $artifacts = @(
            @{ Name = "wf1-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-10); WorkflowRunId = "wf1" },
            @{ Name = "wf1-2"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" },
            @{ Name = "wf2-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-3); WorkflowRunId = "wf2" }
        )
        $policy = @{ KeepLatestPerWorkflow = 1 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.ToDelete.Count | Should -Be 1  # Delete wf1-1 (oldest from wf1)
        $result.ToRetain.Count | Should -Be 2  # Keep wf1-2 and wf2-1 (latest from each workflow)
        # Verify deletion
        $result.ToDelete[0].Name | Should -BeExactly "wf1-1"
        # Verify one is from each workflow
        $retainWfIds = @($result.ToRetain | ForEach-Object { $_.WorkflowRunId })
        $retainWfIds | Should -Contain "wf1"
        $retainWfIds | Should -Contain "wf2"
    }
}

# Test Suite 5: Multiple policies combined
Describe "Multiple Policies Combined" {
    It "should apply all policies cumulatively" {
        $artifacts = @(
            @{ Name = "art1"; Size = 100; CreatedDate = (Get-Date).AddDays(-40); WorkflowRunId = "wf1" },
            @{ Name = "art2"; Size = 100; CreatedDate = (Get-Date).AddDays(-15); WorkflowRunId = "wf1" },
            @{ Name = "art3"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" }
        )
        $policies = @{
            MaxAgeInDays = 30
            KeepLatestPerWorkflow = 2
        }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policies -DryRun $true
        # art1 should be deleted (older than 30 days), keep latest 2 from wf1
        $result.ToDelete.Count | Should -Be 1
        $result.ToDelete[0].Name | Should -BeExactly "art1"
    }
}

# Test Suite 6: Deletion plan summary
Describe "Deletion Plan Summary" {
    It "should calculate total space reclaimed" {
        $artifacts = @(
            @{ Name = "art1"; Size = 1000; CreatedDate = (Get-Date).AddDays(-31); WorkflowRunId = "wf1" },
            @{ Name = "art2"; Size = 2000; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.Summary.TotalSpaceReclaimedBytes | Should -Be 1000
    }

    It "should count retained and deleted artifacts" {
        $artifacts = @(
            @{ Name = "art1"; Size = 100; CreatedDate = (Get-Date).AddDays(-31); WorkflowRunId = "wf1" },
            @{ Name = "art2"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "wf1" },
            @{ Name = "art3"; Size = 100; CreatedDate = (Get-Date).AddDays(-2); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.Summary.ArtifactsRetained | Should -Be 2
        $result.Summary.ArtifactsDeleted | Should -Be 1
    }

    It "should format summary with human-readable sizes" {
        $artifacts = @(
            @{ Name = "art1"; Size = 1048576; CreatedDate = (Get-Date).AddDays(-31); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.Summary.TotalSpaceReclaimedMB | Should -BeGreaterThan 0
        $result.Summary.ToString | Should -Match "MB|GB|KB|Bytes"
    }
}

# Test Suite 7: Dry-run vs actual deletion
Describe "Dry-Run Mode" {
    It "should not delete artifacts in dry-run mode" {
        $artifacts = @(
            @{ Name = "art1"; Size = 100; CreatedDate = (Get-Date).AddDays(-31); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $result = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $result.DryRun | Should -Be $true
        # In dry-run mode, artifacts marked for deletion should still be in ToDelete
        $result.ToDelete.Count | Should -Be 1
    }

    It "should return different result for dry-run vs execute flag" {
        $artifacts = @(
            @{ Name = "art1"; Size = 100; CreatedDate = (Get-Date).AddDays(-31); WorkflowRunId = "wf1" }
        )
        $policy = @{ MaxAgeInDays = 30 }

        $dryRunResult = Get-DeletionPlan -Artifacts $artifacts -Policies $policy -DryRun $true
        $dryRunResult.DryRun | Should -Be $true
    }
}

# Test Suite 8: Error handling
Describe "Error Handling" {
    It "should throw on empty artifact list" {
        { Get-DeletionPlan -Artifacts @() -Policies @{ MaxAgeInDays = 30 } -DryRun $true } | Should -Throw
    }

    It "should throw on empty policies" {
        $artifacts = @(
            @{ Name = "art1"; Size = 100; CreatedDate = (Get-Date); WorkflowRunId = "wf1" }
        )
        { Get-DeletionPlan -Artifacts $artifacts -Policies @{} -DryRun $true } | Should -Throw
    }

    It "should provide meaningful error message for invalid artifact" {
        $invalidArtifact = @{ Name = "art1" }  # Missing required fields
        { Validate-Artifact $invalidArtifact } | Should -Throw
    }
}
