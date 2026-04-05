// TDD tests for PR Label Assigner
// Tests are organized by feature, following red/green/refactor progression.
// Each group of tests was written BEFORE the corresponding implementation code.

using Xunit;

namespace PrLabelAssigner.Tests;

// =============================================================================
// RED/GREEN CYCLE 1: Basic glob matching — single file, single rule
// =============================================================================
public class BasicGlobMatchingTests
{
    [Fact]
    public void SingleFile_MatchingDocsGlob_ReturnsDocumentationLabel()
    {
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };
        var changedFiles = new List<string> { "docs/readme.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("documentation", labels);
        Assert.Single(labels);
    }

    [Fact]
    public void SingleFile_NotMatchingGlob_ReturnsNoLabels()
    {
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };
        var changedFiles = new List<string> { "src/main.cs" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Empty(labels);
    }

    [Fact]
    public void NestedFile_MatchingDoubleStarGlob_ReturnsLabel()
    {
        // ** should match across multiple directory levels
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };
        var changedFiles = new List<string> { "docs/guides/getting-started/intro.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("documentation", labels);
    }
}

// =============================================================================
// RED/GREEN CYCLE 2: Multiple rules — a file can match multiple rules
// =============================================================================
public class MultipleLabelsPerFileTests
{
    [Fact]
    public void FileMatchingMultipleRules_ReturnsAllMatchingLabels()
    {
        // A test file under src/api/ should get both "api" and "tests" labels
        var rules = new List<LabelRule>
        {
            new("src/api/**", "api", Priority: 1),
            new("**/*.test.*", "tests", Priority: 2)
        };
        var changedFiles = new List<string> { "src/api/users.test.cs" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("api", labels);
        Assert.Contains("tests", labels);
        Assert.Equal(2, labels.Count);
    }

    [Fact]
    public void MultipleFiles_EachMatchingDifferentRules_ReturnsUnionOfLabels()
    {
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1),
            new("src/api/**", "api", Priority: 2),
            new("*.test.*", "tests", Priority: 3)
        };
        var changedFiles = new List<string>
        {
            "docs/readme.md",
            "src/api/controller.cs"
        };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("documentation", labels);
        Assert.Contains("api", labels);
        Assert.DoesNotContain("tests", labels);
        Assert.Equal(2, labels.Count);
    }
}

// =============================================================================
// RED/GREEN CYCLE 3: Glob pattern variations — *, **, ?.ext patterns
// =============================================================================
public class GlobPatternTests
{
    [Fact]
    public void StarDotExtension_MatchesFileWithExtension()
    {
        // *.test.* should match "foo.test.cs"
        var rules = new List<LabelRule>
        {
            new("*.test.*", "tests", Priority: 1)
        };
        var changedFiles = new List<string> { "utils.test.js" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("tests", labels);
    }

    [Fact]
    public void DoubleStarSlashStar_MatchesNestedFiles()
    {
        // src/api/** should match files in any subdirectory
        var rules = new List<LabelRule>
        {
            new("src/api/**", "api", Priority: 1)
        };
        var changedFiles = new List<string> { "src/api/v2/endpoints/users.cs" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("api", labels);
    }

    [Fact]
    public void SingleStar_DoesNotMatchAcrossDirectories()
    {
        // *.md should NOT match docs/readme.md (star doesn't cross directory boundaries)
        var rules = new List<LabelRule>
        {
            new("*.md", "markdown", Priority: 1)
        };
        var changedFiles = new List<string> { "docs/readme.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Empty(labels);
    }

    [Fact]
    public void SingleStar_MatchesFileInCurrentDirectory()
    {
        var rules = new List<LabelRule>
        {
            new("*.md", "markdown", Priority: 1)
        };
        var changedFiles = new List<string> { "README.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("markdown", labels);
    }

    [Fact]
    public void QuestionMark_MatchesSingleCharacter()
    {
        var rules = new List<LabelRule>
        {
            new("src/?.cs", "single-char", Priority: 1)
        };
        var changedFiles = new List<string> { "src/A.cs" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("single-char", labels);
    }

    [Fact]
    public void QuestionMark_DoesNotMatchMultipleCharacters()
    {
        var rules = new List<LabelRule>
        {
            new("src/?.cs", "single-char", Priority: 1)
        };
        var changedFiles = new List<string> { "src/AB.cs" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Empty(labels);
    }

    [Fact]
    public void DoubleStarGlob_MatchesAnyTestFile()
    {
        // Match test files in any directory using **/*.test.*
        var rules = new List<LabelRule>
        {
            new("**/*.test.*", "tests", Priority: 1)
        };
        var changedFiles = new List<string>
        {
            "src/api/users.test.cs",
            "lib/helpers.test.js",
            "root.test.py"
        };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("tests", labels);
        Assert.Single(labels); // All files get the same label
    }
}

// =============================================================================
// RED/GREEN CYCLE 4: Priority-based conflict resolution
// =============================================================================
public class PriorityConflictResolutionTests
{
    [Fact]
    public void ConflictingRules_HigherPriorityWins()
    {
        // When two rules conflict, the one with lower priority number wins
        var rules = new List<LabelRule>
        {
            new("src/**", "backend", Priority: 10),
            new("src/api/**", "api", Priority: 1)  // Higher precedence
        };
        // Conflict group: only one of "backend" or "api" should be applied
        var conflictGroups = new List<IReadOnlySet<string>>
        {
            new HashSet<string> { "backend", "api" }
        };
        var changedFiles = new List<string> { "src/api/users.cs" };

        var labels = LabelAssigner.AssignLabelsWithPriority(changedFiles, rules, conflictGroups);

        Assert.Contains("api", labels);
        Assert.DoesNotContain("backend", labels);
    }

    [Fact]
    public void NonConflictingLabels_AllIncluded()
    {
        // Labels not in any conflict group are always included
        var rules = new List<LabelRule>
        {
            new("src/api/**", "api", Priority: 1),
            new("**/*.test.*", "tests", Priority: 2)
        };
        var changedFiles = new List<string> { "src/api/users.test.cs" };

        var labels = LabelAssigner.AssignLabelsWithPriority(changedFiles, rules);

        Assert.Contains("api", labels);
        Assert.Contains("tests", labels);
    }

    [Fact]
    public void MultipleConflictGroups_ResolvedIndependently()
    {
        var rules = new List<LabelRule>
        {
            new("src/**", "backend", Priority: 10),
            new("src/api/**", "api", Priority: 1),
            new("**/*.test.*", "tests", Priority: 5),
            new("**/*.spec.*", "specs", Priority: 3)
        };
        var conflictGroups = new List<IReadOnlySet<string>>
        {
            new HashSet<string> { "backend", "api" },       // Group 1
            new HashSet<string> { "tests", "specs" }         // Group 2
        };
        var changedFiles = new List<string> { "src/api/users.test.cs" };

        var labels = LabelAssigner.AssignLabelsWithPriority(changedFiles, rules, conflictGroups);

        // Group 1: api (priority 1) beats backend (priority 10)
        Assert.Contains("api", labels);
        Assert.DoesNotContain("backend", labels);
        // Group 2: only "tests" matched (specs didn't match), so tests wins
        Assert.Contains("tests", labels);
        Assert.DoesNotContain("specs", labels);
    }
}

// =============================================================================
// RED/GREEN CYCLE 5: Edge cases and error handling
// =============================================================================
public class EdgeCaseTests
{
    [Fact]
    public void EmptyFileList_ReturnsNoLabels()
    {
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };

        var labels = LabelAssigner.AssignLabels(new List<string>(), rules);

        Assert.Empty(labels);
    }

    [Fact]
    public void EmptyRuleList_ReturnsNoLabels()
    {
        var changedFiles = new List<string> { "docs/readme.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, new List<LabelRule>());

        Assert.Empty(labels);
    }

    [Fact]
    public void NullFileList_ThrowsArgumentNullException()
    {
        var rules = new List<LabelRule> { new("docs/**", "documentation") };

        Assert.Throws<ArgumentNullException>(() =>
            LabelAssigner.AssignLabels(null!, rules));
    }

    [Fact]
    public void NullRuleList_ThrowsArgumentNullException()
    {
        var changedFiles = new List<string> { "docs/readme.md" };

        Assert.Throws<ArgumentNullException>(() =>
            LabelAssigner.AssignLabels(changedFiles, null!));
    }

    [Fact]
    public void WhitespaceFilePath_IsSkipped()
    {
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };
        var changedFiles = new List<string> { "  ", "", "docs/readme.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Single(labels);
        Assert.Contains("documentation", labels);
    }

    [Fact]
    public void BackslashPaths_AreNormalized()
    {
        // Windows-style paths should be normalized to forward slashes
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };
        var changedFiles = new List<string> { @"docs\guides\intro.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("documentation", labels);
    }

    [Fact]
    public void DuplicateLabels_AreDeduplicatedInOutput()
    {
        // Multiple files matching the same rule should not produce duplicate labels
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1)
        };
        var changedFiles = new List<string>
        {
            "docs/readme.md",
            "docs/contributing.md",
            "docs/license.md"
        };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Single(labels);
        Assert.Contains("documentation", labels);
    }

    [Fact]
    public void CaseInsensitive_LabelDeduplication()
    {
        // Labels should be deduplicated case-insensitively
        // Two different rules producing the same label in different cases
        var rules = new List<LabelRule>
        {
            new("docs/**", "Documentation", Priority: 1),
            new("*.md", "documentation", Priority: 2)
        };
        // Two files: one matches docs/**, the other matches *.md
        var changedFiles = new List<string> { "docs/readme.md", "README.md" };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        // Both rules produce "documentation" (different case) — should dedup to one
        Assert.Single(labels);
    }
}

// =============================================================================
// RED/GREEN CYCLE 6: Glob-to-regex conversion unit tests
// =============================================================================
public class GlobToRegexTests
{
    [Theory]
    [InlineData("docs/**", "docs/readme.md", true)]
    [InlineData("docs/**", "docs/a/b/c.txt", true)]
    [InlineData("docs/**", "src/docs/readme.md", false)]
    [InlineData("*.md", "README.md", true)]
    [InlineData("*.md", "docs/README.md", false)]
    [InlineData("**/*.md", "docs/README.md", true)]
    [InlineData("**/*.md", "a/b/c/d.md", true)]
    [InlineData("**/*.md", "README.md", true)]
    [InlineData("src/api/**", "src/api/users.cs", true)]
    [InlineData("src/api/**", "src/api/v2/users.cs", true)]
    [InlineData("src/api/**", "src/lib/utils.cs", false)]
    [InlineData("*.test.*", "users.test.cs", true)]
    [InlineData("*.test.*", "src/users.test.cs", false)]
    [InlineData("**/*.test.*", "src/users.test.cs", true)]
    [InlineData("**/*.test.*", "users.test.cs", true)]
    public void GlobMatches_VariousPatterns(string pattern, string path, bool expected)
    {
        var result = LabelAssigner.GlobMatches(path, pattern);
        Assert.Equal(expected, result);
    }
}

// =============================================================================
// RED/GREEN CYCLE 7: Integration test — realistic PR scenario
// =============================================================================
public class IntegrationTests
{
    [Fact]
    public void RealisticPrScenario_AssignsCorrectLabels()
    {
        // Simulate a typical PR with a mix of changed files
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1),
            new("src/api/**", "api", Priority: 2),
            new("src/core/**", "core", Priority: 3),
            new("**/*.test.*", "tests", Priority: 4),
            new("**/*.spec.*", "tests", Priority: 4),
            new(".github/**", "ci/cd", Priority: 5),
            new("*.md", "documentation", Priority: 6),
            new("src/**", "backend", Priority: 10)
        };

        var changedFiles = new List<string>
        {
            "docs/api-reference.md",
            "src/api/users/controller.cs",
            "src/api/users/controller.test.cs",
            "src/core/auth/middleware.cs",
            ".github/workflows/ci.yml",
            "README.md"
        };

        var labels = LabelAssigner.AssignLabels(changedFiles, rules);

        Assert.Contains("documentation", labels);
        Assert.Contains("api", labels);
        Assert.Contains("core", labels);
        Assert.Contains("tests", labels);
        Assert.Contains("ci/cd", labels);
        Assert.Contains("backend", labels);
    }

    [Fact]
    public void RealisticPrScenario_WithPriorityConflicts()
    {
        // In this scenario, "backend" and "api" conflict — api should win
        var rules = new List<LabelRule>
        {
            new("docs/**", "documentation", Priority: 1),
            new("src/api/**", "api", Priority: 2),
            new("**/*.test.*", "tests", Priority: 4),
            new("src/**", "backend", Priority: 10)
        };
        var conflictGroups = new List<IReadOnlySet<string>>
        {
            new HashSet<string> { "backend", "api" }
        };

        var changedFiles = new List<string>
        {
            "src/api/users/controller.cs",
            "src/api/users/controller.test.cs"
        };

        var labels = LabelAssigner.AssignLabelsWithPriority(changedFiles, rules, conflictGroups);

        Assert.Contains("api", labels);
        Assert.Contains("tests", labels);
        Assert.DoesNotContain("backend", labels); // Conflict resolved in favor of "api"
    }

    [Fact]
    public void RealisticPrScenario_OnlyBackendChanges_GetsBackendLabel()
    {
        // When only non-api src changes, backend should win (no api match)
        var rules = new List<LabelRule>
        {
            new("src/api/**", "api", Priority: 2),
            new("src/**", "backend", Priority: 10)
        };
        var conflictGroups = new List<IReadOnlySet<string>>
        {
            new HashSet<string> { "backend", "api" }
        };

        var changedFiles = new List<string>
        {
            "src/core/auth/middleware.cs",
            "src/utils/helpers.cs"
        };

        var labels = LabelAssigner.AssignLabelsWithPriority(changedFiles, rules, conflictGroups);

        Assert.Contains("backend", labels);
        Assert.DoesNotContain("api", labels);
    }
}
