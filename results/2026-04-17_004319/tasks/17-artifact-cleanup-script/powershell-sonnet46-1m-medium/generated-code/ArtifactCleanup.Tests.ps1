#Requires -Modules Pester

# Artifact Cleanup Script - Pester Test Suite
# Uses red/green TDD: tests written first, then implementation added to pass them.
# Tags: "Unit" tests run inside the GitHub Actions workflow via act.
#       "Integration" tests run locally and invoke act to verify the workflow.

BeforeAll {
    # Dot-source the script so its functions are available
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    # Helper to build artifact objects consistently
    function New-TestArtifact {
        param(
            [string]$Name,
            [long]$SizeBytes,
            [int]$DaysOld,
            [string]$WorkflowRunId = "wf-default"
        )
        [PSCustomObject]@{
            Name          = $Name
            SizeBytes     = $SizeBytes
            CreatedAt     = (Get-Date).AddDays(-$DaysOld)
            WorkflowRunId = $WorkflowRunId
        }
    }
}

# ─────────────────────────────────────────────────────────────
# Unit Tests: Max-Age Policy
# ─────────────────────────────────────────────────────────────
Describe "Get-ArtifactDeletionPlan - Max Age Policy" -Tag "Unit" {

    It "marks artifacts older than MaxAgeDays for deletion" {
        $artifacts = @(
            (New-TestArtifact -Name "artifact-fresh"  -SizeBytes 104857600 -DaysOld 5  -WorkflowRunId "wf-1"),
            (New-TestArtifact -Name "artifact-medium" -SizeBytes 209715200 -DaysOld 20 -WorkflowRunId "wf-1"),
            (New-TestArtifact -Name "artifact-old"    -SizeBytes 314572800 -DaysOld 40 -WorkflowRunId "wf-2")
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeBytes = 0; KeepLatestN = 0 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count        | Should -Be 1
        $plan.ToDelete[0].Name      | Should -Be "artifact-old"
        $plan.ToRetain.Count        | Should -Be 2
        $plan.SpaceReclaimedBytes   | Should -Be 314572800
    }

    It "retains all artifacts when none exceed MaxAgeDays" {
        $artifacts = @(
            (New-TestArtifact -Name "art-a" -SizeBytes 50000000 -DaysOld 1),
            (New-TestArtifact -Name "art-b" -SizeBytes 50000000 -DaysOld 10)
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeBytes = 0; KeepLatestN = 0 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count      | Should -Be 0
        $plan.ToRetain.Count      | Should -Be 2
        $plan.SpaceReclaimedBytes | Should -Be 0
    }

    It "handles an empty artifact list gracefully" {
        $plan = Get-ArtifactDeletionPlan -Artifacts @() -Policy @{ MaxAgeDays = 30; MaxTotalSizeBytes = 0; KeepLatestN = 0 }

        $plan.ToDelete.Count      | Should -Be 0
        $plan.ToRetain.Count      | Should -Be 0
        $plan.SpaceReclaimedBytes | Should -Be 0
    }

    It "skips max-age check when MaxAgeDays is 0" {
        $artifacts = @(
            (New-TestArtifact -Name "very-old" -SizeBytes 100000000 -DaysOld 365)
        )
        $policy = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 0; KeepLatestN = 0 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count | Should -Be 0
    }
}

# ─────────────────────────────────────────────────────────────
# Unit Tests: Keep-Latest-N Policy
# ─────────────────────────────────────────────────────────────
Describe "Get-ArtifactDeletionPlan - Keep-Latest-N Policy" -Tag "Unit" {

    It "keeps only the N newest artifacts per workflow run ID" {
        $artifacts = @(
            (New-TestArtifact -Name "build-001" -SizeBytes  52428800 -DaysOld 1 -WorkflowRunId "wf-abc"),
            (New-TestArtifact -Name "build-002" -SizeBytes 104857600 -DaysOld 3 -WorkflowRunId "wf-abc"),
            (New-TestArtifact -Name "build-003" -SizeBytes 157286400 -DaysOld 5 -WorkflowRunId "wf-abc"),
            (New-TestArtifact -Name "build-004" -SizeBytes 209715200 -DaysOld 7 -WorkflowRunId "wf-abc")
        )
        $policy = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 0; KeepLatestN = 2 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count        | Should -Be 2
        $plan.ToRetain.Count        | Should -Be 2
        # The two oldest (7d and 5d) should be deleted
        ($plan.ToDelete | Where-Object Name -EQ "build-004") | Should -Not -BeNullOrEmpty
        ($plan.ToDelete | Where-Object Name -EQ "build-003") | Should -Not -BeNullOrEmpty
        # Space reclaimed = 157286400 + 209715200 = 367001600
        $plan.SpaceReclaimedBytes | Should -Be 367001600
    }

    It "applies keep-latest-N independently per workflow run ID" {
        $artifacts = @(
            (New-TestArtifact -Name "wf1-a" -SizeBytes 10000000 -DaysOld 1 -WorkflowRunId "wf-1"),
            (New-TestArtifact -Name "wf1-b" -SizeBytes 10000000 -DaysOld 5 -WorkflowRunId "wf-1"),
            (New-TestArtifact -Name "wf2-a" -SizeBytes 20000000 -DaysOld 2 -WorkflowRunId "wf-2"),
            (New-TestArtifact -Name "wf2-b" -SizeBytes 20000000 -DaysOld 6 -WorkflowRunId "wf-2")
        )
        $policy = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 0; KeepLatestN = 1 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count | Should -Be 2
        ($plan.ToDelete | Where-Object Name -EQ "wf1-b") | Should -Not -BeNullOrEmpty
        ($plan.ToDelete | Where-Object Name -EQ "wf2-b") | Should -Not -BeNullOrEmpty
    }

    It "skips keep-latest-N check when KeepLatestN is 0" {
        $artifacts = @(
            (New-TestArtifact -Name "x1" -SizeBytes 1000 -DaysOld 1 -WorkflowRunId "wf-x"),
            (New-TestArtifact -Name "x2" -SizeBytes 1000 -DaysOld 2 -WorkflowRunId "wf-x"),
            (New-TestArtifact -Name "x3" -SizeBytes 1000 -DaysOld 3 -WorkflowRunId "wf-x")
        )
        $policy = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 0; KeepLatestN = 0 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count | Should -Be 0
    }
}

# ─────────────────────────────────────────────────────────────
# Unit Tests: Max-Total-Size Policy
# ─────────────────────────────────────────────────────────────
Describe "Get-ArtifactDeletionPlan - Max Total Size Policy" -Tag "Unit" {

    It "deletes oldest artifacts first when total size exceeds limit" {
        # Total: 200+300+100+250 = 850MB. Limit: 500MB.
        # Must delete oldest (30d then 20d) until under 500MB.
        # After deleting 30d(200MB) + 20d(300MB) = 500MB reclaimed => remaining 350MB < 500MB.
        $artifacts = @(
            (New-TestArtifact -Name "art-1" -SizeBytes 209715200 -DaysOld 30 -WorkflowRunId "wf-1"),
            (New-TestArtifact -Name "art-2" -SizeBytes 314572800 -DaysOld 20 -WorkflowRunId "wf-2"),
            (New-TestArtifact -Name "art-3" -SizeBytes 104857600 -DaysOld 10 -WorkflowRunId "wf-3"),
            (New-TestArtifact -Name "art-4" -SizeBytes 262144000 -DaysOld  5 -WorkflowRunId "wf-4")
        )
        $policy = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 524288000; KeepLatestN = 0 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count        | Should -Be 2
        $plan.ToRetain.Count        | Should -Be 2
        # art-1 (oldest, 30d) and art-2 (next oldest, 20d) deleted
        ($plan.ToDelete | Where-Object Name -EQ "art-1") | Should -Not -BeNullOrEmpty
        ($plan.ToDelete | Where-Object Name -EQ "art-2") | Should -Not -BeNullOrEmpty
        # 209715200 + 314572800 = 524288000 bytes reclaimed
        $plan.SpaceReclaimedBytes   | Should -Be 524288000
    }

    It "retains all when total size is within limit" {
        $artifacts = @(
            (New-TestArtifact -Name "small-1" -SizeBytes 10000000 -DaysOld 1),
            (New-TestArtifact -Name "small-2" -SizeBytes 10000000 -DaysOld 2)
        )
        $policy = @{ MaxAgeDays = 0; MaxTotalSizeBytes = 1073741824; KeepLatestN = 0 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        $plan.ToDelete.Count | Should -Be 0
    }
}

# ─────────────────────────────────────────────────────────────
# Unit Tests: Combined Policies
# ─────────────────────────────────────────────────────────────
Describe "Get-ArtifactDeletionPlan - Combined Policies" -Tag "Unit" {

    It "applies all active policies and unions the delete set" {
        $artifacts = @(
            # Old (age policy hits), small                            -- delete
            (New-TestArtifact -Name "old-small" -SizeBytes   5000000 -DaysOld 45 -WorkflowRunId "wf-1"),
            # Recent, wf-1 has 3 builds but KeepLatestN=2             -- delete (3rd newest per wf)
            (New-TestArtifact -Name "recent-extra" -SizeBytes 50000000 -DaysOld 10 -WorkflowRunId "wf-1"),
            # Recent, kept by keep-latest-N
            (New-TestArtifact -Name "recent-kept-1" -SizeBytes 50000000 -DaysOld  5 -WorkflowRunId "wf-1"),
            (New-TestArtifact -Name "recent-kept-2" -SizeBytes 50000000 -DaysOld  1 -WorkflowRunId "wf-1"),
            # Different workflow, fine
            (New-TestArtifact -Name "other-wf"     -SizeBytes 20000000 -DaysOld  3 -WorkflowRunId "wf-2")
        )
        $policy = @{ MaxAgeDays = 30; MaxTotalSizeBytes = 0; KeepLatestN = 2 }

        $plan = Get-ArtifactDeletionPlan -Artifacts $artifacts -Policy $policy

        # old-small (age) + recent-extra (keep-N) = 2 deletions
        $plan.ToDelete.Count | Should -Be 2
        ($plan.ToDelete | Where-Object Name -EQ "old-small")     | Should -Not -BeNullOrEmpty
        ($plan.ToDelete | Where-Object Name -EQ "recent-extra")  | Should -Not -BeNullOrEmpty
        $plan.ToRetain.Count | Should -Be 3
    }
}

# ─────────────────────────────────────────────────────────────
# Unit Tests: Format-CleanupPlan (output formatting)
# ─────────────────────────────────────────────────────────────
Describe "Format-CleanupPlan" -Tag "Unit" {

    It "includes machine-readable CLEANUP_RESULT marker line" {
        $plan = [PSCustomObject]@{
            ToDelete           = @(
                [PSCustomObject]@{ Name="old-art"; SizeBytes=314572800; CreatedAt=(Get-Date).AddDays(-40); WorkflowRunId="wf-2" }
            )
            ToRetain           = @(
                [PSCustomObject]@{ Name="new-art"; SizeBytes=104857600; CreatedAt=(Get-Date).AddDays(-5);  WorkflowRunId="wf-1" }
            )
            SpaceReclaimedBytes = 314572800
            DryRun             = $true
        }

        $output = Format-CleanupPlan -Plan $plan

        $output | Should -Match "CLEANUP_RESULT: deleted=1 retained=1 reclaimed_bytes=314572800"
    }

    It "includes DRY-RUN label when DryRun is true" {
        $plan = [PSCustomObject]@{
            ToDelete = @(); ToRetain = @(); SpaceReclaimedBytes = 0; DryRun = $true
        }
        $output = Format-CleanupPlan -Plan $plan
        $output | Should -Match "DRY-RUN"
    }

    It "does not include DRY-RUN label when DryRun is false" {
        $plan = [PSCustomObject]@{
            ToDelete = @(); ToRetain = @(); SpaceReclaimedBytes = 0; DryRun = $false
        }
        $output = Format-CleanupPlan -Plan $plan
        $output | Should -Not -Match "DRY-RUN"
    }
}

# ─────────────────────────────────────────────────────────────
# Workflow Structure Tests (run inside act too)
# ─────────────────────────────────────────────────────────────
Describe "Workflow Structure Tests" -Tag "Unit" {

    BeforeAll {
        $script:WorkflowFile = Join-Path $PSScriptRoot ".github/workflows/artifact-cleanup-script.yml"
        $script:ScriptFile   = Join-Path $PSScriptRoot "ArtifactCleanup.ps1"
    }

    It "workflow YAML file exists" {
        $script:WorkflowFile | Should -Exist
    }

    It "main script file exists" {
        $script:ScriptFile | Should -Exist
    }

    It "workflow has push trigger" {
        $yaml = Get-Content $script:WorkflowFile -Raw
        $yaml | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $yaml = Get-Content $script:WorkflowFile -Raw
        $yaml | Should -Match "workflow_dispatch:"
    }

    It "workflow references ArtifactCleanup.ps1" {
        $yaml = Get-Content $script:WorkflowFile -Raw
        $yaml | Should -Match "ArtifactCleanup\.ps1"
    }

    It "workflow uses shell: pwsh on run steps" {
        $yaml = Get-Content $script:WorkflowFile -Raw
        $yaml | Should -Match "shell: pwsh"
    }

    It "workflow uses actions/checkout@v4" {
        $yaml = Get-Content $script:WorkflowFile -Raw
        $yaml | Should -Match "actions/checkout@v4"
    }

    It "actionlint passes with exit code 0" {
        $actionlintOutput = actionlint $script:WorkflowFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint found errors: $actionlintOutput"
    }
}

# ─────────────────────────────────────────────────────────────
# Act Integration Tests (run locally, invoke act)
# ─────────────────────────────────────────────────────────────
Describe "Act Integration Tests" -Tag "Integration" {

    BeforeAll {
        $script:ResultFile = Join-Path $PSScriptRoot "act-result.txt"
        $script:TempDir    = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir | Out-Null

        # Copy project files into isolated temp git repo
        Copy-Item "$PSScriptRoot/ArtifactCleanup.ps1" "$script:TempDir/" -Force
        Copy-Item "$PSScriptRoot/.github" "$script:TempDir/" -Recurse -Force
        if (Test-Path "$PSScriptRoot/.actrc") {
            Copy-Item "$PSScriptRoot/.actrc" "$script:TempDir/" -Force
        }

        # Initialise a git repo so `act push` works
        Push-Location $script:TempDir
        git init -b main 2>$null | Out-Null
        git config user.email "ci@test.local"
        git config user.name  "CI Test"
        git add -A
        git commit -m "initial commit" | Out-Null

        # Run act (counts as 1 of 3 allowed runs)
        $script:ActOutput   = (act push --rm 2>&1) | Out-String
        $script:ActExitCode = $LASTEXITCODE
        Pop-Location

        # Append output to act-result.txt (required artifact)
        $sep = "=" * 60
        $block = @(
            $sep,
            "TEST CASE: Max-Age Retention Policy (single act run)",
            "Timestamp: $(Get-Date -Format 'o')",
            $script:ActOutput,
            $sep
        ) -join "`n"
        Add-Content -Path $script:ResultFile -Value $block -Encoding UTF8
    }

    AfterAll {
        # Clean up temp dir
        if ($script:TempDir -and (Test-Path $script:TempDir)) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "act exits with code 0" {
        $script:ActExitCode | Should -Be 0 -Because "act output:`n$($script:ActOutput)"
    }

    It "all jobs show Job succeeded" {
        $script:ActOutput | Should -Match "Job succeeded"
    }

    It "correctly reports 1 artifact deleted (max-age=30, one artifact 40 days old)" {
        $script:ActOutput | Should -Match "deleted=1"
    }

    It "correctly reports 2 artifacts retained" {
        $script:ActOutput | Should -Match "retained=2"
    }

    It "correctly reports 314572800 bytes (300 MB) space reclaimed" {
        $script:ActOutput | Should -Match "reclaimed_bytes=314572800"
    }

    It "reports DRY-RUN mode in output" {
        $script:ActOutput | Should -Match "DRY-RUN"
    }

    It "act-result.txt exists on disk" {
        $script:ResultFile | Should -Exist
    }
}
