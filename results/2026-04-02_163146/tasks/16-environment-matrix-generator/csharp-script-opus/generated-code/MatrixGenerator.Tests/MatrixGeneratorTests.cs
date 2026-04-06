using System.Text.Json;
using Xunit;

// TDD Step 1: Write failing tests first, then implement the code to make them pass.
// We start with the most basic functionality - generating a Cartesian product matrix.

namespace MatrixGenerator.Tests;

public class BasicMatrixGenerationTests
{
    // RED: Test that a simple config with two dimensions produces the correct Cartesian product
    [Fact]
    public void GenerateMatrix_WithTwoDimensions_ProducesCartesianProduct()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" },
                ["node"] = new() { "18", "20" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 2 OS * 2 node versions = 4 combinations
        Assert.Equal(4, result.Combinations.Count);
        Assert.Contains(result.Combinations, c =>
            c["os"] == "ubuntu-latest" && c["node"] == "18");
        Assert.Contains(result.Combinations, c =>
            c["os"] == "ubuntu-latest" && c["node"] == "20");
        Assert.Contains(result.Combinations, c =>
            c["os"] == "windows-latest" && c["node"] == "18");
        Assert.Contains(result.Combinations, c =>
            c["os"] == "windows-latest" && c["node"] == "20");
    }

    // RED: Test single dimension produces one entry per value
    [Fact]
    public void GenerateMatrix_WithSingleDimension_ProducesOneEntryPerValue()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest", "macos-latest" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(3, result.Combinations.Count);
        Assert.All(result.Combinations, c => Assert.Single(c)); // each combo has 1 key
    }

    // RED: Test three dimensions
    [Fact]
    public void GenerateMatrix_WithThreeDimensions_ProducesFullCartesianProduct()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" },
                ["python"] = new() { "3.10", "3.11" },
                ["arch"] = new() { "x64", "arm64" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        // 2 * 2 * 2 = 8 combinations
        Assert.Equal(8, result.Combinations.Count);
    }

    // RED: Test empty matrix config
    [Fact]
    public void GenerateMatrix_WithEmptyMatrix_ProducesEmptyResult()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>()
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Empty(result.Combinations);
    }
}
