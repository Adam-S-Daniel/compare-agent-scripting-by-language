# ArtifactCleanup Pester Tests
# TDD approach: each Describe block represents a TDD cycle.
# Tests were written FIRST (RED), then implementation added to pass (GREEN),
# then refactored as needed.
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module "$PSScriptRoot/ArtifactCleanup.psm1" -Force
}

# ── Helper: build mock artifact lists for reuse across tests ────────────────
function New-TestArtifactSet {
    <#
    .SYNOPSIS
        Creates a standard set of test artifacts for policy testing.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param()

    [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

    [System.Collections.Generic.List[hashtable]]$artifacts = [System.Collections.Generic.List[hashtable]]::new()

    # Artifact 1: recent, workflow A
    $artifacts.Add((New-ArtifactRecord `
        -Name 'build-linux' `
        -SizeBytes 1048576 `
        -CreatedDate $now.AddDays(-1) `
        -WorkflowRunId 'wf-a-100'))

    # Artifact 2: recent, workflow A
    $artifacts.Add((New-ArtifactRecord `
        -Name 'build-linux' `
        -SizeBytes 2097152 `
        -CreatedDate $now.AddDays(-2) `
        -WorkflowRunId 'wf-a-99'))

    # Artifact 3: old, workflow A
    $artifacts.Add((New-ArtifactRecord `
        -Name 'build-linux' `
        -SizeBytes 1048576 `
        -CreatedDate $now.AddDays(-45) `
        -WorkflowRunId 'wf-a-50'))

    # Artifact 4: recent, workflow B
    $artifacts.Add((New-ArtifactRecord `
        -Name 'test-results' `
        -SizeBytes 524288 `
        -CreatedDate $now.AddDays(-3) `
        -WorkflowRunId 'wf-b-200'))

    # Artifact 5: old, workflow B
    $artifacts.Add((New-ArtifactRecord `
        -Name 'test-results' `
        -SizeBytes 524288 `
        -CreatedDate $now.AddDays(-60) `
        -WorkflowRunId 'wf-b-100'))

    # Artifact 6: very old, workflow C
    $artifacts.Add((New-ArtifactRecord `
        -Name 'coverage-report' `
        -SizeBytes 262144 `
        -CreatedDate $now.AddDays(-90) `
        -WorkflowRunId 'wf-c-10'))

    return $artifacts
}

# ── TDD Cycle 1: Artifact record creation ──────────────────────────────────
Describe 'New-ArtifactRecord' {
    It 'creates an artifact with all required metadata fields' {
        [datetime]$created = [datetime]::new(2026, 1, 15, 10, 0, 0)
        $artifact = New-ArtifactRecord `
            -Name 'build-output' `
            -SizeBytes 1048576 `
            -CreatedDate $created `
            -WorkflowRunId 'run-100'

        $artifact.Name          | Should -Be 'build-output'
        $artifact.SizeBytes     | Should -Be 1048576
        $artifact.CreatedDate   | Should -Be $created
        $artifact.WorkflowRunId | Should -Be 'run-100'
    }

    It 'rejects negative size' {
        { New-ArtifactRecord -Name 'bad' -SizeBytes (-1) `
            -CreatedDate ([datetime]::Now) -WorkflowRunId 'run-1' } |
            Should -Throw '*SizeBytes must be non-negative*'
    }

    It 'rejects empty name' {
        { New-ArtifactRecord -Name '' -SizeBytes 100 `
            -CreatedDate ([datetime]::Now) -WorkflowRunId 'run-1' } |
            Should -Throw '*Name must not be empty*'
    }

    It 'rejects empty workflow run ID' {
        { New-ArtifactRecord -Name 'good' -SizeBytes 100 `
            -CreatedDate ([datetime]::Now) -WorkflowRunId '' } |
            Should -Throw '*WorkflowRunId must not be empty*'
    }
}

# ── TDD Cycle 2: Max-age retention policy ──────────────────────────────────
Describe 'Get-ArtifactsExceedingMaxAge' {
    It 'marks artifacts older than max age for deletion' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)
        $artifacts = New-TestArtifactSet

        # Max age = 30 days: artifacts created > 30 days ago should be flagged
        [string[]]$toDelete = Get-ArtifactsExceedingMaxAge `
            -Artifacts $artifacts `
            -MaxAgeDays ([int]30) `
            -ReferenceDate $now

        # Artifacts 3 (45d), 5 (60d), 6 (90d) are older than 30 days
        $toDelete.Count | Should -Be 3
        $toDelete | Should -Contain 'wf-a-50'
        $toDelete | Should -Contain 'wf-b-100'
        $toDelete | Should -Contain 'wf-c-10'
    }

    It 'returns empty when no artifacts exceed max age' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)
        $artifacts = New-TestArtifactSet

        [string[]]$toDelete = Get-ArtifactsExceedingMaxAge `
            -Artifacts $artifacts `
            -MaxAgeDays ([int]365) `
            -ReferenceDate $now

        $toDelete.Count | Should -Be 0
    }

    It 'rejects non-positive MaxAgeDays' {
        $artifacts = New-TestArtifactSet
        { Get-ArtifactsExceedingMaxAge -Artifacts $artifacts `
            -MaxAgeDays ([int]0) -ReferenceDate ([datetime]::Now) } |
            Should -Throw '*MaxAgeDays must be positive*'
    }
}

# ── TDD Cycle 3: Keep-latest-N per workflow ─────────────────────────────────
Describe 'Get-ArtifactsExceedingKeepLatestN' {
    It 'keeps only the N most recent artifacts per unique Name (workflow grouping)' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)
        $artifacts = New-TestArtifactSet

        # Keep latest 1 per artifact name:
        # build-linux: keep wf-a-100 (newest), delete wf-a-99, wf-a-50
        # test-results: keep wf-b-200 (newest), delete wf-b-100
        # coverage-report: keep wf-c-10 (only one)
        [string[]]$toDelete = Get-ArtifactsExceedingKeepLatestN `
            -Artifacts $artifacts `
            -KeepLatestN ([int]1)

        $toDelete.Count | Should -Be 3
        $toDelete | Should -Contain 'wf-a-99'
        $toDelete | Should -Contain 'wf-a-50'
        $toDelete | Should -Contain 'wf-b-100'
    }

    It 'keeps all when N is larger than group sizes' {
        $artifacts = New-TestArtifactSet

        [string[]]$toDelete = Get-ArtifactsExceedingKeepLatestN `
            -Artifacts $artifacts `
            -KeepLatestN ([int]100)

        $toDelete.Count | Should -Be 0
    }

    It 'rejects non-positive KeepLatestN' {
        $artifacts = New-TestArtifactSet
        { Get-ArtifactsExceedingKeepLatestN -Artifacts $artifacts `
            -KeepLatestN ([int]0) } |
            Should -Throw '*KeepLatestN must be positive*'
    }
}

# ── TDD Cycle 4: Max total size policy ──────────────────────────────────────
Describe 'Get-ArtifactsExceedingMaxTotalSize' {
    It 'deletes oldest artifacts until total size fits within budget' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)
        $artifacts = New-TestArtifactSet

        # Total size = 1048576 + 2097152 + 1048576 + 524288 + 524288 + 262144
        #            = 5505024 bytes
        # Budget = 3MB = 3145728 bytes
        # Must delete oldest first until remaining <= budget
        # Sorted oldest first: wf-c-10(262144), wf-b-100(524288),
        #   wf-a-50(1048576), wf-b-200(524288), wf-a-99(2097152), wf-a-100(1048576)
        # Delete wf-c-10: remaining = 5505024 - 262144 = 5242880 (still > 3145728)
        # Delete wf-b-100: remaining = 5242880 - 524288 = 4718592 (still > 3145728)
        # Delete wf-a-50: remaining = 4718592 - 1048576 = 3670016 (still > 3145728)
        # Delete wf-b-200: remaining = 3670016 - 524288 = 3145728 (== 3145728, done)
        [string[]]$toDelete = Get-ArtifactsExceedingMaxTotalSize `
            -Artifacts $artifacts `
            -MaxTotalSizeBytes ([long]3145728)

        $toDelete.Count | Should -Be 4
        $toDelete | Should -Contain 'wf-c-10'
        $toDelete | Should -Contain 'wf-b-100'
        $toDelete | Should -Contain 'wf-a-50'
        $toDelete | Should -Contain 'wf-b-200'
    }

    It 'returns empty when total size already within budget' {
        $artifacts = New-TestArtifactSet

        [string[]]$toDelete = Get-ArtifactsExceedingMaxTotalSize `
            -Artifacts $artifacts `
            -MaxTotalSizeBytes ([long]100000000)

        $toDelete.Count | Should -Be 0
    }

    It 'rejects non-positive MaxTotalSizeBytes' {
        $artifacts = New-TestArtifactSet
        { Get-ArtifactsExceedingMaxTotalSize -Artifacts $artifacts `
            -MaxTotalSizeBytes ([long]0) } |
            Should -Throw '*MaxTotalSizeBytes must be positive*'
    }
}

# ── TDD Cycle 5: Deletion plan generation ───────────────────────────────────
Describe 'New-DeletionPlan' {
    It 'generates a deletion plan with correct retained/deleted counts and reclaimed space' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$false)

        # MaxAge=30d deletes: wf-a-50, wf-b-100, wf-c-10
        # KeepLatestN=2 per name: build-linux keeps wf-a-100, wf-a-99 (del wf-a-50);
        #   test-results keeps wf-b-200 (del wf-b-100); coverage keeps wf-c-10 (only 1)
        # Combined unique: wf-a-50, wf-b-100, wf-c-10
        # MaxTotalSize is generous so no extra deletions
        $plan.DeletedArtifacts.Count  | Should -BeGreaterOrEqual 3
        $plan.TotalArtifacts          | Should -Be 6
        $plan.RetainedCount           | Should -BeLessOrEqual 3
        $plan.SpaceReclaimedBytes     | Should -BeGreaterThan 0
        $plan.DryRun                  | Should -BeFalse
    }

    It 'calculates correct space reclaimed in bytes' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]100
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$false)

        # Only max-age applies: wf-a-50(1MB), wf-b-100(512KB), wf-c-10(256KB)
        # = 1048576 + 524288 + 262144 = 1835008
        $plan.SpaceReclaimedBytes | Should -Be 1835008
        $plan.DeletedCount        | Should -Be 3
        $plan.RetainedCount       | Should -Be 3
    }

    It 'includes all required summary fields' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        $plan.Keys | Should -Contain 'TotalArtifacts'
        $plan.Keys | Should -Contain 'DeletedCount'
        $plan.Keys | Should -Contain 'RetainedCount'
        $plan.Keys | Should -Contain 'SpaceReclaimedBytes'
        $plan.Keys | Should -Contain 'DeletedArtifacts'
        $plan.Keys | Should -Contain 'RetainedArtifacts'
        $plan.Keys | Should -Contain 'DryRun'
        $plan.Keys | Should -Contain 'Summary'
    }
}

# ── TDD Cycle 6: Dry-run mode ──────────────────────────────────────────────
Describe 'Dry-run mode' {
    It 'sets DryRun flag to true in the plan' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        $plan.DryRun | Should -BeTrue
    }

    It 'produces identical deletion list in dry-run vs non-dry-run' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $planDry = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        $planReal = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$false)

        $planDry.DeletedCount | Should -Be $planReal.DeletedCount
        $planDry.SpaceReclaimedBytes | Should -Be $planReal.SpaceReclaimedBytes
    }

    It 'includes [DRY RUN] prefix in summary when dry-run is enabled' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        $plan.Summary | Should -BeLike '*DRY RUN*'
    }

    It 'does NOT include [DRY RUN] prefix when dry-run is disabled' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$false)

        $plan.Summary | Should -Not -BeLike '*DRY RUN*'
    }
}

# ── TDD Cycle 7: Combined policies ─────────────────────────────────────────
Describe 'Combined policy application' {
    It 'unions deletion sets from all policies' {
        $artifacts = New-TestArtifactSet

        # Tight policies: max age 10d + keep 1 per name + 2MB budget
        [hashtable]$policy = @{
            MaxAgeDays        = [int]10
            KeepLatestN       = [int]1
            MaxTotalSizeBytes = [long]2097152
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        # MaxAge=10d: artifacts > 10 days old = wf-a-50(45d), wf-b-200(3d? no, 3<10),
        #   wait: wf-a-99 is 2d old, wf-b-200 is 3d old, wf-a-50 is 45d, wf-b-100 is 60d, wf-c-10 is 90d
        # So >10d: wf-a-50, wf-b-100, wf-c-10
        # KeepLatestN=1: build-linux keep wf-a-100 del wf-a-99,wf-a-50;
        #   test-results keep wf-b-200 del wf-b-100; coverage keep wf-c-10
        # Union of age + keepN: wf-a-50, wf-b-100, wf-c-10, wf-a-99
        # After deleting those 4, remaining: wf-a-100(1MB), wf-b-200(512KB) = 1572864 <= 2MB
        # So max-size doesn't add more deletions
        $plan.DeletedCount  | Should -Be 4
        $plan.RetainedCount | Should -Be 2
    }

    It 'handles empty artifact list gracefully' {
        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)
        [System.Collections.Generic.List[hashtable]]$empty = [System.Collections.Generic.List[hashtable]]::new()

        $plan = New-DeletionPlan `
            -Artifacts $empty `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$false)

        $plan.TotalArtifacts      | Should -Be 0
        $plan.DeletedCount        | Should -Be 0
        $plan.RetainedCount       | Should -Be 0
        $plan.SpaceReclaimedBytes | Should -Be 0
    }

    It 'does not double-count artifacts flagged by multiple policies' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        [System.Collections.Generic.List[hashtable]]$artifacts = [System.Collections.Generic.List[hashtable]]::new()
        # One old, large artifact — will be flagged by both max-age and max-size
        $artifacts.Add((New-ArtifactRecord `
            -Name 'big-old' `
            -SizeBytes 10000000 `
            -CreatedDate $now.AddDays(-100) `
            -WorkflowRunId 'wf-x-1'))

        $artifacts.Add((New-ArtifactRecord `
            -Name 'small-new' `
            -SizeBytes 100 `
            -CreatedDate $now.AddDays(-1) `
            -WorkflowRunId 'wf-y-1'))

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]1
            MaxTotalSizeBytes = [long]1000
        }

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        # big-old flagged by max-age AND max-size — should appear once
        $plan.DeletedCount   | Should -Be 1
        $plan.RetainedCount  | Should -Be 1
    }
}

# ── TDD Cycle 8: Invoke-ArtifactCleanup entry point ────────────────────────
Describe 'Invoke-ArtifactCleanup' {
    It 'accepts artifacts and policy and returns a deletion plan' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = Invoke-ArtifactCleanup `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun

        $plan | Should -Not -BeNullOrEmpty
        $plan.DryRun | Should -BeTrue
        $plan.TotalArtifacts | Should -Be 6
    }

    It 'defaults to dry-run when -DryRun is specified' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = Invoke-ArtifactCleanup `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun

        $plan.DryRun | Should -BeTrue
    }

    It 'returns human-readable summary string' {
        $artifacts = New-TestArtifactSet

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]2
            MaxTotalSizeBytes = [long]100000000
        }

        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        $plan = Invoke-ArtifactCleanup `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now

        $plan.Summary | Should -BeLike '*deleted*'
        $plan.Summary | Should -BeLike '*retained*'
        $plan.Summary | Should -BeLike '*reclaimed*'
    }
}

# ── TDD Cycle 9: Format-ByteSize helper ────────────────────────────────────
Describe 'Format-ByteSize' {
    It 'formats bytes correctly' {
        Format-ByteSize -Bytes ([long]512) | Should -Be '512 B'
    }

    It 'formats kilobytes correctly' {
        Format-ByteSize -Bytes ([long]1536) | Should -Be '1.50 KB'
    }

    It 'formats megabytes correctly' {
        Format-ByteSize -Bytes ([long]2097152) | Should -Be '2.00 MB'
    }

    It 'formats gigabytes correctly' {
        Format-ByteSize -Bytes ([long]1610612736) | Should -Be '1.50 GB'
    }

    It 'handles zero bytes' {
        Format-ByteSize -Bytes ([long]0) | Should -Be '0 B'
    }
}

# ── TDD Cycle 10: Edge cases and error handling ────────────────────────────
Describe 'Edge cases' {
    It 'handles single artifact that passes all policies' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        [System.Collections.Generic.List[hashtable]]$artifacts = [System.Collections.Generic.List[hashtable]]::new()
        $artifacts.Add((New-ArtifactRecord `
            -Name 'sole' `
            -SizeBytes 100 `
            -CreatedDate $now.AddDays(-1) `
            -WorkflowRunId 'wf-1'))

        [hashtable]$policy = @{
            MaxAgeDays        = [int]30
            KeepLatestN       = [int]5
            MaxTotalSizeBytes = [long]100000000
        }

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$false)

        $plan.DeletedCount  | Should -Be 0
        $plan.RetainedCount | Should -Be 1
    }

    It 'handles all artifacts being deleted' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        [System.Collections.Generic.List[hashtable]]$artifacts = [System.Collections.Generic.List[hashtable]]::new()
        $artifacts.Add((New-ArtifactRecord `
            -Name 'ancient' `
            -SizeBytes 999999 `
            -CreatedDate $now.AddDays(-365) `
            -WorkflowRunId 'wf-old'))

        [hashtable]$policy = @{
            MaxAgeDays        = [int]7
            KeepLatestN       = [int]1
            MaxTotalSizeBytes = [long]100000000
        }

        $plan = New-DeletionPlan `
            -Artifacts $artifacts `
            -Policy $policy `
            -ReferenceDate $now `
            -DryRun ([bool]$true)

        $plan.DeletedCount  | Should -Be 1
        $plan.RetainedCount | Should -Be 0
    }

    It 'max-size policy deletes in oldest-first order' {
        [datetime]$now = [datetime]::new(2026, 4, 1, 12, 0, 0)

        [System.Collections.Generic.List[hashtable]]$artifacts = [System.Collections.Generic.List[hashtable]]::new()
        $artifacts.Add((New-ArtifactRecord -Name 'a' -SizeBytes 500 `
            -CreatedDate $now.AddDays(-3) -WorkflowRunId 'wf-1'))
        $artifacts.Add((New-ArtifactRecord -Name 'b' -SizeBytes 500 `
            -CreatedDate $now.AddDays(-2) -WorkflowRunId 'wf-2'))
        $artifacts.Add((New-ArtifactRecord -Name 'c' -SizeBytes 500 `
            -CreatedDate $now.AddDays(-1) -WorkflowRunId 'wf-3'))

        # Total = 1500. Budget = 1100.
        # Delete wf-1 (500): remaining = 1000 <= 1100 → stop. Only 1 deletion.
        [string[]]$toDelete = Get-ArtifactsExceedingMaxTotalSize `
            -Artifacts $artifacts `
            -MaxTotalSizeBytes ([long]1100)

        $toDelete.Count | Should -Be 1
        $toDelete[0]    | Should -Be 'wf-1'
    }
}
