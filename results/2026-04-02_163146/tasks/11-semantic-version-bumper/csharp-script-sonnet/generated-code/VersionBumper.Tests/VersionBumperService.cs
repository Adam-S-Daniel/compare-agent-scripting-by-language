// VersionBumperService — pure arithmetic for calculating the next semver.
// GREEN phase: minimum implementation to make VersionBumperServiceTests pass.

namespace VersionBumper;

/// <summary>
/// Calculates the next <see cref="SemanticVersion"/> from the current version
/// and a <see cref="BumpType"/>.
///
/// Semver bump rules:
///   Major → increment MAJOR, reset MINOR and PATCH to 0
///   Minor → increment MINOR, reset PATCH to 0 (MAJOR unchanged)
///   Patch → increment PATCH (MAJOR and MINOR unchanged)
///   None  → return the same version (no releasable changes)
/// </summary>
public static class VersionBumperService
{
    /// <summary>
    /// Return the next version after applying <paramref name="bumpType"/>.
    /// </summary>
    public static SemanticVersion Bump(SemanticVersion current, BumpType bumpType) =>
        bumpType switch
        {
            BumpType.Major => new SemanticVersion(current.Major + 1, 0, 0),
            BumpType.Minor => new SemanticVersion(current.Major, current.Minor + 1, 0),
            BumpType.Patch => new SemanticVersion(current.Major, current.Minor, current.Patch + 1),
            BumpType.None  => current,
            _              => throw new ArgumentOutOfRangeException(
                                  nameof(bumpType), bumpType, $"Unknown BumpType: {bumpType}")
        };
}
