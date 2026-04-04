# ProcessMonitor.Tests.ps1
# Pester tests for the ProcessMonitor module.
# Written using red/green TDD: each Describe block represents a TDD cycle where
# the test was written FIRST (RED), then the minimum implementation (GREEN),
# then refactored. Tests use mock data fixtures to avoid dependence on live state.

BeforeAll {
    # Import the module under test
    Import-Module "$PSScriptRoot/ProcessMonitor.psm1" -Force

    # Shared mock process data fixture used across test blocks.
    # Provides deterministic, repeatable process data for all tests.
    function Get-MockProcessData {
        @(
            [PSCustomObject]@{ PID = 100; Name = "chrome";   CPUPercent = 45.2; MemoryMB = 1024.0 }
            [PSCustomObject]@{ PID = 200; Name = "firefox";  CPUPercent = 30.1; MemoryMB = 768.5  }
            [PSCustomObject]@{ PID = 300; Name = "code";     CPUPercent = 15.0; MemoryMB = 512.0  }
            [PSCustomObject]@{ PID = 400; Name = "slack";    CPUPercent = 8.5;  MemoryMB = 256.0  }
            [PSCustomObject]@{ PID = 500; Name = "notepad";  CPUPercent = 0.1;  MemoryMB = 10.0   }
        )
    }
}

# =============================================================================
# TDD Cycle 1: Get-ProcessData
# RED:   Function doesn't exist yet -> all tests fail with CommandNotFoundException
# GREEN: Implement Get-ProcessData accepting a -DataSource scriptblock
# REFACTOR: Extract default data source, add error wrapping
# =============================================================================
Describe "Get-ProcessData" {
    Context "when given a custom data source (mock injection)" {
        It "returns process objects with PID, Name, CPUPercent, and MemoryMB properties" {
            # Arrange: inject a mock data source scriptblock
            $mockSource = { Get-MockProcessData }

            # Act
            $result = Get-ProcessData -DataSource $mockSource

            # Assert: verify structure and count
            $result | Should -HaveCount 5
            $result[0].PID | Should -Be 100
            $result[0].Name | Should -Be "chrome"
            $result[0].CPUPercent | Should -Be 45.2
            $result[0].MemoryMB | Should -Be 1024.0
        }

        It "returns all items from the data source preserving order" {
            $mockSource = { Get-MockProcessData }
            $result = Get-ProcessData -DataSource $mockSource
            $result | Should -HaveCount 5
            $result[-1].Name | Should -Be "notepad"
        }

        It "returns an empty array when the data source yields nothing" {
            $emptySource = { }
            $result = Get-ProcessData -DataSource $emptySource
            $result | Should -HaveCount 0
        }
    }

    Context "when no data source is provided" {
        It "uses the default system data source without throwing" {
            # Verifies the default path works; actual values are system-dependent
            { Get-ProcessData } | Should -Not -Throw
        }
    }

    Context "error handling" {
        It "throws a meaningful error when the data source fails" {
            $badSource = { throw "Connection failed" }
            { Get-ProcessData -DataSource $badSource } | Should -Throw "*Failed to retrieve process data*"
        }
    }
}

# =============================================================================
# TDD Cycle 2: Filter-ProcessByThreshold
# RED:   Function doesn't exist -> tests fail
# GREEN: Implement Where-Object filtering by CPU -or Memory threshold
# REFACTOR: Add input validation for negative thresholds
# =============================================================================
Describe "Filter-ProcessByThreshold" {
    BeforeAll {
        $script:testProcesses = Get-MockProcessData
    }

    Context "filtering by CPU threshold only" {
        It "returns only processes with CPU above the threshold" {
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -CPUThreshold 20
            # chrome(45.2) and firefox(30.1) exceed 20
            $result | Should -HaveCount 2
            $result[0].Name | Should -Be "chrome"
            $result[1].Name | Should -Be "firefox"
        }

        It "returns all processes when CPU threshold is 0" {
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -CPUThreshold 0
            $result | Should -HaveCount 5
        }

        It "returns no processes when CPU threshold is very high" {
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -CPUThreshold 99
            $result | Should -HaveCount 0
        }
    }

    Context "filtering by memory threshold only" {
        It "returns only processes with memory above the threshold" {
            # Memory > 500: chrome(1024), firefox(768.5), code(512) = 3
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -MemoryThresholdMB 500
            $result | Should -HaveCount 3
            $result[0].Name | Should -Be "chrome"
        }

        It "returns all processes when memory threshold is 0" {
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -MemoryThresholdMB 0
            $result | Should -HaveCount 5
        }
    }

    Context "filtering by both CPU and memory thresholds (union)" {
        It "returns processes exceeding either threshold" {
            # CPU > 25: chrome(45.2), firefox(30.1)
            # Memory > 600: chrome(1024), firefox(768.5)
            # Union (no dupes): chrome, firefox = 2
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -CPUThreshold 25 -MemoryThresholdMB 600
            $result | Should -HaveCount 2
        }

        It "returns the union without duplicates" {
            # CPU > 10: chrome, firefox, code
            # Memory > 700: chrome, firefox
            # Union: chrome, firefox, code = 3
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses -CPUThreshold 10 -MemoryThresholdMB 700
            $result | Should -HaveCount 3
        }
    }

    Context "with default thresholds" {
        It "uses default thresholds (0, 0) and returns all processes" {
            $result = Filter-ProcessByThreshold -Processes $script:testProcesses
            $result | Should -HaveCount 5
        }
    }

    Context "error handling" {
        It "returns empty array when given an empty process list" {
            $result = Filter-ProcessByThreshold -Processes @() -CPUThreshold 10
            $result | Should -HaveCount 0
        }

        It "throws when CPU threshold is negative" {
            { Filter-ProcessByThreshold -Processes $script:testProcesses -CPUThreshold -5 } |
                Should -Throw "*threshold cannot be negative*"
        }

        It "throws when memory threshold is negative" {
            { Filter-ProcessByThreshold -Processes $script:testProcesses -MemoryThresholdMB -10 } |
                Should -Throw "*threshold cannot be negative*"
        }
    }
}

# =============================================================================
# TDD Cycle 3: Get-TopConsumers
# RED:   Function doesn't exist -> tests fail
# GREEN: Implement Sort-Object + Select-Object -First with SortBy parameter
# REFACTOR: Add TopN/SortBy validation
# =============================================================================
Describe "Get-TopConsumers" {
    BeforeAll {
        $script:testProcesses = Get-MockProcessData
    }

    Context "sorting by CPU (default)" {
        It "returns top N processes sorted by CPU descending" {
            $result = Get-TopConsumers -Processes $script:testProcesses -TopN 3
            $result | Should -HaveCount 3
            $result[0].Name | Should -Be "chrome"
            $result[1].Name | Should -Be "firefox"
            $result[2].Name | Should -Be "code"
        }

        It "returns top 1 process" {
            $result = Get-TopConsumers -Processes $script:testProcesses -TopN 1
            $result | Should -HaveCount 1
            $result[0].Name | Should -Be "chrome"
        }
    }

    Context "sorting by memory" {
        It "returns top N processes sorted by memory descending" {
            $result = Get-TopConsumers -Processes $script:testProcesses -TopN 2 -SortBy Memory
            $result | Should -HaveCount 2
            $result[0].Name | Should -Be "chrome"
            $result[1].Name | Should -Be "firefox"
        }
    }

    Context "when TopN exceeds available processes" {
        It "returns all processes when TopN is larger than the list" {
            $result = Get-TopConsumers -Processes $script:testProcesses -TopN 100
            $result | Should -HaveCount 5
        }
    }

    Context "default TopN" {
        It "defaults to top 5 when TopN is not specified" {
            $result = Get-TopConsumers -Processes $script:testProcesses
            $result | Should -HaveCount 5
        }
    }

    Context "error handling" {
        It "returns empty array when given empty process list" {
            $result = Get-TopConsumers -Processes @() -TopN 3
            $result | Should -HaveCount 0
        }

        It "throws when TopN is zero" {
            { Get-TopConsumers -Processes $script:testProcesses -TopN 0 } |
                Should -Throw "*TopN must be a positive integer*"
        }

        It "throws when TopN is negative" {
            { Get-TopConsumers -Processes $script:testProcesses -TopN -1 } |
                Should -Throw "*TopN must be a positive integer*"
        }

        It "throws for invalid SortBy value" {
            { Get-TopConsumers -Processes $script:testProcesses -SortBy "Disk" } |
                Should -Throw "*SortBy must be 'CPU' or 'Memory'*"
        }
    }
}

# =============================================================================
# TDD Cycle 4: New-AlertReport
# RED:   Function doesn't exist -> tests fail
# GREEN: Implement report generation combining filter + top-N + formatting
# REFACTOR: Extract report sections, improve formatting
# =============================================================================
Describe "New-AlertReport" {
    BeforeAll {
        $script:testProcesses = Get-MockProcessData
    }

    Context "basic report generation" {
        It "generates a report string containing a header" {
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 10 -MemoryThresholdMB 500
            $report | Should -Match "PROCESS MONITOR ALERT REPORT"
        }

        It "includes threshold configuration in the report" {
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 10 -MemoryThresholdMB 500
            $report | Should -Match "CPU Threshold:\s+10%"
            $report | Should -Match "Memory Threshold:\s+500 MB"
        }

        It "includes process names in the report" {
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 10 -MemoryThresholdMB 500
            $report | Should -Match "chrome"
            $report | Should -Match "firefox"
            $report | Should -Match "code"
        }

        It "includes PID, CPU%, and memory for each listed process" {
            $singleProc = @(
                [PSCustomObject]@{ PID = 100; Name = "chrome"; CPUPercent = 45.2; MemoryMB = 1024.0 }
            )
            $report = New-AlertReport -Processes $singleProc -CPUThreshold 0 -MemoryThresholdMB 0
            $report | Should -Match "100"
            $report | Should -Match "45\.2"
            $report | Should -Match "1024"
        }
    }

    Context "top N consumers in report" {
        It "limits report to top N consumers" {
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 0 -MemoryThresholdMB 0 -TopN 2
            # Top 2 by CPU: chrome, firefox. notepad should NOT appear.
            $report | Should -Match "chrome"
            $report | Should -Match "firefox"
            $report | Should -Not -Match "notepad"
        }
    }

    Context "report with no matching processes" {
        It "reports that no processes exceed thresholds" {
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 99 -MemoryThresholdMB 99999
            $report | Should -Match "No processes exceed"
        }
    }

    Context "report includes timestamp" {
        It "includes a date/time stamp in the report" {
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 0 -MemoryThresholdMB 0
            $report | Should -Match "\d{4}-\d{2}-\d{2}"
        }
    }

    Context "report includes alert count summary" {
        It "shows the count of alerting processes" {
            # CPU > 20: chrome(45.2), firefox(30.1) = 2 processes
            $report = New-AlertReport -Processes $script:testProcesses -CPUThreshold 20 -MemoryThresholdMB 99999
            $report | Should -Match "2 process"
        }
    }

    Context "error handling" {
        It "handles empty process list gracefully" {
            $report = New-AlertReport -Processes @() -CPUThreshold 10 -MemoryThresholdMB 500
            $report | Should -Match "No processes exceed"
        }
    }
}

# =============================================================================
# TDD Cycle 5: End-to-end integration
# Verifies the full pipeline: data acquisition -> filter -> top-N -> report
# =============================================================================
Describe "End-to-end pipeline" {
    It "chains Get-ProcessData, Filter, TopConsumers, and Report together" {
        # Arrange: three processes with varying resource usage
        $mockSource = {
            @(
                [PSCustomObject]@{ PID = 1; Name = "heavy-app";  CPUPercent = 90.0; MemoryMB = 2048.0 }
                [PSCustomObject]@{ PID = 2; Name = "medium-app"; CPUPercent = 40.0; MemoryMB = 512.0  }
                [PSCustomObject]@{ PID = 3; Name = "light-app";  CPUPercent = 2.0;  MemoryMB = 32.0   }
            )
        }

        # Act: run full pipeline
        $processes = Get-ProcessData -DataSource $mockSource
        $filtered  = Filter-ProcessByThreshold -Processes $processes -CPUThreshold 10 -MemoryThresholdMB 100
        $top       = Get-TopConsumers -Processes $filtered -TopN 2
        $report    = New-AlertReport -Processes $processes -CPUThreshold 10 -MemoryThresholdMB 100 -TopN 2

        # Assert: each stage produces expected results
        $processes | Should -HaveCount 3
        $filtered  | Should -HaveCount 2
        $filtered[0].Name | Should -Be "heavy-app"
        $top | Should -HaveCount 2
        $report | Should -Match "heavy-app"
        $report | Should -Match "medium-app"
        $report | Should -Not -Match "light-app"
    }

    It "works correctly with a single-process input" {
        $mockSource = {
            @(
                [PSCustomObject]@{ PID = 42; Name = "solo"; CPUPercent = 50.0; MemoryMB = 100.0 }
            )
        }

        $processes = Get-ProcessData -DataSource $mockSource
        $report = New-AlertReport -Processes $processes -CPUThreshold 0 -MemoryThresholdMB 0
        $report | Should -Match "solo"
        $report | Should -Match "1 process"
    }

    It "produces a complete report with configurable sort order" {
        $mockSource = {
            @(
                [PSCustomObject]@{ PID = 10; Name = "low-cpu-high-mem"; CPUPercent = 5.0;  MemoryMB = 4096.0 }
                [PSCustomObject]@{ PID = 20; Name = "high-cpu-low-mem"; CPUPercent = 95.0; MemoryMB = 64.0   }
            )
        }

        $processes = Get-ProcessData -DataSource $mockSource
        # Sort by Memory: low-cpu-high-mem should appear first in the report
        $top = Get-TopConsumers -Processes $processes -TopN 1 -SortBy Memory
        $top[0].Name | Should -Be "low-cpu-high-mem"

        # Sort by CPU: high-cpu-low-mem should appear first
        $top = Get-TopConsumers -Processes $processes -TopN 1 -SortBy CPU
        $top[0].Name | Should -Be "high-cpu-low-mem"
    }
}
