// tests.cs — Log File Analyzer: TDD Test Suite
// Run: dotnet run tests.cs
//
// TDD Methodology demonstrated via this file:
//   RED   → Each test block was written FIRST, before any implementation existed.
//           The file fails to compile until the referenced types are added below.
//   GREEN → Minimal implementation added below each test group to make it pass.
//   REFACTOR → Implementation cleaned up while tests remain green.
//
// Usage: dotnet run tests.cs

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

// ============================================================
// MINIMAL TEST FRAMEWORK
// ============================================================
int _passed = 0, _failed = 0;

void Pass(string msg) {
    Console.ForegroundColor = ConsoleColor.Green;
    Console.Write("  ✓ ");
    Console.ResetColor();
    Console.WriteLine(msg);
    _passed++;
}

void Fail(string msg, string? detail = null) {
    Console.ForegroundColor = ConsoleColor.Red;
    Console.Write("  ✗ ");
    Console.ResetColor();
    Console.WriteLine(msg);
    if (detail != null) Console.WriteLine($"    → {detail}");
    _failed++;
}

void AssertTrue(bool cond, string msg, string? detail = null) {
    if (cond) Pass(msg); else Fail(msg, detail);
}
void AssertFalse(bool cond, string msg) => AssertTrue(!cond, msg);
void AssertEqual<T>(T? expected, T? actual, string msg) {
    if (EqualityComparer<T>.Default.Equals(expected, actual))
        Pass(msg);
    else
        Fail(msg, $"expected '{expected}', got '{actual}'");
}
void AssertNull(object? obj, string msg) =>
    AssertTrue(obj == null, msg, $"expected null, got '{obj}'");
void AssertNotNull(object? obj, string msg) =>
    AssertTrue(obj != null, msg, "expected non-null, got null");

void RunSuite(string name, Action suite) {
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.WriteLine($"\n══ {name} ══");
    Console.ResetColor();
    suite();
}

// ============================================================
// TEST FIXTURES
// (Represent the two log formats the parser must handle)
// ============================================================
const string SyslogError    = "Apr  7 14:23:01 myserver myapp[1234]: ERROR OutOfMemory: Cannot allocate 4096 bytes";
const string SyslogWarn     = "Apr  7 14:25:30 myserver myapp[1234]: WARNING HighMemory: Memory usage at 90%";
const string SyslogWarnLong = "Apr 17 09:05:00 myserver myapp[1234]: WARNING SlowDisk: Write latency at 200ms";
const string SyslogInfo     = "Apr  7 14:20:00 myserver myapp[1234]: INFO Service started successfully";
const string JsonError      = """{"timestamp":"2024-04-07T14:23:01Z","level":"ERROR","type":"DatabaseError","message":"Connection timeout"}""";
const string JsonWarn       = """{"timestamp":"2024-04-07T09:45:00Z","level":"WARNING","type":"SlowQuery","message":"Query took 5000ms"}""";
const string JsonInfo       = """{"timestamp":"2024-04-07T14:23:01Z","level":"INFO","type":"Startup","message":"Service started"}""";
const string MalformedLine  = "this is not a valid log line at all!!!";
const string EmptyLine      = "";
const string JsonNoLevel    = """{"timestamp":"2024-04-07T14:23:01Z","type":"Something","message":"No level field"}""";

// ============================================================
// RED → GREEN: Suite 1 — LogEntry Data Model
// TDD: Written before LogEntry/LogFormat existed.
//      The file would not compile until those types are defined (see below).
// ============================================================
RunSuite("Suite 1: LogEntry Data Model", () => {
    var entry = new LogEntry {
        Timestamp = new DateTime(2024, 4, 7, 14, 23, 1, DateTimeKind.Utc),
        Level     = "ERROR",
        ErrorType = "OutOfMemory",
        Message   = "Cannot allocate 4096 bytes",
        RawLine   = SyslogError,
        Format    = LogFormat.Syslog
    };

    AssertEqual(2024, entry.Timestamp.Year,      "Timestamp year is 2024");
    AssertEqual(14,   entry.Timestamp.Hour,      "Timestamp hour is 14");
    AssertEqual(23,   entry.Timestamp.Minute,    "Timestamp minute is 23");
    AssertEqual("ERROR",       entry.Level,      "Level is ERROR");
    AssertEqual("OutOfMemory", entry.ErrorType,  "ErrorType is OutOfMemory");
    AssertEqual(LogFormat.Syslog, entry.Format,  "Format is Syslog");
    AssertTrue(entry.IsErrorOrWarning,           "ERROR entry IsErrorOrWarning = true");

    var warnEntry = new LogEntry { Level = "WARNING", ErrorType = "x", Message = "", RawLine = "", Format = LogFormat.Syslog };
    AssertTrue(warnEntry.IsErrorOrWarning, "WARNING entry IsErrorOrWarning = true");

    var infoEntry = new LogEntry { Level = "INFO", ErrorType = "x", Message = "", RawLine = "", Format = LogFormat.Syslog };
    AssertFalse(infoEntry.IsErrorOrWarning, "INFO entry IsErrorOrWarning = false");
});

// ============================================================
// RED → GREEN: Suite 2 — Syslog Line Parsing
// TDD: Written before LogParser existed. References LogParser.ParseLine,
//      which didn't compile until the class was added below.
// ============================================================
RunSuite("Suite 2: Syslog Line Parsing", () => {
    // Happy path: ERROR
    var errorEntry = LogParser.ParseLine(SyslogError);
    AssertNotNull(errorEntry,                                      "Parses syslog ERROR line → non-null");
    AssertEqual("ERROR",       errorEntry?.Level,                  "Extracts ERROR level");
    AssertEqual("OutOfMemory", errorEntry?.ErrorType,              "Extracts OutOfMemory type");
    AssertTrue(errorEntry?.Message.Contains("Cannot allocate") == true, "Extracts message body");
    AssertEqual(LogFormat.Syslog, errorEntry?.Format,              "Identifies syslog format");
    AssertEqual(14, errorEntry?.Timestamp.Hour,                    "Extracts hour 14");
    AssertEqual(23, errorEntry?.Timestamp.Minute,                  "Extracts minute 23");
    AssertEqual(1,  errorEntry?.Timestamp.Second,                  "Extracts second 01");

    // Happy path: WARNING
    var warnEntry = LogParser.ParseLine(SyslogWarn);
    AssertNotNull(warnEntry,                               "Parses syslog WARNING line → non-null");
    AssertEqual("WARNING",    warnEntry?.Level,            "Extracts WARNING level");
    AssertEqual("HighMemory", warnEntry?.ErrorType,        "Extracts HighMemory type");

    // Two-digit day
    var longDayEntry = LogParser.ParseLine(SyslogWarnLong);
    AssertNotNull(longDayEntry,                            "Parses syslog line with two-digit day");
    AssertEqual(17, longDayEntry?.Timestamp.Day,           "Two-digit day 17 parsed correctly");

    // INFO lines → null (only errors/warnings are interesting)
    var infoEntry = LogParser.ParseLine(SyslogInfo);
    AssertNull(infoEntry, "Returns null for INFO syslog line");
});

// ============================================================
// RED → GREEN: Suite 3 — JSON Line Parsing
// TDD: Written before JSON branch of ParseLine existed.
// ============================================================
RunSuite("Suite 3: JSON Line Parsing", () => {
    var jsonEntry = LogParser.ParseLine(JsonError);
    AssertNotNull(jsonEntry,                                          "Parses JSON ERROR line → non-null");
    AssertEqual("ERROR",         jsonEntry?.Level,                    "Extracts ERROR level from JSON");
    AssertEqual("DatabaseError", jsonEntry?.ErrorType,                "Extracts DatabaseError type from JSON");
    AssertTrue(jsonEntry?.Message.Contains("Connection timeout") == true, "Extracts message from JSON");
    AssertEqual(LogFormat.Json,  jsonEntry?.Format,                   "Identifies JSON format");
    AssertEqual(2024,            jsonEntry?.Timestamp.Year,           "Extracts year 2024 from JSON timestamp");
    AssertEqual(14,              jsonEntry?.Timestamp.Hour,           "Extracts hour 14 from JSON timestamp");

    var warnEntry = LogParser.ParseLine(JsonWarn);
    AssertNotNull(warnEntry,                          "Parses JSON WARNING line → non-null");
    AssertEqual("WARNING",   warnEntry?.Level,        "Extracts WARNING level from JSON");
    AssertEqual("SlowQuery", warnEntry?.ErrorType,    "Extracts SlowQuery type from JSON");

    // INFO → null
    AssertNull(LogParser.ParseLine(JsonInfo), "Returns null for JSON INFO line");
});

// ============================================================
// RED → GREEN: Suite 4 — Edge Cases & Error Handling
// TDD: Written to guard against bad input; LogParser had to be
//      hardened to return null safely instead of throwing.
// ============================================================
RunSuite("Suite 4: Edge Cases", () => {
    AssertNull(LogParser.ParseLine(MalformedLine),  "Returns null for completely malformed line");
    AssertNull(LogParser.ParseLine(EmptyLine),      "Returns null for empty string");
    AssertNull(LogParser.ParseLine("   "),          "Returns null for whitespace-only string");
    AssertNull(LogParser.ParseLine(JsonNoLevel),    "Returns null for JSON missing 'level' field");
    AssertNull(LogParser.ParseLine("{bad json!!!"), "Returns null for invalid JSON");
});

// ============================================================
// RED → GREEN: Suite 5 — Frequency Table Building
// TDD: Written before LogAnalyzer.BuildFrequencyTable existed.
// ============================================================
RunSuite("Suite 5: Frequency Table Building", () => {
    var entries = new List<LogEntry> {
        new() { Timestamp = new DateTime(2024, 4, 7,  8,  0, 0), Level = "ERROR",   ErrorType = "OutOfMemory",  Message = "m", RawLine = "", Format = LogFormat.Syslog },
        new() { Timestamp = new DateTime(2024, 4, 7,  9,  0, 0), Level = "ERROR",   ErrorType = "OutOfMemory",  Message = "m", RawLine = "", Format = LogFormat.Syslog },
        new() { Timestamp = new DateTime(2024, 4, 7, 10,  0, 0), Level = "ERROR",   ErrorType = "OutOfMemory",  Message = "m", RawLine = "", Format = LogFormat.Syslog },
        new() { Timestamp = new DateTime(2024, 4, 7,  8, 30, 0), Level = "ERROR",   ErrorType = "DatabaseError",Message = "m", RawLine = "", Format = LogFormat.Json   },
        new() { Timestamp = new DateTime(2024, 4, 7,  9, 30, 0), Level = "WARNING", ErrorType = "HighMemory",   Message = "m", RawLine = "", Format = LogFormat.Syslog },
    };

    var table = LogAnalyzer.BuildFrequencyTable(entries);
    AssertEqual(3, table.Count, "Table has 3 distinct error types");

    var oom = table.FirstOrDefault(f => f.ErrorType == "OutOfMemory");
    AssertNotNull(oom,                                                        "OutOfMemory entry exists");
    AssertEqual(3,                          oom?.Count ?? 0,                 "OutOfMemory count = 3");
    AssertEqual(new DateTime(2024, 4, 7, 8,  0, 0), oom?.FirstOccurrence ?? default, "OutOfMemory first = 08:00");
    AssertEqual(new DateTime(2024, 4, 7, 10, 0, 0), oom?.LastOccurrence  ?? default, "OutOfMemory last  = 10:00");

    // Sorted by count descending
    AssertTrue(table[0].Count >= table[1].Count, "Table sorted by count (descending)");
    AssertEqual("OutOfMemory", table[0].ErrorType, "OutOfMemory is first (highest count)");

    // Empty input → empty table (not a crash)
    var emptyTable = LogAnalyzer.BuildFrequencyTable(new List<LogEntry>());
    AssertEqual(0, emptyTable.Count, "Empty input → empty table");
});

// ============================================================
// RED → GREEN: Suite 6 — File Parsing Integration
// TDD: Written before ParseFile existed; uses a temp file for isolation.
// ============================================================
RunSuite("Suite 6: Log File Parsing (Integration)", () => {
    var tempLog = Path.GetTempFileName();
    try {
        File.WriteAllLines(tempLog, new[] {
            "Apr  7 08:00:00 host app[1]: INFO Service started",
            "Apr  7 08:15:00 host app[1]: ERROR OutOfMemory: Cannot allocate memory",
            """{"timestamp":"2024-04-07T09:00:00Z","level":"ERROR","type":"DatabaseError","message":"Conn failed"}""",
            "Apr  7 10:00:00 host app[1]: WARNING HighMemory: Memory at 90%",
            MalformedLine,
            EmptyLine,
            "Apr  7 11:00:00 host app[1]: INFO Daily backup",
        });

        var entries = LogAnalyzer.ParseFile(tempLog).ToList();
        AssertEqual(3, entries.Count, "Parsed 3 error/warning entries (INFO and malformed filtered)");
        AssertTrue(entries.Any(e => e.ErrorType == "OutOfMemory"),   "OutOfMemory entry present");
        AssertTrue(entries.Any(e => e.ErrorType == "DatabaseError"), "DatabaseError entry present");
        AssertTrue(entries.Any(e => e.ErrorType == "HighMemory"),    "HighMemory warning present");
    } finally {
        File.Delete(tempLog);
    }

    // Missing file → meaningful exception
    try {
        LogAnalyzer.ParseFile("/nonexistent/path/missing.log").ToList();
        Fail("Should throw FileNotFoundException for missing file");
    } catch (FileNotFoundException ex) {
        Pass($"Throws FileNotFoundException: {ex.Message.Split('\n')[0]}");
    }
});

// ============================================================
// RED → GREEN: Suite 7 — Human-Readable Table Formatting
// TDD: Written before FormatTable existed.
// ============================================================
RunSuite("Suite 7: Human-Readable Table Formatting", () => {
    var frequencies = new List<ErrorFrequency> {
        new() { ErrorType = "OutOfMemory",  Count = 5, FirstOccurrence = new DateTime(2024, 4, 7, 8, 0, 0), LastOccurrence = new DateTime(2024, 4, 7, 17, 0, 0) },
        new() { ErrorType = "DatabaseError",Count = 2, FirstOccurrence = new DateTime(2024, 4, 7, 9, 0, 0), LastOccurrence = new DateTime(2024, 4, 7, 12, 0, 0) },
    };

    var table = LogAnalyzer.FormatTable(frequencies);
    AssertTrue(table.Contains("OutOfMemory"),   "Table contains 'OutOfMemory'");
    AssertTrue(table.Contains("DatabaseError"), "Table contains 'DatabaseError'");
    AssertTrue(table.Contains("5"),             "Table contains count 5");
    AssertTrue(table.Contains("2024-04-07"),    "Table contains formatted date 2024-04-07");

    // Empty → helpful message instead of crash
    var emptyTable = LogAnalyzer.FormatTable(new List<ErrorFrequency>());
    AssertTrue(emptyTable.Contains("No errors"), "Empty table shows 'No errors' message");
});

// ============================================================
// RED → GREEN: Suite 8 — JSON Report Output
// TDD: Written before WriteJsonReport existed.
// ============================================================
RunSuite("Suite 8: JSON Report Output", () => {
    var frequencies = new List<ErrorFrequency> {
        new() { ErrorType = "OutOfMemory", Count = 3,
                FirstOccurrence = new DateTime(2024, 4, 7, 8, 0, 0),
                LastOccurrence  = new DateTime(2024, 4, 7, 16, 0, 0) },
    };

    var tempJson = Path.GetTempFileName();
    try {
        LogAnalyzer.WriteJsonReport(frequencies, tempJson);
        AssertTrue(File.Exists(tempJson), "JSON report file was created");

        var content = File.ReadAllText(tempJson);
        using var doc  = JsonDocument.Parse(content);
        var root = doc.RootElement;

        AssertTrue(root.TryGetProperty("generatedAt", out _),       "JSON has 'generatedAt'");
        AssertTrue(root.TryGetProperty("totalErrorTypes", out var te),"JSON has 'totalErrorTypes'");
        AssertEqual(1, te.GetInt32(),                                "totalErrorTypes = 1");
        AssertTrue(root.TryGetProperty("totalOccurrences", out var to),"JSON has 'totalOccurrences'");
        AssertEqual(3, to.GetInt32(),                                "totalOccurrences = 3");
        AssertTrue(root.TryGetProperty("errorFrequencies", out var fa),"JSON has 'errorFrequencies'");
        AssertEqual(1, fa.GetArrayLength(),                          "errorFrequencies has 1 entry");

        var first = fa[0];
        AssertEqual("OutOfMemory", first.GetProperty("errorType").GetString(), "entry.errorType = OutOfMemory");
        AssertEqual(3,             first.GetProperty("count").GetInt32(),      "entry.count = 3");
        AssertTrue(first.TryGetProperty("firstOccurrence", out _), "entry has 'firstOccurrence'");
        AssertTrue(first.TryGetProperty("lastOccurrence",  out _), "entry has 'lastOccurrence'");
    } finally {
        File.Delete(tempJson);
    }
});

// ============================================================
// SUMMARY
// ============================================================
Console.WriteLine();
Console.ForegroundColor = _failed == 0 ? ConsoleColor.Green : ConsoleColor.Red;
Console.WriteLine($"══ Results: {_passed} passed, {_failed} failed ══");
Console.ResetColor();
if (_failed > 0) Environment.Exit(1);


// ====================================================================
//
//  IMPLEMENTATION
//  (In TDD, each class below was added incrementally to make the
//   test suites above go from RED → GREEN)
//
// ====================================================================

// ── GREEN for Suite 1 ─────────────────────────────────────────────
// Added LogFormat enum and LogEntry record to satisfy the model tests.

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

    /// <summary>True when Level is ERROR or WARNING (the entries we care about).</summary>
    public bool IsErrorOrWarning => Level is "ERROR" or "WARNING";
}

// ── GREEN for Suites 2, 3, 4 ──────────────────────────────────────
// Added LogParser with two format branches (syslog + JSON) and null-safe
// handling of every bad-input case exercised by Suite 4.

/// <summary>
/// Parses individual log lines. Returns null for INFO/DEBUG lines,
/// unrecognised formats, or malformed input — never throws.
/// </summary>
public static class LogParser {
    // Syslog pattern: "Apr  7 14:23:01 hostname process[pid]: LEVEL TYPE: message"
    // Captures: (1) month, (2) day, (3) time, (4) level, (5) error-type, (6) message
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

    // ── Syslog branch ────────────────────────────────────────────
    private static LogEntry? ParseSyslogLine(string line) {
        var m = SyslogRe.Match(line);
        if (!m.Success) return null;

        var month  = m.Groups[1].Value;
        var day    = int.Parse(m.Groups[2].Value);
        var time   = m.Groups[3].Value;
        var level  = m.Groups[4].Value;      // already ERROR or WARNING (from regex)
        var type   = m.Groups[5].Value;
        var msg    = m.Groups[6].Value;

        // Syslog doesn't include a year — assume the current year.
        // Pad day to 2 digits so ParseExact can use "dd".
        var year    = DateTime.Now.Year;
        var dateStr = $"{month} {day:D2} {time} {year}";
        DateTime.TryParseExact(dateStr, "MMM dd HH:mm:ss yyyy",
            CultureInfo.InvariantCulture, DateTimeStyles.None, out var ts);

        return new LogEntry { Timestamp = ts, Level = level, ErrorType = type,
                              Message = msg, RawLine = line, Format = LogFormat.Syslog };
    }

    // ── JSON branch ───────────────────────────────────────────────
    private static LogEntry? ParseJsonLine(string line) {
        try {
            using var doc  = JsonDocument.Parse(line);
            var root = doc.RootElement;

            // "level" is required and must be ERROR or WARNING
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
        catch { return null; }   // malformed JSON → null, never throws
    }
}

// ── GREEN for Suites 5, 6, 7, 8 ───────────────────────────────────
// Added ErrorFrequency record and LogAnalyzer with all analysis methods.

/// <summary>Aggregated statistics for one error/warning type.</summary>
public record ErrorFrequency {
    public string   ErrorType       { get; init; } = "";
    public int      Count           { get; init; }
    public DateTime FirstOccurrence { get; init; }
    public DateTime LastOccurrence  { get; init; }
}

/// <summary>High-level analysis operations over a collection of log entries.</summary>
public static class LogAnalyzer {
    /// <summary>
    /// Reads every line of <paramref name="filePath"/>, parses it, and yields
    /// only the ERROR/WARNING entries. Throws FileNotFoundException with a clear
    /// message if the file is absent.
    /// </summary>
    public static IEnumerable<LogEntry> ParseFile(string filePath) {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"Log file not found: {filePath}", filePath);

        return File.ReadLines(filePath)
                   .Select(LogParser.ParseLine)
                   .OfType<LogEntry>();   // OfType<> filters out nulls
    }

    /// <summary>
    /// Groups entries by ErrorType and computes count plus first/last timestamps.
    /// Result is sorted by count descending (most frequent first).
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

        // Column widths
        const int tw = 22;   // error type
        const int cw = 7;    // count
        const int dw = 21;   // date/time

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
            var count = f.Count.ToString();
            var first = f.FirstOccurrence.ToString("yyyy-MM-dd HH:mm:ss");
            var last  = f.LastOccurrence .ToString("yyyy-MM-dd HH:mm:ss");
            sb.AppendLine(Row(type, count, first, last));
        }

        sb.AppendLine(Bot);
        var total = frequencies.Sum(f => f.Count);
        sb.AppendLine($"\nTotal: {frequencies.Count} distinct error type(s), {total} total occurrence(s)");
        return sb.ToString();
    }

    /// <summary>
    /// Serialises the frequency table as an indented JSON report and writes it
    /// to <paramref name="outputPath"/>.
    /// Uses Utf8JsonWriter directly to avoid reflection-based serialization,
    /// which is disabled in .NET 10 file-based (trimmed) apps.
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
