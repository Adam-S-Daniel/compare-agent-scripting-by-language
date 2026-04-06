// TDD Cycle 3: Tests for filtering log entries to only errors and warnings.

using Xunit;
using LogAnalyzer;

namespace LogAnalyzer.Tests;

public class LogFilterTests
{
    [Fact]
    public void FilterErrorsAndWarnings_MixedEntries_ReturnsOnlyErrorsAndWarnings()
    {
        var entries = new List<LogEntry>
        {
            new() { Level = LogLevel.Info, Message = "info msg" },
            new() { Level = LogLevel.Error, Message = "error msg" },
            new() { Level = LogLevel.Warning, Message = "warn msg" },
            new() { Level = LogLevel.Info, Message = "another info" },
            new() { Level = LogLevel.Error, Message = "another error" },
        };

        var filtered = LogFilter.FilterErrorsAndWarnings(entries);

        Assert.Equal(3, filtered.Count);
        Assert.All(filtered, e => Assert.True(
            e.Level == LogLevel.Error || e.Level == LogLevel.Warning));
    }

    [Fact]
    public void FilterErrorsAndWarnings_NoErrorsOrWarnings_ReturnsEmpty()
    {
        var entries = new List<LogEntry>
        {
            new() { Level = LogLevel.Info, Message = "info 1" },
            new() { Level = LogLevel.Info, Message = "info 2" },
        };

        var filtered = LogFilter.FilterErrorsAndWarnings(entries);
        Assert.Empty(filtered);
    }

    [Fact]
    public void FilterErrorsAndWarnings_EmptyList_ReturnsEmpty()
    {
        var filtered = LogFilter.FilterErrorsAndWarnings(new List<LogEntry>());
        Assert.Empty(filtered);
    }

    [Fact]
    public void FilterErrorsAndWarnings_AllErrors_ReturnsAll()
    {
        var entries = new List<LogEntry>
        {
            new() { Level = LogLevel.Error, Message = "err 1" },
            new() { Level = LogLevel.Warning, Message = "warn 1" },
        };

        var filtered = LogFilter.FilterErrorsAndWarnings(entries);
        Assert.Equal(2, filtered.Count);
    }
}
