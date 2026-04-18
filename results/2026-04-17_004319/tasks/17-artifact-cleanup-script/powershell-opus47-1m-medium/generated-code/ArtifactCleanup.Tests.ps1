# Pester tests for ArtifactCleanup module.
# Tests were written red/green style: each Context below started as a failing
# test, then the module grew to make it pass, then refactor.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

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

    $script:Now = [datetime]'2026-04-17T00:00:00Z'
}

Describe 'New-ArtifactCleanupPlan' {

    Context 'no policies enabled' {
        It 'retains every artifact' {
            $artifacts = @(
                (script:New-Artifact -Name 'a' -Size 100 -CreationDate $script:Now.AddDays(-1) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'b' -Size 200 -CreationDate $script:Now.AddDays(-100) -WorkflowRunId 'wf2')
            )
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -Now $script:Now
            $plan.Summary.DeletedCount | Should -Be 0
            $plan.Summary.RetainedCount | Should -Be 2
            $plan.Summary.SpaceReclaimed | Should -Be 0
        }
    }

    Context 'MaxAgeDays policy' {
        It 'deletes artifacts older than the cutoff' {
            $artifacts = @(
                (script:New-Artifact -Name 'new' -Size 100 -CreationDate $script:Now.AddDays(-5) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'old' -Size 500 -CreationDate $script:Now.AddDays(-40) -WorkflowRunId 'wf1')
            )
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:Now
            $plan.Summary.DeletedCount | Should -Be 1
            $plan.ToDelete[0].Name | Should -Be 'old'
            $plan.Summary.SpaceReclaimed | Should -Be 500
        }
    }

    Context 'MaxTotalSizeBytes policy' {
        It 'deletes oldest first until under budget' {
            $artifacts = @(
                (script:New-Artifact -Name 'oldest' -Size 400 -CreationDate $script:Now.AddDays(-3) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'middle' -Size 400 -CreationDate $script:Now.AddDays(-2) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'newest' -Size 400 -CreationDate $script:Now.AddDays(-1) -WorkflowRunId 'wf1')
            )
            # Budget 500 means only newest (400) survives.
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 500 -Now $script:Now
            $plan.Summary.DeletedCount | Should -Be 2
            ($plan.ToDelete | ForEach-Object Name) | Should -Be @('oldest','middle')
            $plan.ToRetain[0].Name | Should -Be 'newest'
            $plan.Summary.SpaceReclaimed | Should -Be 800
        }
    }

    Context 'KeepLatestPerWorkflow policy' {
        It 'rescues the N newest artifacts per workflow from age-based deletion' {
            $artifacts = @(
                (script:New-Artifact -Name 'wf1-a' -Size 100 -CreationDate $script:Now.AddDays(-100) -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf1-b' -Size 100 -CreationDate $script:Now.AddDays(-90)  -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf1-c' -Size 100 -CreationDate $script:Now.AddDays(-80)  -WorkflowRunId 'wf1')
                (script:New-Artifact -Name 'wf2-a' -Size 100 -CreationDate $script:Now.AddDays(-200) -WorkflowRunId 'wf2')
            )
            # Age policy would nuke all 4, but keep-latest-2 rescues wf1-b, wf1-c and wf2-a.
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
            $plan = New-ArtifactCleanupPlan -Artifacts $artifacts `
                -MaxAgeDays 30 -MaxTotalSizeBytes 800 -KeepLatestPerWorkflow 1 -Now $script:Now
            # wf1-old deleted by age. Remaining: wf1-new(300)+wf2-heavy(900)=1200>800.
            # wf2-heavy is protected (latest of wf2), so wf1-new would be deleted next — but wf1-new is also protected (latest of wf1).
            # Nothing else can be deleted. Plan should still be valid.
            $plan.ToDelete[0].Name | Should -Be 'wf1-old'
            $plan.Summary.DeletedCount | Should -Be 1
        }
    }

    Context 'DryRun flag' {
        It 'marks the summary as DryRun' {
            $plan = New-ArtifactCleanupPlan -Artifacts @((script:New-Artifact -Name 'a' -Size 1 -CreationDate $script:Now -WorkflowRunId 'wf1')) -DryRun -Now $script:Now
            $plan.Summary.DryRun | Should -BeTrue
        }
    }

    Context 'validation' {
        It 'throws when an artifact is missing a required property' {
            $bad = [pscustomobject]@{ Name='x'; Size=1; CreationDate=$script:Now }  # no WorkflowRunId
            { New-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:Now } |
                Should -Throw "*WorkflowRunId*"
        }
        It 'throws on negative size' {
            $bad = script:New-Artifact -Name 'neg' -Size -1 -CreationDate $script:Now -WorkflowRunId 'wf1'
            { New-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:Now } |
                Should -Throw "*negative Size*"
        }
    }
}

Describe 'Invoke-ArtifactCleanup' {
    It 'returns the same plan and prints a summary' {
        $artifacts = @(
            (script:New-Artifact -Name 'a' -Size 100 -CreationDate $script:Now.AddDays(-60) -WorkflowRunId 'wf1')
            (script:New-Artifact -Name 'b' -Size 100 -CreationDate $script:Now.AddDays(-1)  -WorkflowRunId 'wf1')
        )
        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -DryRun -Now $script:Now
        $plan.Summary.DeletedCount | Should -Be 1
    }
}
