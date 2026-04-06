// ReportFormatter: converts a ComplianceReport to human-readable text
// or machine-readable JSON.

using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LicenseChecker.Lib;

public class ReportFormatter
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    /// <summary>Produce a multi-line human-readable compliance report.</summary>
    public string FormatText(ComplianceReport report)
    {
        var sb = new StringBuilder();

        sb.AppendLine("===========================================");
        sb.AppendLine("   DEPENDENCY LICENSE COMPLIANCE REPORT   ");
        sb.AppendLine("===========================================");
        sb.AppendLine($"Manifest : {report.ManifestFile}");
        sb.AppendLine($"Generated: {report.GeneratedAt:u}");
        sb.AppendLine($"Total    : {report.Results.Count} dependencies");
        sb.AppendLine($"Approved : {report.ApprovedCount}");
        sb.AppendLine($"Denied   : {report.DeniedCount}");
        sb.AppendLine($"Unknown  : {report.UnknownCount}");
        sb.AppendLine($"COMPLIANT: {(report.IsCompliant ? "YES" : "NO")}");
        sb.AppendLine();

        // Group by status for readability
        foreach (var status in new[] { LicenseStatus.Approved, LicenseStatus.Denied, LicenseStatus.Unknown })
        {
            var group = report.Results.Where(r => r.Status == status).ToList();
            if (group.Count == 0) continue;

            sb.AppendLine($"--- {status.ToString().ToUpper()} ({group.Count}) ---");
            foreach (var r in group)
            {
                var licenseLabel = r.License ?? "(unknown)";
                sb.AppendLine($"  {r.Name} {r.Version}");
                sb.AppendLine($"    License : {licenseLabel}");
                sb.AppendLine($"    Reason  : {r.Reason}");
            }
            sb.AppendLine();
        }

        return sb.ToString();
    }

    /// <summary>Produce a JSON compliance report.</summary>
    public string FormatJson(ComplianceReport report)
    {
        var obj = new
        {
            manifestFile  = report.ManifestFile,
            generatedAt   = report.GeneratedAt.ToString("o"),
            isCompliant   = report.IsCompliant,
            approvedCount = report.ApprovedCount,
            deniedCount   = report.DeniedCount,
            unknownCount  = report.UnknownCount,
            results = report.Results.Select(r => new
            {
                name    = r.Name,
                version = r.Version,
                license = r.License,
                status  = r.Status.ToString(),
                reason  = r.Reason
            })
        };
        return JsonSerializer.Serialize(obj, JsonOptions);
    }
}
