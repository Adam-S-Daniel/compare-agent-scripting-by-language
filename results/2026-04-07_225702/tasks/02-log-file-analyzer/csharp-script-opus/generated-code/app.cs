using System.Text.Json;

// =============================================================================
// Log File Analyzer — .NET 10 file-based app
//
// Parses log files containing mixed formats (syslog-style and JSON-structured),
// extracts ERROR and WARNING entries, builds a frequency table, and outputs
// results as both a human-readable table (stdout) and a JSON file.
//
// Usage: dotnet run app.cs <logfile> [output.json]
//   - logfile:     path to the log file to analyze
//   - output.json: optional path for JSON output (default: analysis-output.json)
// =============================================================================

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: dotnet run app.cs <logfile> [output.json]");
    Console.Error.WriteLine("  logfile      Path to the log file to analyze");
    Console.Error.WriteLine("  output.json  Optional path for JSON output (default: analysis-output.json)");
    return 1;
}

var logFilePath = args[0];
var jsonOutputPath = args.Length >= 2 ? args[1] : "analysis-output.json";

if (!File.Exists(logFilePath))
{
    Console.Error.WriteLine($"Error: Log file not found: {logFilePath}");
    return 1;
}

// Step 1: Read and parse all log lines
string[] lines;
try
{
    lines = File.ReadAllLines(logFilePath);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error reading file: {ex.Message}");
    return 1;
}

Console.WriteLine($"Analyzing: {logFilePath}");
Console.WriteLine($"Total lines: {lines.Length}");

var entries = LogParser.ParseLines(lines).ToList();
var unparsed = lines.Length - entries.Count;
if (unparsed > 0)
    Console.WriteLine($"Skipped {unparsed} unparseable line(s)");

// Step 2: Filter to errors and warnings only
var filtered = LogAnalyzer.FilterErrorsAndWarnings(entries).ToList();
Console.WriteLine($"Error/Warning entries: {filtered.Count}");
Console.WriteLine();

// Step 3: Build frequency table
var table = LogAnalyzer.BuildFrequencyTable(filtered);

// Step 4: Output human-readable table to stdout
Console.WriteLine(ReportFormatter.FormatTable(table));

// Step 5: Write JSON output
try
{
    var json = ReportFormatter.FormatJson(table);
    File.WriteAllText(jsonOutputPath, json);
    Console.WriteLine($"JSON output written to: {jsonOutputPath}");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error writing JSON output: {ex.Message}");
    return 1;
}

return 0;

// =============================================================================
// Production code — data types and logic (same as in tests.cs)
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

        var levelWidth = Math.Max("Level".Length, records.Max(r => r.Level.Length));
        var msgWidth = Math.Max("Message".Length, records.Max(r => r.Message.Length));
        var countWidth = Math.Max("Count".Length, records.Max(r => r.Count.ToString().Length));
        const int tsWidth = 19; // "yyyy-MM-dd HH:mm:ss"
        const string tsFmt = "yyyy-MM-dd HH:mm:ss";

        var sb = new System.Text.StringBuilder();

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
