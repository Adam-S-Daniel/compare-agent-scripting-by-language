// bump-version.cs — Semantic Version Bumper
// .NET 10 file-based app: run with `dotnet run bump-version.cs`
//
// Usage:
//   dotnet run bump-version.cs <version-file> <commits-file>
//   dotnet run bump-version.cs version.txt commits.json
//   dotnet run bump-version.cs package.json commits.json
//
// Where:
//   <version-file>  — path to a plain version.txt or package.json
//   <commits-file>  — path to a JSON array of conventional commit strings
//
// Output (stdout):
//   The new version string (e.g. "2.0.0")
//   A markdown changelog entry to stderr is also written to a CHANGELOG.md snippet
//
// Exit codes:  0 = success,  1 = error

using System.Text.Json;
using System.Text.RegularExpressions;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — top-level statements
// ─────────────────────────────────────────────────────────────────────────────

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: dotnet run bump-version.cs <version-file> <commits-file>");
    Console.Error.WriteLine();
    Console.Error.WriteLine("  <version-file>  — version.txt or package.json");
    Console.Error.WriteLine("  <commits-file>  — JSON array of conventional commit messages");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Example:");
    Console.Error.WriteLine("  dotnet run bump-version.cs version.txt commits.json");
    Environment.Exit(1);
}

var versionFilePath = args[0];
var commitsFilePath = args[1];

try
{
    // 1. Read and parse current version
    if (!File.Exists(versionFilePath))
    {
        Console.Error.WriteLine($"Error: version file not found: '{versionFilePath}'");
        Environment.Exit(1);
    }

    var versionContent = await File.ReadAllTextAsync(versionFilePath);
    var currentVersion = AppVersionParser.Parse(versionContent, Path.GetFileName(versionFilePath));

    // 2. Load commit messages
    if (!File.Exists(commitsFilePath))
    {
        Console.Error.WriteLine($"Error: commits file not found: '{commitsFilePath}'");
        Environment.Exit(1);
    }

    var commitsJson    = await File.ReadAllTextAsync(commitsFilePath);
    var commitMessages = JsonSerializer.Deserialize<string[]>(commitsJson);

    if (commitMessages is null || commitMessages.Length == 0)
    {
        Console.Error.WriteLine("Warning: no commits found in commits file. Nothing to bump.");
        Console.WriteLine(currentVersion);
        Environment.Exit(0);
    }

    // 3. Analyse commits — determine bump type
    var parsedCommits = AppCommitAnalyzer.ParseCommits(commitMessages);
    var bumpType      = AppCommitAnalyzer.AnalyzeCommits(commitMessages);

    if (bumpType == AppBumpType.None)
    {
        Console.Error.WriteLine($"No releasable commits found. Current version: {currentVersion}");
        Console.WriteLine(currentVersion);
        Environment.Exit(0);
    }

    // 4. Calculate new version
    var nextVersion = AppVersionBumper.Bump(currentVersion, bumpType);

    // 5. Update the version file
    var updatedContent = AppVersionParser.UpdateContent(versionContent, Path.GetFileName(versionFilePath), nextVersion);
    await File.WriteAllTextAsync(versionFilePath, updatedContent);

    // 6. Generate changelog entry
    var changelog = AppChangelogGenerator.Generate(nextVersion, parsedCommits, DateTime.UtcNow);

    // 7. Append to CHANGELOG.md (create if it doesn't exist)
    var changelogPath = Path.Combine(Path.GetDirectoryName(versionFilePath) ?? ".", "CHANGELOG.md");
    if (File.Exists(changelogPath))
    {
        var existing = await File.ReadAllTextAsync(changelogPath);
        // Insert new entry after the first line (title) if it has one, otherwise prepend
        var lines = existing.Split('\n');
        if (lines.Length > 1 && lines[0].StartsWith("# "))
        {
            await File.WriteAllTextAsync(changelogPath, lines[0] + "\n\n" + changelog + "\n" + string.Join("\n", lines.Skip(1)).TrimStart());
        }
        else
        {
            await File.WriteAllTextAsync(changelogPath, changelog + "\n" + existing);
        }
    }
    else
    {
        await File.WriteAllTextAsync(changelogPath, "# Changelog\n\n" + changelog);
    }

    Console.Error.WriteLine($"Version bumped: {currentVersion} → {nextVersion} ({bumpType})");
    Console.Error.WriteLine($"Changelog written to: {changelogPath}");

    // Output the new version to stdout for scripting
    Console.WriteLine(nextVersion);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.Exit(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain models (self-contained copy for the file-based app)
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>Immutable semantic version (MAJOR.MINOR.PATCH).</summary>
public record AppSemanticVersion(int Major, int Minor, int Patch)
{
    public override string ToString() => $"{Major}.{Minor}.{Patch}";

    public static AppSemanticVersion Parse(string version)
    {
        var trimmed = version.Trim();
        var parts   = trimmed.Split('.');

        if (parts.Length != 3)
            throw new FormatException(
                $"Invalid semantic version: '{trimmed}'. Expected MAJOR.MINOR.PATCH.");

        if (!int.TryParse(parts[0], out var major) ||
            !int.TryParse(parts[1], out var minor) ||
            !int.TryParse(parts[2], out var patch))
            throw new FormatException(
                $"Invalid semantic version: '{trimmed}'. All parts must be integers.");

        return new AppSemanticVersion(major, minor, patch);
    }
}

/// <summary>Version bump magnitude.</summary>
public enum AppBumpType { None = 0, Patch = 1, Minor = 2, Major = 3 }

/// <summary>A parsed conventional commit.</summary>
public record AppCommit(
    string Type,
    string Description,
    bool IsBreaking,
    string? Scope = null,
    string? Body  = null);

// ─────────────────────────────────────────────────────────────────────────────
// VersionParser
// ─────────────────────────────────────────────────────────────────────────────

public static class AppVersionParser
{
    private static readonly Regex PkgVersionRegex = new(
        @"""version""\s*:\s*""(\d+\.\d+\.\d+)""",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public static AppSemanticVersion Parse(string content, string fileName) =>
        IsPackageJson(fileName)
            ? ParsePackageJson(content)
            : AppSemanticVersion.Parse(content.Trim());

    public static string UpdateContent(string content, string fileName, AppSemanticVersion v) =>
        IsPackageJson(fileName)
            ? UpdatePackageJson(content, v)
            : v.ToString();

    private static bool IsPackageJson(string name) =>
        name.Equals("package.json", StringComparison.OrdinalIgnoreCase);

    private static AppSemanticVersion ParsePackageJson(string content)
    {
        using var doc = JsonDocument.Parse(content);
        if (!doc.RootElement.TryGetProperty("version", out var el))
            throw new InvalidOperationException("package.json has no 'version' field.");
        return AppSemanticVersion.Parse(el.GetString()
            ?? throw new InvalidOperationException("'version' in package.json is null."));
    }

    private static string UpdatePackageJson(string content, AppSemanticVersion v)
    {
        if (!PkgVersionRegex.IsMatch(content))
            throw new InvalidOperationException("Could not find 'version' field in package.json.");
        return PkgVersionRegex.Replace(content, $@"""version"": ""{v}""");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// CommitAnalyzer
// ─────────────────────────────────────────────────────────────────────────────

public static class AppCommitAnalyzer
{
    private static readonly Regex ConventionalRx = new(
        @"^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?\s*:\s*(?<desc>.+)$",
        RegexOptions.Compiled);

    private static readonly Regex BreakingBodyRx = new(
        @"BREAKING[\s\-]CHANGE\s*:",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public static AppCommit ParseCommit(string message)
    {
        if (string.IsNullOrWhiteSpace(message))
            return new AppCommit("other", message ?? "", false, Body: message);

        var firstLine = message.Split('\n')[0].Trim();
        var m = ConventionalRx.Match(firstLine);
        if (!m.Success) return new AppCommit("other", firstLine, false, Body: message);

        var type      = m.Groups["type"].Value.ToLowerInvariant();
        var scope     = m.Groups["scope"].Success ? m.Groups["scope"].Value : null;
        var desc      = m.Groups["desc"].Value.Trim();
        var isBreak   = m.Groups["bang"].Success || BreakingBodyRx.IsMatch(message);

        return new AppCommit(type, desc, isBreak, scope, message);
    }

    public static IReadOnlyList<AppCommit> ParseCommits(IEnumerable<string> messages)
        => messages.Select(ParseCommit).ToList().AsReadOnly();

    public static AppBumpType AnalyzeCommits(IEnumerable<string> messages)
    {
        var result = AppBumpType.None;
        foreach (var msg in messages)
        {
            var bump = GetBump(ParseCommit(msg));
            if (bump > result) result = bump;
            if (result == AppBumpType.Major) break;
        }
        return result;
    }

    private static AppBumpType GetBump(AppCommit c) =>
        c.IsBreaking ? AppBumpType.Major :
        c.Type == "feat" ? AppBumpType.Minor :
        c.Type is "fix" or "perf" ? AppBumpType.Patch :
        AppBumpType.None;
}

// ─────────────────────────────────────────────────────────────────────────────
// VersionBumper arithmetic
// ─────────────────────────────────────────────────────────────────────────────

public static class AppVersionBumper
{
    public static AppSemanticVersion Bump(AppSemanticVersion v, AppBumpType t) => t switch
    {
        AppBumpType.Major => new AppSemanticVersion(v.Major + 1, 0, 0),
        AppBumpType.Minor => new AppSemanticVersion(v.Major, v.Minor + 1, 0),
        AppBumpType.Patch => new AppSemanticVersion(v.Major, v.Minor, v.Patch + 1),
        AppBumpType.None  => v,
        _                 => throw new ArgumentOutOfRangeException(nameof(t), t, null)
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// ChangelogGenerator
// ─────────────────────────────────────────────────────────────────────────────

public static class AppChangelogGenerator
{
    public static string Generate(
        AppSemanticVersion version,
        IEnumerable<AppCommit> commits,
        DateTime? date = null)
    {
        var releaseDate = date ?? DateTime.UtcNow;
        var list = commits.ToList();

        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"## [{version}] - {releaseDate:yyyy-MM-dd}");

        var breaking = list.Where(c => c.IsBreaking).ToList();
        var feats    = list.Where(c => !c.IsBreaking && c.Type == "feat").ToList();
        var fixes    = list.Where(c => !c.IsBreaking && c.Type == "fix").ToList();
        var other    = list.Where(c => !c.IsBreaking
                                     && c.Type != "feat"
                                     && c.Type != "fix"
                                     && c.Type != "other").ToList();

        AppendSection(sb, "BREAKING CHANGES", breaking);
        AppendSection(sb, "Features",         feats);
        AppendSection(sb, "Bug Fixes",        fixes);
        AppendSection(sb, "Other Changes",    other);

        return sb.ToString().TrimEnd() + Environment.NewLine;
    }

    private static void AppendSection(System.Text.StringBuilder sb, string title, List<AppCommit> commits)
    {
        if (commits.Count == 0) return;
        sb.AppendLine();
        sb.AppendLine($"### {title}");
        sb.AppendLine();
        foreach (var c in commits)
            sb.AppendLine($"- {(c.Scope != null ? $"**{c.Scope}**: " : "")}{c.Description}{(c.IsBreaking ? " ⚠️ BREAKING" : "")}");
    }
}
