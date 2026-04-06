// TagGenerator: Core logic for generating Docker image tags from git context.
// Follows common CI/CD conventions:
//   - "latest" for main/master branches
//   - "pr-{number}" for pull requests
//   - "v{semver}" for semver tags
//   - "{branch}-{short-sha}" for feature branches
//   - All tags are sanitized: lowercase, alphanumeric + hyphens + dots only

using System.Text.RegularExpressions;

namespace DockerTagGenerator;

public static partial class TagGenerator
{
    // Docker tag rules: lowercase alphanumeric, hyphens, dots, max 128 chars.
    // We strip anything else and collapse repeated separators.
    [GeneratedRegex("[^a-z0-9._-]")]
    private static partial Regex InvalidTagCharsRegex();

    [GeneratedRegex("[-_.]{2,}")]
    private static partial Regex RepeatedSeparatorsRegex();

    /// <summary>
    /// Sanitize a string for use as a Docker image tag.
    /// Converts to lowercase, replaces invalid chars with hyphens,
    /// collapses repeated separators, trims separators from edges,
    /// and truncates to 128 chars.
    /// </summary>
    public static string SanitizeTag(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
            throw new ArgumentException("Tag input must not be empty.", nameof(input));

        // Lowercase first
        var tag = input.ToLowerInvariant();

        // Replace invalid characters with hyphens
        tag = InvalidTagCharsRegex().Replace(tag, "-");

        // Collapse repeated separators (e.g., "--" → "-")
        tag = RepeatedSeparatorsRegex().Replace(tag, match => match.Value[..1].ToString());

        // Trim leading/trailing separators
        tag = tag.Trim('-', '.', '_');

        // Docker tags have a 128-char limit
        if (tag.Length > 128)
            tag = tag[..128].TrimEnd('-', '.', '_');

        if (tag.Length == 0)
            throw new ArgumentException($"Tag '{input}' sanitizes to an empty string.", nameof(input));

        return tag;
    }

    /// <summary>
    /// Generate Docker image tags from the given git context.
    /// Returns a list of tags following common conventions.
    /// </summary>
    public static List<string> GenerateTags(GitContext context)
    {
        if (context is null)
            throw new ArgumentNullException(nameof(context));

        if (string.IsNullOrWhiteSpace(context.CommitSha))
            throw new ArgumentException("CommitSha is required.", nameof(context));

        var tags = new List<string>();

        // 1. If this is a PR build, add pr-{number} tag
        if (context.PrNumber.HasValue)
        {
            tags.Add($"pr-{context.PrNumber.Value}");
        }

        // 2. If there are semver tags, add them (sanitized)
        foreach (var gitTag in context.Tags ?? Array.Empty<string>())
        {
            if (IsSemverTag(gitTag))
            {
                // Keep the "v" prefix if present, sanitize the rest
                tags.Add(SanitizeTag(gitTag));
            }
        }

        // 3. If on main/master, add "latest"
        if (IsDefaultBranch(context.BranchName))
        {
            tags.Add("latest");
        }

        // 4. Always add {branch}-{short-sha} tag (sanitized)
        if (!string.IsNullOrWhiteSpace(context.BranchName))
        {
            var branchTag = SanitizeTag($"{context.BranchName}-{context.ShortSha}");
            tags.Add(branchTag);
        }

        return tags;
    }

    /// <summary>
    /// Check if a branch name is the default branch (main or master).
    /// </summary>
    public static bool IsDefaultBranch(string branchName) =>
        string.Equals(branchName, "main", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(branchName, "master", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Check if a git tag looks like a semantic version (v1.2.3, 1.2.3, v1.0.0-beta.1, etc.).
    /// </summary>
    public static bool IsSemverTag(string tag) =>
        Regex.IsMatch(tag, @"^v?\d+\.\d+\.\d+(-[\w.]+)?(\+[\w.]+)?$", RegexOptions.IgnoreCase);
}
