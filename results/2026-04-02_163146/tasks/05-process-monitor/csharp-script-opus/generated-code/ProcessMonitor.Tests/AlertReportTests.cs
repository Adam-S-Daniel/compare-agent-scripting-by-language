// TDD Cycle 3 - Tests for alert report generation.
// The report should include a header, summary stats, and per-process details.

using Xunit;

public class AlertReportTests
{
    [Fact]
    public void GenerateReport_ContainsHeader()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 100, Name: "chrome", CpuPercent: 50.0, MemoryMb: 1024.0)
        };
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 500.0);

        var report = AlertReport.Generate(processes, config);

        Assert.Contains("PROCESS MONITOR ALERT REPORT", report);
    }

    [Fact]
    public void GenerateReport_ContainsThresholdInfo()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 100, Name: "chrome", CpuPercent: 50.0, MemoryMb: 1024.0)
        };
        var config = new ThresholdConfig(CpuThreshold: 25.0, MemoryThresholdMb: 512.0);

        var report = AlertReport.Generate(processes, config);

        Assert.Contains("25", report);   // CPU threshold shown
        Assert.Contains("512", report);   // Memory threshold shown
    }

    [Fact]
    public void GenerateReport_ListsAllAlertedProcesses()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 100, Name: "chrome",   CpuPercent: 50.0, MemoryMb: 1024.0),
            new(Pid: 500, Name: "dbserver", CpuPercent: 80.0, MemoryMb: 3200.0),
        };
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 500.0);

        var report = AlertReport.Generate(processes, config);

        Assert.Contains("chrome", report);
        Assert.Contains("100", report);   // PID
        Assert.Contains("dbserver", report);
        Assert.Contains("500", report);   // PID
    }

    [Fact]
    public void GenerateReport_ShowsCpuAndMemoryValues()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 42, Name: "testproc", CpuPercent: 65.3, MemoryMb: 2048.5),
        };
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 100.0);

        var report = AlertReport.Generate(processes, config);

        Assert.Contains("65.3", report);
        Assert.Contains("2048.5", report);
    }

    [Fact]
    public void GenerateReport_ShowsAlertedProcessCount()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 1, Name: "a", CpuPercent: 10.0, MemoryMb: 100.0),
            new(Pid: 2, Name: "b", CpuPercent: 20.0, MemoryMb: 200.0),
            new(Pid: 3, Name: "c", CpuPercent: 30.0, MemoryMb: 300.0),
        };
        var config = new ThresholdConfig(CpuThreshold: 5.0, MemoryThresholdMb: 50.0);

        var report = AlertReport.Generate(processes, config);

        Assert.Contains("3", report); // count of alerted processes
    }

    [Fact]
    public void GenerateReport_EmptyProcessList_ShowsNoAlertsMessage()
    {
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 100.0);

        var report = AlertReport.Generate([], config);

        Assert.Contains("No processes exceeded", report);
    }
}
