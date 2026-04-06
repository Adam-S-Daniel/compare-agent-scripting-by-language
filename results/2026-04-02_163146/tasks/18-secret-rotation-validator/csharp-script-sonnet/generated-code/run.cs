// Secret Rotation Validator — .NET 10 file-based app entry point.
//
// This file is self-contained and can be run directly with:
//   dotnet run run.cs
//
// Usage:
//   dotnet run run.cs                   # markdown output, 30-day warning window
//   dotnet run run.cs -- --format json  # JSON output
//   dotnet run run.cs -- --warning 14   # 14-day warning window
//
// For tests run:
//   dotnet test tests/SecretRotation.Tests/
//
// NOTE: The core logic (RotationAnalyzer, ReportFormatter) is implemented in
// src/SecretRotation/ and tested there. This file includes the same logic
// inline so it can run as a standalone file-based app without requiring a
// pre-built library.

using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

// ─── Parse CLI arguments ────────────────────────────────────────────────────

string format = "markdown";
int warningWindowDays = 30;

for (int i = 0; i < args.Length; i++)
{
    if (args[i] is "--format" or "-f" && i + 1 < args.Length)
        format = args[++i].ToLower();
    else if (args[i] is "--warning" or "-w" && i + 1 < args.Length)
        warningWindowDays = int.TryParse(args[++i], out var w) ? w : warningWindowDays;
    else if (args[i] is "--help" or "-h")
    {
        Console.WriteLine("Usage: dotnet run run.cs -- [--format markdown|json] [--warning <days>]");
        return 0;
    }
}

// ─── Mock data: realistic sample secrets ────────────────────────────────────
// In production, these would be loaded from a config file or secrets manager.

var today = DateOnly.FromDateTime(DateTime.UtcNow);
Console.Error.WriteLine($"[INFO] Reference date: {today:yyyy-MM-dd}  Warning window: {warningWindowDays} days");

var secrets = new[]
{
    // EXPIRED: last rotated 120 days ago, 90-day policy → expired 30 days ago
    new SecretConfig(
        Name: "prod-db-password",
        LastRotated: today.AddDays(-120),
        RotationPolicyDays: 90,
        RequiredByServices: ["api-gateway", "reporting-service"]),

    // EXPIRED: last rotated 95 days ago, 90-day policy → expired 5 days ago
    new SecretConfig(
        Name: "oauth-client-secret",
        LastRotated: today.AddDays(-95),
        RotationPolicyDays: 90,
        RequiredByServices: ["auth-service"]),

    // WARNING: last rotated 75 days ago, 90-day policy → expires in 15 days
    new SecretConfig(
        Name: "smtp-credentials",
        LastRotated: today.AddDays(-75),
        RotationPolicyDays: 90,
        RequiredByServices: ["notifications-service", "email-worker"]),

    // WARNING: last rotated 25 days ago, 30-day policy → expires in 5 days
    new SecretConfig(
        Name: "payment-api-key",
        LastRotated: today.AddDays(-25),
        RotationPolicyDays: 30,
        RequiredByServices: ["payments-service"]),

    // OK: last rotated 10 days ago, 90-day policy → expires in 80 days
    new SecretConfig(
        Name: "s3-access-key",
        LastRotated: today.AddDays(-10),
        RotationPolicyDays: 90,
        RequiredByServices: ["storage-service", "backup-worker"]),

    // OK: last rotated yesterday, 365-day policy → expires in 364 days
    new SecretConfig(
        Name: "root-ca-certificate",
        LastRotated: today.AddDays(-1),
        RotationPolicyDays: 365,
        RequiredByServices: ["all-services"]),
};

// ─── Analyze ─────────────────────────────────────────────────────────────────

var report = RotationAnalyzer.Analyze(secrets, warningWindowDays: warningWindowDays, today: today);

// ─── Output ──────────────────────────────────────────────────────────────────

var output = format switch
{
    "json" => ReportFormatter.ToJson(report),
    "markdown" or "md" => ReportFormatter.ToMarkdown(report),
    _ => throw new ArgumentException($"Unknown format: '{format}'. Use 'markdown' or 'json'.")
};

Console.WriteLine(output);
return 0;

// ════════════════════════════════════════════════════════════════════════════
// Inline type and logic definitions
// (mirrors src/SecretRotation/ — kept here for standalone file-based execution)
// ════════════════════════════════════════════════════════════════════════════

/// <summary>Configuration for a single secret.</summary>
record SecretConfig(
    string Name,
    DateOnly LastRotated,
    int RotationPolicyDays,
    string[] RequiredByServices);

/// <summary>Urgency classification.</summary>
enum RotationStatus { Expired, Warning, Ok }

/// <summary>Analysis result for a single secret.</summary>
record RotationResult(
    SecretConfig Secret,
    int DaysUntilExpiry,
    RotationStatus Status,
    string Message);

/// <summary>Full rotation report with results grouped by urgency.</summary>
record RotationReport(
    DateTimeOffset GeneratedAt,
    IReadOnlyList<RotationResult> Results,
    int WarningWindowDays)
{
    public IReadOnlyList<RotationResult> Expired => Results.Where(r => r.Status == RotationStatus.Expired).ToList();
    public IReadOnlyList<RotationResult> Warning => Results.Where(r => r.Status == RotationStatus.Warning).ToList();
    public IReadOnlyList<RotationResult> Ok      => Results.Where(r => r.Status == RotationStatus.Ok).ToList();
}

/// <summary>Core classification logic — today is injected for testability.</summary>
static class RotationAnalyzer
{
    public static RotationReport Analyze(
        IEnumerable<SecretConfig> secrets,
        int warningWindowDays = 30,
        DateOnly? today = null)
    {
        if (warningWindowDays < 0)
            throw new ArgumentOutOfRangeException(nameof(warningWindowDays), "Warning window cannot be negative.");

        var referenceDate = today ?? DateOnly.FromDateTime(DateTime.UtcNow);

        var results = secrets
            .Select(s => Classify(s, referenceDate, warningWindowDays))
            .ToList();

        return new RotationReport(DateTimeOffset.UtcNow, results, warningWindowDays);
    }

    private static RotationResult Classify(SecretConfig secret, DateOnly today, int warningWindowDays)
    {
        var expiryDate = secret.LastRotated.AddDays(secret.RotationPolicyDays);
        var daysUntilExpiry = expiryDate.DayNumber - today.DayNumber;

        var (status, message) = daysUntilExpiry < 0
            ? (RotationStatus.Expired,
               $"Expired {Math.Abs(daysUntilExpiry)} day(s) ago — rotate immediately")
            : daysUntilExpiry <= warningWindowDays
            ? (RotationStatus.Warning,
               $"Expires in {daysUntilExpiry} day(s) — rotation due soon")
            : (RotationStatus.Ok,
               $"OK — expires in {daysUntilExpiry} day(s)");

        return new RotationResult(secret, daysUntilExpiry, status, message);
    }
}

/// <summary>Renders reports in markdown or JSON format.</summary>
static class ReportFormatter
{
    public static string ToMarkdown(RotationReport report)
    {
        var sb = new StringBuilder();

        sb.AppendLine("# Secret Rotation Report");
        sb.AppendLine();
        sb.AppendLine($"**Generated:** {report.GeneratedAt:yyyy-MM-dd HH:mm:ss} UTC  ");
        sb.AppendLine($"**Warning window:** {report.WarningWindowDays} days  ");
        sb.AppendLine($"**Total secrets:** {report.Results.Count}  ");
        sb.AppendLine();

        sb.AppendLine("## Summary");
        sb.AppendLine();
        sb.AppendLine("| Status  | Count |");
        sb.AppendLine("|---------|-------|");
        sb.AppendLine($"| 🔴 Expired | {report.Expired.Count} |");
        sb.AppendLine($"| 🟡 Warning | {report.Warning.Count} |");
        sb.AppendLine($"| 🟢 OK      | {report.Ok.Count} |");
        sb.AppendLine();

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

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    public static string ToJson(RotationReport report)
    {
        var payload = new
        {
            generatedAt = report.GeneratedAt.ToString("O"),
            warningWindowDays = report.WarningWindowDays,
            summary = new
            {
                total = report.Results.Count,
                expired = report.Expired.Count,
                warning = report.Warning.Count,
                ok = report.Ok.Count
            },
            expired = report.Expired.Select(ToEntry).ToArray(),
            warning = report.Warning.Select(ToEntry).ToArray(),
            ok      = report.Ok.Select(ToEntry).ToArray()
        };

        return JsonSerializer.Serialize(payload, JsonOptions);
    }

    private static object ToEntry(RotationResult r) => new
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
