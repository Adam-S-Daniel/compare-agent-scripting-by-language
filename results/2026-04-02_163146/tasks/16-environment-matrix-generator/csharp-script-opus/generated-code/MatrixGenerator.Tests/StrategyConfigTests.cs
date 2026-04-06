using Xunit;

// TDD: Tests for max-parallel and fail-fast strategy configuration.

namespace MatrixGenerator.Tests;

public class StrategyConfigTests
{
    [Fact]
    public void MaxParallel_WhenSet_IncludedInResult()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" }
            },
            MaxParallel = 2
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Equal(2, result.MaxParallel);
    }

    [Fact]
    public void MaxParallel_WhenNotSet_IsNull()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.Null(result.MaxParallel);
    }

    [Fact]
    public void FailFast_DefaultsToTrue()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" }
            }
        };

        var result = MatrixGenerator.Generate(config);

        Assert.True(result.FailFast);
    }

    [Fact]
    public void FailFast_WhenSetToFalse_IsPreserved()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest" }
            },
            FailFast = false
        };

        var result = MatrixGenerator.Generate(config);

        Assert.False(result.FailFast);
    }

    [Fact]
    public void MaxParallel_ZeroValue_TreatedAsNoLimit()
    {
        var config = new MatrixConfig
        {
            Matrix = new Dictionary<string, List<string>>
            {
                ["os"] = new() { "ubuntu-latest", "windows-latest" }
            },
            MaxParallel = 0
        };

        var result = MatrixGenerator.Generate(config);

        // 0 means no limit, same as null
        Assert.Equal(0, result.MaxParallel);
    }
}
