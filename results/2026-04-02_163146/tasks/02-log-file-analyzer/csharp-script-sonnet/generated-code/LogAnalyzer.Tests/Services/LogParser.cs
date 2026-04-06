// LogParser — parses individual log lines in syslog or JSON format.
//
// TDD progression:
//   RED:   Tests in LogParserTests.cs failed (LogParser didn't exist).
//   GREEN: Minimum implementation written here to make tests pass.
//   REFACTOR: Extracted helper methods for clarity.

using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace LogAnalyzer.Tests;

public class LogParser
{
    // Matches: "Jan 15 10:23:45 hostname appname[pid]: LEVEL: message"
    // Groups:  1=month/day/time  2=host  3=app  4=pid  5=level  6=message
    private static readonly Regex SyslogRegex = new(
        @"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+\S+\s+\S+\[\d+\]:\s+(ERROR|WARN(?:ING)?|INFO|DEBUG):\s+(.+)$",
        RegexOptions.Compiled);

    /// <summary>
    /// Attempts to parse a single log line.
    /// Returns null when the line cannot be recognised as syslog or JSON.
    /// </summary>
    public LogEntry? ParseLine(string line)
    {
        if (string.IsNullOrWhiteSpace(line))
            return null;

        // Try JSON first (lines that start with '{')
        if (line.TrimStart().StartsWith('{'))
            return TryParseJson(line);

        // Otherwise try syslog format
        return TryParseSyslog(line);
    }

    /// <summary>Parses all lines, skipping unrecognised ones.</summary>
    public IEnumerable<LogEntry> ParseLines(IEnumerable<string> lines)
    {
        foreach (var line in lines)
        {
            var entry = ParseLine(line);
            if (entry is not null)
                yield return entry;
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static LogEntry? TryParseSyslog(string line)
    {
        var match = SyslogRegex.Match(line);
        if (!match.Success)
            return null;

        var timestampStr = match.Groups[1].Value;   // "Jan 15 10:23:45"
        var level        = NormaliseLevel(match.Groups[2].Value);
        var message      = match.Groups[3].Value.Trim();

        // Parse timestamp — syslog omits the year; use current year as a sensible default.
        // Use InvariantCulture so abbreviated month names like "Jan" work on any locale.
        if (!DateTime.TryParse(
                timestampStr + " " + DateTime.UtcNow.Year,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AllowWhiteSpaces,
                out var ts))
            return null;

        // Extract error type: first word of the message before a space.
        // e.g. "NullReferenceException in UserService" → "NullReferenceException"
        var errorType = ExtractSyslogErrorType(message);

        return new LogEntry
        {
            Timestamp = ts,
            Level     = level,
            Message   = message,
            ErrorType = errorType,
            Format    = "syslog",
            RawLine   = line,
        };
    }

    private static LogEntry? TryParseJson(string line)
    {
        try
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;

            if (!root.TryGetProperty("level", out var lvlEl) ||
                !root.TryGetProperty("message", out var msgEl) ||
                !root.TryGetProperty("timestamp", out var tsEl))
                return null;

            var level   = NormaliseLevel(lvlEl.GetString() ?? string.Empty);
            var message = msgEl.GetString() ?? string.Empty;

            // RoundtripKind preserves the UTC marker ("Z") from ISO 8601 timestamps.
            if (!DateTime.TryParse(
                    tsEl.GetString(),
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.RoundtripKind,
                    out var ts))
                return null;

            // error_type is optional; fall back to the level when absent.
            var errorType = root.TryGetProperty("error_type", out var etEl)
                ? (etEl.GetString() ?? level)
                : level;

            return new LogEntry
            {
                Timestamp = ts,
                Level     = level,
                Message   = message,
                ErrorType = errorType,
                Format    = "json",
                RawLine   = line,
            };
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>Normalises log level strings ("WARNING" → "WARN").</summary>
    private static string NormaliseLevel(string raw) =>
        raw.ToUpperInvariant() switch
        {
            "WARNING" => "WARN",
            var v     => v,
        };

    /// <summary>
    /// Extracts the error type from a syslog message body.
    /// Uses the first token (split on whitespace) which typically is the exception
    /// or error class name.
    /// </summary>
    private static string ExtractSyslogErrorType(string message)
    {
        var firstWord = message.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
        return firstWord ?? message;
    }
}
