using Xunit;

// TDD: Edge case tests for robustness.

namespace MatrixGenerator.Tests;

public class EdgeCaseTests
{
    [Fact]
    public void Generate_SingleValueDimensions_ProducesSingleCombination()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" },
                ["node"] = new() { "20" },
                ["arch"] = new() { "x64" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Single(result.Combinations);
        Assert.Equal("ubuntu-latest", result.Combinations[0]["os"]);
        Assert.Equal("20", result.Combinations[0]["node"]);
        Assert.Equal("x64", result.Combinations[0]["arch"]);
    }

    [Fact]
    public void Generate_LargeMatrix_WithinLimit_Succeeds()
    {
        // 4*4*4 = 64, within 256 limit
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-20.04", "ubuntu-22.04", "windows-2019", "windows-2022" },
                ["python"] = new() { "3.8", "3.9", "3.10", "3.11" },
                ["django"] = new() { "3.2", "4.0", "4.1", "4.2" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(64, result.Combinations.Count);
    }

    [Fact]
    public void Generate_ExcludeAll_ProducesEmptyResult()
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
                new() { ["os"] = "ubuntu-latest", ["node"] = "18" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Empty(result.Combinations);
    }

    [Fact]
    public void Generate_IncludeOnly_NoMatrix_ProducesCombinationsFromIncludes()
    {
        // Empty matrix dimensions but includes specified
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>(),
            Include = new()
            {
                new() { ["os"] = "ubuntu-latest", ["node"] = "18" },
                new() { ["os"] = "windows-latest", ["node"] = "20" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(2, result.Combinations.Count);
    }

    [Fact]
    public void Generate_FeatureFlags_IncludedAsDimensions()
    {
        // Feature flags are just another dimension
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" },
                ["experimental"] = new() { "true", "false" },
                ["coverage"] = new() { "on", "off" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(4, result.Combinations.Count);
        Assert.All(result.Combinations, c =>
        {
            Assert.True(c.ContainsKey("experimental"));
            Assert.True(c.ContainsKey("coverage"));
        });
    }

    [Fact]
    public void Generate_RealisticGitHubActionsConfig_ProducesExpectedOutput()
    {
        // Realistic CI/CD matrix: test on multiple OS, language versions, with excludes
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest", "macos-latest" },
                ["node"] = new() { "16", "18", "20" }
            },
            Exclude = new()
            {
                // Don't test node 16 on macos (legacy combo)
                new() { ["os"] = "macos-latest", ["node"] = "16" }
            },
            Include = new()
            {
                // Add an experimental node 21 test on ubuntu
                new() { ["os"] = "ubuntu-latest", ["node"] = "21", ["experimental"] = "true" }
            },
            FailFast = false,
            MaxParallel = 4,
            MaxMatrixSize = 256
        };

        var result = MatrixGenerator.Generate(config);

        // 3*3 = 9, - 1 exclude = 8, + 1 include = 9
        Assert.Equal(9, result.Combinations.Count);
        Assert.False(result.FailFast);
        Assert.Equal(4, result.MaxParallel);

        // Verify excluded combo is not present
        Assert.DoesNotContain(result.Combinations, c =>
            c["os"] == "macos-latest" && c["node"] == "16");

        // Verify included combo is present with extra key
        var experimental = result.Combinations.FirstOrDefault(c =>
            c["os"] == "ubuntu-latest" && c["node"] == "21");
        Assert.NotNull(experimental);
        Assert.Equal("true", experimental["experimental"]);
    }

    [Fact]
    public void Generate_DuplicateValuesInDimension_AllPreserved()
    {
        // If a user accidentally duplicates, each value creates a separate combo
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "ubuntu-latest" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // Both entries produce separate combos (user's responsibility to deduplicate)
        Assert.Equal(2, result.Combinations.Count);
    }

    [Fact]
    public void Generate_SpecialCharactersInValues_Handled()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["version"] = new() { "3.10", "3.11-rc1" },
                ["flag"] = new() { "--experimental", "--stable" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(4, result.Combinations.Count);
        Assert.Contains(result.Combinations, c =>
            c["version"] == "3.11-rc1" && c["flag"] == "--experimental");
    }
}
