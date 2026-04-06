// generate-tags.cs
// Docker image tag generator — .NET 10 file-based app (top-level statements).
//
// Usage:
//   dotnet run generate-tags.cs -- [options]
//
// Options:
//   --branch <name>      Git branch name (required)
//   --sha <sha>          Full commit SHA (required)
//   --tag <tag>          Git tag (can be repeated for multiple tags)
//   --pr <number>        Pull request number (optional)
//
// Examples:
//   dotnet run generate-tags.cs -- --branch main --sha abc1234567890
//   dotnet run generate-tags.cs -- --branch feature/my-feature --sha abc1234567890
//   dotnet run generate-tags.cs -- --branch main --sha abc1234567890 --tag v1.2.3
//   dotnet run generate-tags.cs -- --branch feature/my-feature --sha abc1234567890 --pr 42

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

// ─── Domain types ─────────────────────────────────────────────────────────────

/// <summary>
/// Represents the git context used to determine appropriate Docker image tags.
/// </summary>
record GitContext(
    string BranchName,
    string CommitSha,
    string[] Tags,
    int? PrNumber
);

// ─── Tag generation logic ─────────────────────────────────────────────────────

static class DockerTagGeneratorService
{
    static readonly Regex SemverPattern = new(@"^v\d+\.\d+\.\d+", RegexOptions.Compiled);
    static readonly Regex InvalidTagChars = new(@"[^a-z0-9._-]", RegexOptions.Compiled);
    static readonly Regex MultipleHyphens = new(@"-{2,}", RegexOptions.Compiled);

    /// <summary>Generates Docker image tags from git context.</summary>
    public static List<string> GenerateTags(GitContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        var tags = new HashSet<string>();
        string shortSha = GetShortSha(context.CommitSha);

        // PR builds → pr-{number}
        if (context.PrNumber.HasValue)
            tags.Add($"pr-{context.PrNumber.Value}");

        // Semver git tags → v{semver}
        foreach (var gitTag in context.Tags)
            if (SemverPattern.IsMatch(gitTag))
                tags.Add(SanitizeTag(gitTag));

        // Main/master branch → latest + main-{sha}
        if (IsMainBranch(context.BranchName))
        {
            tags.Add("latest");
            tags.Add($"main-{shortSha}");
        }
        else if (!context.PrNumber.HasValue)
        {
            // Feature branches → {branch}-{sha}
            string sanitized = SanitizeBranchName(context.BranchName);
            if (!string.IsNullOrEmpty(sanitized))
                tags.Add($"{sanitized}-{shortSha}");
        }

        return tags.OrderBy(t => t).ToList();
    }

    public static string GetShortSha(string sha)
    {
        if (string.IsNullOrEmpty(sha))
            throw new ArgumentException("Commit SHA cannot be null or empty.", nameof(sha));
        return sha.Length >= 7 ? sha[..7].ToLowerInvariant() : sha.ToLowerInvariant();
    }

    public static string SanitizeTag(string tag)
    {
        if (string.IsNullOrEmpty(tag)) return tag;
        string r = tag.ToLowerInvariant();
        r = InvalidTagChars.Replace(r, "-");
        r = MultipleHyphens.Replace(r, "-");
        return r.Trim('-');
    }

    public static string SanitizeBranchName(string branch)
    {
        if (string.IsNullOrEmpty(branch)) return branch;
        string r = branch.ToLowerInvariant().Replace('/', '-');
        r = InvalidTagChars.Replace(r, "-");
        r = MultipleHyphens.Replace(r, "-");
        return r.Trim('-');
    }

    static bool IsMainBranch(string name) => name is "main" or "master";
}

// ─── CLI argument parsing ──────────────────────────────────────────────────────

static class CliArgs
{
    public static (string? branch, string? sha, List<string> tags, int? pr, bool help) Parse(string[] args)
    {
        string? branch = null, sha = null;
        int? pr = null;
        var tags = new List<string>();
        bool help = false;

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--branch" when i + 1 < args.Length:
                    branch = args[++i]; break;
                case "--sha" when i + 1 < args.Length:
                    sha = args[++i]; break;
                case "--tag" when i + 1 < args.Length:
                    tags.Add(args[++i]); break;
                case "--pr" when i + 1 < args.Length:
                    if (int.TryParse(args[++i], out int prNum)) pr = prNum;
                    else { Console.Error.WriteLine($"Invalid PR number: {args[i]}"); } break;
                case "--help": case "-h":
                    help = true; break;
            }
        }

        return (branch, sha, tags, pr, help);
    }
}

// ─── Entry point ──────────────────────────────────────────────────────────────

const string Usage = """
Docker Image Tag Generator
Usage: dotnet run generate-tags.cs -- [options]

Options:
  --branch <name>   Git branch name (required)
  --sha <sha>       Full commit SHA (required)
  --tag <tag>       Git tag (repeatable)
  --pr <number>     Pull request number (optional)
  --help            Show this help message

Examples:
  dotnet run generate-tags.cs -- --branch main --sha abc1234567890
  dotnet run generate-tags.cs -- --branch feature/my-feature --sha def5678 --pr 42
  dotnet run generate-tags.cs -- --branch main --sha abc1234567890 --tag v1.2.3
""";

var (branch, sha, gitTags, pr, help) = CliArgs.Parse(args);

if (help)
{
    Console.WriteLine(Usage);
    return 0;
}

if (string.IsNullOrEmpty(branch))
{
    Console.Error.WriteLine("Error: --branch is required.");
    Console.Error.WriteLine(Usage);
    return 1;
}

if (string.IsNullOrEmpty(sha))
{
    Console.Error.WriteLine("Error: --sha is required.");
    Console.Error.WriteLine(Usage);
    return 1;
}

try
{
    var ctx = new GitContext(branch, sha, gitTags.ToArray(), pr);
    var tags = DockerTagGeneratorService.GenerateTags(ctx);

    Console.WriteLine("Generated Docker image tags:");
    foreach (var tag in tags)
        Console.WriteLine($"  {tag}");

    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}
