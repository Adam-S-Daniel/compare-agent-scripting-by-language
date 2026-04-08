# ProcessMonitor.Tests.ps1
# TDD tests for the Process Monitor script using Pester 5.x
# Red/Green cycle: each Describe block corresponds to one feature

BeforeAll {
    # Dot-source the implementation so all functions are available
    . "$PSScriptRoot/ProcessMonitor.ps1"
}

# ===========================================================================
# Feature 1: Reading / ingesting process data
# ===========================================================================
Describe "Get-ProcessData" {
    Context "When given a mock data provider" {
        It "Returns a list of process objects with required properties" {
            # Arrange – a mock provider returns a fixed list
            $mockProvider = {
                @(
                    [PSCustomObject]@{ PID = 1; Name = "alpha"; CPU = 10.5; MemoryMB = 200 },
                    [PSCustomObject]@{ PID = 2; Name = "beta";  CPU =  5.0; MemoryMB = 100 }
                )
            }

            # Act
            $result = Get-ProcessData -DataProvider $mockProvider

            # Assert
            $result | Should -HaveCount 2
            $result[0].PID     | Should -Be 1
            $result[0].Name    | Should -Be "alpha"
            $result[0].CPU     | Should -Be 10.5
            $result[0].MemoryMB| Should -Be 200
        }

        It "Returns an empty list when the provider returns nothing" {
            $emptyProvider = { @() }
            $result = Get-ProcessData -DataProvider $emptyProvider
            $result | Should -HaveCount 0
        }
    }
}

# ===========================================================================
# Feature 2: Filtering by configurable thresholds
# ===========================================================================
Describe "Invoke-ProcessFilter" {
    BeforeAll {
        $processes = @(
            [PSCustomObject]@{ PID = 1; Name = "high-cpu";  CPU = 80.0; MemoryMB = 100 },
            [PSCustomObject]@{ PID = 2; Name = "high-mem";  CPU =  2.0; MemoryMB = 900 },
            [PSCustomObject]@{ PID = 3; Name = "both-high"; CPU = 75.0; MemoryMB = 800 },
            [PSCustomObject]@{ PID = 4; Name = "low";       CPU =  1.0; MemoryMB =  50 }
        )
        $script:procs = $processes
    }

    It "Returns only processes exceeding the CPU threshold" {
        $result = Invoke-ProcessFilter -Processes $script:procs -CpuThreshold 50 -MemoryMBThreshold 0
        $result | Should -HaveCount 2
        $result.Name | Should -Contain "high-cpu"
        $result.Name | Should -Contain "both-high"
    }

    It "Returns only processes exceeding the memory threshold" {
        $result = Invoke-ProcessFilter -Processes $script:procs -CpuThreshold 0 -MemoryMBThreshold 500
        $result | Should -HaveCount 2
        $result.Name | Should -Contain "high-mem"
        $result.Name | Should -Contain "both-high"
    }

    It "Returns processes exceeding either threshold (OR logic)" {
        $result = Invoke-ProcessFilter -Processes $script:procs -CpuThreshold 50 -MemoryMBThreshold 500
        $result | Should -HaveCount 3
        $result.Name | Should -Not -Contain "low"
    }

    It "Returns an empty list when no processes exceed any threshold" {
        $result = Invoke-ProcessFilter -Processes $script:procs -CpuThreshold 99 -MemoryMBThreshold 9999
        $result | Should -HaveCount 0
    }
}

# ===========================================================================
# Feature 3: Identifying top N resource consumers
# ===========================================================================
Describe "Get-TopConsumers" {
    BeforeAll {
        $script:procs = @(
            [PSCustomObject]@{ PID = 1; Name = "a"; CPU = 30.0; MemoryMB = 100 },
            [PSCustomObject]@{ PID = 2; Name = "b"; CPU = 90.0; MemoryMB = 200 },
            [PSCustomObject]@{ PID = 3; Name = "c"; CPU = 50.0; MemoryMB = 500 },
            [PSCustomObject]@{ PID = 4; Name = "d"; CPU = 10.0; MemoryMB = 800 },
            [PSCustomObject]@{ PID = 5; Name = "e"; CPU = 70.0; MemoryMB = 300 }
        )
    }

    It "Returns the top N processes by CPU usage" {
        $result = Get-TopConsumers -Processes $script:procs -Top 3 -SortBy "CPU"
        $result | Should -HaveCount 3
        $result[0].Name | Should -Be "b"   # 90%
        $result[1].Name | Should -Be "e"   # 70%
        $result[2].Name | Should -Be "c"   # 50%
    }

    It "Returns the top N processes by MemoryMB usage" {
        $result = Get-TopConsumers -Processes $script:procs -Top 2 -SortBy "MemoryMB"
        $result | Should -HaveCount 2
        $result[0].Name | Should -Be "d"   # 800 MB
        $result[1].Name | Should -Be "c"   # 500 MB
    }

    It "Returns all processes when N exceeds the list size" {
        $result = Get-TopConsumers -Processes $script:procs -Top 100 -SortBy "CPU"
        $result | Should -HaveCount 5
    }

    It "Throws a meaningful error when SortBy is invalid" {
        { Get-TopConsumers -Processes $script:procs -Top 3 -SortBy "InvalidProp" } |
            Should -Throw "*not a valid sort property*"
    }
}

# ===========================================================================
# Feature 4: Generating the alert report
# ===========================================================================
Describe "New-AlertReport" {
    BeforeAll {
        $script:alertProcs = @(
            [PSCustomObject]@{ PID = 7;  Name = "svchost"; CPU = 88.0; MemoryMB = 1024 },
            [PSCustomObject]@{ PID = 42; Name = "chrome";  CPU = 55.0; MemoryMB = 2048 }
        )
    }

    It "Returns a string report" {
        $report = New-AlertReport -Processes $script:alertProcs
        $report | Should -BeOfType [string]
    }

    It "Report contains header section" {
        $report = New-AlertReport -Processes $script:alertProcs
        $report | Should -Match "PROCESS ALERT REPORT"
    }

    It "Report lists each alerted process" {
        $report = New-AlertReport -Processes $script:alertProcs
        $report | Should -Match "svchost"
        $report | Should -Match "chrome"
    }

    It "Report contains PID, CPU, and MemoryMB columns" {
        $report = New-AlertReport -Processes $script:alertProcs
        $report | Should -Match "PID"
        $report | Should -Match "CPU"
        $report | Should -Match "Memory"
    }

    It "Returns a no-alerts message when list is empty" {
        $report = New-AlertReport -Processes @()
        $report | Should -Match "No processes"
    }
}

# ===========================================================================
# Feature 5: End-to-end pipeline (integration test with mocks)
# ===========================================================================
Describe "Invoke-ProcessMonitor (integration)" {
    It "Returns a report string from start to finish using mocked data" {
        $mockProvider = {
            @(
                [PSCustomObject]@{ PID = 10; Name = "worker"; CPU = 95.0; MemoryMB = 2000 },
                [PSCustomObject]@{ PID = 11; Name = "idle";   CPU =  0.5; MemoryMB =   20 }
            )
        }

        $report = Invoke-ProcessMonitor `
            -DataProvider    $mockProvider `
            -CpuThreshold    50 `
            -MemoryMBThreshold 500 `
            -Top             5 `
            -SortBy          "CPU"

        $report | Should -BeOfType [string]
        $report | Should -Match "worker"
        $report | Should -Not -Match "idle"
    }

    It "Reports no alerts when all processes are below thresholds" {
        $mockProvider = {
            @(
                [PSCustomObject]@{ PID = 1; Name = "quiet"; CPU = 1.0; MemoryMB = 10 }
            )
        }

        $report = Invoke-ProcessMonitor `
            -DataProvider      $mockProvider `
            -CpuThreshold      80 `
            -MemoryMBThreshold 500 `
            -Top               5 `
            -SortBy            "CPU"

        $report | Should -Match "No processes"
    }
}
