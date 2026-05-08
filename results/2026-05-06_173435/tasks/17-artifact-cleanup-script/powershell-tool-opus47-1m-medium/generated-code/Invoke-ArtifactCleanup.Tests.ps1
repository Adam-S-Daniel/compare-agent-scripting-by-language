# Pester tests for Invoke-ArtifactCleanup. Built TDD-style: each Context here was
# a failing test before its corresponding code branch existed in the script.

BeforeAll {
    . "$PSScriptRoot/Invoke-ArtifactCleanup.ps1"

    # Fixed reference time so age calculations are deterministic across runs.
    $script:Now = [datetime]'2026-05-07T12:00:00Z'

    function New-Artifact {
        param($Name, $Size, $AgeDays, $WorkflowRunId)
        [pscustomobject]@{
            Name          = $Name
            Size          = [long]$Size
            CreatedAt     = $script:Now.AddDays(-$AgeDays)
            WorkflowRunId = $WorkflowRunId
        }
    }
}

Describe 'Get-ArtifactCleanupPlan' {

    Context 'empty input' {
        It 'returns an empty plan with zero counts' {
            $plan = Get-ArtifactCleanupPlan -Artifacts @() -Now $script:Now
            $plan.Summary.DeletedCount   | Should -Be 0
            $plan.Summary.RetainedCount  | Should -Be 0
            $plan.Summary.SpaceReclaimed | Should -Be 0
        }
    }

    Context 'MaxAgeDays policy' {
        It 'deletes artifacts older than the cutoff and keeps newer ones' {
            $artifacts = @(
                (New-Artifact 'old'   100 40 'wf1'),
                (New-Artifact 'fresh' 200  5 'wf1')
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:Now
            $plan.Summary.DeletedCount   | Should -Be 1
            $plan.Summary.RetainedCount  | Should -Be 1
            $plan.Summary.SpaceReclaimed | Should -Be 100
            $plan.ToDelete[0].Name       | Should -Be 'old'
            $plan.ToDelete[0].Reason     | Should -Match 'older than'
        }
    }

    Context 'KeepLatestNPerWorkflow policy' {
        It 'keeps the newest N artifacts per workflow run id' {
            $artifacts = @(
                (New-Artifact 'a' 10 1 'wfA'),
                (New-Artifact 'b' 10 2 'wfA'),
                (New-Artifact 'c' 10 3 'wfA'),  # should be deleted (3rd-oldest in wfA)
                (New-Artifact 'd' 10 4 'wfA'),  # should be deleted
                (New-Artifact 'e' 10 1 'wfB')
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -KeepLatestNPerWorkflow 2 -Now $script:Now
            $plan.Summary.DeletedCount  | Should -Be 2
            ($plan.ToDelete.Name | Sort-Object) -join ',' | Should -Be 'c,d'
        }
    }

    Context 'MaxTotalSize policy' {
        It 'deletes oldest survivors until total <= cap' {
            $artifacts = @(
                (New-Artifact 'oldbig'    500 10 'wf1'),
                (New-Artifact 'midsmall'  100  5 'wf1'),
                (New-Artifact 'newbig'    500  1 'wf1')
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxTotalSize 600 -Now $script:Now
            # Oldest 'oldbig' (500) is dropped; retained = 100 + 500 = 600 <= cap.
            $plan.Summary.DeletedCount   | Should -Be 1
            $plan.ToDelete[0].Name       | Should -Be 'oldbig'
            $plan.Summary.SpaceReclaimed | Should -Be 500
        }
    }

    Context 'combined policies' {
        It 'applies age, then per-workflow keep-N, then size cap' {
            $artifacts = @(
                (New-Artifact 'ancient'  50 100 'wf1'),  # killed by age
                (New-Artifact 'wf1-1'   200   1 'wf1'),
                (New-Artifact 'wf1-2'   200   2 'wf1'),
                (New-Artifact 'wf1-3'   200   3 'wf1'),  # killed by keep-2
                (New-Artifact 'wf2-1'   400   1 'wf2'),
                (New-Artifact 'wf2-2'   100   2 'wf2')
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts `
                -MaxAgeDays 30 -KeepLatestNPerWorkflow 2 -MaxTotalSize 600 -Now $script:Now
            # After age + keep-2: survivors = wf1-1(200), wf1-2(200), wf2-1(400), wf2-2(100) = 900.
            # Cap 600 -> drop oldest survivors: wf1-2 (2d, 200) -> 700; wf2-2 (2d, 100) -> 600. Done.
            $plan.Summary.DeletedCount  | Should -Be 4
            ($plan.ToDelete.Name | Sort-Object) -join ',' | Should -Be 'ancient,wf1-2,wf1-3,wf2-2'
        }
    }

    Context 'DryRun flag' {
        It 'sets Summary.DryRun to true' {
            $plan = Get-ArtifactCleanupPlan -Artifacts @() -Now $script:Now -DryRun
            $plan.Summary.DryRun | Should -BeTrue
        }
    }

    Context 'input validation' {
        It 'throws on negative size' {
            $bad = [pscustomobject]@{
                Name = 'x'; Size = -1; CreatedAt = $script:Now; WorkflowRunId = 'wf'
            }
            { Get-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:Now } | Should -Throw '*negative*'
        }
        It 'throws when a required property is missing' {
            $bad = [pscustomobject]@{ Name = 'x'; Size = 1; CreatedAt = $script:Now }
            { Get-ArtifactCleanupPlan -Artifacts @($bad) -Now $script:Now } | Should -Throw '*WorkflowRunId*'
        }
    }
}

Describe 'Format-CleanupPlan' {
    It 'renders a human-readable summary block' {
        $artifacts = @( (New-Artifact 'old' 100 40 'wf1') )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $script:Now
        $text = Format-CleanupPlan -Plan $plan
        $text | Should -Match 'DeletedCount:   1'
        $text | Should -Match 'SpaceReclaimed: 100 bytes'
        $text | Should -Match 'DELETE name=old'
    }
}

Describe 'Workflow structure' {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot '.github/workflows/artifact-cleanup-script.yml'
    }
    It 'exists' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }
    It 'references the runner script that exists on disk' {
        $yaml = Get-Content -Raw -Path $script:WorkflowPath
        $yaml | Should -Match 'Run-Cleanup\.ps1'
        Test-Path (Join-Path $PSScriptRoot 'Run-Cleanup.ps1') | Should -BeTrue
    }
    It 'declares the expected triggers and jobs' {
        $yaml = Get-Content -Raw -Path $script:WorkflowPath
        foreach ($needle in 'on:', 'push:', 'pull_request:', 'workflow_dispatch:', 'schedule:', 'jobs:', 'test:', 'cleanup:') {
            $yaml | Should -Match ([regex]::Escape($needle))
        }
    }
    It 'passes actionlint' -Skip:(-not (Get-Command actionlint -ErrorAction SilentlyContinue)) {
        $out = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }
}

Describe 'Invoke-FromCli (JSON fixture entry point)' {
    It 'parses a JSON fixture and produces the same plan as direct calls' {
        $tempFixture = Join-Path ([System.IO.Path]::GetTempPath()) "fixture-$([guid]::NewGuid()).json"
        try {
            $data = @(
                @{ Name='a'; Size=100; CreatedAt='2026-03-01T00:00:00Z'; WorkflowRunId='wf1' },
                @{ Name='b'; Size=200; CreatedAt='2026-05-01T00:00:00Z'; WorkflowRunId='wf1' }
            )
            $data | ConvertTo-Json | Set-Content -Path $tempFixture -Encoding utf8
            $plan = Invoke-FromCli -FixturePath $tempFixture -MaxAgeDays 30 -Now $script:Now
            $plan.Summary.DeletedCount | Should -Be 1
            $plan.ToDelete[0].Name     | Should -Be 'a'
        }
        finally {
            Remove-Item $tempFixture -ErrorAction SilentlyContinue
        }
    }
}
