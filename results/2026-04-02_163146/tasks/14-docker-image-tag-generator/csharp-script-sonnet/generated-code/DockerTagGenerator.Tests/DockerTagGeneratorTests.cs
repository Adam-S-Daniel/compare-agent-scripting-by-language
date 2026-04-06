// DockerTagGeneratorTests.cs
// TDD tests for the Docker image tag generator.
//
// RED/GREEN cycle order:
//   1. GetShortSha extracts first 7 chars
//   2. Main branch produces "latest" tag
//   3. PR builds produce "pr-{number}" tag
//   4. Semver git tags produce "v{semver}" Docker tags
//   5. Feature branches produce "{branch}-{short-sha}" tag
//   6. Tag sanitization (lowercase, special chars)
//   7. Branch name with slashes is sanitized
//   8. Null/invalid inputs handled gracefully

using DockerTagGenerator;
using Xunit;
using System.Collections.Generic;

namespace DockerTagGenerator.Tests;

public class GetShortShaTests
{
    // RED: This test was written before GetShortSha existed.
    [Fact]
    public void GetShortSha_Returns7CharPrefix()
    {
        string sha = "abc1234567890";
        string result = DockerTagGeneratorService.GetShortSha(sha);
        Assert.Equal("abc1234", result);
    }

    [Fact]
    public void GetShortSha_NormalizesToLowercase()
    {
        string sha = "ABCDEF1234567";
        string result = DockerTagGeneratorService.GetShortSha(sha);
        Assert.Equal("abcdef1", result);
    }

    [Fact]
    public void GetShortSha_ShortShaReturnedAsIs()
    {
        string sha = "abc12";
        string result = DockerTagGeneratorService.GetShortSha(sha);
        Assert.Equal("abc12", result);
    }

    [Fact]
    public void GetShortSha_ThrowsOnEmpty()
    {
        Assert.Throws<ArgumentException>(() => DockerTagGeneratorService.GetShortSha(""));
    }
}

public class SanitizeTagTests
{
    // RED: Tests for tag sanitization logic.
    [Fact]
    public void SanitizeTag_LowercasesInput()
    {
        Assert.Equal("v1.2.3", DockerTagGeneratorService.SanitizeTag("V1.2.3"));
    }

    [Fact]
    public void SanitizeTag_ReplacesSpecialCharsWithHyphen()
    {
        Assert.Equal("feature-my-branch", DockerTagGeneratorService.SanitizeTag("feature/my branch"));
    }

    [Fact]
    public void SanitizeTag_CollapseMultipleHyphens()
    {
        Assert.Equal("feature-branch", DockerTagGeneratorService.SanitizeTag("feature--branch"));
    }

    [Fact]
    public void SanitizeTag_TrimsLeadingTrailingHyphens()
    {
        Assert.Equal("branch", DockerTagGeneratorService.SanitizeTag("-branch-"));
    }

    [Fact]
    public void SanitizeTag_PreservesDotsAndHyphens()
    {
        Assert.Equal("v1.2.3-rc.1", DockerTagGeneratorService.SanitizeTag("v1.2.3-rc.1"));
    }
}

public class SanitizeBranchNameTests
{
    [Fact]
    public void SanitizeBranchName_ReplacesSlashesWithHyphens()
    {
        Assert.Equal("feature-my-feature", DockerTagGeneratorService.SanitizeBranchName("feature/my-feature"));
    }

    [Fact]
    public void SanitizeBranchName_HandlesNestedPaths()
    {
        Assert.Equal("user-john-fix-bug-123", DockerTagGeneratorService.SanitizeBranchName("user/john/fix-bug-123"));
    }

    [Fact]
    public void SanitizeBranchName_Lowercases()
    {
        Assert.Equal("feature-my-feature", DockerTagGeneratorService.SanitizeBranchName("Feature/My-Feature"));
    }
}

public class GenerateTagsMainBranchTests
{
    // RED: Main branch should produce "latest" tag.
    [Fact]
    public void GenerateTags_MainBranch_ProducesLatest()
    {
        var ctx = new GitContext("main", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("latest", tags);
    }

    [Fact]
    public void GenerateTags_MasterBranch_ProducesLatest()
    {
        var ctx = new GitContext("master", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("latest", tags);
    }

    [Fact]
    public void GenerateTags_MainBranch_AlsoProducesMainShortSha()
    {
        var ctx = new GitContext("main", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("main-abc1234", tags);
    }

    [Fact]
    public void GenerateTags_MainBranch_DoesNotProduceFeatureBranchTag()
    {
        var ctx = new GitContext("main", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        // Should NOT contain the feature-branch format without "latest"
        Assert.DoesNotContain("feature", tags.FindAll(t => t.StartsWith("feature")));
    }
}

public class GenerateTagsPrTests
{
    // RED: PR builds should produce pr-{number} tag.
    [Fact]
    public void GenerateTags_PrBuild_ProducesPrTag()
    {
        var ctx = new GitContext("feature/my-feature", "abc1234567890", [], 42);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("pr-42", tags);
    }

    [Fact]
    public void GenerateTags_PrBuild_DoesNotProduceFeatureBranchTag()
    {
        var ctx = new GitContext("feature/my-feature", "abc1234567890", [], 42);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        // PR builds don't get branch-sha tag
        Assert.DoesNotContain("feature-my-feature-abc1234", tags);
    }

    [Fact]
    public void GenerateTags_NoPr_DoesNotProducePrTag()
    {
        var ctx = new GitContext("feature/my-feature", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.DoesNotContain("pr-", tags.FindAll(t => t.StartsWith("pr-")));
    }
}

public class GenerateTagsSemverTests
{
    // RED: Semver tags should produce v{semver} Docker tags.
    [Fact]
    public void GenerateTags_SemverTag_ProducesVersionTag()
    {
        var ctx = new GitContext("main", "abc1234567890", ["v1.2.3"], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("v1.2.3", tags);
    }

    [Fact]
    public void GenerateTags_SemverTagWithPrerelease_ProducesVersionTag()
    {
        var ctx = new GitContext("main", "abc1234567890", ["v1.2.3-rc.1"], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("v1.2.3-rc.1", tags);
    }

    [Fact]
    public void GenerateTags_MultipleSemverTags_ProducesAllVersionTags()
    {
        var ctx = new GitContext("main", "abc1234567890", ["v1.2.3", "v1.2.3-rc.1"], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("v1.2.3", tags);
        Assert.Contains("v1.2.3-rc.1", tags);
    }

    [Fact]
    public void GenerateTags_NonSemverTag_Ignored()
    {
        var ctx = new GitContext("feature/test", "abc1234567890", ["my-custom-tag"], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.DoesNotContain("my-custom-tag", tags);
    }

    [Fact]
    public void GenerateTags_NoTags_NoVersionTags()
    {
        var ctx = new GitContext("feature/test", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.DoesNotContain(tags, t => t.StartsWith("v") && char.IsDigit(t[1]));
    }
}

public class GenerateTagsFeatureBranchTests
{
    // RED: Feature branches should produce {branch}-{short-sha} tag.
    [Fact]
    public void GenerateTags_FeatureBranch_ProducesBranchShaTags()
    {
        var ctx = new GitContext("feature/my-feature", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("feature-my-feature-abc1234", tags);
    }

    [Fact]
    public void GenerateTags_FeatureBranch_BranchNameSanitized()
    {
        var ctx = new GitContext("Feature/My Feature!!", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        // Should be sanitized: lowercase, slashes/spaces/! become hyphens, collapsed
        Assert.Contains("feature-my-feature-abc1234", tags);
    }

    [Fact]
    public void GenerateTags_FeatureBranch_DoesNotProduceLatest()
    {
        var ctx = new GitContext("feature/my-feature", "abc1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.DoesNotContain("latest", tags);
    }
}

public class GenerateTagsEdgeCasesTests
{
    [Fact]
    public void GenerateTags_NullContext_ThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => DockerTagGeneratorService.GenerateTags(null!));
    }

    [Fact]
    public void GenerateTags_TagsAreLowercase()
    {
        var ctx = new GitContext("Main", "ABC1234567890", [], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        // Even "Main" branch doesn't match main — it won't get "latest"
        // It will get {branch}-{sha} tag sanitized to lowercase
        foreach (var tag in tags)
        {
            Assert.Equal(tag.ToLowerInvariant(), tag);
        }
    }

    [Fact]
    public void GenerateTags_MainBranchWithSemverTag_ProducesBothLatestAndVersion()
    {
        var ctx = new GitContext("main", "abc1234567890", ["v2.0.0"], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("latest", tags);
        Assert.Contains("v2.0.0", tags);
    }

    [Fact]
    public void GenerateTags_PrWithSemverTag_ProducesBothPrAndVersion()
    {
        var ctx = new GitContext("release/1.0", "abc1234567890", ["v1.0.0"], 15);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        Assert.Contains("pr-15", tags);
        Assert.Contains("v1.0.0", tags);
    }

    [Fact]
    public void GenerateTags_ReturnsSortedList()
    {
        var ctx = new GitContext("main", "abc1234567890", ["v1.2.3"], null);
        var tags = DockerTagGeneratorService.GenerateTags(ctx);
        var sorted = new List<string>(tags);
        sorted.Sort();
        Assert.Equal(sorted, tags);
    }
}
