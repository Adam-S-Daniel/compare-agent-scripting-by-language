// LogAnalyzerCore.cs — Core logic for the log file analyzer.
// This file contains all classes and is shared between the test project
// (via <Compile Include>) and the standalone LogAnalyzer.cs file-based app.

using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace LogAnalyzer;

// Severity levels for log entries
public enum LogLevel
{
    Info,
    Warning,
    Error,
    Unknown
}

// Represents a single parsed log entry
public class LogEntry
{
    public DateTime Timestamp { get; set; }
    public LogLevel Level { get; set; }
    public string Source { get; set; } = "";
    public string Message { get; set; } = "";
    // error_type from JSON lines, or derived from source+message for syslog lines
    public string ErrorType { get; set; } = "";
}

// Represents one row in the frequency table: an error type with occurrence data
public class ErrorFrequency
{
    public string ErrorType { get; set; } = "";
    public int Count { get; set; }
    public DateTime FirstOccurrence { get; set; }
    public DateTime LastOccurrence { get; set; }
    public LogLevel Level { get; set; }
}

// Holds the complete analysis result
public class AnalysisResult
{
    public int TotalLines { get; set; }
    public int ErrorCount { get; set; }
    public int WarningCount { get; set; }
    public List<ErrorFrequency> FrequencyTable { get; set; } = new();
}

// Parses individual log lines in both syslog and JSON formats
public static class LogParser
{
    // Regex for syslog-style: "2024-01-15 08:23:01 LEVEL [Source] Message"
    // Allows extra spaces after the level (e.g. "INFO  " or "WARN  ")
    private static readonly Regex SyslogPattern = new(
        @"^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(INFO|WARN|WARNING|ERROR|DEBUG)\s+\[(\w+)\]\s+(.+)$",
        RegexOptions.Compiled);

    /// <summary>
    /// Parse a single log line. Tries JSON first (starts with '{'), then syslog format.
    /// Returns null if the line cannot be parsed.
    /// </summary>
    public static LogEntry? ParseLine(string? line)
    {
        if (string.IsNullOrWhiteSpace(line))
            return null;

        // Try JSON format first if line starts with '{'
        if (line.TrimStart().StartsWith('{'))
            return TryParseJson(line);

        // Otherwise try syslog format
        return TryParseSyslog(line);
    }

    /// <summary>
    /// Parse multiple lines and return all successfully parsed entries.
    /// </summary>
    public static List<LogEntry> ParseLines(IEnumerable<string> lines)
    {
        var entries = new List<LogEntry>();
        foreach (var line in lines)
        {
            var entry = ParseLine(line);
            if (entry != null)
                entries.Add(entry);
        }
        return entries;
    }

    private static LogEntry? TryParseSyslog(string line)
    {
        var match = SyslogPattern.Match(line);
        if (!match.Success)
            return null;

        var timestamp = DateTime.SpecifyKind(
            DateTime.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture), DateTimeKind.Utc);
        var level = ParseLevel(match.Groups[2].Value);
        var source = match.Groups[3].Value;
        var message = match.Groups[4].Value;

        return new LogEntry
        {
            Timestamp = timestamp,
            Level = level,
            Source = source,
            Message = message,
            // For syslog entries without explicit error_type, derive from source + first phrase
            ErrorType = DeriveErrorType(source, message)
        };
    }

    private static LogEntry? TryParseJson(string line)
    {
        try
        {
            var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;

            var timestampStr = root.GetProperty("timestamp").GetString() ?? "";
            var levelStr = root.GetProperty("level").GetString() ?? "";
            var source = root.GetProperty("source").GetString() ?? "";
            var message = root.GetProperty("message").GetString() ?? "";

            // error_type is optional in JSON lines
            var errorType = "";
            if (root.TryGetProperty("error_type", out var et))
                errorType = et.GetString() ?? "";

            var timestamp = DateTime.Parse(timestampStr, CultureInfo.InvariantCulture,
                DateTimeStyles.AdjustToUniversal);

            return new LogEntry
            {
                Timestamp = DateTime.SpecifyKind(timestamp, DateTimeKind.Utc),
                Level = ParseLevel(levelStr),
                Source = source,
                Message = message,
                ErrorType = string.IsNullOrEmpty(errorType) ? DeriveErrorType(source, message) : errorType
            };
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Map level strings (INFO, WARN, WARNING, ERROR) to the LogLevel enum.
    /// </summary>
    public static LogLevel ParseLevel(string level)
    {
        return level.ToUpperInvariant() switch
        {
            "ERROR" => LogLevel.Error,
            "WARN" => LogLevel.Warning,
            "WARNING" => LogLevel.Warning,
            "INFO" => LogLevel.Info,
            "DEBUG" => LogLevel.Info,
            _ => LogLevel.Unknown
        };
    }

    /// <summary>
    /// Derive an error type string from source and message when no explicit error_type is provided.
    /// Uses Source + first meaningful phrase of the message.
    /// </summary>
    public static string DeriveErrorType(string source, string message)
    {
        // Take the first phrase (up to first delimiter) as the error category
        var shortMsg = message.Split(new[] { " - ", ": ", " for " }, StringSplitOptions.None)[0].Trim();
        return $"{source}/{shortMsg}";
    }
}

// Filters log entries to only errors and warnings
public static class LogFilter
{
    public static List<LogEntry> FilterErrorsAndWarnings(List<LogEntry> entries)
    {
        return entries.Where(e => e.Level == LogLevel.Error || e.Level == LogLevel.Warning).ToList();
    }
}

// Builds frequency table from filtered log entries
public static class FrequencyAnalyzer
{
    /// <summary>
    /// Group entries by ErrorType and compute count, first and last occurrence.
    /// Results are sorted by count descending.
    /// </summary>
    public static List<ErrorFrequency> Analyze(List<LogEntry> entries)
    {
        return entries
            .GroupBy(e => e.ErrorType)
            .Select(g => new ErrorFrequency
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
    }
}

// Formats analysis results as a human-readable table
public static class TableFormatter
{
    public static string Format(AnalysisResult result)
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

        // Determine column widths
        var typeWidth = Math.Max("Error Type".Length,
            result.FrequencyTable.Max(f => f.ErrorType.Length));
        var countWidth = Math.Max("Count".Length,
            result.FrequencyTable.Max(f => f.Count.ToString().Length));
        var tsWidth = 19; // "yyyy-MM-dd HH:mm:ss"

        // Header
        var header = string.Format(
            $"{{0,-{typeWidth}}}  {{1,{countWidth}}}  {{2,-5}}  {{3,-{tsWidth}}}  {{4,-{tsWidth}}}",
            "Error Type", "Count", "Level", "First Occurrence", "Last Occurrence");
        sb.AppendLine(header);
        sb.AppendLine(new string('-', header.Length));

        // Rows
        foreach (var f in result.FrequencyTable)
        {
            var levelStr = f.Level == LogLevel.Error ? "ERROR" : "WARN";
            sb.AppendLine(string.Format(
                $"{{0,-{typeWidth}}}  {{1,{countWidth}}}  {{2,-5}}  {{3,-{tsWidth}}}  {{4,-{tsWidth}}}",
                f.ErrorType,
                f.Count,
                levelStr,
                f.FirstOccurrence.ToString("yyyy-MM-dd HH:mm:ss"),
                f.LastOccurrence.ToString("yyyy-MM-dd HH:mm:ss")));
        }

        return sb.ToString();
    }
}

// Serializes analysis results to JSON
public static class JsonOutputWriter
{
    public static string ToJson(AnalysisResult result)
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

        return JsonSerializer.Serialize(output, new JsonSerializerOptions
        {
            WriteIndented = true
        });
    }
}

// Orchestrates the full analysis pipeline
public static class LogAnalyzerEngine
{
    /// <summary>
    /// Run the complete analysis: parse lines, filter, analyze frequencies, return result.
    /// </summary>
    public static AnalysisResult Analyze(IEnumerable<string> lines)
    {
        var allLines = lines.ToList();
        var entries = LogParser.ParseLines(allLines);
        var filtered = LogFilter.FilterErrorsAndWarnings(entries);
        var frequency = FrequencyAnalyzer.Analyze(filtered);

        return new AnalysisResult
        {
            TotalLines = allLines.Count,
            ErrorCount = filtered.Count(e => e.Level == LogLevel.Error),
            WarningCount = filtered.Count(e => e.Level == LogLevel.Warning),
            FrequencyTable = frequency
        };
    }

    /// <summary>
    /// Analyze a log file by path. Returns the analysis result.
    /// Throws FileNotFoundException with a meaningful message if file doesn't exist.
    /// </summary>
    public static AnalysisResult AnalyzeFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"Log file not found: {filePath}", filePath);

        var lines = File.ReadAllLines(filePath);
        return Analyze(lines);
    }
}
