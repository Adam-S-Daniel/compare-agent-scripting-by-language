// LogAnalyzer.cs — .NET 10 file-based app for analyzing log files.
// Run with: dotnet run LogAnalyzer.cs -- <logfile> [--json <output.json>]
//
// Parses mixed-format log files (syslog-style and JSON-structured lines),
// extracts errors and warnings, produces a frequency table of error types
// with first/last occurrence timestamps, and outputs results as a
// human-readable table and optionally a JSON file.

using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

// ─── Entry Point ───────────────────────────────────────────────────────────

if (args.Length == 0)
{
    Console.Error.WriteLine("Usage: dotnet run LogAnalyzer.cs -- <logfile> [--json <output.json>]");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Arguments:");
    Console.Error.WriteLine("  <logfile>              Path to the log file to analyze");
    Console.Error.WriteLine("  --json <output.json>   Optional: write analysis results to a JSON file");
    return 1;
}

var logFilePath = args[0];
string? jsonOutputPath = null;

// Parse --json flag
for (int i = 1; i < args.Length; i++)
{
    if (args[i] == "--json" && i + 1 < args.Length)
    {
        jsonOutputPath = args[i + 1];
        i++;
    }
}

try
{
    // Run the analysis pipeline
    var result = LAEngine.AnalyzeFile(logFilePath);

    // Output human-readable table to stdout
    Console.Write(LATableFormatter.Format(result));

    // Optionally write JSON output
    if (jsonOutputPath != null)
    {
        var json = LAJsonOutput.ToJson(result);
        File.WriteAllText(jsonOutputPath, json);
        Console.WriteLine();
        Console.WriteLine($"JSON output written to: {jsonOutputPath}");
    }

    return 0;
}
catch (FileNotFoundException ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    return 2;
}

// ─── Types ─────────────────────────────────────────────────────────────────

enum LALogLevel { Info, Warning, Error, Unknown }

class LALogEntry
{
    public DateTime Timestamp { get; set; }
    public LALogLevel Level { get; set; }
    public string Source { get; set; } = "";
    public string Message { get; set; } = "";
    public string ErrorType { get; set; } = "";
}

class LAErrorFrequency
{
    public string ErrorType { get; set; } = "";
    public int Count { get; set; }
    public DateTime FirstOccurrence { get; set; }
    public DateTime LastOccurrence { get; set; }
    public LALogLevel Level { get; set; }
}

class LAAnalysisResult
{
    public int TotalLines { get; set; }
    public int ErrorCount { get; set; }
    public int WarningCount { get; set; }
    public List<LAErrorFrequency> FrequencyTable { get; set; } = new();
}

// ─── Parser ────────────────────────────────────────────────────────────────

static class LAParser
{
    static readonly Regex SyslogPattern = new(
        @"^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(INFO|WARN|WARNING|ERROR|DEBUG)\s+\[(\w+)\]\s+(.+)$",
        RegexOptions.Compiled);

    public static LALogEntry? ParseLine(string? line)
    {
        if (string.IsNullOrWhiteSpace(line)) return null;
        return line.TrimStart().StartsWith('{') ? TryParseJson(line) : TryParseSyslog(line);
    }

    public static List<LALogEntry> ParseLines(IEnumerable<string> lines)
    {
        var entries = new List<LALogEntry>();
        foreach (var line in lines)
        {
            var entry = ParseLine(line);
            if (entry != null) entries.Add(entry);
        }
        return entries;
    }

    static LALogEntry? TryParseSyslog(string line)
    {
        var m = SyslogPattern.Match(line);
        if (!m.Success) return null;
        var ts = DateTime.SpecifyKind(DateTime.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture), DateTimeKind.Utc);
        var source = m.Groups[3].Value;
        var msg = m.Groups[4].Value;
        return new LALogEntry
        {
            Timestamp = ts,
            Level = ToLevel(m.Groups[2].Value),
            Source = source,
            Message = msg,
            ErrorType = DeriveType(source, msg)
        };
    }

    static LALogEntry? TryParseJson(string line)
    {
        try
        {
            var doc = JsonDocument.Parse(line);
            var r = doc.RootElement;
            var ts = DateTime.Parse(r.GetProperty("timestamp").GetString()!, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal);
            var source = r.GetProperty("source").GetString() ?? "";
            var msg = r.GetProperty("message").GetString() ?? "";
            var et = r.TryGetProperty("error_type", out var etv) ? etv.GetString() ?? "" : "";
            return new LALogEntry
            {
                Timestamp = DateTime.SpecifyKind(ts, DateTimeKind.Utc),
                Level = ToLevel(r.GetProperty("level").GetString() ?? ""),
                Source = source,
                Message = msg,
                ErrorType = string.IsNullOrEmpty(et) ? DeriveType(source, msg) : et
            };
        }
        catch { return null; }
    }

    static LALogLevel ToLevel(string s) => s.ToUpperInvariant() switch
    {
        "ERROR" => LALogLevel.Error,
        "WARN" or "WARNING" => LALogLevel.Warning,
        "INFO" or "DEBUG" => LALogLevel.Info,
        _ => LALogLevel.Unknown
    };

    static string DeriveType(string source, string msg)
    {
        var shortMsg = msg.Split(new[] { " - ", ": ", " for " }, StringSplitOptions.None)[0].Trim();
        return $"{source}/{shortMsg}";
    }
}

// ─── Engine ────────────────────────────────────────────────────────────────

static class LAEngine
{
    public static LAAnalysisResult AnalyzeFile(string path)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException($"Log file not found: {path}", path);
        return Analyze(File.ReadAllLines(path));
    }

    public static LAAnalysisResult Analyze(IEnumerable<string> lines)
    {
        var all = lines.ToList();
        var entries = LAParser.ParseLines(all);
        var filtered = entries.Where(e => e.Level is LALogLevel.Error or LALogLevel.Warning).ToList();
        var freq = filtered.GroupBy(e => e.ErrorType)
            .Select(g => new LAErrorFrequency
            {
                ErrorType = g.Key,
                Count = g.Count(),
                FirstOccurrence = g.Min(e => e.Timestamp),
                LastOccurrence = g.Max(e => e.Timestamp),
                Level = g.First().Level
            })
            .OrderByDescending(f => f.Count)
            .ThenBy(f => f.FirstOccurrence)
            .ToList();

        return new LAAnalysisResult
        {
            TotalLines = all.Count,
            ErrorCount = filtered.Count(e => e.Level == LALogLevel.Error),
            WarningCount = filtered.Count(e => e.Level == LALogLevel.Warning),
            FrequencyTable = freq
        };
    }
}

// ─── Formatters ────────────────────────────────────────────────────────────

static class LATableFormatter
{
    public static string Format(LAAnalysisResult result)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine("=== Log Analysis Report ===");
        sb.AppendLine();
        sb.AppendLine($"Total lines parsed:  {result.TotalLines}");
        sb.AppendLine($"Errors found:        {result.ErrorCount}");
        sb.AppendLine($"Warnings found:      {result.WarningCount}");
        sb.AppendLine();

        if (result.FrequencyTable.Count == 0)
        {
            sb.AppendLine("No errors or warnings found.");
            return sb.ToString();
        }

        var tw = Math.Max("Error Type".Length, result.FrequencyTable.Max(f => f.ErrorType.Length));
        var cw = Math.Max("Count".Length, result.FrequencyTable.Max(f => f.Count.ToString().Length));
        var tsw = 19;

        var hdr = string.Format($"{{0,-{tw}}}  {{1,{cw}}}  {{2,-5}}  {{3,-{tsw}}}  {{4,-{tsw}}}",
            "Error Type", "Count", "Level", "First Occurrence", "Last Occurrence");
        sb.AppendLine(hdr);
        sb.AppendLine(new string('-', hdr.Length));

        foreach (var f in result.FrequencyTable)
        {
            sb.AppendLine(string.Format($"{{0,-{tw}}}  {{1,{cw}}}  {{2,-5}}  {{3,-{tsw}}}  {{4,-{tsw}}}",
                f.ErrorType, f.Count,
                f.Level == LALogLevel.Error ? "ERROR" : "WARN",
                f.FirstOccurrence.ToString("yyyy-MM-dd HH:mm:ss"),
                f.LastOccurrence.ToString("yyyy-MM-dd HH:mm:ss")));
        }
        return sb.ToString();
    }
}

static class LAJsonOutput
{
    public static string ToJson(LAAnalysisResult result)
    {
        var output = new
        {
            summary = new
            {
                total_lines = result.TotalLines,
                error_count = result.ErrorCount,
                warning_count = result.WarningCount
            },
            frequency_table = result.FrequencyTable.Select(f => new
            {
                error_type = f.ErrorType,
                count = f.Count,
                level = f.Level.ToString().ToLowerInvariant(),
                first_occurrence = f.FirstOccurrence.ToString("yyyy-MM-ddTHH:mm:ssZ"),
                last_occurrence = f.LastOccurrence.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }).ToArray()
        };
        return JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true });
    }
}
