using Xunit;

// TDD: Tests for exclude rule functionality.
// Exclude rules remove combinations where ALL specified dimensions match.

namespace MatrixGenerator.Tests;

public class ExcludeRuleTests
{
    [Fact]
    public void Exclude_SingleRule_RemovesMatchingCombination()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" },
                ["node"] = new() { "18", "20" }
            },
            Exclude = new()
            {
                new() { ["os"] = "windows-latest", ["node"] = "18" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 4 total - 1 excluded = 3
        Assert.Equal(3, result.Combinations.Count);
        Assert.DoesNotContain(result.Combinations, c =>
            c["os"] == "windows-latest" && c["node"] == "18");
    }

    [Fact]
    public void Exclude_PartialMatch_RemovesAllMatchingCombinations()
    {
        // Excluding by just one dimension should remove all combos with that value
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest", "macos-latest" },
                ["node"] = new() { "18", "20" }
            },
            Exclude = new()
            {
                // Exclude all windows combinations
                new() { ["os"] = "windows-latest" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 6 total - 2 windows combos = 4
        Assert.Equal(4, result.Combinations.Count);
        Assert.DoesNotContain(result.Combinations, c => c["os"] == "windows-latest");
    }

    [Fact]
    public void Exclude_MultipleRules_RemovesAllMatches()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" },
                ["node"] = new() { "16", "18", "20" }
            },
            Exclude = new()
            {
                new() { ["os"] = "windows-latest", ["node"] = "16" },
                new() { ["os"] = "ubuntu-latest", ["node"] = "16" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 6 total - 2 excluded = 4
        Assert.Equal(4, result.Combinations.Count);
        Assert.DoesNotContain(result.Combinations, c => c["node"] == "16");
    }

    [Fact]
    public void Exclude_NoMatch_LeavesAllCombinations()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" },
                ["node"] = new() { "18" }
            },
            Exclude = new()
            {
                new() { ["os"] = "macos-latest" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Single(result.Combinations);
    }

    [Fact]
    public void Exclude_EmptyRules_LeavesAllCombinations()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" },
                ["node"] = new() { "18" }
            },
            Exclude = new()
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(2, result.Combinations.Count);
    }
}
