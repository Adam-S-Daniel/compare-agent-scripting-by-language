# Pester tests for ArtifactCleanup module.
#
# Built incrementally using red/green TDD. Each Describe block represents one
# unit of behavior added to the module. The tests use a deterministic
# "now" timestamp so the suite is hermetic and reproducible.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # Fixed reference time so retention math is deterministic in tests.
    $script:Now = [datetime]'2026-04-19T12:00:00Z'

    function script:New-Artifact {
        param(
            [string]$Name,
            [long]$SizeBytes,
            [datetime]$Created,
            [string]$WorkflowRunId,
            [string]$Id = [guid]::NewGuid().ToString()
        )
        [pscustomobject]@{
            id            = $Id
            name          = $Name
            sizeBytes     = $SizeBytes
            createdAt     = $Created
            workflowRunId = $WorkflowRunId
        }
    }
}

Describe 'Get-ArtifactDeletionPlan: max-age policy' {

    It 'marks artifacts older than MaxAgeDays for deletion' {
        $artifacts = @(
            New-Artifact -Name 'old'   -SizeBytes 100 -Created $Now.AddDays(-40) -WorkflowRunId 'run-1'
            New-Artifact -Name 'fresh' -SizeBytes 200 -Created $Now.AddDays(-5)  -WorkflowRunId 'run-2'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $Now

        ($plan.Delete | Measure-Object).Count | Should -Be 1
        $plan.Delete[0].name | Should -Be 'old'
        ($plan.Retain | Measure-Object).Count | Should -Be 1
        $plan.Retain[0].name | Should -Be 'fresh'
    }

    It 'records the reason "max-age" on age-evicted artifacts' {
        $artifacts = @(
            New-Artifact -Name 'old' -SizeBytes 1 -Created $Now.AddDays(-100) -WorkflowRunId 'r'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $Now

        $plan.Delete[0].reason | Should -Be 'max-age'
    }

    It 'leaves all artifacts retained when no policies are supplied' {
        $artifacts = @(
            New-Artifact -Name 'a' -SizeBytes 1 -Created $Now.AddDays(-1000) -WorkflowRunId 'r'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Now $Now

        ($plan.Delete | Measure-Object).Count | Should -Be 0
        ($plan.Retain | Measure-Object).Count | Should -Be 1
    }
}

Describe 'Get-ArtifactDeletionPlan: keep-latest-N per workflow' {

    It 'keeps only the N newest artifacts per workflow run id' {
        $artifacts = @(
            New-Artifact -Name 'wf1-a' -SizeBytes 10 -Created $Now.AddDays(-1) -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf1-b' -SizeBytes 10 -Created $Now.AddDays(-2) -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf1-c' -SizeBytes 10 -Created $Now.AddDays(-3) -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf2-a' -SizeBytes 10 -Created $Now.AddDays(-1) -WorkflowRunId 'wf2'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -KeepLatestPerWorkflow 2 -Now $Now

        ($plan.Delete | Measure-Object).Count | Should -Be 1
        $plan.Delete[0].name | Should -Be 'wf1-c'
        $plan.Delete[0].reason | Should -Be 'keep-latest-per-workflow'
    }

    It 'retains all artifacts when count per workflow does not exceed N' {
        $artifacts = @(
            New-Artifact -Name 'wf1-a' -SizeBytes 10 -Created $Now.AddDays(-1) -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf2-a' -SizeBytes 10 -Created $Now.AddDays(-1) -WorkflowRunId 'wf2'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -KeepLatestPerWorkflow 3 -Now $Now

        ($plan.Delete | Measure-Object).Count | Should -Be 0
    }
}

Describe 'Get-ArtifactDeletionPlan: max-total-size policy' {

    It 'evicts oldest artifacts until total retained size is within budget' {
        # 4 artifacts at 100 bytes each = 400 bytes total. Budget 250 -> must
        # delete two oldest to stay <= 250.
        $artifacts = @(
            New-Artifact -Name 'newest' -SizeBytes 100 -Created $Now.AddDays(-1) -WorkflowRunId 'a'
            New-Artifact -Name 'mid1'   -SizeBytes 100 -Created $Now.AddDays(-2) -WorkflowRunId 'b'
            New-Artifact -Name 'mid2'   -SizeBytes 100 -Created $Now.AddDays(-3) -WorkflowRunId 'c'
            New-Artifact -Name 'oldest' -SizeBytes 100 -Created $Now.AddDays(-4) -WorkflowRunId 'd'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxTotalSizeBytes 250 -Now $Now

        ($plan.Delete | Measure-Object).Count | Should -Be 2
        $plan.Delete.name | Should -Contain 'oldest'
        $plan.Delete.name | Should -Contain 'mid2'
        $plan.Delete[0].reason | Should -Be 'max-total-size'
    }

    It 'is a no-op when total size is already within budget' {
        $artifacts = @(
            New-Artifact -Name 'a' -SizeBytes 50 -Created $Now.AddDays(-1) -WorkflowRunId 'wf'
            New-Artifact -Name 'b' -SizeBytes 50 -Created $Now.AddDays(-2) -WorkflowRunId 'wf'
        )

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxTotalSizeBytes 1000 -Now $Now

        ($plan.Delete | Measure-Object).Count | Should -Be 0
    }
}

Describe 'Get-ArtifactDeletionPlan: combined policies and summary' {

    It 'applies all policies together and produces a summary' {
        $artifacts = @(
            # Both wf1 artifacts will be deleted: one by age, one by keep-latest.
            New-Artifact -Name 'wf1-old'   -SizeBytes 1000 -Created $Now.AddDays(-100) -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf1-newer' -SizeBytes 500  -Created $Now.AddDays(-2)   -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf1-newest'-SizeBytes 500  -Created $Now.AddDays(-1)   -WorkflowRunId 'wf1'
            New-Artifact -Name 'wf2'       -SizeBytes 200  -Created $Now.AddDays(-3)   -WorkflowRunId 'wf2'
        )

        $plan = Get-ArtifactDeletionPlan `
            -Artifacts $artifacts `
            -MaxAgeDays 30 `
            -KeepLatestPerWorkflow 1 `
            -Now $Now

        # wf1-old: age >30d -> delete (max-age)
        # wf1-newer: not newest in wf1 -> delete (keep-latest)
        # wf1-newest: kept (newest of wf1)
        # wf2: kept (only one in wf2, and within age)
        ($plan.Delete | Measure-Object).Count | Should -Be 2
        ($plan.Retain | Measure-Object).Count | Should -Be 2

        $plan.Summary.TotalArtifacts          | Should -Be 4
        $plan.Summary.RetainedCount           | Should -Be 2
        $plan.Summary.DeletedCount            | Should -Be 2
        $plan.Summary.BytesReclaimed          | Should -Be 1500
        $plan.Summary.BytesRetained           | Should -Be 700
    }

    It 'produces a zero-summary when input list is empty' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -MaxAgeDays 30 -Now $Now

        $plan.Summary.TotalArtifacts | Should -Be 0
        $plan.Summary.BytesReclaimed | Should -Be 0
    }
}

Describe 'Get-ArtifactDeletionPlan: input validation' {

    It 'throws a meaningful error when an artifact is missing required fields' {
        $bad = @(
            [pscustomobject]@{ name = 'no-size'; createdAt = $Now; workflowRunId = 'r' }
        )

        { Get-ArtifactDeletionPlan -Artifacts $bad -MaxAgeDays 30 -Now $Now } |
            Should -Throw -ExpectedMessage '*sizeBytes*'
    }

    It 'rejects negative MaxAgeDays' {
        { Get-ArtifactDeletionPlan -Artifacts @() -MaxAgeDays -1 -Now $Now } |
            Should -Throw
    }
}

Describe 'Invoke-ArtifactCleanup: dry-run vs apply' {

    It 'in dry-run mode does not invoke the deleter callback' {
        $deleted = New-Object System.Collections.Generic.List[string]
        $artifacts = @(
            New-Artifact -Id 'A1' -Name 'old' -SizeBytes 1 -Created $Now.AddDays(-100) -WorkflowRunId 'r'
        )

        $result = Invoke-ArtifactCleanup `
            -Artifacts $artifacts `
            -MaxAgeDays 30 `
            -Now $Now `
            -DryRun `
            -Deleter { param($a) $deleted.Add($a.id) }

        $deleted.Count | Should -Be 0
        $result.DryRun | Should -BeTrue
        $result.Plan.Summary.DeletedCount | Should -Be 1
    }

    It 'in apply mode invokes the deleter callback for each deleted artifact' {
        $deleted = New-Object System.Collections.Generic.List[string]
        $artifacts = @(
            New-Artifact -Id 'A1' -Name 'old1' -SizeBytes 1 -Created $Now.AddDays(-100) -WorkflowRunId 'r'
            New-Artifact -Id 'A2' -Name 'old2' -SizeBytes 1 -Created $Now.AddDays(-100) -WorkflowRunId 'r2'
        )

        $result = Invoke-ArtifactCleanup `
            -Artifacts $artifacts `
            -MaxAgeDays 30 `
            -Now $Now `
            -Deleter { param($a) $deleted.Add($a.id) }

        $deleted.Count | Should -Be 2
        $result.DryRun | Should -BeFalse
    }

    It 'records deletion failures rather than aborting the run' {
        $artifacts = @(
            New-Artifact -Id 'good' -Name 'old1' -SizeBytes 1 -Created $Now.AddDays(-100) -WorkflowRunId 'r'
            New-Artifact -Id 'bad'  -Name 'old2' -SizeBytes 1 -Created $Now.AddDays(-100) -WorkflowRunId 'r'
        )

        $result = Invoke-ArtifactCleanup `
            -Artifacts $artifacts `
            -MaxAgeDays 30 `
            -Now $Now `
            -Deleter {
                param($a)
                if ($a.id -eq 'bad') { throw 'simulated API failure' }
            }

        $result.DeletedSucceeded.Count | Should -Be 1
        $result.DeletedFailed.Count    | Should -Be 1
        $result.DeletedFailed[0].Error | Should -Match 'simulated API failure'
    }
}

Describe 'Format-DeletionPlanReport' {

    It 'renders a human-readable summary including reclaimed bytes' {
        $artifacts = @(
            New-Artifact -Name 'old' -SizeBytes 1024 -Created $Now.AddDays(-100) -WorkflowRunId 'r'
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $Now
        $report = Format-DeletionPlanReport -Plan $plan

        $report | Should -Match 'Total artifacts:\s+1'
        $report | Should -Match 'Delete:\s+1'
        $report | Should -Match 'Retain:\s+0'
        $report | Should -Match '1024'
    }
}
