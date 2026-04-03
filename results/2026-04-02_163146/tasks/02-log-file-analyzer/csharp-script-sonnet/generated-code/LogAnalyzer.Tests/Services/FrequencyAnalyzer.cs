// FrequencyAnalyzer — groups log entries by (ErrorType, Level) and computes
// occurrence counts plus first/last timestamps.
//
// TDD progression:
//   RED:   FrequencyAnalyzerTests compiled but had no implementation → build error.
//   GREEN: Static Analyze() method added to make tests pass.
//   REFACTOR: Extracted grouping key logic for readability.

namespace LogAnalyzer.Tests;

public static class FrequencyAnalyzer
{
    private static readonly HashSet<string> IncludedLevels =
        new(StringComparer.OrdinalIgnoreCase) { "ERROR", "WARN" };

    /// <summary>
    /// Produces a frequency table of error/warning types from the given entries.
    /// Only ERROR and WARN entries are included.
    /// Results are sorted by count descending, then by ErrorType ascending for ties.
    /// </summary>
    public static IEnumerable<FrequencyRow> Analyze(IEnumerable<LogEntry> entries)
    {
        return entries
            .Where(e => IncludedLevels.Contains(e.Level))
            .GroupBy(e => (e.ErrorType, e.Level))
            .Select(g => new FrequencyRow
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
}
