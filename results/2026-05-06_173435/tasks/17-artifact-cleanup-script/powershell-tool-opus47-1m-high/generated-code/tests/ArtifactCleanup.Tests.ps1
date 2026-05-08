# Pester tests for ArtifactCleanup.
#
# Approach: red/green TDD. Each Describe block adds one piece of behavior:
#   1. Empty input -> empty plan.
#   2. MaxAgeDays culls old artifacts.
#   3. KeepLatestPerWorkflow keeps only newest N per workflow.
#   4. MaxTotalSizeBytes evicts oldest survivors until under cap.
#   5. Policies combine and reasons are recorded.
#   6. Summary numbers match the plan.
#   7. Dry-run mode produces a plan but performs no destructive callback.
#   8. Invoke-ArtifactCleanup reads JSON, writes a plan file, exits cleanly.
#   9. Error handling: missing input file, malformed JSON.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'ArtifactCleanup.ps1'
    . $script:ScriptPath

    # Pester v5 requires helper functions to be defined inside BeforeAll
    # so they are visible from each It block at run time.
    function New-Artifact {
        param(
            [string] $Name,
            [long]   $SizeBytes,
            [string] $CreatedAt,
            [string] $WorkflowRunId
        )
        [pscustomobject]@{
            Name          = $Name
            SizeBytes     = $SizeBytes
            CreatedAt     = [datetime]::Parse($CreatedAt, [cultureinfo]::InvariantCulture).ToUniversalTime()
            WorkflowRunId = $WorkflowRunId
        }
    }
}

Describe 'Get-CleanupPlan: empty input' {
    It 'returns a plan with no artifacts to delete or retain' {
        $plan = Get-CleanupPlan -Artifacts @() -Now ([datetime]'2026-05-07T00:00:00Z')
        $plan.Delete.Count    | Should -Be 0
        $plan.Retain.Count    | Should -Be 0
        $plan.Summary.DeletedCount         | Should -Be 0
        $plan.Summary.RetainedCount        | Should -Be 0
        $plan.Summary.TotalReclaimedBytes  | Should -Be 0
    }
}

Describe 'Get-CleanupPlan: MaxAgeDays' {
    It 'marks artifacts older than the threshold for deletion and records the reason' {
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old'    -SizeBytes 100 -CreatedAt '2026-04-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'recent' -SizeBytes 200 -CreatedAt '2026-05-06T00:00:00Z' -WorkflowRunId 'A')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 14 -Now $now
        $plan.Delete.Count | Should -Be 1
        $plan.Delete[0].Name | Should -Be 'old'
        $plan.Delete[0].Reasons | Should -Contain 'MaxAgeDays'
        $plan.Retain.Count | Should -Be 1
        $plan.Retain[0].Name | Should -Be 'recent'
    }

    It 'keeps everything when MaxAgeDays is 0 (disabled)' {
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'ancient' -SizeBytes 50 -CreatedAt '2020-01-01T00:00:00Z' -WorkflowRunId 'A')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 0 -Now $now
        $plan.Delete.Count | Should -Be 0
        $plan.Retain.Count | Should -Be 1
    }
}

Describe 'Get-CleanupPlan: KeepLatestPerWorkflow' {
    It 'keeps only the latest N artifacts per workflow run id' {
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'A1' -SizeBytes 100 -CreatedAt '2026-05-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'A2' -SizeBytes 100 -CreatedAt '2026-05-02T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'A3' -SizeBytes 100 -CreatedAt '2026-05-03T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'B1' -SizeBytes 100 -CreatedAt '2026-05-01T00:00:00Z' -WorkflowRunId 'B')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -KeepLatestPerWorkflow 2 -Now $now
        # A1 is the oldest in workflow A; B has only one -> kept.
        $plan.Delete.Count | Should -Be 1
        $plan.Delete[0].Name | Should -Be 'A1'
        $plan.Delete[0].Reasons | Should -Contain 'KeepLatestPerWorkflow'
        ($plan.Retain | ForEach-Object Name) | Should -Contain 'A2'
        ($plan.Retain | ForEach-Object Name) | Should -Contain 'A3'
        ($plan.Retain | ForEach-Object Name) | Should -Contain 'B1'
    }
}

Describe 'Get-CleanupPlan: MaxTotalSizeBytes' {
    It 'evicts oldest first until total retained size is at or below the cap' {
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'oldest'   -SizeBytes 500 -CreatedAt '2026-05-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'middle'   -SizeBytes 500 -CreatedAt '2026-05-02T00:00:00Z' -WorkflowRunId 'B'),
            (New-Artifact -Name 'newest'   -SizeBytes 500 -CreatedAt '2026-05-03T00:00:00Z' -WorkflowRunId 'C')
        )
        # Cap of 1000 bytes: must evict the 500-byte 'oldest'.
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 1000 -Now $now
        $plan.Delete.Count | Should -Be 1
        $plan.Delete[0].Name | Should -Be 'oldest'
        $plan.Delete[0].Reasons | Should -Contain 'MaxTotalSizeBytes'
        ($plan.Retain | Measure-Object -Property SizeBytes -Sum).Sum | Should -Be 1000
    }

    It 'is a no-op when retained total already fits' {
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'a' -SizeBytes 100 -CreatedAt '2026-05-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'b' -SizeBytes 100 -CreatedAt '2026-05-02T00:00:00Z' -WorkflowRunId 'B')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxTotalSizeBytes 1000 -Now $now
        $plan.Delete.Count | Should -Be 0
        $plan.Retain.Count | Should -Be 2
    }
}

Describe 'Get-CleanupPlan: combined policies and summary' {
    It 'applies all three policies and reports a coherent summary' {
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old1'   -SizeBytes 1000 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'A_old'  -SizeBytes  500 -CreatedAt '2026-05-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'A_mid'  -SizeBytes  500 -CreatedAt '2026-05-02T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'A_new'  -SizeBytes  500 -CreatedAt '2026-05-03T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'B_only' -SizeBytes  500 -CreatedAt '2026-05-05T00:00:00Z' -WorkflowRunId 'B')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts `
            -MaxAgeDays 30 `
            -KeepLatestPerWorkflow 2 `
            -MaxTotalSizeBytes 1500 `
            -Now $now
        # old1 is killed by MaxAgeDays. A_old is killed by KeepLatestPerWorkflow=2.
        # Survivors: A_mid (500), A_new (500), B_only (500) = 1500 bytes, fits cap exactly.
        $plan.Delete.Count | Should -Be 2
        $plan.Retain.Count | Should -Be 3
        $plan.Summary.TotalReclaimedBytes | Should -Be 1500
        $plan.Summary.DeletedCount  | Should -Be 2
        $plan.Summary.RetainedCount | Should -Be 3
        ($plan.Delete | Where-Object Name -EQ 'old1').Reasons  | Should -Contain 'MaxAgeDays'
        ($plan.Delete | Where-Object Name -EQ 'A_old').Reasons | Should -Contain 'KeepLatestPerWorkflow'
    }
}

Describe 'Get-CleanupPlan: dry-run vs execution callback' {
    It 'never invokes the delete callback in dry-run mode' {
        $script:invoked = 0
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old' -SizeBytes 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'A')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        Invoke-CleanupPlan -Plan $plan -DryRun -OnDelete { param($a) $script:invoked++ } | Out-Null
        $script:invoked | Should -Be 0
    }

    It 'invokes the delete callback once per artifact when not in dry-run mode' {
        $script:invoked = 0
        $now = [datetime]'2026-05-07T00:00:00Z'
        $artifacts = @(
            (New-Artifact -Name 'old1' -SizeBytes 100 -CreatedAt '2026-01-01T00:00:00Z' -WorkflowRunId 'A'),
            (New-Artifact -Name 'old2' -SizeBytes 100 -CreatedAt '2026-01-02T00:00:00Z' -WorkflowRunId 'B')
        )
        $plan = Get-CleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        Invoke-CleanupPlan -Plan $plan -OnDelete { param($a) $script:invoked++ } | Out-Null
        $script:invoked | Should -Be 2
    }
}

Describe 'Invoke-ArtifactCleanup: end-to-end JSON I/O' {
    BeforeEach {
        $script:tempIn  = [System.IO.Path]::GetTempFileName()
        $script:tempOut = [System.IO.Path]::GetTempFileName()
    }
    AfterEach {
        Remove-Item -Force -ErrorAction SilentlyContinue $script:tempIn, $script:tempOut
    }

    It 'reads artifacts from JSON, writes a plan with summary, and honors dry-run' {
        $input = @(
            @{ Name='old';    SizeBytes=100; CreatedAt='2026-01-01T00:00:00Z'; WorkflowRunId='A' },
            @{ Name='recent'; SizeBytes=200; CreatedAt='2026-05-06T00:00:00Z'; WorkflowRunId='A' }
        )
        ($input | ConvertTo-Json -Depth 5) | Set-Content -Path $script:tempIn -Encoding UTF8
        Invoke-ArtifactCleanup `
            -InputPath  $script:tempIn `
            -OutputPath $script:tempOut `
            -MaxAgeDays 14 `
            -Now ([datetime]'2026-05-07T00:00:00Z') `
            -DryRun | Out-Null
        $plan = Get-Content $script:tempOut -Raw | ConvertFrom-Json
        $plan.Summary.DeletedCount        | Should -Be 1
        $plan.Summary.RetainedCount       | Should -Be 1
        $plan.Summary.TotalReclaimedBytes | Should -Be 100
        $plan.DryRun                      | Should -BeTrue
        $plan.Delete[0].Name              | Should -Be 'old'
    }

    It 'throws a meaningful error when the input file is missing' {
        { Invoke-ArtifactCleanup -InputPath '/nonexistent/path.json' -OutputPath $script:tempOut } |
            Should -Throw '*not found*'
    }

    It 'throws a meaningful error when the input JSON is malformed' {
        Set-Content -Path $script:tempIn -Value 'this is not json {' -Encoding UTF8
        { Invoke-ArtifactCleanup -InputPath $script:tempIn -OutputPath $script:tempOut } |
            Should -Throw '*JSON*'
    }
}
