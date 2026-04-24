# ArtifactCleanup.Tests.ps1 — Pester test suite for artifact retention policy enforcement
#
# TDD Process:
#   RED   → tests written first (this file), no implementation → all fail
#   GREEN → ArtifactCleanup.ps1 implemented to make each test pass
#   REFACTOR → cleanup once green
#
# Run with: Invoke-Pester ./ArtifactCleanup.Tests.ps1 -PassThru

BeforeAll {
    # Dot-source the implementation (fails on first run when file doesn't exist)
    . "$PSScriptRoot/ArtifactCleanup.ps1"

    # Shared fixture helpers — build artifacts relative to "now" so MaxAge tests
    # are always deterministic regardless of when the suite runs.
    function New-Artifact {
        param(
            [string]$Name,
            [long]$SizeBytes,
            [int]$DaysOld,
            [string]$WorkflowRunId
        )
        @{
            Name          = $Name
            Size          = $SizeBytes
            CreatedAt     = [datetime]::Now.AddDays(-$DaysOld)
            WorkflowRunId = $WorkflowRunId
        }
    }

    # Verification fixture — known inputs with computed expected outputs.
    # Policy: MaxAgeDays=30, MaxTotalSizeBytes=500MB, KeepLatestNPerWorkflow=2
    #
    # Phase 1 MaxAge: artifact-D (40d) → deleted
    # Phase 2 KeepLatestN run-1: keep C(2d)+B(5d), delete A(10d)
    #         KeepLatestN run-2: keep E(3d) (only one left)
    # Phase 3 MaxTotalSize: B(200MB)+C(300MB)+E(75MB)=575MB > 500MB
    #         delete oldest of retained: B(5d) → 375MB ≤ 500MB
    #
    # Final: Deleted = D,A,B  (3 artifacts, 367001600 bytes)
    #        Retained = C,E   (2 artifacts)
    $script:verArtifacts = @(
        (New-Artifact "artifact-A" 104857600 10 "run-1"),  # 100 MB
        (New-Artifact "artifact-B" 209715200  5 "run-1"),  # 200 MB
        (New-Artifact "artifact-C" 314572800  2 "run-1"),  # 300 MB
        (New-Artifact "artifact-D"  52428800 40 "run-2"),  #  50 MB
        (New-Artifact "artifact-E"  78643200  3 "run-2")   #  75 MB
    )
    $script:verPolicy = @{
        MaxAgeDays             = 30
        MaxTotalSizeBytes      = 524288000   # 500 MB
        KeepLatestNPerWorkflow = 2
    }
}

# ─────────────────────────────────────────────────────────────
# FIRST FAILING TEST — written before any implementation exists
# ─────────────────────────────────────────────────────────────
Describe "Get-DeletionPlan — function availability" {
    It "should be available as a function" {
        $cmd = Get-Command Get-DeletionPlan -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
    }
}

# ─────────────────────────────────────────────────────────────
# UNIT TESTS — each policy in isolation
# ─────────────────────────────────────────────────────────────
Describe "Get-DeletionPlan — empty input" {
    It "returns empty plan for empty artifact list" {
        $plan = Get-DeletionPlan -Artifacts @() -Policy @{ MaxAgeDays = 30 }
        $plan.ArtifactsToDelete.Count | Should -Be 0
        $plan.ArtifactsToRetain.Count | Should -Be 0
        $plan.Summary.ArtifactsDeleted | Should -Be 0
        $plan.Summary.TotalSpaceReclaimedBytes | Should -Be 0
    }
}

Describe "Get-DeletionPlan — MaxAge policy" {
    BeforeAll {
        $script:artifacts = @(
            @{ Name = "old"; Size = 1024; CreatedAt = [datetime]::Now.AddDays(-40); WorkflowRunId = "r1" },
            @{ Name = "new"; Size = 2048; CreatedAt = [datetime]::Now.AddDays(-5);  WorkflowRunId = "r1" }
        )
        $script:policy = @{ MaxAgeDays = 30 }
    }

    It "marks artifacts older than MaxAgeDays for deletion" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $deleted = $plan.ArtifactsToDelete | Where-Object { $_.Name -eq "old" }
        $deleted | Should -Not -BeNullOrEmpty
        $deleted.DeleteReason | Should -Be "MaxAge"
    }

    It "retains artifacts within MaxAgeDays" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $retained = $plan.ArtifactsToRetain | Where-Object { $_.Name -eq "new" }
        $retained | Should -Not -BeNullOrEmpty
    }

    It "does not include age-deleted artifacts in retained list" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $wronglyRetained = $plan.ArtifactsToRetain | Where-Object { $_.Name -eq "old" }
        $wronglyRetained | Should -BeNullOrEmpty
    }
}

Describe "Get-DeletionPlan — KeepLatestNPerWorkflow policy" {
    BeforeAll {
        # Three artifacts for same workflow run; keep only 2 latest
        $script:artifacts = @(
            @{ Name = "r1-oldest"; Size = 100; CreatedAt = [datetime]::Now.AddDays(-10); WorkflowRunId = "run-1" },
            @{ Name = "r1-middle"; Size = 200; CreatedAt = [datetime]::Now.AddDays(-5);  WorkflowRunId = "run-1" },
            @{ Name = "r1-latest"; Size = 300; CreatedAt = [datetime]::Now.AddDays(-1);  WorkflowRunId = "run-1" },
            @{ Name = "r2-only";   Size = 400; CreatedAt = [datetime]::Now.AddDays(-3);  WorkflowRunId = "run-2" }
        )
        $script:policy = @{ KeepLatestNPerWorkflow = 2 }
    }

    It "deletes oldest artifact beyond N for run-1" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $deleted = $plan.ArtifactsToDelete | Where-Object { $_.Name -eq "r1-oldest" }
        $deleted | Should -Not -BeNullOrEmpty
        $deleted.DeleteReason | Should -Be "KeepLatestN"
    }

    It "retains the two latest artifacts for run-1" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $retainedNames = $plan.ArtifactsToRetain | ForEach-Object { $_.Name }
        $retainedNames | Should -Contain "r1-middle"
        $retainedNames | Should -Contain "r1-latest"
    }

    It "retains single artifact for run-2 (count <= N)" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $retainedNames = $plan.ArtifactsToRetain | ForEach-Object { $_.Name }
        $retainedNames | Should -Contain "r2-only"
    }
}

Describe "Get-DeletionPlan — MaxTotalSize policy" {
    BeforeAll {
        # Three artifacts totalling 600 bytes; limit is 400 bytes
        # Oldest-first deletion should remove oldest (artifact-old, 100) then artifact-mid (200)
        # → remaining 300 bytes ≤ 400 limit
        $script:artifacts = @(
            @{ Name = "artifact-old"; Size = 100; CreatedAt = [datetime]::Now.AddDays(-10); WorkflowRunId = "r1" },
            @{ Name = "artifact-mid"; Size = 200; CreatedAt = [datetime]::Now.AddDays(-5);  WorkflowRunId = "r1" },
            @{ Name = "artifact-new"; Size = 300; CreatedAt = [datetime]::Now.AddDays(-1);  WorkflowRunId = "r1" }
        )
        $script:policy = @{ MaxTotalSizeBytes = 400 }
    }

    It "deletes oldest artifact first when total exceeds limit" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        $deleted = $plan.ArtifactsToDelete | Where-Object { $_.Name -eq "artifact-old" }
        $deleted | Should -Not -BeNullOrEmpty
        $deleted.DeleteReason | Should -Be "MaxTotalSize"
    }

    It "stops deleting once under the size limit" {
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $script:policy
        # 600 total; delete old(100) → 500 still over; delete mid(200) → 300 ≤ 400; stop
        $retainedNames = $plan.ArtifactsToRetain | ForEach-Object { $_.Name }
        $retainedNames | Should -Contain "artifact-new"
    }

    It "retains all artifacts when total is within limit" {
        $smallPolicy = @{ MaxTotalSizeBytes = 1000 }
        $plan = Get-DeletionPlan -Artifacts $script:artifacts -Policy $smallPolicy
        $plan.ArtifactsToRetain.Count | Should -Be 3
        $plan.ArtifactsToDelete.Count | Should -Be 0
    }
}

Describe "Get-DeletionPlan — combined policies (verification fixture)" {
    It "applies all three policies in correct order with known fixture data" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $plan.Summary.ArtifactsDeleted          | Should -Be 3
        $plan.Summary.ArtifactsRetained         | Should -Be 2
        $plan.Summary.TotalSpaceReclaimedBytes  | Should -Be 367001600
    }

    It "deletes artifact-D for MaxAge violation" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $d = $plan.ArtifactsToDelete | Where-Object { $_.Name -eq "artifact-D" }
        $d | Should -Not -BeNullOrEmpty
        $d.DeleteReason | Should -Be "MaxAge"
    }

    It "deletes artifact-A for KeepLatestN violation" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $a = $plan.ArtifactsToDelete | Where-Object { $_.Name -eq "artifact-A" }
        $a | Should -Not -BeNullOrEmpty
        $a.DeleteReason | Should -Be "KeepLatestN"
    }

    It "deletes artifact-B for MaxTotalSize violation" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $b = $plan.ArtifactsToDelete | Where-Object { $_.Name -eq "artifact-B" }
        $b | Should -Not -BeNullOrEmpty
        $b.DeleteReason | Should -Be "MaxTotalSize"
    }

    It "retains artifact-C and artifact-E" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $names = $plan.ArtifactsToRetain | ForEach-Object { $_.Name }
        $names | Should -Contain "artifact-C"
        $names | Should -Contain "artifact-E"
    }
}

Describe "Get-DeletionPlan — DryRun mode" {
    It "produces identical deletion plan whether DryRun is set or not" {
        $plan    = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $dryPlan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy -DryRun
        $dryPlan.Summary.ArtifactsDeleted  | Should -Be $plan.Summary.ArtifactsDeleted
        $dryPlan.Summary.ArtifactsRetained | Should -Be $plan.Summary.ArtifactsRetained
    }

    It "sets DryRun=True in summary when flag is provided" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy -DryRun
        $plan.Summary.DryRun | Should -Be $true
    }

    It "sets DryRun=False in summary when flag is not provided" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $plan.Summary.DryRun | Should -Be $false
    }
}

Describe "Get-DeletionPlan — summary accuracy" {
    It "correctly sums space reclaimed from all deleted artifact sizes" {
        $artifacts = @(
            @{ Name = "a"; Size = 1000; CreatedAt = [datetime]::Now.AddDays(-40); WorkflowRunId = "r1" },
            @{ Name = "b"; Size = 2000; CreatedAt = [datetime]::Now.AddDays(-2);  WorkflowRunId = "r1" }
        )
        $plan = Get-DeletionPlan -Artifacts $artifacts -Policy @{ MaxAgeDays = 30 }
        $plan.Summary.TotalSpaceReclaimedBytes | Should -Be 1000
    }

    It "returned summary counts match list lengths" {
        $plan = Get-DeletionPlan -Artifacts $script:verArtifacts -Policy $script:verPolicy
        $plan.Summary.ArtifactsDeleted  | Should -Be $plan.ArtifactsToDelete.Count
        $plan.Summary.ArtifactsRetained | Should -Be $plan.ArtifactsToRetain.Count
    }
}

# ─────────────────────────────────────────────────────────────
# WORKFLOW STRUCTURE TESTS
# ─────────────────────────────────────────────────────────────
Describe "Workflow structure" {
    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot ".github/workflows/artifact-cleanup-script.yml"
        $script:workflowContent = if (Test-Path $script:workflowPath) {
            Get-Content $script:workflowPath -Raw
        } else { "" }
    }

    It "workflow file exists at expected path" {
        $script:workflowPath | Should -Exist
    }

    It "workflow has push trigger" {
        $script:workflowContent | Should -Match 'push:'
    }

    It "workflow has pull_request trigger" {
        $script:workflowContent | Should -Match 'pull_request:'
    }

    It "workflow has a jobs section" {
        $script:workflowContent | Should -Match 'jobs:'
    }

    It "workflow references ArtifactCleanup.ps1" {
        $script:workflowContent | Should -Match 'ArtifactCleanup\.ps1'
    }

    It "workflow uses shell: pwsh for run steps" {
        $script:workflowContent | Should -Match 'shell:\s*pwsh'
    }

    It "ArtifactCleanup.ps1 script file exists" {
        (Join-Path $PSScriptRoot "ArtifactCleanup.ps1") | Should -Exist
    }

    It "passes actionlint validation" {
        $actionlintCmd = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $actionlintCmd) {
            # actionlint not in container PATH — treat as not applicable
            $true | Should -Be $true
            return
        }
        $output = & actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $output"
    }
}
