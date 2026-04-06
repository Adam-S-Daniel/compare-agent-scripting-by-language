// LicenseCheckerLib.cs - Core library for dependency license checking
// This file contains all the types and logic, shared between tests and the main app.
// Architecture: ManifestParser -> LicenseLookup -> ComplianceChecker -> ReportGenerator

using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace LicenseChecker;

// ── Data Models ──────────────────────────────────────────────────────────────

// Represents a single dependency extracted from a manifest
public record Dependency(string Name, string Version);

// License compliance status for a dependency
public enum LicenseStatus { Approved, Denied, Unknown }

// Result of checking a single dependency against the compliance config
public record ComplianceResult(string DependencyName, string Version, string? License, LicenseStatus Status);

// Compliance configuration: which licenses are allowed/denied
public record ComplianceConfig(
    HashSet<string> AllowedLicenses,
    HashSet<string> DeniedLicenses)
{
    // Parse config from a JSON string
    public static ComplianceConfig FromJson(string json)
    {
        JsonNode? root;
        try
        {
            root = JsonNode.Parse(json);
        }
        catch (JsonException ex)
        {
            throw new ConfigException($"Invalid config JSON: {ex.Message}", ex);
        }

        if (root is null)
            throw new ConfigException("Config JSON is null");

        var allowedNode = root["allowedLicenses"]
            ?? throw new ConfigException("Config missing required field: allowedLicenses");
        var deniedNode = root["deniedLicenses"]
            ?? throw new ConfigException("Config missing required field: deniedLicenses");

        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in allowedNode.AsArray())
            if (item is not null) allowed.Add(item.GetValue<string>());

        var denied = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in deniedNode.AsArray())
            if (item is not null) denied.Add(item.GetValue<string>());

        return new ComplianceConfig(allowed, denied);
    }
}

// Report data models
public record ReportEntry(string DependencyName, string Version, string? License, string Status);
public record ReportSummary(int Total, int Approved, int Denied, int Unknown, bool Pass);
public record ComplianceReport(List<ReportEntry> Entries, ReportSummary Summary);

// ── Custom Exceptions ────────────────────────────────────────────────────────

public class ManifestParseException : Exception
{
    public ManifestParseException(string message) : base(message) { }
    public ManifestParseException(string message, Exception inner) : base(message, inner) { }
}

public class ConfigException : Exception
{
    public ConfigException(string message) : base(message) { }
    public ConfigException(string message, Exception inner) : base(message, inner) { }
}

// ── License Provider Interface & Mock ────────────────────────────────────────

// Interface for license lookup so we can inject mocks for testing
public interface ILicenseProvider
{
    string? GetLicense(string packageName, string version);
}

// Mock implementation that returns licenses from a pre-configured dictionary
public class MockLicenseProvider : ILicenseProvider
{
    private readonly Dictionary<string, string> _licenses;

    public MockLicenseProvider(Dictionary<string, string> licenses)
    {
        _licenses = licenses;
    }

    public string? GetLicense(string packageName, string version)
    {
        return _licenses.TryGetValue(packageName, out var license) ? license : null;
    }
}

// ── Manifest Parser ──────────────────────────────────────────────────────────

// Parses dependency manifests (package.json, requirements.txt)
public static class ManifestParser
{
    // Auto-detect manifest format from filename and parse
    public static List<Dependency> Parse(string filename, string content)
    {
        var name = Path.GetFileName(filename).ToLowerInvariant();
        return name switch
        {
            "package.json" => ParsePackageJson(content),
            "requirements.txt" => ParseRequirementsTxt(content),
            _ => throw new ManifestParseException($"Unsupported manifest format: '{filename}'")
        };
    }

    // Parse a package.json string and extract all dependencies (dependencies + devDependencies)
    public static List<Dependency> ParsePackageJson(string json)
    {
        JsonNode? root;
        try
        {
            root = JsonNode.Parse(json);
        }
        catch (JsonException ex)
        {
            throw new ManifestParseException($"Failed to parse package.json: {ex.Message}", ex);
        }

        if (root is null)
            throw new ManifestParseException("package.json content is null");

        var deps = new List<Dependency>();

        // Extract from "dependencies" and "devDependencies" sections
        ExtractDepsFromSection(root["dependencies"], deps);
        ExtractDepsFromSection(root["devDependencies"], deps);

        return deps;
    }

    private static void ExtractDepsFromSection(JsonNode? section, List<Dependency> deps)
    {
        if (section is not JsonObject obj) return;
        foreach (var kvp in obj)
        {
            var version = kvp.Value?.GetValue<string>() ?? "*";
            deps.Add(new Dependency(kvp.Key, version));
        }
    }

    // Parse a requirements.txt string and extract all dependencies
    // Format: package_name[==|>=|~=|!=|<=|<|>]version  or just package_name
    public static List<Dependency> ParseRequirementsTxt(string content)
    {
        var deps = new List<Dependency>();
        // Regex to match: package_name followed by optional version specifier
        var pattern = new Regex(@"^\s*([a-zA-Z0-9_][a-zA-Z0-9._-]*)\s*((?:==|>=|<=|~=|!=|<|>).+)?\s*$");

        foreach (var rawLine in content.Split('\n'))
        {
            var line = rawLine.Trim();
            // Skip empty lines and comments
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#'))
                continue;

            var match = pattern.Match(line);
            if (match.Success)
            {
                var name = match.Groups[1].Value;
                var version = match.Groups[2].Success ? match.Groups[2].Value : "*";
                deps.Add(new Dependency(name, version));
            }
        }

        return deps;
    }
}

// ── License Lookup ───────────────────────────────────────────────────────────

// Orchestrates license lookups for a list of dependencies
public static class LicenseLookup
{
    // Look up licenses for all dependencies, returning a map of name -> license (or null)
    public static Dictionary<string, string?> LookupAll(
        List<Dependency> dependencies, ILicenseProvider provider)
    {
        var results = new Dictionary<string, string?>();
        foreach (var dep in dependencies)
        {
            results[dep.Name] = provider.GetLicense(dep.Name, dep.Version);
        }
        return results;
    }
}

// ── Compliance Checker ───────────────────────────────────────────────────────

// Checks dependencies against allow/deny license lists
public static class ComplianceChecker
{
    // Classify a single license against the config
    // Deny list takes precedence over allow list
    public static LicenseStatus ClassifyLicense(string? license, ComplianceConfig config)
    {
        if (license is null)
            return LicenseStatus.Unknown;

        // Deny list takes precedence
        if (config.DeniedLicenses.Contains(license))
            return LicenseStatus.Denied;

        if (config.AllowedLicenses.Contains(license))
            return LicenseStatus.Approved;

        return LicenseStatus.Unknown;
    }

    // Check all dependencies and return compliance results
    public static List<ComplianceResult> CheckAll(
        Dictionary<string, string?> licenseMap, ComplianceConfig config)
    {
        var results = new List<ComplianceResult>();
        foreach (var kvp in licenseMap)
        {
            var status = ClassifyLicense(kvp.Value, config);
            // We don't have version info in the license map, so use empty string
            results.Add(new ComplianceResult(kvp.Key, "", kvp.Value, status));
        }
        return results;
    }
}

// ── Report Generator ─────────────────────────────────────────────────────────

// Generates compliance reports in various formats (JSON, text)
public static class ReportGenerator
{
    // Generate a structured report from compliance results
    public static ComplianceReport Generate(List<ComplianceResult> results)
    {
        var entries = results
            .Select(r => new ReportEntry(r.DependencyName, r.Version, r.License, r.Status.ToString()))
            .ToList();

        int approved = results.Count(r => r.Status == LicenseStatus.Approved);
        int denied = results.Count(r => r.Status == LicenseStatus.Denied);
        int unknown = results.Count(r => r.Status == LicenseStatus.Unknown);
        bool pass = denied == 0;

        return new ComplianceReport(
            entries,
            new ReportSummary(results.Count, approved, denied, unknown, pass));
    }

    // Serialize report to indented JSON
    public static string ToJson(ComplianceReport report)
    {
        var options = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
        return JsonSerializer.Serialize(report, options);
    }

    // Render report as a human-readable text table
    public static string ToText(ComplianceReport report)
    {
        var sb = new StringBuilder();
        sb.AppendLine("╔══════════════════════════════════════════════════════════════════╗");
        sb.AppendLine("║              Dependency License Compliance Report               ║");
        sb.AppendLine("╚══════════════════════════════════════════════════════════════════╝");
        sb.AppendLine();

        // Table header
        sb.AppendLine($"{"Dependency",-30} {"Version",-15} {"License",-15} {"Status",-10}");
        sb.AppendLine(new string('-', 70));

        // Table rows
        foreach (var entry in report.Entries)
        {
            var license = entry.License ?? "(unknown)";
            sb.AppendLine($"{entry.DependencyName,-30} {entry.Version,-15} {license,-15} {entry.Status,-10}");
        }

        sb.AppendLine();
        sb.AppendLine($"Total: {report.Summary.Total}  |  " +
                       $"Approved: {report.Summary.Approved}  |  " +
                       $"Denied: {report.Summary.Denied}  |  " +
                       $"Unknown: {report.Summary.Unknown}");
        sb.AppendLine();
        sb.AppendLine(report.Summary.Pass ? "Result: PASS" : "Result: FAIL");

        return sb.ToString();
    }
}
