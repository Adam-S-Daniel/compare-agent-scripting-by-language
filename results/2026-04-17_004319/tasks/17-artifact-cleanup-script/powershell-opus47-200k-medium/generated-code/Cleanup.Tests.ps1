# Pester tests for Cleanup.ps1 — retention policy driven artifact cleanup.
# Each Describe block represents a TDD red/green cycle.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'Cleanup.ps1'
    . $script:ModulePath

    # Helper: build a deterministic artifact record.
    function New-TestArtifact {
        param(
            [string]$Name,
            [long]$Size,
            [datetime]$Created,
            [string]$WorkflowRunId
        )
        [pscustomobject]@{
            Name          = $Name
            Size          = $Size
            Created       = $Created
            WorkflowRunId = $WorkflowRunId
        }
    }

    $script:Now = [datetime]'2026-04-20T00:00:00Z'
}

Describe 'Get-CleanupPlan — max age policy' {
    It 'marks artifacts older than MaxAgeDays for deletion' {
        $artifacts = @(
            (New-TestArtifact -Name 'old'   -Size 1000 -Created $script:Now.AddDays(-40) -WorkflowRunId 'A'),
            (New-TestArtifact -Name 'fresh' -Size 1000 -Created $script:Now.AddDays(-5)  -WorkflowRunId 'B')
        )
        $policy = @{ MaxAgeDays = 30 }
        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy $policy -Now $script:Now
        $plan.ToDelete.Name | Should -Be 'old'
        $plan.ToKeep.Name   | Should -Be 'fresh'
    }

    It 'keeps everything when no policy provided' {
        $artifacts = @(
            (New-TestArtifact -Name 'a' -Size 10 -Created $script:Now.AddDays(-100) -WorkflowRunId 'X')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{} -Now $script:Now
        $plan.ToDelete.Count | Should -Be 0
        $plan.ToKeep.Count   | Should -Be 1
    }
}

Describe 'Get-CleanupPlan — max total size policy' {
    It 'deletes oldest until total size is under MaxTotalSizeBytes' {
        $artifacts = @(
            (New-TestArtifact -Name 'a' -Size 500 -Created $script:Now.AddDays(-3) -WorkflowRunId 'W'),
            (New-TestArtifact -Name 'b' -Size 500 -Created $script:Now.AddDays(-2) -WorkflowRunId 'W'),
            (New-TestArtifact -Name 'c' -Size 500 -Created $script:Now.AddDays(-1) -WorkflowRunId 'W')
        )
        $policy = @{ MaxTotalSizeBytes = 1000 }
        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy $policy -Now $script:Now
        $plan.ToDelete.Name | Should -Be 'a'
        ($plan.ToKeep.Name | Sort-Object) | Should -Be @('b','c')
    }
}

Describe 'Get-CleanupPlan — keep-latest-N per workflow' {
    It 'keeps only the N newest artifacts per workflow id' {
        $artifacts = @(
            (New-TestArtifact -Name 'w1-old'    -Size 10 -Created $script:Now.AddDays(-5) -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w1-mid'    -Size 10 -Created $script:Now.AddDays(-3) -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w1-newest' -Size 10 -Created $script:Now.AddDays(-1) -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w2-only'   -Size 10 -Created $script:Now.AddDays(-2) -WorkflowRunId 'W2')
        )
        $policy = @{ KeepLatestPerWorkflow = 2 }
        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy $policy -Now $script:Now
        $plan.ToDelete.Name | Should -Be 'w1-old'
        ($plan.ToKeep.Name | Sort-Object) | Should -Be @('w1-mid','w1-newest','w2-only')
    }
}

Describe 'Get-CleanupPlan — combined policies' {
    It 'applies age, per-workflow, then size in order and produces a summary' {
        $artifacts = @(
            (New-TestArtifact -Name 'ancient'  -Size 200 -Created $script:Now.AddDays(-60) -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w1-a'     -Size 200 -Created $script:Now.AddDays(-10) -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w1-b'     -Size 200 -Created $script:Now.AddDays(-5)  -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w1-c'     -Size 200 -Created $script:Now.AddDays(-1)  -WorkflowRunId 'W1'),
            (New-TestArtifact -Name 'w2-a'     -Size 200 -Created $script:Now.AddDays(-2)  -WorkflowRunId 'W2')
        )
        $policy = @{
            MaxAgeDays            = 30
            KeepLatestPerWorkflow = 2
            MaxTotalSizeBytes     = 400
        }
        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy $policy -Now $script:Now

        # 'ancient' removed by age; 'w1-a' removed by keep-latest-2 of W1;
        # remaining {w1-b, w1-c, w2-a}=600 > 400 so oldest 'w2-a' (or 'w1-b') goes next.
        # Sorting by date ascending for size trimming: w1-b(-5) < w2-a(-2) < w1-c(-1)
        # so 'w1-b' is deleted to bring size to 400.
        $plan.ToDelete.Name | Sort-Object | Should -Be @('ancient','w1-a','w1-b')
        $plan.Summary.TotalReclaimed | Should -Be 600
        $plan.Summary.DeletedCount   | Should -Be 3
        $plan.Summary.RetainedCount  | Should -Be 2
    }
}

Describe 'Invoke-ArtifactCleanup — dry run' {
    It 'does not call the delete action under -DryRun' {
        $artifacts = @(
            (New-TestArtifact -Name 'old' -Size 100 -Created $script:Now.AddDays(-40) -WorkflowRunId 'W')
        )
        $script:deletedNames = @()
        $deleter = { param($a) $script:deletedNames += $a.Name }
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy @{ MaxAgeDays = 30 } `
            -Now $script:Now -DeleteAction $deleter -DryRun
        $script:deletedNames.Count | Should -Be 0
        $result.Summary.DeletedCount | Should -Be 1
        $result.DryRun | Should -Be $true
    }

    It 'invokes DeleteAction for each artifact when not a dry run' {
        $artifacts = @(
            (New-TestArtifact -Name 'a' -Size 100 -Created $script:Now.AddDays(-40) -WorkflowRunId 'W'),
            (New-TestArtifact -Name 'b' -Size 100 -Created $script:Now.AddDays(-40) -WorkflowRunId 'W')
        )
        $script:deletedNames = @()
        $deleter = { param($a) $script:deletedNames += $a.Name }
        Invoke-ArtifactCleanup -Artifacts $artifacts -Policy @{ MaxAgeDays = 30 } `
            -Now $script:Now -DeleteAction $deleter | Out-Null
        ($script:deletedNames | Sort-Object) | Should -Be @('a','b')
    }

    It 'continues and reports errors if a delete action throws' {
        $artifacts = @(
            (New-TestArtifact -Name 'good' -Size 1 -Created $script:Now.AddDays(-40) -WorkflowRunId 'W'),
            (New-TestArtifact -Name 'bad'  -Size 1 -Created $script:Now.AddDays(-40) -WorkflowRunId 'W')
        )
        $deleter = { param($a) if ($a.Name -eq 'bad') { throw "boom" } }
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy @{ MaxAgeDays = 30 } `
            -Now $script:Now -DeleteAction $deleter
        $result.Summary.FailedCount | Should -Be 1
        $result.Errors[0].Name | Should -Be 'bad'
    }
}

Describe 'Invoke-ArtifactCleanup — input validation' {
    It 'throws when Artifacts is null' {
        { Invoke-ArtifactCleanup -Artifacts $null -Policy @{} } | Should -Throw
    }
    It 'throws when MaxAgeDays is negative' {
        { Get-CleanupPlan -Artifacts @() -Policy @{ MaxAgeDays = -1 } -Now $script:Now } |
            Should -Throw
    }
}

Describe 'Format-CleanupReport' {
    It 'renders a human readable summary block' {
        $plan = @{
            ToDelete = @(
                [pscustomobject]@{ Name='old'; Size=1000; Created=$script:Now.AddDays(-40); WorkflowRunId='W' }
            )
            ToKeep   = @()
            Summary  = @{
                DeletedCount   = 1
                RetainedCount  = 0
                FailedCount    = 0
                TotalReclaimed = 1000
            }
            DryRun   = $true
        }
        $text = Format-CleanupReport -Plan $plan
        $text | Should -Match 'DRY RUN'
        $text | Should -Match 'Deleted:\s*1'
        $text | Should -Match 'Reclaimed:\s*1000'
        $text | Should -Match 'old'
    }
}
