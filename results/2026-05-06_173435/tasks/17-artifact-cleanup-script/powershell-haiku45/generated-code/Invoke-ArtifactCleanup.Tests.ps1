# Test suite for Invoke-ArtifactCleanup script
# Red/Green TDD approach: failing tests first, then implement

param(
    [string]$ScriptPath = "$PSScriptRoot/Invoke-ArtifactCleanup.ps1"
)

# Test 1: Script exists and is loadable
Describe "Artifact Cleanup Script - Basic Loading" {
    It "Should load the script without errors" {
        { . $ScriptPath } | Should -Not -Throw
    }
}

# Test 2: Function exists with correct signature
Describe "Invoke-ArtifactCleanup - Function Definition" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should export Invoke-ArtifactCleanup function" {
        Get-Command Invoke-ArtifactCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It "Should have correct function parameters" {
        $cmd = Get-Command Invoke-ArtifactCleanup
        $paramNames = $cmd.Parameters.Keys
        $paramNames | Should -Contain "Artifacts"
        $paramNames | Should -Contain "MaxAgeInDays"
        $paramNames | Should -Contain "MaxTotalSizeInMB"
        $paramNames | Should -Contain "KeepLatestPerWorkflow"
        $paramNames | Should -Contain "DryRun"
    }
}

# Test 3: Parse and validate artifact input
Describe "Invoke-ArtifactCleanup - Input Parsing" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should accept artifacts array and return object with plan property" {
        $artifacts = @(
            @{ Name = "build-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run1" }
        )
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 2
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "DeletionPlan"
    }
}

# Test 4: Empty artifacts list should return empty deletion plan
Describe "Invoke-ArtifactCleanup - Empty Input" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should handle empty artifacts array" {
        $result = Invoke-ArtifactCleanup -Artifacts @() -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 2
        $result.DeletionPlan | Should -BeNullOrEmpty
        $result.Summary.ArtifactsToDelete | Should -Be 0
    }
}

# Test 5: Artifacts older than MaxAgeInDays should be marked for deletion
Describe "Invoke-ArtifactCleanup - Max Age Policy" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should mark old artifacts for deletion" {
        $artifacts = @(
            @{ Name = "old-artifact"; Size = 100; CreatedDate = (Get-Date).AddDays(-40); WorkflowRunId = "run1" },
            @{ Name = "new-artifact"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run2" }
        )
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 5
        $result.DeletionPlan | Should -HaveCount 1
        $result.DeletionPlan[0].Name | Should -Be "old-artifact"
    }
}

# Test 6: Dry-run mode should not modify anything but show plan
Describe "Invoke-ArtifactCleanup - Dry-Run Mode" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should indicate dry-run in result" {
        $artifacts = @(
            @{ Name = "artifact1"; Size = 100; CreatedDate = (Get-Date).AddDays(-40); WorkflowRunId = "run1" }
        )
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 5 -DryRun
        $result.DryRun | Should -Be $true
    }
}

# Test 7: Total size limit policy - keep newest artifacts until limit is reached
Describe "Invoke-ArtifactCleanup - Max Total Size Policy" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should delete artifacts when total size exceeds limit" {
        # Create 5 artifacts of 200 MB each = 1000 MB total, but limit to 500 MB
        # Should keep ~2 newest, delete 3 oldest
        $artifacts = @(
            @{ Name = "artifact-1"; Size = 200; CreatedDate = (Get-Date).AddDays(-10); WorkflowRunId = "run1" },
            @{ Name = "artifact-2"; Size = 200; CreatedDate = (Get-Date).AddDays(-8); WorkflowRunId = "run1" },
            @{ Name = "artifact-3"; Size = 200; CreatedDate = (Get-Date).AddDays(-6); WorkflowRunId = "run1" },
            @{ Name = "artifact-4"; Size = 200; CreatedDate = (Get-Date).AddDays(-4); WorkflowRunId = "run1" },
            @{ Name = "artifact-5"; Size = 200; CreatedDate = (Get-Date).AddDays(-2); WorkflowRunId = "run1" }
        )
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 365 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 5
        $result.DeletionPlan | Should -HaveCount 3
        # Newest 2 (artifact-5, artifact-4) should be retained
        $result.DeletionPlan.Name | Should -Not -Contain "artifact-5"
        $result.DeletionPlan.Name | Should -Not -Contain "artifact-4"
    }
}

# Test 8: Keep latest N per workflow policy
Describe "Invoke-ArtifactCleanup - Keep Latest Per Workflow" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should keep only latest N artifacts per workflow" {
        $artifacts = @(
            @{ Name = "run1-artifact-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-10); WorkflowRunId = "run1" },
            @{ Name = "run1-artifact-2"; Size = 100; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run1" },
            @{ Name = "run1-artifact-3"; Size = 100; CreatedDate = (Get-Date).AddDays(-2); WorkflowRunId = "run1" },
            @{ Name = "run2-artifact-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-8); WorkflowRunId = "run2" },
            @{ Name = "run2-artifact-2"; Size = 100; CreatedDate = (Get-Date).AddDays(-1); WorkflowRunId = "run2" }
        )
        # Keep only 2 latest per workflow - should delete 1 from run1, 1 from run2
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 365 -MaxTotalSizeInMB 10000 -KeepLatestPerWorkflow 2
        $result.DeletionPlan | Should -HaveCount 1
        $result.DeletionPlan[0].Name | Should -Be "run1-artifact-1"
    }
}

# Test 9: Summary should contain correct counts and space calculations
Describe "Invoke-ArtifactCleanup - Summary Report" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should calculate correct summary" {
        $artifacts = @(
            @{ Name = "delete-me-1"; Size = 100; CreatedDate = (Get-Date).AddDays(-50); WorkflowRunId = "run1" },
            @{ Name = "delete-me-2"; Size = 150; CreatedDate = (Get-Date).AddDays(-50); WorkflowRunId = "run1" },
            @{ Name = "keep-me"; Size = 200; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run1" }
        )
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 5
        $result.Summary.TotalInputArtifacts | Should -Be 3
        $result.Summary.ArtifactsToDelete | Should -Be 2
        $result.Summary.ArtifactsToRetain | Should -Be 1
        $result.Summary.SpaceReclaimedMB | Should -Be 250
    }
}

# Test 10: Combined policies - all constraints applied together
Describe "Invoke-ArtifactCleanup - Combined Policies" {
    BeforeAll {
        . $ScriptPath
    }

    It "Should apply all policies together" {
        $artifacts = @(
            @{ Name = "old-artifact"; Size = 100; CreatedDate = (Get-Date).AddDays(-40); WorkflowRunId = "run1" },
            @{ Name = "new-artifact-1"; Size = 300; CreatedDate = (Get-Date).AddDays(-5); WorkflowRunId = "run1" },
            @{ Name = "new-artifact-2"; Size = 300; CreatedDate = (Get-Date).AddDays(-3); WorkflowRunId = "run1" },
            @{ Name = "new-artifact-3"; Size = 300; CreatedDate = (Get-Date).AddDays(-1); WorkflowRunId = "run1" }
        )
        # Max age: delete old-artifact (100 MB)
        # Remaining: 3 artifacts × 300 MB = 900 MB
        # Max size (500 MB): must delete oldest artifacts
        #   - Delete new-artifact-1 (oldest of new): 900 - 300 = 600 MB, still over limit
        #   - Delete new-artifact-2 (next oldest): 600 - 300 = 300 MB, now under limit
        # Keep latest 3: all 3 new artifacts pass this check
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeInDays 30 -MaxTotalSizeInMB 500 -KeepLatestPerWorkflow 3
        # Should delete: old-artifact (age) + new-artifact-1 (size) + new-artifact-2 (size)
        $result.DeletionPlan | Should -HaveCount 3
    }
}
