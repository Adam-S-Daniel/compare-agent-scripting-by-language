// TDD Cycle 7: Integration tests — end-to-end analysis of mixed log files.
// These tests use the sample fixture files and validate the complete pipeline.

using System.Text.Json;
using Xunit;
using LogAnalyzer;

namespace LogAnalyzer.Tests;

public class IntegrationTests
{
    private string FixturePath(string filename) =>
        Path.Combine(AppContext.BaseDirectory, "fixtures", filename);

    [Fact]
    public void AnalyzeFile_MixedLog_ReturnsCorrectCounts()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-mixed.log"));

        // The mixed log has 15 lines total
        Assert.Equal(15, result.TotalLines);
        // Errors: ConnectionTimeout x3, AuthService x2, PaymentFailed x1, NullRef x1 = 7
        Assert.Equal(7, result.ErrorCount);
        // Warnings: SSL cert x1, DiskMonitor x2, CacheMissRate x1, MemoryMonitor x1 = 5
        Assert.Equal(5, result.WarningCount);
    }

    [Fact]
    public void AnalyzeFile_MixedLog_FrequencyTableHasEntries()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-mixed.log"));

        // Should have multiple distinct error types
        Assert.True(result.FrequencyTable.Count > 0);

        // ConnectionTimeout appears 3 times (from JSON lines with explicit error_type)
        var connTimeout = result.FrequencyTable.FirstOrDefault(f => f.ErrorType == "ConnectionTimeout");
        Assert.NotNull(connTimeout);
        Assert.Equal(3, connTimeout!.Count);
    }

    [Fact]
    public void AnalyzeFile_MixedLog_FirstAndLastTimestampsCorrect()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-mixed.log"));

        var connTimeout = result.FrequencyTable.First(f => f.ErrorType == "ConnectionTimeout");
        // First: 2024-01-15T08:24:00Z, Last: 2024-01-15T08:36:00Z
        Assert.Equal(new DateTime(2024, 1, 15, 8, 24, 0, DateTimeKind.Utc), connTimeout.FirstOccurrence);
        Assert.Equal(new DateTime(2024, 1, 15, 8, 36, 0, DateTimeKind.Utc), connTimeout.LastOccurrence);
    }

    [Fact]
    public void AnalyzeFile_SyslogOnly_ParsesAllLines()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-syslog.log"));

        Assert.Equal(7, result.TotalLines);
        // 3 errors + 3 warnings in syslog file (INFO lines filtered out)
        Assert.True(result.ErrorCount >= 2);
        Assert.True(result.WarningCount >= 2);
    }

    [Fact]
    public void AnalyzeFile_JsonOnly_ParsesAllLines()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-json.log"));

        Assert.Equal(6, result.TotalLines);
        // 4 ERROR + 1 WARNING in JSON file (1 INFO filtered out)
        Assert.Equal(4, result.ErrorCount);
        Assert.Equal(1, result.WarningCount);
    }

    [Fact]
    public void AnalyzeFile_NonexistentFile_ThrowsFileNotFoundException()
    {
        var ex = Assert.Throws<FileNotFoundException>(
            () => LogAnalyzerEngine.AnalyzeFile("nonexistent-file.log"));
        Assert.Contains("nonexistent-file.log", ex.Message);
    }

    [Fact]
    public void FullPipeline_TableOutput_ContainsExpectedData()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-mixed.log"));
        var table = TableFormatter.Format(result);

        Assert.Contains("Log Analysis Report", table);
        Assert.Contains("ConnectionTimeout", table);
        Assert.Contains("15", table);  // total lines
    }

    [Fact]
    public void FullPipeline_JsonOutput_IsValidAndComplete()
    {
        var result = LogAnalyzerEngine.AnalyzeFile(FixturePath("sample-mixed.log"));
        var json = JsonOutputWriter.ToJson(result);

        var doc = JsonDocument.Parse(json);
        var summary = doc.RootElement.GetProperty("summary");
        Assert.Equal(15, summary.GetProperty("total_lines").GetInt32());
        Assert.Equal(7, summary.GetProperty("error_count").GetInt32());
        Assert.Equal(5, summary.GetProperty("warning_count").GetInt32());

        var freqTable = doc.RootElement.GetProperty("frequency_table");
        Assert.True(freqTable.GetArrayLength() > 0);
    }

    [Fact]
    public void Analyze_EmptyInput_ReturnsZeroCounts()
    {
        var result = LogAnalyzerEngine.Analyze(Array.Empty<string>());

        Assert.Equal(0, result.TotalLines);
        Assert.Equal(0, result.ErrorCount);
        Assert.Equal(0, result.WarningCount);
        Assert.Empty(result.FrequencyTable);
    }
}
