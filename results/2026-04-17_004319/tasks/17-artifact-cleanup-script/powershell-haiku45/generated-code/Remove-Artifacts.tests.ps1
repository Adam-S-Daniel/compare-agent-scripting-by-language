BeforeAll {
    # Import the module/script being tested
    . $PSScriptRoot/Remove-Artifacts.ps1
}

Describe 'Artifact Cleanup - Basic Functionality' {
    Context 'Creating deletion plan' {
        It 'returns empty deletion list for empty artifact list' {
            $artifacts = @()
            $plan = Get-DeletionPlan -Artifacts $artifacts
            $plan.ToDelete | Should -HaveCount 0
            $plan.ToRetain | Should -HaveCount 0
        }
    }
}

Describe 'Artifact Cleanup - Retention Policies' {
    Context 'Max age policy' {
        It 'marks artifacts older than max age for deletion' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'artifact-1.zip'; Size = 1000; CreatedDate = $now.AddDays(-100); WorkflowRunId = '1' },
                @{ Name = 'artifact-2.zip'; Size = 1000; CreatedDate = $now.AddDays(-5);   WorkflowRunId = '2' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeInDays 30
            $plan.ToDelete | Should -HaveCount 1
            $plan.ToDelete[0].Name | Should -Be 'artifact-1.zip'
        }
    }

    Context 'Max total size policy' {
        It 'deletes oldest artifacts when total size exceeds limit' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'old.zip';    Size = 800; CreatedDate = $now.AddDays(-10); WorkflowRunId = '1' },
                @{ Name = 'recent.zip'; Size = 500; CreatedDate = $now.AddDays(-1);  WorkflowRunId = '2' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxTotalSizeInMB 1
            $plan.ToDelete | Should -HaveCount 1
            $plan.ToDelete[0].Name | Should -Be 'old.zip'
        }
    }

    Context 'Keep latest N per workflow' {
        It 'keeps only the N most recent artifacts per workflow' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'wf1-v1.zip'; Size = 100; CreatedDate = $now.AddDays(-20); WorkflowRunId = '1' },
                @{ Name = 'wf1-v2.zip'; Size = 100; CreatedDate = $now.AddDays(-10); WorkflowRunId = '1' },
                @{ Name = 'wf1-v3.zip'; Size = 100; CreatedDate = $now.AddDays(-1);  WorkflowRunId = '1' },
                @{ Name = 'wf2-v1.zip'; Size = 100; CreatedDate = $now.AddDays(-15); WorkflowRunId = '2' },
                @{ Name = 'wf2-v2.zip'; Size = 100; CreatedDate = $now.AddDays(-5);  WorkflowRunId = '2' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -KeepLatestN 2
            $plan.ToDelete | Should -HaveCount 1
            $plan.ToDelete[0].Name | Should -Be 'wf1-v1.zip'
            $plan.ToRetain | Should -HaveCount 4
        }
    }
}

Describe 'Artifact Cleanup - Deletion Plan Summary' {
    Context 'Plan summary' {
        It 'calculates total space to be reclaimed' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'delete-me-1.zip'; Size = 1000; CreatedDate = $now.AddDays(-100); WorkflowRunId = '1' },
                @{ Name = 'delete-me-2.zip'; Size = 500;  CreatedDate = $now.AddDays(-100); WorkflowRunId = '2' },
                @{ Name = 'keep-me.zip';     Size = 2000; CreatedDate = $now.AddDays(-1);   WorkflowRunId = '3' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeInDays 30
            $plan.SpaceReclaimedMB | Should -Be 1.46484375  # (1000 + 500) bytes = 1.46484375 MB
        }

        It 'includes retention count in summary' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'old.zip';    Size = 100; CreatedDate = $now.AddDays(-100); WorkflowRunId = '1' },
                @{ Name = 'recent.zip'; Size = 100; CreatedDate = $now.AddDays(-1);   WorkflowRunId = '2' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeInDays 30
            $plan.RetainedCount | Should -Be 1
            $plan.DeletedCount | Should -Be 1
        }
    }
}

Describe 'Artifact Cleanup - Dry Run Mode' {
    Context 'Dry run operations' {
        It 'does not delete artifacts in dry-run mode' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'test.zip'; Size = 1000; CreatedDate = $now.AddDays(-100); WorkflowRunId = '1' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeInDays 30
            $result = Invoke-CleanupPlan -Plan $plan -DryRun

            $result.ExecutedCount | Should -Be 0
            $result.DryRunMode | Should -Be $true
        }

        It 'reports what would be deleted in dry-run mode' {
            $now = Get-Date
            $artifacts = @(
                @{ Name = 'test.zip'; Size = 1000; CreatedDate = $now.AddDays(-100); WorkflowRunId = '1' }
            )

            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeInDays 30
            $result = Invoke-CleanupPlan -Plan $plan -DryRun

            $result.WouldDeleteCount | Should -Be 1
        }
    }
}

Describe 'Artifact Cleanup - Error Handling' {
    Context 'Invalid input validation' {
        It 'throws error for null artifacts' {
            { Get-DeletionPlan -Artifacts $null } | Should -Throw
        }

        It 'throws error for negative MaxAgeInDays' {
            $artifacts = @()
            { Get-DeletionPlan -Artifacts $artifacts -MaxAgeInDays -1 } | Should -Throw
        }

        It 'throws error for zero MaxTotalSizeInMB' {
            $artifacts = @()
            { Get-DeletionPlan -Artifacts $artifacts -MaxTotalSizeInMB 0 } | Should -Throw
        }

        It 'throws error for KeepLatestN less than 1' {
            $artifacts = @()
            { Get-DeletionPlan -Artifacts $artifacts -KeepLatestN 0 } | Should -Throw
        }
    }
}
