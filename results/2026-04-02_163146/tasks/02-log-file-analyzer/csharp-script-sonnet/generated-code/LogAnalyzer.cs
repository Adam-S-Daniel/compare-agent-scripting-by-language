// LogAnalyzer.cs — .NET 10 file-based app (run with: dotnet run LogAnalyzer.cs)
//
// Parses a mixed-format log file (syslog-style + JSON-structured lines),
// extracts error and warning entries, produces a frequency table with first/last
// occurrence timestamps, and writes both a human-readable table and a JSON report.
//
// Usage:
//   dotnet run LogAnalyzer.cs <input-log-file> [output-json-file]
//
// If output-json-file is omitted, it defaults to <input-log-file>.report.json

// ── .NET 10 file-based app: top-level statements below are the entry point ──

using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

// ── Entry point ──────────────────────────────────────────────────────────────

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: dotnet run LogAnalyzer.cs <log-file> [output-json]");
    Console.Error.WriteLine("  log-file    : path to mixed-format log file");
    Console.Error.WriteLine("  output-json : path for JSON report (default: <log-file>.report.json)");
    return 1;
}

var inputPath  = args[0];
var outputPath = args.Length >= 2 ? args[1] : inputPath + ".report.json";

if (!File.Exists(inputPath))
{
    Console.Error.WriteLine($"Error: file not found: {inputPath}");
    return 1;
}

Console.WriteLine($"Parsing log file: {inputPath}");

var lines   = File.ReadAllLines(inputPath);
var parser  = new AppLogParser();
var entries = parser.ParseLines(lines).ToList();

Console.WriteLine($"Parsed {entries.Count} valid log entries " +
                  $"({entries.Count(e => e.Level == "ERROR")} errors, " +
                  $"{entries.Count(e => e.Level == "WARN")} warnings, " +
                  $"{entries.Count(e => e.Level is "INFO" or "DEBUG")} info/debug)");

var rows  = AppFrequencyAnalyzer.Analyze(entries).ToList();
var table = AppReportGenerator.RenderTable(rows);

// Print human-readable table to console
Console.WriteLine();
Console.Write(table);

// Write JSON report
AppReportGenerator.WriteJsonFile(rows, outputPath);
Console.WriteLine($"JSON report written to: {outputPath}");

return 0;

// ── Models ───────────────────────────────────────────────────────────────────

/// <summary>Represents a single parsed log entry.</summary>
class AppLogEntry
{
    public DateTime Timestamp { get; init; }
    public string   Level     { get; init; } = string.Empty;
    public string   Message   { get; init; } = string.Empty;
    /// <summary>
    /// Error/warning category: from "error_type" in JSON, or first word of syslog message.
    /// </summary>
    public string   ErrorType { get; init; } = string.Empty;
    /// <summary>"syslog" or "json"</summary>
    public string   Format    { get; init; } = string.Empty;
}

/// <summary>One row in the frequency report.</summary>
class AppFrequencyRow
{
    public string   ErrorType       { get; init; } = string.Empty;
    public string   Level           { get; init; } = string.Empty;
    public int      Count           { get; init; }
    public DateTime FirstOccurrence { get; init; }
    public DateTime LastOccurrence  { get; init; }
}

// ── Parser ───────────────────────────────────────────────────────────────────

/// <summary>
/// Parses individual log lines in syslog or JSON format.
/// Unrecognised lines are silently skipped.
/// </summary>
class AppLogParser
{
    // Matches: "Jan 15 10:23:45 hostname app[pid]: LEVEL: message"
    private static readonly Regex SyslogRegex = new(
        @"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+\S+\s+\S+\[\d+\]:\s+(ERROR|WARN(?:ING)?|INFO|DEBUG):\s+(.+)$",
        RegexOptions.Compiled);

    public AppLogEntry? ParseLine(string line)
    {
        if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith('#'))
            return null;

        if (line.TrimStart().StartsWith('{'))
            return TryParseJson(line);

        return TryParseSyslog(line);
    }

    public IEnumerable<AppLogEntry> ParseLines(IEnumerable<string> lines)
    {
        foreach (var line in lines)
        {
            var entry = ParseLine(line);
            if (entry is not null) yield return entry;
        }
    }

    private static AppLogEntry? TryParseSyslog(string line)
    {
        var m = SyslogRegex.Match(line);
        if (!m.Success) return null;

        var tsStr   = m.Groups[1].Value;
        var level   = Normalise(m.Groups[2].Value);
        var message = m.Groups[3].Value.Trim();

        if (!DateTime.TryParse(
                tsStr + " " + DateTime.UtcNow.Year,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AllowWhiteSpaces,
                out var ts))
            return null;

        var firstWord = message.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? message;

        return new AppLogEntry
        {
            Timestamp = ts, Level = level, Message = message,
            ErrorType = firstWord, Format = "syslog",
        };
    }

    private static AppLogEntry? TryParseJson(string line)
    {
        try
        {
            using var doc  = JsonDocument.Parse(line);
            var root = doc.RootElement;

            if (!root.TryGetProperty("level",     out var lvlEl)  ||
                !root.TryGetProperty("message",   out var msgEl)  ||
                !root.TryGetProperty("timestamp", out var tsEl))
                return null;

            var level   = Normalise(lvlEl.GetString() ?? "");
            var message = msgEl.GetString() ?? "";

            if (!DateTime.TryParse(
                    tsEl.GetString(),
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.RoundtripKind,
                    out var ts)) return null;

            var errorType = root.TryGetProperty("error_type", out var etEl)
                ? (etEl.GetString() ?? level)
                : level;

            return new AppLogEntry
            {
                Timestamp = ts, Level = level, Message = message,
                ErrorType = errorType, Format = "json",
            };
        }
        catch (JsonException) { return null; }
    }

    private static string Normalise(string raw) =>
        raw.ToUpperInvariant() == "WARNING" ? "WARN" : raw.ToUpperInvariant();
}

// ── Frequency analyzer ───────────────────────────────────────────────────────

static class AppFrequencyAnalyzer
{
    private static readonly HashSet<string> Included =
        new(StringComparer.OrdinalIgnoreCase) { "ERROR", "WARN" };

    public static IEnumerable<AppFrequencyRow> Analyze(IEnumerable<AppLogEntry> entries) =>
        entries
            .Where(e => Included.Contains(e.Level))
            .GroupBy(e => (e.ErrorType, e.Level))
            .Select(g => new AppFrequencyRow
            {
                ErrorType       = g.Key.ErrorType,
                Level           = g.Key.Level,
                Count           = g.Count(),
                FirstOccurrence = g.Min(e => e.Timestamp),
                LastOccurrence  = g.Max(e => e.Timestamp),
            })
            .OrderByDescending(r => r.Count)
            .ThenBy(r => r.ErrorType);
}

// ── Report generator ─────────────────────────────────────────────────────────

static class AppReportGenerator
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented        = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters           = { new JsonStringEnumConverter() },
    };

    public static string RenderTable(IEnumerable<AppFrequencyRow> rows)
    {
        var list = rows.ToList();
        if (list.Count == 0) return "No errors or warnings found in the log file.\n";

        string Fmt(DateTime dt) => dt.ToString("yyyy-MM-dd HH:mm:ss");

        var headers  = new[] { "Error Type", "Level", "Count", "First Seen", "Last Seen" };
        var dataRows = list.Select(r => new[]
        {
            r.ErrorType, r.Level, r.Count.ToString(),
            Fmt(r.FirstOccurrence), Fmt(r.LastOccurrence),
        }).ToList();

        var widths = headers
            .Select((h, i) => Math.Max(h.Length, dataRows.Max(row => row[i].Length)))
            .ToArray();

        var sb = new StringBuilder();
        sb.AppendLine(Sep(widths));
        sb.AppendLine(Row(headers, widths));
        sb.AppendLine(Sep(widths));
        foreach (var r in dataRows) sb.AppendLine(Row(r, widths));
        sb.AppendLine(Sep(widths));
        sb.AppendLine($"Total: {list.Count} distinct type(s), {list.Sum(r => r.Count)} occurrence(s).");
        return sb.ToString();
    }

    public static string ToJson(IEnumerable<AppFrequencyRow> rows) =>
        JsonSerializer.Serialize(rows.ToList(), JsonOpts);

    public static void WriteJsonFile(IEnumerable<AppFrequencyRow> rows, string path)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
        File.WriteAllText(path, ToJson(rows));
    }

    private static string Sep(int[] widths) =>
        "+" + string.Join("+", widths.Select(w => new string('-', w + 2))) + "+";

    private static string Row(string[] cells, int[] widths) =>
        "|" + string.Join("|", cells.Select((c, i) => " " + c.PadRight(widths[i]) + " ")) + "|";
}
