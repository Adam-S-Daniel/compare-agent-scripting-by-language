// TDD Cycle 2 - Tests for identifying top N resource consumers.
// Validates sorting by CPU, memory, or combined score, and limiting to top N.

using Xunit;

public class TopConsumerTests
{
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
    public void TopByCpu_ReturnsTopNSortedDescending()
    {
        var processes = CreateMockProcesses();

        var top3 = TopConsumers.ByCpu(processes, 3);

        Assert.Equal(3, top3.Count);
        Assert.Equal("dbserver", top3[0].Name);   // 75%
        Assert.Equal("chrome", top3[1].Name);      // 45%
        Assert.Equal("webserver", top3[2].Name);   // 30%
    }

    [Fact]
    public void TopByMemory_ReturnsTopNSortedDescending()
    {
        var processes = CreateMockProcesses();

        var top2 = TopConsumers.ByMemory(processes, 2);

        Assert.Equal(2, top2.Count);
        Assert.Equal("dbserver", top2[0].Name);    // 3200 MB
        Assert.Equal("chrome", top2[1].Name);       // 1200 MB
    }

    [Fact]
    public void TopByCpu_WhenNExceedsList_ReturnsAll()
    {
        var processes = CreateMockProcesses();

        var result = TopConsumers.ByCpu(processes, 100);

        Assert.Equal(6, result.Count);
        // Still sorted descending
        Assert.Equal("dbserver", result[0].Name);
    }

    [Fact]
    public void TopByMemory_WithEmptyList_ReturnsEmpty()
    {
        var result = TopConsumers.ByMemory([], 5);

        Assert.Empty(result);
    }

    [Fact]
    public void TopByCpu_TopOne_ReturnsSingleHighest()
    {
        var processes = CreateMockProcesses();

        var top1 = TopConsumers.ByCpu(processes, 1);

        Assert.Single(top1);
        Assert.Equal("dbserver", top1[0].Name);
    }
}
