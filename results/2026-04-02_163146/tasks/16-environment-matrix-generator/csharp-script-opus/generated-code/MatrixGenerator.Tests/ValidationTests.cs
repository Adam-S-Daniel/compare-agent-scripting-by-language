using Xunit;

// TDD: Tests for matrix size validation and error handling.
// GitHub Actions limits matrices to 256 combinations by default.

namespace MatrixGenerator.Tests;

public class ValidationTests
{
    [Fact]
    public void Validate_ExceedsMaxSize_ThrowsWithMessage()
    {
        // Create a config that would produce too many combinations (3^6 = 729 > 256)
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["a"] = new() { "1", "2", "3" },
                ["b"] = new() { "1", "2", "3" },
                ["c"] = new() { "1", "2", "3" },
                ["d"] = new() { "1", "2", "3" },
                ["e"] = new() { "1", "2", "3" },
                ["f"] = new() { "1", "2", "3" }
            },
            MaxMatrixSize = 256
        };

        var ex = Assert.Throws<InvalidOperationException>(() =>
            MatrixGenerator.Generate(config));

        Assert.Contains("729", ex.Message);
        Assert.Contains("256", ex.Message);
    }

    [Fact]
    public void Validate_ExactlyAtMaxSize_Succeeds()
    {
        // 4 * 4 = 16, set max to 16
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["a"] = new() { "1", "2", "3", "4" },
                ["b"] = new() { "1", "2", "3", "4" }
            },
            MaxMatrixSize = 16
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(16, result.Combinations.Count);
    }

    [Fact]
    public void Validate_CustomMaxSize_Respected()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["a"] = new() { "1", "2", "3" },
                ["b"] = new() { "1", "2", "3" }
            },
            MaxMatrixSize = 5 // 3*3=9 > 5
        };

        var ex = Assert.Throws<InvalidOperationException>(() =>
            MatrixGenerator.Generate(config));

        Assert.Contains("9", ex.Message);
        Assert.Contains("5", ex.Message);
    }

    [Fact]
    public void Validate_ExcludesReduceSizeBelowMax_Succeeds()
    {
        // 3*3=9, but with 5 excludes => 4, and max is 5
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["a"] = new() { "1", "2", "3" },
                ["b"] = new() { "1", "2", "3" }
            },
            Exclude = new()
            {
                new() { ["a"] = "1", ["b"] = "1" },
                new() { ["a"] = "1", ["b"] = "2" },
                new() { ["a"] = "2", ["b"] = "1" },
                new() { ["a"] = "2", ["b"] = "2" },
                new() { ["a"] = "3", ["b"] = "1" }
            },
            MaxMatrixSize = 5
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(4, result.Combinations.Count);
    }

    [Fact]
    public void Validate_NullConfig_ThrowsArgumentNull()
    {
        Assert.Throws<ArgumentNullException>(() =>
            MatrixGenerator.Generate(null!));
    }

    [Fact]
    public void Validate_EmptyDimensionValues_ThrowsArgumentException()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" },
                ["node"] = new() // empty!
            }
        };

        var ex = Assert.Throws<ArgumentException>(() =>
            MatrixGenerator.Generate(config));

        Assert.Contains("node", ex.Message);
    }
}
