# ProcessMonitor.Tests.ps1
# TDD test suite for the Process Monitor module.
#
# TDD PROGRESSION (Red → Green → Refactor cycles):
#   Cycle 1: New-ProcessEntry — basic object creation
#   Cycle 2: New-ProcessEntry — input validation (negative values)
#   Cycle 3: New-ResourceThreshold — threshold configuration object
#   Cycle 4: Filter-ProcessesByThreshold — CPU/memory filtering
#   Cycle 5: Get-TopNConsumers — sorting and slicing
#   Cycle 6: New-AlertReport — formatted text output
#   Cycle 7: Invoke-ProcessMonitor — end-to-end integration with mock injection
#
# Each Context block corresponds to one red/green/refactor cycle.
# Tests were written BEFORE the matching implementation in ProcessMonitor.psm1.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ── Module import ──────────────────────────────────────────────────────────────
$script:ModulePath = Join-Path $PSScriptRoot 'ProcessMonitor.psm1'

if (-not (Test-Path $script:ModulePath)) {
    throw "Module not found at '$script:ModulePath'. Run from the project root."
}

Import-Module $script:ModulePath -Force

# ── Shared mock fixture data ───────────────────────────────────────────────────
# All process data is defined here so tests never rely on live system state.
# ProcessId values are arbitrary and stable across test runs.

Describe 'ProcessMonitor' {

    BeforeAll {
        # Four mock processes covering a range of CPU and memory values.
        $script:MockProcesses = [PSCustomObject[]]@(
            [PSCustomObject]@{ Name = 'chrome'; PID = [int]1234; CPUPercent = [double]45.5; MemoryMB = [double]512.0 },
            [PSCustomObject]@{ Name = 'code';   PID = [int]5678; CPUPercent = [double]12.3; MemoryMB = [double]1024.0 },
            [PSCustomObject]@{ Name = 'system'; PID = [int]4;    CPUPercent = [double]2.1;  MemoryMB = [double]128.0 },
            [PSCustomObject]@{ Name = 'idle';   PID = [int]0;    CPUPercent = [double]0.1;  MemoryMB = [double]4.0 }
        )
    }

    # ── Cycle 1 & 2: New-ProcessEntry ─────────────────────────────────────────
    # RED:  Test that New-ProcessEntry creates a typed object with all required fields.
    # GREEN: Implement New-ProcessEntry returning a PSCustomObject.
    # REFACTOR: Add input validation guards.

    Context 'New-ProcessEntry' {

        It 'creates a process entry with all required fields' {
            $proc = New-ProcessEntry -Name 'test' -ProcessId 123 -CPUPercent 10.5 -MemoryMB 256.0
            $proc.Name       | Should -Be 'test'
            $proc.PID        | Should -Be 123
            $proc.CPUPercent | Should -Be 10.5
            $proc.MemoryMB   | Should -Be 256.0
        }

        It 'accepts zero values for CPU and memory' {
            $proc = New-ProcessEntry -Name 'idle' -ProcessId 0 -CPUPercent 0.0 -MemoryMB 0.0
            $proc.CPUPercent | Should -Be 0.0
            $proc.MemoryMB   | Should -Be 0.0
        }

        It 'throws a meaningful error when CPUPercent is negative' {
            { New-ProcessEntry -Name 'bad' -ProcessId 1 -CPUPercent -1.0 -MemoryMB 100.0 } |
                Should -Throw -ExpectedMessage '*CPUPercent*negative*'
        }

        It 'throws a meaningful error when MemoryMB is negative' {
            { New-ProcessEntry -Name 'bad' -ProcessId 1 -CPUPercent 5.0 -MemoryMB -1.0 } |
                Should -Throw -ExpectedMessage '*MemoryMB*negative*'
        }
    }

    # ── Cycle 3: New-ResourceThreshold ────────────────────────────────────────
    # RED:  Test that New-ResourceThreshold creates a configuration object.
    # GREEN: Implement New-ResourceThreshold.

    Context 'New-ResourceThreshold' {

        It 'creates a threshold object with both properties' {
            $t = New-ResourceThreshold -MinCPUPercent 5.0 -MinMemoryMB 100.0
            $t.MinCPUPercent | Should -Be 5.0
            $t.MinMemoryMB   | Should -Be 100.0
        }

        It 'accepts zero thresholds (include everything)' {
            $t = New-ResourceThreshold -MinCPUPercent 0.0 -MinMemoryMB 0.0
            $t.MinCPUPercent | Should -Be 0.0
            $t.MinMemoryMB   | Should -Be 0.0
        }
    }

    # ── Cycle 4: Filter-ProcessesByThreshold ──────────────────────────────────
    # RED:  Test threshold filtering — CPU-only, memory-only, combined, no-match.
    # GREEN: Implement Filter-ProcessesByThreshold using Where-Object.
    # REFACTOR: Ensure null-safe return (Where-Object can return $null on no match).

    Context 'Filter-ProcessesByThreshold' {

        It 'returns all processes when both thresholds are zero' {
            $t      = New-ResourceThreshold -MinCPUPercent 0.0 -MinMemoryMB 0.0
            $result = Filter-ProcessesByThreshold -Processes $script:MockProcesses -Threshold $t
            $result.Count | Should -Be 4
        }

        It 'filters out processes below the CPU threshold' {
            # Only chrome (45.5%) and code (12.3%) are >= 10.0%
            $t      = New-ResourceThreshold -MinCPUPercent 10.0 -MinMemoryMB 0.0
            $result = Filter-ProcessesByThreshold -Processes $script:MockProcesses -Threshold $t
            $result.Count | Should -Be 2
            $result | ForEach-Object { $_.CPUPercent | Should -BeGreaterOrEqual 10.0 }
        }

        It 'filters out processes below the memory threshold' {
            # Only chrome (512 MB) and code (1024 MB) are >= 256 MB
            $t      = New-ResourceThreshold -MinCPUPercent 0.0 -MinMemoryMB 256.0
            $result = Filter-ProcessesByThreshold -Processes $script:MockProcesses -Threshold $t
            $result.Count | Should -Be 2
            $result | ForEach-Object { $_.MemoryMB | Should -BeGreaterOrEqual 256.0 }
        }

        It 'applies both thresholds simultaneously' {
            # chrome: 45.5% CPU >= 20%, 512 MB >= 500 MB → PASS
            # code:   12.3% CPU < 20%                    → FAIL (CPU too low)
            # system/idle: both thresholds fail
            $t      = New-ResourceThreshold -MinCPUPercent 20.0 -MinMemoryMB 500.0
            $result = Filter-ProcessesByThreshold -Processes $script:MockProcesses -Threshold $t
            $result.Count     | Should -Be 1
            $result[0].Name   | Should -Be 'chrome'
        }

        It 'returns an empty array (not null) when no processes match' {
            $t      = New-ResourceThreshold -MinCPUPercent 99.0 -MinMemoryMB 0.0
            $result = Filter-ProcessesByThreshold -Processes $script:MockProcesses -Threshold $t
            # @($null).Count == 1, @(@()).Count == 0 — fails if function collapses to $null
            @($result).Count | Should -Be 0
        }

        It 'returns an empty array when given an empty input' {
            $t      = New-ResourceThreshold -MinCPUPercent 0.0 -MinMemoryMB 0.0
            $result = Filter-ProcessesByThreshold -Processes ([PSCustomObject[]]@()) -Threshold $t
            @($result).Count | Should -Be 0
        }
    }

    # ── Cycle 5: Get-TopNConsumers ─────────────────────────────────────────────
    # RED:  Test descending sort by CPU and by Memory, capped at N items.
    # GREEN: Implement Get-TopNConsumers with Sort-Object + Select-Object.
    # REFACTOR: Guard against N > list size; validate SortBy parameter.

    Context 'Get-TopNConsumers' {

        It 'returns top 2 processes sorted by CPU descending' {
            $result = Get-TopNConsumers -Processes $script:MockProcesses -TopN 2 -SortBy 'CPU'
            $result.Count    | Should -Be 2
            $result[0].Name  | Should -Be 'chrome'   # 45.5%
            $result[1].Name  | Should -Be 'code'     # 12.3%
        }

        It 'returns top 2 processes sorted by Memory descending' {
            $result = Get-TopNConsumers -Processes $script:MockProcesses -TopN 2 -SortBy 'Memory'
            $result.Count    | Should -Be 2
            $result[0].Name  | Should -Be 'code'     # 1024 MB
            $result[1].Name  | Should -Be 'chrome'   # 512 MB
        }

        It 'returns all processes when TopN exceeds the list count' {
            $result = Get-TopNConsumers -Processes $script:MockProcesses -TopN 100 -SortBy 'CPU'
            $result.Count | Should -Be 4
        }

        It 'returns a single top process when TopN is 1' {
            $result = Get-TopNConsumers -Processes $script:MockProcesses -TopN 1 -SortBy 'CPU'
            $result.Count   | Should -Be 1
            $result[0].Name | Should -Be 'chrome'
        }

        It 'returns an empty array when given an empty input list' {
            $result = Get-TopNConsumers -Processes ([PSCustomObject[]]@()) -TopN 3 -SortBy 'CPU'
            @($result).Count | Should -Be 0
        }
    }

    # ── Cycle 6: New-AlertReport ───────────────────────────────────────────────
    # RED:  Test that the report contains expected sections and data.
    # GREEN: Implement New-AlertReport with StringBuilder.
    # REFACTOR: Clean up formatting; handle empty-list case.

    Context 'New-AlertReport' {

        BeforeAll {
            $script:ReportThresholds = New-ResourceThreshold -MinCPUPercent 10.0 -MinMemoryMB 256.0
            # chrome and code both exceed CPU 10% AND memory 256 MB
            $script:AlertProcesses   = [PSCustomObject[]]@(
                $script:MockProcesses | Where-Object { $_.CPUPercent -ge 10.0 -and $_.MemoryMB -ge 256.0 }
            )
        }

        It 'includes the report title in the output' {
            $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:ReportThresholds -TopN 5
            $report | Should -Match 'Process Monitor Alert Report'
        }

        It 'includes the configured CPU threshold value' {
            $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:ReportThresholds -TopN 5
            $report | Should -Match '10'          # MinCPUPercent = 10.0
        }

        It 'includes the configured memory threshold value' {
            $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:ReportThresholds -TopN 5
            $report | Should -Match '256'         # MinMemoryMB = 256.0
        }

        It 'lists process names that exceeded thresholds' {
            $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:ReportThresholds -TopN 5
            $report | Should -Match 'chrome'
            $report | Should -Match 'code'
        }

        It 'shows a no-processes message when the list is empty' {
            $report = New-AlertReport -Processes ([PSCustomObject[]]@()) -Thresholds $script:ReportThresholds -TopN 5
            $report | Should -Match 'No processes'
        }

        It 'returns a non-empty string' {
            $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:ReportThresholds -TopN 5
            $report | Should -Not -BeNullOrEmpty
        }
    }

    # ── Cycle 7: Invoke-ProcessMonitor (integration) ───────────────────────────
    # RED:  Test the full pipeline with a mocked process provider scriptblock.
    # GREEN: Implement Invoke-ProcessMonitor, wiring all sub-functions together.
    # REFACTOR: Ensure clean separation of the live-data path from the mock path.

    Context 'Invoke-ProcessMonitor' {

        It 'runs end-to-end with injected mock process data' {
            $provider = { $script:MockProcesses }
            $result   = Invoke-ProcessMonitor `
                            -ProcessProvider $provider `
                            -MinCPUPercent 0.0 `
                            -MinMemoryMB   0.0 `
                            -TopN          3   `
                            -SortBy        'CPU'

            $result                      | Should -Not -BeNullOrEmpty
            $result.Report               | Should -Match 'Process Monitor Alert Report'
            $result.TopConsumers.Count   | Should -Be 3
            $result.FilteredProcesses.Count | Should -Be 4
        }

        It 'respects thresholds when filtering via the mock provider' {
            $provider = { $script:MockProcesses }
            $result   = Invoke-ProcessMonitor `
                            -ProcessProvider $provider `
                            -MinCPUPercent 20.0 `
                            -MinMemoryMB   500.0 `
                            -TopN          5 `
                            -SortBy        'CPU'

            # chrome: 45.5% CPU >= 20%, 512 MB >= 500 MB → PASS
            # code:   12.3% CPU < 20%                    → FAIL
            $result.FilteredProcesses.Count   | Should -Be 1
            $result.FilteredProcesses[0].Name | Should -Be 'chrome'
        }

        It 'top consumers reflect the requested sort order' {
            $provider = { $script:MockProcesses }

            $byCPU    = Invoke-ProcessMonitor -ProcessProvider $provider -MinCPUPercent 0.0 -MinMemoryMB 0.0 -TopN 1 -SortBy 'CPU'
            $byMemory = Invoke-ProcessMonitor -ProcessProvider $provider -MinCPUPercent 0.0 -MinMemoryMB 0.0 -TopN 1 -SortBy 'Memory'

            $byCPU.TopConsumers[0].Name    | Should -Be 'chrome'   # highest CPU
            $byMemory.TopConsumers[0].Name | Should -Be 'code'     # highest memory
        }

        It 'surfaces the custom process data injected by the provider' {
            # Use $script: scope so the variable is accessible when the scriptblock
            # is invoked inside Invoke-ProcessMonitor's dynamic scope.
            $script:CustomTestProc = New-ProcessEntry -Name 'custom-proc' -ProcessId 9999 -CPUPercent 88.8 -MemoryMB 2048.0
            $provider = { [PSCustomObject[]]@($script:CustomTestProc) }

            $result = Invoke-ProcessMonitor `
                            -ProcessProvider $provider `
                            -MinCPUPercent 0.0 `
                            -MinMemoryMB   0.0 `
                            -TopN          1 `
                            -SortBy        'CPU'

            $result.TopConsumers[0].Name | Should -Be 'custom-proc'
            $result.Report               | Should -Match 'custom-proc'
        }

        It 'returns the thresholds used in the result object' {
            $provider = { $script:MockProcesses }
            $result   = Invoke-ProcessMonitor `
                            -ProcessProvider $provider `
                            -MinCPUPercent 15.0 `
                            -MinMemoryMB   300.0 `
                            -TopN          2 `
                            -SortBy        'Memory'

            $result.Thresholds.MinCPUPercent | Should -Be 15.0
            $result.Thresholds.MinMemoryMB   | Should -Be 300.0
        }
    }
}
