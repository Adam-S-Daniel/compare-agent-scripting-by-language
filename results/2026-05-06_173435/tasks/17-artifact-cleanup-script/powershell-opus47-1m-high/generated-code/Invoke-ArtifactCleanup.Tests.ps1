# Pester tests for the artifact cleanup script.
# Covers retention policies (max age, max total size, keep-latest-N per
# workflow), dry-run mode, summary generation, and input-validation errors.
#
# Tests are written following red/green TDD: each Describe block was added
# with a failing assertion first, followed by the minimum implementation
# needed to turn it green.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Invoke-ArtifactCleanup.ps1'
    . $script:ScriptPath

    # Reference "now" used by every test. Fixed so test data stays
    # deterministic regardless of when the suite runs.
    $script:Now = [datetime]::Parse('2026-05-07T12:00:00Z').ToUniversalTime()

    function New-TestArtifact {
        param(
            [Parameter(Mandatory)] [string] $Name,
            [Parameter(Mandatory)] [long]   $SizeBytes,
            [Parameter(Mandatory)] [int]    $AgeDays,
            [Parameter(Mandatory)] [string] $WorkflowName,
            [Parameter(Mandatory)] [long]   $WorkflowRunId
        )
        [pscustomobject]@{
            name           = $Name
            size_bytes     = $SizeBytes
            created_at     = $script:Now.AddDays(-$AgeDays).ToString('o')
            workflow_name  = $WorkflowName
            workflow_run_id = $WorkflowRunId
        }
    }
}

Describe 'Get-ArtifactCleanupPlan' {
    Context 'when given an empty artifact list' {
        It 'produces an empty plan with zero reclaimed bytes' {
            $plan = Get-ArtifactCleanupPlan -Artifacts @() -Policy @{} -Now $script:Now
            $plan.ToDelete         | Should -BeNullOrEmpty
            $plan.ToRetain         | Should -BeNullOrEmpty
            $plan.BytesReclaimed   | Should -Be 0
            $plan.TotalArtifacts   | Should -Be 0
        }
    }

    Context 'when no policy applies' {
        It 'retains every artifact' {
            $artifacts = @(
                (New-TestArtifact -Name 'a' -SizeBytes 100 -AgeDays 1 -WorkflowName 'build' -WorkflowRunId 1)
                (New-TestArtifact -Name 'b' -SizeBytes 200 -AgeDays 5 -WorkflowName 'build' -WorkflowRunId 2)
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -Policy @{} -Now $script:Now
            $plan.ToDelete       | Should -BeNullOrEmpty
            $plan.ToRetain.Count | Should -Be 2
            $plan.BytesReclaimed | Should -Be 0
        }
    }

    Context 'with a max-age policy' {
        It 'deletes only artifacts older than the cutoff' {
            $artifacts = @(
                (New-TestArtifact -Name 'fresh'  -SizeBytes 100 -AgeDays 1  -WorkflowName 'w' -WorkflowRunId 1)
                (New-TestArtifact -Name 'edge'   -SizeBytes 200 -AgeDays 30 -WorkflowName 'w' -WorkflowRunId 2)
                (New-TestArtifact -Name 'old'    -SizeBytes 400 -AgeDays 31 -WorkflowName 'w' -WorkflowRunId 3)
                (New-TestArtifact -Name 'older'  -SizeBytes 800 -AgeDays 90 -WorkflowName 'w' -WorkflowRunId 4)
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts `
                -Policy @{ MaxAgeDays = 30 } -Now $script:Now
            ($plan.ToDelete | ForEach-Object name) | Should -Be @('old', 'older')
            $plan.BytesReclaimed | Should -Be 1200
            $plan.ToRetain.Count | Should -Be 2
            ($plan.ToDelete | ForEach-Object reason) | Should -Be @('max-age', 'max-age')
        }
    }

    Context 'with a keep-latest-N-per-workflow policy' {
        It 'keeps only the N newest artifacts of each workflow' {
            $artifacts = @(
                (New-TestArtifact -Name 'b1' -SizeBytes 10 -AgeDays 1 -WorkflowName 'build' -WorkflowRunId 100)
                (New-TestArtifact -Name 'b2' -SizeBytes 20 -AgeDays 2 -WorkflowName 'build' -WorkflowRunId 99)
                (New-TestArtifact -Name 'b3' -SizeBytes 40 -AgeDays 3 -WorkflowName 'build' -WorkflowRunId 98)
                (New-TestArtifact -Name 'b4' -SizeBytes 80 -AgeDays 4 -WorkflowName 'build' -WorkflowRunId 97)
                (New-TestArtifact -Name 't1' -SizeBytes 5  -AgeDays 1 -WorkflowName 'test'  -WorkflowRunId 200)
                (New-TestArtifact -Name 't2' -SizeBytes 7  -AgeDays 2 -WorkflowName 'test'  -WorkflowRunId 199)
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts `
                -Policy @{ KeepLatestNPerWorkflow = 2 } -Now $script:Now
            ($plan.ToRetain | ForEach-Object name | Sort-Object) | Should -Be @('b1', 'b2', 't1', 't2')
            ($plan.ToDelete | ForEach-Object name | Sort-Object) | Should -Be @('b3', 'b4')
            $plan.BytesReclaimed | Should -Be 120
            ($plan.ToDelete | ForEach-Object reason | Select-Object -Unique) | Should -Be 'keep-latest-n'
        }
    }

    Context 'with a max-total-size policy' {
        It 'evicts oldest artifacts until total is within the cap' {
            # Sizes total 1000. Cap to 500. Oldest two (300+250=550) must
            # go, leaving 450 retained.
            $artifacts = @(
                (New-TestArtifact -Name 'newest' -SizeBytes 200 -AgeDays 1 -WorkflowName 'w' -WorkflowRunId 1)
                (New-TestArtifact -Name 'mid'    -SizeBytes 250 -AgeDays 5 -WorkflowName 'w' -WorkflowRunId 2)
                (New-TestArtifact -Name 'older'  -SizeBytes 250 -AgeDays 8 -WorkflowName 'w' -WorkflowRunId 3)
                (New-TestArtifact -Name 'oldest' -SizeBytes 300 -AgeDays 9 -WorkflowName 'w' -WorkflowRunId 4)
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts `
                -Policy @{ MaxTotalSizeBytes = 500 } -Now $script:Now
            ($plan.ToDelete | ForEach-Object name) | Should -Be @('oldest', 'older')
            ($plan.ToRetain | ForEach-Object name) | Should -Be @('newest', 'mid')
            $plan.BytesReclaimed | Should -Be 550
            ($plan.ToDelete | ForEach-Object reason | Select-Object -Unique) | Should -Be 'max-total-size'
        }
    }

    Context 'with combined policies' {
        It 'applies max-age, then keep-latest-N, then max-total-size in order' {
            $artifacts = @(
                # build workflow: 4 artifacts, keep latest 2 -> b3,b4 deletable
                (New-TestArtifact -Name 'b1' -SizeBytes 100 -AgeDays 1  -WorkflowName 'build' -WorkflowRunId 1)
                (New-TestArtifact -Name 'b2' -SizeBytes 100 -AgeDays 2  -WorkflowName 'build' -WorkflowRunId 2)
                (New-TestArtifact -Name 'b3' -SizeBytes 100 -AgeDays 3  -WorkflowName 'build' -WorkflowRunId 3)
                (New-TestArtifact -Name 'b4' -SizeBytes 100 -AgeDays 4  -WorkflowName 'build' -WorkflowRunId 4)
                # too old -> deleted by max-age
                (New-TestArtifact -Name 'x'  -SizeBytes 999 -AgeDays 60 -WorkflowName 'test'  -WorkflowRunId 9)
                # test workflow has 1 artifact at age 60 (above) and one fresh
                (New-TestArtifact -Name 't1' -SizeBytes 50  -AgeDays 1  -WorkflowName 'test'  -WorkflowRunId 10)
            )
            $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -Policy @{
                MaxAgeDays              = 30
                KeepLatestNPerWorkflow  = 2
                MaxTotalSizeBytes       = 200
            } -Now $script:Now

            # Expected: x deleted by max-age. b3,b4 deleted by keep-latest-n.
            # Survivors: b1(100), b2(100), t1(50) = 250 bytes -> exceeds 200,
            # so oldest (b2) goes by max-total-size. Final retained: b1, t1.
            ($plan.ToDelete | ForEach-Object name | Sort-Object) | Should -Be @('b2', 'b3', 'b4', 'x')
            ($plan.ToRetain | ForEach-Object name | Sort-Object) | Should -Be @('b1', 't1')
            $plan.BytesReclaimed | Should -Be 1299
            $reasons = @{}
            foreach ($d in $plan.ToDelete) { $reasons[$d.name] = $d.reason }
            $reasons['x']  | Should -Be 'max-age'
            $reasons['b3'] | Should -Be 'keep-latest-n'
            $reasons['b4'] | Should -Be 'keep-latest-n'
            $reasons['b2'] | Should -Be 'max-total-size'
        }
    }
}

Describe 'Format-ArtifactCleanupSummary' {
    It 'renders counts, reclaimed bytes, and a per-reason breakdown' {
        $artifacts = @(
            (New-TestArtifact -Name 'a' -SizeBytes 1024 -AgeDays 1  -WorkflowName 'w' -WorkflowRunId 1)
            (New-TestArtifact -Name 'b' -SizeBytes 2048 -AgeDays 99 -WorkflowName 'w' -WorkflowRunId 2)
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts `
            -Policy @{ MaxAgeDays = 30 } -Now $script:Now
        $summary = Format-ArtifactCleanupSummary -Plan $plan
        $summary | Should -Match 'Total artifacts: 2'
        $summary | Should -Match 'Retained: 1'
        $summary | Should -Match 'Deleted: 1'
        $summary | Should -Match 'Reclaimed: 2048 bytes'
        $summary | Should -Match 'max-age: 1'
    }

    It 'tags the summary with DRY-RUN when the plan is dry-run' {
        $plan = Get-ArtifactCleanupPlan -Artifacts @() -Policy @{} -Now $script:Now -DryRun
        $summary = Format-ArtifactCleanupSummary -Plan $plan
        $summary | Should -Match 'DRY-RUN'
    }
}

Describe 'Invoke-ArtifactCleanupFromFile' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("acleanup-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null
    }
    AfterAll {
        if (Test-Path $script:TempDir) { Remove-Item -Recurse -Force $script:TempDir }
    }

    It 'reads artifacts + policy JSON and emits a JSON plan' {
        $artifactsPath = Join-Path $script:TempDir 'artifacts.json'
        $policyPath    = Join-Path $script:TempDir 'policy.json'
        @(
            @{ name='old'; size_bytes=500; created_at=$script:Now.AddDays(-40).ToString('o'); workflow_name='w'; workflow_run_id=1 }
            @{ name='new'; size_bytes=100; created_at=$script:Now.AddDays(-1).ToString('o');  workflow_name='w'; workflow_run_id=2 }
        ) | ConvertTo-Json | Set-Content -Path $artifactsPath
        @{ MaxAgeDays = 30; DryRun = $true } | ConvertTo-Json | Set-Content -Path $policyPath

        $result = Invoke-ArtifactCleanupFromFile -ArtifactsPath $artifactsPath -PolicyPath $policyPath -Now $script:Now
        $result.Plan.BytesReclaimed | Should -Be 500
        ($result.Plan.ToDelete | ForEach-Object name) | Should -Be @('old')
        $result.Plan.DryRun     | Should -BeTrue
        $result.Summary         | Should -Match 'DRY-RUN'
    }

    It 'errors with a meaningful message when artifacts file does not exist' {
        { Invoke-ArtifactCleanupFromFile -ArtifactsPath '/no/such/file.json' -PolicyPath '/no/such/policy.json' } |
            Should -Throw -ExpectedMessage '*Artifacts file not found*'
    }

    It 'errors with a meaningful message when artifact JSON is malformed' {
        $bad = Join-Path $script:TempDir 'bad.json'
        Set-Content -Path $bad -Value '{ this is not valid json'
        $policyPath = Join-Path $script:TempDir 'policy.json'
        @{} | ConvertTo-Json | Set-Content -Path $policyPath
        { Invoke-ArtifactCleanupFromFile -ArtifactsPath $bad -PolicyPath $policyPath } |
            Should -Throw -ExpectedMessage '*Failed to parse artifacts JSON*'
    }
}
