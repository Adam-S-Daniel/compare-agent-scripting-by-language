// ManifestParser: reads package.json and requirements.txt files,
// returning a flat list of Dependency(name, version) records.

using System.Text.Json;
using System.Text.RegularExpressions;

namespace LicenseChecker.Lib;

public class ManifestParser
{
    /// <summary>Parse a package.json string and return all dependencies (prod + dev).</summary>
    public List<Dependency> ParsePackageJson(string json)
    {
        var deps = new List<Dependency>();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        foreach (var section in new[] { "dependencies", "devDependencies", "peerDependencies" })
        {
            if (root.TryGetProperty(section, out var obj) && obj.ValueKind == JsonValueKind.Object)
            {
                foreach (var prop in obj.EnumerateObject())
                    deps.Add(new Dependency(prop.Name, prop.Value.GetString() ?? ""));
            }
        }

        return deps;
    }

    /// <summary>
    /// Parse a requirements.txt string.
    /// Supports: name==ver, name>=ver, name~=ver, name<=ver, name!=ver.
    /// Lines starting with '#' or empty lines are skipped.
    /// </summary>
    public List<Dependency> ParseRequirementsTxt(string content)
    {
        var deps = new List<Dependency>();
        // Matches: package_name followed by optional version specifier
        var lineRegex = new Regex(
            @"^(?<name>[A-Za-z0-9_.\-]+)\s*(?<op>==|>=|<=|~=|!=|>|<)\s*(?<ver>[^\s#]+)",
            RegexOptions.Compiled
        );

        foreach (var rawLine in content.Split('\n'))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrEmpty(line) || line.StartsWith('#'))
                continue;

            var m = lineRegex.Match(line);
            if (m.Success)
            {
                var name = m.Groups["name"].Value;
                var op   = m.Groups["op"].Value;
                var ver  = m.Groups["ver"].Value;
                // Preserve the operator in the version string (e.g. ">=2.0.0")
                var version = op == "==" ? ver : op + ver;
                deps.Add(new Dependency(name, version));
            }
        }

        return deps;
    }

    /// <summary>Auto-detect format from the filename and parse accordingly.</summary>
    public List<Dependency> DetectAndParse(string content, string filename)
    {
        var lower = filename.ToLowerInvariant();
        if (lower == "package.json")
            return ParsePackageJson(content);
        if (lower == "requirements.txt")
            return ParseRequirementsTxt(content);

        throw new NotSupportedException(
            $"Unsupported manifest format: '{filename}'. " +
            "Supported formats: package.json, requirements.txt"
        );
    }
}
