// Domain models for the semantic version bumper.
// These are the core types shared across all components.

namespace VersionBumper;

/// <summary>
/// Immutable semantic version (MAJOR.MINOR.PATCH).
/// Uses record for value equality — two SemanticVersion instances
/// with the same numbers are considered equal.
/// </summary>
public record SemanticVersion(int Major, int Minor, int Patch)
{
    /// <summary>Returns "MAJOR.MINOR.PATCH" string representation.</summary>
    public override string ToString() => $"{Major}.{Minor}.{Patch}";

    /// <summary>
    /// Parse a "MAJOR.MINOR.PATCH" string into a SemanticVersion.
    /// Throws <see cref="FormatException"/> if the input is not a valid semver.
    /// </summary>
    public static SemanticVersion Parse(string version)
    {
        if (string.IsNullOrWhiteSpace(version))
            throw new FormatException($"Invalid semantic version: '{version}'. Value cannot be empty.");

        var trimmed = version.Trim();
        var parts = trimmed.Split('.');

        if (parts.Length != 3)
            throw new FormatException(
                $"Invalid semantic version: '{trimmed}'. Expected format: MAJOR.MINOR.PATCH (got {parts.Length} part(s)).");

        if (!int.TryParse(parts[0], out var major) ||
            !int.TryParse(parts[1], out var minor) ||
            !int.TryParse(parts[2], out var patch))
            throw new FormatException(
                $"Invalid semantic version: '{trimmed}'. All parts must be non-negative integers.");

        if (major < 0 || minor < 0 || patch < 0)
            throw new FormatException(
                $"Invalid semantic version: '{trimmed}'. Version numbers cannot be negative.");

        return new SemanticVersion(major, minor, patch);
    }
}

/// <summary>
/// The type of version bump to apply, ordered from least to greatest impact.
/// Higher enum values override lower ones when combining multiple commits.
/// </summary>
public enum BumpType
{
    None  = 0, // No releasable commits (chore, docs, etc.)
    Patch = 1, // fix: — backwards-compatible bug fixes
    Minor = 2, // feat: — backwards-compatible new features
    Major = 3  // BREAKING CHANGE / "!" — incompatible API changes
}

/// <summary>
/// A parsed conventional commit message.
/// See https://www.conventionalcommits.org/
/// </summary>
public record Commit(
    string Type,          // e.g. "feat", "fix", "chore"
    string Description,   // The commit subject line (after the colon)
    bool IsBreaking,      // True if "!" suffix or "BREAKING CHANGE:" in body
    string? Scope = null, // Optional scope e.g. feat(api):
    string? Body = null   // Full raw message (subject + body)
);
