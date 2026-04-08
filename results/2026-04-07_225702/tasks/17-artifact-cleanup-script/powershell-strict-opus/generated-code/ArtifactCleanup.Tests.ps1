BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot/ArtifactCleanup.ps1"
}

Describe 'New-ArtifactRecord' {
    It 'creates an artifact record with all required fields' {
        $artifact = New-ArtifactRecord -Name 'build-output' `
            -SizeBytes 1048576 `
            -CreationDate ([datetime]'2026-03-01') `
            -WorkflowRunId 'run-100'

        $artifact.Name | Should -Be 'build-output'
        $artifact.SizeBytes | Should -Be 1048576
        $artifact.CreationDate | Should -Be ([datetime]'2026-03-01')
        $artifact.WorkflowRunId | Should -Be 'run-100'
    }

    It 'rejects empty name' {
        # PowerShell validates [string] Mandatory params — empty string is rejected at binding
        { New-ArtifactRecord -Name '' -SizeBytes 100 -CreationDate ([datetime]::Now) -WorkflowRunId 'run-1' } |
            Should -Throw
    }

    It 'rejects negative size' {
        { New-ArtifactRecord -Name 'a' -SizeBytes -1 -CreationDate ([datetime]::Now) -WorkflowRunId 'run-1' } |
            Should -Throw '*SizeBytes must be non-negative*'
    }
}

Describe 'New-MockArtifactSet' {
    It 'returns a known set of artifacts for testing' {
        $artifacts = New-MockArtifactSet
        $artifacts.Count | Should -BeGreaterThan 0
        # Each record must have the expected properties
        foreach ($a in $artifacts) {
            $a.PSObject.Properties.Name | Should -Contain 'Name'
            $a.PSObject.Properties.Name | Should -Contain 'SizeBytes'
            $a.PSObject.Properties.Name | Should -Contain 'CreationDate'
            $a.PSObject.Properties.Name | Should -Contain 'WorkflowRunId'
        }
    }
}

Describe 'Get-ArtifactsExceedingMaxAge' {
    BeforeAll {
        # Fixed reference date for deterministic tests
        [datetime]$script:refDate = [datetime]'2026-04-01'
        $script:artifacts = @(
            (New-ArtifactRecord -Name 'old-1'    -SizeBytes 100 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'run-1'),
            (New-ArtifactRecord -Name 'recent-1' -SizeBytes 200 -CreationDate ([datetime]'2026-03-25') -WorkflowRunId 'run-2'),
            (New-ArtifactRecord -Name 'old-2'    -SizeBytes 300 -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'run-3')
        )
    }

    It 'marks artifacts older than MaxAgeDays for deletion' {
        # 30 day max age from 2026-04-01 => cutoff is 2026-03-02
        [PSCustomObject[]]$result = Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays ([int]30) -ReferenceDate $script:refDate
        $result.Count | Should -Be 2
        $result.Name | Should -Contain 'old-1'
        $result.Name | Should -Contain 'old-2'
    }

    It 'returns nothing when all artifacts are within age limit' {
        [array]$result = @(Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays ([int]365) -ReferenceDate $script:refDate)
        $result.Count | Should -Be 0
    }

    It 'returns all artifacts when MaxAgeDays is 0' {
        [PSCustomObject[]]$result = Get-ArtifactsExceedingMaxAge -Artifacts $script:artifacts -MaxAgeDays ([int]0) -ReferenceDate $script:refDate
        $result.Count | Should -Be 3
    }
}

Describe 'Get-ArtifactsExceedingKeepLatestN' {
    BeforeAll {
        # 3 artifacts from workflow A, 2 from workflow B
        $script:artifacts = @(
            (New-ArtifactRecord -Name 'A-oldest' -SizeBytes 100 -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-A'),
            (New-ArtifactRecord -Name 'A-middle' -SizeBytes 200 -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'wf-A'),
            (New-ArtifactRecord -Name 'A-newest' -SizeBytes 300 -CreationDate ([datetime]'2026-03-01') -WorkflowRunId 'wf-A'),
            (New-ArtifactRecord -Name 'B-older'  -SizeBytes 150 -CreationDate ([datetime]'2026-01-15') -WorkflowRunId 'wf-B'),
            (New-ArtifactRecord -Name 'B-newer'  -SizeBytes 250 -CreationDate ([datetime]'2026-03-15') -WorkflowRunId 'wf-B')
        )
    }

    It 'keeps only N newest artifacts per workflow and marks the rest for deletion' {
        # Keep latest 1 per workflow => delete A-oldest, A-middle, B-older
        [PSCustomObject[]]$result = Get-ArtifactsExceedingKeepLatestN -Artifacts $script:artifacts -KeepLatestN ([int]1)
        $result.Count | Should -Be 3
        $result.Name | Should -Contain 'A-oldest'
        $result.Name | Should -Contain 'A-middle'
        $result.Name | Should -Contain 'B-older'
    }

    It 'returns nothing when N is greater than or equal to artifacts per workflow' {
        [array]$result = @(Get-ArtifactsExceedingKeepLatestN -Artifacts $script:artifacts -KeepLatestN ([int]10))
        $result.Count | Should -Be 0
    }

    It 'keeps exactly 2 per workflow' {
        # wf-A has 3 => delete 1 (oldest), wf-B has 2 => delete 0
        [PSCustomObject[]]$result = Get-ArtifactsExceedingKeepLatestN -Artifacts $script:artifacts -KeepLatestN ([int]2)
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'A-oldest'
    }
}

Describe 'Get-ArtifactsExceedingMaxTotalSize' {
    BeforeAll {
        $script:artifacts = @(
            (New-ArtifactRecord -Name 'small'  -SizeBytes ([long]100) -CreationDate ([datetime]'2026-03-01') -WorkflowRunId 'wf-1'),
            (New-ArtifactRecord -Name 'medium' -SizeBytes ([long]200) -CreationDate ([datetime]'2026-02-01') -WorkflowRunId 'wf-1'),
            (New-ArtifactRecord -Name 'large'  -SizeBytes ([long]300) -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-2')
        )
        # Total = 600
    }

    It 'marks oldest artifacts for deletion until total size is within budget' {
        # Max 400 => need to drop 200+ => oldest first: large (300) removed, total becomes 300
        [PSCustomObject[]]$result = Get-ArtifactsExceedingMaxTotalSize -Artifacts $script:artifacts -MaxTotalSizeBytes ([long]400)
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'large'
    }

    It 'returns nothing when already within budget' {
        [array]$result = @(Get-ArtifactsExceedingMaxTotalSize -Artifacts $script:artifacts -MaxTotalSizeBytes ([long]1000))
        $result.Count | Should -Be 0
    }

    It 'marks multiple artifacts when needed to meet budget' {
        # Max 100 => only keep 'small' (100), delete medium (200) + large (300)
        [PSCustomObject[]]$result = Get-ArtifactsExceedingMaxTotalSize -Artifacts $script:artifacts -MaxTotalSizeBytes ([long]100)
        $result.Count | Should -Be 2
        $result.Name | Should -Contain 'medium'
        $result.Name | Should -Contain 'large'
    }
}

Describe 'New-DeletionPlan' {
    BeforeAll {
        [datetime]$script:refDate = [datetime]'2026-04-01'
        # Workflow A: 3 artifacts, mixed ages and sizes
        $script:artifacts = @(
            (New-ArtifactRecord -Name 'A-old'    -SizeBytes ([long]500) -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-A'),
            (New-ArtifactRecord -Name 'A-mid'    -SizeBytes ([long]300) -CreationDate ([datetime]'2026-02-15') -WorkflowRunId 'wf-A'),
            (New-ArtifactRecord -Name 'A-new'    -SizeBytes ([long]200) -CreationDate ([datetime]'2026-03-25') -WorkflowRunId 'wf-A'),
            (New-ArtifactRecord -Name 'B-old'    -SizeBytes ([long]400) -CreationDate ([datetime]'2026-01-10') -WorkflowRunId 'wf-B'),
            (New-ArtifactRecord -Name 'B-new'    -SizeBytes ([long]100) -CreationDate ([datetime]'2026-03-28') -WorkflowRunId 'wf-B')
        )
        # Total size = 1500
    }

    It 'combines all policies and de-duplicates artifacts to delete' {
        # MaxAge=60 days => cutoff 2026-01-31 => deletes A-old, B-old
        # KeepLatestN=2 => wf-A: keep A-mid + A-new, delete A-old; wf-B: keep both
        # MaxTotalSize=1000 => total 1500, need to shed 500+
        # Union: A-old and B-old from age+keepN; size policy may add more
        $plan = New-DeletionPlan -Artifacts $script:artifacts `
            -MaxAgeDays ([int]60) `
            -KeepLatestN ([int]2) `
            -MaxTotalSizeBytes ([long]1000) `
            -ReferenceDate $script:refDate

        $plan.PSObject.Properties.Name | Should -Contain 'ToDelete'
        $plan.PSObject.Properties.Name | Should -Contain 'ToRetain'
        $plan.PSObject.Properties.Name | Should -Contain 'SpaceReclaimedBytes'
        $plan.PSObject.Properties.Name | Should -Contain 'TotalArtifacts'
        $plan.PSObject.Properties.Name | Should -Contain 'DeletedCount'
        $plan.PSObject.Properties.Name | Should -Contain 'RetainedCount'

        # A-old and B-old should definitely be deleted (both are > 60 days old)
        $plan.ToDelete.Name | Should -Contain 'A-old'
        $plan.ToDelete.Name | Should -Contain 'B-old'
        $plan.DeletedCount | Should -BeGreaterOrEqual 2
        $plan.RetainedCount | Should -Be ($plan.TotalArtifacts - $plan.DeletedCount)
        $plan.SpaceReclaimedBytes | Should -BeGreaterThan 0
    }

    It 'handles case where no policies trigger any deletions' {
        $plan = New-DeletionPlan -Artifacts $script:artifacts `
            -MaxAgeDays ([int]365) `
            -KeepLatestN ([int]100) `
            -MaxTotalSizeBytes ([long]999999) `
            -ReferenceDate $script:refDate

        $plan.DeletedCount | Should -Be 0
        $plan.RetainedCount | Should -Be 5
        $plan.SpaceReclaimedBytes | Should -Be 0
    }
}

Describe 'Invoke-ArtifactCleanup (dry-run)' {
    BeforeAll {
        $script:artifacts = New-MockArtifactSet
    }

    It 'in DryRun mode returns a plan without executing deletions' {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts `
            -MaxAgeDays ([int]60) `
            -KeepLatestN ([int]2) `
            -MaxTotalSizeBytes ([long]10000000) `
            -ReferenceDate ([datetime]'2026-04-01') `
            -DryRun

        $result.PSObject.Properties.Name | Should -Contain 'DryRun'
        $result.DryRun | Should -BeTrue
        $result.PSObject.Properties.Name | Should -Contain 'Plan'
        $result.Plan | Should -Not -BeNullOrEmpty
    }

    It 'in non-DryRun mode returns a plan with DryRun false' {
        $result = Invoke-ArtifactCleanup -Artifacts $script:artifacts `
            -MaxAgeDays ([int]60) `
            -KeepLatestN ([int]2) `
            -MaxTotalSizeBytes ([long]10000000) `
            -ReferenceDate ([datetime]'2026-04-01')

        $result.DryRun | Should -BeFalse
        $result.Plan | Should -Not -BeNullOrEmpty
    }
}

Describe 'Format-DeletionSummary' {
    It 'produces a human-readable summary string' {
        $artifacts = @(
            (New-ArtifactRecord -Name 'x' -SizeBytes ([long]1048576)  -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-1'),
            (New-ArtifactRecord -Name 'y' -SizeBytes ([long]2097152)  -CreationDate ([datetime]'2026-03-01') -WorkflowRunId 'wf-1')
        )
        $plan = New-DeletionPlan -Artifacts $artifacts `
            -MaxAgeDays ([int]30) `
            -KeepLatestN ([int]10) `
            -MaxTotalSizeBytes ([long]999999999) `
            -ReferenceDate ([datetime]'2026-04-01')

        [string]$summary = Format-DeletionSummary -Plan $plan
        $summary | Should -Not -BeNullOrEmpty
        # Should mention retained and deleted counts
        $summary | Should -Match 'retain'
        $summary | Should -Match 'delete'
    }
}

Describe 'Format-ByteSize' {
    It 'formats bytes' {
        Format-ByteSize -Bytes ([long]512) | Should -Be '512 B'
    }
    It 'formats kilobytes' {
        Format-ByteSize -Bytes ([long]2048) | Should -Be '2.00 KB'
    }
    It 'formats megabytes' {
        Format-ByteSize -Bytes ([long]5242880) | Should -Be '5.00 MB'
    }
    It 'formats gigabytes' {
        Format-ByteSize -Bytes ([long]2147483648) | Should -Be '2.00 GB'
    }
    It 'formats zero' {
        Format-ByteSize -Bytes ([long]0) | Should -Be '0 B'
    }
}

Describe 'Integration: full pipeline with mock data' {
    It 'processes the mock artifact set with realistic policies' {
        [PSCustomObject[]]$artifacts = New-MockArtifactSet
        [datetime]$refDate = [datetime]'2026-04-01'

        # Apply: max age 60 days, keep latest 2 per workflow, max total 15 MB
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts `
            -MaxAgeDays ([int]60) `
            -KeepLatestN ([int]2) `
            -MaxTotalSizeBytes ([long]15728640) `
            -ReferenceDate $refDate `
            -DryRun

        $result.DryRun | Should -BeTrue
        [PSCustomObject]$plan = $result.Plan

        # Total artifacts should match mock set count
        $plan.TotalArtifacts | Should -Be $artifacts.Count

        # Deleted + Retained = Total
        ($plan.DeletedCount + $plan.RetainedCount) | Should -Be $plan.TotalArtifacts

        # Space reclaimed should be sum of deleted artifact sizes
        [long]$expectedReclaimed = [long]0
        foreach ($d in $plan.ToDelete) {
            $expectedReclaimed += [long]$d.SizeBytes
        }
        $plan.SpaceReclaimedBytes | Should -Be $expectedReclaimed

        # The very old artifacts should be marked for deletion
        # deploy-C-1 (2025-12-01) and build-A-1 (2026-01-10) are > 60 days old from 2026-04-01
        $plan.ToDelete.Name | Should -Contain 'deploy-C-1'
        $plan.ToDelete.Name | Should -Contain 'build-A-1'

        # The newest per workflow should be retained
        $plan.ToRetain.Name | Should -Contain 'build-A-4'
        $plan.ToRetain.Name | Should -Contain 'test-B-3'
        $plan.ToRetain.Name | Should -Contain 'deploy-C-3'

        # Generate summary and verify it's non-empty
        [string]$summary = Format-DeletionSummary -Plan $plan
        $summary.Length | Should -BeGreaterThan 100
    }

    It 'non-dry-run marks deleted artifacts' {
        [PSCustomObject[]]$artifacts = New-MockArtifactSet
        $result = Invoke-ArtifactCleanup -Artifacts $artifacts `
            -MaxAgeDays ([int]30) `
            -KeepLatestN ([int]1) `
            -MaxTotalSizeBytes ([long]999999999) `
            -ReferenceDate ([datetime]'2026-04-01')

        $result.DryRun | Should -BeFalse
        # Each deleted artifact should have a 'Deleted' property
        foreach ($d in $result.Plan.ToDelete) {
            $d.PSObject.Properties.Name | Should -Contain 'Deleted'
            $d.Deleted | Should -BeTrue
        }
    }
}

Describe 'Error handling' {
    It 'New-DeletionPlan rejects negative MaxAgeDays' {
        $artifacts = @(
            (New-ArtifactRecord -Name 'x' -SizeBytes ([long]100) -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-1')
        )
        { New-DeletionPlan -Artifacts $artifacts -MaxAgeDays ([int]-1) -KeepLatestN ([int]1) -MaxTotalSizeBytes ([long]100) -ReferenceDate ([datetime]'2026-04-01') } |
            Should -Throw '*non-negative*'
    }

    It 'Get-ArtifactsExceedingKeepLatestN rejects negative N' {
        $artifacts = @(
            (New-ArtifactRecord -Name 'x' -SizeBytes ([long]100) -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-1')
        )
        { Get-ArtifactsExceedingKeepLatestN -Artifacts $artifacts -KeepLatestN ([int]-1) } |
            Should -Throw '*non-negative*'
    }

    It 'Get-ArtifactsExceedingMaxTotalSize rejects negative size' {
        $artifacts = @(
            (New-ArtifactRecord -Name 'x' -SizeBytes ([long]100) -CreationDate ([datetime]'2026-01-01') -WorkflowRunId 'wf-1')
        )
        { Get-ArtifactsExceedingMaxTotalSize -Artifacts $artifacts -MaxTotalSizeBytes ([long]-1) } |
            Should -Throw '*non-negative*'
    }
}
