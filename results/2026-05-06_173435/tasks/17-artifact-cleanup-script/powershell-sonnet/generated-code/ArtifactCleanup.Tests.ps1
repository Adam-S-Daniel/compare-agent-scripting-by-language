# ArtifactCleanup.Tests.ps1
#
# TDD approach (red/green/refactor):
#   Iteration 1 — New-Artifact: test fails (no function), implement, pass.
#   Iteration 2 — Max-age policy: tests fail, implement Get-DeletionPlan age branch, pass.
#   Iteration 3 — Max-total-size policy: tests fail, implement size branch, pass.
#   Iteration 4 — Keep-latest-N policy: tests fail, implement keep-N branch, pass.
#   Iteration 5 — Combined policies: tests fail, ensure union logic correct, pass.
#   Iteration 6 — Dry-run mode: tests fail, add IsDryRun flag, pass.
#   Iteration 7 — Invoke-ArtifactCleanup wrapper: tests fail, implement wrapper, pass.
#   Iteration 8 — Workflow structure: validate YAML triggers, paths, actionlint.
#
# All tests emit TESTRESULT markers so run-tests.sh can assert exact expected values.

BeforeAll {
    . "$PSScriptRoot/ArtifactCleanup.ps1"
    # Fixed reference date for reproducible test assertions
    $script:Ref = [DateTime]::Parse("2026-05-07")
}

# ===========================================================================
# Iteration 1: New-Artifact
# Red: New-Artifact does not exist => NameError
# Green: add function with required params
# ===========================================================================
Describe "New-Artifact" {
    It "creates artifact with all required properties" {
        $a = New-Artifact -Name "build-output" -SizeMB 100 `
            -CreatedAt $script:Ref.AddDays(-5) -WorkflowRunId "run-001"
        $a.Name          | Should -Be "build-output"
        $a.SizeMB        | Should -Be 100
        $a.WorkflowRunId | Should -Be "run-001"
        $a.IsDeleted     | Should -Be $false
    }

    It "stores the CreatedAt datetime exactly" {
        $dt = $script:Ref.AddDays(-10)
        $a = New-Artifact -Name "x" -SizeMB 50 -CreatedAt $dt -WorkflowRunId "r1"
        $a.CreatedAt | Should -Be $dt
    }

    It "throws when Name is missing" {
        { New-Artifact -SizeMB 50 -CreatedAt $script:Ref -WorkflowRunId "r1" } |
            Should -Throw
    }

    It "throws when SizeMB is missing" {
        { New-Artifact -Name "x" -CreatedAt $script:Ref -WorkflowRunId "r1" } |
            Should -Throw
    }
}

# ===========================================================================
# Iteration 2: Max-age policy
# Fixture: 5 artifacts; 2 older than 30 days.
# Reference date 2026-05-07; cutoff = 2026-04-07.
#   artifact-old-1:    created 2026-04-01 (36d) => DELETE  100 MB
#   artifact-recent-1: created 2026-04-15 (22d) => KEEP    150 MB
#   artifact-old-2:    created 2026-03-01 (67d) => DELETE  200 MB
#   artifact-recent-2: created 2026-05-01  (6d) => KEEP     50 MB
#   artifact-recent-3: created 2026-05-06  (1d) => KEEP     75 MB
# Expected: deleted=2, retained=3, space_mb=300
# ===========================================================================
Describe "Get-DeletionPlan - Max-Age Policy" {
    BeforeAll {
        $script:AgeArtifacts = @(
            New-Artifact -Name "artifact-old-1"    -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-04-01")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact-recent-1" -SizeMB 150 -CreatedAt ([DateTime]::Parse("2026-04-15")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact-old-2"    -SizeMB 200 -CreatedAt ([DateTime]::Parse("2026-03-01")) -WorkflowRunId "run-002"
            New-Artifact -Name "artifact-recent-2" -SizeMB  50 -CreatedAt ([DateTime]::Parse("2026-05-01")) -WorkflowRunId "run-002"
            New-Artifact -Name "artifact-recent-3" -SizeMB  75 -CreatedAt ([DateTime]::Parse("2026-05-06")) -WorkflowRunId "run-003"
        )
        $script:AgePlan = Get-DeletionPlan -Artifacts $script:AgeArtifacts `
            -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref
    }

    It "marks exactly 2 artifacts for deletion" {
        $script:AgePlan.ArtifactsToDelete | Should -HaveCount 2
    }

    It "deletes artifact-old-1 (36 days old)" {
        $script:AgePlan.ArtifactsToDelete.Name | Should -Contain "artifact-old-1"
    }

    It "deletes artifact-old-2 (67 days old)" {
        $script:AgePlan.ArtifactsToDelete.Name | Should -Contain "artifact-old-2"
    }

    It "retains exactly 3 artifacts" {
        $script:AgePlan.ArtifactsToRetain | Should -HaveCount 3
    }

    It "retains artifact-recent-1 (22 days old)" {
        $script:AgePlan.ArtifactsToRetain.Name | Should -Contain "artifact-recent-1"
    }

    It "summary reports 2 deleted, 3 retained, 300 MB reclaimed" {
        $s = $script:AgePlan.Summary
        $s.ArtifactsDeleted  | Should -Be 2
        $s.ArtifactsRetained | Should -Be 3
        $s.SpaceReclaimedMB  | Should -Be 300
    }

    It "IsDryRun is false when not specified" {
        $script:AgePlan.IsDryRun | Should -Be $false
    }

    AfterAll {
        $p = $script:AgePlan
        Write-Host ("TESTRESULT|max-age-policy|deleted={0}|retained={1}|space_mb={2}" -f
            $p.Summary.ArtifactsDeleted,
            $p.Summary.ArtifactsRetained,
            [int]$p.Summary.SpaceReclaimedMB)
    }
}

# ===========================================================================
# Iteration 3: Max-total-size policy
# Fixture: 5 recent artifacts (all < 30 days), total = 550 MB.
# Policy: MaxTotalSizeMB = 400 => delete oldest first until total <= 400.
#   artifact-c: 50 MB, created 2026-04-09 (28d) — oldest  => DELETE first
#   artifact-a: 100 MB, created 2026-04-12 (25d)           => DELETE second
#   artifact-b: 200 MB, created 2026-04-17 (20d)           => KEEP
#   artifact-d: 75 MB,  created 2026-04-22 (15d)           => KEEP
#   artifact-e: 125 MB, created 2026-04-27 (10d) — newest  => KEEP
# After deleting c (50): total = 500 > 400. Delete a (100): total = 400 = limit. Stop.
# Expected: deleted=2, retained=3, space_mb=150
# ===========================================================================
Describe "Get-DeletionPlan - Max-Total-Size Policy" {
    BeforeAll {
        $script:SizeArtifacts = @(
            New-Artifact -Name "artifact-a" -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-04-12")) -WorkflowRunId "run-010"
            New-Artifact -Name "artifact-b" -SizeMB 200 -CreatedAt ([DateTime]::Parse("2026-04-17")) -WorkflowRunId "run-010"
            New-Artifact -Name "artifact-c" -SizeMB  50 -CreatedAt ([DateTime]::Parse("2026-04-09")) -WorkflowRunId "run-010"
            New-Artifact -Name "artifact-d" -SizeMB  75 -CreatedAt ([DateTime]::Parse("2026-04-22")) -WorkflowRunId "run-011"
            New-Artifact -Name "artifact-e" -SizeMB 125 -CreatedAt ([DateTime]::Parse("2026-04-27")) -WorkflowRunId "run-011"
        )
        $script:SizePlan = Get-DeletionPlan -Artifacts $script:SizeArtifacts `
            -Policy @{ MaxTotalSizeMB = 400 } -ReferenceDate $script:Ref
    }

    It "deletes the 2 oldest artifacts to bring total under limit" {
        $script:SizePlan.ArtifactsToDelete | Should -HaveCount 2
    }

    It "deletes artifact-c (oldest, 50 MB)" {
        $script:SizePlan.ArtifactsToDelete.Name | Should -Contain "artifact-c"
    }

    It "deletes artifact-a (second oldest, 100 MB)" {
        $script:SizePlan.ArtifactsToDelete.Name | Should -Contain "artifact-a"
    }

    It "retains 3 artifacts" {
        $script:SizePlan.ArtifactsToRetain | Should -HaveCount 3
    }

    It "summary: 2 deleted, 3 retained, 150 MB reclaimed" {
        $s = $script:SizePlan.Summary
        $s.ArtifactsDeleted  | Should -Be 2
        $s.ArtifactsRetained | Should -Be 3
        $s.SpaceReclaimedMB  | Should -Be 150
    }

    AfterAll {
        $p = $script:SizePlan
        Write-Host ("TESTRESULT|max-size-policy|deleted={0}|retained={1}|space_mb={2}" -f
            $p.Summary.ArtifactsDeleted,
            $p.Summary.ArtifactsRetained,
            [int]$p.Summary.SpaceReclaimedMB)
    }
}

# ===========================================================================
# Iteration 4: Keep-latest-N-per-workflow policy
# Fixture: 3 artifacts in run-001, 3 in run-002; KeepLatestNPerWorkflow=2.
#   run-001: artifact1(Apr-01,100MB), artifact2(Apr-10,150MB), artifact3(May-01,75MB)
#     Keep: artifact3, artifact2 (newest 2); Delete: artifact1
#   run-002: artifact4(Mar-15,80MB), artifact5(Apr-20,90MB), artifact6(May-05,110MB)
#     Keep: artifact6, artifact5 (newest 2); Delete: artifact4
# Expected: deleted=2, retained=4, space_mb=180
# ===========================================================================
Describe "Get-DeletionPlan - Keep-Latest-N Policy" {
    BeforeAll {
        $script:KeepNArtifacts = @(
            New-Artifact -Name "artifact1" -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-04-01")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact2" -SizeMB 150 -CreatedAt ([DateTime]::Parse("2026-04-10")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact3" -SizeMB  75 -CreatedAt ([DateTime]::Parse("2026-05-01")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact4" -SizeMB  80 -CreatedAt ([DateTime]::Parse("2026-03-15")) -WorkflowRunId "run-002"
            New-Artifact -Name "artifact5" -SizeMB  90 -CreatedAt ([DateTime]::Parse("2026-04-20")) -WorkflowRunId "run-002"
            New-Artifact -Name "artifact6" -SizeMB 110 -CreatedAt ([DateTime]::Parse("2026-05-05")) -WorkflowRunId "run-002"
        )
        $script:KeepNPlan = Get-DeletionPlan -Artifacts $script:KeepNArtifacts `
            -Policy @{ KeepLatestNPerWorkflow = 2 } -ReferenceDate $script:Ref
    }

    It "deletes 2 artifacts (oldest from each run)" {
        $script:KeepNPlan.ArtifactsToDelete | Should -HaveCount 2
    }

    It "deletes artifact1 (oldest in run-001)" {
        $script:KeepNPlan.ArtifactsToDelete.Name | Should -Contain "artifact1"
    }

    It "deletes artifact4 (oldest in run-002)" {
        $script:KeepNPlan.ArtifactsToDelete.Name | Should -Contain "artifact4"
    }

    It "retains 4 artifacts" {
        $script:KeepNPlan.ArtifactsToRetain | Should -HaveCount 4
    }

    It "retains the two newest from run-001" {
        $names = $script:KeepNPlan.ArtifactsToRetain.Name
        $names | Should -Contain "artifact2"
        $names | Should -Contain "artifact3"
    }

    It "summary: 2 deleted, 4 retained, 180 MB reclaimed" {
        $s = $script:KeepNPlan.Summary
        $s.ArtifactsDeleted  | Should -Be 2
        $s.ArtifactsRetained | Should -Be 4
        $s.SpaceReclaimedMB  | Should -Be 180
    }

    AfterAll {
        $p = $script:KeepNPlan
        Write-Host ("TESTRESULT|keep-latest-n|deleted={0}|retained={1}|space_mb={2}" -f
            $p.Summary.ArtifactsDeleted,
            $p.Summary.ArtifactsRetained,
            [int]$p.Summary.SpaceReclaimedMB)
    }
}

# ===========================================================================
# Iteration 5: Combined policies (MaxAgeDays + KeepLatestNPerWorkflow union)
# Fixture: 5 artifacts across 2 runs.
#   artifact1: 100MB, Apr-01 (36d ago), run-001  => age policy DELETE
#   artifact2: 150MB, Apr-15 (22d ago), run-001  => keep-N DELETE (not latest)
#   artifact3:  75MB, May-01  (6d ago), run-001  => KEEP (latest in run-001)
#   artifact4:  80MB, Mar-15 (53d ago), run-002  => age policy DELETE
#   artifact5:  90MB, May-05  (2d ago), run-002  => KEEP (latest in run-002)
# Policy: MaxAgeDays=30, KeepLatestNPerWorkflow=1
# Union of deletions: artifact1(age), artifact2(keep-N), artifact4(age+keep-N)
# Expected: deleted=3, retained=2, space_mb=330
# ===========================================================================
Describe "Get-DeletionPlan - Combined Policies" {
    BeforeAll {
        $script:CombinedArtifacts = @(
            New-Artifact -Name "combined-a1" -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-04-01")) -WorkflowRunId "run-001"
            New-Artifact -Name "combined-a2" -SizeMB 150 -CreatedAt ([DateTime]::Parse("2026-04-15")) -WorkflowRunId "run-001"
            New-Artifact -Name "combined-a3" -SizeMB  75 -CreatedAt ([DateTime]::Parse("2026-05-01")) -WorkflowRunId "run-001"
            New-Artifact -Name "combined-a4" -SizeMB  80 -CreatedAt ([DateTime]::Parse("2026-03-15")) -WorkflowRunId "run-002"
            New-Artifact -Name "combined-a5" -SizeMB  90 -CreatedAt ([DateTime]::Parse("2026-05-05")) -WorkflowRunId "run-002"
        )
        $script:CombinedPlan = Get-DeletionPlan -Artifacts $script:CombinedArtifacts `
            -Policy @{ MaxAgeDays = 30; KeepLatestNPerWorkflow = 1 } `
            -ReferenceDate $script:Ref
    }

    It "deletes 3 artifacts" {
        $script:CombinedPlan.ArtifactsToDelete | Should -HaveCount 3
    }

    It "deletes combined-a1 (age > 30d)" {
        $script:CombinedPlan.ArtifactsToDelete.Name | Should -Contain "combined-a1"
    }

    It "deletes combined-a2 (not latest in run-001)" {
        $script:CombinedPlan.ArtifactsToDelete.Name | Should -Contain "combined-a2"
    }

    It "deletes combined-a4 (age > 30d and not latest in run-002)" {
        $script:CombinedPlan.ArtifactsToDelete.Name | Should -Contain "combined-a4"
    }

    It "retains 2 artifacts (the latest from each run)" {
        $script:CombinedPlan.ArtifactsToRetain | Should -HaveCount 2
    }

    It "summary: 3 deleted, 2 retained, 330 MB reclaimed" {
        $s = $script:CombinedPlan.Summary
        $s.ArtifactsDeleted  | Should -Be 3
        $s.ArtifactsRetained | Should -Be 2
        $s.SpaceReclaimedMB  | Should -Be 330
    }

    AfterAll {
        $p = $script:CombinedPlan
        Write-Host ("TESTRESULT|combined-policies|deleted={0}|retained={1}|space_mb={2}" -f
            $p.Summary.ArtifactsDeleted,
            $p.Summary.ArtifactsRetained,
            [int]$p.Summary.SpaceReclaimedMB)
    }
}

# ===========================================================================
# Iteration 6: Dry-run mode
# Same fixtures as max-age test, but with -DryRun switch.
# Expected: same deletion decisions, IsDryRun=True, artifacts NOT mutated.
# ===========================================================================
Describe "Get-DeletionPlan - Dry-Run Mode" {
    BeforeAll {
        $script:DryRunArtifacts = @(
            New-Artifact -Name "artifact-old-1"    -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-04-01")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact-recent-1" -SizeMB 150 -CreatedAt ([DateTime]::Parse("2026-04-15")) -WorkflowRunId "run-001"
            New-Artifact -Name "artifact-old-2"    -SizeMB 200 -CreatedAt ([DateTime]::Parse("2026-03-01")) -WorkflowRunId "run-002"
            New-Artifact -Name "artifact-recent-2" -SizeMB  50 -CreatedAt ([DateTime]::Parse("2026-05-01")) -WorkflowRunId "run-002"
            New-Artifact -Name "artifact-recent-3" -SizeMB  75 -CreatedAt ([DateTime]::Parse("2026-05-06")) -WorkflowRunId "run-003"
        )
        $script:DryRunPlan = Get-DeletionPlan -Artifacts $script:DryRunArtifacts `
            -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref -DryRun
    }

    It "IsDryRun is true" {
        $script:DryRunPlan.IsDryRun | Should -Be $true
    }

    It "identifies same 2 artifacts for deletion as non-dry-run" {
        $script:DryRunPlan.ArtifactsToDelete | Should -HaveCount 2
    }

    It "summary matches non-dry-run: 2 deleted, 3 retained, 300 MB" {
        $s = $script:DryRunPlan.Summary
        $s.ArtifactsDeleted  | Should -Be 2
        $s.ArtifactsRetained | Should -Be 3
        $s.SpaceReclaimedMB  | Should -Be 300
    }

    AfterAll {
        $p = $script:DryRunPlan
        Write-Host ("TESTRESULT|dry-run|deleted={0}|retained={1}|space_mb={2}|is_dry_run={3}" -f
            $p.Summary.ArtifactsDeleted,
            $p.Summary.ArtifactsRetained,
            [int]$p.Summary.SpaceReclaimedMB,
            $p.IsDryRun)
    }
}

# ===========================================================================
# Iteration 7: Invoke-ArtifactCleanup wrapper
# Non-dry-run: marks deleted artifacts with IsDeleted=true.
# Dry-run: does NOT mutate artifact objects.
# ===========================================================================
Describe "Invoke-ArtifactCleanup" {
    It "marks deleted artifacts as IsDeleted=true in execute mode" {
        $arts = @(
            New-Artifact -Name "old" -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-03-01")) -WorkflowRunId "r1"
            New-Artifact -Name "new" -SizeMB  50 -CreatedAt ([DateTime]::Parse("2026-05-06")) -WorkflowRunId "r1"
        )
        Invoke-ArtifactCleanup -Artifacts $arts `
            -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref -Confirm:$false | Out-Null
        ($arts | Where-Object Name -eq "old").IsDeleted  | Should -Be $true
        ($arts | Where-Object Name -eq "new").IsDeleted  | Should -Be $false
    }

    It "does NOT mutate artifacts in dry-run mode" {
        $arts = @(
            New-Artifact -Name "old" -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-03-01")) -WorkflowRunId "r1"
            New-Artifact -Name "new" -SizeMB  50 -CreatedAt ([DateTime]::Parse("2026-05-06")) -WorkflowRunId "r1"
        )
        Invoke-ArtifactCleanup -Artifacts $arts `
            -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref -DryRun | Out-Null
        ($arts | Where-Object Name -eq "old").IsDeleted | Should -Be $false
    }

    It "returns a plan with correct summary" {
        $arts = @(
            New-Artifact -Name "old" -SizeMB 200 -CreatedAt ([DateTime]::Parse("2026-03-01")) -WorkflowRunId "r1"
            New-Artifact -Name "new" -SizeMB 100 -CreatedAt ([DateTime]::Parse("2026-05-06")) -WorkflowRunId "r1"
        )
        $plan = Invoke-ArtifactCleanup -Artifacts $arts `
            -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref -Confirm:$false
        $plan.Summary.ArtifactsDeleted | Should -Be 1
        $plan.Summary.SpaceReclaimedMB | Should -Be 200
    }
}

# ===========================================================================
# Iteration 8: Edge cases
# ===========================================================================
Describe "Get-DeletionPlan - Edge Cases" {
    It "handles empty artifact list gracefully" {
        $plan = Get-DeletionPlan -Artifacts @() -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref
        $plan.Summary.TotalArtifacts    | Should -Be 0
        $plan.Summary.ArtifactsDeleted  | Should -Be 0
        $plan.ArtifactsToDelete         | Should -HaveCount 0
    }

    It "retains all artifacts when none exceed policies" {
        $arts = @(
            New-Artifact -Name "fresh1" -SizeMB 10 -CreatedAt $script:Ref.AddDays(-1) -WorkflowRunId "r1"
            New-Artifact -Name "fresh2" -SizeMB 10 -CreatedAt $script:Ref.AddDays(-2) -WorkflowRunId "r1"
        )
        $plan = Get-DeletionPlan -Artifacts $arts -Policy @{ MaxAgeDays = 30 } -ReferenceDate $script:Ref
        $plan.ArtifactsToDelete | Should -HaveCount 0
        $plan.ArtifactsToRetain | Should -HaveCount 2
    }

    It "does not delete anything when MaxTotalSizeMB is already satisfied" {
        $arts = @(
            New-Artifact -Name "a" -SizeMB 50 -CreatedAt $script:Ref.AddDays(-1) -WorkflowRunId "r1"
            New-Artifact -Name "b" -SizeMB 50 -CreatedAt $script:Ref.AddDays(-2) -WorkflowRunId "r1"
        )
        $plan = Get-DeletionPlan -Artifacts $arts -Policy @{ MaxTotalSizeMB = 200 } -ReferenceDate $script:Ref
        $plan.ArtifactsToDelete | Should -HaveCount 0
    }

    It "keeps all when KeepLatestN >= group size" {
        $arts = @(
            New-Artifact -Name "a1" -SizeMB 10 -CreatedAt $script:Ref.AddDays(-3) -WorkflowRunId "r1"
            New-Artifact -Name "a2" -SizeMB 10 -CreatedAt $script:Ref.AddDays(-1) -WorkflowRunId "r1"
        )
        $plan = Get-DeletionPlan -Artifacts $arts -Policy @{ KeepLatestNPerWorkflow = 5 } -ReferenceDate $script:Ref
        $plan.ArtifactsToDelete | Should -HaveCount 0
    }
}

# ===========================================================================
# Iteration 8: Workflow structure validation
# Parses the workflow YAML (as text) to verify required elements.
# ===========================================================================
Describe "Workflow Structure" {
    BeforeAll {
        $wfPath = "$PSScriptRoot/.github/workflows/artifact-cleanup-script.yml"
        $script:WfExists = Test-Path $wfPath
        $script:WfContent = if ($script:WfExists) { Get-Content $wfPath -Raw } else { "" }
    }

    It "workflow YAML file exists" {
        $script:WfExists | Should -Be $true
    }

    It "has push trigger" {
        $script:WfContent | Should -Match 'push:'
    }

    It "has pull_request trigger" {
        $script:WfContent | Should -Match 'pull_request:'
    }

    It "has schedule trigger" {
        $script:WfContent | Should -Match 'schedule:'
    }

    It "has workflow_dispatch trigger" {
        $script:WfContent | Should -Match 'workflow_dispatch'
    }

    It "uses actions/checkout@v4" {
        $script:WfContent | Should -Match 'actions/checkout@v4'
    }

    It "uses shell: pwsh for PowerShell steps" {
        $script:WfContent | Should -Match 'shell:\s*pwsh'
    }

    It "references ArtifactCleanup.ps1" {
        $script:WfContent | Should -Match 'ArtifactCleanup\.ps1'
    }

    It "references ArtifactCleanup.Tests.ps1" {
        $script:WfContent | Should -Match 'ArtifactCleanup\.Tests\.ps1'
    }

    It "ArtifactCleanup.ps1 exists on disk" {
        "$PSScriptRoot/ArtifactCleanup.ps1" | Should -Exist
    }

    It "ArtifactCleanup.Tests.ps1 exists on disk" {
        "$PSScriptRoot/ArtifactCleanup.Tests.ps1" | Should -Exist
    }
}
