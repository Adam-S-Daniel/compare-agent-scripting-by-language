// VersionParser — reads and writes version strings in both plain version.txt
// and package.json formats.
// GREEN phase: minimum implementation to make VersionParserTests pass.

using System.Text.Json;
using System.Text.RegularExpressions;

namespace VersionBumper;

/// <summary>
/// Parses and updates semantic version strings embedded in version files.
/// Supports two file types:
///   - Plain text (*.txt, VERSION, etc.) — the whole file is the version string.
///   - package.json — the "version" JSON field is read/written.
/// </summary>
public static class VersionParser
{
    // Regex to match the "version" field in package.json (handles whitespace variants)
    private static readonly Regex PackageVersionRegex = new(
        @"""version""\s*:\s*""(\d+\.\d+\.\d+)""",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    /// <summary>
    /// Parse a <see cref="SemanticVersion"/> from the given file <paramref name="content"/>.
    /// The <paramref name="fileName"/> is used only to choose the parsing strategy
    /// (package.json vs plain text).
    /// </summary>
    public static SemanticVersion Parse(string content, string fileName)
    {
        return IsPackageJson(fileName)
            ? ParseFromPackageJson(content)
            : SemanticVersion.Parse(content.Trim());
    }

    /// <summary>
    /// Return a new copy of <paramref name="content"/> with the version replaced
    /// by <paramref name="newVersion"/>.
    /// For plain text files the entire content is replaced.
    /// For package.json only the "version" field value is replaced.
    /// </summary>
    public static string UpdateContent(string content, string fileName, SemanticVersion newVersion)
    {
        return IsPackageJson(fileName)
            ? UpdatePackageJson(content, newVersion)
            : newVersion.ToString();
    }

    // ─────────────────────────────────────────────────────
    // Async file-level helpers
    // ─────────────────────────────────────────────────────

    /// <summary>Read a version file from disk and parse it.</summary>
    public static async Task<SemanticVersion> ParseFileAsync(string filePath)
    {
        var content = await File.ReadAllTextAsync(filePath);
        return Parse(content, Path.GetFileName(filePath));
    }

    /// <summary>Read a version file, update the version, and write it back.</summary>
    public static async Task UpdateFileAsync(string filePath, SemanticVersion newVersion)
    {
        var content = await File.ReadAllTextAsync(filePath);
        var updated = UpdateContent(content, Path.GetFileName(filePath), newVersion);
        await File.WriteAllTextAsync(filePath, updated);
    }

    // ─────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────

    private static bool IsPackageJson(string fileName) =>
        Path.GetFileName(fileName).Equals("package.json", StringComparison.OrdinalIgnoreCase);

    private static SemanticVersion ParseFromPackageJson(string content)
    {
        using var doc = JsonDocument.Parse(content);

        if (!doc.RootElement.TryGetProperty("version", out var versionElement))
            throw new InvalidOperationException(
                "package.json does not contain a 'version' field. " +
                "Ensure the file has a top-level \"version\" key.");

        var versionStr = versionElement.GetString()
            ?? throw new InvalidOperationException(
                "'version' field in package.json is null. Expected a semver string like \"1.0.0\".");

        return SemanticVersion.Parse(versionStr);
    }

    private static string UpdatePackageJson(string content, SemanticVersion newVersion)
    {
        // Use regex replacement to preserve all other formatting
        if (!PackageVersionRegex.IsMatch(content))
            throw new InvalidOperationException(
                "Could not find a 'version' field to update in package.json.");

        return PackageVersionRegex.Replace(
            content,
            $@"""version"": ""{newVersion}""");
    }
}
