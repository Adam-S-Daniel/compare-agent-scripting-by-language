# Pester tests for the ArtifactCleanup module.
#
# We follow strict red/green TDD: each Describe/It block was added by first
# observing it fail (red), then making it pass with the smallest feasible
# change in src/ArtifactCleanup.psm1 (green), then refactoring as needed.
#
# Run with: Invoke-Pester -Path ./tests/ArtifactCleanup.Tests.ps1

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # Helper: build an artifact object with sane defaults so each test can
    # express only the fields it cares about.
    function script:New-TestArtifact {
        param(
            [string]$Name,
            [long]$Size = 1MB,
            [datetime]$CreatedAt = (Get-Date),
            [string]$WorkflowRunId = 'wf-default'
        )
        [pscustomobject]@{
            name          = $Name
            size          = $Size
            createdAt     = $CreatedAt.ToString('o')
            workflowRunId = $WorkflowRunId
        }
    }
}

Describe 'Get-CleanupPlan - basic shape' {
    It 'returns an object with empty toDelete/toRetain when given no artifacts' {
        $plan = Get-CleanupPlan -Artifacts @() -Policy @{}

        $plan | Should -Not -BeNullOrEmpty
        # PowerShell unwraps empty arrays in property access, so we use
        # @() to coerce back into an array before counting.
        @($plan.toDelete).Count | Should -Be 0
        @($plan.toRetain).Count | Should -Be 0
        $plan.totalReclaimedBytes | Should -Be 0
        $plan.totalRetainedBytes | Should -Be 0
        $plan.dryRun | Should -BeTrue
    }

    It 'retains every artifact when no policies apply' {
        $artifacts = @(
            New-TestArtifact -Name 'a' -Size 100
            New-TestArtifact -Name 'b' -Size 200
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{}

        @($plan.toDelete).Count | Should -Be 0
        @($plan.toRetain).Count | Should -Be 2
        $plan.totalRetainedBytes | Should -Be 300
        $plan.totalReclaimedBytes | Should -Be 0
    }
}

Describe 'Get-CleanupPlan - maxAgeDays policy' {
    It 'deletes artifacts older than maxAgeDays' {
        $now = Get-Date
        $artifacts = @(
            New-TestArtifact -Name 'old'    -Size 100 -CreatedAt $now.AddDays(-40)
            New-TestArtifact -Name 'recent' -Size 200 -CreatedAt $now.AddDays(-10)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{ maxAgeDays = 30 }

        @($plan.toDelete).Count | Should -Be 1
        @($plan.toDelete)[0].name | Should -Be 'old'
        @($plan.toRetain).Count | Should -Be 1
        @($plan.toRetain)[0].name | Should -Be 'recent'
        $plan.totalReclaimedBytes | Should -Be 100
        $plan.totalRetainedBytes  | Should -Be 200
    }

    It 'treats artifact exactly at the boundary as still within retention' {
        $now = Get-Date
        # The artifact is exactly 30 days old; "older than" means strictly greater.
        $artifacts = @(
            New-TestArtifact -Name 'edge' -Size 50 -CreatedAt $now.AddDays(-30)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{ maxAgeDays = 30 }

        @($plan.toDelete).Count | Should -Be 0
        @($plan.toRetain).Count | Should -Be 1
    }
}

Describe 'Get-CleanupPlan - keepLatestPerWorkflow policy' {
    It 'retains the N most recent artifacts per workflow run, deletes the rest' {
        $now = Get-Date
        $artifacts = @(
            New-TestArtifact -Name 'wf1-old'    -Size 10 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-5)
            New-TestArtifact -Name 'wf1-mid'    -Size 20 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-3)
            New-TestArtifact -Name 'wf1-newest' -Size 30 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-1)
            New-TestArtifact -Name 'wf2-only'   -Size 40 -WorkflowRunId 'wf2' -CreatedAt $now.AddDays(-2)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{ keepLatestPerWorkflow = 2 }

        @($plan.toDelete).Count | Should -Be 1
        @($plan.toDelete)[0].name | Should -Be 'wf1-old'
        @($plan.toRetain).Count | Should -Be 3
        ($plan.toRetain.name | Sort-Object) -join ',' | Should -Be 'wf1-mid,wf1-newest,wf2-only'
    }

    It 'protects keep-latest artifacts even when they are older than maxAgeDays' {
        $now = Get-Date
        # Both artifacts are 90 days old but they are the latest 2 per workflow.
        # keepLatestPerWorkflow takes precedence over maxAgeDays.
        $artifacts = @(
            New-TestArtifact -Name 'wf1-a' -Size 1 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-90)
            New-TestArtifact -Name 'wf1-b' -Size 1 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-91)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{
            maxAgeDays            = 30
            keepLatestPerWorkflow = 2
        }

        @($plan.toDelete).Count | Should -Be 0
        @($plan.toRetain).Count | Should -Be 2
    }

    It 'keepLatestPerWorkflow=0 disables protection' {
        $now = Get-Date
        $artifacts = @(
            New-TestArtifact -Name 'old' -Size 1 -CreatedAt $now.AddDays(-90)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{
            maxAgeDays            = 30
            keepLatestPerWorkflow = 0
        }

        @($plan.toDelete).Count | Should -Be 1
    }
}

Describe 'Get-CleanupPlan - maxTotalSize policy' {
    It 'deletes oldest artifacts until retained size fits the cap' {
        $now = Get-Date
        # 4 artifacts of 100 bytes each = 400 total. Cap = 250 → must delete
        # the two oldest non-protected to stay <= 250.
        $artifacts = @(
            New-TestArtifact -Name 'oldest' -Size 100 -CreatedAt $now.AddDays(-4)
            New-TestArtifact -Name 'older'  -Size 100 -CreatedAt $now.AddDays(-3)
            New-TestArtifact -Name 'newer'  -Size 100 -CreatedAt $now.AddDays(-2)
            New-TestArtifact -Name 'newest' -Size 100 -CreatedAt $now.AddDays(-1)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{ maxTotalSize = 250 }

        $plan.totalRetainedBytes | Should -BeLessOrEqual 250
        @($plan.toDelete).Count | Should -Be 2
        # Eviction is from the oldest end first.
        ($plan.toDelete.name | Sort-Object) -join ',' | Should -Be 'older,oldest'
        ($plan.toRetain.name | Sort-Object) -join ',' | Should -Be 'newer,newest'
    }

    It 'reports cap could not be satisfied when only protected items remain' {
        $now = Get-Date
        $artifacts = @(
            New-TestArtifact -Name 'a' -Size 100 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-2)
            New-TestArtifact -Name 'b' -Size 100 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-1)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{
            maxTotalSize          = 50
            keepLatestPerWorkflow = 2
        }

        $plan.totalRetainedBytes | Should -BeGreaterThan 50
    }

    It 'never evicts protected (keep-latest) artifacts even if cap is exceeded' {
        $now = Get-Date
        # Two artifacts of 100B each, both top-2 of wf1 → both protected.
        # Cap = 50 (smaller than either). Plan must respect the protection
        # and report retained > cap (the script signals that the cap could
        # not be satisfied).
        $artifacts = @(
            New-TestArtifact -Name 'a' -Size 100 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-2)
            New-TestArtifact -Name 'b' -Size 100 -WorkflowRunId 'wf1' -CreatedAt $now.AddDays(-1)
        )

        $plan = Get-CleanupPlan -Artifacts $artifacts -Policy @{
            maxTotalSize          = 50
            keepLatestPerWorkflow = 2
        }

        @($plan.toDelete).Count | Should -Be 0
        @($plan.toRetain).Count | Should -Be 2
        $plan.totalRetainedBytes | Should -Be 200
    }
}

Describe 'Invoke-CleanupPlan - dry-run vs commit' {
    It 'never calls the delete action when plan.dryRun is $true' {
        $now = Get-Date
        $plan = Get-CleanupPlan -Artifacts @(
            New-TestArtifact -Name 'old' -Size 1 -CreatedAt $now.AddDays(-90)
        ) -Policy @{ maxAgeDays = 30 } -DryRun $true

        $script:deleted = New-Object System.Collections.Generic.List[string]
        $action = { param($a) $script:deleted.Add($a.name) }

        $result = Invoke-CleanupPlan -Plan $plan -DeleteAction $action

        $script:deleted.Count | Should -Be 0
        $result.deletedActuallyCount | Should -Be 0
        $result.dryRun | Should -BeTrue
    }

    It 'calls the delete action once per artifact when not in dry-run' {
        $now = Get-Date
        $plan = Get-CleanupPlan -Artifacts @(
            New-TestArtifact -Name 'old1' -Size 1 -CreatedAt $now.AddDays(-90)
            New-TestArtifact -Name 'old2' -Size 1 -CreatedAt $now.AddDays(-90)
        ) -Policy @{ maxAgeDays = 30 } -DryRun $false

        $script:deleted = New-Object System.Collections.Generic.List[string]
        $action = { param($a) $script:deleted.Add($a.name) }

        $result = Invoke-CleanupPlan -Plan $plan -DeleteAction $action

        ($script:deleted | Sort-Object) -join ',' | Should -Be 'old1,old2'
        $result.deletedActuallyCount | Should -Be 2
        $result.dryRun | Should -BeFalse
    }
}

Describe 'Get-CleanupPlan - input validation' {
    It 'throws when an artifact is missing required field createdAt' {
        $bad = @([pscustomobject]@{ name = 'x'; size = 1; workflowRunId = 'wf' })
        { Get-CleanupPlan -Artifacts $bad -Policy @{ maxAgeDays = 30 } } |
            Should -Throw '*createdAt*'
    }

    It 'throws when policy maxAgeDays is negative' {
        { Get-CleanupPlan -Artifacts @() -Policy @{ maxAgeDays = -5 } } |
            Should -Throw '*maxAgeDays*'
    }

    It 'throws when policy maxTotalSize is negative' {
        { Get-CleanupPlan -Artifacts @() -Policy @{ maxTotalSize = -1 } } |
            Should -Throw '*maxTotalSize*'
    }
}

Describe 'Format-CleanupSummary - human-readable output' {
    It 'produces a summary string containing reclaimed/retained counts and bytes' {
        $now = Get-Date
        $plan = Get-CleanupPlan -Artifacts @(
            New-TestArtifact -Name 'kept' -Size 100 -CreatedAt $now.AddDays(-1)
            New-TestArtifact -Name 'gone' -Size 200 -CreatedAt $now.AddDays(-90)
        ) -Policy @{ maxAgeDays = 30 }

        $summary = Format-CleanupSummary -Plan $plan

        $summary | Should -Match 'retained: 1'
        $summary | Should -Match 'deleted: 1'
        $summary | Should -Match 'reclaimed: 200'
        $summary | Should -Match 'DRY-RUN'
    }
}
