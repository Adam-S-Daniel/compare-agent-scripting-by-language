using System.Text.Json;
using Xunit;

// TDD: Tests for parsing JSON configuration input into MatrixConfig.

namespace MatrixGenerator.Tests;

public class ConfigParsingTests
{
    [Fact]
    public void ParseConfig_BasicJson_ProducesValidConfig()
    {
        var json = """
        {
            "matrix": {
                "os": ["ubuntu-latest", "windows-latest"],
                "node": ["18", "20"]
            }
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.Equal(2, config.Matrix.Count);
        Assert.Equal(2, config.Matrix["os"].Count);
        Assert.Equal(2, config.Matrix["node"].Count);
    }

    [Fact]
    public void ParseConfig_WithExclude_ParsesCorrectly()
    {
        var json = """
        {
            "matrix": {
                "os": ["ubuntu-latest", "windows-latest"],
                "node": ["18", "20"]
            },
            "exclude": [
                { "os": "windows-latest", "node": "18" }
            ]
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.Single(config.Exclude);
        Assert.Equal("windows-latest", config.Exclude[0]["os"]);
        Assert.Equal("18", config.Exclude[0]["node"]);
    }

    [Fact]
    public void ParseConfig_WithInclude_ParsesCorrectly()
    {
        var json = """
        {
            "matrix": {
                "os": ["ubuntu-latest"],
                "node": ["18"]
            },
            "include": [
                { "os": "macos-latest", "node": "20", "experimental": "true" }
            ]
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.Single(config.Include);
        Assert.Equal(3, config.Include[0].Count);
    }

    [Fact]
    public void ParseConfig_WithStrategySettings_ParsesCorrectly()
    {
        var json = """
        {
            "matrix": {
                "os": ["ubuntu-latest"]
            },
            "fail-fast": false,
            "max-parallel": 4,
            "max-matrix-size": 100
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.False(config.FailFast);
        Assert.Equal(4, config.MaxParallel);
        Assert.Equal(100, config.MaxMatrixSize);
    }

    [Fact]
    public void ParseConfig_DefaultValues_AppliedWhenMissing()
    {
        var json = """
        {
            "matrix": {
                "os": ["ubuntu-latest"]
            }
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.True(config.FailFast);
        Assert.Null(config.MaxParallel);
        Assert.Equal(256, config.MaxMatrixSize);
        Assert.Empty(config.Include);
        Assert.Empty(config.Exclude);
    }

    [Fact]
    public void ParseConfig_InvalidJson_ThrowsMeaningfulError()
    {
        var json = "not valid json {{{";

        var ex = Assert.Throws<ArgumentException>(() =>
            MatrixConfigParser.Parse(json));

        Assert.Contains("Invalid JSON", ex.Message);
    }

    [Fact]
    public void ParseConfig_MissingMatrix_ThrowsMeaningfulError()
    {
        var json = """
        {
            "fail-fast": true
        }
        """;

        var ex = Assert.Throws<ArgumentException>(() =>
            MatrixConfigParser.Parse(json));

        Assert.Contains("matrix", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ParseConfig_NumericValuesInMatrix_ConvertedToStrings()
    {
        // GitHub Actions matrix values can be numbers; we treat everything as strings
        var json = """
        {
            "matrix": {
                "node": [16, 18, 20],
                "os": ["ubuntu-latest"]
            }
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.Equal(3, config.Matrix["node"].Count);
        Assert.Contains("16", config.Matrix["node"]);
        Assert.Contains("18", config.Matrix["node"]);
        Assert.Contains("20", config.Matrix["node"]);
    }

    [Fact]
    public void ParseConfig_BooleanValuesInMatrix_ConvertedToStrings()
    {
        var json = """
        {
            "matrix": {
                "experimental": [true, false],
                "os": ["ubuntu-latest"]
            }
        }
        """;

        var config = MatrixConfigParser.Parse(json);

        Assert.Equal(2, config.Matrix["experimental"].Count);
        // Booleans should be lowercased strings
        Assert.Contains("true", config.Matrix["experimental"]);
        Assert.Contains("false", config.Matrix["experimental"]);
    }
}
