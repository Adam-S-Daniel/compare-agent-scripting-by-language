// DockerTagGenerator.cs
// Core library for generating Docker image tags from git context.
// This file contains the domain logic, separated for testability.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace DockerTagGenerator;

/// <summary>
/// Represents the git context used to determine appropriate Docker image tags.
/// </summary>
public record GitContext(
    string BranchName,
    string CommitSha,
    string[] Tags,
    int? PrNumber
);

/// <summary>
/// Generates Docker image tags following common conventions:
/// - "latest" for the main branch
/// - "pr-{number}" for pull requests
/// - "v{semver}" for semantic version tags
/// - "{branch}-{short-sha}" for feature branches
///
/// All tags are sanitized to be lowercase and contain only alphanumeric characters, hyphens, and dots.
/// </summary>
public static class DockerTagGeneratorService
{
    // Semver pattern: vMAJOR.MINOR.PATCH with optional pre-release/build metadata
    private static readonly Regex SemverPattern = new(@"^v\d+\.\d+\.\d+", RegexOptions.Compiled);

    // Characters allowed in Docker tags: [a-zA-Z0-9_.-]
    // We'll normalize to lowercase and replace invalid chars with hyphens
    private static readonly Regex InvalidTagChars = new(@"[^a-z0-9._-]", RegexOptions.Compiled);

    // Multiple consecutive hyphens/dots should be collapsed
    private static readonly Regex MultipleHyphens = new(@"-{2,}", RegexOptions.Compiled);

    /// <summary>
    /// Generates a list of Docker image tags for the given git context.
    /// </summary>
    public static List<string> GenerateTags(GitContext context)
    {
        if (context == null)
            throw new ArgumentNullException(nameof(context));

        var tags = new HashSet<string>();

        string shortSha = GetShortSha(context.CommitSha);

        // Rule 1: PR builds get pr-{number} tag
        if (context.PrNumber.HasValue)
        {
            tags.Add($"pr-{context.PrNumber.Value}");
        }

        // Rule 2: Semver tags get v{semver} tag (e.g., v1.2.3)
        foreach (var gitTag in context.Tags)
        {
            if (SemverPattern.IsMatch(gitTag))
            {
                tags.Add(SanitizeTag(gitTag));
            }
        }

        // Rule 3: Main/master branch gets "latest"
        if (IsMainBranch(context.BranchName))
        {
            tags.Add("latest");
            tags.Add($"main-{shortSha}");
        }
        else if (!context.PrNumber.HasValue)
        {
            // Rule 4: Feature branches get {branch}-{short-sha}
            string sanitizedBranch = SanitizeBranchName(context.BranchName);
            if (!string.IsNullOrEmpty(sanitizedBranch))
            {
                tags.Add($"{sanitizedBranch}-{shortSha}");
            }
        }

        return tags.OrderBy(t => t).ToList();
    }

    /// <summary>
    /// Returns the first 7 characters of a commit SHA (short SHA convention).
    /// </summary>
    public static string GetShortSha(string commitSha)
    {
        if (string.IsNullOrEmpty(commitSha))
            throw new ArgumentException("Commit SHA cannot be null or empty.", nameof(commitSha));

        return commitSha.Length >= 7 ? commitSha[..7].ToLowerInvariant() : commitSha.ToLowerInvariant();
    }

    /// <summary>
    /// Sanitizes a tag string: lowercase, replace invalid chars with hyphens,
    /// collapse multiple hyphens, trim leading/trailing hyphens.
    /// </summary>
    public static string SanitizeTag(string tag)
    {
        if (string.IsNullOrEmpty(tag))
            return tag;

        string result = tag.ToLowerInvariant();
        result = InvalidTagChars.Replace(result, "-");
        result = MultipleHyphens.Replace(result, "-");
        result = result.Trim('-');
        return result;
    }

    /// <summary>
    /// Sanitizes a branch name for use in a Docker tag.
    /// Slashes (e.g., feature/my-feature) become hyphens.
    /// </summary>
    public static string SanitizeBranchName(string branchName)
    {
        if (string.IsNullOrEmpty(branchName))
            return branchName;

        string result = branchName.ToLowerInvariant();
        // Replace slashes with hyphens first
        result = result.Replace('/', '-');
        result = InvalidTagChars.Replace(result, "-");
        result = MultipleHyphens.Replace(result, "-");
        result = result.Trim('-');
        return result;
    }

    private static bool IsMainBranch(string branchName) =>
        branchName is "main" or "master";
}
