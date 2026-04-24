# Pester tests for ArtifactCleanup module.
# TDD: each Describe block was written red-first, then the module was
# grown to satisfy it. Tests are deterministic — "today" is always injected.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # Deterministic "now" used across all tests so age math is reproducible.
    $script:TestNow = [datetime]'2026-04-19T00:00:00Z'

    function script:New-TestArtifact {
        param(
            [string]$Name,
            [long]$SizeBytes,
            [datetime]$CreatedAt,
            [string]$WorkflowRunId
        )
        [pscustomobject]@{
            Name          = $Name
            SizeBytes     = $SizeBytes
            CreatedAt     = $CreatedAt
            WorkflowRunId = $WorkflowRunId
        }
    }
}

AfterAll {
    Remove-Module ArtifactCleanup -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ArtifactCleanupPlan - input validation' {
    It 'returns an empty plan when given no artifacts' {
        $plan = Get-ArtifactCleanupPlan -Artifacts @() -Now $script:TestNow
        $plan.ToDelete      | Should -HaveCount 0
        $plan.ToRetain      | Should -HaveCount 0
        $plan.BytesReclaimed | Should -Be 0
    }

    It 'throws a clear message when an artifact is missing required fields' {
        $bad = [pscustomobject]@{ Name = 'x' }  # missing SizeBytes, CreatedAt, WorkflowRunId
        { Get-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:TestNow } |
            Should -Throw '*missing required field*'
    }
}

Describe 'Get-ArtifactCleanupPlan - MaxAgeDays policy' {
    It 'deletes artifacts older than MaxAgeDays' {
        $artifacts = @(
            (New-TestArtifact -Name 'old'    -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-40) -WorkflowRunId 'r1')
            (New-TestArtifact -Name 'recent' -SizeBytes 200 -CreatedAt $script:TestNow.AddDays(-5)  -WorkflowRunId 'r2')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:TestNow

        $plan.ToDelete.Name  | Should -Be 'old'
        $plan.ToRetain.Name  | Should -Be 'recent'
        $plan.BytesReclaimed | Should -Be 100
    }

    It 'records the MaxAgeDays reason on deleted items' {
        $artifacts = @(
            (New-TestArtifact -Name 'ancient' -SizeBytes 50 -CreatedAt $script:TestNow.AddDays(-100) -WorkflowRunId 'r1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:TestNow
        $plan.ToDelete[0].Reason | Should -Match 'MaxAgeDays'
    }
}

Describe 'Get-ArtifactCleanupPlan - KeepLatestPerWorkflow policy' {
    It 'keeps only the N newest artifacts per workflow run id' {
        $artifacts = @(
            (New-TestArtifact -Name 'a-old'    -SizeBytes 10 -CreatedAt $script:TestNow.AddDays(-10) -WorkflowRunId 'ci')
            (New-TestArtifact -Name 'a-mid'    -SizeBytes 20 -CreatedAt $script:TestNow.AddDays(-5)  -WorkflowRunId 'ci')
            (New-TestArtifact -Name 'a-new'    -SizeBytes 30 -CreatedAt $script:TestNow.AddDays(-1)  -WorkflowRunId 'ci')
            (New-TestArtifact -Name 'b-only'   -SizeBytes 40 -CreatedAt $script:TestNow.AddDays(-3)  -WorkflowRunId 'release')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -KeepLatestPerWorkflow 2 -Now $script:TestNow

        ($plan.ToDelete.Name | Sort-Object) | Should -Be @('a-old')
        ($plan.ToRetain.Name | Sort-Object) | Should -Be @('a-mid','a-new','b-only')
        $plan.BytesReclaimed | Should -Be 10
    }
}

Describe 'Get-ArtifactCleanupPlan - MaxTotalSizeBytes policy' {
    It 'deletes oldest artifacts until total retained size is at or below the cap' {
        $artifacts = @(
            (New-TestArtifact -Name 'oldest' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-10) -WorkflowRunId 'r1')
            (New-TestArtifact -Name 'middle' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-5)  -WorkflowRunId 'r2')
            (New-TestArtifact -Name 'newest' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-1)  -WorkflowRunId 'r3')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 150 -Now $script:TestNow

        ($plan.ToDelete.Name | Sort-Object)   | Should -Be @('middle','oldest')
        $plan.ToRetain.Name                   | Should -Be 'newest'
        $plan.BytesReclaimed                  | Should -Be 200
    }
}

Describe 'Get-ArtifactCleanupPlan - policy precedence' {
    It 'does not double-count an artifact caught by multiple policies' {
        # 'old-in-ci' is both past MaxAgeDays AND beyond KeepLatestPerWorkflow.
        $artifacts = @(
            (New-TestArtifact -Name 'old-in-ci' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-60) -WorkflowRunId 'ci')
            (New-TestArtifact -Name 'new-in-ci' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-1)  -WorkflowRunId 'ci')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts `
                                        -MaxAgeDays 30 `
                                        -KeepLatestPerWorkflow 1 `
                                        -Now $script:TestNow

        $plan.ToDelete       | Should -HaveCount 1
        $plan.ToDelete.Name  | Should -Be 'old-in-ci'
        $plan.BytesReclaimed | Should -Be 100
    }
}

Describe 'Get-ArtifactCleanupPlan - summary' {
    It 'produces a summary with counts and space metrics' {
        $artifacts = @(
            (New-TestArtifact -Name 'a' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-90) -WorkflowRunId 'r1')
            (New-TestArtifact -Name 'b' -SizeBytes 200 -CreatedAt $script:TestNow.AddDays(-1)  -WorkflowRunId 'r2')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:TestNow

        $plan.Summary.TotalArtifacts  | Should -Be 2
        $plan.Summary.DeletedCount    | Should -Be 1
        $plan.Summary.RetainedCount   | Should -Be 1
        $plan.Summary.BytesReclaimed  | Should -Be 100
        $plan.Summary.BytesRetained   | Should -Be 200
    }
}

Describe 'Invoke-ArtifactCleanup - dry-run semantics' {
    It 'never invokes the delete action when DryRun is set' {
        $artifacts = @(
            (New-TestArtifact -Name 'doomed' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-90) -WorkflowRunId 'r1')
        )
        $script:deleteCalls = @()
        $deleteAction = { param($artifact) $script:deleteCalls += $artifact.Name }

        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts `
                                       -MaxAgeDays 30 `
                                       -Now $script:TestNow `
                                       -DryRun `
                                       -DeleteAction $deleteAction

        $script:deleteCalls  | Should -HaveCount 0
        $plan.ToDelete.Name  | Should -Be 'doomed'
        $plan.DryRun         | Should -BeTrue
    }

    It 'invokes the delete action once per deletable artifact when not a dry run' {
        $artifacts = @(
            (New-TestArtifact -Name 'd1' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-90) -WorkflowRunId 'r1')
            (New-TestArtifact -Name 'd2' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-80) -WorkflowRunId 'r2')
            (New-TestArtifact -Name 'keep' -SizeBytes 100 -CreatedAt $script:TestNow.AddDays(-1) -WorkflowRunId 'r3')
        )
        $script:deleteCalls = @()
        $deleteAction = { param($artifact) $script:deleteCalls += $artifact.Name }

        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts `
                                       -MaxAgeDays 30 `
                                       -Now $script:TestNow `
                                       -DeleteAction $deleteAction

        ($script:deleteCalls | Sort-Object) | Should -Be @('d1','d2')
        $plan.DryRun | Should -BeFalse
    }

    It 'collects failures from the delete action and still returns a plan' {
        $artifacts = @(
            (New-TestArtifact -Name 'boom' -SizeBytes 50 -CreatedAt $script:TestNow.AddDays(-90) -WorkflowRunId 'r1')
        )
        $deleteAction = { param($artifact) throw "simulated API failure for $($artifact.Name)" }

        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts `
                                       -MaxAgeDays 30 `
                                       -Now $script:TestNow `
                                       -DeleteAction $deleteAction

        $plan.Failures                | Should -HaveCount 1
        $plan.Failures[0].Name        | Should -Be 'boom'
        $plan.Failures[0].Error       | Should -Match 'simulated API failure'
    }
}
