// app.cs — Log File Analyzer
// Run: dotnet run app.cs [logfile] [output.json]
//
// Parses a mixed-format log file (syslog-style + JSON-structured lines),
// extracts ERROR and WARNING entries, builds a frequency table per error type
// with first/last occurrence timestamps, then outputs:
//   • A human-readable table to stdout
//   • A JSON report file (default: analysis.json)
//
// Example:
//   dotnet run app.cs sample.log analysis.json

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

// ─── Entry point ────────────────────────────────────────────────────────────

var logFile    = args.Length > 0 ? args[0] : "sample.log";
var outputFile = args.Length > 1 ? args[1] : "analysis.json";

Console.WriteLine($"Log File Analyzer — .NET 10 file-based app");
Console.WriteLine($"{'─', -50}");

if (!File.Exists(logFile)) {
    Console.Error.WriteLine($"Error: log file '{logFile}' not found.");
    Console.Error.WriteLine("Usage: dotnet run app.cs [logfile] [output.json]");
    Environment.Exit(1);
}

Console.WriteLine($"Input  : {logFile}");
Console.WriteLine($"Output : {outputFile}");
Console.WriteLine();

try {
    var entries    = LogAnalyzer.ParseFile(logFile).ToList();
    var table      = LogAnalyzer.BuildFrequencyTable(entries);
    var formatted  = LogAnalyzer.FormatTable(table);

    Console.WriteLine($"Parsed {entries.Count} error/warning entries from log.");
    Console.WriteLine();
    Console.WriteLine(formatted);

    LogAnalyzer.WriteJsonReport(table, outputFile);
    Console.WriteLine($"JSON report written → {outputFile}");
} catch (FileNotFoundException ex) {
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.Exit(1);
} catch (Exception ex) {
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    Environment.Exit(2);
}


// ─── Domain model ────────────────────────────────────────────────────────────

/// <summary>Which log format this entry was parsed from.</summary>
public enum LogFormat { Syslog, Json, Unknown }

/// <summary>
/// A single parsed log entry. Only ERROR and WARNING entries are produced;
/// INFO/DEBUG are discarded by the parser.
/// </summary>
public record LogEntry {
    public DateTime  Timestamp { get; init; }
    public string    Level     { get; init; } = "";
    public string    ErrorType { get; init; } = "";
    public string    Message   { get; init; } = "";
    public string    RawLine   { get; init; } = "";
    public LogFormat Format    { get; init; }

    /// <summary>True when Level is ERROR or WARNING.</summary>
    public bool IsErrorOrWarning => Level is "ERROR" or "WARNING";
}

/// <summary>Aggregated statistics for one error/warning type.</summary>
public record ErrorFrequency {
    public string   ErrorType       { get; init; } = "";
    public int      Count           { get; init; }
    public DateTime FirstOccurrence { get; init; }
    public DateTime LastOccurrence  { get; init; }
}


// ─── Parser ──────────────────────────────────────────────────────────────────

/// <summary>
/// Parses individual log lines. Returns null for INFO/DEBUG lines,
/// unrecognised formats, or malformed input — never throws.
/// </summary>
public static class LogParser {
    // Syslog: "Apr  7 14:23:01 hostname process[pid]: LEVEL TYPE: message"
    // Groups: (1) month  (2) day  (3) time  (4) level  (5) type  (6) message
    private static readonly Regex SyslogRe = new(
        @"^(\w{3})\s+(\d{1,2})\s+([\d:]+)\s+\S+\s+\S+\[\d+\]:\s+(ERROR|WARNING)\s+(\w+):\s+(.*)$",
        RegexOptions.Compiled);

    /// <summary>
    /// Detects the format of <paramref name="line"/> and delegates to the
    /// appropriate parser. Returns null if the line is not an error/warning
    /// or cannot be parsed.
    /// </summary>
    public static LogEntry? ParseLine(string line) {
        if (string.IsNullOrWhiteSpace(line)) return null;
        var trimmed = line.TrimStart();
        return trimmed.StartsWith('{') ? ParseJsonLine(trimmed) : ParseSyslogLine(line);
    }

    private static LogEntry? ParseSyslogLine(string line) {
        var m = SyslogRe.Match(line);
        if (!m.Success) return null;

        var month = m.Groups[1].Value;
        var day   = int.Parse(m.Groups[2].Value);
        var time  = m.Groups[3].Value;
        var level = m.Groups[4].Value;
        var type  = m.Groups[5].Value;
        var msg   = m.Groups[6].Value;

        // Syslog has no year — assume current year; pad day for ParseExact
        var year    = DateTime.Now.Year;
        var dateStr = $"{month} {day:D2} {time} {year}";
        DateTime.TryParseExact(dateStr, "MMM dd HH:mm:ss yyyy",
            CultureInfo.InvariantCulture, DateTimeStyles.None, out var ts);

        return new LogEntry { Timestamp = ts, Level = level, ErrorType = type,
                              Message = msg, RawLine = line, Format = LogFormat.Syslog };
    }

    private static LogEntry? ParseJsonLine(string line) {
        try {
            using var doc  = JsonDocument.Parse(line);
            var root = doc.RootElement;

            if (!root.TryGetProperty("level", out var lvProp)) return null;
            var level = lvProp.GetString()?.ToUpperInvariant() ?? "";
            if (level is not ("ERROR" or "WARNING")) return null;

            var type = root.TryGetProperty("type", out var tp)
                ? tp.GetString() ?? "Unknown" : "Unknown";

            var msg = root.TryGetProperty("message", out var mp)
                ? mp.GetString() ?? "" : "";

            DateTime ts = DateTime.MinValue;
            if (root.TryGetProperty("timestamp", out var tsp)) {
                var s = tsp.GetString();
                if (s != null)
                    DateTime.TryParse(s, CultureInfo.InvariantCulture,
                        DateTimeStyles.RoundtripKind, out ts);
            }

            return new LogEntry { Timestamp = ts, Level = level, ErrorType = type,
                                  Message = msg, RawLine = line, Format = LogFormat.Json };
        }
        catch { return null; }
    }
}


// ─── Analyzer ────────────────────────────────────────────────────────────────

/// <summary>High-level analysis operations over a collection of log entries.</summary>
public static class LogAnalyzer {
    /// <summary>
    /// Reads every line of <paramref name="filePath"/>, parses it, and yields
    /// only ERROR/WARNING entries. Throws FileNotFoundException with a clear
    /// message if the file is absent.
    /// </summary>
    public static IEnumerable<LogEntry> ParseFile(string filePath) {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"Log file not found: {filePath}", filePath);

        return File.ReadLines(filePath)
                   .Select(LogParser.ParseLine)
                   .OfType<LogEntry>();
    }

    /// <summary>
    /// Groups entries by ErrorType, computes count + first/last timestamps.
    /// Result sorted by count descending (most frequent first).
    /// </summary>
    public static List<ErrorFrequency> BuildFrequencyTable(IEnumerable<LogEntry> entries) =>
        entries
            .GroupBy(e => e.ErrorType)
            .Select(g => new ErrorFrequency {
                ErrorType       = g.Key,
                Count           = g.Count(),
                FirstOccurrence = g.Min(e => e.Timestamp),
                LastOccurrence  = g.Max(e => e.Timestamp)
            })
            .OrderByDescending(f => f.Count)
            .ThenBy(f => f.ErrorType)
            .ToList();

    /// <summary>
    /// Formats the frequency table as a Unicode box-drawing ASCII table
    /// suitable for console or text-file output.
    /// </summary>
    public static string FormatTable(List<ErrorFrequency> frequencies) {
        if (frequencies.Count == 0) return "No errors or warnings found in the log file.";

        const int tw = 22;   // error type column width
        const int cw = 7;    // count column width
        const int dw = 21;   // date column width

        string Rep(char c, int n) => new string(c, n);
        string Top = $"╔{Rep('═', tw+2)}╦{Rep('═', cw+2)}╦{Rep('═', dw+2)}╦{Rep('═', dw+2)}╗";
        string Mid = $"╠{Rep('═', tw+2)}╬{Rep('═', cw+2)}╬{Rep('═', dw+2)}╬{Rep('═', dw+2)}╣";
        string Bot = $"╚{Rep('═', tw+2)}╩{Rep('═', cw+2)}╩{Rep('═', dw+2)}╩{Rep('═', dw+2)}╝";
        string Row(string a, string b, string c, string d) =>
            $"║ {a.PadRight(tw)} ║ {b.PadRight(cw)} ║ {c.PadRight(dw)} ║ {d.PadRight(dw)} ║";

        var sb = new StringBuilder();
        sb.AppendLine(Top);
        sb.AppendLine(Row("Error Type", "Count", "First Occurrence", "Last Occurrence"));
        sb.AppendLine(Mid);

        foreach (var f in frequencies) {
            var type  = f.ErrorType.Length > tw ? f.ErrorType[..tw] : f.ErrorType;
            sb.AppendLine(Row(
                type,
                f.Count.ToString(),
                f.FirstOccurrence.ToString("yyyy-MM-dd HH:mm:ss"),
                f.LastOccurrence .ToString("yyyy-MM-dd HH:mm:ss")));
        }

        sb.AppendLine(Bot);
        var total = frequencies.Sum(f => f.Count);
        sb.AppendLine($"\nTotal: {frequencies.Count} distinct error type(s), {total} total occurrence(s)");
        return sb.ToString();
    }

    /// <summary>
    /// Writes the frequency table as a pretty-printed JSON report.
    /// Uses Utf8JsonWriter to avoid reflection-based serialization
    /// (disabled in .NET 10 file-based trimmed apps).
    /// </summary>
    public static void WriteJsonReport(List<ErrorFrequency> frequencies, string outputPath) {
        using var stream = new FileStream(outputPath, FileMode.Create, FileAccess.Write);
        using var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true });

        writer.WriteStartObject();
        writer.WriteString("generatedAt",      DateTime.UtcNow.ToString("o"));
        writer.WriteNumber("totalErrorTypes",  frequencies.Count);
        writer.WriteNumber("totalOccurrences", frequencies.Sum(f => f.Count));

        writer.WriteStartArray("errorFrequencies");
        foreach (var f in frequencies) {
            writer.WriteStartObject();
            writer.WriteString("errorType",       f.ErrorType);
            writer.WriteNumber("count",           f.Count);
            writer.WriteString("firstOccurrence", f.FirstOccurrence.ToString("o"));
            writer.WriteString("lastOccurrence",  f.LastOccurrence .ToString("o"));
            writer.WriteEndObject();
        }
        writer.WriteEndArray();

        writer.WriteEndObject();
        writer.Flush();
    }
}
