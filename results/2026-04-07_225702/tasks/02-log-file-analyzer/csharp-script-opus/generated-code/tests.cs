using System.Text.Json;

// =============================================================================
// Self-contained TDD test runner for Log File Analyzer
// Each test method follows red/green/refactor: tests are written first,
// then the production code in LogAnalyzer is built up to make them pass.
// =============================================================================

var passed = 0;
var failed = 0;
var errors = new List<string>();

void AssertEqual<T>(T expected, T actual, string testName)
{
    if (EqualityComparer<T>.Default.Equals(expected, actual))
    {
        Console.WriteLine($"  ✓ {testName}");
        passed++;
    }
    else
    {
        Console.WriteLine($"  ✗ {testName}");
        Console.WriteLine($"    Expected: {expected}");
        Console.WriteLine($"    Actual:   {actual}");
        failed++;
        errors.Add(testName);
    }
}

void AssertTrue(bool condition, string testName)
{
    if (condition)
    {
        Console.WriteLine($"  ✓ {testName}");
        passed++;
    }
    else
    {
        Console.WriteLine($"  ✗ {testName}");
        failed++;
        errors.Add(testName);
    }
}

void AssertNotNull(object? obj, string testName)
{
    if (obj is not null)
    {
        Console.WriteLine($"  ✓ {testName}");
        passed++;
    }
    else
    {
        Console.WriteLine($"  ✗ {testName}");
        Console.WriteLine($"    Expected non-null but got null");
        failed++;
        errors.Add(testName);
    }
}

void AssertNull(object? obj, string testName)
{
    if (obj is null)
    {
        Console.WriteLine($"  ✓ {testName}");
        passed++;
    }
    else
    {
        Console.WriteLine($"  ✗ {testName}");
        Console.WriteLine($"    Expected null but got: {obj}");
        failed++;
        errors.Add(testName);
    }
}

// ---------------------------------------------------------------------------
// TEST GROUP 1: Parsing syslog-style lines
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Parsing syslog-style lines ==");

{
    var line = "2024-01-15 08:23:01 server1 syslog ERROR: Disk space critically low on /dev/sda1";
    var entry = LogParser.ParseLine(line);
    AssertNotNull(entry, "Syslog line parses to non-null");
    AssertEqual(new DateTime(2024, 1, 15, 8, 23, 1), entry!.Timestamp, "Syslog timestamp parsed");
    AssertEqual("ERROR", entry.Level, "Syslog level parsed");
    AssertEqual("Disk space critically low on /dev/sda1", entry.Message, "Syslog message parsed");
    AssertEqual("server1", entry.Host, "Syslog host parsed");
}

{
    var line = "2024-01-15 08:24:12 server2 syslog WARNING: High memory usage detected (92%)";
    var entry = LogParser.ParseLine(line);
    AssertNotNull(entry, "Syslog WARNING parses to non-null");
    AssertEqual("WARNING", entry!.Level, "Syslog WARNING level parsed");
}

{
    var line = "2024-01-15 08:23:05 server1 syslog INFO: Scheduled backup started";
    var entry = LogParser.ParseLine(line);
    AssertNotNull(entry, "Syslog INFO parses to non-null");
    AssertEqual("INFO", entry!.Level, "Syslog INFO level parsed");
}

// ---------------------------------------------------------------------------
// TEST GROUP 2: Parsing JSON-structured lines
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Parsing JSON-structured lines ==");

{
    var line = """{"timestamp":"2024-01-15T08:26:30Z","host":"server3","level":"ERROR","message":"Connection timeout to database","service":"api-gateway"}""";
    var entry = LogParser.ParseLine(line);
    AssertNotNull(entry, "JSON line parses to non-null");
    AssertEqual(new DateTime(2024, 1, 15, 8, 26, 30), entry!.Timestamp, "JSON timestamp parsed");
    AssertEqual("ERROR", entry.Level, "JSON level parsed");
    AssertEqual("Connection timeout to database", entry.Message, "JSON message parsed");
    AssertEqual("server3", entry.Host, "JSON host parsed");
}

// ---------------------------------------------------------------------------
// TEST GROUP 3: Malformed / empty lines return null
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Malformed / empty lines ==");

{
    AssertNull(LogParser.ParseLine(""), "Empty line returns null");
    AssertNull(LogParser.ParseLine("   "), "Whitespace line returns null");
    AssertNull(LogParser.ParseLine("random garbage text"), "Garbage line returns null");
    AssertNull(LogParser.ParseLine("{invalid json"), "Broken JSON returns null");
}

// ---------------------------------------------------------------------------
// TEST GROUP 4: Filtering errors and warnings only
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Filtering errors and warnings ==");

{
    var lines = new[]
    {
        "2024-01-15 08:23:01 server1 syslog ERROR: Disk space low",
        "2024-01-15 08:23:05 server1 syslog INFO: Backup started",
        "2024-01-15 08:24:12 server2 syslog WARNING: High memory",
        """{"timestamp":"2024-01-15T08:26:30Z","host":"s3","level":"INFO","message":"ok"}""",
        """{"timestamp":"2024-01-15T08:27:00Z","host":"s3","level":"ERROR","message":"fail"}""",
    };
    var entries = LogParser.ParseLines(lines).ToList();
    var filtered = LogAnalyzer.FilterErrorsAndWarnings(entries).ToList();
    AssertEqual(3, filtered.Count, "Only ERROR and WARNING entries kept");
    AssertTrue(filtered.All(e => e.Level is "ERROR" or "WARNING"), "All filtered entries are ERROR or WARNING");
}

// ---------------------------------------------------------------------------
// TEST GROUP 5: Frequency table generation
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Frequency table ==");

{
    var entries = new List<LogEntry>
    {
        new("ERROR", "Disk space low", new DateTime(2024,1,15,8,0,0), "s1"),
        new("ERROR", "Disk space low", new DateTime(2024,1,15,9,0,0), "s1"),
        new("ERROR", "Disk space low", new DateTime(2024,1,15,10,0,0), "s1"),
        new("WARNING", "High memory", new DateTime(2024,1,15,8,30,0), "s2"),
        new("WARNING", "High memory", new DateTime(2024,1,15,9,30,0), "s2"),
        new("ERROR", "Connection timeout", new DateTime(2024,1,15,8,15,0), "s3"),
    };
    var table = LogAnalyzer.BuildFrequencyTable(entries);
    AssertEqual(3, table.Count, "Three distinct error types in frequency table");

    var diskEntry = table.First(t => t.Message == "Disk space low");
    AssertEqual(3, diskEntry.Count, "Disk space low count = 3");
    AssertEqual(new DateTime(2024,1,15,8,0,0), diskEntry.FirstOccurrence, "Disk space low first occurrence");
    AssertEqual(new DateTime(2024,1,15,10,0,0), diskEntry.LastOccurrence, "Disk space low last occurrence");
    AssertEqual("ERROR", diskEntry.Level, "Disk space low level");

    var connEntry = table.First(t => t.Message == "Connection timeout");
    AssertEqual(1, connEntry.Count, "Connection timeout count = 1");
    AssertEqual(connEntry.FirstOccurrence, connEntry.LastOccurrence, "Single occurrence: first == last");
}

// ---------------------------------------------------------------------------
// TEST GROUP 6: Human-readable table output
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Human-readable table output ==");

{
    var freqTable = new List<FrequencyRecord>
    {
        new("ERROR", "Disk space low", 3, new DateTime(2024,1,15,8,0,0), new DateTime(2024,1,15,10,0,0)),
        new("WARNING", "High memory", 2, new DateTime(2024,1,15,8,30,0), new DateTime(2024,1,15,9,30,0)),
    };
    var output = ReportFormatter.FormatTable(freqTable);
    AssertTrue(output.Contains("Disk space low"), "Table contains 'Disk space low'");
    AssertTrue(output.Contains("High memory"), "Table contains 'High memory'");
    AssertTrue(output.Contains("3"), "Table contains count 3");
    AssertTrue(output.Contains("ERROR"), "Table contains ERROR level");
    AssertTrue(output.Contains("WARNING"), "Table contains WARNING level");
    // Verify it has header and separator
    AssertTrue(output.Contains("Level"), "Table has Level header");
    AssertTrue(output.Contains("Count"), "Table has Count header");
    AssertTrue(output.Contains("---"), "Table has separator line");
}

// ---------------------------------------------------------------------------
// TEST GROUP 7: JSON output
// ---------------------------------------------------------------------------
Console.WriteLine("\n== JSON output ==");

{
    var freqTable = new List<FrequencyRecord>
    {
        new("ERROR", "Disk space low", 3, new DateTime(2024,1,15,8,0,0), new DateTime(2024,1,15,10,0,0)),
    };
    var json = ReportFormatter.FormatJson(freqTable);
    // Parse it back to verify it's valid JSON
    var doc = JsonDocument.Parse(json);
    var root = doc.RootElement;
    AssertEqual(JsonValueKind.Array, root.ValueKind, "JSON root is an array");
    AssertEqual(1, root.GetArrayLength(), "JSON array has 1 element");
    var item = root[0];
    AssertEqual("ERROR", item.GetProperty("level").GetString()!, "JSON level is ERROR");
    AssertEqual("Disk space low", item.GetProperty("message").GetString()!, "JSON message correct");
    AssertEqual(3, item.GetProperty("count").GetInt32(), "JSON count is 3");
    AssertTrue(item.TryGetProperty("first_occurrence", out _), "JSON has first_occurrence");
    AssertTrue(item.TryGetProperty("last_occurrence", out _), "JSON has last_occurrence");
}

// ---------------------------------------------------------------------------
// TEST GROUP 8: End-to-end with sample fixture file
// ---------------------------------------------------------------------------
Console.WriteLine("\n== End-to-end with fixture file ==");

{
    var fixturePath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "test-fixtures", "sample.log");
    // Also try relative to current directory
    if (!File.Exists(fixturePath))
        fixturePath = Path.Combine(Directory.GetCurrentDirectory(), "test-fixtures", "sample.log");

    if (File.Exists(fixturePath))
    {
        var lines = File.ReadAllLines(fixturePath);
        var entries = LogParser.ParseLines(lines).ToList();
        AssertEqual(15, entries.Count, "Fixture: all 15 lines parsed");

        var filtered = LogAnalyzer.FilterErrorsAndWarnings(entries).ToList();
        AssertEqual(12, filtered.Count, "Fixture: 12 error/warning entries");

        var table = LogAnalyzer.BuildFrequencyTable(filtered);
        // "Disk space critically low on /dev/sda1" should appear 4 times
        var diskErrors = table.First(t => t.Message.Contains("Disk space"));
        AssertEqual(4, diskErrors.Count, "Fixture: Disk space error count = 4");
        AssertEqual(new DateTime(2024,1,15,8,23,1), diskErrors.FirstOccurrence, "Fixture: Disk space first occurrence");
        AssertEqual(new DateTime(2024,1,15,9,5,0), diskErrors.LastOccurrence, "Fixture: Disk space last occurrence");

        // "Connection timeout to database" should appear 2 times
        var connErrors = table.First(t => t.Message.Contains("Connection timeout"));
        AssertEqual(2, connErrors.Count, "Fixture: Connection timeout count = 2");

        // "High memory usage detected (92%)" should appear 2 times (1 syslog + 1 JSON)
        var memWarnings = table.First(t => t.Message.Contains("High memory"));
        AssertEqual(2, memWarnings.Count, "Fixture: High memory warning count = 2");
    }
    else
    {
        Console.WriteLine($"  ⚠ Fixture file not found at {fixturePath}");
        failed++;
        errors.Add("Fixture file not found");
    }
}

// ---------------------------------------------------------------------------
// TEST GROUP 9: Edge cases
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Edge cases ==");

{
    // Empty input
    var entries = LogParser.ParseLines(Array.Empty<string>()).ToList();
    AssertEqual(0, entries.Count, "Empty input produces no entries");

    var filtered = LogAnalyzer.FilterErrorsAndWarnings(entries).ToList();
    AssertEqual(0, filtered.Count, "Empty filter produces no results");

    var table = LogAnalyzer.BuildFrequencyTable(filtered);
    AssertEqual(0, table.Count, "Empty table is empty");

    // Table/JSON formatting with empty data
    var tableStr = ReportFormatter.FormatTable(table);
    AssertTrue(tableStr.Contains("No error"), "Empty table shows 'no error' message");

    var jsonStr = ReportFormatter.FormatJson(table);
    AssertEqual("[]", jsonStr.Trim(), "Empty JSON is []");
}

// ---------------------------------------------------------------------------
// TEST GROUP 10: File error handling
// ---------------------------------------------------------------------------
Console.WriteLine("\n== File error handling ==");

{
    // Nonexistent file
    var caught = false;
    try
    {
        var lines = File.ReadAllLines("/nonexistent/path/log.txt");
    }
    catch (DirectoryNotFoundException)
    {
        caught = true;
    }
    catch (FileNotFoundException)
    {
        caught = true;
    }
    AssertTrue(caught, "Nonexistent file throws meaningful exception");
}

// ---------------------------------------------------------------------------
// TEST GROUP 11: JSON with WARN level (normalization)
// ---------------------------------------------------------------------------
Console.WriteLine("\n== Level normalization ==");

{
    // JSON with "WARN" level should be normalized to "WARNING" and caught by filter
    var line = """{"timestamp":"2024-01-15T08:26:30Z","host":"s1","level":"WARN","message":"Low disk"}""";
    var entry = LogParser.ParseLine(line);
    AssertNotNull(entry, "WARN JSON line parses");
    AssertEqual("WARNING", entry!.Level, "WARN normalized to WARNING");
    var filtered = LogAnalyzer.FilterErrorsAndWarnings(new[] { entry }).ToList();
    AssertEqual(1, filtered.Count, "WARN (normalized to WARNING) caught by filter");
}

{
    // Mixed case JSON levels should be uppercased
    var line = """{"timestamp":"2024-01-15T08:26:30Z","host":"s1","level":"error","message":"Lowercase err"}""";
    var entry = LogParser.ParseLine(line);
    AssertNotNull(entry, "Lowercase 'error' JSON parses");
    AssertEqual("ERROR", entry!.Level, "Lowercase 'error' normalized to ERROR");
    var filtered = LogAnalyzer.FilterErrorsAndWarnings(new[] { entry }).ToList();
    AssertEqual(1, filtered.Count, "Lowercase 'error' matched by filter after normalization");
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
Console.WriteLine($"\n{"=",-50}");
Console.WriteLine($"Results: {passed} passed, {failed} failed");
if (errors.Count > 0)
{
    Console.WriteLine("Failed tests:");
    foreach (var e in errors)
        Console.WriteLine($"  - {e}");
}
Console.WriteLine($"{"=",-50}");

return failed > 0 ? 1 : 0;

// =============================================================================
// Production code — data types and logic
// =============================================================================

/// <summary>A single parsed log entry.</summary>
record LogEntry(string Level, string Message, DateTime Timestamp, string Host);

/// <summary>An aggregated frequency record for a specific error/warning type.</summary>
record FrequencyRecord(string Level, string Message, int Count, DateTime FirstOccurrence, DateTime LastOccurrence);

/// <summary>Parses raw log lines in syslog or JSON format.</summary>
static class LogParser
{
    // Syslog format: "YYYY-MM-DD HH:MM:SS hostname facility LEVEL: message"
    // JSON format: {"timestamp":"...","host":"...","level":"...","message":"..."}
    public static LogEntry? ParseLine(string line)
    {
        if (string.IsNullOrWhiteSpace(line))
            return null;

        var trimmed = line.Trim();

        // Try JSON first if it starts with '{'
        if (trimmed.StartsWith('{'))
            return TryParseJson(trimmed);

        // Otherwise try syslog format
        return TryParseSyslog(trimmed);
    }

    /// <summary>Parse all lines, skipping any that fail to parse.</summary>
    public static IEnumerable<LogEntry> ParseLines(IEnumerable<string> lines)
    {
        foreach (var line in lines)
        {
            var entry = ParseLine(line);
            if (entry is not null)
                yield return entry;
        }
    }

    /// <summary>Normalize level to uppercase and map WARN → WARNING.</summary>
    private static string NormalizeLevel(string level)
    {
        var upper = level.ToUpperInvariant();
        return upper == "WARN" ? "WARNING" : upper;
    }

    private static LogEntry? TryParseSyslog(string line)
    {
        // Expected: "2024-01-15 08:23:01 server1 syslog ERROR: Disk space critically low"
        // Parts:     ^--- timestamp ---^ ^host^  ^fac^  ^level^: ^--- message ---^
        // The timestamp is 19 chars: "YYYY-MM-DD HH:MM:SS"
        if (line.Length < 20)
            return null;

        if (!DateTime.TryParse(line[..19], out var timestamp))
            return null;

        // After timestamp, split remaining by spaces to get host, facility, level
        var rest = line[20..];
        var colonIdx = rest.IndexOf(':');
        if (colonIdx < 0)
            return null;

        var beforeColon = rest[..colonIdx].Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (beforeColon.Length < 3)
            return null;

        var host = beforeColon[0];
        // facility is beforeColon[1] (e.g. "syslog") — we don't need it
        var level = NormalizeLevel(beforeColon[^1]); // last word before colon is the level
        var message = rest[(colonIdx + 1)..].Trim();

        return new LogEntry(level, message, timestamp, host);
    }

    private static LogEntry? TryParseJson(string line)
    {
        try
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;

            var level = NormalizeLevel(root.GetProperty("level").GetString() ?? "");
            var message = root.GetProperty("message").GetString() ?? "";
            var host = root.TryGetProperty("host", out var h) ? h.GetString() ?? "" : "";

            DateTime timestamp;
            var tsStr = root.GetProperty("timestamp").GetString();
            if (tsStr is null || !DateTime.TryParse(tsStr, null,
                    System.Globalization.DateTimeStyles.AdjustToUniversal |
                    System.Globalization.DateTimeStyles.AssumeUniversal,
                    out timestamp))
                return null;

            return new LogEntry(level, message, timestamp, host);
        }
        catch
        {
            return null;
        }
    }
}

/// <summary>Filtering and aggregation logic for log entries.</summary>
static class LogAnalyzer
{
    /// <summary>Keep only ERROR and WARNING entries.</summary>
    public static IEnumerable<LogEntry> FilterErrorsAndWarnings(IEnumerable<LogEntry> entries)
        => entries.Where(e => e.Level is "ERROR" or "WARNING");

    /// <summary>
    /// Build a frequency table grouped by (level, message).
    /// Tracks count, first occurrence, and last occurrence for each group.
    /// Results are sorted by count descending.
    /// </summary>
    public static List<FrequencyRecord> BuildFrequencyTable(IEnumerable<LogEntry> entries)
    {
        return entries
            .GroupBy(e => (e.Level, e.Message))
            .Select(g => new FrequencyRecord(
                g.Key.Level,
                g.Key.Message,
                g.Count(),
                g.Min(e => e.Timestamp),
                g.Max(e => e.Timestamp)))
            .OrderByDescending(r => r.Count)
            .ThenBy(r => r.FirstOccurrence)
            .ToList();
    }
}

/// <summary>Formats frequency table data as human-readable text or JSON.</summary>
static class ReportFormatter
{
    /// <summary>Format as an aligned, human-readable table.</summary>
    public static string FormatTable(List<FrequencyRecord> records)
    {
        if (records.Count == 0)
            return "No error or warning entries found.";

        // Compute column widths
        var levelWidth = Math.Max("Level".Length, records.Max(r => r.Level.Length));
        var msgWidth = Math.Max("Message".Length, records.Max(r => r.Message.Length));
        var countWidth = Math.Max("Count".Length, records.Max(r => r.Count.ToString().Length));
        const int tsWidth = 19; // "yyyy-MM-dd HH:mm:ss"
        const string tsFmt = "yyyy-MM-dd HH:mm:ss";

        var sb = new System.Text.StringBuilder();

        // Header
        sb.AppendLine($"{"Level".PadRight(levelWidth)}  {"Count".PadLeft(countWidth)}  {"Message".PadRight(msgWidth)}  {"First Occurrence".PadRight(tsWidth)}  {"Last Occurrence".PadRight(tsWidth)}");
        sb.AppendLine($"{new string('-', levelWidth)}  {new string('-', countWidth)}  {new string('-', msgWidth)}  {new string('-', tsWidth)}  {new string('-', tsWidth)}");

        foreach (var r in records)
        {
            sb.AppendLine($"{r.Level.PadRight(levelWidth)}  {r.Count.ToString().PadLeft(countWidth)}  {r.Message.PadRight(msgWidth)}  {r.FirstOccurrence.ToString(tsFmt)}  {r.LastOccurrence.ToString(tsFmt)}");
        }

        sb.AppendLine();
        sb.AppendLine($"Total distinct error/warning types: {records.Count}");
        sb.AppendLine($"Total occurrences: {records.Sum(r => r.Count)}");

        return sb.ToString();
    }

    /// <summary>Format as a JSON array using Utf8JsonWriter (AOT-compatible).</summary>
    public static string FormatJson(List<FrequencyRecord> records)
    {
        using var stream = new System.IO.MemoryStream();
        using var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true });

        writer.WriteStartArray();
        foreach (var r in records)
        {
            writer.WriteStartObject();
            writer.WriteString("level", r.Level);
            writer.WriteString("message", r.Message);
            writer.WriteNumber("count", r.Count);
            writer.WriteString("first_occurrence", r.FirstOccurrence.ToString("yyyy-MM-ddTHH:mm:ssZ"));
            writer.WriteString("last_occurrence", r.LastOccurrence.ToString("yyyy-MM-ddTHH:mm:ssZ"));
            writer.WriteEndObject();
        }
        writer.WriteEndArray();
        writer.Flush();

        return System.Text.Encoding.UTF8.GetString(stream.ToArray());
    }
}
