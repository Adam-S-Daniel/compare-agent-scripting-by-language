// Integration tests — verify the full end-to-end workflow using temp files
// and the mock commit fixture (Fixtures/commits.json).
// (Namespaces imported via GlobalUsings.cs: VersionBumper, System.Text.Json, Xunit)

namespace VersionBumper.Tests;

/// <summary>
/// End-to-end integration tests covering the complete version-bump workflow:
///   1. Read version from file
///   2. Analyze commits from fixture
///   3. Bump version
///   4. Write updated file
///   5. Generate changelog
/// </summary>
public class IntegrationTests
{
    // ─────────────────────────────────────────────────────
    // Helper: load commit fixture
    // ─────────────────────────────────────────────────────

    private static string[] LoadFixtureCommits()
    {
        var path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Fixtures", "commits.json");
        var json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<string[]>(json)
               ?? throw new InvalidOperationException("commits.json is empty or invalid");
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration: Full workflow with version.txt
    // ─────────────────────────────────────────────────────

    [Fact]
    public async Task FullWorkflow_VersionTxt_WithFeatCommit_BumpsMinor()
    {
        var tmpFile = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.txt");
        try
        {
            await File.WriteAllTextAsync(tmpFile, "1.2.3");

            var commits = new[] { "feat: add dark mode support", "fix: correct button alignment" };
            var currentVersion = await VersionParser.ParseFileAsync(tmpFile);
            var bumpType = CommitAnalyzer.AnalyzeCommits(commits);
            var nextVersion = VersionBumperService.Bump(currentVersion, bumpType);

            await VersionParser.UpdateFileAsync(tmpFile, nextVersion);
            var updatedContent = await File.ReadAllTextAsync(tmpFile);

            Assert.Equal("1.3.0", updatedContent.Trim());
            Assert.Equal(BumpType.Minor, bumpType);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public async Task FullWorkflow_PackageJson_WithBreakingCommit_BumpsMajor()
    {
        var tmpFile = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}_package.json");
        try
        {
            var initialJson = """{"name":"my-app","version":"2.4.1","private":true}""";
            await File.WriteAllTextAsync(tmpFile, initialJson);

            var commits = new[] { "fix: handle edge case", "feat!: redesign API" };
            var currentVersion = await VersionParser.ParseFileAsync(tmpFile);
            var bumpType = CommitAnalyzer.AnalyzeCommits(commits);
            var nextVersion = VersionBumperService.Bump(currentVersion, bumpType);

            await VersionParser.UpdateFileAsync(tmpFile, nextVersion);

            var updatedVersion = await VersionParser.ParseFileAsync(tmpFile);
            Assert.Equal(new SemanticVersion(3, 0, 0), updatedVersion);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration: Changelog generation in full workflow
    // ─────────────────────────────────────────────────────

    [Fact]
    public void FullWorkflow_GeneratesChangelogWithAllSections()
    {
        var commits = new[]
        {
            "feat: add user authentication",
            "fix: resolve null reference in login handler",
            "fix: correct email validation regex",
            "feat!: redesign API response format",
            "chore: update dependencies"
        };

        var currentVersion = new SemanticVersion(1, 5, 2);
        var parsedCommits = CommitAnalyzer.ParseCommits(commits);
        var bumpType = CommitAnalyzer.AnalyzeCommits(commits);
        var nextVersion = VersionBumperService.Bump(currentVersion, bumpType);
        var changelog = ChangelogGenerator.Generate(nextVersion, parsedCommits, new DateTime(2026, 4, 5));

        Assert.Equal(new SemanticVersion(2, 0, 0), nextVersion);
        Assert.Contains("## [2.0.0]", changelog);
        Assert.Contains("### BREAKING CHANGES", changelog);
        Assert.Contains("### Features", changelog);
        Assert.Contains("### Bug Fixes", changelog);
        Assert.Contains("add user authentication", changelog);
        Assert.Contains("resolve null reference in login handler", changelog);
        Assert.Contains("redesign API response format", changelog);
    }

    // ─────────────────────────────────────────────────────
    // TDD Iteration: Load commits from fixture file
    // ─────────────────────────────────────────────────────

    [Fact]
    public void FixtureCommits_AreLoadedAndAnalyzedCorrectly()
    {
        var commits = LoadFixtureCommits();

        // Fixture contains breaking changes — should be Major
        var bumpType = CommitAnalyzer.AnalyzeCommits(commits);

        Assert.NotEmpty(commits);
        Assert.Equal(BumpType.Major, bumpType); // fixture has breaking commits
    }

    [Fact]
    public void FixtureCommits_ParsedCommitsContainExpectedTypes()
    {
        var commitMessages = LoadFixtureCommits();
        var commits = CommitAnalyzer.ParseCommits(commitMessages);

        Assert.Contains(commits, c => c.Type == "feat");
        Assert.Contains(commits, c => c.Type == "fix");
        Assert.Contains(commits, c => c.IsBreaking);
    }

    [Fact]
    public async Task FullWorkflow_WithFixtureFile_ProducesValidChangelog()
    {
        var tmpFile = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.txt");
        try
        {
            await File.WriteAllTextAsync(tmpFile, "1.0.0");

            var commitMessages = LoadFixtureCommits();
            var currentVersion = await VersionParser.ParseFileAsync(tmpFile);
            var parsedCommits = CommitAnalyzer.ParseCommits(commitMessages);
            var bumpType = CommitAnalyzer.AnalyzeCommits(commitMessages);
            var nextVersion = VersionBumperService.Bump(currentVersion, bumpType);

            await VersionParser.UpdateFileAsync(tmpFile, nextVersion);
            var changelog = ChangelogGenerator.Generate(nextVersion, parsedCommits, new DateTime(2026, 4, 5));

            // After a major bump from 1.0.0 we expect 2.0.0
            Assert.Equal(new SemanticVersion(2, 0, 0), nextVersion);
            Assert.Contains("## [2.0.0]", changelog);
            Assert.NotEmpty(changelog);

            var updatedContent = await File.ReadAllTextAsync(tmpFile);
            Assert.Equal("2.0.0", updatedContent.Trim());
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }
}
