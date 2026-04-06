// Docker Image Tag Generator — .NET 10 file-based app
// Run with: dotnet run DockerTagGenerator.cs
//
// Given git context (branch, commit SHA, tags, PR number), generates
// Docker image tags following common CI/CD conventions:
//   - "latest" for main/master branches
//   - "pr-{number}" for pull requests
//   - "v{semver}" for semver tags
//   - "{branch}-{short-sha}" for feature branches
//   - All tags sanitized: lowercase, no special chars except hyphens/dots/underscores

using System.Text.RegularExpressions;

// ─── Parse CLI args or use defaults ──────────────────────────────────

var branch = GetArg("--branch", "main");
var sha = GetArg("--sha", "abc1234567890def1234567890abcdef12345678");
var tagsArg = GetArg("--tags", "");
var prArg = GetArg("--pr", "");

var gitTags = string.IsNullOrWhiteSpace(tagsArg)
    ? Array.Empty<string>()
    : tagsArg.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

int? prNumber = int.TryParse(prArg, out var pr) ? pr : null;

// ─── Build context and generate tags ─────────────────────────────────

var context = new GitContext
{
    BranchName = branch,
    CommitSha = sha,
    Tags = gitTags,
    PrNumber = prNumber
};

Console.WriteLine($"Git Context:");
Console.WriteLine($"  Branch:    {context.BranchName}");
Console.WriteLine($"  SHA:       {context.CommitSha}");
Console.WriteLine($"  Short SHA: {context.ShortSha}");
Console.WriteLine($"  Tags:      {(gitTags.Length > 0 ? string.Join(", ", gitTags) : "(none)")}");
Console.WriteLine($"  PR:        {(prNumber.HasValue ? $"#{prNumber}" : "(none)")}");
Console.WriteLine();

try
{
    var dockerTags = TagGenerator.GenerateTags(context);

    Console.WriteLine("Generated Docker Tags:");
    foreach (var tag in dockerTags)
    {
        Console.WriteLine($"  - {tag}");
    }
    Console.WriteLine();

    // Output in a format suitable for CI/CD (comma-separated)
    Console.WriteLine($"DOCKER_TAGS={string.Join(",", dockerTags)}");
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}

return 0;

// ─── Helper: parse named CLI arguments ───────────────────────────────

string GetArg(string name, string defaultValue)
{
    for (int i = 0; i < args.Length - 1; i++)
    {
        if (args[i] == name)
            return args[i + 1];
    }
    return defaultValue;
}

// ─── Types ───────────────────────────────────────────────────────────

/// <summary>
/// Represents git context used for tag generation. In real CI/CD, these
/// values come from environment variables like GITHUB_REF, GITHUB_SHA, etc.
/// </summary>
class GitContext
{
    public string BranchName { get; set; } = string.Empty;
    public string CommitSha { get; set; } = string.Empty;
    public string[] Tags { get; set; } = Array.Empty<string>();
    public int? PrNumber { get; set; }

    public string ShortSha => CommitSha.Length >= 7
        ? CommitSha[..7]
        : CommitSha;
}

/// <summary>
/// Generates Docker image tags following common conventions.
/// </summary>
static partial class TagGenerator
{
    [GeneratedRegex("[^a-z0-9._-]")]
    private static partial Regex InvalidTagCharsRegex();

    [GeneratedRegex("[-_.]{2,}")]
    private static partial Regex RepeatedSeparatorsRegex();

    public static string SanitizeTag(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
            throw new ArgumentException("Tag input must not be empty.", nameof(input));

        var tag = input.ToLowerInvariant();
        tag = InvalidTagCharsRegex().Replace(tag, "-");
        tag = RepeatedSeparatorsRegex().Replace(tag, match => match.Value[..1].ToString());
        tag = tag.Trim('-', '.', '_');

        if (tag.Length > 128)
            tag = tag[..128].TrimEnd('-', '.', '_');

        if (tag.Length == 0)
            throw new ArgumentException($"Tag '{input}' sanitizes to an empty string.", nameof(input));

        return tag;
    }

    public static List<string> GenerateTags(GitContext context)
    {
        if (context is null)
            throw new ArgumentNullException(nameof(context));

        if (string.IsNullOrWhiteSpace(context.CommitSha))
            throw new ArgumentException("CommitSha is required.", nameof(context));

        var tags = new List<string>();

        // PR builds get a pr-{number} tag
        if (context.PrNumber.HasValue)
            tags.Add($"pr-{context.PrNumber.Value}");

        // Semver git tags get included as Docker tags
        foreach (var gitTag in context.Tags ?? Array.Empty<string>())
        {
            if (IsSemverTag(gitTag))
                tags.Add(SanitizeTag(gitTag));
        }

        // Main/master branches get the "latest" tag
        if (IsDefaultBranch(context.BranchName))
            tags.Add("latest");

        // Always include a {branch}-{short-sha} tag
        if (!string.IsNullOrWhiteSpace(context.BranchName))
            tags.Add(SanitizeTag($"{context.BranchName}-{context.ShortSha}"));

        return tags;
    }

    public static bool IsDefaultBranch(string branchName) =>
        string.Equals(branchName, "main", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(branchName, "master", StringComparison.OrdinalIgnoreCase);

    public static bool IsSemverTag(string tag) =>
        Regex.IsMatch(tag, @"^v?\d+\.\d+\.\d+(-[\w.]+)?(\+[\w.]+)?$", RegexOptions.IgnoreCase);
}
