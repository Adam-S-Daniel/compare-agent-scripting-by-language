// TDD Cycle 1 - RED: Tests for ProcessInfo model and threshold-based filtering.
// These tests define the contract for how processes are filtered by CPU and memory thresholds.

using Xunit;

public class ProcessFilterTests
{
    // Helper to create mock process data for testing
    private static List<ProcessInfo> CreateMockProcesses() =>
    [
        new ProcessInfo(Pid: 100, Name: "chrome",    CpuPercent: 45.0, MemoryMb: 1200.0),
        new ProcessInfo(Pid: 200, Name: "firefox",   CpuPercent: 12.5, MemoryMb: 800.0),
        new ProcessInfo(Pid: 300, Name: "vscode",    CpuPercent: 8.0,  MemoryMb: 950.0),
        new ProcessInfo(Pid: 400, Name: "idle",      CpuPercent: 0.1,  MemoryMb: 5.0),
        new ProcessInfo(Pid: 500, Name: "dbserver",  CpuPercent: 75.0, MemoryMb: 3200.0),
        new ProcessInfo(Pid: 600, Name: "webserver", CpuPercent: 30.0, MemoryMb: 512.0),
    ];

    [Fact]
    public void ProcessInfo_Record_StoresAllFields()
    {
        var proc = new ProcessInfo(Pid: 42, Name: "test", CpuPercent: 55.5, MemoryMb: 1024.0);

        Assert.Equal(42, proc.Pid);
        Assert.Equal("test", proc.Name);
        Assert.Equal(55.5, proc.CpuPercent);
        Assert.Equal(1024.0, proc.MemoryMb);
    }

    [Fact]
    public void FilterByCpu_ReturnsOnlyProcessesAboveThreshold()
    {
        var processes = CreateMockProcesses();
        var config = new ThresholdConfig(CpuThreshold: 20.0, MemoryThresholdMb: 0);

        var result = ProcessFilter.Apply(processes, config);

        // Only chrome (45%), dbserver (75%), webserver (30%) exceed 20% CPU
        Assert.Equal(3, result.Count);
        Assert.All(result, p => Assert.True(p.CpuPercent >= 20.0));
    }

    [Fact]
    public void FilterByMemory_ReturnsOnlyProcessesAboveThreshold()
    {
        var processes = CreateMockProcesses();
        var config = new ThresholdConfig(CpuThreshold: 0, MemoryThresholdMb: 900.0);

        var result = ProcessFilter.Apply(processes, config);

        // Only chrome (1200), vscode (950), dbserver (3200) exceed 900 MB
        Assert.Equal(3, result.Count);
        Assert.All(result, p => Assert.True(p.MemoryMb >= 900.0));
    }

    [Fact]
    public void FilterByCpuAndMemory_ReturnsBothCriteriaMet()
    {
        var processes = CreateMockProcesses();
        // Process must exceed EITHER threshold (union) to appear in filtered results
        var config = new ThresholdConfig(CpuThreshold: 30.0, MemoryThresholdMb: 1000.0);

        var result = ProcessFilter.Apply(processes, config);

        // chrome: CPU 45% >= 30 OR mem 1200 >= 1000 -> YES
        // firefox: CPU 12.5 < 30 AND mem 800 < 1000 -> NO
        // vscode: CPU 8 < 30 AND mem 950 < 1000 -> NO
        // idle: NO
        // dbserver: CPU 75 >= 30 OR mem 3200 >= 1000 -> YES
        // webserver: CPU 30 >= 30 OR mem 512 < 1000 -> YES
        Assert.Equal(3, result.Count);
        Assert.Contains(result, p => p.Name == "chrome");
        Assert.Contains(result, p => p.Name == "dbserver");
        Assert.Contains(result, p => p.Name == "webserver");
    }

    [Fact]
    public void Filter_WithZeroThresholds_ReturnsAllProcesses()
    {
        var processes = CreateMockProcesses();
        var config = new ThresholdConfig(CpuThreshold: 0, MemoryThresholdMb: 0);

        var result = ProcessFilter.Apply(processes, config);

        Assert.Equal(processes.Count, result.Count);
    }

    [Fact]
    public void Filter_WithVeryHighThresholds_ReturnsEmpty()
    {
        var processes = CreateMockProcesses();
        var config = new ThresholdConfig(CpuThreshold: 99.0, MemoryThresholdMb: 99999.0);

        var result = ProcessFilter.Apply(processes, config);

        Assert.Empty(result);
    }

    [Fact]
    public void Filter_EmptyInput_ReturnsEmpty()
    {
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 100.0);

        var result = ProcessFilter.Apply([], config);

        Assert.Empty(result);
    }
}
