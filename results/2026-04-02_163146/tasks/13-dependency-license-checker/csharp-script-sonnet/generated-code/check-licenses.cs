#!/usr/bin/env dotnet-script
// check-licenses.cs — Dependency License Checker
//
// Usage:
//   dotnet run check-licenses.cs <manifest-file> [--config config.json] [--output json|text]
//
// Or run with config defaults:
//   dotnet run check-licenses.cs package.json
//
// The license config can be supplied via --config <file> (JSON with
// "allowList" and "denyList" arrays).  If omitted, a built-in permissive
// default is used that allows MIT/Apache-2.0/BSD/ISC and denies GPL/AGPL.
//
// License lookup is mocked in this standalone script for demonstration;
// swap in a real HTTP lookup (npm registry, PyPI JSON API, etc.) by
// replacing the CreateLookup() function.

// ── top-level statements (file-based app) ─────────────────────────────────

using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

// ── arg parsing ───────────────────────────────────────────────────────────
if (args.Length == 0 || args[0] == "--help" || args[0] == "-h")
{
    Console.WriteLine("Usage: dotnet run check-licenses.cs <manifest> [--config <file>] [--output json|text]");
    return 1;
}

string manifestPath = args[0];
string? configPath  = null;
string outputFormat = "text";

for (int i = 1; i < args.Length; i++)
{
    if (args[i] == "--config" && i + 1 < args.Length)
        configPath = args[++i];
    else if (args[i] == "--output" && i + 1 < args.Length)
        outputFormat = args[++i].ToLower();
}

// ── load manifest ─────────────────────────────────────────────────────────
if (!File.Exists(manifestPath))
{
    Console.Error.WriteLine($"Error: manifest file not found: {manifestPath}");
    return 2;
}

string manifestContent = await File.ReadAllTextAsync(manifestPath);
string manifestName    = Path.GetFileName(manifestPath);

// ── load or build config ──────────────────────────────────────────────────
LicenseConfig config;
if (configPath != null)
{
    if (!File.Exists(configPath))
    {
        Console.Error.WriteLine($"Error: config file not found: {configPath}");
        return 2;
    }
    var configJson = await File.ReadAllTextAsync(configPath);
    config = ParseConfig(configJson);
}
else
{
    // Built-in defaults: permissive licenses allowed, copyleft denied
    config = new LicenseConfig(
        AllowList: ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "0BSD", "Unlicense"],
        DenyList:  ["GPL-2.0", "GPL-3.0", "AGPL-3.0", "LGPL-2.0", "LGPL-2.1", "LGPL-3.0"]
    );
}

// ── parse manifest ────────────────────────────────────────────────────────
List<Dependency> dependencies;
try
{
    var parser = new ManifestParser();
    dependencies = parser.DetectAndParse(manifestContent, manifestName);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error parsing manifest: {ex.Message}");
    return 3;
}

if (dependencies.Count == 0)
{
    Console.Error.WriteLine("Warning: no dependencies found in the manifest.");
}

// ── check licenses ────────────────────────────────────────────────────────
// For this demo, use a built-in mock lookup.  Replace CreateLookup() with a
// real HTTP client to query npm / PyPI.
var lookup  = CreateLookup(manifestName);
var checker = new ComplianceChecker(config, lookup);
var results = await checker.CheckAllAsync(dependencies);

// ── generate report ───────────────────────────────────────────────────────
var report    = new ComplianceReport(manifestName, DateTime.UtcNow, results);
var formatter = new ReportFormatter();

var output = outputFormat == "json"
    ? formatter.FormatJson(report)
    : formatter.FormatText(report);

Console.Write(output);
return report.IsCompliant ? 0 : 1;

// ── helper: build a demo mock lookup ─────────────────────────────────────
static ILicenseLookup CreateLookup(string manifestName)
{
    // Demo data — in production replace with real registry calls
    var npm = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["express"]      = "MIT",
        ["lodash"]       = "MIT",
        ["react"]        = "MIT",
        ["react-dom"]    = "MIT",
        ["axios"]        = "MIT",
        ["typescript"]   = "Apache-2.0",
        ["jest"]         = "MIT",
        ["webpack"]      = "MIT",
        ["babel-core"]   = "MIT",
        ["eslint"]       = "MIT",
        ["gpl-module"]   = "GPL-3.0",
        ["agpl-server"]  = "AGPL-3.0",
    };

    var pypi = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["requests"]   = "Apache-2.0",
        ["flask"]      = "BSD-3-Clause",
        ["django"]     = "BSD-3-Clause",
        ["numpy"]      = "BSD-3-Clause",
        ["pandas"]     = "BSD-3-Clause",
        ["pytest"]     = "MIT",
        ["setuptools"] = "MIT",
        ["click"]      = "BSD-3-Clause",
        ["pydantic"]   = "MIT",
        ["fastapi"]    = "MIT",
    };

    var map = manifestName.ToLower() == "requirements.txt" ? pypi : npm;
    return new MockLicenseLookup(map);
}

// ── helper: parse JSON config ─────────────────────────────────────────────
static LicenseConfig ParseConfig(string json)
{
    using var doc  = JsonDocument.Parse(json);
    var root       = doc.RootElement;
    var allowList  = ParseStringArray(root, "allowList");
    var denyList   = ParseStringArray(root, "denyList");
    return new LicenseConfig(allowList, denyList);
}

static List<string> ParseStringArray(JsonElement parent, string propertyName)
{
    if (parent.TryGetProperty(propertyName, out var arr) && arr.ValueKind == JsonValueKind.Array)
        return arr.EnumerateArray().Select(e => e.GetString() ?? "").Where(s => s.Length > 0).ToList();
    return [];
}

// ═══════════════════════════════════════════════════════════════════════════
// Inline library — same code as LicenseChecker.Lib, duplicated here so the
// file-based app can be run standalone with `dotnet run check-licenses.cs`.
// ═══════════════════════════════════════════════════════════════════════════

// ── Models ────────────────────────────────────────────────────────────────
record Dependency(string Name, string Version);

enum LicenseStatus { Approved, Denied, Unknown }

record LicenseCheckResult(
    string Name, string Version, string? License,
    LicenseStatus Status, string Reason);

record LicenseConfig(IReadOnlyList<string> AllowList, IReadOnlyList<string> DenyList);

record ComplianceReport(
    string ManifestFile,
    DateTime GeneratedAt,
    IReadOnlyList<LicenseCheckResult> Results)
{
    public int  ApprovedCount => Results.Count(r => r.Status == LicenseStatus.Approved);
    public int  DeniedCount   => Results.Count(r => r.Status == LicenseStatus.Denied);
    public int  UnknownCount  => Results.Count(r => r.Status == LicenseStatus.Unknown);
    public bool IsCompliant   => DeniedCount == 0;
}

// ── ILicenseLookup / MockLicenseLookup ────────────────────────────────────
interface ILicenseLookup
{
    Task<string?> GetLicenseAsync(string packageName, string version);
}

class MockLicenseLookup(Dictionary<string, string> licenses) : ILicenseLookup
{
    public Task<string?> GetLicenseAsync(string packageName, string version)
    {
        licenses.TryGetValue(packageName, out var license);
        return Task.FromResult<string?>(license);
    }
}

// ── ManifestParser ────────────────────────────────────────────────────────
class ManifestParser
{
    public List<Dependency> ParsePackageJson(string json)
    {
        var deps = new List<Dependency>();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        foreach (var section in new[] { "dependencies", "devDependencies", "peerDependencies" })
        {
            if (root.TryGetProperty(section, out var obj) && obj.ValueKind == JsonValueKind.Object)
                foreach (var prop in obj.EnumerateObject())
                    deps.Add(new Dependency(prop.Name, prop.Value.GetString() ?? ""));
        }
        return deps;
    }

    public List<Dependency> ParseRequirementsTxt(string content)
    {
        var deps = new List<Dependency>();
        var lineRegex = new Regex(
            @"^(?<name>[A-Za-z0-9_.\-]+)\s*(?<op>==|>=|<=|~=|!=|>|<)\s*(?<ver>[^\s#]+)",
            RegexOptions.Compiled);
        foreach (var rawLine in content.Split('\n'))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrEmpty(line) || line.StartsWith('#')) continue;
            var m = lineRegex.Match(line);
            if (m.Success)
            {
                var op      = m.Groups["op"].Value;
                var ver     = m.Groups["ver"].Value;
                var version = op == "==" ? ver : op + ver;
                deps.Add(new Dependency(m.Groups["name"].Value, version));
            }
        }
        return deps;
    }

    public List<Dependency> DetectAndParse(string content, string filename)
    {
        var lower = filename.ToLowerInvariant();
        if (lower == "package.json")      return ParsePackageJson(content);
        if (lower == "requirements.txt")  return ParseRequirementsTxt(content);
        throw new NotSupportedException($"Unsupported manifest format: '{filename}'.");
    }
}

// ── ComplianceChecker ─────────────────────────────────────────────────────
class ComplianceChecker(LicenseConfig config, ILicenseLookup lookup)
{
    public async Task<LicenseCheckResult> CheckAsync(Dependency dep)
    {
        var license = await lookup.GetLicenseAsync(dep.Name, dep.Version);
        if (license is null)
            return new(dep.Name, dep.Version, null, LicenseStatus.Unknown,
                "License information could not be found.");

        var norm = license.ToUpperInvariant();
        if (config.DenyList.Any(d => d.ToUpperInvariant() == norm))
            return new(dep.Name, dep.Version, license, LicenseStatus.Denied,
                $"License '{license}' is on the deny list.");
        if (config.AllowList.Any(a => a.ToUpperInvariant() == norm))
            return new(dep.Name, dep.Version, license, LicenseStatus.Approved,
                $"License '{license}' is on the allow list.");
        return new(dep.Name, dep.Version, license, LicenseStatus.Unknown,
            $"License '{license}' is not on either the allow list or the deny list.");
    }

    public async Task<IReadOnlyList<LicenseCheckResult>> CheckAllAsync(
        IEnumerable<Dependency> dependencies)
    {
        var tasks = dependencies.Select(CheckAsync);
        return await Task.WhenAll(tasks);
    }
}

// ── ReportFormatter ───────────────────────────────────────────────────────
class ReportFormatter
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters    = { new JsonStringEnumConverter() }
    };

    public string FormatText(ComplianceReport report)
    {
        var sb = new System.Text.StringBuilder();
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
        foreach (var status in new[] { LicenseStatus.Approved, LicenseStatus.Denied, LicenseStatus.Unknown })
        {
            var group = report.Results.Where(r => r.Status == status).ToList();
            if (group.Count == 0) continue;
            sb.AppendLine($"--- {status.ToString().ToUpper()} ({group.Count}) ---");
            foreach (var r in group)
            {
                sb.AppendLine($"  {r.Name} {r.Version}");
                sb.AppendLine($"    License : {r.License ?? "(unknown)"}");
                sb.AppendLine($"    Reason  : {r.Reason}");
            }
            sb.AppendLine();
        }
        return sb.ToString();
    }

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
