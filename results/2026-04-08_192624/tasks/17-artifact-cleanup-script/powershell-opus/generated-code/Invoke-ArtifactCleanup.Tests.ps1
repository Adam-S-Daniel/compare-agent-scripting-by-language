<#
.SYNOPSIS
    Pester tests for Invoke-ArtifactCleanup.ps1
    Uses TDD approach: each test was written before the corresponding feature code.
#>

Describe "Artifact Cleanup Script" {

    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot 'Invoke-ArtifactCleanup.ps1'

        # Helper: run the cleanup script with given parameters and return parsed output
        function Invoke-Cleanup {
            param(
                [string]$ArtifactsJson,
                [int]$MaxAgeDays = -1,
                [long]$MaxTotalSizeBytes = -1,
                [int]$KeepLatestN = -1,
                [switch]$DryRun,
                [string]$ReferenceDate = "2026-01-15"
            )

            $params = @(
                '-NoProfile', '-NonInteractive', '-File', $script:ScriptPath,
                '-ArtifactsJson', $ArtifactsJson,
                '-ReferenceDate', $ReferenceDate
            )
            if ($MaxAgeDays -ge 0)       { $params += '-MaxAgeDays';       $params += $MaxAgeDays }
            if ($MaxTotalSizeBytes -ge 0) { $params += '-MaxTotalSizeBytes'; $params += $MaxTotalSizeBytes }
            if ($KeepLatestN -ge 0)       { $params += '-KeepLatestN';     $params += $KeepLatestN }
            if ($DryRun)                  { $params += '-DryRun' }

            $output = & pwsh @params 2>&1
            $outputText = $output -join "`n"

            # Extract JSON plan from between markers
            $jsonPlan = $null
            if ($outputText -match 'JSON_PLAN_START\s*([\s\S]*?)\s*JSON_PLAN_END') {
                $jsonPlan = $Matches[1] | ConvertFrom-Json
            }

            return @{
                RawOutput = $outputText
                Plan      = $jsonPlan
            }
        }

        # 5 artifacts across 2 workflow runs
        $script:MockArtifacts = @(
            @{ name = "build-log-1"; size = 1000; createdAt = "2026-01-01"; workflowRunId = "run-100" }
            @{ name = "build-log-2"; size = 2000; createdAt = "2026-01-05"; workflowRunId = "run-100" }
            @{ name = "build-log-3"; size = 3000; createdAt = "2026-01-10"; workflowRunId = "run-100" }
            @{ name = "test-results-1"; size = 500;  createdAt = "2026-01-03"; workflowRunId = "run-200" }
            @{ name = "test-results-2"; size = 1500; createdAt = "2026-01-12"; workflowRunId = "run-200" }
        ) | ConvertTo-Json -Compress

        $script:SingleArtifact = @(
            @{ name = "only-one"; size = 5000; createdAt = "2026-01-14"; workflowRunId = "run-300" }
        ) | ConvertTo-Json -Compress
    }

    Context "Basic parsing and empty input" {

        It "Should handle empty array input" {
            $result = Invoke-Cleanup -ArtifactsJson '[]'
            $result.Plan.TotalArtifacts | Should -Be 0
            $result.Plan.ArtifactsToDelete | Should -Be 0
            $result.Plan.SpaceReclaimed | Should -Be 0
        }

        It "Should parse and return all artifacts when no policies applied" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts
            $result.Plan.TotalArtifacts | Should -Be 5
            $result.Plan.ArtifactsToDelete | Should -Be 0
            $result.Plan.ArtifactsToRetain | Should -Be 5
        }
    }

    Context "Max age policy" {

        It "Should delete artifacts older than MaxAgeDays" {
            # Reference date 2026-01-15, MaxAgeDays=10
            # build-log-1 (Jan 1) = 14 days old -> DELETE
            # test-results-1 (Jan 3) = 12 days old -> DELETE
            # build-log-2 (Jan 5) = 10 days old -> KEEP (not strictly greater)
            # build-log-3 (Jan 10) = 5 days old -> KEEP
            # test-results-2 (Jan 12) = 3 days old -> KEEP
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10
            $result.Plan.ArtifactsToDelete | Should -Be 2
            $result.Plan.ArtifactsToRetain | Should -Be 3
            $result.Plan.SpaceReclaimed | Should -Be 1500
        }

        It "Should delete all artifacts when MaxAgeDays is 0" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 0
            $result.Plan.ArtifactsToDelete | Should -Be 5
            $result.Plan.ArtifactsToRetain | Should -Be 0
            $result.Plan.SpaceReclaimed | Should -Be 8000
        }

        It "Should retain all artifacts when none are old enough" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 30
            $result.Plan.ArtifactsToDelete | Should -Be 0
            $result.Plan.ArtifactsToRetain | Should -Be 5
        }
    }

    Context "Keep-latest-N per workflow policy" {

        It "Should keep only N most recent artifacts per workflow" {
            # run-100 has 3 artifacts: keep latest 1 -> delete 2 oldest
            # run-200 has 2 artifacts: keep latest 1 -> delete 1 oldest
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -KeepLatestN 1
            $result.Plan.ArtifactsToDelete | Should -Be 3
            $result.Plan.ArtifactsToRetain | Should -Be 2
            # Retained: build-log-3 (3000) + test-results-2 (1500) = 4500
            $result.Plan.SpaceRetained | Should -Be 4500
        }

        It "Should keep all when N is greater than group size" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -KeepLatestN 10
            $result.Plan.ArtifactsToDelete | Should -Be 0
            $result.Plan.ArtifactsToRetain | Should -Be 5
        }

        It "Should keep latest 2 per workflow" {
            # run-100: keep build-log-3, build-log-2; delete build-log-1
            # run-200: keep both (only 2)
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -KeepLatestN 2
            $result.Plan.ArtifactsToDelete | Should -Be 1
            $result.Plan.ArtifactsToRetain | Should -Be 4
            $result.Plan.SpaceReclaimed | Should -Be 1000
        }
    }

    Context "Max total size policy" {

        It "Should delete oldest artifacts when total exceeds max size" {
            # Total = 8000 bytes. Max = 5000.
            # Delete oldest first:
            # build-log-1 (Jan 1, 1000) -> total 7000
            # test-results-1 (Jan 3, 500) -> total 6500
            # build-log-2 (Jan 5, 2000) -> total 4500, <= 5000 STOP
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxTotalSizeBytes 5000
            $result.Plan.ArtifactsToDelete | Should -Be 3
            $result.Plan.ArtifactsToRetain | Should -Be 2
            $result.Plan.SpaceReclaimed | Should -Be 3500
            $result.Plan.SpaceRetained | Should -Be 4500
        }

        It "Should retain all when total is already under max" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxTotalSizeBytes 99999
            $result.Plan.ArtifactsToDelete | Should -Be 0
            $result.Plan.ArtifactsToRetain | Should -Be 5
        }

        It "Should delete all if max size is 0" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxTotalSizeBytes 0
            $result.Plan.ArtifactsToDelete | Should -Be 5
            $result.Plan.ArtifactsToRetain | Should -Be 0
            $result.Plan.SpaceReclaimed | Should -Be 8000
        }
    }

    Context "Combined policies" {

        It "Should apply max-age AND keep-latest-N together" {
            # MaxAgeDays=10: deletes build-log-1 (14d), test-results-1 (12d)
            # KeepLatestN=1: from remaining {build-log-2, build-log-3, test-results-2}
            #   run-100: build-log-3 kept, build-log-2 deleted
            #   run-200: test-results-2 kept (only one left)
            # Total deleted: build-log-1, test-results-1, build-log-2 = 3
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10 -KeepLatestN 1
            $result.Plan.ArtifactsToDelete | Should -Be 3
            $result.Plan.ArtifactsToRetain | Should -Be 2
            $result.Plan.SpaceRetained | Should -Be 4500
        }

        It "Should apply all three policies together" {
            # MaxAgeDays=10: deletes build-log-1, test-results-1
            # KeepLatestN=2: no additional (run-100 has 2 left, run-200 has 1)
            # MaxTotalSizeBytes=4000: remaining=6500, oldest first:
            #   build-log-2 (2000) -> 4500
            #   test-results-2 (1500) -> 3000, <= 4000 STOP
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10 -KeepLatestN 2 -MaxTotalSizeBytes 4000
            # After max-age+keepN: remaining = build-log-2(2000)+build-log-3(3000)+test-results-2(1500)=6500
            # MaxSize=4000: delete build-log-2(2000)->4500, delete build-log-3(3000)->1500 STOP
            $result.Plan.ArtifactsToDelete | Should -Be 4
            $result.Plan.ArtifactsToRetain | Should -Be 1
            $result.Plan.SpaceRetained | Should -Be 1500
        }
    }

    Context "Dry-run mode" {

        It "Should indicate dry run in output" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10 -DryRun
            $result.RawOutput | Should -Match "DRY RUN MODE"
            $result.Plan.DryRun | Should -Be $true
        }

        It "Should indicate execution mode when not dry-run" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10
            $result.RawOutput | Should -Match "EXECUTION MODE"
            $result.Plan.DryRun | Should -Be $false
        }
    }

    Context "Single artifact edge case" {

        It "Should handle single artifact with keep-latest-1" {
            $result = Invoke-Cleanup -ArtifactsJson $script:SingleArtifact -KeepLatestN 1
            $result.Plan.TotalArtifacts | Should -Be 1
            $result.Plan.ArtifactsToRetain | Should -Be 1
            $result.Plan.ArtifactsToDelete | Should -Be 0
        }
    }

    Context "Output format" {

        It "Should list deleted artifacts with reasons" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10
            $result.RawOutput | Should -Match "Artifacts to delete:"
            $result.RawOutput | Should -Match "build-log-1"
            $result.RawOutput | Should -Match "Reason:"
        }

        It "Should list retained artifacts" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10
            $result.RawOutput | Should -Match "Artifacts retained:"
            $result.RawOutput | Should -Match "build-log-3"
        }

        It "Should include summary counts" {
            $result = Invoke-Cleanup -ArtifactsJson $script:MockArtifacts -MaxAgeDays 10
            $result.RawOutput | Should -Match "Total artifacts: 5"
            $result.RawOutput | Should -Match "To delete: 2"
            $result.RawOutput | Should -Match "To retain: 3"
            $result.RawOutput | Should -Match "Space reclaimed: 1500 bytes"
        }
    }
}
