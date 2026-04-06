# ProcessMonitor.Tests.ps1
# Pester tests for the ProcessMonitor module.
#
# TDD Methodology:
#   Each Describe block below was conceived as a RED test (written before the
#   implementation). The corresponding function in ProcessMonitor.psm1 was then
#   written as the minimum code to make each test GREEN, followed by refactoring.
#
# Running: Invoke-Pester -Path ./ProcessMonitor.Tests.ps1 -Output Detailed

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    # Import the module under test — forces a fresh load each run
    $modulePath = Join-Path $PSScriptRoot 'ProcessMonitor.psm1'
    Import-Module $modulePath -Force
}

# ============================================================================
# TDD Cycle 1 (RED→GREEN→REFACTOR): New-ProcessInfo
# Creates typed process-data objects with validation.
# ============================================================================
Describe 'New-ProcessInfo' {

    Context 'Happy path' {
        It 'creates a process info object with all required properties' {
            $proc = New-ProcessInfo -PID 1234 -Name 'myapp' -CpuPercent 55.5 -MemoryMB 512.0

            $proc.PID        | Should -Be 1234
            $proc.Name       | Should -Be 'myapp'
            $proc.CpuPercent | Should -Be 55.5
            $proc.MemoryMB   | Should -Be 512.0
        }

        It 'returns a PSCustomObject with the ProcessInfo type name' {
            $proc = New-ProcessInfo -PID 1 -Name 'test' -CpuPercent 0.0 -MemoryMB 0.0
            $proc.PSObject.TypeNames[0] | Should -Be 'ProcessMonitor.ProcessInfo'
        }

        It 'accepts zero values for CPU and memory' {
            $proc = New-ProcessInfo -PID 0 -Name 'idle' -CpuPercent 0.0 -MemoryMB 0.0
            $proc.CpuPercent | Should -Be 0.0
            $proc.MemoryMB   | Should -Be 0.0
        }
    }

    Context 'Validation errors' {
        It 'rejects a negative PID' {
            { New-ProcessInfo -PID -1 -Name 'bad' -CpuPercent 0 -MemoryMB 0 } |
                Should -Throw '*PID must be*'
        }

        It 'rejects an empty name' {
            { New-ProcessInfo -PID 1 -Name '' -CpuPercent 0 -MemoryMB 0 } |
                Should -Throw '*Name must not be*'
        }

        It 'rejects negative CpuPercent' {
            { New-ProcessInfo -PID 1 -Name 'x' -CpuPercent (-5) -MemoryMB 0 } |
                Should -Throw '*CpuPercent must be*'
        }

        It 'rejects negative MemoryMB' {
            { New-ProcessInfo -PID 1 -Name 'x' -CpuPercent 0 -MemoryMB (-10) } |
                Should -Throw '*MemoryMB must be*'
        }
    }
}

# ============================================================================
# TDD Cycle 2 (RED→GREEN→REFACTOR): Get-ProcessInfo
# Retrieves process information. Accepts a -ProcessDataSource scriptblock
# so tests can inject mock data instead of hitting the live system.
# ============================================================================
Describe 'Get-ProcessInfo' {

    # A mock data source returning canned process objects
    BeforeAll {
        [scriptblock]$mockSource = {
            @(
                [PSCustomObject]@{ Id = 100; ProcessName = 'alpha';   CPU = [double]10.0; WorkingSet64 = [long](200MB) }
                [PSCustomObject]@{ Id = 200; ProcessName = 'bravo';   CPU = [double]45.5; WorkingSet64 = [long](800MB) }
                [PSCustomObject]@{ Id = 300; ProcessName = 'charlie'; CPU = [double]90.0; WorkingSet64 = [long](1500MB) }
            )
        }
    }

    It 'returns ProcessInfo objects from the mock data source' {
        $result = Get-ProcessInfo -ProcessDataSource $mockSource
        $result.Count | Should -Be 3
    }

    It 'correctly maps PID, Name, CpuPercent, and MemoryMB' {
        $result = Get-ProcessInfo -ProcessDataSource $mockSource
        $first = $result | Where-Object { $_.PID -eq 100 }
        $first.Name       | Should -Be 'alpha'
        $first.CpuPercent | Should -Be 10.0
        # 200MB ÷ 1MB = 200
        $first.MemoryMB   | Should -BeGreaterOrEqual 199
        $first.MemoryMB   | Should -BeLessOrEqual 201
    }

    It 'produces objects with the ProcessInfo type name' {
        $result = Get-ProcessInfo -ProcessDataSource $mockSource
        $result[0].PSObject.TypeNames[0] | Should -Be 'ProcessMonitor.ProcessInfo'
    }

    It 'handles an empty data source gracefully' {
        [scriptblock]$emptySource = { @() }
        $result = Get-ProcessInfo -ProcessDataSource $emptySource
        $result | Should -BeNullOrEmpty
    }

    It 'handles a data source that throws and returns a meaningful error' {
        [scriptblock]$badSource = { throw 'Simulated failure' }
        { Get-ProcessInfo -ProcessDataSource $badSource } |
            Should -Throw '*Failed to retrieve process data*'
    }
}

# ============================================================================
# TDD Cycle 3 (RED→GREEN→REFACTOR): Select-ByThreshold
# Filters process list by configurable CPU and/or memory thresholds.
# ============================================================================
Describe 'Select-ByThreshold' {

    BeforeAll {
        # Build a reusable set of mock processes
        [array]$script:testProcs = @(
            (New-ProcessInfo -PID 1 -Name 'low'    -CpuPercent 5.0  -MemoryMB 100.0)
            (New-ProcessInfo -PID 2 -Name 'midcpu' -CpuPercent 50.0 -MemoryMB 100.0)
            (New-ProcessInfo -PID 3 -Name 'midmem' -CpuPercent 5.0  -MemoryMB 600.0)
            (New-ProcessInfo -PID 4 -Name 'high'   -CpuPercent 80.0 -MemoryMB 900.0)
        )
    }

    It 'filters by CpuPercent threshold' {
        $result = Select-ByThreshold -Processes $script:testProcs -CpuThreshold 40.0
        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'midcpu'
        $result.Name  | Should -Contain 'high'
    }

    It 'filters by MemoryMB threshold' {
        $result = Select-ByThreshold -Processes $script:testProcs -MemoryThreshold 500.0
        $result.Count | Should -Be 2
        $result.Name  | Should -Contain 'midmem'
        $result.Name  | Should -Contain 'high'
    }

    It 'filters by both thresholds using OR logic (exceeding either triggers inclusion)' {
        $result = Select-ByThreshold -Processes $script:testProcs `
            -CpuThreshold 40.0 -MemoryThreshold 500.0
        $result.Count | Should -Be 3
        $result.Name  | Should -Contain 'midcpu'
        $result.Name  | Should -Contain 'midmem'
        $result.Name  | Should -Contain 'high'
    }

    It 'returns nothing when no process exceeds thresholds' {
        $result = Select-ByThreshold -Processes $script:testProcs `
            -CpuThreshold 99.0 -MemoryThreshold 9999.0
        $result | Should -BeNullOrEmpty
    }

    It 'returns all processes when thresholds are zero' {
        $result = Select-ByThreshold -Processes $script:testProcs `
            -CpuThreshold 0.0 -MemoryThreshold 0.0
        $result.Count | Should -Be 4
    }

    It 'handles an empty process list' {
        $result = Select-ByThreshold -Processes @() -CpuThreshold 10.0
        $result | Should -BeNullOrEmpty
    }

    It 'uses default thresholds when none are specified (no filtering)' {
        # With no thresholds specified, nothing should match (defaults are high)
        $result = Select-ByThreshold -Processes $script:testProcs
        # Default thresholds should be high enough that nothing passes
        # Actually, by design we use [double]::MaxValue so nothing passes
        $result | Should -BeNullOrEmpty
    }
}

# ============================================================================
# TDD Cycle 4 (RED→GREEN→REFACTOR): Get-TopConsumers
# Identifies the top N processes sorted by a chosen metric (CPU or Memory).
# ============================================================================
Describe 'Get-TopConsumers' {

    BeforeAll {
        [array]$script:testProcs = @(
            (New-ProcessInfo -PID 1 -Name 'low'    -CpuPercent 5.0   -MemoryMB 100.0)
            (New-ProcessInfo -PID 2 -Name 'mid'    -CpuPercent 50.0  -MemoryMB 400.0)
            (New-ProcessInfo -PID 3 -Name 'high'   -CpuPercent 80.0  -MemoryMB 900.0)
            (New-ProcessInfo -PID 4 -Name 'ultra'  -CpuPercent 95.0  -MemoryMB 2000.0)
            (New-ProcessInfo -PID 5 -Name 'medium' -CpuPercent 30.0  -MemoryMB 300.0)
        )
    }

    It 'returns top N processes sorted by CPU descending' {
        $result = Get-TopConsumers -Processes $script:testProcs -TopN 3 -SortBy 'CPU'
        $result.Count       | Should -Be 3
        $result[0].Name     | Should -Be 'ultra'
        $result[1].Name     | Should -Be 'high'
        $result[2].Name     | Should -Be 'mid'
    }

    It 'returns top N processes sorted by Memory descending' {
        $result = Get-TopConsumers -Processes $script:testProcs -TopN 2 -SortBy 'Memory'
        $result.Count       | Should -Be 2
        $result[0].Name     | Should -Be 'ultra'
        $result[1].Name     | Should -Be 'high'
    }

    It 'defaults to sorting by CPU when SortBy is not specified' {
        $result = Get-TopConsumers -Processes $script:testProcs -TopN 1
        $result.Name | Should -Be 'ultra'
    }

    It 'returns all processes if TopN exceeds the count' {
        $result = Get-TopConsumers -Processes $script:testProcs -TopN 100 -SortBy 'CPU'
        $result.Count | Should -Be 5
    }

    It 'returns empty for empty input' {
        $result = Get-TopConsumers -Processes @() -TopN 5 -SortBy 'CPU'
        $result | Should -BeNullOrEmpty
    }

    It 'rejects TopN less than 1' {
        { Get-TopConsumers -Processes $script:testProcs -TopN 0 -SortBy 'CPU' } |
            Should -Throw '*TopN must be*'
    }

    It 'rejects invalid SortBy value' {
        { Get-TopConsumers -Processes $script:testProcs -TopN 1 -SortBy 'Disk' } |
            Should -Throw '*SortBy must be*'
    }
}

# ============================================================================
# TDD Cycle 5 (RED→GREEN→REFACTOR): New-AlertReport
# Generates a structured alert report from a list of flagged processes.
# ============================================================================
Describe 'New-AlertReport' {

    BeforeAll {
        [array]$script:alertProcs = @(
            (New-ProcessInfo -PID 1001 -Name 'hog1' -CpuPercent 92.3 -MemoryMB 1500.0)
            (New-ProcessInfo -PID 1002 -Name 'hog2' -CpuPercent 88.0 -MemoryMB 2048.0)
        )
    }

    It 'creates a report object with Timestamp, Thresholds, and Alerts' {
        $report = New-AlertReport -Processes $script:alertProcs `
            -CpuThreshold 80.0 -MemoryThreshold 1000.0

        $report.Timestamp      | Should -Not -BeNullOrEmpty
        $report.Thresholds     | Should -Not -BeNullOrEmpty
        $report.Alerts         | Should -Not -BeNullOrEmpty
    }

    It 'records the thresholds used' {
        $report = New-AlertReport -Processes $script:alertProcs `
            -CpuThreshold 80.0 -MemoryThreshold 1000.0

        $report.Thresholds.CpuPercent | Should -Be 80.0
        $report.Thresholds.MemoryMB   | Should -Be 1000.0
    }

    It 'includes all alerted processes with their details' {
        $report = New-AlertReport -Processes $script:alertProcs `
            -CpuThreshold 80.0 -MemoryThreshold 1000.0

        $report.Alerts.Count | Should -Be 2
        $report.Alerts[0].PID  | Should -Be 1001
        $report.Alerts[1].Name | Should -Be 'hog2'
    }

    It 'includes an AlertCount summary' {
        $report = New-AlertReport -Processes $script:alertProcs `
            -CpuThreshold 80.0 -MemoryThreshold 1000.0

        $report.AlertCount | Should -Be 2
    }

    It 'returns a report with zero alerts when given an empty list' {
        $report = New-AlertReport -Processes @() `
            -CpuThreshold 50.0 -MemoryThreshold 500.0

        $report.AlertCount | Should -Be 0
        $report.Alerts     | Should -BeNullOrEmpty
    }

    It 'produces a valid timestamp in ISO 8601 format' {
        $report = New-AlertReport -Processes $script:alertProcs `
            -CpuThreshold 80.0 -MemoryThreshold 1000.0

        # Parse should succeed for ISO 8601
        { [datetime]::Parse($report.Timestamp) } | Should -Not -Throw
    }

    It 'has the AlertReport type name' {
        $report = New-AlertReport -Processes $script:alertProcs `
            -CpuThreshold 80.0 -MemoryThreshold 1000.0

        $report.PSObject.TypeNames[0] | Should -Be 'ProcessMonitor.AlertReport'
    }
}

# ============================================================================
# TDD Cycle 6 (RED→GREEN→REFACTOR): Format-AlertReport
# Renders an AlertReport as a human-readable string for console/log output.
# ============================================================================
Describe 'Format-AlertReport' {

    BeforeAll {
        [array]$procs = @(
            (New-ProcessInfo -PID 42 -Name 'runaway' -CpuPercent 99.1 -MemoryMB 3000.0)
        )
        $script:report = New-AlertReport -Processes $procs `
            -CpuThreshold 75.0 -MemoryThreshold 2000.0
    }

    It 'returns a non-empty string' {
        $text = Format-AlertReport -Report $script:report
        $text | Should -Not -BeNullOrEmpty
    }

    It 'includes the word ALERT in the output' {
        $text = Format-AlertReport -Report $script:report
        $text | Should -Match 'ALERT'
    }

    It 'mentions the process name' {
        $text = Format-AlertReport -Report $script:report
        $text | Should -Match 'runaway'
    }

    It 'includes threshold information' {
        $text = Format-AlertReport -Report $script:report
        $text | Should -Match '75'
        $text | Should -Match '2000'
    }

    It 'handles a report with no alerts gracefully' {
        $emptyReport = New-AlertReport -Processes @() `
            -CpuThreshold 50.0 -MemoryThreshold 500.0
        $text = Format-AlertReport -Report $emptyReport
        $text | Should -Match 'No alerts'
    }
}

# ============================================================================
# TDD Cycle 7: Integration test — full pipeline with mock data
# ============================================================================
Describe 'Integration: Full pipeline' {

    BeforeAll {
        # Simulate a realistic process list via a mock data source
        [scriptblock]$script:mockSource = {
            @(
                [PSCustomObject]@{ Id = 1;  ProcessName = 'idle';     CPU = [double]0.1;  WorkingSet64 = [long](10MB) }
                [PSCustomObject]@{ Id = 10; ProcessName = 'nginx';    CPU = [double]12.0; WorkingSet64 = [long](150MB) }
                [PSCustomObject]@{ Id = 20; ProcessName = 'postgres'; CPU = [double]35.0; WorkingSet64 = [long](800MB) }
                [PSCustomObject]@{ Id = 30; ProcessName = 'java';     CPU = [double]72.0; WorkingSet64 = [long](2048MB) }
                [PSCustomObject]@{ Id = 40; ProcessName = 'chrome';   CPU = [double]88.0; WorkingSet64 = [long](3000MB) }
                [PSCustomObject]@{ Id = 50; ProcessName = 'vscode';   CPU = [double]25.0; WorkingSet64 = [long](1200MB) }
            )
        }
    }

    It 'end-to-end: fetches, filters, ranks, and generates a report' {
        # Step 1: Fetch process data from mock source
        $allProcs = Get-ProcessInfo -ProcessDataSource $script:mockSource
        $allProcs.Count | Should -Be 6

        # Step 2: Filter by thresholds (CPU > 30% OR Memory > 1000 MB)
        $filtered = Select-ByThreshold -Processes $allProcs `
            -CpuThreshold 30.0 -MemoryThreshold 1000.0
        $filtered.Count | Should -BeGreaterOrEqual 3

        # Step 3: Get top 2 consumers by CPU
        $top = Get-TopConsumers -Processes $filtered -TopN 2 -SortBy 'CPU'
        $top.Count    | Should -Be 2
        $top[0].Name  | Should -Be 'chrome'
        $top[1].Name  | Should -Be 'java'

        # Step 4: Generate alert report
        $report = New-AlertReport -Processes $top `
            -CpuThreshold 30.0 -MemoryThreshold 1000.0
        $report.AlertCount | Should -Be 2

        # Step 5: Format for display
        $text = Format-AlertReport -Report $report
        $text | Should -Match 'chrome'
        $text | Should -Match 'java'
    }

    It 'end-to-end: produces no alerts when all processes are within limits' {
        $allProcs = Get-ProcessInfo -ProcessDataSource $script:mockSource
        $filtered = Select-ByThreshold -Processes $allProcs `
            -CpuThreshold 99.0 -MemoryThreshold 99999.0
        $filtered | Should -BeNullOrEmpty

        # Even with empty, the report should be valid
        $report = New-AlertReport -Processes @() `
            -CpuThreshold 99.0 -MemoryThreshold 99999.0
        $report.AlertCount | Should -Be 0

        $text = Format-AlertReport -Report $report
        $text | Should -Match 'No alerts'
    }
}
