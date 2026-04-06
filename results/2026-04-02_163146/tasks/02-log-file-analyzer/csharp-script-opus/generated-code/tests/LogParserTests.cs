// TDD Cycle 1 & 2: Tests for parsing syslog-style and JSON-structured log lines.
// RED phase: these tests are written first, before any implementation exists.

using Xunit;
using LogAnalyzer;

namespace LogAnalyzer.Tests;

public class SyslogParserTests
{
    // Cycle 1: Parse a standard syslog-style log line
    [Fact]
    public void ParseSyslogLine_ValidErrorLine_ReturnsLogEntry()
    {
        var line = "2024-01-15 08:25:12 ERROR [AuthService] Failed login attempt for user admin - invalid credentials";
        var entry = LogParser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal(new DateTime(2024, 1, 15, 8, 25, 12, DateTimeKind.Utc), entry!.Timestamp);
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Equal("AuthService", entry.Source);
        Assert.Equal("Failed login attempt for user admin - invalid credentials", entry.Message);
    }

    [Fact]
    public void ParseSyslogLine_ValidWarnLine_ReturnsLogEntry()
    {
        var line = "2024-01-15 08:23:05 WARN  [WebServer] SSL certificate expires in 7 days";
        var entry = LogParser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal(LogLevel.Warning, entry!.Level);
        Assert.Equal("WebServer", entry.Source);
        Assert.Equal("SSL certificate expires in 7 days", entry.Message);
    }

    [Fact]
    public void ParseSyslogLine_InfoLine_ReturnsInfoLevel()
    {
        var line = "2024-01-15 08:23:01 INFO  [WebServer] Server started on port 8080";
        var entry = LogParser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal(LogLevel.Info, entry!.Level);
    }

    [Fact]
    public void ParseSyslogLine_InvalidLine_ReturnsNull()
    {
        var line = "this is not a valid log line";
        var entry = LogParser.ParseLine(line);

        Assert.Null(entry);
    }

    [Fact]
    public void ParseSyslogLine_EmptyLine_ReturnsNull()
    {
        var entry = LogParser.ParseLine("");
        Assert.Null(entry);

        var entryNull = LogParser.ParseLine(null!);
        Assert.Null(entryNull);
    }
}

public class JsonLogParserTests
{
    // Cycle 2: Parse a JSON-structured log line
    [Fact]
    public void ParseJsonLine_ValidErrorLine_ReturnsLogEntry()
    {
        var line = "{\"timestamp\":\"2024-01-15T08:24:00Z\",\"level\":\"ERROR\",\"source\":\"Database\",\"message\":\"Connection timeout after 30s\",\"error_type\":\"ConnectionTimeout\"}";
        var entry = LogParser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal(new DateTime(2024, 1, 15, 8, 24, 0, DateTimeKind.Utc), entry!.Timestamp);
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Equal("Database", entry.Source);
        Assert.Equal("Connection timeout after 30s", entry.Message);
        Assert.Equal("ConnectionTimeout", entry.ErrorType);
    }

    [Fact]
    public void ParseJsonLine_WarningLevel_RecognizedAsWarning()
    {
        var line = "{\"timestamp\":\"2024-01-15T08:31:00Z\",\"level\":\"WARNING\",\"source\":\"Cache\",\"message\":\"Cache miss rate above threshold\",\"error_type\":\"CacheMissRate\"}";
        var entry = LogParser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal(LogLevel.Warning, entry!.Level);
    }

    [Fact]
    public void ParseJsonLine_InfoLevel_ReturnsInfoEntry()
    {
        var line = "{\"timestamp\":\"2024-01-15T08:26:30Z\",\"level\":\"INFO\",\"source\":\"Scheduler\",\"message\":\"Cron job started\"}";
        var entry = LogParser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal(LogLevel.Info, entry!.Level);
    }

    [Fact]
    public void ParseJsonLine_MalformedJson_ReturnsNull()
    {
        var line = "{\"timestamp\":\"2024-01-15T08:26:30Z\",\"level\":\"INFO\"";
        var entry = LogParser.ParseLine(line);

        Assert.Null(entry);
    }
}

public class ParseMultipleLinesTests
{
    // Test parsing multiple lines from a file-like input
    [Fact]
    public void ParseLines_MixedInput_ReturnsAllValidEntries()
    {
        var lines = new[]
        {
            "2024-01-15 08:23:01 INFO  [WebServer] Server started on port 8080",
            "{\"timestamp\":\"2024-01-15T08:24:00Z\",\"level\":\"ERROR\",\"source\":\"Database\",\"message\":\"Connection timeout\",\"error_type\":\"ConnectionTimeout\"}",
            "this is garbage",
            "2024-01-15 08:25:12 ERROR [AuthService] Failed login attempt",
            ""
        };

        var entries = LogParser.ParseLines(lines);

        Assert.Equal(3, entries.Count);
        Assert.Equal(LogLevel.Info, entries[0].Level);
        Assert.Equal(LogLevel.Error, entries[1].Level);
        Assert.Equal(LogLevel.Error, entries[2].Level);
    }
}
