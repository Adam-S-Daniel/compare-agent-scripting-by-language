Describe "Get-DeletionPlan" {
    BeforeAll {
        . $PSScriptRoot/ArtifactCleanup.ps1

        $script:ReferenceDate = [datetime]::Parse("2026-05-07T00:00:00")

        function New-TestArtifact {
            param(
                [string]$Name,
                [long]$Size,
                [string]$CreationDate,
                [string]$WorkflowRunId
            )
            [PSCustomObject]@{
                Name          = $Name
                Size          = $Size
                CreationDate  = $CreationDate
                WorkflowRunId = $WorkflowRunId
            }
        }
    }

    Context "Empty input" {
        It "returns empty plan with summary for no artifacts" {
            $plan = Get-DeletionPlan -Artifacts @() -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 0
            $plan.ToRetain.Count | Should -Be 0
            $plan.SpaceReclaimed | Should -Be 0
            $plan.Summary | Should -Be "No artifacts to process."
        }
    }

    Context "Validation" {
        It "throws on artifact missing required properties" {
            $bad = @([PSCustomObject]@{ Name = "x" })
            { Get-DeletionPlan -Artifacts $bad -ReferenceDate $script:ReferenceDate } |
                Should -Throw "*Invalid artifact*"
        }
    }

    Context "Max age policy" {
        It "deletes artifacts older than MaxAgeDays" {
            $artifacts = @(
                (New-TestArtifact -Name "old" -Size 100 -CreationDate "2026-04-01" -WorkflowRunId "1")
                (New-TestArtifact -Name "recent" -Size 200 -CreationDate "2026-05-05" -WorkflowRunId "1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 7 -ReferenceDate $script:ReferenceDate

            $plan.ToDelete.Count | Should -Be 1
            $plan.ToDelete[0].Name | Should -Be "old"
            $plan.ToRetain.Count | Should -Be 1
            $plan.ToRetain[0].Name | Should -Be "recent"
            $plan.SpaceReclaimed | Should -Be 100
            $plan.SpaceRetained | Should -Be 200
        }

        It "retains all artifacts when none exceed max age" {
            $artifacts = @(
                (New-TestArtifact -Name "a" -Size 50 -CreationDate "2026-05-06" -WorkflowRunId "1")
                (New-TestArtifact -Name "b" -Size 50 -CreationDate "2026-05-05" -WorkflowRunId "2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 0
            $plan.ToRetain.Count | Should -Be 2
        }

        It "deletes all artifacts when all exceed max age" {
            $artifacts = @(
                (New-TestArtifact -Name "a" -Size 100 -CreationDate "2026-03-01" -WorkflowRunId "1")
                (New-TestArtifact -Name "b" -Size 200 -CreationDate "2026-03-15" -WorkflowRunId "2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 5 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 2
            $plan.ToRetain.Count | Should -Be 0
            $plan.SpaceReclaimed | Should -Be 300
        }
    }

    Context "Keep-latest-N per workflow" {
        It "keeps only N most recent artifacts per workflow run ID" {
            $artifacts = @(
                (New-TestArtifact -Name "w1-old" -Size 100 -CreationDate "2026-05-01" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "w1-mid" -Size 100 -CreationDate "2026-05-03" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "w1-new" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "w2-only" -Size 100 -CreationDate "2026-05-02" -WorkflowRunId "wf2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -KeepLatestN 1 -ReferenceDate $script:ReferenceDate

            $plan.ToDelete.Count | Should -Be 2
            $deletedNames = $plan.ToDelete | ForEach-Object { $_.Name } | Sort-Object
            $deletedNames | Should -Be @("w1-mid", "w1-old")
            $plan.ToRetain.Count | Should -Be 2
            $retainedNames = $plan.ToRetain | ForEach-Object { $_.Name } | Sort-Object
            $retainedNames | Should -Be @("w1-new", "w2-only")
        }

        It "keeps 2 per workflow when KeepLatestN=2" {
            $artifacts = @(
                (New-TestArtifact -Name "a1" -Size 10 -CreationDate "2026-05-01" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "a2" -Size 20 -CreationDate "2026-05-03" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "a3" -Size 30 -CreationDate "2026-05-05" -WorkflowRunId "wf1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -KeepLatestN 2 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 1
            $plan.ToDelete[0].Name | Should -Be "a1"
            $plan.SpaceReclaimed | Should -Be 10
        }
    }

    Context "Max total size policy" {
        It "deletes oldest retained artifacts to fit under max total size" {
            $artifacts = @(
                (New-TestArtifact -Name "oldest" -Size 500 -CreationDate "2026-05-01" -WorkflowRunId "1")
                (New-TestArtifact -Name "middle" -Size 300 -CreationDate "2026-05-03" -WorkflowRunId "2")
                (New-TestArtifact -Name "newest" -Size 200 -CreationDate "2026-05-06" -WorkflowRunId "3")
            )
            # Total is 1000. Limit to 500 => must delete oldest first.
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxTotalSizeBytes 500 -ReferenceDate $script:ReferenceDate

            $plan.ToDelete.Count | Should -Be 1
            $plan.ToDelete[0].Name | Should -Be "oldest"
            $plan.SpaceReclaimed | Should -Be 500
            $plan.SpaceRetained | Should -Be 500
        }

        It "deletes multiple oldest until under limit" {
            $artifacts = @(
                (New-TestArtifact -Name "a" -Size 400 -CreationDate "2026-05-01" -WorkflowRunId "1")
                (New-TestArtifact -Name "b" -Size 400 -CreationDate "2026-05-03" -WorkflowRunId "2")
                (New-TestArtifact -Name "c" -Size 400 -CreationDate "2026-05-06" -WorkflowRunId "3")
            )
            # Total 1200, limit 400 => must delete a and b
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxTotalSizeBytes 400 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 2
            $deletedNames = $plan.ToDelete | ForEach-Object { $_.Name } | Sort-Object
            $deletedNames | Should -Be @("a", "b")
            $plan.SpaceReclaimed | Should -Be 800
        }
    }

    Context "Combined policies" {
        It "applies max age and keep-latest-N together" {
            $artifacts = @(
                (New-TestArtifact -Name "old1" -Size 100 -CreationDate "2026-03-01" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "old2" -Size 100 -CreationDate "2026-03-10" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "new1" -Size 100 -CreationDate "2026-05-04" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "new2" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "wf1")
            )
            # MaxAge=10 deletes old1,old2. KeepLatestN=1 also deletes new1.
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 10 -KeepLatestN 1 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 3
            $plan.ToRetain.Count | Should -Be 1
            $plan.ToRetain[0].Name | Should -Be "new2"
            $plan.SpaceReclaimed | Should -Be 300
        }

        It "applies all three policies together" {
            $artifacts = @(
                (New-TestArtifact -Name "ancient" -Size 500 -CreationDate "2026-01-01" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "medium" -Size 300 -CreationDate "2026-05-02" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "recent1" -Size 200 -CreationDate "2026-05-05" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "recent2" -Size 200 -CreationDate "2026-05-06" -WorkflowRunId "wf2")
                (New-TestArtifact -Name "recent3" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "wf2")
            )
            # MaxAge=30 deletes "ancient". KeepLatestN=1 per wf: keeps recent1 for wf1 (deletes medium),
            # keeps recent2 for wf2 (deletes recent3, same date but order matters — recent2 is first at 200).
            # Actually: wf2 has recent2 and recent3 both at 2026-05-06. Sort descending by date:
            # they tie, so order is implementation-dependent. Let's just check counts.
            # MaxTotalSize=250: retained after age+keepN => check what remains and trim if over 250.
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestN 1 -MaxTotalSizeBytes 250 -ReferenceDate $script:ReferenceDate

            # ancient deleted by age. medium deleted by keepN. One of recent3/recent2 deleted by keepN.
            # After age+keepN, retained: recent1(200) + one-of-wf2. If retained total > 250, oldest trimmed.
            $plan.ToDelete.Count | Should -BeGreaterOrEqual 3
            $plan.ToRetain.Count | Should -BeLessOrEqual 2
            ($plan.SpaceReclaimed + $plan.SpaceRetained) | Should -Be 1300
        }
    }

    Context "Dry-run mode" {
        It "sets DryRun flag in plan" {
            $artifacts = @(
                (New-TestArtifact -Name "x" -Size 100 -CreationDate "2026-03-01" -WorkflowRunId "1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 5 -DryRun $true -ReferenceDate $script:ReferenceDate
            $plan.DryRun | Should -Be $true
            $plan.Summary | Should -Match "DRY RUN"
        }

        It "sets live mode label when DryRun is false" {
            $artifacts = @(
                (New-TestArtifact -Name "x" -Size 100 -CreationDate "2026-03-01" -WorkflowRunId "1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 5 -DryRun $false -ReferenceDate $script:ReferenceDate
            $plan.DryRun | Should -Be $false
            $plan.Summary | Should -Match "LIVE"
        }
    }

    Context "Summary output" {
        It "includes correct counts and sizes in summary" {
            $artifacts = @(
                (New-TestArtifact -Name "del" -Size 750 -CreationDate "2026-03-01" -WorkflowRunId "1")
                (New-TestArtifact -Name "keep" -Size 250 -CreationDate "2026-05-06" -WorkflowRunId "2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 10 -DryRun $true -ReferenceDate $script:ReferenceDate

            $plan.Summary | Should -Match "Total artifacts: 2"
            $plan.Summary | Should -Match "Artifacts to delete: 1"
            $plan.Summary | Should -Match "Artifacts to retain: 1"
            $plan.Summary | Should -Match "Space reclaimed: 750 bytes"
            $plan.Summary | Should -Match "Space retained: 250 bytes"
            $plan.Summary | Should -Match "del"
            $plan.Summary | Should -Match "keep"
        }
    }

    Context "No policies applied" {
        It "retains all artifacts when no policies are set" {
            $artifacts = @(
                (New-TestArtifact -Name "a" -Size 100 -CreationDate "2026-05-01" -WorkflowRunId "1")
                (New-TestArtifact -Name "b" -Size 200 -CreationDate "2026-05-03" -WorkflowRunId "2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 0
            $plan.ToRetain.Count | Should -Be 2
            $plan.SpaceReclaimed | Should -Be 0
            $plan.SpaceRetained | Should -Be 300
        }
    }

    Context "CLI integration" {
        It "processes JSON file and produces correct output" {
            $fixtures = @(
                [PSCustomObject]@{ Name = "art1"; Size = 500; CreationDate = "2026-03-01"; WorkflowRunId = "run1" }
                [PSCustomObject]@{ Name = "art2"; Size = 300; CreationDate = "2026-05-06"; WorkflowRunId = "run1" }
            )
            $tmpFile = Join-Path $TestDrive "fixtures.json"
            $fixtures | ConvertTo-Json -Depth 3 | Set-Content $tmpFile

            $output = pwsh -NoProfile -File "$PSScriptRoot/ArtifactCleanup.ps1" `
                -ArtifactFile $tmpFile `
                -MaxAgeDays 10 `
                -DryRun `
                -ReferenceDate "2026-05-07"

            $joined = $output -join "`n"
            $joined | Should -Match "DRY RUN"
            $joined | Should -Match "Artifacts to delete: 1"
            $joined | Should -Match "Artifacts to retain: 1"
            $joined | Should -Match "Space reclaimed: 500 bytes"
        }
    }

    Context "Edge cases" {
        It "handles KeepLatestN=0 deleting all artifacts in each workflow" {
            $artifacts = @(
                (New-TestArtifact -Name "a" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "b" -Size 200 -CreationDate "2026-05-05" -WorkflowRunId "wf2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -KeepLatestN 0 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 2
            $plan.ToRetain.Count | Should -Be 0
            $plan.SpaceReclaimed | Should -Be 300
        }

        It "handles MaxTotalSizeBytes=0 deleting all" {
            $artifacts = @(
                (New-TestArtifact -Name "a" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxTotalSizeBytes 0 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 1
            $plan.SpaceReclaimed | Should -Be 100
        }

        It "handles MaxAgeDays=0 deleting everything not created today" {
            $artifacts = @(
                (New-TestArtifact -Name "today" -Size 100 -CreationDate "2026-05-07" -WorkflowRunId "1")
                (New-TestArtifact -Name "yesterday" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "2")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 0 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 1
            $plan.ToDelete[0].Name | Should -Be "yesterday"
            $plan.ToRetain.Count | Should -Be 1
            $plan.ToRetain[0].Name | Should -Be "today"
        }

        It "correctly reports delete reasons in summary" {
            $artifacts = @(
                (New-TestArtifact -Name "multi-reason" -Size 500 -CreationDate "2026-03-01" -WorkflowRunId "wf1")
                (New-TestArtifact -Name "ok" -Size 100 -CreationDate "2026-05-06" -WorkflowRunId "wf1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -MaxAgeDays 10 -KeepLatestN 1 -ReferenceDate $script:ReferenceDate
            $plan.ToDelete[0].DeleteReason.Count | Should -BeGreaterOrEqual 1
        }

        It "handles single artifact with no policies" {
            $artifacts = @(
                (New-TestArtifact -Name "solo" -Size 999 -CreationDate "2026-05-06" -WorkflowRunId "wf1")
            )
            $plan = Get-DeletionPlan -Artifacts $artifacts -ReferenceDate $script:ReferenceDate
            $plan.ToDelete.Count | Should -Be 0
            $plan.ToRetain.Count | Should -Be 1
            $plan.SpaceRetained | Should -Be 999
        }
    }
}
