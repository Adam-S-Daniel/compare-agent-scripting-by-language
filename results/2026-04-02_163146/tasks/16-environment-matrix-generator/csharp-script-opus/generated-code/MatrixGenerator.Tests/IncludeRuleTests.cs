using Xunit;

// TDD: Tests for include rule functionality.
// Include rules can either merge extra keys into matching combinations
// or add entirely new combinations.

namespace MatrixGenerator.Tests;

public class IncludeRuleTests
{
    [Fact]
    public void Include_NewCombination_AddsToMatrix()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" },
                ["node"] = new() { "18" }
            },
            Include = new()
            {
                // This doesn't match any existing combo (os=macos not in matrix)
                new() { ["os"] = "macos-latest", ["node"] = "20" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 1 original + 1 included = 2
        Assert.Equal(2, result.Combinations.Count);
        Assert.Contains(result.Combinations, c =>
            c["os"] == "macos-latest" && c["node"] == "20");
    }

    [Fact]
    public void Include_MatchingCombination_MergesExtraKeys()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" },
                ["node"] = new() { "18" }
            },
            Include = new()
            {
                // Matches os=ubuntu-latest, node=18 — adds an extra key
                new() { ["os"] = "ubuntu-latest", ["node"] = "18", ["npm"] = "9" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // Still 2 combinations, but one has an extra key
        Assert.Equal(2, result.Combinations.Count);
        var ubuntuCombo = result.Combinations.First(c => c["os"] == "ubuntu-latest");
        Assert.Equal("9", ubuntuCombo["npm"]);
    }

    [Fact]
    public void Include_WithOnlyNewDimensions_AddsAsNewCombination()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" }
            },
            Include = new()
            {
                // Completely new dimension set
                new() { ["arch"] = "arm64", ["experimental"] = "true" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 1 original + 1 new = 2
        Assert.Equal(2, result.Combinations.Count);
        Assert.Contains(result.Combinations, c =>
            c.ContainsKey("arch") && c["arch"] == "arm64");
    }

    [Fact]
    public void Include_MultipleRules_AllApplied()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" },
                ["node"] = new() { "18" }
            },
            Include = new()
            {
                new() { ["os"] = "macos-latest", ["node"] = "20" },
                new() { ["os"] = "windows-latest", ["node"] = "20" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(3, result.Combinations.Count);
    }

    [Fact]
    public void Include_EmptyRules_NoChange()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" }
            },
            Include = new()
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Single(result.Combinations);
    }

    [Fact]
    public void Include_AfterExclude_CanReAddCombinations()
    {
        // Exclude removes a combo, then include adds a variant of it back
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
            },
            Include = new()
            {
                // Re-add windows+18 with an extra flag
                new() { ["os"] = "windows-latest", ["node"] = "18", ["experimental"] = "true" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 4 - 1 excluded + 1 included = 4
        Assert.Equal(4, result.Combinations.Count);
        var reAdded = result.Combinations.FirstOrDefault(c =>
            c["os"] == "windows-latest" && c["node"] == "18");
        Assert.NotNull(reAdded);
        Assert.Equal("true", reAdded["experimental"]);
    }
}
