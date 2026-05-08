BeforeAll {
    Import-Module "$PSScriptRoot/ArtifactCleanup.psm1" -Force
}

Describe "ConvertTo-ArtifactList" {
    It "parses JSON array into artifact objects" {
        $json = '[{"Name":"art1","SizeBytes":1024,"CreatedDate":"2026-05-01T00:00:00Z","WorkflowRunId":"wf1"}]'
        $result = @(ConvertTo-ArtifactList -Json $json)
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be "art1"
        $result[0].SizeBytes | Should -Be 1024
        $result[0].WorkflowRunId | Should -Be "wf1"
    }

    It "parses multiple artifacts" {
        $json = '[{"Name":"a","SizeBytes":100,"CreatedDate":"2026-05-01T00:00:00Z","WorkflowRunId":"w1"},{"Name":"b","SizeBytes":200,"CreatedDate":"2026-05-02T00:00:00Z","WorkflowRunId":"w2"}]'
        $result = @(ConvertTo-ArtifactList -Json $json)
        $result.Count | Should -Be 2
        $result[0].Name | Should -Be "a"
        $result[1].Name | Should -Be "b"
    }

    It "handles empty JSON array" {
        $result = @(ConvertTo-ArtifactList -Json '[]')
        $result.Count | Should -Be 0
    }

    It "throws on invalid JSON" {
        { ConvertTo-ArtifactList -Json 'not-json' } | Should -Throw "*Failed to parse*"
    }

    It "throws on missing required field" {
        { ConvertTo-ArtifactList -Json '[{"Name":"x","SizeBytes":1}]' } | Should -Throw "*missing required field*"
    }
}

Describe "New-RetentionPolicy" {
    It "creates policy with specified values" {
        $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 1048576 -KeepLatestNPerWorkflow 2
        $policy.MaxAgeDays | Should -Be 30
        $policy.MaxTotalSizeBytes | Should -Be 1048576
        $policy.KeepLatestNPerWorkflow | Should -Be 2
    }

    It "defaults to zero for unspecified values" {
        $policy = New-RetentionPolicy
        $policy.MaxAgeDays | Should -Be 0
        $policy.MaxTotalSizeBytes | Should -Be 0
        $policy.KeepLatestNPerWorkflow | Should -Be 0
    }

    It "rejects negative MaxAgeDays" {
        { New-RetentionPolicy -MaxAgeDays -1 } | Should -Throw
    }
}

Describe "Get-DeletionPlan" {
    Context "max age policy" {
        It "deletes artifacts older than max age" {
            $json = @'
[
    {"Name":"old-art","SizeBytes":1024,"CreatedDate":"2026-04-01T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"new-art","SizeBytes":1024,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"}
]
'@
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxAgeDays 30
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 1
            $plan.RetainedCount | Should -Be 1
            $plan.DeletedArtifacts[0].Name | Should -Be "old-art"
            $plan.DeletedArtifacts[0].Reason | Should -Match "exceeded max age of 30 days \(36 days old\)"
            $plan.RetainedArtifacts[0].Name | Should -Be "new-art"
        }

        It "retains artifacts within max age" {
            $json = '[{"Name":"recent","SizeBytes":512,"CreatedDate":"2026-05-05T00:00:00Z","WorkflowRunId":"wf1"}]'
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxAgeDays 30
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 0
            $plan.RetainedCount | Should -Be 1
        }
    }

    Context "keep-latest-N per workflow" {
        It "keeps only N most recent per workflow" {
            $json = @'
[
    {"Name":"art-3","SizeBytes":1024,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"art-2","SizeBytes":1024,"CreatedDate":"2026-05-05T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"art-1","SizeBytes":1024,"CreatedDate":"2026-05-04T00:00:00Z","WorkflowRunId":"wf1"}
]
'@
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -KeepLatestNPerWorkflow 2
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 1
            $plan.RetainedCount | Should -Be 2
            $plan.DeletedArtifacts[0].Name | Should -Be "art-1"
            $plan.DeletedArtifacts[0].Reason | Should -Match "exceeded keep-latest-2 per workflow 'wf1'"
        }

        It "does not delete when artifact count equals N" {
            $json = @'
[
    {"Name":"art-2","SizeBytes":1024,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"art-1","SizeBytes":1024,"CreatedDate":"2026-05-05T00:00:00Z","WorkflowRunId":"wf1"}
]
'@
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -KeepLatestNPerWorkflow 2
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 0
            $plan.RetainedCount | Should -Be 2
        }
    }

    Context "max total size" {
        It "removes oldest artifacts until under size limit" {
            $json = @'
[
    {"Name":"big-new","SizeBytes":5242880,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"big-old","SizeBytes":5242880,"CreatedDate":"2026-05-04T00:00:00Z","WorkflowRunId":"wf2"}
]
'@
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxTotalSizeBytes 5242880
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 1
            $plan.RetainedCount | Should -Be 1
            $plan.DeletedArtifacts[0].Name | Should -Be "big-old"
            $plan.SpaceReclaimed | Should -Be 5242880
            $plan.SpaceRetained | Should -Be 5242880
        }

        It "retains all when under size limit" {
            $json = @'
[
    {"Name":"small1","SizeBytes":100,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"small2","SizeBytes":100,"CreatedDate":"2026-05-05T00:00:00Z","WorkflowRunId":"wf2"}
]
'@
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxTotalSizeBytes 1000
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 0
            $plan.RetainedCount | Should -Be 2
        }
    }

    Context "combined policies" {
        It "applies all three policies in correct order with standard fixture" {
            $json = Get-Content "$PSScriptRoot/fixtures/standard-artifacts.json" -Raw
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 31457280 -KeepLatestNPerWorkflow 2
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.TotalArtifacts | Should -Be 10
            $plan.DeletedCount | Should -Be 4
            $plan.RetainedCount | Should -Be 6
            $plan.SpaceReclaimed | Should -Be 18874368
            $plan.SpaceRetained | Should -Be 26214400
            $plan.Mode | Should -Be "DRY-RUN"

            # Verify specific deletions and reasons
            $deleted = $plan.DeletedArtifacts
            ($deleted | Where-Object Name -eq 'build-linux-121').Reason | Should -Match "exceeded max age"
            ($deleted | Where-Object Name -eq 'deploy-logs-10').Reason | Should -Match "exceeded max age"
            ($deleted | Where-Object Name -eq 'test-results-198').Reason | Should -Match "exceeded keep-latest-2"
            ($deleted | Where-Object Name -eq 'build-windows-49').Reason | Should -Match "exceeded max total size"
        }
    }

    Context "edge cases" {
        It "handles empty artifact list" {
            $artifacts = @(ConvertTo-ArtifactList -Json '[]')
            $policy = New-RetentionPolicy -MaxAgeDays 30
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.TotalArtifacts | Should -Be 0
            $plan.DeletedCount | Should -Be 0
            $plan.RetainedCount | Should -Be 0
            $plan.SpaceReclaimed | Should -Be 0
            $plan.SpaceRetained | Should -Be 0
        }

        It "retains all when no policy violations" {
            $json = '[{"Name":"art1","SizeBytes":1024,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"}]'
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeBytes 1048576 -KeepLatestNPerWorkflow 5
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 0
            $plan.RetainedCount | Should -Be 1
        }

        It "sets mode to LIVE when DryRun is not specified" {
            $json = '[{"Name":"art1","SizeBytes":1024,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"}]'
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07")

            $plan.Mode | Should -Be "LIVE"
        }

        It "skips disabled policies (value of 0)" {
            $json = @'
[
    {"Name":"very-old","SizeBytes":1024,"CreatedDate":"2020-01-01T00:00:00Z","WorkflowRunId":"wf1"},
    {"Name":"recent","SizeBytes":1024,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"}
]
'@
            $artifacts = @(ConvertTo-ArtifactList -Json $json)
            $policy = New-RetentionPolicy -MaxAgeDays 0
            $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun

            $plan.DeletedCount | Should -Be 0
            $plan.RetainedCount | Should -Be 2
        }
    }
}

Describe "Format-CleanupSummary" {
    It "formats plan with deletions into readable output" {
        $json = '[{"Name":"old","SizeBytes":2097152,"CreatedDate":"2026-04-01T00:00:00Z","WorkflowRunId":"wf1"},{"Name":"new","SizeBytes":1048576,"CreatedDate":"2026-05-06T00:00:00Z","WorkflowRunId":"wf1"}]'
        $artifacts = @(ConvertTo-ArtifactList -Json $json)
        $policy = New-RetentionPolicy -MaxAgeDays 30
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun
        $output = Format-CleanupSummary -Plan $plan

        $output | Should -Match "=== ARTIFACT CLEANUP PLAN ==="
        $output | Should -Match "Mode: DRY-RUN"
        $output | Should -Match "Reference Date: 2026-05-07"
        $output | Should -Match "Artifacts to delete: 1"
        $output | Should -Match "Artifacts to retain: 1"
        $output | Should -Match "Space to reclaim: 2097152 bytes"
        $output | Should -Match "Space retained: 1048576 bytes"
    }

    It "formats empty plan with (none) markers" {
        $artifacts = @(ConvertTo-ArtifactList -Json '[]')
        $policy = New-RetentionPolicy -MaxAgeDays 30
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate ([datetime]"2026-05-07") -DryRun
        $output = Format-CleanupSummary -Plan $plan

        $output | Should -Match "\(none\)"
        $output | Should -Match "Total artifacts: 0"
        $output | Should -Match "Space to reclaim: 0 bytes"
    }
}
