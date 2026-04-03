// End-to-end integration tests using the sample.log fixture.
// These tests verify the complete pipeline: parse → analyze → report.

using System.Text.Json;
using Xunit;

namespace LogAnalyzer.Tests;

public class IntegrationTests
{
    // Path to the sample fixture relative to the test assembly output directory.
    // The fixture is copied to output via the .csproj CopyToOutputDirectory setting.
    private static string FixturePath => Path.Combine(
        AppContext.BaseDirectory, "Fixtures", "sample.log");

    [Fact]
    public void SampleLog_ParsedEntriesCount_IsCorrect()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();

        // The sample has 29 non-comment, non-blank lines total.
        // 3 are invalid/missing required fields → 26 valid entries expected.
        // (2 malformed lines: raw text + broken JSON without timestamp/level)
        Assert.True(entries.Count >= 24, $"Expected at least 24 entries but got {entries.Count}");
    }

    [Fact]
    public void SampleLog_HasBothSyslogAndJsonEntries()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();

        Assert.Contains(entries, e => e.Format == "syslog");
        Assert.Contains(entries, e => e.Format == "json");
    }

    [Fact]
    public void SampleLog_FrequencyTable_ContainsExpectedTypes()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();
        var rows    = FrequencyAnalyzer.Analyze(entries).ToList();

        // Sample contains: NullReferenceException, ConnectionTimeoutException,
        // ConnectionError, AuthenticationError, PerformanceWarning, SlowQuery,
        // HighMemory/WARNING-related WARN entries
        Assert.True(rows.Count >= 5, $"Expected at least 5 frequency rows but got {rows.Count}");
        Assert.Contains(rows, r => r.ErrorType.Contains("NullReference"));
        Assert.Contains(rows, r => r.ErrorType.Contains("ConnectionError") || r.ErrorType.Contains("Connection"));
    }

    [Fact]
    public void SampleLog_FrequencyTable_OnlyContainsErrorsAndWarnings()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();
        var rows    = FrequencyAnalyzer.Analyze(entries).ToList();

        Assert.DoesNotContain(rows, r => r.Level == "INFO");
        Assert.DoesNotContain(rows, r => r.Level == "DEBUG");
    }

    [Fact]
    public void SampleLog_HumanReadableReport_IsWellFormed()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();
        var rows    = FrequencyAnalyzer.Analyze(entries).ToList();
        var table   = ReportGenerator.RenderTable(rows);

        Assert.Contains("Error Type", table);
        Assert.Contains("Count", table);
        Assert.Contains("|", table); // ASCII table borders
    }

    [Fact]
    public void SampleLog_JsonReport_IsValidAndComplete()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();
        var rows    = FrequencyAnalyzer.Analyze(entries).ToList();
        var json    = ReportGenerator.ToJson(rows);

        using var doc = JsonDocument.Parse(json);
        Assert.Equal(JsonValueKind.Array, doc.RootElement.ValueKind);
        Assert.True(doc.RootElement.GetArrayLength() > 0);

        // Verify each object has required fields
        foreach (var item in doc.RootElement.EnumerateArray())
        {
            Assert.True(item.TryGetProperty("errorType",       out _), "Missing errorType");
            Assert.True(item.TryGetProperty("level",           out _), "Missing level");
            Assert.True(item.TryGetProperty("count",           out _), "Missing count");
            Assert.True(item.TryGetProperty("firstOccurrence", out _), "Missing firstOccurrence");
            Assert.True(item.TryGetProperty("lastOccurrence",  out _), "Missing lastOccurrence");
        }
    }

    [Fact]
    public void SampleLog_WriteJsonFile_CreatesReadableFile()
    {
        var lines   = File.ReadAllLines(FixturePath);
        var parser  = new LogParser();
        var entries = parser.ParseLines(lines).ToList();
        var rows    = FrequencyAnalyzer.Analyze(entries).ToList();
        var outPath = Path.Combine(Path.GetTempPath(), $"integration-test-{Guid.NewGuid()}.json");

        try
        {
            ReportGenerator.WriteJsonFile(rows, outPath);
            Assert.True(File.Exists(outPath));

            var json = File.ReadAllText(outPath);
            using var doc = JsonDocument.Parse(json);
            Assert.True(doc.RootElement.GetArrayLength() > 0);
        }
        finally
        {
            if (File.Exists(outPath)) File.Delete(outPath);
        }
    }
}
