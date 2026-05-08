# Pester tests for the ArtifactCleanup module.
#
# These tests were written red-first: each Describe / It block was added before
# the implementation and watched to fail, then the minimum code was added to
# make it pass, then refactored. The commit log preserves the order; here we
# keep them grouped semantically for readability.

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $modulePath = Join-Path (Split-Path -Parent $here) 'ArtifactCleanup.psm1'
    Import-Module $modulePath -Force
}

Describe 'New-Artifact (test fixture builder)' {
    It 'creates a normalized artifact hashtable with the expected keys' {
        $a = New-Artifact -Name 'build-x' -Size 100 -CreatedAt '2026-05-01T00:00:00Z' -WorkflowRunId 'wf-1'
        $a.Name           | Should -Be 'build-x'
        $a.Size           | Should -Be 100
        $a.WorkflowRunId  | Should -Be 'wf-1'
        $a.CreatedAt      | Should -BeOfType [datetime]
    }
}

Describe 'Get-CleanupPlan: max-age policy' {
    It 'marks artifacts older than MaxAgeDays for deletion with reason "age"' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @(
            (New-Artifact -Name 'old' -Size 1000 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'fresh' -Size 2000 -CreatedAt '2026-04-30T00:00:00Z' -WorkflowRunId 'wf1')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        ($plan.Delete | Where-Object Name -eq 'old').Reasons    | Should -Contain 'age'
        ($plan.Keep   | Where-Object Name -eq 'fresh')          | Should -Not -BeNullOrEmpty
    }

    It 'leaves all artifacts in Keep when MaxAgeDays is not specified' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @(
            (New-Artifact -Name 'a' -Size 1 -CreatedAt '2020-01-01T00:00:00Z' -WorkflowRunId 'wf1')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -Now $now
        $plan.Keep.Count   | Should -Be 1
        $plan.Delete.Count | Should -Be 0
    }
}

Describe 'Get-CleanupPlan: keep-latest-N-per-workflow policy' {
    It 'within each workflow keeps the N most recent and marks the rest with reason "count"' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @(
            (New-Artifact -Name 'wf1-old'    -Size 1 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf1-mid'    -Size 1 -CreatedAt '2026-04-10T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf1-newest' -Size 1 -CreatedAt '2026-04-20T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'wf2-only'   -Size 1 -CreatedAt '2026-04-15T00:00:00Z' -WorkflowRunId 'wf2')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -KeepLatestPerWorkflow 1 -Now $now
        $plan.Keep.Count                                   | Should -Be 2
        ($plan.Keep   | ForEach-Object Name) -join ','     | Should -Match 'wf1-newest'
        ($plan.Keep   | ForEach-Object Name) -join ','     | Should -Match 'wf2-only'
        ($plan.Delete | Where-Object Name -eq 'wf1-old').Reasons | Should -Contain 'count'
        ($plan.Delete | Where-Object Name -eq 'wf1-mid').Reasons | Should -Contain 'count'
    }
}

Describe 'Get-CleanupPlan: max-total-size policy' {
    It 'deletes oldest first to bring kept-set total size under MaxTotalSizeBytes' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        # Three artifacts at 1000B each; threshold 1500B should drop the two oldest.
        $artifacts = @(
            (New-Artifact -Name 'oldest' -Size 1000 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'mid'    -Size 1000 -CreatedAt '2026-04-10T00:00:00Z' -WorkflowRunId 'wf2'),
            (New-Artifact -Name 'newest' -Size 1000 -CreatedAt '2026-04-20T00:00:00Z' -WorkflowRunId 'wf3')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 1500 -Now $now
        ($plan.Keep   | ForEach-Object Name)                 | Should -Be @('newest')
        ($plan.Delete | Where-Object Name -eq 'oldest').Reasons | Should -Contain 'size'
        ($plan.Delete | Where-Object Name -eq 'mid').Reasons    | Should -Contain 'size'
    }

    It 'is a no-op when total size already fits under the threshold' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @(
            (New-Artifact -Name 'a' -Size 100 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'b' -Size 100 -CreatedAt '2026-04-10T00:00:00Z' -WorkflowRunId 'wf2')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 1000 -Now $now
        $plan.Keep.Count   | Should -Be 2
        $plan.Delete.Count | Should -Be 0
    }
}

Describe 'Get-CleanupPlan: combining policies' {
    It 'attaches every applicable reason to an artifact deleted under multiple rules' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        # 'ancient-extra' is both old (age) and not in the latest 1 per workflow (count).
        $artifacts = @(
            (New-Artifact -Name 'ancient-extra' -Size 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'fresh-keeper'  -Size 100 -CreatedAt '2026-04-25T00:00:00Z' -WorkflowRunId 'wf1')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestPerWorkflow 1 -Now $now
        $row = $plan.Delete | Where-Object Name -eq 'ancient-extra'
        $row.Reasons | Should -Contain 'age'
        $row.Reasons | Should -Contain 'count'
    }

    It 'never marks the same artifact in both Keep and Delete lists' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = 1..10 | ForEach-Object {
            New-Artifact -Name "a$_" -Size 100 -CreatedAt ([datetime]::Parse('2026-04-01T00:00:00Z').AddDays($_).ToString('o')) -WorkflowRunId "wf$($_ % 3)"
        }
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 5 -KeepLatestPerWorkflow 1 -MaxTotalSizeBytes 250 -Now $now
        $keepNames   = $plan.Keep   | ForEach-Object Name
        $deleteNames = $plan.Delete | ForEach-Object Name
        ($keepNames | Where-Object { $_ -in $deleteNames }).Count | Should -Be 0
        ($keepNames.Count + $deleteNames.Count) | Should -Be 10
    }
}

Describe 'Get-CleanupPlan: summary fields' {
    It 'reports total reclaimed bytes and counts of kept vs deleted' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @(
            (New-Artifact -Name 'old'   -Size 5000 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'fresh' -Size 100  -CreatedAt '2026-04-30T00:00:00Z' -WorkflowRunId 'wf1')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        $plan.Summary.TotalReclaimedBytes | Should -Be 5000
        $plan.Summary.KeptCount           | Should -Be 1
        $plan.Summary.DeletedCount        | Should -Be 1
        $plan.Summary.TotalArtifacts      | Should -Be 2
        $plan.Summary.DryRun              | Should -BeFalse
    }

    It 'sets DryRun=true on the summary when -DryRun is requested' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @( (New-Artifact -Name 'a' -Size 1 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf') )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 1 -Now $now -DryRun
        $plan.Summary.DryRun | Should -BeTrue
    }
}

Describe 'Format-CleanupPlanText' {
    It 'renders a human-readable report with deterministic markers used by the harness' {
        $now = [datetime]::Parse('2026-05-01T00:00:00Z').ToUniversalTime()
        $artifacts = @(
            (New-Artifact -Name 'old'   -Size 5000 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'wf1'),
            (New-Artifact -Name 'fresh' -Size 100  -CreatedAt '2026-04-30T00:00:00Z' -WorkflowRunId 'wf1')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DryRun
        $text = Format-CleanupPlanText -Plan $plan

        # Markers the act-harness greps for; keeping them stable is part of the contract.
        $text | Should -Match 'ARTIFACT-CLEANUP-SUMMARY'
        $text | Should -Match 'TotalArtifacts=2'
        $text | Should -Match 'DeletedCount=1'
        $text | Should -Match 'KeptCount=1'
        $text | Should -Match 'TotalReclaimedBytes=5000'
        $text | Should -Match 'DryRun=True'
    }
}

Describe 'Invoke-ArtifactCleanup error handling' {
    It 'throws a clear error when the input file does not exist' {
        { Invoke-ArtifactCleanup -InputPath '/no/such/file.json' } | Should -Throw '*not found*'
    }

    It 'throws a clear error when the input is not valid JSON' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value 'not-json-at-all' -NoNewline
        try {
            { Invoke-ArtifactCleanup -InputPath $tmp.FullName } | Should -Throw '*JSON*'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}
