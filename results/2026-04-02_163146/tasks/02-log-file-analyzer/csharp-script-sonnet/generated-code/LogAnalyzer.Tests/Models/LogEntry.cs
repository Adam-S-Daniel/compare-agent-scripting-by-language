// Model representing a single parsed log entry from either syslog or JSON format.

namespace LogAnalyzer.Tests;

public class LogEntry
{
    /// <summary>Timestamp of the log event.</summary>
    public DateTime Timestamp { get; init; }

    /// <summary>Normalized level: ERROR, WARN, INFO, DEBUG.</summary>
    public string Level { get; init; } = string.Empty;

    /// <summary>Human-readable message body.</summary>
    public string Message { get; init; } = string.Empty;

    /// <summary>
    /// Error/warning category used for frequency grouping.
    /// For JSON logs: taken from the "error_type" field (falls back to Level).
    /// For syslog logs: extracted as the first word of the message (e.g. "NullReferenceException").
    /// </summary>
    public string ErrorType { get; init; } = string.Empty;

    /// <summary>Source format detected: "syslog" or "json".</summary>
    public string Format { get; init; } = string.Empty;

    /// <summary>The original unparsed line for debugging.</summary>
    public string RawLine { get; init; } = string.Empty;
}
