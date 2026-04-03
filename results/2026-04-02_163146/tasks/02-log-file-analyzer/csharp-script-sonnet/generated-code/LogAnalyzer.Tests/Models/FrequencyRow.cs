// Model for a single row in the error/warning frequency table.

namespace LogAnalyzer.Tests;

public class FrequencyRow
{
    public string ErrorType      { get; init; } = string.Empty;
    public string Level          { get; init; } = string.Empty;
    public int    Count          { get; init; }
    public DateTime FirstOccurrence { get; init; }
    public DateTime LastOccurrence  { get; init; }
}
