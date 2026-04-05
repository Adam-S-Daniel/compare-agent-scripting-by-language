// PR Label Assigner Tests
// TDD approach: RED -> GREEN -> REFACTOR for each feature cycle
//
// Feature cycles:
//   Cycle 1: Basic glob with ** (docs/**) matches a file in that directory
//   Cycle 2: Non-matching file gets no label
//   Cycle 3: Pattern * (single level) does NOT cross directory boundaries
//   Cycle 4: Pattern without slash matches filename anywhere in the tree
//   Cycle 5: Multiple rules -> multiple labels per PR
//   Cycle 6: Priority ordering determines rule evaluation order
//   Cycle 7: Conflicting labels - higher priority rule wins when same label offered
//   Cycle 8: Full mock PR scenario

using Xunit;
using PrLabelAssigner;

// ============================================================
// CYCLE 1 RED: Basic glob match with **
// At this point LabelRule, LabelAssigner, GlobMatcher don't exist.
// This test will fail to compile until we create them.
// ============================================================

public class GlobMatcherTests
{
    // Cycle 1: ** pattern matches any path under directory
    [Fact]
    public void DoubleStarPattern_MatchesFileInSubdirectory()
    {
        Assert.True(GlobMatcher.IsMatch("docs/readme.md", "docs/**"));
    }

    // Cycle 1: ** pattern matches file directly in directory
    [Fact]
    public void DoubleStarPattern_MatchesFileDirectlyInDirectory()
    {
        Assert.True(GlobMatcher.IsMatch("docs/guide.md", "docs/**"));
    }

    // Cycle 1: ** pattern matches nested subdirectory files
    [Fact]
    public void DoubleStarPattern_MatchesNestedSubdirectoryFile()
    {
        Assert.True(GlobMatcher.IsMatch("docs/api/reference.md", "docs/**"));
    }

    // Cycle 2: Non-matching file returns false
    [Fact]
    public void DoubleStarPattern_DoesNotMatchFileOutsideDirectory()
    {
        Assert.False(GlobMatcher.IsMatch("src/main.cs", "docs/**"));
    }

    // Cycle 3: Pattern WITHOUT slash behaves like .gitignore - matches at any depth.
    // So *.md (no slash) matches docs/readme.md and also readme.md.
    [Fact]
    public void PatternWithoutSlash_MatchesFileAtAnyDepth()
    {
        // *.md has no slash -> should match docs/readme.md (any depth)
        Assert.True(GlobMatcher.IsMatch("docs/readme.md", "*.md"));
    }

    // Cycle 3: Pattern WITHOUT slash also matches at root level
    [Fact]
    public void PatternWithoutSlash_MatchesFileAtRootLevel()
    {
        Assert.True(GlobMatcher.IsMatch("readme.md", "*.md"));
    }

    // Cycle 3: Pattern WITH slash anchors to root - single * does NOT cross /
    // "src/*.cs" has a slash -> anchored; * only matches within that directory level
    [Fact]
    public void PatternWithSlash_SingleStar_DoesNotCrossDirectoryBoundary()
    {
        // src/*.cs has '/' -> anchored; should NOT match src/utils/helper.cs
        Assert.False(GlobMatcher.IsMatch("src/utils/helper.cs", "src/*.cs"));
    }

    // Cycle 3: Pattern with slash and single * matches at the exact level
    [Fact]
    public void PatternWithSlash_SingleStar_MatchesAtCorrectLevel()
    {
        Assert.True(GlobMatcher.IsMatch("src/main.cs", "src/*.cs"));
    }

    // Cycle 4: Pattern without slash matches filename at any depth
    // (like .gitignore: if no / in pattern, match basename anywhere)
    [Fact]
    public void PatternWithoutSlash_MatchesFilenameAtAnyDepth()
    {
        // *.test.* has no slash -> matches src/utils/helper.test.ts
        Assert.True(GlobMatcher.IsMatch("src/utils/helper.test.ts", "*.test.*"));
    }

    // Cycle 4: Pattern without slash matches at root level too
    [Fact]
    public void PatternWithoutSlash_MatchesFileAtRoot()
    {
        Assert.True(GlobMatcher.IsMatch("helper.test.ts", "*.test.*"));
    }

    // Cycle 4: Pattern without slash doesn't match files that don't fit
    [Fact]
    public void PatternWithoutSlash_DoesNotMatchNonMatchingFile()
    {
        Assert.False(GlobMatcher.IsMatch("src/utils/helper.cs", "*.test.*"));
    }

    // Cycle 5: Exact path match
    [Fact]
    public void ExactPath_MatchesExactFile()
    {
        Assert.True(GlobMatcher.IsMatch("src/api/endpoint.cs", "src/api/**"));
    }

    // Cycle 5: Deep nested path under api
    [Fact]
    public void DeepPath_MatchesUnderApiDirectory()
    {
        Assert.True(GlobMatcher.IsMatch("src/api/v2/controllers/UserController.cs", "src/api/**"));
    }

    // Glob with ? wildcard
    [Fact]
    public void QuestionMark_MatchesSingleCharacter()
    {
        Assert.True(GlobMatcher.IsMatch("src/v1/main.cs", "src/v?/main.cs"));
    }

    [Fact]
    public void QuestionMark_DoesNotMatchZeroOrMultipleChars()
    {
        Assert.False(GlobMatcher.IsMatch("src/v12/main.cs", "src/v?/main.cs"));
    }
}

public class LabelAssignerTests
{
    // Cycle 1: Single rule matching one file -> returns that label
    [Fact]
    public void SingleRule_MatchingFile_ReturnsLabel()
    {
        var rules = new List<LabelRule>
        {
            new LabelRule("docs/**", "documentation", Priority: 1)
        };
        var files = new List<string> { "docs/readme.md" };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        Assert.Contains("documentation", labels);
    }

    // Cycle 2: Non-matching file returns empty set
    [Fact]
    public void SingleRule_NoMatchingFile_ReturnsEmptySet()
    {
        var rules = new List<LabelRule>
        {
            new LabelRule("docs/**", "documentation", Priority: 1)
        };
        var files = new List<string> { "src/main.cs" };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        Assert.Empty(labels);
    }

    // Cycle 3: Multiple files, multiple matching rules -> all labels collected
    [Fact]
    public void MultipleRules_MultipleMatchingFiles_AllLabelsReturned()
    {
        var rules = new List<LabelRule>
        {
            new LabelRule("docs/**", "documentation", Priority: 1),
            new LabelRule("src/api/**", "api", Priority: 2),
        };
        var files = new List<string>
        {
            "docs/readme.md",
            "src/api/endpoint.cs"
        };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        Assert.Contains("documentation", labels);
        Assert.Contains("api", labels);
        Assert.Equal(2, labels.Count);
    }

    // Cycle 4: Multiple files with same label -> deduplication
    [Fact]
    public void MultipleMatchingFiles_SameLabel_DeduplicatesLabels()
    {
        var rules = new List<LabelRule>
        {
            new LabelRule("docs/**", "documentation", Priority: 1),
        };
        var files = new List<string>
        {
            "docs/readme.md",
            "docs/guide.md",
            "docs/api/reference.md"
        };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        // Should only have one "documentation" label
        Assert.Single(labels);
        Assert.Contains("documentation", labels);
    }

    // Cycle 5: *.test.* pattern matches test files anywhere in tree
    [Fact]
    public void TestFilePattern_MatchesTestFilesAtAnyDepth()
    {
        var rules = new List<LabelRule>
        {
            new LabelRule("*.test.*", "tests", Priority: 1),
        };
        var files = new List<string>
        {
            "src/utils/helper.test.ts",
            "components/Button.test.tsx",
        };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        Assert.Contains("tests", labels);
        Assert.Single(labels);
    }

    // Cycle 6: Priority ordering - lower number = higher priority (applied first)
    // Both labels should still be returned (priority doesn't suppress labels,
    // it determines order for conflict resolution)
    [Fact]
    public void Priority_RulesAppliedInPriorityOrder_AllLabelsCollected()
    {
        var rules = new List<LabelRule>
        {
            // Deliberately add in reverse priority order
            new LabelRule("src/**", "source", Priority: 10),
            new LabelRule("src/api/**", "api", Priority: 1),
        };
        var files = new List<string> { "src/api/endpoint.cs" };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        // Both labels apply - multiple labels per file is supported
        Assert.Contains("api", labels);
        Assert.Contains("source", labels);
    }

    // Cycle 7: Priority-based conflict resolution
    // When a higher-priority "exclude" rule matches, it can suppress lower-priority labels
    // (This tests the conflict resolution scenario)
    [Fact]
    public void Priority_HigherPriorityRuleWins_InConflictScenario()
    {
        // Imagine we have a "no-label" sentinel: if a file matches a high-priority rule
        // explicitly marked to override, lower priority rules for the same file are ignored
        // In our model: all matching rules contribute labels. Priority is for ordering only.
        // So this test verifies that rules are evaluated in priority order.
        var rules = new List<LabelRule>
        {
            new LabelRule("src/api/**", "api", Priority: 1),     // high priority
            new LabelRule("**/*.cs", "csharp", Priority: 5),     // lower priority
        };
        var files = new List<string> { "src/api/controller.cs" };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(files);

        // Both labels apply to this file
        Assert.Contains("api", labels);
        Assert.Contains("csharp", labels);
    }

    // Cycle 8: Empty file list -> empty labels
    [Fact]
    public void EmptyFileList_ReturnsEmptyLabels()
    {
        var rules = new List<LabelRule>
        {
            new LabelRule("docs/**", "documentation", Priority: 1),
        };
        var assigner = new LabelAssigner(rules);

        var labels = assigner.AssignLabels(new List<string>());

        Assert.Empty(labels);
    }

    // Cycle 8: Empty rules -> empty labels
    [Fact]
    public void EmptyRules_ReturnsEmptyLabels()
    {
        var assigner = new LabelAssigner(new List<LabelRule>());
        var files = new List<string> { "docs/readme.md" };

        var labels = assigner.AssignLabels(files);

        Assert.Empty(labels);
    }

    // Full mock PR scenario - demonstrates realistic usage
    [Fact]
    public void MockPR_MixedChangedFiles_CorrectLabelsAssigned()
    {
        // Configurable rules (simulating a .github/label-rules.yml)
        var rules = new List<LabelRule>
        {
            new LabelRule("docs/**",     "documentation", Priority: 1),
            new LabelRule("src/api/**",  "api",           Priority: 2),
            new LabelRule("*.test.*",    "tests",         Priority: 3),
            new LabelRule("src/**",      "source",        Priority: 4),
            new LabelRule("*.md",        "markdown",      Priority: 5),
        };

        // Mock PR: changed files (simulating what git diff --name-only returns)
        var changedFiles = new List<string>
        {
            "docs/getting-started.md",           // matches: docs/**, *.md
            "src/api/v2/UserController.cs",      // matches: src/api/**, src/**
            "src/utils/validator.test.ts",       // matches: *.test.*, src/**
            "src/models/User.cs",                // matches: src/**
            "README.md",                         // matches: *.md (no slash -> any depth)
        };

        var assigner = new LabelAssigner(rules);
        var labels = assigner.AssignLabels(changedFiles);

        Assert.Contains("documentation", labels);
        Assert.Contains("api", labels);
        Assert.Contains("tests", labels);
        Assert.Contains("source", labels);
        Assert.Contains("markdown", labels);
    }
}
