#Requires -Module Pester

# Pester tests for the artifact cleanup module. Follows red/green TDD: each
# Describe block focuses on one behaviour of Get-DeletionPlan / Invoke-ArtifactCleanup.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # Helper: build an artifact hashtable with sane defaults so tests stay readable.
    function script:New-Artifact {
        param(
            [string]$Name,
            [int]$AgeDays = 0,
            [long]$Size = 1MB,
            [string]$WorkflowId = 'wf-1',
            [int]$Index = 0
        )
        [pscustomobject]@{
            Name           = $Name
            SizeBytes      = $Size
            CreatedAt      = (Get-Date).AddDays(-$AgeDays).AddMinutes(-$Index)
            WorkflowRunId  = $WorkflowId
        }
    }
}

Describe 'Get-DeletionPlan: structure' {
    It 'returns an object with Delete, Retain, and Summary properties' {
        $plan = Get-DeletionPlan -Artifacts @() -MaxAgeDays 30
        $plan.PSObject.Properties.Name | Should -Contain 'Delete'
        $plan.PSObject.Properties.Name | Should -Contain 'Retain'
        $plan.PSObject.Properties.Name | Should -Contain 'Summary'
    }
}

Describe 'Get-DeletionPlan: max age policy' {
    It 'deletes artifacts older than MaxAgeDays' {
        $arts = @(
            (New-Artifact -Name 'old'   -AgeDays 40),
            (New-Artifact -Name 'fresh' -AgeDays  5)
        )
        $plan = Get-DeletionPlan -Artifacts $arts -MaxAgeDays 30
        $plan.Delete.Name | Should -Be @('old')
        $plan.Retain.Name | Should -Be @('fresh')
    }
}

Describe 'Get-DeletionPlan: keep-latest-N per workflow' {
    It 'keeps only the N most recent artifacts per workflow run id' {
        $arts = @(
            (New-Artifact -Name 'a-1' -WorkflowId 'A' -Index 1),
            (New-Artifact -Name 'a-2' -WorkflowId 'A' -Index 2),
            (New-Artifact -Name 'a-3' -WorkflowId 'A' -Index 3),
            (New-Artifact -Name 'b-1' -WorkflowId 'B' -Index 1)
        )
        $plan = Get-DeletionPlan -Artifacts $arts -KeepLatestPerWorkflow 1
        # a-1 is newest in A (Index 1 -> latest); b-1 is the only B.
        ($plan.Retain.Name | Sort-Object) | Should -Be @('a-1','b-1')
        ($plan.Delete.Name | Sort-Object) | Should -Be @('a-2','a-3')
    }
}

Describe 'Get-DeletionPlan: max total size policy' {
    It 'deletes oldest artifacts until total retained size is under MaxTotalSizeBytes' {
        $arts = @(
            (New-Artifact -Name 'oldest' -AgeDays 10 -Size 500),
            (New-Artifact -Name 'mid'    -AgeDays  5 -Size 500),
            (New-Artifact -Name 'newest' -AgeDays  1 -Size 500)
        )
        # Cap of 1000 bytes: must drop the oldest 500-byte artifact.
        $plan = Get-DeletionPlan -Artifacts $arts -MaxTotalSizeBytes 1000
        $plan.Delete.Name | Should -Be @('oldest')
        ($plan.Retain.Name | Sort-Object) | Should -Be @('mid','newest')
    }
}

Describe 'Get-DeletionPlan: summary' {
    It 'reports total space reclaimed and counts' {
        $arts = @(
            (New-Artifact -Name 'old'   -AgeDays 60 -Size 1000),
            (New-Artifact -Name 'fresh' -AgeDays  1 -Size  500)
        )
        $plan = Get-DeletionPlan -Artifacts $arts -MaxAgeDays 30
        $plan.Summary.DeletedCount        | Should -Be 1
        $plan.Summary.RetainedCount       | Should -Be 1
        $plan.Summary.SpaceReclaimedBytes | Should -Be 1000
    }
}

Describe 'Get-DeletionPlan: combined policies' {
    It 'applies age, keep-latest, and size together' {
        $arts = @(
            (New-Artifact -Name 'expired' -AgeDays 90 -Size 100 -WorkflowId 'A' -Index 1),
            (New-Artifact -Name 'A-old'   -AgeDays  5 -Size 100 -WorkflowId 'A' -Index 5),
            (New-Artifact -Name 'A-new'   -AgeDays  5 -Size 100 -WorkflowId 'A' -Index 1),
            (New-Artifact -Name 'B-only'  -AgeDays  1 -Size 100 -WorkflowId 'B' -Index 1)
        )
        $plan = Get-DeletionPlan -Artifacts $arts -MaxAgeDays 30 -KeepLatestPerWorkflow 1
        ($plan.Delete.Name | Sort-Object) | Should -Be @('A-old','expired')
        ($plan.Retain.Name | Sort-Object) | Should -Be @('A-new','B-only')
    }
}

Describe 'Invoke-ArtifactCleanup: dry-run' {
    It 'does not invoke the deleter when -DryRun is set' {
        $arts = @(
            (New-Artifact -Name 'old'   -AgeDays 60 -Size 100),
            (New-Artifact -Name 'fresh' -AgeDays  1 -Size 100)
        )
        $deleted = [System.Collections.ArrayList]::new()
        $deleter = { param($a) [void]$deleted.Add($a.Name) }

        $result = Invoke-ArtifactCleanup -Artifacts $arts -MaxAgeDays 30 -DryRun -Deleter $deleter
        $deleted.Count | Should -Be 0
        $result.Summary.DeletedCount | Should -Be 1
        $result.DryRun | Should -BeTrue
    }

    It 'invokes the deleter once per artifact when not in dry-run' {
        $arts = @(
            (New-Artifact -Name 'old1' -AgeDays 60 -Size 100),
            (New-Artifact -Name 'old2' -AgeDays 70 -Size 100)
        )
        $deleted = [System.Collections.ArrayList]::new()
        $deleter = { param($a) [void]$deleted.Add($a.Name) }

        $null = Invoke-ArtifactCleanup -Artifacts $arts -MaxAgeDays 30 -Deleter $deleter
        ($deleted | Sort-Object) | Should -Be @('old1','old2')
    }
}

Describe 'Get-DeletionPlan: input validation' {
    It 'throws a meaningful error when no policy is supplied' {
        { Get-DeletionPlan -Artifacts @() } | Should -Throw -ExpectedMessage '*at least one retention policy*'
    }
}
