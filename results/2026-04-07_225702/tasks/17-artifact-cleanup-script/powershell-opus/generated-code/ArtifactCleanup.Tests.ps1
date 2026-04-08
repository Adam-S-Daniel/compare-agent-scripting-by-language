# Pester tests for the Artifact Cleanup module.
# We follow red/green TDD: each Describe block was written as a failing test first,
# then the implementation was added to make it pass.

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    # --- Test fixtures ---
    # Shared mock data factory — placed in BeforeAll so it's available in all test scopes.
    function Get-TestArtifacts {
        <#
        .SYNOPSIS
            Returns a standard set of mock artifacts for testing retention policies.
            6 artifacts across 3 workflows, with various ages and sizes.
        #>
        $now = [datetime]::new(2026, 4, 8, 12, 0, 0)
        @(
            # Workflow 100 — two recent builds
            [PSCustomObject]@{ Name = "build-output";  SizeMB = 500;  CreatedDate = $now.AddDays(-1);  WorkflowRunId = 100 }
            [PSCustomObject]@{ Name = "build-output";  SizeMB = 480;  CreatedDate = $now.AddDays(-3);  WorkflowRunId = 100 }
            # Workflow 200 — one recent, one old
            [PSCustomObject]@{ Name = "test-results";  SizeMB = 50;   CreatedDate = $now.AddDays(-2);  WorkflowRunId = 200 }
            [PSCustomObject]@{ Name = "test-results";  SizeMB = 45;   CreatedDate = $now.AddDays(-40); WorkflowRunId = 200 }
            # Workflow 300 — all old
            [PSCustomObject]@{ Name = "coverage-report"; SizeMB = 200; CreatedDate = $now.AddDays(-60); WorkflowRunId = 300 }
            [PSCustomObject]@{ Name = "coverage-report"; SizeMB = 180; CreatedDate = $now.AddDays(-90); WorkflowRunId = 300 }
        )
    }
}

# ============================================================
# 1. Test: New-RetentionPolicy creates a valid policy object
# ============================================================
Describe "New-RetentionPolicy" {
    It "creates a policy with default values" {
        $policy = New-RetentionPolicy
        $policy | Should -Not -BeNullOrEmpty
        $policy.MaxAgeDays       | Should -Be 30
        $policy.MaxTotalSizeMB   | Should -Be $null
        $policy.KeepLatestN      | Should -Be 1
    }

    It "accepts custom values" {
        $policy = New-RetentionPolicy -MaxAgeDays 7 -MaxTotalSizeMB 1000 -KeepLatestN 3
        $policy.MaxAgeDays       | Should -Be 7
        $policy.MaxTotalSizeMB   | Should -Be 1000
        $policy.KeepLatestN      | Should -Be 3
    }

    It "rejects negative MaxAgeDays" {
        { New-RetentionPolicy -MaxAgeDays -1 } | Should -Throw "*must be a positive*"
    }

    It "rejects negative KeepLatestN" {
        { New-RetentionPolicy -KeepLatestN -2 } | Should -Throw "*must be a non-negative*"
    }
}

# ============================================================
# 2. Test: Get-DeletionPlan — max-age policy
# ============================================================
Describe "Get-DeletionPlan — MaxAge policy" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "marks artifacts older than MaxAgeDays for deletion" {
        $artifacts = Get-TestArtifacts
        # 30-day max age, keep 1 per workflow
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # Workflow 200: the 40-day-old artifact should be deleted
        # Workflow 300: both are >30 days, but keep-latest-1 protects the 60-day-old one
        #   so only the 90-day-old one is deleted by age policy (the 60-day-old is kept)
        # Workflow 100: both are <30 days, but keep-latest-1 means the 3-day-old is a candidate
        #   yet it's not older than 30 days so it stays (size policy not active)
        $deleted = $plan.ToDelete
        $deletedNames = $deleted | ForEach-Object { "$($_.WorkflowRunId):$($_.Name):$([int]($now - $_.CreatedDate).TotalDays)d" }

        # The 40-day-old test-results (wf 200) should be deleted
        $deleted | Where-Object { $_.WorkflowRunId -eq 200 -and ($now - $_.CreatedDate).TotalDays -gt 30 } |
            Should -Not -BeNullOrEmpty

        # The 90-day-old coverage-report (wf 300) should be deleted
        $deleted | Where-Object { $_.WorkflowRunId -eq 300 -and ($now - $_.CreatedDate).TotalDays -gt 60 } |
            Should -Not -BeNullOrEmpty
    }

    It "always keeps at least KeepLatestN per workflow even if old" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # Workflow 300: the newest (60-day-old) is kept despite being over MaxAge
        $retained300 = $plan.ToRetain | Where-Object { $_.WorkflowRunId -eq 300 }
        $retained300 | Should -Not -BeNullOrEmpty
        $retained300.Count | Should -Be 1
    }

    It "keeps everything when KeepLatestN is high enough" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 10
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # All artifacts retained (2 per workflow, KeepLatestN=10 protects them all)
        $plan.ToRetain.Count | Should -Be 6
        $plan.ToDelete.Count | Should -Be 0
    }
}

# ============================================================
# 3. Test: Get-DeletionPlan — max total size policy
# ============================================================
Describe "Get-DeletionPlan — MaxTotalSize policy" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "trims oldest artifacts when total size exceeds budget" {
        $artifacts = Get-TestArtifacts
        # Total size: 500+480+50+45+200+180 = 1455 MB. Budget: 1000 MB.
        # Protected (KeepLatestN=1): 500+50+200 = 750 MB. Unprotected: 480+45+180 = 705 MB.
        # Must delete unprotected until total ≤ 1000.
        $policy = New-RetentionPolicy -MaxAgeDays 365 -MaxTotalSizeMB 1000 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        $retainedSize = ($plan.ToRetain | Measure-Object -Property SizeMB -Sum).Sum
        $retainedSize | Should -BeLessOrEqual 1000
        # At least some artifacts should be deleted
        $plan.ToDelete.Count | Should -BeGreaterThan 0
    }

    It "deletes oldest-first to meet size budget" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 365 -MaxTotalSizeMB 1000 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # The oldest unprotected artifact (90-day coverage, 180MB) should be deleted first
        $plan.ToDelete | Where-Object { $_.WorkflowRunId -eq 300 -and $_.SizeMB -eq 180 } |
            Should -Not -BeNullOrEmpty
    }

    It "respects KeepLatestN even when over budget" {
        $artifacts = Get-TestArtifacts
        # Budget is tiny — can only keep 50 MB, but keep-latest-1 per workflow
        $policy = New-RetentionPolicy -MaxAgeDays 365 -MaxTotalSizeMB 50 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # Each workflow's newest artifact must survive (3 workflows => 3 retained minimum)
        foreach ($wfId in @(100, 200, 300)) {
            $plan.ToRetain | Where-Object { $_.WorkflowRunId -eq $wfId } |
                Should -Not -BeNullOrEmpty -Because "workflow $wfId must keep at least 1"
        }
    }
}

# ============================================================
# 4. Test: Get-DeletionPlan — summary fields
# ============================================================
Describe "Get-DeletionPlan — Summary" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "calculates total space reclaimed" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        $plan.Summary | Should -Not -BeNullOrEmpty
        $plan.Summary.SpaceReclaimedMB | Should -BeGreaterThan 0
        $deletedSize = ($plan.ToDelete | Measure-Object -Property SizeMB -Sum).Sum
        $plan.Summary.SpaceReclaimedMB | Should -Be $deletedSize
    }

    It "counts retained and deleted artifacts" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        $plan.Summary.RetainedCount | Should -Be $plan.ToRetain.Count
        $plan.Summary.DeletedCount  | Should -Be $plan.ToDelete.Count
        ($plan.Summary.RetainedCount + $plan.Summary.DeletedCount) | Should -Be $artifacts.Count
    }

    It "includes total retained size" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        $retainedSize = ($plan.ToRetain | Measure-Object -Property SizeMB -Sum).Sum
        $plan.Summary.RetainedSizeMB | Should -Be $retainedSize
    }
}

# ============================================================
# 5. Test: Invoke-ArtifactCleanup — dry-run mode
# ============================================================
Describe "Invoke-ArtifactCleanup — DryRun" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "returns a plan without executing deletions in dry-run mode" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy `
            -DryRun -ReferenceDate $now

        $result | Should -Not -BeNullOrEmpty
        $result.DryRun | Should -Be $true
        $result.Plan.ToDelete.Count | Should -BeGreaterThan 0
        # No actual deletion callback should have been invoked
        $result.DeletedArtifacts | Should -BeNullOrEmpty
    }

    It "invokes the delete callback when not in dry-run mode" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        # Track which artifacts the callback receives
        $deletedLog = [System.Collections.Generic.List[object]]::new()
        $callback = { param($artifact) $deletedLog.Add($artifact) }

        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy `
            -DeleteAction $callback -ReferenceDate $now

        $result.DryRun | Should -Be $false
        $result.DeletedArtifacts.Count | Should -Be $result.Plan.ToDelete.Count
        $deletedLog.Count | Should -Be $result.Plan.ToDelete.Count
    }
}

# ============================================================
# 6. Test: Format-DeletionReport — human-readable output
# ============================================================
Describe "Format-DeletionReport" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "produces a readable summary string" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        $report = Format-DeletionReport -Plan $plan -DryRun
        $report | Should -Not -BeNullOrEmpty
        # Should contain key phrases
        $report | Should -Match "DRY RUN"
        $report | Should -Match "DELETE"
        $report | Should -Match "RETAIN"
        $report | Should -Match "reclaimed"
    }

    It "omits DRY RUN label when not in dry-run" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        $report = Format-DeletionReport -Plan $plan
        $report | Should -Not -Match "DRY RUN"
    }
}

# ============================================================
# 7. Edge cases
# ============================================================
Describe "Edge cases" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "handles empty artifact list" {
        $policy = New-RetentionPolicy -MaxAgeDays 30
        $plan = Get-DeletionPlan -Artifacts @() -Policy $policy -ReferenceDate $now

        $plan.ToRetain.Count | Should -Be 0
        $plan.ToDelete.Count | Should -Be 0
        $plan.Summary.SpaceReclaimedMB | Should -Be 0
    }

    It "handles a single artifact" {
        $single = @(
            [PSCustomObject]@{ Name = "lone-artifact"; SizeMB = 100; CreatedDate = $now.AddDays(-5); WorkflowRunId = 999 }
        )
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $single -Policy $policy -ReferenceDate $now

        # Single artifact is protected by KeepLatestN
        $plan.ToRetain.Count | Should -Be 1
        $plan.ToDelete.Count | Should -Be 0
    }

    It "handles KeepLatestN of 0 with age policy" {
        $artifacts = Get-TestArtifacts
        # KeepLatestN=0 means no protection — pure age-based cleanup
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 0
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # Both workflow-300 artifacts (60d and 90d) should be deleted since neither is protected
        $deleted300 = $plan.ToDelete | Where-Object { $_.WorkflowRunId -eq 300 }
        $deleted300.Count | Should -Be 2
    }

    It "handles all artifacts being within retention" {
        $fresh = @(
            [PSCustomObject]@{ Name = "a"; SizeMB = 10; CreatedDate = $now.AddHours(-1); WorkflowRunId = 1 }
            [PSCustomObject]@{ Name = "b"; SizeMB = 20; CreatedDate = $now.AddHours(-2); WorkflowRunId = 2 }
        )
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $fresh -Policy $policy -ReferenceDate $now

        $plan.ToRetain.Count | Should -Be 2
        $plan.ToDelete.Count | Should -Be 0
    }

    It "combined age + size policies work together" {
        $artifacts = Get-TestArtifacts
        # Age removes the >30-day artifacts, then size trims further
        $policy = New-RetentionPolicy -MaxAgeDays 30 -MaxTotalSizeMB 800 -KeepLatestN 1
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy $policy -ReferenceDate $now

        # Age deletes: 40-day test-results (45MB), 90-day coverage (180MB)
        # After age: retained = 500+480+50+200 = 1230 MB, over 800 budget
        # Size trims: unprotected oldest first — 480MB (3-day build, unprotected)
        # After size: retained = 500+50+200 = 750 ≤ 800
        $retainedSize = ($plan.ToRetain | Measure-Object -Property SizeMB -Sum).Sum
        $retainedSize | Should -BeLessOrEqual 800
        $plan.ToDelete.Count | Should -BeGreaterOrEqual 3
    }
}

# ============================================================
# 8. Test: Error handling in Invoke-ArtifactCleanup
# ============================================================
Describe "Invoke-ArtifactCleanup — error handling" {
    BeforeAll {
        $script:now = [datetime]::new(2026, 4, 8, 12, 0, 0)
    }

    It "continues deleting remaining artifacts when one fails" {
        $artifacts = Get-TestArtifacts
        $policy = New-RetentionPolicy -MaxAgeDays 30 -KeepLatestN 1
        $callCount = 0
        # Callback that fails on the first call but succeeds on subsequent ones
        $flakyCallback = {
            param($artifact)
            $script:callCount++
            if ($script:callCount -eq 1) { throw "Simulated API failure" }
        }

        # Should emit a non-terminating error for the failed artifact but not abort
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts -Policy $policy `
            -DeleteAction $flakyCallback -ReferenceDate $now -ErrorAction SilentlyContinue

        # The first artifact fails, the rest succeed
        $result.DeletedArtifacts.Count | Should -Be ($result.Plan.ToDelete.Count - 1)
    }
}
