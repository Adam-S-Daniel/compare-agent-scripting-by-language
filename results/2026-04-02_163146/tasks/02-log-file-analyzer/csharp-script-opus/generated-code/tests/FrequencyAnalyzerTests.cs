// TDD Cycle 4: Tests for frequency table generation from error/warning entries.

using Xunit;
using LogAnalyzer;

namespace LogAnalyzer.Tests;

public class FrequencyAnalyzerTests
{
    [Fact]
    public void Analyze_MultipleEntriesSameType_GroupsCorrectly()
    {
        var entries = new List<LogEntry>
        {
            new() { ErrorType = "ConnectionTimeout", Level = LogLevel.Error,
                     Timestamp = new DateTime(2024, 1, 15, 8, 0, 0, DateTimeKind.Utc) },
            new() { ErrorType = "ConnectionTimeout", Level = LogLevel.Error,
                     Timestamp = new DateTime(2024, 1, 15, 9, 0, 0, DateTimeKind.Utc) },
            new() { ErrorType = "ConnectionTimeout", Level = LogLevel.Error,
                     Timestamp = new DateTime(2024, 1, 15, 10, 0, 0, DateTimeKind.Utc) },
        };

        var result = FrequencyAnalyzer.Analyze(entries);

        Assert.Single(result);
        Assert.Equal("ConnectionTimeout", result[0].ErrorType);
        Assert.Equal(3, result[0].Count);
        Assert.Equal(new DateTime(2024, 1, 15, 8, 0, 0, DateTimeKind.Utc), result[0].FirstOccurrence);
        Assert.Equal(new DateTime(2024, 1, 15, 10, 0, 0, DateTimeKind.Utc), result[0].LastOccurrence);
    }

    [Fact]
    public void Analyze_DifferentTypes_CreatesSeparateRows()
    {
        var entries = new List<LogEntry>
        {
            new() { ErrorType = "TypeA", Level = LogLevel.Error,
                     Timestamp = new DateTime(2024, 1, 15, 8, 0, 0, DateTimeKind.Utc) },
            new() { ErrorType = "TypeB", Level = LogLevel.Warning,
                     Timestamp = new DateTime(2024, 1, 15, 9, 0, 0, DateTimeKind.Utc) },
            new() { ErrorType = "TypeA", Level = LogLevel.Error,
                     Timestamp = new DateTime(2024, 1, 15, 10, 0, 0, DateTimeKind.Utc) },
        };

        var result = FrequencyAnalyzer.Analyze(entries);

        Assert.Equal(2, result.Count);
        // TypeA has count 2, so it should come first (sorted by count desc)
        Assert.Equal("TypeA", result[0].ErrorType);
        Assert.Equal(2, result[0].Count);
        Assert.Equal("TypeB", result[1].ErrorType);
        Assert.Equal(1, result[1].Count);
    }

    [Fact]
    public void Analyze_SingleEntry_ReturnsSingleRow()
    {
        var ts = new DateTime(2024, 1, 15, 8, 30, 0, DateTimeKind.Utc);
        var entries = new List<LogEntry>
        {
            new() { ErrorType = "OnlyOne", Level = LogLevel.Error, Timestamp = ts },
        };

        var result = FrequencyAnalyzer.Analyze(entries);

        Assert.Single(result);
        Assert.Equal(1, result[0].Count);
        Assert.Equal(ts, result[0].FirstOccurrence);
        Assert.Equal(ts, result[0].LastOccurrence);
    }

    [Fact]
    public void Analyze_EmptyList_ReturnsEmpty()
    {
        var result = FrequencyAnalyzer.Analyze(new List<LogEntry>());
        Assert.Empty(result);
    }

    [Fact]
    public void Analyze_PreservesLevelInfo()
    {
        var entries = new List<LogEntry>
        {
            new() { ErrorType = "DiskWarn", Level = LogLevel.Warning,
                     Timestamp = new DateTime(2024, 1, 15, 8, 0, 0, DateTimeKind.Utc) },
        };

        var result = FrequencyAnalyzer.Analyze(entries);
        Assert.Equal(LogLevel.Warning, result[0].Level);
    }
}
