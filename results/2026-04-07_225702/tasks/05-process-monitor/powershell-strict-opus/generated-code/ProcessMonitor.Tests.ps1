Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/ProcessMonitor.ps1"

    # Helper: build a standard mock process list used across multiple test groups
    function New-MockProcessList {
        [CmdletBinding()]
        [OutputType([PSCustomObject[]])]
        param()
        @(
            (New-ProcessInfo -ProcessId 100 -Name 'idle'    -CpuPercent 0.5  -MemoryMB 10.0),
            (New-ProcessInfo -ProcessId 200 -Name 'browser' -CpuPercent 55.0 -MemoryMB 1200.0),
            (New-ProcessInfo -ProcessId 300 -Name 'editor'  -CpuPercent 12.0 -MemoryMB 800.0),
            (New-ProcessInfo -ProcessId 400 -Name 'dbserv'  -CpuPercent 80.0 -MemoryMB 2048.0),
            (New-ProcessInfo -ProcessId 500 -Name 'logger'  -CpuPercent 3.0  -MemoryMB 50.0)
        )
    }
}

Describe 'New-ProcessInfo' {
    It 'creates a process info object with all required fields' {
        $proc = New-ProcessInfo -ProcessId 1234 -Name 'testapp' -CpuPercent 45.2 -MemoryMB 512.0
        $proc.PID | Should -Be 1234
        $proc.Name | Should -Be 'testapp'
        $proc.CpuPercent | Should -Be 45.2
        $proc.MemoryMB | Should -Be 512.0
    }

    It 'rejects negative CPU percent' {
        { New-ProcessInfo -ProcessId 1 -Name 'x' -CpuPercent -5.0 -MemoryMB 10.0 } |
            Should -Throw '*CPU percent cannot be negative*'
    }

    It 'rejects negative memory' {
        { New-ProcessInfo -ProcessId 1 -Name 'x' -CpuPercent 0.0 -MemoryMB -1.0 } |
            Should -Throw '*Memory cannot be negative*'
    }

    It 'rejects empty name' {
        { New-ProcessInfo -ProcessId 1 -Name '' -CpuPercent 0.0 -MemoryMB 0.0 } |
            Should -Throw '*Process name cannot be empty*'
    }
}

Describe 'Get-FilteredProcesses' {
    BeforeAll {
        $script:procs = New-MockProcessList
    }

    It 'filters by CPU threshold only' {
        $result = Get-FilteredProcesses -Processes $script:procs -CpuThreshold 50.0
        $result | Should -HaveCount 2
        $result.Name | Should -Contain 'browser'
        $result.Name | Should -Contain 'dbserv'
    }

    It 'filters by memory threshold only' {
        $result = Get-FilteredProcesses -Processes $script:procs -MemoryThresholdMB 1000.0
        $result | Should -HaveCount 2
        $result.Name | Should -Contain 'browser'
        $result.Name | Should -Contain 'dbserv'
    }

    It 'filters by both CPU and memory (OR logic — exceeding either triggers inclusion)' {
        $result = Get-FilteredProcesses -Processes $script:procs -CpuThreshold 50.0 -MemoryThresholdMB 700.0
        $result | Should -HaveCount 3
        $result.Name | Should -Contain 'browser'
        $result.Name | Should -Contain 'editor'
        $result.Name | Should -Contain 'dbserv'
    }

    It 'returns nothing when no process exceeds thresholds' {
        $result = Get-FilteredProcesses -Processes $script:procs -CpuThreshold 99.0 -MemoryThresholdMB 9999.0
        $result | Should -HaveCount 0
    }

    It 'returns all processes when thresholds are zero' {
        $result = Get-FilteredProcesses -Processes $script:procs -CpuThreshold 0.0 -MemoryThresholdMB 0.0
        $result | Should -HaveCount 5
    }
}

Describe 'Get-TopConsumers' {
    BeforeAll {
        $script:procs = New-MockProcessList
    }

    It 'returns top N processes by CPU (descending)' {
        $top = Get-TopConsumers -Processes $script:procs -SortBy 'CPU' -Count 3
        $top | Should -HaveCount 3
        $top[0].Name | Should -Be 'dbserv'   # 80%
        $top[1].Name | Should -Be 'browser'  # 55%
        $top[2].Name | Should -Be 'editor'   # 12%
    }

    It 'returns top N processes by Memory (descending)' {
        $top = Get-TopConsumers -Processes $script:procs -SortBy 'Memory' -Count 2
        $top | Should -HaveCount 2
        $top[0].Name | Should -Be 'dbserv'   # 2048 MB
        $top[1].Name | Should -Be 'browser'  # 1200 MB
    }

    It 'returns all when Count exceeds list size' {
        $top = Get-TopConsumers -Processes $script:procs -SortBy 'CPU' -Count 100
        $top | Should -HaveCount 5
    }

    It 'rejects invalid SortBy value' {
        { Get-TopConsumers -Processes $script:procs -SortBy 'Disk' -Count 3 } |
            Should -Throw '*SortBy must be*'
    }

    It 'rejects Count less than 1' {
        { Get-TopConsumers -Processes $script:procs -SortBy 'CPU' -Count 0 } |
            Should -Throw '*Count must be at least 1*'
    }
}

Describe 'New-AlertReport' {
    BeforeAll {
        $script:procs = New-MockProcessList
    }

    It 'generates a report with header, thresholds, and alert entries' {
        $alerting = @(
            (New-ProcessInfo -ProcessId 400 -Name 'dbserv'  -CpuPercent 80.0 -MemoryMB 2048.0),
            (New-ProcessInfo -ProcessId 200 -Name 'browser' -CpuPercent 55.0 -MemoryMB 1200.0)
        )
        $report = New-AlertReport -AlertProcesses $alerting `
            -CpuThreshold 50.0 -MemoryThresholdMB 1000.0 -TopN 3

        # Report is a string containing key sections
        $report | Should -Match 'PROCESS MONITOR ALERT REPORT'
        $report | Should -Match 'CPU Threshold:\s+50'
        $report | Should -Match 'Memory Threshold:\s+1000'
        $report | Should -Match 'dbserv'
        $report | Should -Match 'browser'
        $report | Should -Match '400'   # PID
        $report | Should -Match '200'   # PID
    }

    It 'produces a no-alerts message when list is empty' {
        [PSCustomObject[]]$empty = @()
        $report = New-AlertReport -AlertProcesses $empty `
            -CpuThreshold 50.0 -MemoryThresholdMB 1000.0 -TopN 3
        $report | Should -Match 'No processes exceed'
    }
}

Describe 'Invoke-ProcessMonitor (end-to-end with mock data)' {
    It 'runs the full pipeline and returns a report string' {
        $mockProcs = New-MockProcessList
        $report = Invoke-ProcessMonitor -Processes $mockProcs `
            -CpuThreshold 10.0 -MemoryThresholdMB 500.0 -TopN 2

        # Should mention the top offenders
        $report | Should -Match 'dbserv'
        $report | Should -Match 'browser'
        $report | Should -BeOfType [string]
    }

    It 'returns no-alert report when nothing exceeds thresholds' {
        $mockProcs = New-MockProcessList
        $report = Invoke-ProcessMonitor -Processes $mockProcs `
            -CpuThreshold 99.0 -MemoryThresholdMB 9999.0 -TopN 5
        $report | Should -Match 'No processes exceed'
    }
}

Describe 'Read-ProcessData' {
    It 'reads from a scriptblock data source for testability' {
        # Mock data source: a scriptblock that returns process-like objects
        [scriptblock]$mockSource = {
            @(
                [PSCustomObject]@{ Id = 10; ProcessName = 'mock1'; CPU = [double]22.5; WorkingSet64 = [long](300MB) },
                [PSCustomObject]@{ Id = 20; ProcessName = 'mock2'; CPU = [double]5.0;  WorkingSet64 = [long](64MB) }
            )
        }
        $result = Read-ProcessData -DataSource $mockSource
        $result | Should -HaveCount 2
        $result[0].PID | Should -Be 10
        $result[0].Name | Should -Be 'mock1'
        $result[0].CpuPercent | Should -Be 22.5
        # Memory should be converted from bytes to MB
        [double]$expectedMB = [math]::Round([double](300MB) / 1MB, 1)
        $result[0].MemoryMB | Should -Be $expectedMB
    }

    It 'handles a data source that returns nothing gracefully' {
        [scriptblock]$emptySource = { @() }
        $result = Read-ProcessData -DataSource $emptySource
        $result | Should -HaveCount 0
    }
}

Describe 'Edge cases' {
    It 'handles a single-process list through the full pipeline' {
        [PSCustomObject[]]$single = @(
            (New-ProcessInfo -ProcessId 1 -Name 'solo' -CpuPercent 99.0 -MemoryMB 4096.0)
        )
        $report = Invoke-ProcessMonitor -Processes $single `
            -CpuThreshold 0.0 -MemoryThresholdMB 0.0 -TopN 1
        $report | Should -Match 'solo'
        $report | Should -Match '99'
    }

    It 'TopN larger than filtered set does not error' {
        [PSCustomObject[]]$small = @(
            (New-ProcessInfo -ProcessId 1 -Name 'a' -CpuPercent 50.0 -MemoryMB 100.0)
        )
        $report = Invoke-ProcessMonitor -Processes $small `
            -CpuThreshold 10.0 -MemoryThresholdMB 50.0 -TopN 10
        $report | Should -Match 'a'
    }
}
