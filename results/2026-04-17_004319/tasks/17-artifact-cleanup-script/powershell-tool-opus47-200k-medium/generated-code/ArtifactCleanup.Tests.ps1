# Pester tests for ArtifactCleanup module.
# TDD: each Describe block was written failing before the corresponding
# implementation in ArtifactCleanup.psm1.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'New-Artifact factory' {
    It 'creates an artifact object with required fields' {
        $a = New-Artifact -Name 'build-1' -SizeBytes 1024 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'wf-1'
        $a.Name | Should -Be 'build-1'
        $a.SizeBytes | Should -Be 1024
        $a.WorkflowRunId | Should -Be 'wf-1'
        $a.CreatedAt | Should -BeOfType ([datetime])
    }
}

Describe 'Get-ArtifactsToDelete - max age policy' {
    It 'flags artifacts older than MaxAgeDays for deletion' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old' -SizeBytes 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'a'),
            (New-Artifact -Name 'new' -SizeBytes 100 -CreatedAt '2026-04-19T00:00:00Z' -WorkflowRunId 'b')
        )
        $plan = New-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        $plan.Delete.Name | Should -Contain 'old'
        $plan.Retain.Name | Should -Contain 'new'
    }
}

Describe 'Get-ArtifactsToDelete - keep latest N per workflow' {
    It 'keeps only the N newest artifacts per workflow run' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'wf1-a' -SizeBytes 10 -CreatedAt '2026-04-10T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf1-b' -SizeBytes 10 -CreatedAt '2026-04-15T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf1-c' -SizeBytes 10 -CreatedAt '2026-04-18T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf2-a' -SizeBytes 10 -CreatedAt '2026-04-18T00:00:00Z' -WorkflowRunId 'wf2')
        )
        $plan = New-CleanupPlan -Artifacts $artifacts -KeepLatestPerWorkflow 1 -Now $now
        $plan.Delete.Name | Should -Contain 'wf1-a'
        $plan.Delete.Name | Should -Contain 'wf1-b'
        $plan.Retain.Name | Should -Contain 'wf1-c'
        $plan.Retain.Name | Should -Contain 'wf2-a'
    }
}

Describe 'Get-ArtifactsToDelete - max total size policy' {
    It 'deletes oldest first until total size <= MaxTotalSizeBytes' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'oldest' -SizeBytes 500 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'a'),
            (New-Artifact -Name 'mid'    -SizeBytes 500 -CreatedAt '2026-04-10T00:00:00Z' -WorkflowRunId 'b'),
            (New-Artifact -Name 'newest' -SizeBytes 500 -CreatedAt '2026-04-19T00:00:00Z' -WorkflowRunId 'c')
        )
        $plan = New-CleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 1000 -Now $now
        $plan.Delete.Name | Should -Be @('oldest')
        ($plan.Retain | Measure-Object -Property SizeBytes -Sum).Sum | Should -Be 1000
    }
}

Describe 'New-CleanupPlan summary' {
    It 'computes BytesReclaimed, RetainedCount, DeletedCount' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old' -SizeBytes 1000 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'a'),
            (New-Artifact -Name 'new' -SizeBytes 200  -CreatedAt '2026-04-19T00:00:00Z' -WorkflowRunId 'b')
        )
        $plan = New-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        $plan.Summary.BytesReclaimed | Should -Be 1000
        $plan.Summary.DeletedCount | Should -Be 1
        $plan.Summary.RetainedCount | Should -Be 1
    }
}

Describe 'Combined policies' {
    It 'unions deletions across all policies' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old'    -SizeBytes 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf1-a'  -SizeBytes 100 -CreatedAt '2026-04-10T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf1-b'  -SizeBytes 100 -CreatedAt '2026-04-18T00:00:00Z' -WorkflowRunId 'wf1')
        )
        $plan = New-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestPerWorkflow 1 -Now $now
        $plan.Delete.Name | Should -Contain 'old'
        $plan.Delete.Name | Should -Contain 'wf1-a'
        $plan.Retain.Name | Should -Be @('wf1-b')
    }
}

Describe 'Invoke-ArtifactCleanup dry-run mode' {
    It 'does not call the deletion action in dry-run' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old' -SizeBytes 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'a')
        )
        $deleted = [System.Collections.ArrayList]::new()
        $action = { param($a) [void]$deleted.Add($a.Name) }
        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DryRun -DeleteAction $action
        $deleted.Count | Should -Be 0
        $plan.DryRun | Should -BeTrue
        $plan.Delete.Name | Should -Contain 'old'
    }

    It 'calls the deletion action when not in dry-run' {
        $now = [datetime]'2026-04-20T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old' -SizeBytes 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'a')
        )
        $deleted = [System.Collections.ArrayList]::new()
        $action = { param($a) [void]$deleted.Add($a.Name) }
        Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DeleteAction $action | Out-Null
        $deleted | Should -Contain 'old'
    }
}

Describe 'Error handling' {
    It 'rejects negative MaxAgeDays' {
        { New-CleanupPlan -Artifacts @() -MaxAgeDays -1 } | Should -Throw '*MaxAgeDays*'
    }
    It 'rejects negative KeepLatestPerWorkflow' {
        { New-CleanupPlan -Artifacts @() -KeepLatestPerWorkflow -1 } | Should -Throw '*KeepLatestPerWorkflow*'
    }
    It 'returns empty plan for empty input' {
        $plan = New-CleanupPlan -Artifacts @() -MaxAgeDays 30
        $plan.Summary.DeletedCount | Should -Be 0
        $plan.Summary.RetainedCount | Should -Be 0
        $plan.Summary.BytesReclaimed | Should -Be 0
    }
}

Describe 'Fixture-driven cleanup (integration with mock data)' {
    It 'processes a JSON fixture and produces expected counts' {
        $fixturePath = Join-Path $PSScriptRoot 'fixtures/artifacts-basic.json'
        if (-not (Test-Path $fixturePath)) { Set-ItResult -Skipped -Because 'fixture missing' ; return }
        $artifacts = Get-Content $fixturePath -Raw | ConvertFrom-Json | ForEach-Object {
            New-Artifact -Name $_.name -SizeBytes $_.size -CreatedAt $_.created_at -WorkflowRunId $_.workflow_run_id
        }
        $plan = New-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestPerWorkflow 2 -Now ([datetime]'2026-04-20T00:00:00Z')
        $plan.Summary.DeletedCount | Should -BeGreaterThan 0
    }
}
