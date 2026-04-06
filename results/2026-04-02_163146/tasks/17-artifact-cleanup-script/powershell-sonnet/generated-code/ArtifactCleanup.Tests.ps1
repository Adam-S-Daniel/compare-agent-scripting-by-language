# ArtifactCleanup.Tests.ps1
# Pester tests for the artifact cleanup script.
# TDD approach: tests are written first, then implementation code is added
# to make each test pass.

BeforeAll {
    # Dot-source the implementation file so its functions are available in tests
    . "$PSScriptRoot/ArtifactCleanup.ps1"
}

# ===========================================================================
# FIXTURE HELPERS
# ===========================================================================
# Helper: build an artifact hashtable for test clarity
function New-TestArtifact {
    param(
        [string]$Name,
        [long]$SizeBytes,
        [datetime]$CreatedAt,
        [string]$WorkflowRunId
    )
    return @{
        Name          = $Name
        SizeBytes     = $SizeBytes
        CreatedAt     = $CreatedAt
        WorkflowRunId = $WorkflowRunId
    }
}

# ===========================================================================
# CYCLE 1 — Mock data / fixture loading
# ===========================================================================
Describe "Get-MockArtifacts" {
    It "returns a non-empty list of artifacts" {
        $artifacts = Get-MockArtifacts
        $artifacts | Should -Not -BeNullOrEmpty
    }

    It "each artifact has required fields: Name, SizeBytes, CreatedAt, WorkflowRunId" {
        $artifacts = Get-MockArtifacts
        foreach ($a in $artifacts) {
            $a.Name          | Should -Not -BeNullOrEmpty
            $a.SizeBytes     | Should -BeGreaterThan 0
            $a.CreatedAt     | Should -BeOfType [datetime]
            $a.WorkflowRunId | Should -Not -BeNullOrEmpty
        }
    }
}

# ===========================================================================
# CYCLE 2 — Max-age policy
# ===========================================================================
Describe "Invoke-MaxAgePolicy" {
    BeforeEach {
        # Use a fixed reference time so tests are deterministic — no wall-clock drift
        $script:refTime = [datetime]::new(2026, 1, 15, 12, 0, 0, [System.DateTimeKind]::Utc)

        $script:artifacts = @(
            New-TestArtifact -Name "old-artifact"    -SizeBytes 100MB -CreatedAt $script:refTime.AddDays(-40) -WorkflowRunId "run-1"
            New-TestArtifact -Name "recent-artifact" -SizeBytes  50MB -CreatedAt $script:refTime.AddDays(-5)  -WorkflowRunId "run-2"
            # Exactly at the boundary: created exactly 30 days before refTime.
            # The rule is strict greater-than (age > MaxAgeDays), so this is NOT deleted.
            New-TestArtifact -Name "border-artifact" -SizeBytes  20MB -CreatedAt $script:refTime.AddDays(-30) -WorkflowRunId "run-3"
        )
    }

    It "marks artifacts older than MaxAgeDays for deletion" {
        # MaxAgeDays = 30 → anything created more than 30 days ago should be deleted
        $result = Invoke-MaxAgePolicy -Artifacts $script:artifacts -MaxAgeDays 30 -ReferenceTime $script:refTime
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        $toDelete.Name | Should -Contain "old-artifact"
    }

    It "does not mark artifacts within MaxAgeDays for deletion" {
        $result = Invoke-MaxAgePolicy -Artifacts $script:artifacts -MaxAgeDays 30 -ReferenceTime $script:refTime
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        $toDelete.Name | Should -Not -Contain "recent-artifact"
    }

    It "artifact exactly at boundary (created exactly MaxAgeDays ago) is NOT marked for deletion" {
        # boundary: age == MaxAgeDays is kept (strict greater-than rule)
        $result = Invoke-MaxAgePolicy -Artifacts $script:artifacts -MaxAgeDays 30 -ReferenceTime $script:refTime
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        $toDelete.Name | Should -Not -Contain "border-artifact"
    }

    It "returns all artifacts with a MarkedForDeletion property" {
        $result = Invoke-MaxAgePolicy -Artifacts $script:artifacts -MaxAgeDays 30 -ReferenceTime $script:refTime
        $result.Count | Should -Be $script:artifacts.Count
        foreach ($r in $result) {
            $r.PSObject.Properties.Name | Should -Contain "MarkedForDeletion"
        }
    }
}

# ===========================================================================
# CYCLE 3 — Max total-size policy
# ===========================================================================
Describe "Invoke-MaxSizePolicy" {
    BeforeEach {
        $now = [datetime]::UtcNow

        # 5 artifacts ordered newest → oldest (so oldest are candidates for deletion)
        $script:artifacts = @(
            New-TestArtifact -Name "newest" -SizeBytes 200MB -CreatedAt $now.AddDays(-1)  -WorkflowRunId "run-1"
            New-TestArtifact -Name "newer"  -SizeBytes 150MB -CreatedAt $now.AddDays(-3)  -WorkflowRunId "run-2"
            New-TestArtifact -Name "mid"    -SizeBytes 100MB -CreatedAt $now.AddDays(-7)  -WorkflowRunId "run-3"
            New-TestArtifact -Name "older"  -SizeBytes  80MB -CreatedAt $now.AddDays(-14) -WorkflowRunId "run-4"
            New-TestArtifact -Name "oldest" -SizeBytes  50MB -CreatedAt $now.AddDays(-21) -WorkflowRunId "run-5"
        )
        # Total = 580 MB
    }

    It "marks oldest artifacts for deletion until total size is within limit" {
        # Limit = 400 MB → must delete 180 MB worth (oldest first: 50 MB + 80 MB = 130 MB still over,
        # then 100 MB more = 230 MB deleted, total 350 MB ≤ 400 MB)
        $result = Invoke-MaxSizePolicy -Artifacts $script:artifacts -MaxTotalSizeBytes (400MB)
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        $toDelete.Name | Should -Contain "oldest"
        $toDelete.Name | Should -Contain "older"
        $toDelete.Name | Should -Contain "mid"
    }

    It "does not mark artifacts for deletion when total size is within limit" {
        $result = Invoke-MaxSizePolicy -Artifacts $script:artifacts -MaxTotalSizeBytes (1GB)
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        $toDelete | Should -BeNullOrEmpty
    }

    It "respects already-marked artifacts (does not double-count their size)" {
        # Pre-mark the newest artifact as already being deleted (e.g. from age policy)
        $script:artifacts[0].MarkedForDeletion = $true

        # With 200 MB already marked, remaining = 380 MB which is under 400 MB limit
        $result = Invoke-MaxSizePolicy -Artifacts $script:artifacts -MaxTotalSizeBytes (400MB)
        $newlyMarked = $result | Where-Object { $_.MarkedForDeletion -eq $true -and $_.Name -ne "newest" }
        $newlyMarked | Should -BeNullOrEmpty
    }
}

# ===========================================================================
# CYCLE 4 — Keep-latest-N per workflow policy
# ===========================================================================
Describe "Invoke-KeepLatestNPolicy" {
    BeforeEach {
        $now = [datetime]::UtcNow

        # workflow "build" has 4 runs; "deploy" has 2 runs
        $script:artifacts = @(
            New-TestArtifact -Name "build-v4" -SizeBytes 10MB -CreatedAt $now.AddDays(-1)  -WorkflowRunId "build"
            New-TestArtifact -Name "build-v3" -SizeBytes 10MB -CreatedAt $now.AddDays(-3)  -WorkflowRunId "build"
            New-TestArtifact -Name "build-v2" -SizeBytes 10MB -CreatedAt $now.AddDays(-7)  -WorkflowRunId "build"
            New-TestArtifact -Name "build-v1" -SizeBytes 10MB -CreatedAt $now.AddDays(-14) -WorkflowRunId "build"
            New-TestArtifact -Name "deploy-v2" -SizeBytes 5MB -CreatedAt $now.AddDays(-2)  -WorkflowRunId "deploy"
            New-TestArtifact -Name "deploy-v1" -SizeBytes 5MB -CreatedAt $now.AddDays(-10) -WorkflowRunId "deploy"
        )
    }

    It "marks excess artifacts for deletion, keeping only the N latest per workflow" {
        $result = Invoke-KeepLatestNPolicy -Artifacts $script:artifacts -KeepLatestN 2
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        # build has 4 → delete 2 oldest: build-v1 and build-v2
        $toDelete.Name | Should -Contain "build-v1"
        $toDelete.Name | Should -Contain "build-v2"
    }

    It "does not mark artifacts when workflow has N or fewer runs" {
        $result = Invoke-KeepLatestNPolicy -Artifacts $script:artifacts -KeepLatestN 2
        $toDelete = $result | Where-Object { $_.MarkedForDeletion -eq $true }
        # deploy has exactly 2 → nothing deleted
        $toDelete.Name | Should -Not -Contain "deploy-v1"
        $toDelete.Name | Should -Not -Contain "deploy-v2"
    }

    It "keeps the N most-recent artifacts per workflow" {
        $result = Invoke-KeepLatestNPolicy -Artifacts $script:artifacts -KeepLatestN 2
        $kept = $result | Where-Object { $_.MarkedForDeletion -ne $true -and $_.WorkflowRunId -eq "build" }
        $kept.Name | Should -Contain "build-v4"
        $kept.Name | Should -Contain "build-v3"
    }
}

# ===========================================================================
# CYCLE 5 — Combined policy application (Invoke-RetentionPolicies)
# ===========================================================================
Describe "Invoke-RetentionPolicies" {
    BeforeEach {
        $script:refTime = [datetime]::new(2026, 1, 15, 12, 0, 0, [System.DateTimeKind]::Utc)

        $script:artifacts = @(
            New-TestArtifact -Name "a-new-small"   -SizeBytes  10MB -CreatedAt $script:refTime.AddDays(-2)  -WorkflowRunId "wf-a"
            New-TestArtifact -Name "a-old-small"   -SizeBytes  10MB -CreatedAt $script:refTime.AddDays(-40) -WorkflowRunId "wf-a"
            New-TestArtifact -Name "a-old-small-2" -SizeBytes  10MB -CreatedAt $script:refTime.AddDays(-35) -WorkflowRunId "wf-a"
            New-TestArtifact -Name "b-new-large"   -SizeBytes 300MB -CreatedAt $script:refTime.AddDays(-5)  -WorkflowRunId "wf-b"
            New-TestArtifact -Name "b-new-medium"  -SizeBytes 200MB -CreatedAt $script:refTime.AddDays(-8)  -WorkflowRunId "wf-b"
        )

        $script:policy = @{
            MaxAgeDays        = 30
            MaxTotalSizeBytes = 400MB
            KeepLatestN       = 1
        }
    }

    It "applies all three policies and returns deletion decisions for all artifacts" {
        $result = Invoke-RetentionPolicies -Artifacts $script:artifacts -Policy $script:policy -ReferenceTime $script:refTime
        $result.Count | Should -Be $script:artifacts.Count
    }

    It "marks a-old-small for deletion (age policy)" {
        $result = Invoke-RetentionPolicies -Artifacts $script:artifacts -Policy $script:policy -ReferenceTime $script:refTime
        ($result | Where-Object { $_.Name -eq "a-old-small" }).MarkedForDeletion | Should -Be $true
    }

    It "marks excess wf-a artifacts for deletion (keep-latest-N policy)" {
        $result = Invoke-RetentionPolicies -Artifacts $script:artifacts -Policy $script:policy -ReferenceTime $script:refTime
        # wf-a has 3 artifacts, keep 1 → 2 deleted (oldest); a-old-small already age-deleted
        $deleted = $result | Where-Object { $_.MarkedForDeletion -eq $true -and $_.WorkflowRunId -eq "wf-a" }
        $deleted.Count | Should -BeGreaterOrEqual 2
    }
}

# ===========================================================================
# CYCLE 6 — Deletion plan / summary generation
# ===========================================================================
Describe "New-DeletionPlan" {
    BeforeEach {
        $now = [datetime]::UtcNow

        $script:artifacts = @(
            New-TestArtifact -Name "keep-me"   -SizeBytes 100MB -CreatedAt $now.AddDays(-1) -WorkflowRunId "run-1"
            New-TestArtifact -Name "delete-me" -SizeBytes 200MB -CreatedAt $now.AddDays(-5) -WorkflowRunId "run-2"
        )
        $script:artifacts[0].MarkedForDeletion = $false
        $script:artifacts[0] | Add-Member -NotePropertyName DeletionReasons -NotePropertyValue @() -Force
        $script:artifacts[1].MarkedForDeletion = $true
        $script:artifacts[1] | Add-Member -NotePropertyName DeletionReasons -NotePropertyValue @("MaxAge") -Force
    }

    It "returns a plan object with ArtifactsToDelete, ArtifactsToRetain, SpaceReclaimedBytes, and Summary" {
        $plan = New-DeletionPlan -Artifacts $script:artifacts
        $plan.PSObject.Properties.Name | Should -Contain "ArtifactsToDelete"
        $plan.PSObject.Properties.Name | Should -Contain "ArtifactsToRetain"
        $plan.PSObject.Properties.Name | Should -Contain "SpaceReclaimedBytes"
        $plan.PSObject.Properties.Name | Should -Contain "Summary"
    }

    It "correctly separates artifacts to delete vs retain" {
        $plan = New-DeletionPlan -Artifacts $script:artifacts
        $plan.ArtifactsToDelete.Count | Should -Be 1
        $plan.ArtifactsToRetain.Count | Should -Be 1
        $plan.ArtifactsToDelete[0].Name | Should -Be "delete-me"
        $plan.ArtifactsToRetain[0].Name  | Should -Be "keep-me"
    }

    It "computes SpaceReclaimedBytes as the sum of deleted artifact sizes" {
        $plan = New-DeletionPlan -Artifacts $script:artifacts
        $plan.SpaceReclaimedBytes | Should -Be (200MB)
    }

    It "summary contains human-readable counts and reclaimed space" {
        $plan = New-DeletionPlan -Artifacts $script:artifacts
        $plan.Summary | Should -Match "1"      # artifact counts
        $plan.Summary | Should -Match "200"    # some numeric indicator of MB
    }
}

# ===========================================================================
# CYCLE 7 — Dry-run mode (Invoke-ArtifactCleanup)
# ===========================================================================
Describe "Invoke-ArtifactCleanup" {
    BeforeEach {
        $script:refTime = [datetime]::new(2026, 1, 15, 12, 0, 0, [System.DateTimeKind]::Utc)

        $script:artifacts = @(
            New-TestArtifact -Name "keep-fresh" -SizeBytes  50MB -CreatedAt $script:refTime.AddDays(-2)  -WorkflowRunId "wf-1"
            New-TestArtifact -Name "delete-old" -SizeBytes 100MB -CreatedAt $script:refTime.AddDays(-45) -WorkflowRunId "wf-1"
        )

        $script:policy = @{
            MaxAgeDays        = 30
            MaxTotalSizeBytes = 10GB   # large enough not to trigger
            KeepLatestN       = 10     # large enough not to trigger
        }
    }

    It "returns a deletion plan in dry-run mode" {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts -Policy $script:policy -DryRun $true -ReferenceTime $script:refTime
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "ArtifactsToDelete"
    }

    It "does not invoke any real deletion in dry-run mode (IsDryRun flag is set)" {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts -Policy $script:policy -DryRun $true -ReferenceTime $script:refTime
        $result.IsDryRun | Should -Be $true
    }

    It "identifies the old artifact as marked for deletion" {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts -Policy $script:policy -DryRun $true -ReferenceTime $script:refTime
        $result.ArtifactsToDelete.Name | Should -Contain "delete-old"
    }

    It "identifies the fresh artifact as retained" {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts -Policy $script:policy -DryRun $true -ReferenceTime $script:refTime
        $result.ArtifactsToRetain.Name | Should -Contain "keep-fresh"
    }

    It "non-dry-run mode also returns a plan" {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts -Policy $script:policy -DryRun $false -ReferenceTime $script:refTime
        $result | Should -Not -BeNullOrEmpty
        $result.IsDryRun | Should -Be $false
    }

    It "throws a meaningful error when Policy is missing required keys" {
        $badPolicy = @{ MaxAgeDays = 30 }  # missing MaxTotalSizeBytes and KeepLatestN
        { Invoke-ArtifactCleanup -Artifacts $script:artifacts -Policy $badPolicy -DryRun $true -ReferenceTime $script:refTime } | Should -Throw
    }
}
