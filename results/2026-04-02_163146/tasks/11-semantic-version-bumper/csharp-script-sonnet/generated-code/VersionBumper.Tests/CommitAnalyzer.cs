// CommitAnalyzer — parses conventional commit messages and determines the
// required version bump type.
// GREEN phase: minimum implementation to make CommitAnalyzerTests pass.

using System.Text.RegularExpressions;

namespace VersionBumper;

/// <summary>
/// Analyses a list of conventional commit messages to determine the required
/// <see cref="BumpType"/>.
///
/// Conventional Commits spec: https://www.conventionalcommits.org/
///   type(scope)!: description
///   [optional body containing "BREAKING CHANGE: ..."]
///
/// Bump rules:
///   BREAKING CHANGE (! or body keyword)  → Major
///   feat                                 → Minor
///   fix / perf                           → Patch
///   everything else                      → None
/// </summary>
public static class CommitAnalyzer
{
    // Matches:  type(optional scope)optional!: description
    // Groups:   type | scope | breaking | description
    private static readonly Regex ConventionalPattern = new(
        @"^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?\s*:\s*(?<description>.+)$",
        RegexOptions.Compiled);

    // Matches "BREAKING CHANGE:" or "BREAKING-CHANGE:" anywhere in the message body
    private static readonly Regex BreakingBodyPattern = new(
        @"BREAKING[\s\-]CHANGE\s*:",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    // ─────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────

    /// <summary>
    /// Parse a single conventional commit message into a <see cref="Commit"/> record.
    /// Non-conventional messages are returned with Type = "other".
    /// </summary>
    public static Commit ParseCommit(string message)
    {
        if (string.IsNullOrWhiteSpace(message))
            return new Commit("other", message ?? "", false, Body: message);

        // The conventional commit subject is always the first line
        var firstLine = message.Split('\n')[0].Trim();
        var match = ConventionalPattern.Match(firstLine);

        if (!match.Success)
            return new Commit("other", firstLine, false, Body: message);

        var type        = match.Groups["type"].Value.ToLowerInvariant();
        var scope       = match.Groups["scope"].Success ? match.Groups["scope"].Value : null;
        var description = match.Groups["description"].Value.Trim();

        // Breaking if "!" appears after the type/scope OR "BREAKING CHANGE:" is in the body
        var isBreaking = match.Groups["breaking"].Success
                      || BreakingBodyPattern.IsMatch(message);

        return new Commit(type, description, isBreaking, scope, message);
    }

    /// <summary>
    /// Parse a collection of commit messages into <see cref="Commit"/> records.
    /// </summary>
    public static IReadOnlyList<Commit> ParseCommits(IEnumerable<string> messages)
        => messages.Select(ParseCommit).ToList().AsReadOnly();

    /// <summary>
    /// Analyse a collection of commit messages and return the highest
    /// <see cref="BumpType"/> required.  Major > Minor > Patch > None.
    /// </summary>
    public static BumpType AnalyzeCommits(IEnumerable<string> messages)
    {
        var result = BumpType.None;

        foreach (var message in messages)
        {
            var commit    = ParseCommit(message);
            var commitBump = GetBumpType(commit);

            // Keep the highest bump encountered
            if (commitBump > result)
                result = commitBump;

            // Short-circuit: nothing can exceed Major
            if (result == BumpType.Major)
                return result;
        }

        return result;
    }

    // ─────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────

    private static BumpType GetBumpType(Commit commit)
    {
        // Breaking change always wins regardless of type
        if (commit.IsBreaking)
            return BumpType.Major;

        return commit.Type switch
        {
            "feat"  => BumpType.Minor,
            "fix"   => BumpType.Patch,
            "perf"  => BumpType.Patch, // performance fixes are patch-level
            _       => BumpType.None   // chore, docs, style, test, refactor, etc.
        };
    }
}
