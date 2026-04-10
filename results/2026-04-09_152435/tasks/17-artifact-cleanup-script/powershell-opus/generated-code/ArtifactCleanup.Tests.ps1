# ArtifactCleanup.Tests.ps1
# Pester tests for the ArtifactCleanup module.
# TDD approach: each Describe block tests one piece of functionality.

BeforeAll {
    Import-Module "$PSScriptRoot/ArtifactCleanup.psm1" -Force

    # Helper to create mock artifact objects (must be inside BeforeAll for Pester v5 scope)
    function New-MockArtifact {
        param(
            [string]$Name,
            [long]$SizeBytes,
            [datetime]$CreatedDate,
            [string]$WorkflowRunId
        )
        [PSCustomObject]@{
            Name          = $Name
            SizeBytes     = $SizeBytes
            CreatedDate   = $CreatedDate
            WorkflowRunId = $WorkflowRunId
        }
    }
}

Describe "Get-ArtifactDeletionPlan" {

    # Shared reference date for deterministic tests
    BeforeAll {
        $refDate = [datetime]::new(2026, 4, 10)
    }

    Context "with no policies (all zeros)" {
        It "retains all artifacts when no policies are active" {
            $artifacts = @(
                (New-MockArtifact -Name "a1" -SizeBytes 100 -CreatedDate "2026-01-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "a2" -SizeBytes 200 -CreatedDate "2026-02-01" -WorkflowRunId "w2")
            )
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -ReferenceDate $refDate
            $plan.DeleteCount | Should -Be 0
            $plan.RetainCount | Should -Be 2
            $plan.SpaceReclaimed | Should -Be 0
            $plan.SpaceRetained | Should -Be 300
        }
    }

    Context "MaxAgeDays policy" {
        It "deletes artifacts older than MaxAgeDays" {
            $artifacts = @(
                (New-MockArtifact -Name "old" -SizeBytes 500 -CreatedDate "2026-01-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "new" -SizeBytes 300 -CreatedDate "2026-04-05" -WorkflowRunId "w1")
            )
            # MaxAgeDays=30 means cutoff is 2026-03-11 — "old" is before that
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -ReferenceDate $refDate
            $plan.DeleteCount | Should -Be 1
            $plan.RetainCount | Should -Be 1
            $plan.SpaceReclaimed | Should -Be 500
            $plan.ToDelete[0].Name | Should -Be "old"
            $plan.ToDelete[0].Reason | Should -BeLike "*max age*"
        }

        It "retains artifacts within the age limit" {
            $artifacts = @(
                (New-MockArtifact -Name "recent" -SizeBytes 100 -CreatedDate "2026-04-09" -WorkflowRunId "w1")
            )
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 7 -ReferenceDate $refDate
            $plan.DeleteCount | Should -Be 0
            $plan.RetainCount | Should -Be 1
        }
    }

    Context "KeepLatestPerWorkflow policy" {
        It "keeps the N most recent artifacts per workflow and deletes extras" {
            $artifacts = @(
                (New-MockArtifact -Name "w1-oldest" -SizeBytes 100 -CreatedDate "2026-03-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "w1-middle" -SizeBytes 100 -CreatedDate "2026-03-15" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "w1-newest" -SizeBytes 100 -CreatedDate "2026-04-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "w2-only"   -SizeBytes 100 -CreatedDate "2026-03-01" -WorkflowRunId "w2")
            )
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -KeepLatestPerWorkflow 2 -ReferenceDate $refDate
            $plan.DeleteCount | Should -Be 1
            $plan.RetainCount | Should -Be 3
            $plan.ToDelete[0].Name | Should -Be "w1-oldest"
        }

        It "protects latest-N from age-based deletion" {
            # Even if old, the latest per workflow should be retained
            $artifacts = @(
                (New-MockArtifact -Name "only-one" -SizeBytes 100 -CreatedDate "2026-01-01" -WorkflowRunId "w1")
            )
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestPerWorkflow 1 -ReferenceDate $refDate
            # The artifact is old but it's the only one for w1, so KeepLatest protects it
            $plan.RetainCount | Should -Be 1
            $plan.DeleteCount | Should -Be 0
        }
    }

    Context "MaxTotalSizeBytes policy" {
        It "deletes oldest artifacts to fit within size budget" {
            $artifacts = @(
                (New-MockArtifact -Name "oldest" -SizeBytes 400 -CreatedDate "2026-03-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "middle" -SizeBytes 300 -CreatedDate "2026-03-15" -WorkflowRunId "w2"),
                (New-MockArtifact -Name "newest" -SizeBytes 200 -CreatedDate "2026-04-01" -WorkflowRunId "w3")
            )
            # Budget is 500 bytes, total is 900 — oldest (400) gets deleted to reach 500
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxTotalSizeBytes 500 -ReferenceDate $refDate
            $plan.DeleteCount | Should -Be 1
            $plan.RetainCount | Should -Be 2
            $plan.SpaceReclaimed | Should -Be 400
            $plan.ToDelete[0].Name | Should -Be "oldest"
        }
    }

    Context "combined policies" {
        It "applies age + keep-latest + size together" {
            $artifacts = @(
                (New-MockArtifact -Name "a1" -SizeBytes 200 -CreatedDate "2026-01-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "a2" -SizeBytes 200 -CreatedDate "2026-02-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "a3" -SizeBytes 200 -CreatedDate "2026-04-01" -WorkflowRunId "w1"),
                (New-MockArtifact -Name "a4" -SizeBytes 200 -CreatedDate "2026-04-05" -WorkflowRunId "w2"),
                (New-MockArtifact -Name "a5" -SizeBytes 200 -CreatedDate "2026-04-08" -WorkflowRunId "w2")
            )
            # MaxAge=60 deletes a1 (Jan 1 = 99 days old). KeepLatest=1 deletes a2 (extra for w1) and a4 (extra for w2).
            # After that, retained = a3 + a5 = 400 bytes. Budget 500 is fine.
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts `
                -MaxAgeDays 60 -KeepLatestPerWorkflow 1 -MaxTotalSizeBytes 500 `
                -ReferenceDate $refDate
            $plan.DeleteCount | Should -Be 3
            $plan.RetainCount | Should -Be 2
            $plan.SpaceReclaimed | Should -Be 600
            $deletedNames = $plan.ToDelete | ForEach-Object { $_.Name } | Sort-Object
            $deletedNames | Should -Be @("a1", "a2", "a4")
        }
    }

    Context "dry-run mode" {
        It "sets DryRun flag in the plan" {
            $artifacts = @(
                (New-MockArtifact -Name "x" -SizeBytes 100 -CreatedDate "2026-01-01" -WorkflowRunId "w1")
            )
            $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -MaxAgeDays 10 -ReferenceDate $refDate -DryRun
            $plan.DryRun | Should -BeTrue
            $plan.DeleteCount | Should -Be 1
        }
    }

    Context "input validation" {
        It "throws on negative MaxAgeDays" {
            $a = @((New-MockArtifact -Name "x" -SizeBytes 1 -CreatedDate "2026-01-01" -WorkflowRunId "w1"))
            { Get-ArtifactDeletionPlan -Artifacts $a -MaxAgeDays -1 } | Should -Throw "*non-negative*"
        }
        It "throws on negative MaxTotalSizeBytes" {
            $a = @((New-MockArtifact -Name "x" -SizeBytes 1 -CreatedDate "2026-01-01" -WorkflowRunId "w1"))
            { Get-ArtifactDeletionPlan -Artifacts $a -MaxTotalSizeBytes -1 } | Should -Throw "*non-negative*"
        }
    }

    Context "edge cases" {
        It "handles empty artifact list" {
            $plan = Get-ArtifactDeletionPlan -Artifacts @() -ReferenceDate $refDate
            $plan.TotalArtifacts | Should -Be 0
            $plan.DeleteCount | Should -Be 0
            $plan.RetainCount | Should -Be 0
            $plan.SpaceReclaimed | Should -Be 0
        }
    }
}

Describe "Format-DeletionPlan" {
    It "produces DRY RUN header when DryRun is true" {
        $plan = [PSCustomObject]@{
            DryRun         = $true
            TotalArtifacts = 1
            DeleteCount    = 1
            RetainCount    = 0
            SpaceReclaimed = 100
            SpaceRetained  = 0
            ToDelete       = @([PSCustomObject]@{ Name="x"; SizeBytes=100; CreatedDate=[datetime]"2026-01-01"; WorkflowRunId="w1"; Reason="test" })
            ToRetain       = @()
        }
        $output = Format-DeletionPlan -Plan $plan
        $output | Should -BeLike "*DRY RUN*"
        $output | Should -BeLike "*DELETE*x*"
    }

    It "produces LIVE header when DryRun is false" {
        $plan = [PSCustomObject]@{
            DryRun         = $false
            TotalArtifacts = 0
            DeleteCount    = 0
            RetainCount    = 0
            SpaceReclaimed = 0
            SpaceRetained  = 0
            ToDelete       = @()
            ToRetain       = @()
        }
        $output = Format-DeletionPlan -Plan $plan
        $output | Should -BeLike "*LIVE*"
    }
}

Describe "Invoke-ArtifactCleanup" {
    It "loads artifacts from JSON and produces a plan" {
        $jsonPath = Join-Path $TestDrive "artifacts.json"
        $data = @(
            @{ Name = "build-1"; SizeBytes = 500; CreatedDate = "2026-01-15T00:00:00"; WorkflowRunId = "run-100" },
            @{ Name = "build-2"; SizeBytes = 300; CreatedDate = "2026-04-05T00:00:00"; WorkflowRunId = "run-100" }
        )
        $data | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath

        $plan = Invoke-ArtifactCleanup -ArtifactsJsonPath $jsonPath `
            -MaxAgeDays 30 -ReferenceDate ([datetime]"2026-04-10") -DryRun
        $plan.DeleteCount | Should -Be 1
        $plan.RetainCount | Should -Be 1
        $plan.ToDelete[0].Name | Should -Be "build-1"
    }

    It "throws when JSON file does not exist" {
        { Invoke-ArtifactCleanup -ArtifactsJsonPath "/nonexistent/file.json" -DryRun } | Should -Throw "*not found*"
    }
}
