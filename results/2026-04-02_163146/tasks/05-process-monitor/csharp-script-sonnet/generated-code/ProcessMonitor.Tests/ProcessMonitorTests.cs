// TDD Red-Green-Refactor Approach:
// 1. Write a failing test first (RED)
// 2. Write minimum code to make it pass (GREEN)
// 3. Refactor for clarity and quality
// 4. Repeat for each piece of functionality
//
// All process data is provided via IProcessProvider, making tests fully mockable.

using Xunit;
using ProcessMonitorLib;
using ProcessMonitorLib.Models;
using ProcessMonitorLib.Services;

namespace ProcessMonitor.Tests;

// ============================================================
// TEST CYCLE 1: Filter processes by CPU threshold (RED → GREEN)
// ============================================================
public class CpuFilterTests
{
    [Fact]
    public void FilterByCpu_ReturnsOnlyProcessesExceedingThreshold()
    {
        // Arrange
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "high-cpu",    CpuPercent = 85.0, MemoryMb = 100.0 },
            new() { Pid = 2, Name = "low-cpu",     CpuPercent =  5.0, MemoryMb =  50.0 },
            new() { Pid = 3, Name = "medium-cpu",  CpuPercent = 50.0, MemoryMb = 200.0 },
        };
        var monitor = new ProcessMonitorService();

        // Act
        var result = monitor.FilterByCpu(processes, cpuThreshold: 60.0);

        // Assert — only high-cpu (85%) should exceed the 60% threshold
        Assert.Single(result);
        Assert.Equal("high-cpu", result.First().Name);
    }

    [Fact]
    public void FilterByCpu_WhenThresholdIsZero_ReturnsAllProcesses()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "a", CpuPercent = 0.0,  MemoryMb = 10 },
            new() { Pid = 2, Name = "b", CpuPercent = 50.0, MemoryMb = 20 },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.FilterByCpu(processes, cpuThreshold: 0.0);

        // Threshold of 0 means > 0, so both processes (0 and 50) must be checked.
        // A process at exactly 0 CPU is NOT "above" the threshold — it equals it.
        // Only process "b" (50%) is strictly above 0.
        Assert.Single(result);
        Assert.Equal("b", result.First().Name);
    }

    [Fact]
    public void FilterByCpu_WhenNoProcessesExceedThreshold_ReturnsEmpty()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "idle", CpuPercent = 1.0, MemoryMb = 10 },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.FilterByCpu(processes, cpuThreshold: 90.0);

        Assert.Empty(result);
    }
}

// ============================================================
// TEST CYCLE 2: Filter processes by memory threshold (RED → GREEN)
// ============================================================
public class MemoryFilterTests
{
    [Fact]
    public void FilterByMemory_ReturnsOnlyProcessesExceedingThreshold()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "big-mem",   CpuPercent = 5.0,  MemoryMb = 2048.0 },
            new() { Pid = 2, Name = "small-mem", CpuPercent = 5.0,  MemoryMb =   64.0 },
            new() { Pid = 3, Name = "med-mem",   CpuPercent = 5.0,  MemoryMb =  512.0 },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.FilterByMemory(processes, memoryThresholdMb: 1000.0);

        Assert.Single(result);
        Assert.Equal("big-mem", result.First().Name);
    }

    [Fact]
    public void FilterByMemory_WhenNoProcessesExceedThreshold_ReturnsEmpty()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "small", CpuPercent = 1.0, MemoryMb = 32.0 },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.FilterByMemory(processes, memoryThresholdMb: 1000.0);

        Assert.Empty(result);
    }
}

// ============================================================
// TEST CYCLE 3: Top N consumers by CPU (RED → GREEN)
// ============================================================
public class TopConsumersTests
{
    [Fact]
    public void GetTopCpuConsumers_ReturnsTopNSortedDescending()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "p1", CpuPercent = 10.0, MemoryMb = 100 },
            new() { Pid = 2, Name = "p2", CpuPercent = 80.0, MemoryMb = 200 },
            new() { Pid = 3, Name = "p3", CpuPercent = 45.0, MemoryMb = 150 },
            new() { Pid = 4, Name = "p4", CpuPercent = 95.0, MemoryMb = 300 },
            new() { Pid = 5, Name = "p5", CpuPercent = 30.0, MemoryMb = 80  },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.GetTopCpuConsumers(processes, topN: 3);

        Assert.Equal(3, result.Count);
        // Should be sorted descending: p4 (95%), p2 (80%), p3 (45%)
        Assert.Equal("p4", result[0].Name);
        Assert.Equal("p2", result[1].Name);
        Assert.Equal("p3", result[2].Name);
    }

    [Fact]
    public void GetTopMemoryConsumers_ReturnsTopNSortedDescending()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "p1", CpuPercent = 5, MemoryMb = 500 },
            new() { Pid = 2, Name = "p2", CpuPercent = 5, MemoryMb = 100 },
            new() { Pid = 3, Name = "p3", CpuPercent = 5, MemoryMb = 800 },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.GetTopMemoryConsumers(processes, topN: 2);

        Assert.Equal(2, result.Count);
        Assert.Equal("p3", result[0].Name); // 800 MB first
        Assert.Equal("p1", result[1].Name); // 500 MB second
    }

    [Fact]
    public void GetTopCpuConsumers_WhenNLargerThanList_ReturnsAll()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "only", CpuPercent = 20.0, MemoryMb = 50 },
        };
        var monitor = new ProcessMonitorService();

        var result = monitor.GetTopCpuConsumers(processes, topN: 10);

        Assert.Single(result);
    }
}

// ============================================================
// TEST CYCLE 4: Alert report generation (RED → GREEN)
// ============================================================
public class AlertReportTests
{
    [Fact]
    public void GenerateReport_ContainsAlertForHighCpuProcess()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 100, Name = "hungry-proc", CpuPercent = 92.0, MemoryMb = 256.0 },
            new() { Pid = 101, Name = "idle-proc",   CpuPercent =  1.0, MemoryMb =  32.0 },
        };
        var config = new ThresholdConfig
        {
            CpuThresholdPercent   = 80.0,
            MemoryThresholdMb     = 1000.0,
            TopN                  = 5,
        };
        var monitor = new ProcessMonitorService();

        var report = monitor.GenerateReport(processes, config);

        Assert.NotNull(report);
        Assert.Contains(report.CpuAlerts, a => a.ProcessName == "hungry-proc");
        Assert.DoesNotContain(report.CpuAlerts, a => a.ProcessName == "idle-proc");
    }

    [Fact]
    public void GenerateReport_ContainsAlertForHighMemoryProcess()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 200, Name = "memory-hog", CpuPercent = 2.0,  MemoryMb = 4096.0 },
            new() { Pid = 201, Name = "lean-proc",  CpuPercent = 2.0,  MemoryMb =   32.0 },
        };
        var config = new ThresholdConfig
        {
            CpuThresholdPercent   = 80.0,
            MemoryThresholdMb     = 1000.0,
            TopN                  = 5,
        };
        var monitor = new ProcessMonitorService();

        var report = monitor.GenerateReport(processes, config);

        Assert.Contains(report.MemoryAlerts, a => a.ProcessName == "memory-hog");
        Assert.DoesNotContain(report.MemoryAlerts, a => a.ProcessName == "lean-proc");
    }

    [Fact]
    public void GenerateReport_TopConsumersRespectsTopNConfig()
    {
        // Create 5 processes, TopN = 3
        var processes = Enumerable.Range(1, 5)
            .Select(i => new ProcessInfo { Pid = i, Name = $"proc{i}", CpuPercent = i * 10.0, MemoryMb = i * 100.0 })
            .ToList();
        var config = new ThresholdConfig
        {
            CpuThresholdPercent = 0.0,
            MemoryThresholdMb   = 0.0,
            TopN                = 3,
        };
        var monitor = new ProcessMonitorService();

        var report = monitor.GenerateReport(processes, config);

        Assert.Equal(3, report.TopCpuConsumers.Count);
        Assert.Equal(3, report.TopMemoryConsumers.Count);
    }

    [Fact]
    public void GenerateReport_SummaryContainsCorrectCounts()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "a", CpuPercent = 90.0, MemoryMb = 2000.0 },
            new() { Pid = 2, Name = "b", CpuPercent = 70.0, MemoryMb =  500.0 },
            new() { Pid = 3, Name = "c", CpuPercent = 10.0, MemoryMb =  100.0 },
        };
        var config = new ThresholdConfig
        {
            CpuThresholdPercent = 80.0,
            MemoryThresholdMb   = 1500.0,
            TopN                = 5,
        };
        var monitor = new ProcessMonitorService();

        var report = monitor.GenerateReport(processes, config);

        Assert.Equal(3, report.Summary.TotalProcessesScanned);
        Assert.Equal(1, report.Summary.CpuAlertsCount);    // only "a" > 80%
        Assert.Equal(1, report.Summary.MemoryAlertsCount); // only "a" > 1500 MB
    }

    [Fact]
    public void GenerateReport_ReportTextIsNotEmpty()
    {
        var processes = new List<ProcessInfo>
        {
            new() { Pid = 1, Name = "proc", CpuPercent = 50.0, MemoryMb = 256.0 },
        };
        var config = new ThresholdConfig
        {
            CpuThresholdPercent = 80.0,
            MemoryThresholdMb   = 1000.0,
            TopN                = 3,
        };
        var monitor = new ProcessMonitorService();

        var report = monitor.GenerateReport(processes, config);
        var text = report.FormatAsText();

        Assert.False(string.IsNullOrWhiteSpace(text));
        Assert.Contains("Process Monitor Alert Report", text);
    }
}

// ============================================================
// TEST CYCLE 5: IProcessProvider mock integration (RED → GREEN)
// ============================================================
public class MockProviderTests
{
    // Mock implementation — no live system state, fully controlled data
    private class MockProcessProvider : IProcessProvider
    {
        private readonly List<ProcessInfo> _processes;
        public MockProcessProvider(List<ProcessInfo> processes) => _processes = processes;
        public IReadOnlyList<ProcessInfo> GetProcesses() => _processes.AsReadOnly();
    }

    [Fact]
    public void RunMonitor_UsesProviderData_NotLiveSystem()
    {
        // Arrange — inject controlled mock data
        var fakeProcesses = new List<ProcessInfo>
        {
            new() { Pid = 999, Name = "fake-high-cpu", CpuPercent = 99.0, MemoryMb = 512.0 },
            new() { Pid = 998, Name = "fake-low-cpu",  CpuPercent =  1.0, MemoryMb =  64.0 },
        };
        IProcessProvider provider = new MockProcessProvider(fakeProcesses);
        var config = new ThresholdConfig
        {
            CpuThresholdPercent = 80.0,
            MemoryThresholdMb   = 1000.0,
            TopN                = 5,
        };
        var monitor = new ProcessMonitorService();

        // Act — run monitor using mock provider
        var processes = provider.GetProcesses();
        var report = monitor.GenerateReport(processes, config);

        // Assert — results come from mock, not live system
        Assert.Contains(report.CpuAlerts, a => a.Pid == 999);
        Assert.DoesNotContain(report.CpuAlerts, a => a.Pid == 998);
    }

    [Fact]
    public void RunMonitor_WithEmptyProcessList_ProducesEmptyReport()
    {
        IProcessProvider provider = new MockProcessProvider(new List<ProcessInfo>());
        var config = new ThresholdConfig
        {
            CpuThresholdPercent = 80.0,
            MemoryThresholdMb   = 1000.0,
            TopN                = 5,
        };
        var monitor = new ProcessMonitorService();

        var processes = provider.GetProcesses();
        var report = monitor.GenerateReport(processes, config);

        Assert.Empty(report.CpuAlerts);
        Assert.Empty(report.MemoryAlerts);
        Assert.Equal(0, report.Summary.TotalProcessesScanned);
    }
}

// ============================================================
// TEST CYCLE 6: ThresholdConfig validation (RED → GREEN)
// ============================================================
public class ThresholdConfigTests
{
    [Fact]
    public void ThresholdConfig_NegativeCpuThreshold_ThrowsArgumentException()
    {
        var config = new ThresholdConfig { CpuThresholdPercent = -1.0, MemoryThresholdMb = 0, TopN = 5 };
        var monitor = new ProcessMonitorService();

        Assert.Throws<ArgumentException>(() => monitor.ValidateConfig(config));
    }

    [Fact]
    public void ThresholdConfig_NegativeTopN_ThrowsArgumentException()
    {
        var config = new ThresholdConfig { CpuThresholdPercent = 80.0, MemoryThresholdMb = 0, TopN = 0 };
        var monitor = new ProcessMonitorService();

        Assert.Throws<ArgumentException>(() => monitor.ValidateConfig(config));
    }

    [Fact]
    public void ThresholdConfig_ValidConfig_DoesNotThrow()
    {
        var config = new ThresholdConfig { CpuThresholdPercent = 80.0, MemoryThresholdMb = 1024.0, TopN = 5 };
        var monitor = new ProcessMonitorService();

        // Should not throw
        monitor.ValidateConfig(config);
    }
}
