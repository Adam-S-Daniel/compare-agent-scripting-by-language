# Pester tests for ArtifactCleanup module.
# Written TDD: each Describe/Context block was added as a failing test first,
# followed by the minimum implementation in ArtifactCleanup.psm1.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
    Import-Module $script:ModulePath -Force

    # Helper to build a synthetic artifact for tests. Defined in BeforeAll so
    # Pester v5 propagates it into every It block in this file.
    function New-TestArtifact {
        param(
            [string]$Name,
            [long]$SizeBytes,
            [datetime]$CreatedAt,
            [string]$WorkflowId,
            [int]$Id = 0
        )
        [pscustomobject]@{
            Id         = $Id
            Name       = $Name
            SizeBytes  = $SizeBytes
            CreatedAt  = $CreatedAt
            WorkflowId = $WorkflowId
        }
    }
}

AfterAll {
    Remove-Module ArtifactCleanup -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ArtifactCleanupPlan - basic shape' {
    It 'returns a plan object with Retained, Deleted, and Summary keys when given no artifacts' {
        $plan = Get-ArtifactCleanupPlan -Artifacts @() -MaxAgeDays 30
        $plan | Should -Not -BeNullOrEmpty
        # Empty collections pipe as no value to Should, so check the property
        # list structurally instead of piping the value itself.
        $plan.PSObject.Properties.Name | Should -Contain 'Retained'
        $plan.PSObject.Properties.Name | Should -Contain 'Deleted'
        $plan.PSObject.Properties.Name | Should -Contain 'Summary'
    }

    It 'returns empty Retained and Deleted arrays when given no artifacts' {
        $plan = Get-ArtifactCleanupPlan -Artifacts @() -MaxAgeDays 30
        @($plan.Retained).Count | Should -Be 0
        @($plan.Deleted).Count  | Should -Be 0
        $plan.Summary.SpaceReclaimedBytes | Should -Be 0
        $plan.Summary.RetainedCount       | Should -Be 0
        $plan.Summary.DeletedCount        | Should -Be 0
    }
}

Describe 'MaxAgeDays policy' {
    It 'marks artifacts older than MaxAgeDays for deletion' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'young'    -SizeBytes 100 -CreatedAt $now.AddDays(-5)  -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'old'      -SizeBytes 200 -CreatedAt $now.AddDays(-60) -WorkflowId 'w1'),
            (New-TestArtifact -Id 3 -Name 'ancient'  -SizeBytes 300 -CreatedAt $now.AddDays(-90) -WorkflowId 'w1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        @($plan.Deleted).Count  | Should -Be 2
        @($plan.Retained).Count | Should -Be 1
        ($plan.Retained | Select-Object -ExpandProperty Name) | Should -Be 'young'
    }

    It 'keeps all artifacts if none exceed MaxAgeDays' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'a' -SizeBytes 100 -CreatedAt $now.AddDays(-5) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'b' -SizeBytes 200 -CreatedAt $now.AddDays(-10) -WorkflowId 'w1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        @($plan.Deleted).Count  | Should -Be 0
        @($plan.Retained).Count | Should -Be 2
    }
}

Describe 'KeepLatestNPerWorkflow policy' {
    It 'keeps the N most recent artifacts per workflow even if older than MaxAgeDays' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'w1-old1' -SizeBytes 100 -CreatedAt $now.AddDays(-100) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'w1-old2' -SizeBytes 100 -CreatedAt $now.AddDays(-90)  -WorkflowId 'w1'),
            (New-TestArtifact -Id 3 -Name 'w1-old3' -SizeBytes 100 -CreatedAt $now.AddDays(-80)  -WorkflowId 'w1'),
            (New-TestArtifact -Id 4 -Name 'w1-old4' -SizeBytes 100 -CreatedAt $now.AddDays(-70)  -WorkflowId 'w1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestNPerWorkflow 2 -Now $now
        @($plan.Retained).Count | Should -Be 2
        @($plan.Deleted).Count  | Should -Be 2
        # The two newest (w1-old3, w1-old4) must be retained
        ($plan.Retained | Sort-Object Name | Select-Object -ExpandProperty Name) | Should -Be @('w1-old3','w1-old4')
    }

    It 'applies KeepLatestN independently per workflow' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'w1-a' -SizeBytes 100 -CreatedAt $now.AddDays(-50) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'w1-b' -SizeBytes 100 -CreatedAt $now.AddDays(-45) -WorkflowId 'w1'),
            (New-TestArtifact -Id 3 -Name 'w2-a' -SizeBytes 100 -CreatedAt $now.AddDays(-55) -WorkflowId 'w2'),
            (New-TestArtifact -Id 4 -Name 'w2-b' -SizeBytes 100 -CreatedAt $now.AddDays(-40) -WorkflowId 'w2')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -KeepLatestNPerWorkflow 1 -Now $now
        @($plan.Retained).Count | Should -Be 2
        ($plan.Retained | Sort-Object Name | Select-Object -ExpandProperty Name) | Should -Be @('w1-b','w2-b')
    }
}

Describe 'MaxTotalSizeBytes policy' {
    It 'deletes oldest artifacts to bring total size under the cap' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            # All within MaxAgeDays so only size policy applies
            (New-TestArtifact -Id 1 -Name 'oldest'   -SizeBytes 100 -CreatedAt $now.AddDays(-10) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'older'    -SizeBytes 100 -CreatedAt $now.AddDays(-8)  -WorkflowId 'w1'),
            (New-TestArtifact -Id 3 -Name 'newer'    -SizeBytes 100 -CreatedAt $now.AddDays(-5)  -WorkflowId 'w1'),
            (New-TestArtifact -Id 4 -Name 'newest'   -SizeBytes 100 -CreatedAt $now.AddDays(-1)  -WorkflowId 'w1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -MaxTotalSizeBytes 250 -Now $now
        # Total is 400; cap is 250; must delete oldest until cumulative size <= 250.
        # Retained (newest-first) cumulative: newest=100, newer=200 -> stop; older/oldest deleted.
        @($plan.Deleted).Count  | Should -Be 2
        @($plan.Retained).Count | Should -Be 2
        ($plan.Retained | Sort-Object Name | Select-Object -ExpandProperty Name) | Should -Be @('newer','newest')
    }

    It 'does nothing when total size is already under the cap' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'a' -SizeBytes 50 -CreatedAt $now.AddDays(-1) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'b' -SizeBytes 50 -CreatedAt $now.AddDays(-2) -WorkflowId 'w1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -MaxTotalSizeBytes 1000 -Now $now
        @($plan.Deleted).Count | Should -Be 0
    }
}

Describe 'Policy interaction: KeepLatestN protects from all deletion reasons' {
    It 'keeps latest-N even when size policy would otherwise delete them' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'w1-oldest' -SizeBytes 500 -CreatedAt $now.AddDays(-10) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'w1-newest' -SizeBytes 500 -CreatedAt $now.AddDays(-1)  -WorkflowId 'w1')
        )
        # Cap of 200 would normally force deletion of both; KeepLatestN=1 should still protect newest.
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -MaxTotalSizeBytes 200 -KeepLatestNPerWorkflow 1 -Now $now
        ($plan.Retained | Select-Object -ExpandProperty Name) | Should -Contain 'w1-newest'
    }
}

Describe 'Summary output' {
    It 'reports accurate counts and space reclaimed' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'old1' -SizeBytes 100 -CreatedAt $now.AddDays(-60) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'old2' -SizeBytes 250 -CreatedAt $now.AddDays(-45) -WorkflowId 'w1'),
            (New-TestArtifact -Id 3 -Name 'new1' -SizeBytes 50  -CreatedAt $now.AddDays(-1)  -WorkflowId 'w1')
        )
        $plan = Get-ArtifactCleanupPlan -Artifacts $artifacts -MaxAgeDays 30 -Now $now
        $plan.Summary.RetainedCount       | Should -Be 1
        $plan.Summary.DeletedCount        | Should -Be 2
        $plan.Summary.SpaceReclaimedBytes | Should -Be 350
        $plan.Summary.TotalSizeBytes      | Should -Be 400
    }
}

Describe 'Invoke-ArtifactCleanup (dry-run)' {
    It 'in dry-run mode returns the plan without invoking the delete action' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'old' -SizeBytes 100 -CreatedAt $now.AddDays(-60) -WorkflowId 'w1')
        )
        $script:deleteCalled = $false
        $deleter = {
            param($artifact)
            $script:deleteCalled = $true
        }
        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DryRun -DeleteAction $deleter
        $script:deleteCalled | Should -BeFalse
        @($plan.Deleted).Count | Should -Be 1
        $plan.DryRun | Should -BeTrue
    }

    It 'in non-dry-run mode invokes the delete action exactly once per deleted artifact' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'old1' -SizeBytes 100 -CreatedAt $now.AddDays(-60) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'old2' -SizeBytes 100 -CreatedAt $now.AddDays(-65) -WorkflowId 'w1'),
            (New-TestArtifact -Id 3 -Name 'new'  -SizeBytes 100 -CreatedAt $now.AddDays(-1)  -WorkflowId 'w1')
        )
        $script:deletedIds = @()
        $deleter = {
            param($artifact)
            $script:deletedIds += $artifact.Id
        }
        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DeleteAction $deleter
        $plan.DryRun | Should -BeFalse
        ($script:deletedIds | Sort-Object) | Should -Be @(1, 2)
    }

    It 'continues deleting remaining artifacts if the delete action throws for one' {
        $now = Get-Date '2026-04-17T00:00:00Z'
        $artifacts = @(
            (New-TestArtifact -Id 1 -Name 'old1' -SizeBytes 100 -CreatedAt $now.AddDays(-60) -WorkflowId 'w1'),
            (New-TestArtifact -Id 2 -Name 'old2' -SizeBytes 100 -CreatedAt $now.AddDays(-61) -WorkflowId 'w1')
        )
        $script:attempted = @()
        $deleter = {
            param($artifact)
            $script:attempted += $artifact.Id
            if ($artifact.Id -eq 1) { throw 'simulated API failure' }
        }
        $plan = Invoke-ArtifactCleanup -Artifacts $artifacts -MaxAgeDays 30 -Now $now -DeleteAction $deleter -ErrorAction SilentlyContinue
        ($script:attempted | Sort-Object) | Should -Be @(1, 2)
        $plan.Errors.Count | Should -Be 1
    }
}

Describe 'Error handling and input validation' {
    It 'throws a clear error when MaxAgeDays is negative' {
        { Get-ArtifactCleanupPlan -Artifacts @() -MaxAgeDays -1 } |
            Should -Throw -ExpectedMessage '*MaxAgeDays*'
    }

    It 'throws a clear error when MaxTotalSizeBytes is negative' {
        { Get-ArtifactCleanupPlan -Artifacts @() -MaxAgeDays 30 -MaxTotalSizeBytes -1 } |
            Should -Throw -ExpectedMessage '*MaxTotalSizeBytes*'
    }

    It 'throws a clear error when KeepLatestNPerWorkflow is negative' {
        { Get-ArtifactCleanupPlan -Artifacts @() -MaxAgeDays 30 -KeepLatestNPerWorkflow -1 } |
            Should -Throw -ExpectedMessage '*KeepLatestNPerWorkflow*'
    }

    It 'throws a clear error when an artifact is missing a required field' {
        $bad = [pscustomobject]@{ Id = 1; Name = 'x' } # no SizeBytes/CreatedAt/WorkflowId
        { Get-ArtifactCleanupPlan -Artifacts @($bad) -MaxAgeDays 30 } |
            Should -Throw -ExpectedMessage '*SizeBytes*'
    }
}

Describe 'Read-ArtifactsFromJson' {
    It 'parses an artifacts JSON file into objects with typed fields' {
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "artifacts-$(New-Guid).json"
        try {
            @'
[
  { "id": 1, "name": "a", "sizeBytes": 100, "createdAt": "2026-01-01T00:00:00Z", "workflowId": "w1" },
  { "id": 2, "name": "b", "sizeBytes": 200, "createdAt": "2026-02-01T00:00:00Z", "workflowId": "w2" }
]
'@ | Set-Content -Path $tempFile -Encoding UTF8
            $artifacts = Read-ArtifactsFromJson -Path $tempFile
            @($artifacts).Count | Should -Be 2
            $artifacts[0].SizeBytes  | Should -BeOfType [long]
            $artifacts[0].CreatedAt  | Should -BeOfType [datetime]
            $artifacts[0].WorkflowId | Should -Be 'w1'
        } finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when the JSON file does not exist' {
        { Read-ArtifactsFromJson -Path '/tmp/definitely-not-there-xyz.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}
