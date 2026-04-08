# ProcessMonitor.Tests.ps1
# TDD test suite for the Process Monitor module.
# RED/GREEN approach: tests are written before implementation.
# Run with: Invoke-Pester ./ProcessMonitor.Tests.ps1

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

# Import the module under test (will fail on first run — that's the RED step)
$modulePath = Join-Path $PSScriptRoot 'ProcessMonitor.psm1'
Import-Module $modulePath -Force

# ---------------------------------------------------------------------------
# SECTION 1: New-ProcessRecord — data structure creation
# RED: No module exists yet; import above will fail.
# ---------------------------------------------------------------------------
Describe 'New-ProcessRecord' {

    It 'creates a process record with all required fields' {
        $record = New-ProcessRecord -Pid 42 -Name 'chrome' -CpuPercent 15.5 -MemoryMB 512.0

        $record.Pid         | Should -Be 42
        $record.Name        | Should -Be 'chrome'
        $record.CpuPercent  | Should -Be 15.5
        $record.MemoryMB    | Should -Be 512.0
    }

    It 'rejects negative CPU percent' {
        { New-ProcessRecord -Pid 1 -Name 'bad' -CpuPercent -1.0 -MemoryMB 100.0 } |
            Should -Throw
    }

    It 'rejects negative memory' {
        { New-ProcessRecord -Pid 1 -Name 'bad' -CpuPercent 0.0 -MemoryMB -1.0 } |
            Should -Throw
    }
}

# ---------------------------------------------------------------------------
# SECTION 2: Test-ProcessThreshold — threshold filtering logic
# RED: function does not exist yet.
# ---------------------------------------------------------------------------
Describe 'Test-ProcessThreshold' {

    BeforeEach {
        # Build a set of mock process records used across threshold tests
        $script:highCpu  = New-ProcessRecord -Pid 100 -Name 'hog'    -CpuPercent 90.0 -MemoryMB 200.0
        $script:lowCpu   = New-ProcessRecord -Pid 101 -Name 'idle'   -CpuPercent  2.0 -MemoryMB  50.0
        $script:highMem  = New-ProcessRecord -Pid 102 -Name 'leaky'  -CpuPercent  5.0 -MemoryMB 900.0
        $script:highBoth = New-ProcessRecord -Pid 103 -Name 'beast'  -CpuPercent 80.0 -MemoryMB 800.0
    }

    It 'returns true when CPU exceeds threshold' {
        $thresholds = @{ CpuPercent = 50.0; MemoryMB = 1000.0 }
        Test-ProcessThreshold -ProcessRecord $script:highCpu -Thresholds $thresholds |
            Should -BeTrue
    }

    It 'returns false when CPU and memory are both below threshold' {
        $thresholds = @{ CpuPercent = 50.0; MemoryMB = 1000.0 }
        Test-ProcessThreshold -ProcessRecord $script:lowCpu -Thresholds $thresholds |
            Should -BeFalse
    }

    It 'returns true when memory exceeds threshold' {
        $thresholds = @{ CpuPercent = 50.0; MemoryMB = 500.0 }
        Test-ProcessThreshold -ProcessRecord $script:highMem -Thresholds $thresholds |
            Should -BeTrue
    }

    It 'returns true when both CPU and memory exceed thresholds' {
        $thresholds = @{ CpuPercent = 50.0; MemoryMB = 500.0 }
        Test-ProcessThreshold -ProcessRecord $script:highBoth -Thresholds $thresholds |
            Should -BeTrue
    }

    It 'throws when Thresholds hashtable is missing required keys' {
        $badThresholds = @{ CpuPercent = 50.0 }  # missing MemoryMB
        { Test-ProcessThreshold -ProcessRecord $script:highCpu -Thresholds $badThresholds } |
            Should -Throw
    }
}

# ---------------------------------------------------------------------------
# SECTION 3: Get-FilteredProcesses — apply thresholds to a list
# RED: function does not exist yet.
# ---------------------------------------------------------------------------
Describe 'Get-FilteredProcesses' {

    BeforeEach {
        $script:processes = @(
            (New-ProcessRecord -Pid 1 -Name 'systemd'  -CpuPercent  0.5 -MemoryMB  30.0),
            (New-ProcessRecord -Pid 2 -Name 'chrome'   -CpuPercent 75.0 -MemoryMB 600.0),
            (New-ProcessRecord -Pid 3 -Name 'postgres' -CpuPercent 45.0 -MemoryMB 400.0),
            (New-ProcessRecord -Pid 4 -Name 'leaky'    -CpuPercent  3.0 -MemoryMB 700.0)
        )
        $script:thresholds = @{ CpuPercent = 50.0; MemoryMB = 500.0 }
    }

    It 'returns only processes exceeding at least one threshold' {
        $filtered = Get-FilteredProcesses -Processes $script:processes -Thresholds $script:thresholds
        $filtered | Should -HaveCount 2
        ($filtered | Where-Object { $_.Name -eq 'chrome' })  | Should -Not -BeNullOrEmpty
        ($filtered | Where-Object { $_.Name -eq 'leaky' })   | Should -Not -BeNullOrEmpty
    }

    It 'returns empty array when no processes exceed thresholds' {
        $lowThresholds = @{ CpuPercent = 100.0; MemoryMB = 2000.0 }
        $filtered = Get-FilteredProcesses -Processes $script:processes -Thresholds $lowThresholds
        @($filtered) | Should -HaveCount 0
    }

    It 'returns all processes when thresholds are zero' {
        $zeroThresholds = @{ CpuPercent = 0.0; MemoryMB = 0.0 }
        $filtered = Get-FilteredProcesses -Processes $script:processes -Thresholds $zeroThresholds
        @($filtered) | Should -HaveCount 4
    }
}

# ---------------------------------------------------------------------------
# SECTION 4: Get-TopProcesses — identify top N resource consumers
# RED: function does not exist yet.
# ---------------------------------------------------------------------------
Describe 'Get-TopProcesses' {

    BeforeEach {
        $script:processes = @(
            (New-ProcessRecord -Pid 1 -Name 'a' -CpuPercent 10.0 -MemoryMB 100.0),
            (New-ProcessRecord -Pid 2 -Name 'b' -CpuPercent 80.0 -MemoryMB 200.0),
            (New-ProcessRecord -Pid 3 -Name 'c' -CpuPercent 50.0 -MemoryMB 800.0),
            (New-ProcessRecord -Pid 4 -Name 'd' -CpuPercent 30.0 -MemoryMB 400.0),
            (New-ProcessRecord -Pid 5 -Name 'e' -CpuPercent 95.0 -MemoryMB  50.0)
        )
    }

    It 'returns top N by CPU in descending order' {
        $top = Get-TopProcesses -Processes $script:processes -TopN 3 -SortBy 'CpuPercent'
        @($top) | Should -HaveCount 3
        $top[0].Name | Should -Be 'e'   # 95%
        $top[1].Name | Should -Be 'b'   # 80%
        $top[2].Name | Should -Be 'c'   # 50%
    }

    It 'returns top N by memory in descending order' {
        $top = Get-TopProcesses -Processes $script:processes -TopN 2 -SortBy 'MemoryMB'
        @($top) | Should -HaveCount 2
        $top[0].Name | Should -Be 'c'   # 800 MB
        $top[1].Name | Should -Be 'd'   # 400 MB
    }

    It 'returns all processes when TopN exceeds list length' {
        $top = Get-TopProcesses -Processes $script:processes -TopN 100 -SortBy 'CpuPercent'
        @($top) | Should -HaveCount 5
    }

    It 'throws when SortBy value is invalid' {
        { Get-TopProcesses -Processes $script:processes -TopN 3 -SortBy 'InvalidField' } |
            Should -Throw
    }

    It 'returns empty array for empty input' {
        $top = Get-TopProcesses -Processes @() -TopN 3 -SortBy 'CpuPercent'
        @($top) | Should -HaveCount 0
    }
}

# ---------------------------------------------------------------------------
# SECTION 5: New-AlertReport — generate the textual alert report
# RED: function does not exist yet.
# ---------------------------------------------------------------------------
Describe 'New-AlertReport' {

    BeforeEach {
        $script:alertProcesses = @(
            (New-ProcessRecord -Pid 99  -Name 'hog'   -CpuPercent 92.3 -MemoryMB 750.0),
            (New-ProcessRecord -Pid 200 -Name 'leaky' -CpuPercent  4.1 -MemoryMB 910.0)
        )
        $script:thresholds = @{ CpuPercent = 50.0; MemoryMB = 500.0 }
        $script:report = New-AlertReport -AlertProcesses $script:alertProcesses `
                                          -Thresholds $script:thresholds `
                                          -GeneratedAt '2026-01-01T00:00:00Z'
    }

    It 'report contains header' {
        $script:report | Should -Match 'PROCESS MONITOR ALERT REPORT'
    }

    It 'report contains threshold information' {
        $script:report | Should -Match '50'    # CpuPercent threshold
        $script:report | Should -Match '500'   # MemoryMB threshold
    }

    It 'report lists each alerted process by name' {
        $script:report | Should -Match 'hog'
        $script:report | Should -Match 'leaky'
    }

    It 'report includes PID for each process' {
        $script:report | Should -Match '99'
        $script:report | Should -Match '200'
    }

    It 'report includes the generation timestamp' {
        $script:report | Should -Match '2026-01-01'
    }

    It 'report indicates no alerts when list is empty' {
        $emptyReport = New-AlertReport -AlertProcesses @() `
                                        -Thresholds $script:thresholds `
                                        -GeneratedAt '2026-01-01T00:00:00Z'
        $emptyReport | Should -Match 'No processes'
    }
}

# ---------------------------------------------------------------------------
# SECTION 6: Invoke-ProcessMonitor — end-to-end integration with mock data
# RED: function does not exist yet.
# ---------------------------------------------------------------------------
Describe 'Invoke-ProcessMonitor' {

    It 'returns a report string from mock process data' {
        # Mock process list simulates what Get-Process would return in production
        $mockProcesses = @(
            (New-ProcessRecord -Pid 1 -Name 'idle'   -CpuPercent  0.1 -MemoryMB  20.0),
            (New-ProcessRecord -Pid 2 -Name 'chrome' -CpuPercent 85.0 -MemoryMB 700.0),
            (New-ProcessRecord -Pid 3 -Name 'doom'   -CpuPercent 60.0 -MemoryMB 300.0)
        )
        $thresholds = @{ CpuPercent = 50.0; MemoryMB = 500.0 }

        $report = Invoke-ProcessMonitor -Processes $mockProcesses -Thresholds $thresholds -TopN 5

        $report | Should -Match 'PROCESS MONITOR ALERT REPORT'
        $report | Should -Match 'chrome'
        $report | Should -Not -Match 'idle'   # below both thresholds
    }

    It 'respects TopN limit in the report' {
        $mockProcesses = @(
            (New-ProcessRecord -Pid 1 -Name 'p1' -CpuPercent 90.0 -MemoryMB 600.0),
            (New-ProcessRecord -Pid 2 -Name 'p2' -CpuPercent 80.0 -MemoryMB 700.0),
            (New-ProcessRecord -Pid 3 -Name 'p3' -CpuPercent 70.0 -MemoryMB 800.0),
            (New-ProcessRecord -Pid 4 -Name 'p4' -CpuPercent 60.0 -MemoryMB 900.0)
        )
        $thresholds = @{ CpuPercent = 0.0; MemoryMB = 0.0 }  # all qualify

        $report = Invoke-ProcessMonitor -Processes $mockProcesses -Thresholds $thresholds -TopN 2

        # Only top 2 by CPU should appear
        $report | Should -Match 'p1'
        $report | Should -Match 'p2'
        $report | Should -Not -Match 'p3'
        $report | Should -Not -Match 'p4'
    }
}
