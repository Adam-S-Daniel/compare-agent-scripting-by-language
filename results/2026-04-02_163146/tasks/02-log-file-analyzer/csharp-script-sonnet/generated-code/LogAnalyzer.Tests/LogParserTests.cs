// TDD Red/Green/Refactor for LogParser
// Each test is written FIRST (failing), then minimum implementation is added to pass it.

using Xunit;

namespace LogAnalyzer.Tests;

public class LogParserTests
{
    // ── RED: First failing test ──────────────────────────────────────────────
    // LogParser and LogEntry don't exist yet — this won't compile until we add them.

    [Fact]
    public void ParseLine_SyslogErrorLine_ReturnsParsedEntry()
    {
        // Arrange: a standard syslog-format error line
        var parser = new LogParser();
        string line = "Jan 15 10:23:45 myserver myapp[1234]: ERROR: NullReferenceException in UserService";

        // Act
        var entry = parser.ParseLine(line);

        // Assert
        Assert.NotNull(entry);
        Assert.Equal("ERROR", entry.Level);
        Assert.Equal(1, entry.Timestamp.Month);
        Assert.Equal(15, entry.Timestamp.Day);
        Assert.Equal(10, entry.Timestamp.Hour);
        Assert.Equal(23, entry.Timestamp.Minute);
        Assert.Equal(45, entry.Timestamp.Second);
        Assert.Equal("NullReferenceException in UserService", entry.Message);
        Assert.Equal("syslog", entry.Format);
    }

    [Fact]
    public void ParseLine_SyslogWarnLine_ReturnsParsedEntry()
    {
        var parser = new LogParser();
        string line = "Jan 15 10:24:00 myserver myapp[5678]: WARN: Deprecated API usage in /api/v1/users";

        var entry = parser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal("WARN", entry.Level);
        Assert.Equal("Deprecated API usage in /api/v1/users", entry.Message);
    }

    [Fact]
    public void ParseLine_SyslogInfoLine_ReturnsParsedEntry()
    {
        var parser = new LogParser();
        string line = "Jan 15 10:24:10 myserver myapp[1234]: INFO: User login successful";

        var entry = parser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal("INFO", entry.Level);
    }

    [Fact]
    public void ParseLine_SyslogLineWithWARNINGLevel_NormalizesToWARN()
    {
        var parser = new LogParser();
        // Some syslog producers emit "WARNING" not "WARN"
        string line = "Jan 15 10:25:30 myserver myapp[9012]: WARNING: High memory usage: 85%";

        var entry = parser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal("WARN", entry.Level);
    }

    [Fact]
    public void ParseLine_InvalidLine_ReturnsNull()
    {
        var parser = new LogParser();
        string line = "this is not a valid log line at all";

        var entry = parser.ParseLine(line);

        Assert.Null(entry);
    }

    [Fact]
    public void ParseLine_EmptyLine_ReturnsNull()
    {
        var parser = new LogParser();

        var entry = parser.ParseLine(string.Empty);

        Assert.Null(entry);
    }

    // ── RED: JSON format tests ───────────────────────────────────────────────

    [Fact]
    public void ParseLine_JsonErrorLine_ReturnsParsedEntry()
    {
        var parser = new LogParser();
        string line = """{"timestamp":"2024-01-15T10:23:47Z","level":"ERROR","message":"Failed to connect to Redis","error_type":"ConnectionError","host":"myserver"}""";

        var entry = parser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal("ERROR", entry.Level);
        Assert.Equal("Failed to connect to Redis", entry.Message);
        Assert.Equal("ConnectionError", entry.ErrorType);
        Assert.Equal(new DateTime(2024, 1, 15, 10, 23, 47, DateTimeKind.Utc), entry.Timestamp.ToUniversalTime());
        Assert.Equal("json", entry.Format);
    }

    [Fact]
    public void ParseLine_JsonWarnLine_ReturnsParsedEntry()
    {
        var parser = new LogParser();
        string line = """{"timestamp":"2024-01-15T10:24:00Z","level":"WARN","message":"Cache miss rate above threshold","error_type":"PerformanceWarning"}""";

        var entry = parser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal("WARN", entry.Level);
        Assert.Equal("PerformanceWarning", entry.ErrorType);
    }

    [Fact]
    public void ParseLine_JsonLineWithoutErrorType_UsesLevelAsErrorType()
    {
        var parser = new LogParser();
        // Some JSON entries may not have an explicit error_type field
        string line = """{"timestamp":"2024-01-15T10:25:15Z","level":"INFO","message":"Health check passed"}""";

        var entry = parser.ParseLine(line);

        Assert.NotNull(entry);
        Assert.Equal("INFO", entry.Level);
        // When error_type is absent, fall back to the level value
        Assert.Equal("INFO", entry.ErrorType);
    }

    [Fact]
    public void ParseLine_InvalidJson_ReturnsNull()
    {
        var parser = new LogParser();
        string line = "{not valid json at all";

        var entry = parser.ParseLine(line);

        Assert.Null(entry);
    }

    // ── File-level parsing ───────────────────────────────────────────────────

    [Fact]
    public void ParseLines_MixedFile_ReturnsAllParsedEntries()
    {
        var parser = new LogParser();
        var lines = new[]
        {
            "Jan 15 10:23:45 myserver myapp[1234]: ERROR: Connection refused",
            """{"timestamp":"2024-01-15T10:23:47Z","level":"ERROR","message":"DB failed","error_type":"DBError"}""",
            "Jan 15 10:24:00 myserver myapp[5678]: INFO: Started successfully",
            "this line is invalid and should be skipped",
            """{"timestamp":"2024-01-15T10:25:00Z","level":"WARN","message":"Slow query","error_type":"SlowQuery"}""",
        };

        var entries = parser.ParseLines(lines).ToList();

        // Invalid line is skipped; 4 valid entries
        Assert.Equal(4, entries.Count);
        Assert.Equal(2, entries.Count(e => e.Level == "ERROR"));
        Assert.Equal(1, entries.Count(e => e.Level == "INFO"));
        Assert.Equal(1, entries.Count(e => e.Level == "WARN"));
    }

    [Fact]
    public void ParseLines_ExtractsErrorTypeFromSyslogMessage()
    {
        // For syslog lines, the ErrorType is extracted from the message prefix
        // (the word/phrase before the first space or colon in the message)
        var parser = new LogParser();
        var lines = new[]
        {
            "Jan 15 10:23:45 myserver myapp[1234]: ERROR: NullReferenceException in UserService",
            "Jan 15 10:25:00 myserver myapp[5678]: ERROR: NullReferenceException in OrderService",
            "Jan 15 10:26:00 myserver myapp[1234]: ERROR: ConnectionTimeoutException to db:5432",
        };

        var entries = parser.ParseLines(lines).ToList();

        Assert.Equal("NullReferenceException", entries[0].ErrorType);
        Assert.Equal("NullReferenceException", entries[1].ErrorType);
        Assert.Equal("ConnectionTimeoutException", entries[2].ErrorType);
    }
}
