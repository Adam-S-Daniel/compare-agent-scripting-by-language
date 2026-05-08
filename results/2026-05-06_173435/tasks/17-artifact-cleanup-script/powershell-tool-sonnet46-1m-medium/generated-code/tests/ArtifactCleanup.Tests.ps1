#Requires -Module Pester

# Red/Green TDD tests for the ArtifactCleanup module.
# Written BEFORE the module implementation so each block starts as a failing test.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'ArtifactCleanup.psm1'
    Import-Module $ModulePath -Force

    # Factory function: build a mock artifact with sensible defaults.
    function script:New-MockArtifact {
        param(
            [string]$Name,
            [int]$AgeDays     = 0,
            [long]$Size       = 1MB,
            [string]$Workflow = 'wf-default',
            [int]$Ordinal     = 0   # tie-break within same AgeDays (higher = older)
        )
        [pscustomobject]@{
            Name          = $Name
            SizeBytes     = $Size
            CreatedAt     = (Get-Date).AddDays(-$AgeDays).AddMinutes(-$Ordinal)
            WorkflowRunId = $Workflow
        }
    }
}

# ── Structure ─────────────────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: return structure' {
    It 'returns an object with Delete, Retain, and Summary properties' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -MaxAgeDays 30
        $plan.PSObject.Properties.Name | Should -Contain 'Delete'
        $plan.PSObject.Properties.Name | Should -Contain 'Retain'
        $plan.PSObject.Properties.Name | Should -Contain 'Summary'
    }

    It 'Summary contains DeletedCount, RetainedCount, SpaceReclaimedBytes' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -MaxAgeDays 30
        $plan.Summary.PSObject.Properties.Name | Should -Contain 'DeletedCount'
        $plan.Summary.PSObject.Properties.Name | Should -Contain 'RetainedCount'
        $plan.Summary.PSObject.Properties.Name | Should -Contain 'SpaceReclaimedBytes'
    }
}

# ── Max-age policy ────────────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: MaxAgeDays policy' {
    It 'deletes artifacts older than MaxAgeDays' {
        $arts = @(
            (New-MockArtifact -Name 'stale'  -AgeDays 45),
            (New-MockArtifact -Name 'recent' -AgeDays  5)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxAgeDays 30
        $plan.Delete.Name | Should -Contain 'stale'
        $plan.Retain.Name | Should -Contain 'recent'
        $plan.Delete.Name | Should -Not -Contain 'recent'
    }

    It 'retains artifacts exactly at the age boundary' {
        # An artifact whose age equals MaxAgeDays is NOT past it — keep it.
        $arts = @(
            (New-MockArtifact -Name 'boundary' -AgeDays 30)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxAgeDays 30
        $plan.Retain.Name | Should -Contain 'boundary'
    }

    It 'handles an empty artifact list' {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -MaxAgeDays 30
        $plan.Delete.Count | Should -Be 0
        $plan.Retain.Count | Should -Be 0
    }
}

# ── Keep-latest-N policy ───────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: KeepLatestPerWorkflow policy' {
    It 'keeps the N newest artifacts per workflow run id' {
        $arts = @(
            (New-MockArtifact -Name 'wf1-new'    -Workflow 'wf-1' -Ordinal 1),
            (New-MockArtifact -Name 'wf1-mid'    -Workflow 'wf-1' -Ordinal 2),
            (New-MockArtifact -Name 'wf1-oldest' -Workflow 'wf-1' -Ordinal 3),
            (New-MockArtifact -Name 'wf2-only'   -Workflow 'wf-2' -Ordinal 1)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -KeepLatestPerWorkflow 1
        $plan.Retain.Name | Should -Contain 'wf1-new'
        $plan.Retain.Name | Should -Contain 'wf2-only'
        $plan.Delete.Name | Should -Contain 'wf1-mid'
        $plan.Delete.Name | Should -Contain 'wf1-oldest'
    }

    It 'keeps all artifacts when N >= count per workflow' {
        $arts = @(
            (New-MockArtifact -Name 'a' -Workflow 'wf-1' -Ordinal 1),
            (New-MockArtifact -Name 'b' -Workflow 'wf-1' -Ordinal 2)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -KeepLatestPerWorkflow 5
        $plan.Delete.Count | Should -Be 0
        $plan.Retain.Count | Should -Be 2
    }
}

# ── Max-total-size policy ─────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: MaxTotalSizeBytes policy' {
    It 'evicts oldest artifacts until total size fits the cap' {
        $arts = @(
            (New-MockArtifact -Name 'oldest' -AgeDays 30 -Size 600),
            (New-MockArtifact -Name 'middle' -AgeDays 15 -Size 600),
            (New-MockArtifact -Name 'newest' -AgeDays  1 -Size 600)
        )
        # Total = 1800; cap = 1200 → need to drop 600, evict oldest.
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxTotalSizeBytes 1200
        $plan.Delete.Name | Should -Contain 'oldest'
        $plan.Retain.Name | Should -Contain 'middle'
        $plan.Retain.Name | Should -Contain 'newest'
    }

    It 'does not delete anything when total size already fits' {
        $arts = @(
            (New-MockArtifact -Name 'small' -Size 100)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxTotalSizeBytes 1000
        $plan.Delete.Count | Should -Be 0
    }
}

# ── Summary accuracy ──────────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: Summary values' {
    It 'reports correct DeletedCount, RetainedCount, and SpaceReclaimedBytes' {
        $arts = @(
            (New-MockArtifact -Name 'gone'  -AgeDays 60 -Size 2000),
            (New-MockArtifact -Name 'kept1' -AgeDays  1 -Size  500),
            (New-MockArtifact -Name 'kept2' -AgeDays  2 -Size  300)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxAgeDays 30
        $plan.Summary.DeletedCount        | Should -Be 1
        $plan.Summary.RetainedCount       | Should -Be 2
        $plan.Summary.SpaceReclaimedBytes | Should -Be 2000
    }
}

# ── Combined policies ─────────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: combined policies' {
    It 'applies age + keep-latest together, union of deletions' {
        $arts = @(
            (New-MockArtifact -Name 'old-wf1-1' -AgeDays 60 -Workflow 'wf-1' -Ordinal 1),
            (New-MockArtifact -Name 'wf1-new'   -AgeDays  2 -Workflow 'wf-1' -Ordinal 1),
            (New-MockArtifact -Name 'wf1-extra'  -AgeDays 2 -Workflow 'wf-1' -Ordinal 2),
            (New-MockArtifact -Name 'wf2-only'   -AgeDays 1 -Workflow 'wf-2' -Ordinal 1)
        )
        $plan = Get-ArtifactDeletionPlan -Artifacts $arts -MaxAgeDays 30 -KeepLatestPerWorkflow 1
        $plan.Delete.Name | Should -Contain 'old-wf1-1'
        $plan.Delete.Name | Should -Contain 'wf1-extra'
        $plan.Retain.Name | Should -Contain 'wf1-new'
        $plan.Retain.Name | Should -Contain 'wf2-only'
    }
}

# ── Input validation ──────────────────────────────────────────────────────────
Describe 'Get-ArtifactDeletionPlan: input validation' {
    It 'throws when no policy parameters are provided' {
        { Get-ArtifactDeletionPlan -Artifacts @() } |
            Should -Throw -ExpectedMessage '*at least one retention policy*'
    }
}

# ── Invoke-ArtifactCleanup: dry-run ───────────────────────────────────────────
Describe 'Invoke-ArtifactCleanup: DryRun mode' {
    It 'does not call the Deleter scriptblock when -DryRun is set' {
        $arts = @(
            (New-MockArtifact -Name 'stale' -AgeDays 90 -Size 500),
            (New-MockArtifact -Name 'fresh' -AgeDays  1 -Size 200)
        )
        $callCount = 0
        $deleter = { param($a) $script:callCount++ }

        $result = Invoke-ArtifactCleanup -Artifacts $arts -MaxAgeDays 30 `
                    -Deleter $deleter -DryRun
        $callCount          | Should -Be 0
        $result.DryRun      | Should -BeTrue
        $result.Summary.DeletedCount | Should -Be 1
    }

    It 'calls the Deleter once per artifact when not in DryRun' {
        $arts = @(
            (New-MockArtifact -Name 'old1' -AgeDays 60 -Size 100),
            (New-MockArtifact -Name 'old2' -AgeDays 70 -Size 100)
        )
        $deleted = [System.Collections.Generic.List[string]]::new()
        $deleter = { param($a) $deleted.Add($a.Name) }

        $null = Invoke-ArtifactCleanup -Artifacts $arts -MaxAgeDays 30 -Deleter $deleter
        ($deleted | Sort-Object) | Should -Be @('old1', 'old2')
    }
}

# ── Workflow-structure tests ──────────────────────────────────────────────────
# These verify the YAML file exists and has the expected shape.
Describe 'Workflow YAML structure' {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot '..' '.github' 'workflows' 'artifact-cleanup-script.yml'
    }

    It 'workflow file exists on disk' {
        $WorkflowPath | Should -Exist
    }

    It 'workflow YAML references the PowerShell module file' {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match 'ArtifactCleanup'
    }

    It 'workflow has pwsh shell steps' {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match 'shell:\s*pwsh'
    }

    It 'workflow uses actions/checkout' {
        $content = Get-Content $WorkflowPath -Raw
        $content | Should -Match 'actions/checkout'
    }

    It 'actionlint reports no errors' {
        $out = actionlint $WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $out"
    }
}
