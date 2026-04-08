# ProcessMonitor.Tests.ps1
# TDD tests for the Process Monitor script using Pester 5.x
# Each test was written FIRST (red), then implementation added (green), then refactored.

BeforeAll {
    . $PSScriptRoot/ProcessMonitor.ps1
}

Describe "Get-ProcessInfo" {
    It "returns process objects with required properties (CPU, Memory, PID, Name)" {
        # Arrange: mock data source so we don't depend on live system state
        $mockProcesses = @(
            [PSCustomObject]@{ Id = 1; ProcessName = "app1"; CPU = 50.5; WorkingSet64 = 104857600 }
            [PSCustomObject]@{ Id = 2; ProcessName = "app2"; CPU = 10.2; WorkingSet64 = 52428800 }
        )

        # Act
        $result = Get-ProcessInfo -ProcessData $mockProcesses

        # Assert: each result has the expected properties
        $result | Should -HaveCount 2
        $result[0].PID | Should -Be 1
        $result[0].Name | Should -Be "app1"
        $result[0].CPUPercent | Should -Be 50.5
        $result[0].MemoryMB | Should -Be 100  # 104857600 / 1MB = 100
        $result[1].PID | Should -Be 2
        $result[1].Name | Should -Be "app2"
    }
}

Describe "Get-FilteredProcesses" {
    BeforeAll {
        # Shared mock data in normalized format
        $script:testProcesses = @(
            [PSCustomObject]@{ PID = 1; Name = "heavy-cpu";  CPUPercent = 85.0; MemoryMB = 50 }
            [PSCustomObject]@{ PID = 2; Name = "heavy-mem";  CPUPercent = 5.0;  MemoryMB = 900 }
            [PSCustomObject]@{ PID = 3; Name = "light";      CPUPercent = 1.0;  MemoryMB = 20 }
            [PSCustomObject]@{ PID = 4; Name = "both-heavy"; CPUPercent = 90.0; MemoryMB = 1024 }
        )
    }

    It "filters processes exceeding CPU threshold" {
        $result = Get-FilteredProcesses -Processes $script:testProcesses -CPUThreshold 80
        $result.Name | Should -Contain "heavy-cpu"
        $result.Name | Should -Contain "both-heavy"
        $result.Name | Should -Not -Contain "light"
        $result.Name | Should -Not -Contain "heavy-mem"
    }

    It "filters processes exceeding memory threshold" {
        $result = Get-FilteredProcesses -Processes $script:testProcesses -MemoryThresholdMB 500
        $result.Name | Should -Contain "heavy-mem"
        $result.Name | Should -Contain "both-heavy"
        $result.Name | Should -Not -Contain "light"
    }

    It "filters processes exceeding EITHER threshold (OR logic)" {
        $result = Get-FilteredProcesses -Processes $script:testProcesses -CPUThreshold 80 -MemoryThresholdMB 500
        $result | Should -HaveCount 3
        $result.Name | Should -Contain "heavy-cpu"
        $result.Name | Should -Contain "heavy-mem"
        $result.Name | Should -Contain "both-heavy"
    }

    It "returns nothing when no processes exceed thresholds" {
        $result = Get-FilteredProcesses -Processes $script:testProcesses -CPUThreshold 99 -MemoryThresholdMB 9999
        $result | Should -BeNullOrEmpty
    }
}

Describe "Get-TopConsumers" {
    BeforeAll {
        $script:testProcesses = @(
            [PSCustomObject]@{ PID = 1; Name = "a"; CPUPercent = 10.0; MemoryMB = 200 }
            [PSCustomObject]@{ PID = 2; Name = "b"; CPUPercent = 80.0; MemoryMB = 50 }
            [PSCustomObject]@{ PID = 3; Name = "c"; CPUPercent = 50.0; MemoryMB = 800 }
            [PSCustomObject]@{ PID = 4; Name = "d"; CPUPercent = 90.0; MemoryMB = 100 }
            [PSCustomObject]@{ PID = 5; Name = "e"; CPUPercent = 30.0; MemoryMB = 400 }
        )
    }

    It "returns top N processes sorted by CPU descending" {
        $result = Get-TopConsumers -Processes $script:testProcesses -TopN 3 -SortBy CPU
        $result | Should -HaveCount 3
        $result[0].Name | Should -Be "d"   # 90%
        $result[1].Name | Should -Be "b"   # 80%
        $result[2].Name | Should -Be "c"   # 50%
    }

    It "returns top N processes sorted by Memory descending" {
        $result = Get-TopConsumers -Processes $script:testProcesses -TopN 2 -SortBy Memory
        $result | Should -HaveCount 2
        $result[0].Name | Should -Be "c"   # 800 MB
        $result[1].Name | Should -Be "e"   # 400 MB
    }

    It "returns all processes when TopN exceeds count" {
        $result = Get-TopConsumers -Processes $script:testProcesses -TopN 100 -SortBy CPU
        $result | Should -HaveCount 5
    }

    It "defaults to sorting by CPU" {
        $result = Get-TopConsumers -Processes $script:testProcesses -TopN 1
        $result[0].Name | Should -Be "d"
    }
}

Describe "New-AlertReport" {
    BeforeAll {
        $script:alertProcesses = @(
            [PSCustomObject]@{ PID = 100; Name = "runaway"; CPUPercent = 95.5; MemoryMB = 1200 }
            [PSCustomObject]@{ PID = 200; Name = "leaker";  CPUPercent = 12.0; MemoryMB = 3000 }
        )
    }

    It "generates a report string containing all alerted process names" {
        $report = New-AlertReport -Processes $script:alertProcesses -CPUThreshold 80 -MemoryThresholdMB 1024
        $report | Should -BeOfType [string]
        $report | Should -Match "runaway"
        $report | Should -Match "leaker"
    }

    It "includes threshold values in the report header" {
        $report = New-AlertReport -Processes $script:alertProcesses -CPUThreshold 80 -MemoryThresholdMB 1024
        $report | Should -Match "80"
        $report | Should -Match "1024"
    }

    It "includes PID, CPU, and memory values for each process" {
        $report = New-AlertReport -Processes $script:alertProcesses -CPUThreshold 80 -MemoryThresholdMB 1024
        $report | Should -Match "100"
        $report | Should -Match "95.5"
        $report | Should -Match "1200"
        $report | Should -Match "200"
        $report | Should -Match "3000"
    }

    It "returns a no-alerts message when process list is empty" {
        $report = New-AlertReport -Processes @() -CPUThreshold 80 -MemoryThresholdMB 1024
        $report | Should -Match "No processes exceed"
    }
}

Describe "Invoke-ProcessMonitor" {
    It "orchestrates the full pipeline: normalize, filter, top-N, report" {
        # Arrange: mock raw process data
        $mockRaw = @(
            [PSCustomObject]@{ Id = 1; ProcessName = "idle";   CPU = 0.5;  WorkingSet64 = 10485760 }
            [PSCustomObject]@{ Id = 2; ProcessName = "worker"; CPU = 75.0; WorkingSet64 = 524288000 }
            [PSCustomObject]@{ Id = 3; ProcessName = "hog";    CPU = 95.0; WorkingSet64 = 2147483648 }
            [PSCustomObject]@{ Id = 4; ProcessName = "mid";    CPU = 40.0; WorkingSet64 = 209715200 }
        )

        # Act: run full pipeline with CPU threshold 50%, top 2
        $result = Invoke-ProcessMonitor -ProcessData $mockRaw -CPUThreshold 50 -MemoryThresholdMB 1024 -TopN 2

        # Assert: returns a report object with both report text and filtered data
        $result.Report | Should -Match "hog"
        $result.Report | Should -Match "worker"
        $result.AlertedProcesses | Should -HaveCount 2
    }

    It "returns a clean report when no processes exceed thresholds" {
        $mockRaw = @(
            [PSCustomObject]@{ Id = 1; ProcessName = "quiet"; CPU = 1.0; WorkingSet64 = 1048576 }
        )

        $result = Invoke-ProcessMonitor -ProcessData $mockRaw -CPUThreshold 99 -MemoryThresholdMB 9999 -TopN 5
        $result.Report | Should -Match "No processes exceed"
        $result.AlertedProcesses | Should -HaveCount 0
    }

    It "handles null CPU values gracefully (processes without CPU time)" {
        $mockRaw = @(
            [PSCustomObject]@{ Id = 10; ProcessName = "zombie"; CPU = $null; WorkingSet64 = 0 }
        )

        # Should not throw — graceful handling of null/missing CPU
        { Invoke-ProcessMonitor -ProcessData $mockRaw -CPUThreshold 50 -MemoryThresholdMB 100 -TopN 5 } |
            Should -Not -Throw
    }
}

Describe "Error handling" {
    It "Get-FilteredProcesses throws on null Processes parameter" {
        { Get-FilteredProcesses -Processes $null -CPUThreshold 50 } | Should -Throw
    }

    It "Get-TopConsumers throws on null Processes parameter" {
        { Get-TopConsumers -Processes $null -TopN 3 } | Should -Throw
    }

    It "Get-TopConsumers rejects invalid SortBy value" {
        $procs = @([PSCustomObject]@{ PID = 1; Name = "x"; CPUPercent = 1; MemoryMB = 1 })
        { Get-TopConsumers -Processes $procs -SortBy "Disk" } | Should -Throw
    }
}
