// TDD RED phase: Tests for VersionBumperService — version arithmetic.
// Written before the implementation class exists.
// (Namespaces imported via GlobalUsings.cs: VersionBumper, Xunit)

namespace VersionBumper.Tests;

/// <summary>
/// Tests for VersionBumperService — calculates next version from bump type.
/// TDD iterations:
///   1. Patch bump increments patch and resets nothing
///   2. Minor bump increments minor and resets patch to 0
///   3. Major bump increments major and resets minor+patch to 0
///   4. None bump returns same version unchanged
/// </summary>
public class VersionBumperServiceTests
{
    // ─────────────────────────────────────────────────────
    // TDD Iteration 1: Patch bump
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Bump_PatchOnVersion100_Returns101()
    {
        var current = new SemanticVersion(1, 0, 0);

        var next = VersionBumperService.Bump(current, BumpType.Patch);

        Assert.Equal(new SemanticVersion(1, 0, 1), next);
    }

    [Fact]
    public void Bump_PatchOnVersion123_Returns124()
    {
        var current = new SemanticVersion(1, 2, 3);

        var next = VersionBumperService.Bump(current, BumpType.Patch);

        Assert.Equal(new SemanticVersion(1, 2, 4), next);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 2: Minor bump resets patch
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Bump_MinorOnVersion100_Returns110()
    {
        var current = new SemanticVersion(1, 0, 0);

        var next = VersionBumperService.Bump(current, BumpType.Minor);

        Assert.Equal(new SemanticVersion(1, 1, 0), next);
    }

    [Fact]
    public void Bump_MinorOnVersion123_Returns130()
    {
        var current = new SemanticVersion(1, 2, 3);

        var next = VersionBumperService.Bump(current, BumpType.Minor);

        // patch is reset to 0
        Assert.Equal(new SemanticVersion(1, 3, 0), next);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 3: Major bump resets minor and patch
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Bump_MajorOnVersion100_Returns200()
    {
        var current = new SemanticVersion(1, 0, 0);

        var next = VersionBumperService.Bump(current, BumpType.Major);

        Assert.Equal(new SemanticVersion(2, 0, 0), next);
    }

    [Fact]
    public void Bump_MajorOnVersion123_Returns200()
    {
        var current = new SemanticVersion(1, 2, 3);

        var next = VersionBumperService.Bump(current, BumpType.Major);

        // minor and patch both reset to 0
        Assert.Equal(new SemanticVersion(2, 0, 0), next);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 4: None returns same version
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Bump_NoneOnVersion123_ReturnsSameVersion()
    {
        var current = new SemanticVersion(1, 2, 3);

        var next = VersionBumperService.Bump(current, BumpType.None);

        Assert.Equal(current, next);
    }

    // ─────────────────────────────────────────────────────
    // ToString / equality helpers
    // ─────────────────────────────────────────────────────

    [Fact]
    public void SemanticVersion_ToString_ReturnsDotSeparated()
    {
        var version = new SemanticVersion(2, 10, 5);

        Assert.Equal("2.10.5", version.ToString());
    }

    [Fact]
    public void SemanticVersion_Equality_SameValuesAreEqual()
    {
        var v1 = new SemanticVersion(1, 2, 3);
        var v2 = new SemanticVersion(1, 2, 3);

        Assert.Equal(v1, v2);
    }
}
