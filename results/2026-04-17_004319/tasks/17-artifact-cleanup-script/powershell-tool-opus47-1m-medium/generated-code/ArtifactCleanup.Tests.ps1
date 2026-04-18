#Requires -Module @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

# TDD tests for ArtifactCleanup. Each Describe block corresponds to one
# requirement of the retention engine. Tests were authored red-first and
# the module implementation was built to satisfy them.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-ArtifactCleanupPlan - input validation' {
    It 'returns an empty plan when given no artifacts' {
        $plan = Get-ArtifactCleanupPlan -Artifacts @() -Now (Get-Date '2026-01-01')
        $plan.Retained.Count | Should -Be 0
        $plan.Deleted.Count  | Should -Be 0
        $plan.SpaceReclaimedBytes | Should -Be 0
    }

    It 'throws when an artifact is missing required properties' {
        { Get-ArtifactCleanupPlan -Artifacts @([pscustomobject]@{ Name = 'x' }) } |
            Should -Throw -ExpectedMessage '*required*'
    }
}

Describe 'Get-ArtifactCleanupPlan - MaxAgeDays policy' {
    It 'deletes artifacts older than MaxAgeDays' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            [pscustomobject]@{ Name='old';   SizeBytes=100; CreatedAt=$now.AddDays(-40); WorkflowRunId='wf1' }
            [pscustomobject]@{ Name='fresh'; SizeBytes=200; CreatedAt=$now.AddDays(-1);  WorkflowRunId='wf1' }
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        $plan.Deleted.Name  | Should -Be 'old'
        $plan.Retained.Name | Should -Be 'fresh'
        $plan.SpaceReclaimedBytes | Should -Be 100
    }
}

Describe 'Get-ArtifactCleanupPlan - KeepLatestNPerWorkflow policy' {
    It 'keeps only the latest N per workflow run id' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            [pscustomobject]@{ Name='a1'; SizeBytes=10; CreatedAt=$now.AddDays(-3); WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='a2'; SizeBytes=10; CreatedAt=$now.AddDays(-2); WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='a3'; SizeBytes=10; CreatedAt=$now.AddDays(-1); WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='b1'; SizeBytes=10; CreatedAt=$now.AddDays(-1); WorkflowRunId='wfB' }
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -KeepLatestNPerWorkflow 2 -Now $now
        ($plan.Retained.Name | Sort-Object) -join ',' | Should -Be 'a2,a3,b1'
        $plan.Deleted.Name | Should -Be 'a1'
    }
}

Describe 'Get-ArtifactCleanupPlan - MaxTotalSizeBytes policy' {
    It 'evicts oldest artifacts until total size is under the cap' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            [pscustomobject]@{ Name='oldest'; SizeBytes=100; CreatedAt=$now.AddDays(-5); WorkflowRunId='wf' }
            [pscustomobject]@{ Name='mid';    SizeBytes=100; CreatedAt=$now.AddDays(-3); WorkflowRunId='wf' }
            [pscustomobject]@{ Name='newest'; SizeBytes=100; CreatedAt=$now.AddDays(-1); WorkflowRunId='wf' }
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 200 -Now $now
        $plan.Retained.Count | Should -Be 2
        $plan.Retained.Name -contains 'newest' | Should -BeTrue
        $plan.Retained.Name -contains 'mid'    | Should -BeTrue
        $plan.Deleted.Name | Should -Be 'oldest'
        $plan.SpaceReclaimedBytes | Should -Be 100
    }
}

Describe 'Get-ArtifactCleanupPlan - combined policies' {
    It 'applies age, keep-latest, and size together' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            [pscustomobject]@{ Name='ancient'; SizeBytes=500; CreatedAt=$now.AddDays(-90); WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='a1';      SizeBytes=300; CreatedAt=$now.AddDays(-10); WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='a2';      SizeBytes=300; CreatedAt=$now.AddDays(-5);  WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='a3';      SizeBytes=300; CreatedAt=$now.AddDays(-2);  WorkflowRunId='wfA' }
            [pscustomobject]@{ Name='b1';      SizeBytes=100; CreatedAt=$now.AddDays(-1);  WorkflowRunId='wfB' }
        )
        $plan = Get-ArtifactCleanupPlan `
            -Artifacts $artifacts `
            -MaxAgeDays 30 `
            -KeepLatestNPerWorkflow 2 `
            -MaxTotalSizeBytes 500 `
            -Now $now

        # ancient -> aged out; a1 -> beyond keep-latest-2 for wfA;
        # then retained = {a2=300, a3=300, b1=100} = 700 > 500 cap,
        # evict oldest until under: drop a2(300) -> 400 OK.
        ($plan.Retained.Name | Sort-Object) -join ',' | Should -Be 'a3,b1'
        ($plan.Deleted.Name  | Sort-Object) -join ',' | Should -Be 'a1,a2,ancient'
        $plan.SpaceReclaimedBytes | Should -Be (500 + 300 + 300)
    }
}

Describe 'Get-ArtifactCleanupPlan - summary and dry-run' {
    It 'populates summary counters' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            [pscustomobject]@{ Name='x'; SizeBytes=10; CreatedAt=$now.AddDays(-100); WorkflowRunId='w' }
            [pscustomobject]@{ Name='y'; SizeBytes=20; CreatedAt=$now.AddDays(-1);   WorkflowRunId='w' }
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DryRun
        $plan.TotalRetained | Should -Be 1
        $plan.TotalDeleted  | Should -Be 1
        $plan.DryRun        | Should -BeTrue
        $plan.SpaceReclaimedBytes | Should -Be 10
    }
}

Describe 'Invoke-ArtifactCleanup script entry point' {
    It 'loads artifacts from JSON and prints a summary' {
        $fixture = @(
            @{ Name='keep'; SizeBytes=10; CreatedAt='2026-04-16T00:00:00Z'; WorkflowRunId='w1' }
            @{ Name='drop'; SizeBytes=99; CreatedAt='2025-01-01T00:00:00Z'; WorkflowRunId='w1' }
        ) | ConvertTo-Json
        $tmp = New-TemporaryFile
        Set-Content -LiteralPath $tmp -Value $fixture
        try {
            $output = & (Join-Path $PSScriptRoot 'Invoke-ArtifactCleanup.ps1') `
                -ArtifactsJsonPath $tmp `
                -MaxAgeDays 30 `
                -Now '2026-04-17T00:00:00Z' `
                -DryRun 6>&1 | Out-String
            $output | Should -Match 'Deleted:\s*1'
            $output | Should -Match 'Retained:\s*1'
            $output | Should -Match 'Reclaimed:\s*99'
            $output | Should -Match 'DRY-RUN'
        } finally {
            Remove-Item $tmp -Force
        }
    }
}
