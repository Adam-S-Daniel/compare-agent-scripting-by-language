// TDD Cycle 4 - Tests for the IProcessProvider interface and mock implementation.
// Also tests the full pipeline: provider -> filter -> top N -> report.

using Xunit;

public class ProcessProviderTests
{
    [Fact]
    public void MockProvider_ReturnsConfiguredProcesses()
    {
        var expected = new List<ProcessInfo>
        {
            new(Pid: 1, Name: "proc1", CpuPercent: 10.0, MemoryMb: 100.0),
            new(Pid: 2, Name: "proc2", CpuPercent: 20.0, MemoryMb: 200.0),
        };
        var provider = new MockProcessProvider(expected);

        var result = provider.GetProcesses();

        Assert.Equal(2, result.Count);
        Assert.Equal(expected, result);
    }

    [Fact]
    public void MockProvider_EmptyList_ReturnsEmpty()
    {
        var provider = new MockProcessProvider([]);

        var result = provider.GetProcesses();

        Assert.Empty(result);
    }
}

/// <summary>
/// Tests for the full monitoring pipeline, using mocks for all process data.
/// </summary>
public class MonitorPipelineTests
{
    [Fact]
    public void FullPipeline_FiltersThenRanksAndGeneratesReport()
    {
        // Arrange: mock process data
        var provider = new MockProcessProvider(
        [
            new ProcessInfo(Pid: 1, Name: "low_cpu",    CpuPercent: 2.0,  MemoryMb: 50.0),
            new ProcessInfo(Pid: 2, Name: "med_cpu",    CpuPercent: 25.0, MemoryMb: 300.0),
            new ProcessInfo(Pid: 3, Name: "high_cpu",   CpuPercent: 90.0, MemoryMb: 4000.0),
            new ProcessInfo(Pid: 4, Name: "high_mem",   CpuPercent: 5.0,  MemoryMb: 8000.0),
            new ProcessInfo(Pid: 5, Name: "med_both",   CpuPercent: 40.0, MemoryMb: 2000.0),
        ]);
        var config = new ThresholdConfig(CpuThreshold: 20.0, MemoryThresholdMb: 1000.0);

        // Act: run the full pipeline
        var allProcesses = provider.GetProcesses();
        var filtered = ProcessFilter.Apply(allProcesses, config);
        var topByCpu = TopConsumers.ByCpu(filtered, 2);
        var report = AlertReport.Generate(filtered, config);

        // Assert
        // Filtered should include med_cpu (25%), high_cpu (90%), high_mem (8000MB), med_both (40%/2000MB)
        Assert.Equal(4, filtered.Count);
        Assert.DoesNotContain(filtered, p => p.Name == "low_cpu");

        // Top 2 by CPU from filtered: high_cpu (90%), med_both (40%)
        Assert.Equal(2, topByCpu.Count);
        Assert.Equal("high_cpu", topByCpu[0].Name);
        Assert.Equal("med_both", topByCpu[1].Name);

        // Report should mention the alerted processes
        Assert.Contains("PROCESS MONITOR ALERT REPORT", report);
        Assert.Contains("high_cpu", report);
        Assert.Contains("high_mem", report);
    }

    [Fact]
    public void FullPipeline_NoProcessesExceedThresholds_ReportsClean()
    {
        var provider = new MockProcessProvider(
        [
            new ProcessInfo(Pid: 1, Name: "idle1", CpuPercent: 0.5, MemoryMb: 10.0),
            new ProcessInfo(Pid: 2, Name: "idle2", CpuPercent: 1.0, MemoryMb: 20.0),
        ]);
        var config = new ThresholdConfig(CpuThreshold: 50.0, MemoryThresholdMb: 5000.0);

        var filtered = ProcessFilter.Apply(provider.GetProcesses(), config);
        var report = AlertReport.Generate(filtered, config);

        Assert.Empty(filtered);
        Assert.Contains("No processes exceeded", report);
    }
}
