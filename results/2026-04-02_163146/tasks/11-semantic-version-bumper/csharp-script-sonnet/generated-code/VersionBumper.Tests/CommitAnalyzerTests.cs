// TDD RED phase: Tests for CommitAnalyzer — written before implementation.
// These cover parsing conventional commit messages and determining the bump type.
// (Namespaces imported via GlobalUsings.cs: VersionBumper, Xunit)

namespace VersionBumper.Tests;

/// <summary>
/// Tests for CommitAnalyzer — conventional commit parsing and bump-type determination.
/// TDD iterations:
///   1. Parse individual commits (type, scope, description, breaking flag)
///   2. Determine bump type per commit type
///   3. Analyze multiple commits — highest bump wins
///   4. Breaking-change detection via "!" and "BREAKING CHANGE:" body
/// </summary>
public class CommitAnalyzerTests
{
    // ─────────────────────────────────────────────────────
    // TDD Iteration 1: Parse individual commit messages
    // ─────────────────────────────────────────────────────

    [Fact]
    public void ParseCommit_FeatCommit_ReturnsCorrectType()
    {
        var commit = CommitAnalyzer.ParseCommit("feat: add user authentication");

        Assert.Equal("feat", commit.Type);
        Assert.Equal("add user authentication", commit.Description);
        Assert.False(commit.IsBreaking);
        Assert.Null(commit.Scope);
    }

    [Fact]
    public void ParseCommit_FixWithScope_ReturnsTypeAndScope()
    {
        var commit = CommitAnalyzer.ParseCommit("fix(auth): resolve null reference in login");

        Assert.Equal("fix", commit.Type);
        Assert.Equal("auth", commit.Scope);
        Assert.Equal("resolve null reference in login", commit.Description);
        Assert.False(commit.IsBreaking);
    }

    [Fact]
    public void ParseCommit_FeatWithBreakingBang_SetsIsBreaking()
    {
        var commit = CommitAnalyzer.ParseCommit("feat!: redesign API response format");

        Assert.Equal("feat", commit.Type);
        Assert.True(commit.IsBreaking);
    }

    [Fact]
    public void ParseCommit_FixWithScopeAndBreakingBang_SetsIsBreaking()
    {
        var commit = CommitAnalyzer.ParseCommit("fix(api)!: remove deprecated parameter");

        Assert.Equal("fix", commit.Type);
        Assert.Equal("api", commit.Scope);
        Assert.True(commit.IsBreaking);
    }

    [Fact]
    public void ParseCommit_NonConventional_ReturnsOtherType()
    {
        var commit = CommitAnalyzer.ParseCommit("update some stuff in the codebase");

        Assert.Equal("other", commit.Type);
        Assert.False(commit.IsBreaking);
    }

    [Fact]
    public void ParseCommit_WithBreakingChangeInBody_SetsIsBreaking()
    {
        var message = "feat: new authentication flow\n\nBREAKING CHANGE: old tokens are invalidated";

        var commit = CommitAnalyzer.ParseCommit(message);

        Assert.Equal("feat", commit.Type);
        Assert.True(commit.IsBreaking);
    }

    [Fact]
    public void ParseCommit_ChoreCommit_ReturnsChoreType()
    {
        var commit = CommitAnalyzer.ParseCommit("chore: update dependencies");

        Assert.Equal("chore", commit.Type);
        Assert.False(commit.IsBreaking);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 2: Determine bump type per commit
    // ─────────────────────────────────────────────────────

    [Fact]
    public void AnalyzeCommits_SingleFix_ReturnsPatch()
    {
        var result = CommitAnalyzer.AnalyzeCommits(["fix: correct email validation"]);

        Assert.Equal(BumpType.Patch, result);
    }

    [Fact]
    public void AnalyzeCommits_SingleFeat_ReturnsMinor()
    {
        var result = CommitAnalyzer.AnalyzeCommits(["feat: add dark mode support"]);

        Assert.Equal(BumpType.Minor, result);
    }

    [Fact]
    public void AnalyzeCommits_BreakingFeat_ReturnsMajor()
    {
        var result = CommitAnalyzer.AnalyzeCommits(["feat!: redesign public API"]);

        Assert.Equal(BumpType.Major, result);
    }

    [Fact]
    public void AnalyzeCommits_BreakingChangeInBody_ReturnsMajor()
    {
        var messages = new[]
        {
            "feat: new auth\n\nBREAKING CHANGE: sessions are invalidated"
        };

        var result = CommitAnalyzer.AnalyzeCommits(messages);

        Assert.Equal(BumpType.Major, result);
    }

    [Fact]
    public void AnalyzeCommits_OnlyChore_ReturnsNone()
    {
        var result = CommitAnalyzer.AnalyzeCommits(["chore: update deps", "docs: fix typo"]);

        Assert.Equal(BumpType.None, result);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 3: Multiple commits — highest bump wins
    // ─────────────────────────────────────────────────────

    [Fact]
    public void AnalyzeCommits_MixedFeatAndFix_ReturnsMinor()
    {
        var messages = new[]
        {
            "fix: handle edge case",
            "feat: add rate limiting",
            "fix: correct button alignment"
        };

        var result = CommitAnalyzer.AnalyzeCommits(messages);

        Assert.Equal(BumpType.Minor, result);
    }

    [Fact]
    public void AnalyzeCommits_MixedWithBreaking_ReturnsMajor()
    {
        var messages = new[]
        {
            "feat: add user auth",
            "fix: resolve null ref",
            "feat!: redesign API response format",
            "fix: correct date parsing"
        };

        var result = CommitAnalyzer.AnalyzeCommits(messages);

        Assert.Equal(BumpType.Major, result);
    }

    [Fact]
    public void AnalyzeCommits_EmptyList_ReturnsNone()
    {
        var result = CommitAnalyzer.AnalyzeCommits([]);

        Assert.Equal(BumpType.None, result);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration 4: ParseCommits returns list of Commit records
    // ─────────────────────────────────────────────────────

    [Fact]
    public void ParseCommits_MultipleMessages_ReturnsAllCommits()
    {
        var messages = new[]
        {
            "feat: add auth",
            "fix: resolve bug",
            "chore: update deps"
        };

        var commits = CommitAnalyzer.ParseCommits(messages);

        Assert.Equal(3, commits.Count);
        Assert.Equal("feat", commits[0].Type);
        Assert.Equal("fix", commits[1].Type);
        Assert.Equal("chore", commits[2].Type);
    }

    [Fact]
    public void ParseCommit_UppercaseType_NormalizesToLowercase()
    {
        var commit = CommitAnalyzer.ParseCommit("FEAT: add something");

        Assert.Equal("feat", commit.Type);
    }
}
