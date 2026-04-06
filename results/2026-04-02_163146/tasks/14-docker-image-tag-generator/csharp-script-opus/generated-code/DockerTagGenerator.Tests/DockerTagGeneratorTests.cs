// TDD tests for Docker image tag generation.
// Each test class covers a specific scenario:
//   1. MainBranchTests   — main/master → "latest" tag
//   2. PrTests           — PR builds → "pr-{number}" tag
//   3. SemverTagTests    — git semver tags → version tags
//   4. FeatureBranchTests — feature branches → "{branch}-{sha}" tag
//   5. SanitizationTests — tag sanitization (lowercase, no special chars)
//   6. EdgeCaseTests     — error handling, validation

using Xunit;
using DockerTagGenerator;

namespace DockerTagGenerator.Tests;

// ─── 1. Main/master branch → "latest" tag ───────────────────────────

public class MainBranchTests
{
    [Fact]
    public void MainBranch_ShouldProduceLatestTag()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("latest", tags);
    }

    [Fact]
    public void MasterBranch_ShouldProduceLatestTag()
    {
        var context = new GitContext
        {
            BranchName = "master",
            CommitSha = "abc1234567890def",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("latest", tags);
    }

    [Fact]
    public void MainBranch_ShouldAlsoProduceBranchShaTag()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        // Should also have the branch-sha tag
        Assert.Contains("main-abc1234", tags);
    }

    [Fact]
    public void NonMainBranch_ShouldNotProduceLatestTag()
    {
        var context = new GitContext
        {
            BranchName = "develop",
            CommitSha = "abc1234567890def",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.DoesNotContain("latest", tags);
    }
}

// ─── 2. PR builds → "pr-{number}" tag ───────────────────────────────

public class PrTests
{
    [Fact]
    public void PrBuild_ShouldProducePrTag()
    {
        var context = new GitContext
        {
            BranchName = "feature/add-login",
            CommitSha = "deadbeef1234567",
            Tags = [],
            PrNumber = 42
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("pr-42", tags);
    }

    [Fact]
    public void PrBuild_ShouldAlsoProduceBranchShaTag()
    {
        var context = new GitContext
        {
            BranchName = "feature/add-login",
            CommitSha = "deadbeef1234567",
            Tags = [],
            PrNumber = 42
        };

        var tags = TagGenerator.GenerateTags(context);

        // Branch tag should be sanitized (/ → -)
        Assert.Contains("feature-add-login-deadbee", tags);
    }

    [Fact]
    public void PrBuild_WithoutPrNumber_ShouldNotProducePrTag()
    {
        var context = new GitContext
        {
            BranchName = "feature/add-login",
            CommitSha = "deadbeef1234567",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.DoesNotContain(tags, t => t.StartsWith("pr-"));
    }
}

// ─── 3. Semver tags → version tags ──────────────────────────────────

public class SemverTagTests
{
    [Fact]
    public void SemverTag_ShouldBeIncluded()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = ["v1.2.3"],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("v1.2.3", tags);
    }

    [Fact]
    public void SemverTag_WithoutV_ShouldBeIncluded()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = ["1.2.3"],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("1.2.3", tags);
    }

    [Fact]
    public void SemverTag_WithPrerelease_ShouldBeIncluded()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = ["v2.0.0-beta.1"],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("v2.0.0-beta.1", tags);
    }

    [Fact]
    public void MultipleSemverTags_ShouldAllBeIncluded()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = ["v1.0.0", "v1.0.0-rc.1"],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("v1.0.0", tags);
        Assert.Contains("v1.0.0-rc.1", tags);
    }

    [Fact]
    public void NonSemverTag_ShouldBeIgnored()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "abc1234567890def",
            Tags = ["release-candidate", "deploy-2024"],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.DoesNotContain("release-candidate", tags);
        Assert.DoesNotContain("deploy-2024", tags);
    }

    [Theory]
    [InlineData("v1.2.3", true)]
    [InlineData("1.2.3", true)]
    [InlineData("v0.0.1", true)]
    [InlineData("v2.0.0-beta.1", true)]
    [InlineData("v1.0.0+build.123", true)]
    [InlineData("v1.0.0-alpha+001", true)]
    [InlineData("release-candidate", false)]
    [InlineData("deploy-2024", false)]
    [InlineData("v1.2", false)]
    [InlineData("latest", false)]
    [InlineData("", false)]
    public void IsSemverTag_ShouldClassifyCorrectly(string tag, bool expected)
    {
        Assert.Equal(expected, TagGenerator.IsSemverTag(tag));
    }
}

// ─── 4. Feature branch → "{branch}-{short-sha}" tag ────────────────

public class FeatureBranchTests
{
    [Fact]
    public void FeatureBranch_ShouldProduceSanitizedBranchShaTag()
    {
        var context = new GitContext
        {
            BranchName = "feature/my-feature",
            CommitSha = "1234567890abcdef",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        // "feature/my-feature" → "feature-my-feature", sha → "1234567"
        Assert.Contains("feature-my-feature-1234567", tags);
    }

    [Fact]
    public void FeatureBranch_ShouldNotProduceLatestTag()
    {
        var context = new GitContext
        {
            BranchName = "feature/my-feature",
            CommitSha = "1234567890abcdef",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.DoesNotContain("latest", tags);
    }

    [Fact]
    public void ShortSha_ShouldBe7Characters()
    {
        var context = new GitContext
        {
            CommitSha = "abcdef1234567890"
        };

        Assert.Equal("abcdef1", context.ShortSha);
    }

    [Fact]
    public void ShortSha_WhenShaIsShort_ShouldReturnWhatIsAvailable()
    {
        var context = new GitContext
        {
            CommitSha = "abc"
        };

        Assert.Equal("abc", context.ShortSha);
    }
}

// ─── 5. Tag sanitization ────────────────────────────────────────────

public class SanitizationTests
{
    [Theory]
    [InlineData("Feature/My-Branch", "feature-my-branch")]
    [InlineData("UPPERCASE", "uppercase")]
    [InlineData("feature/CAPS/test", "feature-caps-test")]
    public void SanitizeTag_ShouldLowercase(string input, string expected)
    {
        Assert.Equal(expected, TagGenerator.SanitizeTag(input));
    }

    [Theory]
    [InlineData("feature/my-branch", "feature-my-branch")]
    [InlineData("fix/bug#123", "fix-bug-123")]
    [InlineData("user@branch", "user-branch")]
    [InlineData("feature[test]", "feature-test")]
    public void SanitizeTag_ShouldReplaceSpecialChars(string input, string expected)
    {
        Assert.Equal(expected, TagGenerator.SanitizeTag(input));
    }

    [Theory]
    [InlineData("a--b", "a-b")]
    [InlineData("a///b", "a-b")]
    [InlineData("a..b", "a.b")]
    public void SanitizeTag_ShouldCollapseRepeatedSeparators(string input, string expected)
    {
        Assert.Equal(expected, TagGenerator.SanitizeTag(input));
    }

    [Theory]
    [InlineData("-leading", "leading")]
    [InlineData("trailing-", "trailing")]
    [InlineData("-both-", "both")]
    [InlineData(".dotted.", "dotted")]
    public void SanitizeTag_ShouldTrimSeparatorsFromEdges(string input, string expected)
    {
        Assert.Equal(expected, TagGenerator.SanitizeTag(input));
    }

    [Fact]
    public void SanitizeTag_ShouldTruncateTo128Chars()
    {
        var longInput = new string('a', 200);
        var result = TagGenerator.SanitizeTag(longInput);

        Assert.True(result.Length <= 128);
    }

    [Fact]
    public void SanitizeTag_ShouldPreserveDotsAndHyphens()
    {
        Assert.Equal("v1.2.3-beta.1", TagGenerator.SanitizeTag("v1.2.3-beta.1"));
    }
}

// ─── 6. Edge cases and error handling ───────────────────────────────

public class EdgeCaseTests
{
    [Fact]
    public void GenerateTags_WithNullContext_ShouldThrow()
    {
        Assert.Throws<ArgumentNullException>(() => TagGenerator.GenerateTags(null!));
    }

    [Fact]
    public void GenerateTags_WithEmptySha_ShouldThrow()
    {
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "",
            Tags = [],
            PrNumber = null
        };

        Assert.Throws<ArgumentException>(() => TagGenerator.GenerateTags(context));
    }

    [Fact]
    public void SanitizeTag_WithEmptyInput_ShouldThrow()
    {
        Assert.Throws<ArgumentException>(() => TagGenerator.SanitizeTag(""));
    }

    [Fact]
    public void SanitizeTag_WithWhitespace_ShouldThrow()
    {
        Assert.Throws<ArgumentException>(() => TagGenerator.SanitizeTag("   "));
    }

    [Fact]
    public void SanitizeTag_WithOnlySpecialChars_ShouldThrow()
    {
        Assert.Throws<ArgumentException>(() => TagGenerator.SanitizeTag("@#$%"));
    }

    [Fact]
    public void GenerateTags_CombinedScenario_PrWithSemverOnMain()
    {
        // A PR merged to main with a version tag — should produce all tag types
        var context = new GitContext
        {
            BranchName = "main",
            CommitSha = "fedcba9876543210",
            Tags = ["v3.1.0"],
            PrNumber = 99
        };

        var tags = TagGenerator.GenerateTags(context);

        Assert.Contains("latest", tags);
        Assert.Contains("pr-99", tags);
        Assert.Contains("v3.1.0", tags);
        Assert.Contains("main-fedcba9", tags);
        Assert.Equal(4, tags.Count);
    }

    [Fact]
    public void GenerateTags_FeatureBranchWithSpecialChars()
    {
        var context = new GitContext
        {
            BranchName = "feature/JIRA-1234_My Feature!",
            CommitSha = "abcdef1234567890",
            Tags = [],
            PrNumber = null
        };

        var tags = TagGenerator.GenerateTags(context);

        // Should be sanitized: lowercase, special chars replaced, underscores preserved
        var branchTag = tags.Single(); // only one tag for a feature branch
        Assert.Equal("feature-jira-1234_my-feature-abcdef1", branchTag);
    }
}
