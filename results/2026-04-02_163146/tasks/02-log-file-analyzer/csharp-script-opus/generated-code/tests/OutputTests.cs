// TDD Cycles 5 & 6: Tests for human-readable table formatting and JSON output.

using System.Text.Json;
using Xunit;
using LogAnalyzer;

namespace LogAnalyzer.Tests;

public class TableFormatterTests
{
    private AnalysisResult CreateSampleResult()
    {
        return new AnalysisResult
        {
            TotalLines = 15,
            ErrorCount = 6,
            WarningCount = 4,
            FrequencyTable = new List<ErrorFrequency>
            {
                new()
                {
                    ErrorType = "ConnectionTimeout", Count = 3, Level = LogLevel.Error,
                    FirstOccurrence = new DateTime(2024, 1, 15, 8, 24, 0, DateTimeKind.Utc),
                    LastOccurrence = new DateTime(2024, 1, 15, 8, 36, 0, DateTimeKind.Utc)
                },
                new()
                {
                    ErrorType = "AuthFailure", Count = 2, Level = LogLevel.Error,
                    FirstOccurrence = new DateTime(2024, 1, 15, 8, 25, 0, DateTimeKind.Utc),
                    LastOccurrence = new DateTime(2024, 1, 15, 8, 30, 0, DateTimeKind.Utc)
                }
            }
        };
    }

    [Fact]
    public void Format_ContainsReportHeader()
    {
        var result = CreateSampleResult();
        var output = TableFormatter.Format(result);

        Assert.Contains("Log Analysis Report", output);
    }

    [Fact]
    public void Format_ContainsSummaryStats()
    {
        var result = CreateSampleResult();
        var output = TableFormatter.Format(result);

        Assert.Contains("Total lines parsed:", output);
        Assert.Contains("15", output);
        Assert.Contains("Errors found:", output);
        Assert.Contains("6", output);
        Assert.Contains("Warnings found:", output);
        Assert.Contains("4", output);
    }

    [Fact]
    public void Format_ContainsColumnHeaders()
    {
        var result = CreateSampleResult();
        var output = TableFormatter.Format(result);

        Assert.Contains("Error Type", output);
        Assert.Contains("Count", output);
        Assert.Contains("First Occurrence", output);
        Assert.Contains("Last Occurrence", output);
    }

    [Fact]
    public void Format_ContainsFrequencyData()
    {
        var result = CreateSampleResult();
        var output = TableFormatter.Format(result);

        Assert.Contains("ConnectionTimeout", output);
        Assert.Contains("3", output);
        Assert.Contains("AuthFailure", output);
        Assert.Contains("2", output);
    }

    [Fact]
    public void Format_ContainsTimestamps()
    {
        var result = CreateSampleResult();
        var output = TableFormatter.Format(result);

        Assert.Contains("2024-01-15 08:24:00", output);
        Assert.Contains("2024-01-15 08:36:00", output);
    }

    [Fact]
    public void Format_EmptyFrequencyTable_ShowsNoErrorsMessage()
    {
        var result = new AnalysisResult
        {
            TotalLines = 5,
            ErrorCount = 0,
            WarningCount = 0,
            FrequencyTable = new List<ErrorFrequency>()
        };

        var output = TableFormatter.Format(result);
        Assert.Contains("No errors or warnings found", output);
    }
}

public class JsonOutputWriterTests
{
    [Fact]
    public void ToJson_ValidResult_ProducesValidJson()
    {
        var result = new AnalysisResult
        {
            TotalLines = 10,
            ErrorCount = 3,
            WarningCount = 2,
            FrequencyTable = new List<ErrorFrequency>
            {
                new()
                {
                    ErrorType = "TestError", Count = 3, Level = LogLevel.Error,
                    FirstOccurrence = new DateTime(2024, 1, 15, 8, 0, 0, DateTimeKind.Utc),
                    LastOccurrence = new DateTime(2024, 1, 15, 9, 0, 0, DateTimeKind.Utc)
                }
            }
        };

        var json = JsonOutputWriter.ToJson(result);

        // Should be valid JSON
        var doc = JsonDocument.Parse(json);
        Assert.NotNull(doc);
    }

    [Fact]
    public void ToJson_ContainsSummary()
    {
        var result = new AnalysisResult
        {
            TotalLines = 10,
            ErrorCount = 3,
            WarningCount = 2,
            FrequencyTable = new List<ErrorFrequency>()
        };

        var json = JsonOutputWriter.ToJson(result);
        var doc = JsonDocument.Parse(json);
        var summary = doc.RootElement.GetProperty("summary");

        Assert.Equal(10, summary.GetProperty("total_lines").GetInt32());
        Assert.Equal(3, summary.GetProperty("error_count").GetInt32());
        Assert.Equal(2, summary.GetProperty("warning_count").GetInt32());
    }

    [Fact]
    public void ToJson_ContainsFrequencyTable()
    {
        var result = new AnalysisResult
        {
            TotalLines = 5,
            ErrorCount = 2,
            WarningCount = 0,
            FrequencyTable = new List<ErrorFrequency>
            {
                new()
                {
                    ErrorType = "Timeout", Count = 2, Level = LogLevel.Error,
                    FirstOccurrence = new DateTime(2024, 1, 15, 8, 0, 0, DateTimeKind.Utc),
                    LastOccurrence = new DateTime(2024, 1, 15, 9, 0, 0, DateTimeKind.Utc)
                }
            }
        };

        var json = JsonOutputWriter.ToJson(result);
        var doc = JsonDocument.Parse(json);
        var table = doc.RootElement.GetProperty("frequency_table");

        Assert.Equal(1, table.GetArrayLength());
        var first = table[0];
        Assert.Equal("Timeout", first.GetProperty("error_type").GetString());
        Assert.Equal(2, first.GetProperty("count").GetInt32());
        Assert.Equal("error", first.GetProperty("level").GetString());
        Assert.Equal("2024-01-15T08:00:00Z", first.GetProperty("first_occurrence").GetString());
        Assert.Equal("2024-01-15T09:00:00Z", first.GetProperty("last_occurrence").GetString());
    }

    [Fact]
    public void ToJson_EmptyFrequencyTable_ReturnsEmptyArray()
    {
        var result = new AnalysisResult
        {
            TotalLines = 5,
            ErrorCount = 0,
            WarningCount = 0,
            FrequencyTable = new List<ErrorFrequency>()
        };

        var json = JsonOutputWriter.ToJson(result);
        var doc = JsonDocument.Parse(json);
        var table = doc.RootElement.GetProperty("frequency_table");
        Assert.Equal(0, table.GetArrayLength());
    }
}
