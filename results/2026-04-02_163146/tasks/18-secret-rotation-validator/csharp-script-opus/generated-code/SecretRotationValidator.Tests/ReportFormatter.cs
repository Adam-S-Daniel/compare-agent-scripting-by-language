// ReportFormatter: Outputs a ValidationReport as either markdown table or JSON.
// Supports grouped output by urgency with summary statistics.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace SecretRotationValidator;

public static class ReportFormatter
{
    /// <summary>
    /// Formats the validation report as a markdown document with tables grouped by urgency.
    /// </summary>
    public static string FormatMarkdown(ValidationReport report, DateTime asOf)
    {
        var sb = new StringBuilder();
        var total = report.All.Count();

        sb.AppendLine($"# Secret Rotation Report");
        sb.AppendLine($"Generated: {asOf:yyyy-MM-dd}");
        sb.AppendLine();

        if (total == 0)
        {
            sb.AppendLine("No secrets to report.");
            return sb.ToString();
        }

        // Summary line
        sb.AppendLine($"**Summary:** {total} secrets — " +
            $"{report.Expired.Count} expired, " +
            $"{report.Warning.Count} warning, " +
            $"{report.Ok.Count} ok");
        sb.AppendLine();

        // Render each group if it has entries
        AppendSection(sb, "Expired", report.Expired);
        AppendSection(sb, "Warning", report.Warning);
        AppendSection(sb, "Ok", report.Ok);

        return sb.ToString();
    }

    private static void AppendSection(StringBuilder sb, string title, List<ValidationEntry> entries)
    {
        if (entries.Count == 0) return;

        sb.AppendLine($"## {title}");
        sb.AppendLine();
        sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |");
        sb.AppendLine("|------|-------------|---------------|-------------------|-------------|");

        foreach (var entry in entries)
        {
            var services = string.Join(", ", entry.Secret.RequiredByServices);
            sb.AppendLine($"| {entry.Secret.Name} | {entry.Secret.LastRotated:yyyy-MM-dd} " +
                $"| {entry.Secret.RotationPolicyDays} | {entry.DaysUntilExpiry} | {services} |");
        }

        sb.AppendLine();
    }

    /// <summary>
    /// Formats the validation report as a JSON string with grouped entries and summary.
    /// </summary>
    public static string FormatJson(ValidationReport report, DateTime asOf)
    {
        var total = report.All.Count();
        var data = new
        {
            reportDate = asOf.ToString("yyyy-MM-dd"),
            summary = new
            {
                total,
                expired = report.Expired.Count,
                warning = report.Warning.Count,
                ok = report.Ok.Count
            },
            expired = report.Expired.Select(ToJsonEntry),
            warning = report.Warning.Select(ToJsonEntry),
            ok = report.Ok.Select(ToJsonEntry)
        };

        return JsonSerializer.Serialize(data, new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
    }

    private static object ToJsonEntry(ValidationEntry entry) => new
    {
        name = entry.Secret.Name,
        lastRotated = entry.Secret.LastRotated.ToString("yyyy-MM-dd"),
        rotationPolicyDays = entry.Secret.RotationPolicyDays,
        daysUntilExpiry = entry.DaysUntilExpiry,
        urgency = entry.Urgency.ToString().ToLowerInvariant(),
        requiredByServices = entry.Secret.RequiredByServices
    };
}
