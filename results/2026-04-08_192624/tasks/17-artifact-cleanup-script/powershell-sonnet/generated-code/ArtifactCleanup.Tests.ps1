#Requires -Modules Pester
# ArtifactCleanup.Tests.ps1
# TDD test suite for artifact cleanup script
# Tests are written first (red), then minimum code is added to make them pass (green)

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/ArtifactCleanup.ps1"
}

Describe "New-ArtifactRecord" {
    # RED: Write failing test for artifact data model creation
    It "creates an artifact record with required fields" {
        $artifact = New-ArtifactRecord -Name "build-output" -SizeBytes 1048576 -CreatedAt ([datetime]"2026-01-01") -WorkflowRunId "run-001"

        $artifact.Name        | Should -Be "build-output"
        $artifact.SizeBytes   | Should -Be 1048576
        $artifact.CreatedAt   | Should -Be ([datetime]"2026-01-01")
        $artifact.WorkflowRunId | Should -Be "run-001"
    }

    It "returns a PSCustomObject" {
        $artifact = New-ArtifactRecord -Name "logs" -SizeBytes 512 -CreatedAt ([datetime]"2026-03-01") -WorkflowRunId "run-002"
        $artifact | Should -BeOfType [PSCustomObject]
    }
}

Describe "Get-ArtifactsExceedingMaxAge" {
    BeforeAll {
        $ReferenceDate = [datetime]"2026-04-09"

        $script:Artifacts = @(
            New-ArtifactRecord -Name "old-artifact"    -SizeBytes 100 -CreatedAt ([datetime]"2026-01-01") -WorkflowRunId "run-001"
            New-ArtifactRecord -Name "recent-artifact" -SizeBytes 200 -CreatedAt ([datetime]"2026-04-01") -WorkflowRunId "run-002"
            New-ArtifactRecord -Name "boundary"        -SizeBytes 300 -CreatedAt ([datetime]"2026-02-07") -WorkflowRunId "run-003"
        )
    }

    # RED: artifact older than max-age should be flagged for deletion
    It "flags artifacts older than MaxAgeDays" {
        $result = Get-ArtifactsExceedingMaxAge -Artifacts $script:Artifacts -MaxAgeDays 60 -ReferenceDate $ReferenceDate
        $result | Should -HaveCount 2
        $result.Name | Should -Contain "old-artifact"
        $result.Name | Should -Contain "boundary"
    }

    It "keeps artifacts within MaxAgeDays" {
        $result = Get-ArtifactsExceedingMaxAge -Artifacts $script:Artifacts -MaxAgeDays 60 -ReferenceDate $ReferenceDate
        $result.Name | Should -Not -Contain "recent-artifact"
    }

    It "returns empty array when no artifacts exceed max age" {
        $result = Get-ArtifactsExceedingMaxAge -Artifacts $script:Artifacts -MaxAgeDays 365 -ReferenceDate $ReferenceDate
        $result | Should -HaveCount 0
    }
}

Describe "Get-ArtifactsExceedingTotalSize" {
    BeforeAll {
        # Artifacts sorted newest-first: keep newest until budget exceeded
        $script:SizedArtifacts = @(
            New-ArtifactRecord -Name "artifact-a" -SizeBytes (100MB) -CreatedAt ([datetime]"2026-04-08") -WorkflowRunId "run-001"
            New-ArtifactRecord -Name "artifact-b" -SizeBytes (200MB) -CreatedAt ([datetime]"2026-04-07") -WorkflowRunId "run-001"
            New-ArtifactRecord -Name "artifact-c" -SizeBytes (300MB) -CreatedAt ([datetime]"2026-04-06") -WorkflowRunId "run-002"
        )
    }

    # RED: when total size exceeds budget, oldest artifacts should be flagged
    It "flags oldest artifacts when total size exceeds MaxTotalSizeBytes" {
        # Budget = 250MB; keep newest (a=100MB, b=200MB fits 300MB budget? No — 100+200=300>250)
        # Keep artifact-a (100MB), artifact-b would push to 300MB > 250MB → delete b and c
        $result = Get-ArtifactsExceedingTotalSize -Artifacts $script:SizedArtifacts -MaxTotalSizeBytes (250MB)
        $result | Should -HaveCount 2
        $result.Name | Should -Contain "artifact-b"
        $result.Name | Should -Contain "artifact-c"
    }

    It "returns empty when total size is within budget" {
        $result = Get-ArtifactsExceedingTotalSize -Artifacts $script:SizedArtifacts -MaxTotalSizeBytes (700MB)
        $result | Should -HaveCount 0
    }

    It "flags all artifacts if budget is zero" {
        $result = Get-ArtifactsExceedingTotalSize -Artifacts $script:SizedArtifacts -MaxTotalSizeBytes 0
        $result | Should -HaveCount 3
    }
}

Describe "Get-ArtifactsExceedingKeepLatestN" {
    BeforeAll {
        # Multiple artifacts per workflow run — keep only N latest per workflow
        $script:WorkflowArtifacts = @(
            New-ArtifactRecord -Name "wf1-run3" -SizeBytes 100 -CreatedAt ([datetime]"2026-04-08") -WorkflowRunId "workflow-1"
            New-ArtifactRecord -Name "wf1-run2" -SizeBytes 100 -CreatedAt ([datetime]"2026-04-07") -WorkflowRunId "workflow-1"
            New-ArtifactRecord -Name "wf1-run1" -SizeBytes 100 -CreatedAt ([datetime]"2026-04-06") -WorkflowRunId "workflow-1"
            New-ArtifactRecord -Name "wf2-run2" -SizeBytes 100 -CreatedAt ([datetime]"2026-04-08") -WorkflowRunId "workflow-2"
            New-ArtifactRecord -Name "wf2-run1" -SizeBytes 100 -CreatedAt ([datetime]"2026-04-07") -WorkflowRunId "workflow-2"
        )
    }

    # RED: only keep latest N per workflow, delete older ones
    It "flags artifacts beyond KeepLatestN per workflow" {
        $result = Get-ArtifactsExceedingKeepLatestN -Artifacts $script:WorkflowArtifacts -KeepLatestN 2
        $result | Should -HaveCount 1
        $result.Name | Should -Contain "wf1-run1"
    }

    It "keeps all when KeepLatestN is greater than count" {
        $result = Get-ArtifactsExceedingKeepLatestN -Artifacts $script:WorkflowArtifacts -KeepLatestN 10
        $result | Should -HaveCount 0
    }

    It "flags all but latest one per workflow when KeepLatestN is 1" {
        $result = Get-ArtifactsExceedingKeepLatestN -Artifacts $script:WorkflowArtifacts -KeepLatestN 1
        $result | Should -HaveCount 3
        $result.Name | Should -Contain "wf1-run2"
        $result.Name | Should -Contain "wf1-run1"
        $result.Name | Should -Contain "wf2-run1"
    }
}

Describe "Invoke-ArtifactCleanup" {
    BeforeAll {
        $ReferenceDate = [datetime]"2026-04-09"

        # Mixed fixture: some old, some large, some exceeding per-workflow limit
        $script:MixedArtifacts = @(
            New-ArtifactRecord -Name "ancient"    -SizeBytes (50MB)  -CreatedAt ([datetime]"2025-12-01") -WorkflowRunId "workflow-a"
            New-ArtifactRecord -Name "wfa-run2"   -SizeBytes (80MB)  -CreatedAt ([datetime]"2026-04-01") -WorkflowRunId "workflow-a"
            New-ArtifactRecord -Name "wfa-run1"   -SizeBytes (80MB)  -CreatedAt ([datetime]"2026-03-25") -WorkflowRunId "workflow-a"
            New-ArtifactRecord -Name "wfa-run0"   -SizeBytes (80MB)  -CreatedAt ([datetime]"2026-03-20") -WorkflowRunId "workflow-a"
            New-ArtifactRecord -Name "fresh"      -SizeBytes (100MB) -CreatedAt ([datetime]"2026-04-08") -WorkflowRunId "workflow-b"
        )

        $script:Policy = @{
            MaxAgeDays        = 90       # "ancient" is 129 days old → delete
            MaxTotalSizeBytes = 400MB    # total = 390MB → within budget
            KeepLatestN       = 2        # workflow-a has 3 non-ancient runs → delete oldest (wfa-run0)
        }
    }

    # RED: combined policy should produce correct deletion plan
    It "returns a deletion plan with ToDelete and ToRetain" {
        $plan = Invoke-ArtifactCleanup -Artifacts $script:MixedArtifacts -Policy $script:Policy -ReferenceDate $ReferenceDate -DryRun $true
        $plan | Should -Not -BeNullOrEmpty
        $plan.ToDelete | Should -Not -BeNullOrEmpty
        $plan.ToRetain | Should -Not -BeNullOrEmpty
    }

    It "correctly identifies artifacts to delete based on combined policies" {
        $plan = Invoke-ArtifactCleanup -Artifacts $script:MixedArtifacts -Policy $script:Policy -ReferenceDate $ReferenceDate -DryRun $true
        # "ancient" → max age violation; "wfa-run0" → keep-latest-N violation
        $plan.ToDelete.Name | Should -Contain "ancient"
        $plan.ToDelete.Name | Should -Contain "wfa-run0"
    }

    It "retains artifacts that satisfy all policies" {
        $plan = Invoke-ArtifactCleanup -Artifacts $script:MixedArtifacts -Policy $script:Policy -ReferenceDate $ReferenceDate -DryRun $true
        $plan.ToRetain.Name | Should -Contain "fresh"
        $plan.ToRetain.Name | Should -Contain "wfa-run2"
    }

    It "includes summary with space reclaimed and counts" {
        $plan = Invoke-ArtifactCleanup -Artifacts $script:MixedArtifacts -Policy $script:Policy -ReferenceDate $ReferenceDate -DryRun $true
        $plan.Summary | Should -Not -BeNullOrEmpty
        $plan.Summary.SpaceReclaimedBytes | Should -BeGreaterThan 0
        $plan.Summary.ArtifactsDeleted  | Should -BeGreaterThan 0
        $plan.Summary.ArtifactsRetained | Should -BeGreaterThan 0
    }

    It "in dry-run mode, plan has DryRun flag set true" {
        $plan = Invoke-ArtifactCleanup -Artifacts $script:MixedArtifacts -Policy $script:Policy -ReferenceDate $ReferenceDate -DryRun $true
        $plan.DryRun | Should -BeTrue
    }

    It "in non-dry-run mode, plan has DryRun flag set false" {
        $plan = Invoke-ArtifactCleanup -Artifacts $script:MixedArtifacts -Policy $script:Policy -ReferenceDate $ReferenceDate -DryRun $false
        $plan.DryRun | Should -BeFalse
    }
}

Describe "Format-CleanupReport" {
    BeforeAll {
        $script:SamplePlan = [PSCustomObject]@{
            DryRun   = $true
            ToDelete = @(
                New-ArtifactRecord -Name "old-thing" -SizeBytes (50MB) -CreatedAt ([datetime]"2026-01-01") -WorkflowRunId "wf-1"
            )
            ToRetain = @(
                New-ArtifactRecord -Name "new-thing" -SizeBytes (100MB) -CreatedAt ([datetime]"2026-04-08") -WorkflowRunId "wf-2"
            )
            Summary  = [PSCustomObject]@{
                SpaceReclaimedBytes = 50MB
                ArtifactsDeleted   = 1
                ArtifactsRetained  = 1
            }
        }
    }

    # RED: report should be human-readable string
    It "produces a non-empty string report" {
        $report = Format-CleanupReport -Plan $script:SamplePlan
        $report | Should -Not -BeNullOrEmpty
        $report | Should -BeOfType [string]
    }

    It "report includes DRY RUN label when DryRun is true" {
        $report = Format-CleanupReport -Plan $script:SamplePlan
        $report | Should -Match "DRY RUN"
    }

    It "report includes artifact name to delete" {
        $report = Format-CleanupReport -Plan $script:SamplePlan
        $report | Should -Match "old-thing"
    }

    It "report includes space reclaimed in human-readable form" {
        $report = Format-CleanupReport -Plan $script:SamplePlan
        $report | Should -Match "50"   # 50 MB
    }

    It "report includes retained count" {
        $report = Format-CleanupReport -Plan $script:SamplePlan
        $report | Should -Match "1"
    }
}
