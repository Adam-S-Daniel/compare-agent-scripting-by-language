// TDD Red/Green/Refactor for ReportGenerator.
// Tests written first — ReportGenerator class doesn't exist yet (RED phase).

using System.Text.Json;
using Xunit;

namespace LogAnalyzer.Tests;

public class ReportGeneratorTests
{
    private static readonly DateTime T1 = new(2024, 1, 15, 10, 0, 0, DateTimeKind.Utc);
    private static readonly DateTime T2 = new(2024, 1, 15, 11, 30, 0, DateTimeKind.Utc);

    private static FrequencyRow MakeRow(string errorType, string level, int count, DateTime first, DateTime last) =>
        new() { ErrorType = errorType, Level = level, Count = count, FirstOccurrence = first, LastOccurrence = last };

    // ── Human-readable table tests ───────────────────────────────────────────

    [Fact]
    public void RenderTable_NonEmptyRows_ContainsHeaders()
    {
        var rows = new[] { MakeRow("DBError", "ERROR", 5, T1, T2) };

        var output = ReportGenerator.RenderTable(rows);

        // Table must have column headers
        Assert.Contains("Error Type", output);
        Assert.Contains("Level", output);
        Assert.Contains("Count", output);
        Assert.Contains("First Seen", output);
        Assert.Contains("Last Seen", output);
    }

    [Fact]
    public void RenderTable_OneRow_ContainsRowData()
    {
        var rows = new[] { MakeRow("DBError", "ERROR", 5, T1, T2) };

        var output = ReportGenerator.RenderTable(rows);

        Assert.Contains("DBError", output);
        Assert.Contains("ERROR", output);
        Assert.Contains("5", output);
    }

    [Fact]
    public void RenderTable_MultipleRows_AllRowsPresent()
    {
        var rows = new[]
        {
            MakeRow("NullRefEx", "ERROR", 10, T1, T2),
            MakeRow("SlowQuery", "WARN",   3, T1, T1),
        };

        var output = ReportGenerator.RenderTable(rows);

        Assert.Contains("NullRefEx", output);
        Assert.Contains("SlowQuery", output);
    }

    [Fact]
    public void RenderTable_EmptyRows_ReturnsNoDataMessage()
    {
        var output = ReportGenerator.RenderTable(Array.Empty<FrequencyRow>());

        Assert.Contains("No errors", output, StringComparison.OrdinalIgnoreCase);
    }

    // ── JSON output tests ────────────────────────────────────────────────────

    [Fact]
    public void ToJson_SingleRow_IsValidJson()
    {
        var rows = new[] { MakeRow("DBError", "ERROR", 5, T1, T2) };

        var json = ReportGenerator.ToJson(rows);

        // Must parse without exception
        using var doc = JsonDocument.Parse(json);
        Assert.Equal(JsonValueKind.Array, doc.RootElement.ValueKind);
        Assert.Equal(1, doc.RootElement.GetArrayLength());
    }

    [Fact]
    public void ToJson_RowFields_ArePresentInJson()
    {
        var rows = new[] { MakeRow("DBError", "ERROR", 5, T1, T2) };

        var json = ReportGenerator.ToJson(rows);

        using var doc  = JsonDocument.Parse(json);
        var first = doc.RootElement[0];

        Assert.Equal("DBError", first.GetProperty("errorType").GetString());
        Assert.Equal("ERROR",   first.GetProperty("level").GetString());
        Assert.Equal(5,         first.GetProperty("count").GetInt32());
        Assert.True(first.TryGetProperty("firstOccurrence", out _));
        Assert.True(first.TryGetProperty("lastOccurrence",  out _));
    }

    [Fact]
    public void ToJson_EmptyRows_ReturnsEmptyJsonArray()
    {
        var json = ReportGenerator.ToJson(Array.Empty<FrequencyRow>());

        using var doc = JsonDocument.Parse(json);
        Assert.Equal(0, doc.RootElement.GetArrayLength());
    }

    // ── File-writing integration test ────────────────────────────────────────

    [Fact]
    public void WriteJsonFile_CreatesFileWithCorrectContent()
    {
        var rows = new[] { MakeRow("TestError", "ERROR", 2, T1, T2) };
        var path = Path.Combine(Path.GetTempPath(), $"test-report-{Guid.NewGuid()}.json");

        try
        {
            ReportGenerator.WriteJsonFile(rows, path);

            Assert.True(File.Exists(path));
            var content = File.ReadAllText(path);
            using var doc = JsonDocument.Parse(content);
            Assert.Equal(1, doc.RootElement.GetArrayLength());
        }
        finally
        {
            if (File.Exists(path)) File.Delete(path);
        }
    }
}
