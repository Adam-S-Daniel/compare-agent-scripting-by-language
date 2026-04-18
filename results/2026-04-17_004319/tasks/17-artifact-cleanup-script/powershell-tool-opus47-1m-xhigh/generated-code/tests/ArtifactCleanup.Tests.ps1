# Pester tests for ArtifactCleanup.psm1
# Written red/green TDD-style: each Describe block exercises a single
# function in isolation before the integration tests hit Invoke-ArtifactCleanup.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # A handful of fixture artifacts used across tests.
    $script:RefDate = [DateTime]::Parse('2026-04-17T00:00:00Z').ToUniversalTime()

    function New-Artifact($Id, $Name, $SizeBytes, $CreatedAt, $WorkflowRunId) {
        [pscustomobject]@{
            Id            = $Id
            Name          = $Name
            SizeBytes     = [long]$SizeBytes
            CreatedAt     = [DateTime]::Parse($CreatedAt).ToUniversalTime()
            WorkflowRunId = $WorkflowRunId
        }
    }

    $script:SampleArtifacts = @(
        New-Artifact 1 'build-run100-a'  1000 '2026-01-01T00:00:00Z' 100
        New-Artifact 2 'build-run100-b'  2000 '2026-02-01T00:00:00Z' 100
        New-Artifact 3 'build-run100-c'  3000 '2026-03-01T00:00:00Z' 100
        New-Artifact 4 'build-run101-a'  4000 '2026-04-10T00:00:00Z' 101
        New-Artifact 5 'build-run101-b'  5000 '2026-04-15T00:00:00Z' 101
    )
}

Describe 'Get-ArtifactList' {
    It 'loads a well-formed JSON fixture' {
        $tmp = New-TemporaryFile
        $payload = @{
            artifacts = @(
                @{ id=1; name='x'; sizeBytes=100; createdAt='2026-01-01T00:00:00Z'; workflowRunId=10 }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $tmp -Value $payload
        try {
            $loaded = Get-ArtifactList -Path $tmp
            $loaded.Count | Should -Be 1
            $loaded[0].Name | Should -Be 'x'
            $loaded[0].SizeBytes | Should -Be 100
            $loaded[0].CreatedAt.Kind | Should -Be ([DateTimeKind]::Utc)
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }

    It 'throws a descriptive error when the file is missing' {
        { Get-ArtifactList -Path '/no/such/path-xyz.json' } |
            Should -Throw -ExpectedMessage 'Fixture file not found:*'
    }

    It 'throws when a required field is missing' {
        $tmp = New-TemporaryFile
        '{"artifacts":[{"id":1,"name":"x"}]}' | Set-Content -LiteralPath $tmp
        try {
            { Get-ArtifactList -Path $tmp } |
                Should -Throw -ExpectedMessage "*missing required field*"
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }
}

Describe 'Find-ArtifactsExceedingAge' {
    It 'returns only artifacts older than MaxAgeDays' {
        $picks = Find-ArtifactsExceedingAge -Artifacts $script:SampleArtifacts `
            -MaxAgeDays 30 -ReferenceDate $script:RefDate
        ($picks | ForEach-Object Id) | Sort-Object | Should -Be @(1, 2, 3)
    }

    It 'returns empty when MaxAgeDays is 0 (policy disabled)' {
        $picks = Find-ArtifactsExceedingAge -Artifacts $script:SampleArtifacts `
            -MaxAgeDays 0 -ReferenceDate $script:RefDate
        $picks.Count | Should -Be 0
    }

    It 'is strict at the boundary — exactly N days old is retained' {
        $a = [pscustomobject]@{
            Id=99; Name='edge'; SizeBytes=1
            CreatedAt=$script:RefDate.AddDays(-30)
            WorkflowRunId=1
        }
        $picks = Find-ArtifactsExceedingAge -Artifacts @($a) -MaxAgeDays 30 -ReferenceDate $script:RefDate
        $picks.Count | Should -Be 0
    }
}

Describe 'Find-ArtifactsExceedingTotalSize' {
    It 'deletes oldest first until total size fits the cap' {
        # Total = 15000. Cap = 10000. Expect ids 1 and 2 (1000+2000=3000 removed
        # brings us to 12000, then id 3 removed -> 9000). So 1,2,3 deleted.
        $picks = Find-ArtifactsExceedingTotalSize -Artifacts $script:SampleArtifacts `
            -MaxTotalSizeBytes 10000
        ($picks | ForEach-Object Id) | Should -Be @(1, 2, 3)
    }

    It 'returns empty when total size already fits' {
        $picks = Find-ArtifactsExceedingTotalSize -Artifacts $script:SampleArtifacts `
            -MaxTotalSizeBytes 100000
        $picks.Count | Should -Be 0
    }

    It 'skips artifacts already flagged by another policy' {
        # Pretend 1,2,3 already deleted by age policy. Remaining=4,5 = 9000.
        # Cap = 5000 — should then delete 4 (oldest of the remaining).
        $picks = Find-ArtifactsExceedingTotalSize -Artifacts $script:SampleArtifacts `
            -MaxTotalSizeBytes 5000 -AlreadyDeletedIds @(1,2,3)
        ($picks | ForEach-Object Id) | Should -Be @(4)
    }
}

Describe 'Find-ArtifactsExceedingKeepLatestN' {
    It 'keeps only N newest per workflow run' {
        $picks = Find-ArtifactsExceedingKeepLatestN -Artifacts $script:SampleArtifacts -KeepLatestN 1
        # Per workflow 100: keep 3 (newest), delete 1 and 2.
        # Per workflow 101: keep 5 (newest), delete 4.
        ($picks | ForEach-Object Id) | Sort-Object | Should -Be @(1, 2, 4)
    }

    It 'returns empty when each workflow has <= N artifacts' {
        $picks = Find-ArtifactsExceedingKeepLatestN -Artifacts $script:SampleArtifacts -KeepLatestN 5
        $picks.Count | Should -Be 0
    }
}

Describe 'New-CleanupPlan — integration' {
    It 'produces a plan that unions all policies and computes the summary' {
        $plan = New-CleanupPlan -Artifacts $script:SampleArtifacts `
            -MaxAgeDays 30 `
            -KeepLatestN 1 `
            -MaxTotalSizeBytes 0 `
            -ReferenceDate $script:RefDate

        # MaxAgeDays=30 -> deletes 1,2,3 (reason MaxAgeDays).
        # KeepLatestN=1, run 101 -> deletes 4 (reason KeepLatestN).
        # Net deletes: 1,2,3,4. Keep: 5.
        ($plan.Delete | ForEach-Object Id) | Sort-Object | Should -Be @(1,2,3,4)
        $plan.Keep.Count | Should -Be 1
        $plan.Keep[0].Id | Should -Be 5
        $plan.Summary.DeletedCount | Should -Be 4
        $plan.Summary.RetainedCount | Should -Be 1
        $plan.Summary.ReclaimedBytes | Should -Be 10000  # 1000+2000+3000+4000
        $plan.Summary.RetainedBytes  | Should -Be 5000
        $plan.Summary.Reasons.MaxAgeDays  | Should -Be 3
        # Workflow 100 loses 1,2 to KeepLatestN (plus they're already dead by age)
        # and workflow 101 loses 4 to KeepLatestN -> three 'KeepLatestN' markings.
        $plan.Summary.Reasons.KeepLatestN | Should -Be 3
    }

    It 'records multiple deletion reasons when policies overlap' {
        # Age alone deletes 1,2,3 AND keep-latest-1 also flags 1,2 (run 100).
        $plan = New-CleanupPlan -Artifacts $script:SampleArtifacts `
            -MaxAgeDays 30 -KeepLatestN 1 -ReferenceDate $script:RefDate

        $a1 = $plan.Delete | Where-Object Id -eq 1
        $a1.DeletionReasons | Should -Contain 'MaxAgeDays'
        $a1.DeletionReasons | Should -Contain 'KeepLatestN'
    }

    It 'returns a plan with zero deletions when no policy fires' {
        $plan = New-CleanupPlan -Artifacts $script:SampleArtifacts `
            -MaxAgeDays 0 -MaxTotalSizeBytes 0 -KeepLatestN 0 -ReferenceDate $script:RefDate
        $plan.Summary.DeletedCount | Should -Be 0
        $plan.Summary.RetainedCount | Should -Be 5
        $plan.Summary.ReclaimedBytes | Should -Be 0
    }
}

Describe 'Invoke-ArtifactCleanup' {
    BeforeAll {
        $script:FixturePath = Join-Path $TestDrive 'artifacts.json'
        $fixture = @{
            artifacts = @(
                @{ id=1; name='a'; sizeBytes=1000; createdAt='2026-01-01T00:00:00Z'; workflowRunId=100 }
                @{ id=2; name='b'; sizeBytes=2000; createdAt='2026-04-15T00:00:00Z'; workflowRunId=101 }
            )
        } | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $script:FixturePath -Value $fixture
    }

    It 'returns DryRun=$true and does not populate ExecutedDeletions when -DryRun' {
        $plan = Invoke-ArtifactCleanup -ArtifactsPath $script:FixturePath `
            -MaxAgeDays 30 -DryRun -ReferenceDate $script:RefDate
        $plan.DryRun | Should -BeTrue
        $plan.ExecutedDeletions.Count | Should -Be 0
        $plan.Summary.DeletedCount | Should -Be 1
        $plan.Summary.ReclaimedBytes | Should -Be 1000
    }

    It 'lists the ids in ExecutedDeletions when not a dry-run' {
        $plan = Invoke-ArtifactCleanup -ArtifactsPath $script:FixturePath `
            -MaxAgeDays 30 -ReferenceDate $script:RefDate
        $plan.DryRun | Should -BeFalse
        $plan.ExecutedDeletions | Should -Be @(1)
    }

    It 'throws a friendly error for a missing fixture' {
        { Invoke-ArtifactCleanup -ArtifactsPath '/tmp/does-not-exist-xyz.json' } |
            Should -Throw -ExpectedMessage 'Fixture file not found:*'
    }
}
