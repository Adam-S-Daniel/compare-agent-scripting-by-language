// LicenseCheckerApp.cs - Main entry point for the dependency license checker
// This is a .NET 10 file-based app: run with `dotnet run LicenseCheckerApp.cs`
//
// Usage:
//   dotnet run LicenseCheckerApp.cs <manifest-file> <config-file> [--json] [--output <file>]
//
// Arguments:
//   manifest-file  Path to package.json or requirements.txt
//   config-file    Path to JSON config with allowedLicenses and deniedLicenses
//   --json         Output as JSON instead of text table
//   --output       Write report to a file instead of stdout

using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

// ── Top-level entry point ──────────────────────────────────────��─────────────

try
{
    if (args.Length < 2)
    {
        Console.Error.WriteLine("Usage: dotnet run LicenseCheckerApp.cs <manifest-file> <config-file> [--json] [--output <file>]");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Arguments:");
        Console.Error.WriteLine("  manifest-file  Path to package.json or requirements.txt");
        Console.Error.WriteLine("  config-file    Path to JSON config with allowedLicenses and deniedLicenses");
        Console.Error.WriteLine("  --json         Output as JSON instead of text table");
        Console.Error.WriteLine("  --output FILE  Write report to FILE instead of stdout");
        return 1;
    }

    var manifestPath = args[0];
    var configPath = args[1];
    bool jsonOutput = args.Contains("--json");
    string? outputPath = null;
    var outputIdx = Array.IndexOf(args, "--output");
    if (outputIdx >= 0 && outputIdx + 1 < args.Length)
        outputPath = args[outputIdx + 1];

    // Read input files
    if (!File.Exists(manifestPath))
    {
        Console.Error.WriteLine($"Error: Manifest file not found: {manifestPath}");
        return 1;
    }
    if (!File.Exists(configPath))
    {
        Console.Error.WriteLine($"Error: Config file not found: {configPath}");
        return 1;
    }

    var manifestContent = File.ReadAllText(manifestPath);
    var configContent = File.ReadAllText(configPath);

    // Parse config
    var config = AppComplianceConfig.FromJson(configContent);

    // Parse manifest
    var deps = AppParser.Parse(Path.GetFileName(manifestPath), manifestContent);
    Console.Error.WriteLine($"Found {deps.Count} dependencies in {manifestPath}");

    // Look up licenses (using mock provider)
    var provider = new AppMockLicenseProvider();
    var results = new List<AppComplianceResult>();
    foreach (var dep in deps)
    {
        var license = provider.GetLicense(dep.Name, dep.Version);
        var status = AppChecker.Classify(license, config);
        results.Add(new AppComplianceResult(dep.Name, dep.Version, license, status));
    }

    // Generate report
    var report = AppReporter.Generate(results);
    var output = jsonOutput ? AppReporter.ToJson(report) : AppReporter.ToText(report);

    // Write output
    if (outputPath is not null)
    {
        File.WriteAllText(outputPath, output);
        Console.Error.WriteLine($"Report written to {outputPath}");
    }
    else
    {
        Console.WriteLine(output);
    }

    return report.Summary.Pass ? 0 : 2;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

// ── Inline types for file-based app self-containment ─────────────────────────
// These mirror the library types but are prefixed with "App" to avoid conflicts
// when used as a standalone file-based app.

record AppDependency(string Name, string Version);
enum AppLicenseStatus { Approved, Denied, Unknown }
record AppComplianceResult(string DependencyName, string Version, string? License, AppLicenseStatus Status);
record AppReportEntry(string DependencyName, string Version, string? License, string Status);
record AppReportSummary(int Total, int Approved, int Denied, int Unknown, bool Pass);
record AppComplianceReport(List<AppReportEntry> Entries, AppReportSummary Summary);

record AppComplianceConfig(HashSet<string> AllowedLicenses, HashSet<string> DeniedLicenses)
{
    public static AppComplianceConfig FromJson(string json)
    {
        JsonNode? root;
        try { root = JsonNode.Parse(json); }
        catch (JsonException ex) { throw new Exception($"Invalid config JSON: {ex.Message}", ex); }
        if (root is null) throw new Exception("Config JSON is null");
        var allowedNode = root["allowedLicenses"] ?? throw new Exception("Config missing: allowedLicenses");
        var deniedNode = root["deniedLicenses"] ?? throw new Exception("Config missing: deniedLicenses");
        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in allowedNode.AsArray()) if (item is not null) allowed.Add(item.GetValue<string>());
        var denied = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in deniedNode.AsArray()) if (item is not null) denied.Add(item.GetValue<string>());
        return new AppComplianceConfig(allowed, denied);
    }
}

// Mock license provider with common package licenses
class AppMockLicenseProvider
{
    static readonly Dictionary<string, string> KnownLicenses = new(StringComparer.OrdinalIgnoreCase)
    {
        ["express"] = "MIT", ["lodash"] = "MIT", ["react"] = "MIT",
        ["react-dom"] = "MIT", ["axios"] = "MIT", ["moment"] = "MIT",
        ["typescript"] = "Apache-2.0", ["webpack"] = "MIT", ["jest"] = "MIT",
        ["mocha"] = "MIT", ["chalk"] = "MIT", ["commander"] = "MIT",
        ["flask"] = "BSD-3-Clause", ["requests"] = "Apache-2.0",
        ["numpy"] = "BSD-3-Clause", ["pandas"] = "BSD-3-Clause",
        ["django"] = "BSD-3-Clause", ["fastapi"] = "MIT",
        ["sqlalchemy"] = "MIT", ["pytest"] = "MIT",
        ["gpl-library"] = "GPL-3.0", ["agpl-package"] = "AGPL-3.0",
    };

    public string? GetLicense(string packageName, string version)
        => KnownLicenses.TryGetValue(packageName, out var lic) ? lic : null;
}

// Manifest parser
static class AppParser
{
    public static List<AppDependency> Parse(string filename, string content)
    {
        var name = Path.GetFileName(filename).ToLowerInvariant();
        return name switch
        {
            "package.json" => ParsePackageJson(content),
            "requirements.txt" => ParseRequirementsTxt(content),
            _ => throw new Exception($"Unsupported manifest format: '{filename}'")
        };
    }

    static List<AppDependency> ParsePackageJson(string json)
    {
        JsonNode? root;
        try { root = JsonNode.Parse(json); }
        catch (JsonException ex) { throw new Exception($"Failed to parse package.json: {ex.Message}", ex); }
        if (root is null) throw new Exception("package.json content is null");
        var deps = new List<AppDependency>();
        ExtractSection(root["dependencies"], deps);
        ExtractSection(root["devDependencies"], deps);
        return deps;
    }

    static void ExtractSection(JsonNode? section, List<AppDependency> deps)
    {
        if (section is not JsonObject obj) return;
        foreach (var kvp in obj)
            deps.Add(new AppDependency(kvp.Key, kvp.Value?.GetValue<string>() ?? "*"));
    }

    static List<AppDependency> ParseRequirementsTxt(string content)
    {
        var deps = new List<AppDependency>();
        var pattern = new Regex(@"^\s*([a-zA-Z0-9_][a-zA-Z0-9._-]*)\s*((?:==|>=|<=|~=|!=|<|>).+)?\s*$");
        foreach (var rawLine in content.Split('\n'))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#')) continue;
            var match = pattern.Match(line);
            if (match.Success)
                deps.Add(new AppDependency(match.Groups[1].Value,
                    match.Groups[2].Success ? match.Groups[2].Value : "*"));
        }
        return deps;
    }
}

// Compliance checker
static class AppChecker
{
    public static AppLicenseStatus Classify(string? license, AppComplianceConfig config)
    {
        if (license is null) return AppLicenseStatus.Unknown;
        if (config.DeniedLicenses.Contains(license)) return AppLicenseStatus.Denied;
        if (config.AllowedLicenses.Contains(license)) return AppLicenseStatus.Approved;
        return AppLicenseStatus.Unknown;
    }
}

// Report generator
static class AppReporter
{
    public static AppComplianceReport Generate(List<AppComplianceResult> results)
    {
        var entries = results.Select(r =>
            new AppReportEntry(r.DependencyName, r.Version, r.License, r.Status.ToString())).ToList();
        int approved = results.Count(r => r.Status == AppLicenseStatus.Approved);
        int denied = results.Count(r => r.Status == AppLicenseStatus.Denied);
        int unknown = results.Count(r => r.Status == AppLicenseStatus.Unknown);
        return new AppComplianceReport(entries,
            new AppReportSummary(results.Count, approved, denied, unknown, denied == 0));
    }

    public static string ToJson(AppComplianceReport report) =>
        JsonSerializer.Serialize(report, new JsonSerializerOptions
            { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

    public static string ToText(AppComplianceReport report)
    {
        var sb = new StringBuilder();
        sb.AppendLine("╔══════════════════════════════════════════════════════════════════╗");
        sb.AppendLine("║              Dependency License Compliance Report               ║");
        sb.AppendLine("╚══════════════════════════════════════════════════════════════════╝");
        sb.AppendLine();
        sb.AppendLine($"{"Dependency",-30} {"Version",-15} {"License",-15} {"Status",-10}");
        sb.AppendLine(new string('-', 70));
        foreach (var e in report.Entries)
            sb.AppendLine($"{e.DependencyName,-30} {e.Version,-15} {(e.License ?? "(unknown)"),-15} {e.Status,-10}");
        sb.AppendLine();
        sb.AppendLine($"Total: {report.Summary.Total}  |  Approved: {report.Summary.Approved}  |  " +
                       $"Denied: {report.Summary.Denied}  |  Unknown: {report.Summary.Unknown}");
        sb.AppendLine();
        sb.AppendLine(report.Summary.Pass ? "Result: PASS" : "Result: FAIL");
        return sb.ToString();
    }
}
