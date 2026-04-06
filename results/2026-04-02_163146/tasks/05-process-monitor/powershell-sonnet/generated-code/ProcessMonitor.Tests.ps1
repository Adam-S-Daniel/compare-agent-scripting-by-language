# ProcessMonitor.Tests.ps1
# TDD test suite for the Process Monitor script.
# Tests are written BEFORE implementation (red), then implementation is added (green).
# All tests use mock data — no live system process data is accessed.

# Ensure Pester 5+ is available
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    # Import the module under test
    . "$PSScriptRoot/ProcessMonitor.ps1"
}

# =============================================================================
# RED PHASE 1: Test that Get-MockProcessData returns structured process objects
# =============================================================================
Describe "Get-MockProcessData" {
    It "returns a list of process objects with required fields" {
        $processes = Get-MockProcessData

        $processes | Should -Not -BeNullOrEmpty
        $processes.Count | Should -BeGreaterThan 0

        $first = $processes[0]
        $first.PSObject.Properties.Name | Should -Contain 'PID'
        $first.PSObject.Properties.Name | Should -Contain 'Name'
        $first.PSObject.Properties.Name | Should -Contain 'CPU'
        $first.PSObject.Properties.Name | Should -Contain 'MemoryMB'
    }

    It "returns process objects with numeric CPU and MemoryMB values" {
        $processes = Get-MockProcessData

        foreach ($p in $processes) {
            $p.CPU    | Should -BeOfType [double]
            $p.MemoryMB | Should -BeOfType [double]
            $p.PID    | Should -BeOfType [int]
        }
    }
}

# =============================================================================
# RED PHASE 2: Test filtering by CPU and memory thresholds
# =============================================================================
Describe "Get-FilteredProcesses" {
    BeforeEach {
        # Define fixed mock data for deterministic tests
        $script:MockProcesses = @(
            [PSCustomObject]@{ PID = 1; Name = 'idle';    CPU = 0.5;  MemoryMB = 10.0  }
            [PSCustomObject]@{ PID = 2; Name = 'worker';  CPU = 75.0; MemoryMB = 512.0 }
            [PSCustomObject]@{ PID = 3; Name = 'hungry';  CPU = 90.0; MemoryMB = 2048.0 }
            [PSCustomObject]@{ PID = 4; Name = 'memhog';  CPU = 5.0;  MemoryMB = 1500.0 }
        )
    }

    It "returns only processes exceeding CPU threshold" {
        $result = Get-FilteredProcesses -Processes $script:MockProcesses -CpuThreshold 50.0 -MemoryThresholdMB 0.0

        $result.Count | Should -Be 2
        $result.Name | Should -Contain 'worker'
        $result.Name | Should -Contain 'hungry'
        $result.Name | Should -Not -Contain 'idle'
    }

    It "returns only processes exceeding memory threshold" {
        $result = Get-FilteredProcesses -Processes $script:MockProcesses -CpuThreshold 0.0 -MemoryThresholdMB 1000.0

        $result.Count | Should -Be 2
        $result.Name | Should -Contain 'hungry'
        $result.Name | Should -Contain 'memhog'
    }

    It "returns processes exceeding either threshold (OR logic)" {
        $result = Get-FilteredProcesses -Processes $script:MockProcesses -CpuThreshold 70.0 -MemoryThresholdMB 1000.0

        # worker: CPU 75 > 70, hungry: CPU 90 > 70 AND mem > 1000, memhog: mem > 1000
        $result.Count | Should -Be 3
        $result.Name | Should -Contain 'worker'
        $result.Name | Should -Contain 'hungry'
        $result.Name | Should -Contain 'memhog'
    }

    It "returns empty when no processes exceed thresholds" {
        $result = Get-FilteredProcesses -Processes $script:MockProcesses -CpuThreshold 99.0 -MemoryThresholdMB 9999.0

        $result | Should -BeNullOrEmpty
    }
}

# =============================================================================
# RED PHASE 3: Test Get-TopResourceConsumers
# =============================================================================
Describe "Get-TopResourceConsumers" {
    BeforeEach {
        $script:MockProcesses = @(
            [PSCustomObject]@{ PID = 1; Name = 'a'; CPU = 10.0; MemoryMB = 100.0 }
            [PSCustomObject]@{ PID = 2; Name = 'b'; CPU = 80.0; MemoryMB = 200.0 }
            [PSCustomObject]@{ PID = 3; Name = 'c'; CPU = 50.0; MemoryMB = 800.0 }
            [PSCustomObject]@{ PID = 4; Name = 'd'; CPU = 95.0; MemoryMB = 500.0 }
            [PSCustomObject]@{ PID = 5; Name = 'e'; CPU = 30.0; MemoryMB = 300.0 }
        )
    }

    It "returns top N processes by CPU" {
        $result = Get-TopResourceConsumers -Processes $script:MockProcesses -TopN 2 -SortBy 'CPU'

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'd'   # 95% CPU
        $result[1].Name | Should -Be 'b'   # 80% CPU
    }

    It "returns top N processes by MemoryMB" {
        $result = Get-TopResourceConsumers -Processes $script:MockProcesses -TopN 3 -SortBy 'MemoryMB'

        $result.Count | Should -Be 3
        $result[0].Name | Should -Be 'c'   # 800 MB
        $result[1].Name | Should -Be 'd'   # 500 MB
        $result[2].Name | Should -Be 'e'   # 300 MB
    }

    It "returns all processes when TopN exceeds count" {
        $result = Get-TopResourceConsumers -Processes $script:MockProcesses -TopN 100 -SortBy 'CPU'

        $result.Count | Should -Be 5
    }

    It "throws a meaningful error for invalid SortBy value" {
        { Get-TopResourceConsumers -Processes $script:MockProcesses -TopN 2 -SortBy 'InvalidField' } |
            Should -Throw "*Invalid SortBy*"
    }
}

# =============================================================================
# RED PHASE 4: Test New-AlertReport
# =============================================================================
Describe "New-AlertReport" {
    BeforeEach {
        $script:AlertProcesses = @(
            [PSCustomObject]@{ PID = 42;  Name = 'badproc';  CPU = 95.0; MemoryMB = 2048.0 }
            [PSCustomObject]@{ PID = 100; Name = 'memheavy'; CPU = 20.0; MemoryMB = 3000.0 }
        )
        $script:Thresholds = @{ CpuThreshold = 80.0; MemoryThresholdMB = 1000.0 }
    }

    It "returns a non-empty report string" {
        $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:Thresholds

        $report | Should -Not -BeNullOrEmpty
        $report | Should -BeOfType [string]
    }

    It "includes process names in the report" {
        $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:Thresholds

        $report | Should -Match 'badproc'
        $report | Should -Match 'memheavy'
    }

    It "includes PID values in the report" {
        $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:Thresholds

        $report | Should -Match '42'
        $report | Should -Match '100'
    }

    It "includes threshold information in the report" {
        $report = New-AlertReport -Processes $script:AlertProcesses -Thresholds $script:Thresholds

        $report | Should -Match '80'     # CPU threshold
        $report | Should -Match '1000'   # Memory threshold
    }

    It "returns a message indicating no alerts when processes list is empty" {
        $report = New-AlertReport -Processes @() -Thresholds $script:Thresholds

        $report | Should -Match 'No alerts'
    }
}

# =============================================================================
# RED PHASE 5: Integration test — full pipeline with mock data
# =============================================================================
Describe "Invoke-ProcessMonitor (integration)" {
    It "runs the full pipeline and returns a report string" {
        # Use custom mock data injected via -ProcessData parameter
        $mockData = @(
            [PSCustomObject]@{ PID = 1;  Name = 'normal';  CPU = 5.0;   MemoryMB = 100.0  }
            [PSCustomObject]@{ PID = 2;  Name = 'cpuhog';  CPU = 91.0;  MemoryMB = 200.0  }
            [PSCustomObject]@{ PID = 3;  Name = 'ramhog';  CPU = 3.0;   MemoryMB = 1500.0 }
        )

        $params = @{
            ProcessData         = $mockData
            CpuThreshold        = 80.0
            MemoryThresholdMB   = 1000.0
            TopN                = 5
            SortBy              = 'CPU'
        }

        $report = Invoke-ProcessMonitor @params

        $report | Should -Not -BeNullOrEmpty
        $report | Should -Match 'cpuhog'
        $report | Should -Match 'ramhog'
        $report | Should -Not -Match 'normal'
    }

    It "uses live-like mock data when no ProcessData is supplied" {
        # Proves the function has a default data source (Get-MockProcessData)
        $report = Invoke-ProcessMonitor -CpuThreshold 0.0 -MemoryThresholdMB 0.0 -TopN 3 -SortBy 'CPU'

        $report | Should -Not -BeNullOrEmpty
    }
}
