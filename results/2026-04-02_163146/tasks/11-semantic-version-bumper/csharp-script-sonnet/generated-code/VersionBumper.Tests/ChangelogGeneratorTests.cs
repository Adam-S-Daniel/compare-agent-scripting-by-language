// TDD RED phase: Tests for ChangelogGenerator — written before implementation.
// (Namespaces imported via GlobalUsings.cs: VersionBumper, Xunit)

namespace VersionBumper.Tests;

/// <summary>
/// Tests for ChangelogGenerator — markdown changelog entry generation.
/// TDD iterations:
///   1. Basic structure (header with version and date)
///   2. Features section
///   3. Bug fixes section
///   4. Breaking changes section
///   5. Mixed commits grouped correctly
///   6. Commits with scopes
/// </summary>
public class ChangelogGeneratorTests
{
    private static readonly DateTime FixedDate = new(2026, 4, 5);

    // ─────────────────────────────────────────────────────
    // TDD Iteration 1: Header format
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Generate_AnyCommits_IncludesVersionHeader()
    {
        var commits = new[] { new Commit("fix", "patch something", false) };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(1, 0, 1), commits, FixedDate);

        Assert.Contains("## [1.0.1]", changelog);
        Assert.Contains("2026-04-05", changelog);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 2: Features section
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Generate_WithFeatCommit_IncludesFeaturesSection()
    {
        var commits = new[] { new Commit("feat", "add dark mode support", false) };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(1, 1, 0), commits, FixedDate);

        Assert.Contains("### Features", changelog);
        Assert.Contains("add dark mode support", changelog);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 3: Bug fixes section
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Generate_WithFixCommit_IncludesBugFixesSection()
    {
        var commits = new[] { new Commit("fix", "resolve null reference in login", false) };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(1, 0, 1), commits, FixedDate);

        Assert.Contains("### Bug Fixes", changelog);
        Assert.Contains("resolve null reference in login", changelog);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 4: Breaking changes section
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Generate_WithBreakingCommit_IncludesBreakingSection()
    {
        var commits = new[] { new Commit("feat", "redesign API response format", IsBreaking: true) };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(2, 0, 0), commits, FixedDate);

        Assert.Contains("### BREAKING CHANGES", changelog);
        Assert.Contains("redesign API response format", changelog);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 5: Mixed commits grouped correctly
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Generate_MixedCommits_GroupsByCategory()
    {
        var commits = new Commit[]
        {
            new("feat", "add user authentication", false),
            new("fix", "resolve null reference", false),
            new("feat", "add rate limiting", IsBreaking: true)
        };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(2, 0, 0), commits, FixedDate);

        // Breaking changes appear before features
        var breakingPos = changelog.IndexOf("### BREAKING CHANGES", StringComparison.Ordinal);
        var featuresPos = changelog.IndexOf("### Features", StringComparison.Ordinal);
        var fixesPos = changelog.IndexOf("### Bug Fixes", StringComparison.Ordinal);

        Assert.True(breakingPos < featuresPos, "Breaking should come before features");
        Assert.True(featuresPos < fixesPos, "Features should come before bug fixes");

        Assert.Contains("add user authentication", changelog);
        Assert.Contains("resolve null reference", changelog);
        Assert.Contains("add rate limiting", changelog);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 6: Commits with scopes
    // ─────────────────────────────────────────────────────

    [Fact]
    public void Generate_CommitWithScope_IncludesScopeInEntry()
    {
        var commits = new[] { new Commit("fix", "correct button alignment on mobile", false, Scope: "ui") };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(1, 0, 1), commits, FixedDate);

        // scope should appear bolded in output
        Assert.Contains("ui", changelog);
        Assert.Contains("correct button alignment on mobile", changelog);
    }

    [Fact]
    public void Generate_EmptyCommits_ReturnsHeaderOnly()
    {
        var changelog = ChangelogGenerator.Generate(new SemanticVersion(1, 0, 0), [], FixedDate);

        Assert.Contains("## [1.0.0]", changelog);
        Assert.DoesNotContain("### Features", changelog);
        Assert.DoesNotContain("### Bug Fixes", changelog);
    }

    [Fact]
    public void Generate_OnlyChoreCommits_NoSectionsExceptHeader()
    {
        var commits = new[] { new Commit("chore", "update dependencies", false) };

        var changelog = ChangelogGenerator.Generate(new SemanticVersion(1, 0, 1), commits, FixedDate);

        Assert.Contains("## [1.0.1]", changelog);
        Assert.DoesNotContain("### Features", changelog);
        Assert.DoesNotContain("### Bug Fixes", changelog);
    }
}
