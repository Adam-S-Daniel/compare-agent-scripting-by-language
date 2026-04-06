// Output formatters for the rotation report.
// Supports markdown table and JSON formats.
// Both are pure functions: given a RotationReport, return a string.

using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SecretRotation;

public static class ReportFormatter
{
    // ─────────────────────────────────────────────────────────
    // Markdown table format
    // ─────────────────────────────────────────────────────────

    /// <summary>
    /// Renders the rotation report as a markdown document with grouped tables.
    /// </summary>
    public static string ToMarkdown(RotationReport report)
    {
        var sb = new StringBuilder();

        sb.AppendLine("# Secret Rotation Report");
        sb.AppendLine();
        sb.AppendLine($"**Generated:** {report.GeneratedAt:yyyy-MM-dd HH:mm:ss} UTC  ");
        sb.AppendLine($"**Warning window:** {report.WarningWindowDays} days  ");
        sb.AppendLine($"**Total secrets:** {report.Results.Count}  ");
        sb.AppendLine();

        // Summary counts
        sb.AppendLine("## Summary");
        sb.AppendLine();
        sb.AppendLine($"| Status  | Count |");
        sb.AppendLine($"|---------|-------|");
        sb.AppendLine($"| 🔴 Expired | {report.Expired.Count} |");
        sb.AppendLine($"| 🟡 Warning | {report.Warning.Count} |");
        sb.AppendLine($"| 🟢 OK      | {report.Ok.Count} |");
        sb.AppendLine();

        // Per-status sections
        AppendSection(sb, "🔴 Expired", report.Expired, "Expired");
        AppendSection(sb, "🟡 Warning", report.Warning, "Warning");
        AppendSection(sb, "🟢 OK", report.Ok, "OK");

        return sb.ToString();
    }

    private static void AppendSection(
        StringBuilder sb,
        string heading,
        IReadOnlyList<RotationResult> results,
        string statusLabel)
    {
        sb.AppendLine($"## {heading}");
        sb.AppendLine();

        if (results.Count == 0)
        {
            sb.AppendLine($"_No secrets in {statusLabel} state._");
            sb.AppendLine();
            return;
        }

        // Markdown table header
        sb.AppendLine("| Secret Name | Policy (days) | Days Until Expiry | Required By | Message |");
        sb.AppendLine("|-------------|--------------|-------------------|-------------|---------|");

        foreach (var r in results)
        {
            var services = string.Join(", ", r.Secret.RequiredByServices);
            sb.AppendLine(
                $"| {r.Secret.Name} " +
                $"| {r.Secret.RotationPolicyDays} " +
                $"| {r.DaysUntilExpiry} " +
                $"| {services} " +
                $"| {r.Message} |");
        }

        sb.AppendLine();
    }

    // ─────────────────────────────────────────────────────────
    // JSON format
    // ─────────────────────────────────────────────────────────

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        // Serialize enums as strings ("Expired") not integers (0)
        Converters = { new JsonStringEnumConverter() }
    };

    /// <summary>
    /// Renders the rotation report as a structured JSON document.
    /// Results are grouped into "expired", "warning", and "ok" arrays.
    /// </summary>
    public static string ToJson(RotationReport report)
    {
        var payload = new
        {
            generatedAt = report.GeneratedAt.ToString("O"),          // ISO 8601
            warningWindowDays = report.WarningWindowDays,
            summary = new
            {
                total = report.Results.Count,
                expired = report.Expired.Count,
                warning = report.Warning.Count,
                ok = report.Ok.Count
            },
            expired = report.Expired.Select(ToJsonEntry).ToArray(),
            warning = report.Warning.Select(ToJsonEntry).ToArray(),
            ok      = report.Ok.Select(ToJsonEntry).ToArray()
        };

        return JsonSerializer.Serialize(payload, JsonOptions);
    }

    private static object ToJsonEntry(RotationResult r) => new
    {
        name = r.Secret.Name,
        lastRotated = r.Secret.LastRotated.ToString("yyyy-MM-dd"),
        rotationPolicyDays = r.Secret.RotationPolicyDays,
        requiredByServices = r.Secret.RequiredByServices,
        daysUntilExpiry = r.DaysUntilExpiry,
        status = r.Status,
        message = r.Message
    };
}
