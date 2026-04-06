// ChangelogGenerator — produces a Keep-a-Changelog-style markdown section
// for a new release.
// GREEN phase: minimum implementation to make ChangelogGeneratorTests pass.

using System.Text;

namespace VersionBumper;

/// <summary>
/// Generates a markdown changelog entry for a release.
///
/// Output format follows Keep a Changelog (https://keepachangelog.com/):
///
///   ## [MAJOR.MINOR.PATCH] - YYYY-MM-DD
///
///   ### BREAKING CHANGES
///   - **scope**: description ⚠️ BREAKING
///
///   ### Features
///   - **scope**: description
///
///   ### Bug Fixes
///   - description
///
/// Only sections that have commits are included.
/// </summary>
public static class ChangelogGenerator
{
    /// <summary>
    /// Generate a changelog entry.
    /// </summary>
    /// <param name="version">The new version being released.</param>
    /// <param name="commits">Parsed commits included in this release.</param>
    /// <param name="date">Release date (defaults to UTC today if null).</param>
    public static string Generate(
        SemanticVersion version,
        IEnumerable<Commit> commits,
        DateTime? date = null)
    {
        var releaseDate = date ?? DateTime.UtcNow;
        var commitList = commits.ToList();

        var sb = new StringBuilder();
        sb.AppendLine($"## [{version}] - {releaseDate:yyyy-MM-dd}");

        // Partition commits into categories
        var breaking  = commitList.Where(c => c.IsBreaking).ToList();
        var features  = commitList.Where(c => !c.IsBreaking && c.Type == "feat").ToList();
        var fixes     = commitList.Where(c => !c.IsBreaking && c.Type == "fix").ToList();
        var other     = commitList.Where(c => !c.IsBreaking
                                           && c.Type != "feat"
                                           && c.Type != "fix"
                                           && c.Type != "other").ToList();

        AppendSection(sb, "BREAKING CHANGES", breaking);
        AppendSection(sb, "Features",         features);
        AppendSection(sb, "Bug Fixes",        fixes);
        AppendSection(sb, "Other Changes",    other);

        return sb.ToString().TrimEnd() + Environment.NewLine;
    }

    // ─────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────

    private static void AppendSection(StringBuilder sb, string title, List<Commit> commits)
    {
        if (commits.Count == 0) return;

        sb.AppendLine();
        sb.AppendLine($"### {title}");
        sb.AppendLine();
        foreach (var commit in commits)
            sb.AppendLine($"- {FormatCommit(commit)}");
    }

    private static string FormatCommit(Commit commit)
    {
        // Prefix with bold scope if present
        var prefix = commit.Scope is not null ? $"**{commit.Scope}**: " : string.Empty;
        // Append a visual warning marker for breaking changes
        var suffix = commit.IsBreaking ? " ⚠️ BREAKING" : string.Empty;
        return $"{prefix}{commit.Description}{suffix}";
    }
}
