// TDD Cycle 5 - Tests for error handling and edge cases.
// Validates graceful handling of invalid inputs and negative values.

using Xunit;

public class ErrorHandlingTests
{
    [Fact]
    public void ThresholdConfig_NegativeValues_AreTreatedAsZero()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 1, Name: "proc", CpuPercent: 5.0, MemoryMb: 100.0),
        };
        // Negative thresholds should behave like 0 (include everything)
        var config = new ThresholdConfig(CpuThreshold: -10.0, MemoryThresholdMb: -500.0);

        var result = ProcessFilter.Apply(processes, config);

        Assert.Single(result);
    }

    [Fact]
    public void TopConsumers_ZeroN_ReturnsEmpty()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 1, Name: "proc", CpuPercent: 50.0, MemoryMb: 1000.0),
        };

        var result = TopConsumers.ByCpu(processes, 0);

        Assert.Empty(result);
    }

    [Fact]
    public void TopConsumers_NegativeN_ReturnsEmpty()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 1, Name: "proc", CpuPercent: 50.0, MemoryMb: 1000.0),
        };

        var result = TopConsumers.ByCpu(processes, -1);

        Assert.Empty(result);
    }

    [Fact]
    public void ProcessInfo_WithZeroValues_IsValid()
    {
        var proc = new ProcessInfo(Pid: 0, Name: "idle", CpuPercent: 0.0, MemoryMb: 0.0);

        Assert.Equal(0, proc.Pid);
        Assert.Equal(0.0, proc.CpuPercent);
        Assert.Equal(0.0, proc.MemoryMb);
    }

    [Fact]
    public void ProcessFilter_NullProcessName_DoesNotThrow()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 1, Name: null!, CpuPercent: 50.0, MemoryMb: 1000.0),
        };
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 100.0);

        // Should not throw — null name is unusual but shouldn't crash filtering
        var result = ProcessFilter.Apply(processes, config);

        Assert.Single(result);
    }

    [Fact]
    public void AlertReport_ProcessWithNullName_HandlesGracefully()
    {
        var processes = new List<ProcessInfo>
        {
            new(Pid: 999, Name: null!, CpuPercent: 50.0, MemoryMb: 1000.0),
        };
        var config = new ThresholdConfig(CpuThreshold: 10.0, MemoryThresholdMb: 100.0);

        // Should not throw
        var report = AlertReport.Generate(processes, config);

        Assert.Contains("999", report); // PID should still appear
    }

    [Fact]
    public void ParseArgs_ValidArguments_ReturnsCorrectConfig()
    {
        var args = new[] { "--cpu", "50", "--memory", "1024", "--top", "5" };

        var (config, topN) = ArgParser.Parse(args);

        Assert.Equal(50.0, config.CpuThreshold);
        Assert.Equal(1024.0, config.MemoryThresholdMb);
        Assert.Equal(5, topN);
    }

    [Fact]
    public void ParseArgs_DefaultValues_WhenNoArgsProvided()
    {
        var args = Array.Empty<string>();

        var (config, topN) = ArgParser.Parse(args);

        // Defaults: cpu=10%, memory=500MB, top=5
        Assert.Equal(10.0, config.CpuThreshold);
        Assert.Equal(500.0, config.MemoryThresholdMb);
        Assert.Equal(5, topN);
    }

    [Fact]
    public void ParseArgs_PartialArgs_UsesDefaults()
    {
        var args = new[] { "--cpu", "80" };

        var (config, topN) = ArgParser.Parse(args);

        Assert.Equal(80.0, config.CpuThreshold);
        Assert.Equal(500.0, config.MemoryThresholdMb);  // default
        Assert.Equal(5, topN);                            // default
    }

    [Fact]
    public void ParseArgs_InvalidNumber_ThrowsMeaningfulError()
    {
        var args = new[] { "--cpu", "notanumber" };

        var ex = Assert.Throws<ArgumentException>(() => ArgParser.Parse(args));
        Assert.Contains("cpu", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ParseArgs_UnknownFlag_ThrowsMeaningfulError()
    {
        var args = new[] { "--unknown", "42" };

        var ex = Assert.Throws<ArgumentException>(() => ArgParser.Parse(args));
        Assert.Contains("unknown", ex.Message, StringComparison.OrdinalIgnoreCase);
    }
}
