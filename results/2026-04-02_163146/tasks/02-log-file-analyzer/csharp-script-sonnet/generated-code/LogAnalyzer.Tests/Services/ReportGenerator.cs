// ReportGenerator — produces human-readable table output and JSON files.
//
// TDD progression:
//   RED:   ReportGeneratorTests wouldn't compile (class missing).
//   GREEN: RenderTable(), ToJson(), WriteJsonFile() added to pass tests.
//   REFACTOR: Column widths computed dynamically for a well-aligned table.

using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LogAnalyzer.Tests;

public static class ReportGenerator
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter() },
    };

    // ── Human-readable table ─────────────────────────────────────────────────

    /// <summary>Renders the frequency table as a formatted text table string.</summary>
    public static string RenderTable(IEnumerable<FrequencyRow> rows)
    {
        var list = rows.ToList();

        if (list.Count == 0)
            return "No errors or warnings found in the log file.\n";

        // Define columns
        var headers = new[] { "Error Type", "Level", "Count", "First Seen", "Last Seen" };

        // Format timestamps consistently
        string Fmt(DateTime dt) => dt.ToString("yyyy-MM-dd HH:mm:ss");

        // Build data rows as string arrays
        var dataRows = list
            .Select(r => new[]
            {
                r.ErrorType,
                r.Level,
                r.Count.ToString(),
                Fmt(r.FirstOccurrence),
                Fmt(r.LastOccurrence),
            })
            .ToList();

        // Compute column widths (max of header vs data)
        var widths = headers
            .Select((h, i) => Math.Max(h.Length, dataRows.Max(row => row[i].Length)))
            .ToArray();

        var sb = new StringBuilder();

        // Header
        sb.AppendLine(BuildSeparator(widths));
        sb.AppendLine(BuildRow(headers, widths));
        sb.AppendLine(BuildSeparator(widths));

        // Data rows
        foreach (var row in dataRows)
            sb.AppendLine(BuildRow(row, widths));

        sb.AppendLine(BuildSeparator(widths));
        sb.AppendLine($"Total: {list.Count} distinct error/warning type(s), " +
                      $"{list.Sum(r => r.Count)} total occurrence(s).");

        return sb.ToString();
    }

    // ── JSON output ──────────────────────────────────────────────────────────

    /// <summary>Serialises the frequency rows to a JSON string.</summary>
    public static string ToJson(IEnumerable<FrequencyRow> rows) =>
        JsonSerializer.Serialize(rows.ToList(), JsonOptions);

    /// <summary>Writes the JSON report to a file, creating/overwriting it.</summary>
    public static void WriteJsonFile(IEnumerable<FrequencyRow> rows, string filePath)
    {
        var dir = Path.GetDirectoryName(filePath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        File.WriteAllText(filePath, ToJson(rows));
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static string BuildSeparator(int[] widths) =>
        "+" + string.Join("+", widths.Select(w => new string('-', w + 2))) + "+";

    private static string BuildRow(string[] cells, int[] widths)
    {
        var cols = cells
            .Select((c, i) => " " + c.PadRight(widths[i]) + " ")
            .ToArray();
        return "|" + string.Join("|", cols) + "|";
    }
}
