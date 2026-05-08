# ArtifactCleanup.Tests.ps1
# Pester test suite for artifact cleanup retention policy logic.
# Written FIRST (TDD) before the implementation in ArtifactCleanup.psm1.

BeforeAll {
    Import-Module "$PSScriptRoot/ArtifactCleanup.psm1" -Force

    # Helper to build artifact objects for tests.
    # Must live in BeforeAll — Pester 5 does not execute bare script-level
    # functions during the run phase, only during discovery.
    function New-TestArtifact {
        param([string]$Name, [double]$SizeMB, [string]$Date, [string]$WorkflowRunId)
        [PSCustomObject]@{
            name          = $Name
            sizeMB        = $SizeMB
            createdDate   = [datetime]::Parse($Date)
            workflowRunId = $WorkflowRunId
        }
    }

    function New-TestPolicy {
        param(
            [nullable[int]]$MaxAgeDays = $null,
            [nullable[double]]$MaxTotalSizeMB = $null,
            [nullable[int]]$KeepLatestNPerWorkflow = $null
        )
        [PSCustomObject]@{
            maxAgeDays             = $MaxAgeDays
            maxTotalSizeMB         = $MaxTotalSizeMB
            keepLatestNPerWorkflow = $KeepLatestNPerWorkflow
        }
    }
}

# ─── MAX AGE POLICY ───────────────────────────────────────────────────────────

Describe "Get-ArtifactsToDelete - Max Age Policy" {

    BeforeAll {
        $refDate = [datetime]"2026-05-01"
    }

    It "marks artifacts older than maxAgeDays for deletion" {
        # artifact-old: 151 days before refDate (> 90 day limit)
        # artifact-new: 16 days before refDate (< 90 day limit)
        $artifacts = @(
            New-TestArtifact "artifact-old" 10.0 "2025-12-01" "run-1"
            New-TestArtifact "artifact-new" 20.0 "2026-04-15" "run-1"
        )
        $policy = New-TestPolicy -MaxAgeDays 90

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete.artifact.name | Should -Contain "artifact-old"
        $result.ToDelete.artifact.name | Should -Not -Contain "artifact-new"
    }

    It "keeps all artifacts when none exceed maxAgeDays" {
        $artifacts = @(
            New-TestArtifact "recent-1" 10.0 "2026-04-01" "run-1"
            New-TestArtifact "recent-2" 20.0 "2026-04-15" "run-1"
        )
        $policy = New-TestPolicy -MaxAgeDays 90

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 0
    }

    It "skips age check when maxAgeDays is null" {
        $artifacts = @(
            New-TestArtifact "very-old" 10.0 "2020-01-01" "run-1"
        )
        $policy = New-TestPolicy  # all nulls

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 0
    }
}

# ─── KEEP LATEST-N POLICY ────────────────────────────────────────────────────

Describe "Get-ArtifactsToDelete - Keep Latest-N Policy" {

    BeforeAll {
        $refDate = [datetime]"2026-05-01"
    }

    It "removes artifacts beyond the N most recent per workflow" {
        # 4 artifacts in same workflow; keep latest 2 -> delete 2 oldest
        $artifacts = @(
            New-TestArtifact "v1" 5.0 "2026-01-01" "wf-a"
            New-TestArtifact "v2" 5.0 "2026-02-01" "wf-a"
            New-TestArtifact "v3" 5.0 "2026-03-01" "wf-a"
            New-TestArtifact "v4" 5.0 "2026-04-01" "wf-a"
        )
        $policy = New-TestPolicy -KeepLatestNPerWorkflow 2

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 2
        $result.ToDelete.artifact.name | Should -Contain "v1"
        $result.ToDelete.artifact.name | Should -Contain "v2"
        $result.ToDelete.artifact.name | Should -Not -Contain "v3"
        $result.ToDelete.artifact.name | Should -Not -Contain "v4"
    }

    It "keeps all artifacts when count is within the limit" {
        $artifacts = @(
            New-TestArtifact "v1" 5.0 "2026-04-01" "wf-a"
            New-TestArtifact "v2" 5.0 "2026-04-15" "wf-a"
        )
        $policy = New-TestPolicy -KeepLatestNPerWorkflow 3

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 0
    }

    It "applies keepLatestN independently per workflow" {
        # wf-a has 3 artifacts (keep 2 -> delete 1 oldest)
        # wf-b has 2 artifacts (keep 2 -> delete 0)
        $artifacts = @(
            New-TestArtifact "a1" 5.0 "2026-01-01" "wf-a"
            New-TestArtifact "a2" 5.0 "2026-02-01" "wf-a"
            New-TestArtifact "a3" 5.0 "2026-03-01" "wf-a"
            New-TestArtifact "b1" 5.0 "2026-02-01" "wf-b"
            New-TestArtifact "b2" 5.0 "2026-03-01" "wf-b"
        )
        $policy = New-TestPolicy -KeepLatestNPerWorkflow 2

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 1
        $result.ToDelete[0].artifact.name | Should -Be "a1"
    }

    It "skips keep-latest-N check when policy is null" {
        $artifacts = @(
            New-TestArtifact "v1" 5.0 "2026-01-01" "wf-a"
            New-TestArtifact "v2" 5.0 "2026-02-01" "wf-a"
            New-TestArtifact "v3" 5.0 "2026-03-01" "wf-a"
        )
        $policy = New-TestPolicy  # all nulls

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 0
    }
}

# ─── MAX TOTAL SIZE POLICY ───────────────────────────────────────────────────

Describe "Get-ArtifactsToDelete - Max Total Size Policy" {

    BeforeAll {
        $refDate = [datetime]"2026-05-01"
    }

    It "deletes oldest artifacts until total size is within the limit" {
        # sizes: 100 + 200 + 300 = 600 MB, limit 400 MB
        # delete oldest (100), remaining 500 > 400
        # delete next oldest (200), remaining 300 <= 400  --> 2 deleted
        $artifacts = @(
            New-TestArtifact "small-old"  100.0 "2026-01-01" "wf-a"
            New-TestArtifact "medium-mid" 200.0 "2026-02-01" "wf-a"
            New-TestArtifact "large-new"  300.0 "2026-03-01" "wf-a"
        )
        $policy = New-TestPolicy -MaxTotalSizeMB 400

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 2
        $result.ToDelete.artifact.name | Should -Contain "small-old"
        $result.ToDelete.artifact.name | Should -Contain "medium-mid"
        $result.ToDelete.artifact.name | Should -Not -Contain "large-new"
    }

    It "keeps all artifacts when total size is within the limit" {
        $artifacts = @(
            New-TestArtifact "a1" 50.0 "2026-04-01" "wf-a"
            New-TestArtifact "a2" 50.0 "2026-04-15" "wf-a"
        )
        $policy = New-TestPolicy -MaxTotalSizeMB 200

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 0
    }

    It "skips size check when maxTotalSizeMB is null" {
        $artifacts = @(
            New-TestArtifact "huge" 9999.0 "2026-04-01" "wf-a"
        )
        $policy = New-TestPolicy  # all nulls

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 0
    }
}

# ─── COMBINED POLICIES ───────────────────────────────────────────────────────

Describe "Get-ArtifactsToDelete - Combined Policies" {

    It "applies all three policies together and unions the deletion sets" {
        # Reference: 2026-05-01, maxAgeDays=90 (cutoff=2026-01-31), keepLatestN=2, maxTotalSizeMB=1000
        # artifacts-in-fixture scenario used by the integration test:
        #   artifact-old-1: 2025-12-01 (151 days) -> DELETE by age
        #   artifact-old-2: 2026-01-15 (106 days) -> DELETE by age
        #   artifact-new-1: 2026-03-01 (61 days)  -> KEEP
        #   artifact-new-2: 2026-04-15 (16 days)  -> KEEP
        #   artifact-b-old: 2025-11-01 (181 days) -> DELETE by age
        # After age+keepLatestN: 2 artifacts remain (new-1, new-2), total=70MB < 1000MB
        # => 3 deletions total
        $refDate = [datetime]"2026-05-01"
        $artifacts = @(
            New-TestArtifact "artifact-old-1" 10.0 "2025-12-01" "workflow-a"
            New-TestArtifact "artifact-old-2" 20.0 "2026-01-15" "workflow-a"
            New-TestArtifact "artifact-new-1" 30.0 "2026-03-01" "workflow-a"
            New-TestArtifact "artifact-new-2" 40.0 "2026-04-15" "workflow-a"
            New-TestArtifact "artifact-b-old"  5.0 "2025-11-01" "workflow-b"
        )
        $policy = New-TestPolicy -MaxAgeDays 90 -MaxTotalSizeMB 1000 -KeepLatestNPerWorkflow 2

        $result = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate

        $result.ToDelete | Should -HaveCount 3
        $result.ToDelete.artifact.name | Should -Contain "artifact-old-1"
        $result.ToDelete.artifact.name | Should -Contain "artifact-old-2"
        $result.ToDelete.artifact.name | Should -Contain "artifact-b-old"
        $result.ToDelete.artifact.name | Should -Not -Contain "artifact-new-1"
        $result.ToDelete.artifact.name | Should -Not -Contain "artifact-new-2"
    }
}

# ─── DELETION PLAN ───────────────────────────────────────────────────────────

Describe "New-DeletionPlan" {

    BeforeAll {
        $refDate = [datetime]"2026-05-01"
        $artifacts = @(
            New-TestArtifact "old-1" 10.0 "2025-12-01" "wf-a"
            New-TestArtifact "old-2" 25.0 "2026-01-15" "wf-a"
            New-TestArtifact "new-1" 30.0 "2026-04-01" "wf-a"
        )
        $policy = New-TestPolicy -MaxAgeDays 90
        $deleteResult = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate
        $script:plan = New-DeletionPlan -Artifacts $artifacts -DeletionDecisions $deleteResult.ToDelete -DryRun:$false
    }

    It "reports the correct number of artifacts to delete" {
        $plan.DeleteCount | Should -Be 2
    }

    It "reports the correct number of artifacts to retain" {
        $plan.RetainCount | Should -Be 1
    }

    It "calculates total space reclaimed correctly" {
        $plan.SpaceReclaimedMB | Should -Be 35.0
    }

    It "reports total artifact count" {
        $plan.TotalCount | Should -Be 3
    }

    It "includes DryRun flag in the plan" {
        $plan.IsDryRun | Should -BeFalse
    }

    It "dry-run flag is reflected in the plan" {
        $dryPlan = New-DeletionPlan -Artifacts $artifacts -DeletionDecisions $deleteResult.ToDelete -DryRun:$true
        $dryPlan.IsDryRun | Should -BeTrue
    }
}

# ─── TEXT FORMATTING ─────────────────────────────────────────────────────────

Describe "Format-DeletionPlan" {

    BeforeAll {
        $refDate = [datetime]"2026-05-01"
        $artifacts = @(
            New-TestArtifact "old-artifact" 10.0 "2025-12-01" "wf-a"
            New-TestArtifact "new-artifact" 20.0 "2026-04-15" "wf-a"
        )
        $policy = New-TestPolicy -MaxAgeDays 90
        $deleteResult = Get-ArtifactsToDelete -Artifacts $artifacts -Policy $policy -ReferenceDate $refDate
        $script:plan = New-DeletionPlan -Artifacts $artifacts -DeletionDecisions $deleteResult.ToDelete -DryRun:$false
        $script:planDry = New-DeletionPlan -Artifacts $artifacts -DeletionDecisions $deleteResult.ToDelete -DryRun:$true
    }

    It "output contains artifact counts" {
        $text = Format-DeletionPlan -Plan $plan
        $text | Should -Match "Artifacts to delete: 1"
        $text | Should -Match "Artifacts to retain: 1"
    }

    It "output contains space reclaimed" {
        $text = Format-DeletionPlan -Plan $plan
        $text | Should -Match "Space to reclaim: 10\.00 MB"
    }

    It "dry-run output contains DRY RUN marker" {
        $text = Format-DeletionPlan -Plan $planDry
        $text | Should -Match "DRY RUN"
    }

    It "non-dry-run output does not contain DRY RUN marker" {
        $text = Format-DeletionPlan -Plan $plan
        $text | Should -Not -Match "DRY RUN"
    }

    It "output lists the artifact to be deleted by name" {
        $text = Format-DeletionPlan -Plan $plan
        $text | Should -Match "old-artifact"
    }
}

# ─── FILE I/O FUNCTIONS ──────────────────────────────────────────────────────

Describe "Get-ArtifactsFromFile" {

    It "reads and parses a JSON artifacts file" {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        try {
            @'
[
  {"name":"art-1","sizeMB":10.5,"createdDate":"2026-01-01T00:00:00Z","workflowRunId":"run-42"},
  {"name":"art-2","sizeMB":20.0,"createdDate":"2026-03-01T00:00:00Z","workflowRunId":"run-99"}
]
'@ | Set-Content $tmpFile

            $artifacts = Get-ArtifactsFromFile -Path $tmpFile

            $artifacts | Should -HaveCount 2
            $artifacts[0].name      | Should -Be "art-1"
            $artifacts[0].sizeMB    | Should -Be 10.5
            $artifacts[0].workflowRunId | Should -Be "run-42"
            $artifacts[0].createdDate   | Should -BeOfType [datetime]
        }
        finally {
            Remove-Item $tmpFile -ErrorAction SilentlyContinue
        }
    }

    It "throws a meaningful error for a missing file" {
        { Get-ArtifactsFromFile -Path "/nonexistent/path.json" } | Should -Throw "*not found*"
    }
}

Describe "Get-PolicyFromFile" {

    It "reads and parses a JSON policy file" {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        try {
            '{"maxAgeDays":30,"maxTotalSizeMB":500,"keepLatestNPerWorkflow":3}' | Set-Content $tmpFile

            $policy = Get-PolicyFromFile -Path $tmpFile

            $policy.maxAgeDays             | Should -Be 30
            $policy.maxTotalSizeMB         | Should -Be 500
            $policy.keepLatestNPerWorkflow  | Should -Be 3
        }
        finally {
            Remove-Item $tmpFile -ErrorAction SilentlyContinue
        }
    }

    It "throws a meaningful error for a missing file" {
        { Get-PolicyFromFile -Path "/nonexistent/policy.json" } | Should -Throw "*not found*"
    }
}

# ─── WORKFLOW STRUCTURE TESTS ────────────────────────────────────────────────

Describe "Workflow Structure" {

    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot ".github/workflows/artifact-cleanup-script.yml"
    }

    It "workflow file exists at the expected path" {
        $workflowPath | Should -Exist
    }

    It "workflow file references the main script" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "ArtifactCleanup\.ps1"
    }

    It "workflow has a push trigger" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "push"
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "workflow_dispatch"
    }

    It "workflow has at least one job" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "jobs:"
    }

    It "workflow uses actions/checkout" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "actions/checkout"
    }

    It "workflow uses shell: pwsh for run steps" {
        $content = Get-Content $workflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "fixtures directory exists" {
        Join-Path $PSScriptRoot "fixtures/artifacts.json" | Should -Exist
        Join-Path $PSScriptRoot "fixtures/policy.json"    | Should -Exist
    }

    It "actionlint passes on the workflow file" -Skip:(!(Get-Command actionlint -ErrorAction SilentlyContinue)) {
        $lintOut = & actionlint $workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
