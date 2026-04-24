# ArtifactCleanup.Tests.ps1
# TDD red/green: each Context was written as a failing test first, then
# the minimum module code was added to make it pass.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # Helper: construct a typed artifact object
    function script:New-Artifact {
        param(
            [string]$Name,
            [long]$Size,
            [datetime]$CreationDate,
            [string]$WorkflowRunId
        )
        [pscustomobject]@{
            Name          = $Name
            Size          = $Size
            CreationDate  = $CreationDate
            WorkflowRunId = $WorkflowRunId
        }
    }

    # Fixed reference time so tests are deterministic
    $script:Now = [datetime]'2026-04-17T00:00:00Z'
}

Describe 'New-ArtifactCleanupPlan' {

    Context 'no policies enabled' {
        It 'retains all artifacts when no policy is set' {
            $artifacts = @(
                (script:New-Artifact -Name 'a' -Size 100 -CreationDate $script:Now.AddDays(-1) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'b' -Size 200 -CreationDate $script:Now.AddDays(-100) -WorkflowRunId 'wf2')
            )
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -Now $script:Now
            $plan.Summary.DeletedCount  | Should -Be 0
            $plan.Summary.RetainedCount | Should -Be 2
            $plan.Summary.SpaceReclaimed | Should -Be 0
        }
    }

    Context 'MaxAgeDays policy' {
        It 'deletes artifacts older than the age cutoff' {
            $artifacts = @(
                (script:New-Artifact -Name 'new-art' -Size 100 -CreationDate $script:Now.AddDays(-5)  -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'old-art' -Size 500 -CreationDate $script:Now.AddDays(-40) -WorkflowRunId 'wf1')
            )
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:Now
            $plan.Summary.DeletedCount    | Should -Be 1
            $plan.ToDelete[0].Name        | Should -Be 'old-art'
            $plan.Summary.SpaceReclaimed  | Should -Be 500
        }

        It 'retains artifacts exactly at the age boundary' {
            $artifacts = @(
                (script:New-Artifact -Name 'on-boundary' -Size 100 -CreationDate $script:Now.AddDays(-30) -WorkflowRunId 'wf1')
            )
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:Now
            # Artifact created exactly 30 days ago is NOT older than 30 days
            $plan.Summary.DeletedCount | Should -Be 0
        }
    }

    Context 'MaxTotalSizeBytes policy' {
        It 'deletes oldest artifacts first until total is within budget' {
            $artifacts = @(
                (script:New-Artifact -Name 'oldest' -Size 400 -CreationDate $script:Now.AddDays(-3) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'middle' -Size 400 -CreationDate $script:Now.AddDays(-2) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'newest' -Size 400 -CreationDate $script:Now.AddDays(-1) -WorkflowRunId 'wf1')
            )
            # Budget 500 — need to delete 2 oldest to get under budget
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 500 -Now $script:Now
            $plan.Summary.DeletedCount   | Should -Be 2
            ($plan.ToDelete | ForEach-Object Name) | Should -Be @('oldest','middle')
            $plan.ToRetain[0].Name        | Should -Be 'newest'
            $plan.Summary.SpaceReclaimed  | Should -Be 800
        }

        It 'deletes nothing when total size is within budget' {
            $artifacts = @(
                (script:New-Artifact -Name 'small' -Size 100 -CreationDate $script:Now.AddDays(-1) -WorkflowRunId 'wf1')
            )
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 5000 -Now $script:Now
            $plan.Summary.DeletedCount | Should -Be 0
        }
    }

    Context 'KeepLatestPerWorkflow policy' {
        It 'rescues the N newest artifacts per workflow from age deletion' {
            $artifacts = @(
                (script:New-Artifact -Name 'wf1-a' -Size 100 -CreationDate $script:Now.AddDays(-100) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf1-b' -Size 100 -CreationDate $script:Now.AddDays(-90)  -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf1-c' -Size 100 -CreationDate $script:Now.AddDays(-80)  -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf2-a' -Size 100 -CreationDate $script:Now.AddDays(-200) -WorkflowRunId 'wf2')
            )
            # Age policy would delete all 4; keep-latest-2 rescues wf1-b, wf1-c (newest 2 of wf1) and wf2-a (newest 1 of wf2)
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestPerWorkflow 2 -Now $script:Now
            ($plan.ToRetain | ForEach-Object Name | Sort-Object) | Should -Be @('wf1-b','wf1-c','wf2-a')
            $plan.ToDelete[0].Name | Should -Be 'wf1-a'
        }
    }

    Context 'combined policies' {
        It 'applies age, size, and keep-latest together' {
            $artifacts = @(
                (script:New-Artifact -Name 'wf1-old'   -Size 300 -CreationDate $script:Now.AddDays(-100) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf1-new'   -Size 300 -CreationDate $script:Now.AddDays(-1)   -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf2-heavy' -Size 900 -CreationDate $script:Now.AddDays(-2)   -WorkflowRunId 'wf2')
            )
            # wf1-old deleted by age; wf1-new and wf2-heavy are both protected (latest per wf) so size budget can't trim them
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts `
                -MaxAgeDays 30 -MaxTotalSizeBytes 800 -KeepLatestPerWorkflow 1 -Now $script:Now
            $plan.ToDelete[0].Name       | Should -Be 'wf1-old'
            $plan.Summary.DeletedCount   | Should -Be 1
        }
    }

    Context 'DryRun flag' {
        It 'sets DryRun=true on the summary' {
            $a = script:New-Artifact -Name 'x' -Size 1 -CreationDate $script:Now -WorkflowRunId 'wf1'
            $plan = New-ArtifactCleanupPlan -Artifacts @($a) -DryRun -Now $script:Now
            $plan.Summary.DryRun | Should -BeTrue
        }

        It 'sets DryRun=false by default' {
            $a = script:New-Artifact -Name 'x' -Size 1 -CreationDate $script:Now -WorkflowRunId 'wf1'
            $plan = New-ArtifactCleanupPlan -Artifacts @($a) -Now $script:Now
            $plan.Summary.DryRun | Should -BeFalse
        }
    }

    Context 'input validation' {
        It 'throws when an artifact is missing WorkflowRunId' {
            $bad = [pscustomobject]@{ Name='x'; Size=1; CreationDate=$script:Now }
            { New-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:Now } |
                Should -Throw "*WorkflowRunId*"
        }

        It 'throws when artifact has negative size' {
            $bad = script:New-Artifact -Name 'neg' -Size -1 -CreationDate $script:Now -WorkflowRunId 'wf1'
            { New-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:Now } |
                Should -Throw "*negative Size*"
        }
    }
}

Describe 'Invoke-ArtifactCleanup' {
    It 'returns a plan and prints a summary' {
        $artifacts = @(
            (script:New-Artifact -Name 'old' -Size 100 -CreationDate $script:Now.AddDays(-60) -WorkflowRunId 'wf1')
            (script:New-Artifact -Name 'new' -Size 100 -CreationDate $script:Now.AddDays(-1)  -WorkflowRunId 'wf1')
        )
        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -DryRun -Now $script:Now
        $plan.Summary.DeletedCount | Should -Be 1
    }
}
