// TDD Red/Green/Refactor for FrequencyAnalyzer.
// Tests written FIRST; FrequencyAnalyzer doesn't exist yet → compile failure (RED).

using Xunit;

namespace LogAnalyzer.Tests;

public class FrequencyAnalyzerTests
{
    private static readonly DateTime T1 = new(2024, 1, 15, 10, 0, 0);
    private static readonly DateTime T2 = new(2024, 1, 15, 10, 5, 0);
    private static readonly DateTime T3 = new(2024, 1, 15, 10, 10, 0);

    private static LogEntry MakeEntry(string level, string errorType, DateTime ts) =>
        new() { Level = level, ErrorType = errorType, Timestamp = ts, Message = "test", Format = "syslog", RawLine = "" };

    // ── RED: FrequencyAnalyzer tests ─────────────────────────────────────────

    [Fact]
    public void Analyze_SingleErrorEntry_ReturnsOneRow()
    {
        var entries = new[]
        {
            MakeEntry("ERROR", "NullReferenceException", T1),
        };

        var rows = FrequencyAnalyzer.Analyze(entries).ToList();

        Assert.Single(rows);
        Assert.Equal("NullReferenceException", rows[0].ErrorType);
        Assert.Equal("ERROR", rows[0].Level);
        Assert.Equal(1, rows[0].Count);
        Assert.Equal(T1, rows[0].FirstOccurrence);
        Assert.Equal(T1, rows[0].LastOccurrence);
    }

    [Fact]
    public void Analyze_MultipleEntriesSameType_CountsCorrectly()
    {
        var entries = new[]
        {
            MakeEntry("ERROR", "NullReferenceException", T1),
            MakeEntry("ERROR", "NullReferenceException", T2),
            MakeEntry("ERROR", "NullReferenceException", T3),
        };

        var rows = FrequencyAnalyzer.Analyze(entries).ToList();

        Assert.Single(rows);
        Assert.Equal(3, rows[0].Count);
        Assert.Equal(T1, rows[0].FirstOccurrence);
        Assert.Equal(T3, rows[0].LastOccurrence);
    }

    [Fact]
    public void Analyze_DifferentErrorTypes_ProducesOneRowEach()
    {
        var entries = new[]
        {
            MakeEntry("ERROR", "NullReferenceException", T1),
            MakeEntry("ERROR", "ConnectionTimeout", T2),
            MakeEntry("WARN",  "HighMemory", T3),
        };

        var rows = FrequencyAnalyzer.Analyze(entries).ToList();

        Assert.Equal(3, rows.Count);
    }

    [Fact]
    public void Analyze_SameErrorTypeDifferentLevels_TreatsAsSeparateRows()
    {
        // "DatabaseError" as ERROR vs "DatabaseError" as WARN are different rows
        var entries = new[]
        {
            MakeEntry("ERROR", "DatabaseError", T1),
            MakeEntry("WARN",  "DatabaseError", T2),
        };

        var rows = FrequencyAnalyzer.Analyze(entries).ToList();

        Assert.Equal(2, rows.Count);
        Assert.Contains(rows, r => r.Level == "ERROR" && r.Count == 1);
        Assert.Contains(rows, r => r.Level == "WARN"  && r.Count == 1);
    }

    [Fact]
    public void Analyze_EmptyInput_ReturnsEmptyResult()
    {
        var rows = FrequencyAnalyzer.Analyze(Array.Empty<LogEntry>()).ToList();

        Assert.Empty(rows);
    }

    [Fact]
    public void Analyze_FiltersOutInfoAndDebugLevels()
    {
        // Only ERROR and WARN entries should appear in the frequency table
        var entries = new[]
        {
            MakeEntry("ERROR", "SomeError",   T1),
            MakeEntry("INFO",  "StartupInfo", T2),
            MakeEntry("DEBUG", "DebugTrace",  T3),
            MakeEntry("WARN",  "SlowQuery",   T3),
        };

        var rows = FrequencyAnalyzer.Analyze(entries).ToList();

        Assert.Equal(2, rows.Count);
        Assert.DoesNotContain(rows, r => r.Level == "INFO");
        Assert.DoesNotContain(rows, r => r.Level == "DEBUG");
    }

    [Fact]
    public void Analyze_ResultsSortedByCountDescending()
    {
        var entries = new[]
        {
            MakeEntry("ERROR", "TypeA", T1),
            MakeEntry("ERROR", "TypeB", T1),
            MakeEntry("ERROR", "TypeB", T2),
            MakeEntry("ERROR", "TypeB", T3),
            MakeEntry("WARN",  "TypeC", T1),
            MakeEntry("WARN",  "TypeC", T2),
        };

        var rows = FrequencyAnalyzer.Analyze(entries).ToList();

        // TypeB (3) > TypeC (2) > TypeA (1)
        Assert.Equal("TypeB", rows[0].ErrorType);
        Assert.Equal("TypeC", rows[1].ErrorType);
        Assert.Equal("TypeA", rows[2].ErrorType);
    }
}
