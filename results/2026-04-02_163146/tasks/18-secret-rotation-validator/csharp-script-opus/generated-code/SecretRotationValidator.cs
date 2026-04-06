// Secret Rotation Validator — .NET 10 file-based app
// Run with: dotnet run SecretRotationValidator.cs -- [options]
//
// Validates secrets against their rotation policies, groups by urgency,
// and outputs reports in markdown or JSON format.
//
// Usage:
//   dotnet run SecretRotationValidator.cs -- --config secrets.json [--format markdown|json] [--warning-days 7]
//   dotnet run SecretRotationValidator.cs -- --config secrets.json --format json --warning-days 14

#:package System.Text.Json@9.*

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;

// --- Entry point ---

var (configPath, format, warningDays) = ParseArgs(args);

try
{
    var secrets = LoadFromFile(configPath);
    var report = Validate(secrets, DateTime.Today, warningDays);

    var output = format switch
    {
        "json" => FormatJson(report, DateTime.Today),
        "markdown" or "md" => FormatMarkdown(report, DateTime.Today),
        _ => throw new ArgumentException($"Unknown format: {format}. Use 'markdown' or 'json'.")
    };

    Console.WriteLine(output);

    // Exit with non-zero if any secrets are expired
    if (report.Expired.Count > 0)
        Environment.Exit(1);
}
catch (ConfigLoadException ex)
{
    Console.Error.WriteLine($"Error loading configuration: {ex.Message}");
    Environment.Exit(2);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    Environment.Exit(3);
}

// --- Argument parsing ---

static (string configPath, string format, int warningDays) ParseArgs(string[] args)
{
    string? configPath = null;
    string format = "markdown";
    int warningDays = 7;

    for (int i = 0; i < args.Length; i++)
    {
        switch (args[i])
        {
            case "--config" or "-c":
                if (i + 1 >= args.Length)
                    ExitWithUsage("--config requires a file path argument.");
                configPath = args[++i];
                break;
            case "--format" or "-f":
                if (i + 1 >= args.Length)
                    ExitWithUsage("--format requires a value (markdown or json).");
                format = args[++i].ToLowerInvariant();
                break;
            case "--warning-days" or "-w":
                if (i + 1 >= args.Length || !int.TryParse(args[i + 1], out warningDays) || warningDays < 0)
                    ExitWithUsage("--warning-days requires a non-negative integer.");
                i++;
                break;
            case "--help" or "-h":
                ExitWithUsage(null);
                break;
            default:
                ExitWithUsage($"Unknown argument: {args[i]}");
                break;
        }
    }

    if (configPath is null)
        ExitWithUsage("--config is required.");

    return (configPath!, format, warningDays);
}

static void ExitWithUsage(string? error)
{
    if (error is not null)
        Console.Error.WriteLine($"Error: {error}");

    Console.Error.WriteLine("""
        Usage: dotnet run SecretRotationValidator.cs -- --config <path> [--format markdown|json] [--warning-days <n>]

        Options:
          --config, -c         Path to secrets JSON configuration file (required)
          --format, -f         Output format: markdown (default) or json
          --warning-days, -w   Days before expiry to trigger warning (default: 7)
          --help, -h           Show this help message
        """);
    Environment.Exit(error is null ? 0 : 2);
}

// --- Models ---

record SecretConfig(string Name, DateTime LastRotated, int RotationPolicyDays, List<string> RequiredByServices)
{
    public int DaysUntilExpiry(DateTime asOf) => (int)(LastRotated.AddDays(RotationPolicyDays) - asOf).TotalDays;
    public bool IsExpired(DateTime asOf) => DaysUntilExpiry(asOf) < 0;
    public bool IsInWarningWindow(DateTime asOf, int warningDays)
    {
        var days = DaysUntilExpiry(asOf);
        return days >= 0 && days <= warningDays;
    }
}

enum Urgency { Expired, Warning, Ok }
record ValidationEntry(SecretConfig Secret, Urgency Urgency, int DaysUntilExpiry);
record ValidationReport(List<ValidationEntry> Expired, List<ValidationEntry> Warning, List<ValidationEntry> Ok)
{
    public IEnumerable<ValidationEntry> All => Expired.Concat(Warning).Concat(Ok);
}

// --- Validator ---

static ValidationReport Validate(List<SecretConfig> secrets, DateTime asOf, int warningDays)
{
    var expired = new List<ValidationEntry>();
    var warning = new List<ValidationEntry>();
    var ok = new List<ValidationEntry>();

    foreach (var secret in secrets)
    {
        var daysUntilExpiry = secret.DaysUntilExpiry(asOf);
        Urgency urgency;
        if (secret.IsExpired(asOf)) urgency = Urgency.Expired;
        else if (secret.IsInWarningWindow(asOf, warningDays)) urgency = Urgency.Warning;
        else urgency = Urgency.Ok;

        var entry = new ValidationEntry(secret, urgency, daysUntilExpiry);
        switch (urgency)
        {
            case Urgency.Expired: expired.Add(entry); break;
            case Urgency.Warning: warning.Add(entry); break;
            case Urgency.Ok:      ok.Add(entry); break;
        }
    }
    return new ValidationReport(expired, warning, ok);
}

// --- Config loader ---

class ConfigLoadException : Exception
{
    public ConfigLoadException(string message) : base(message) { }
    public ConfigLoadException(string message, Exception inner) : base(message, inner) { }
}

static List<SecretConfig> LoadFromFile(string filePath)
{
    if (!File.Exists(filePath))
        throw new ConfigLoadException($"Configuration file not found: {filePath}");
    return LoadFromString(File.ReadAllText(filePath));
}

static List<SecretConfig> LoadFromString(string json)
{
    JsonDocument doc;
    try { doc = JsonDocument.Parse(json); }
    catch (JsonException ex) { throw new ConfigLoadException($"Invalid JSON: {ex.Message}", ex); }

    if (!doc.RootElement.TryGetProperty("secrets", out var secretsArray))
        throw new ConfigLoadException("Configuration must contain a 'secrets' array.");

    var results = new List<SecretConfig>();
    for (int i = 0; i < secretsArray.GetArrayLength(); i++)
    {
        var el = secretsArray[i];

        if (!el.TryGetProperty("name", out var nameEl) || nameEl.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(nameEl.GetString()))
            throw new ConfigLoadException($"Secret at index {i}: 'name' is required.");
        var name = nameEl.GetString()!;

        if (!el.TryGetProperty("lastRotated", out var dateEl) || dateEl.ValueKind != JsonValueKind.String)
            throw new ConfigLoadException($"Secret '{name}': 'lastRotated' is required.");
        if (!DateTime.TryParseExact(dateEl.GetString(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var lastRotated))
            throw new ConfigLoadException($"Secret '{name}': 'lastRotated' value '{dateEl.GetString()}' is not a valid date (yyyy-MM-dd).");

        if (!el.TryGetProperty("rotationPolicyDays", out var policyEl) || policyEl.ValueKind != JsonValueKind.Number)
            throw new ConfigLoadException($"Secret '{name}': 'rotationPolicyDays' is required.");
        var policyDays = policyEl.GetInt32();
        if (policyDays <= 0)
            throw new ConfigLoadException($"Secret '{name}': 'rotationPolicyDays' must be positive, got {policyDays}.");

        var services = new List<string>();
        if (el.TryGetProperty("requiredByServices", out var svcEl) && svcEl.ValueKind == JsonValueKind.Array)
            foreach (var s in svcEl.EnumerateArray())
                if (s.ValueKind == JsonValueKind.String) services.Add(s.GetString()!);

        results.Add(new SecretConfig(name, lastRotated, policyDays, services));
    }
    return results;
}

// --- Report formatters ---

static string FormatMarkdown(ValidationReport report, DateTime asOf)
{
    var sb = new StringBuilder();
    var total = report.All.Count();

    sb.AppendLine("# Secret Rotation Report");
    sb.AppendLine($"Generated: {asOf:yyyy-MM-dd}");
    sb.AppendLine();

    if (total == 0)
    {
        sb.AppendLine("No secrets to report.");
        return sb.ToString();
    }

    sb.AppendLine($"**Summary:** {total} secrets — {report.Expired.Count} expired, {report.Warning.Count} warning, {report.Ok.Count} ok");
    sb.AppendLine();

    AppendSection(sb, "Expired", report.Expired);
    AppendSection(sb, "Warning", report.Warning);
    AppendSection(sb, "Ok", report.Ok);

    return sb.ToString();
}

static void AppendSection(StringBuilder sb, string title, List<ValidationEntry> entries)
{
    if (entries.Count == 0) return;
    sb.AppendLine($"## {title}");
    sb.AppendLine();
    sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |");
    sb.AppendLine("|------|-------------|---------------|-------------------|-------------|");
    foreach (var e in entries)
    {
        var svcs = string.Join(", ", e.Secret.RequiredByServices);
        sb.AppendLine($"| {e.Secret.Name} | {e.Secret.LastRotated:yyyy-MM-dd} | {e.Secret.RotationPolicyDays} | {e.DaysUntilExpiry} | {svcs} |");
    }
    sb.AppendLine();
}

static string FormatJson(ValidationReport report, DateTime asOf)
{
    var data = new
    {
        reportDate = asOf.ToString("yyyy-MM-dd"),
        summary = new
        {
            total = report.All.Count(),
            expired = report.Expired.Count,
            warning = report.Warning.Count,
            ok = report.Ok.Count
        },
        expired = report.Expired.Select(ToJsonEntry),
        warning = report.Warning.Select(ToJsonEntry),
        ok = report.Ok.Select(ToJsonEntry)
    };
    return JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase });
}

static object ToJsonEntry(ValidationEntry entry) => new
{
    name = entry.Secret.Name,
    lastRotated = entry.Secret.LastRotated.ToString("yyyy-MM-dd"),
    rotationPolicyDays = entry.Secret.RotationPolicyDays,
    daysUntilExpiry = entry.DaysUntilExpiry,
    urgency = entry.Urgency.ToString().ToLowerInvariant(),
    requiredByServices = entry.Secret.RequiredByServices
};
