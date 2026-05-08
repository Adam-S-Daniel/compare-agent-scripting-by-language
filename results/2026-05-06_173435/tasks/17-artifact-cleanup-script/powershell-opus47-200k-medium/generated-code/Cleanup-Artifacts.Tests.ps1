#requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    . $PSScriptRoot/Cleanup-Artifacts.ps1
    $script:Now = [datetime]'2026-05-08T12:00:00Z'

    function New-Artifact {
        param($Name, $SizeBytes, $AgeDays, $WorkflowRunId)
        [pscustomobject]@{
            Name          = $Name
            SizeBytes     = [long]$SizeBytes
            CreatedAt     = $script:Now.AddDays(-$AgeDays)
            WorkflowRunId = $WorkflowRunId
        }
    }
}

Describe 'Get-ArtifactDeletionPlan' {

    It 'returns empty plan when no policies and no artifacts' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -Now $script:Now
        $plan.DeletedCount  | Should -Be 0
        $plan.RetainedCount | Should -Be 0
        $plan.TotalReclaimedBytes | Should -Be 0
    }

    It 'retains everything when no policy is configured' {
        $arts = @(
            (New-Artifact 'a' 100 1 'r1'),
            (New-Artifact 'b' 200 30 'r2')
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -Now $script:Now
        $plan.RetainedCount | Should -Be 2
        $plan.DeletedCount  | Should -Be 0
    }

    It 'deletes artifacts older than MaxAgeDays' {
        $arts = @(
            (New-Artifact 'fresh' 100  1 'r1'),
            (New-Artifact 'old'   200 60 'r2')
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxAgeDays 30 -Now $script:Now
        $plan.DeletedCount  | Should -Be 1
        $plan.Delete[0].Name | Should -Be 'old'
        $plan.TotalReclaimedBytes | Should -Be 200
    }

    It 'keeps latest N per workflow run' {
        $arts = @(
            (New-Artifact 'r1-newest' 10 1 'r1'),
            (New-Artifact 'r1-mid'    10 2 'r1'),
            (New-Artifact 'r1-old'    10 3 'r1'),
            (New-Artifact 'r2-only'   10 5 'r2')
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -KeepLatestPerWorkflow 1 -Now $script:Now
        $plan.DeletedCount | Should -Be 2
        ($plan.Delete.Name | Sort-Object) -join ',' | Should -Be 'r1-mid,r1-old'
        $plan.Retain.Name | Should -Contain 'r1-newest'
        $plan.Retain.Name | Should -Contain 'r2-only'
    }

    It 'evicts oldest first when over MaxTotalSizeBytes' {
        $arts = @(
            (New-Artifact 'oldest' 500 10 'r1'),
            (New-Artifact 'mid'    500  5 'r2'),
            (New-Artifact 'newest' 500  1 'r3')
        )
        # Budget = 1000 -> must drop one (the oldest, 500 bytes)
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxTotalSizeBytes 1000 -Now $script:Now
        $plan.DeletedCount | Should -Be 1
        $plan.Delete[0].Name | Should -Be 'oldest'
        $plan.TotalReclaimedBytes | Should -Be 500
    }

    It 'combines all three policies' {
        $arts = @(
            (New-Artifact 'ancient'   100 365 'r1'),  # killed by age
            (New-Artifact 'r2-new'    300   1 'r2'),
            (New-Artifact 'r2-older'  300   2 'r2'),  # killed by keep-latest-1
            (New-Artifact 'r3-big'    900   3 'r3')
        )
        # After age+keep: survivors r2-new(300) + r3-big(900) = 1200; budget 1000.
        # Drop oldest survivor first -> r3-big(3d old) is older than r2-new(1d).
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts `
            -MaxAgeDays 30 -KeepLatestPerWorkflow 1 -MaxTotalSizeBytes 1000 -Now $script:Now
        $plan.Delete.Name | Should -Contain 'ancient'
        $plan.Delete.Name | Should -Contain 'r2-older'
        $plan.Delete.Name | Should -Contain 'r3-big'
        $plan.RetainedCount | Should -Be 1
        $plan.Retain[0].Name | Should -Be 'r2-new'
        $plan.TotalReclaimedBytes | Should -Be (100 + 300 + 900)
    }

    It 'throws on artifact missing required fields' {
        $bad = @([pscustomobject]@{ Name='x'; SizeBytes=1; CreatedAt=(Get-Date) })  # no WorkflowRunId
        { Get-ArtifactDeletionPlan -Artifacts $bad } | Should -Throw "*WorkflowRunId*"
    }
}

Describe 'Format-CleanupSummary' {
    It 'labels DRY-RUN mode' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -Now $script:Now
        $out = Format-CleanupSummary -Plan $plan -DryRun
        $out | Should -Match 'DRY-RUN'
    }
    It 'labels EXECUTE mode' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -Now $script:Now
        $out = Format-CleanupSummary -Plan $plan
        $out | Should -Match 'EXECUTE'
    }
}

Describe 'Invoke-ArtifactCleanup' {
    BeforeAll {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("artcleanup-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }
    AfterAll {
        if (Test-Path $script:tmp) { Remove-Item -Recurse -Force $script:tmp }
    }

    It 'reads JSON file and computes a plan' {
        $file = Join-Path $script:tmp 'arts.json'
        @(
            @{ Name='a'; SizeBytes=10; CreatedAt='2026-05-07T00:00:00Z'; WorkflowRunId='r1' },
            @{ Name='b'; SizeBytes=20; CreatedAt='2024-01-01T00:00:00Z'; WorkflowRunId='r2' }
        ) | ConvertTo-Json | Set-Content -LiteralPath $file
        $plan = Invoke-ArtifactCleanup -InputPath $file -MaxAgeDays 30 -DryRun 6>$null
        $plan.DeletedCount | Should -Be 1
        $plan.Delete[0].Name | Should -Be 'b'
    }

    It 'throws clear error when input file is missing' {
        { Invoke-ArtifactCleanup -InputPath (Join-Path $script:tmp 'no-such.json') } |
            Should -Throw "*not found*"
    }

    It 'throws clear error on invalid JSON' {
        $file = Join-Path $script:tmp 'bad.json'
        '{ this is not json' | Set-Content -LiteralPath $file
        { Invoke-ArtifactCleanup -InputPath $file } | Should -Throw "*Failed to parse JSON*"
    }
}
