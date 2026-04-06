using System.Text.Json;
using Xunit;

// TDD: Tests for JSON serialization of the matrix output.
// The output should be valid GitHub Actions strategy.matrix JSON.

namespace MatrixGenerator.Tests;

public class JsonOutputTests
{
    [Fact]
    public void ToJson_ProducesValidJson()
    {
        var result = new MatrixResult
        {
            Combinations = new()
            {
                new() { ["os"] = "ubuntu-latest", ["node"] = "18" },
                new() { ["os"] = "windows-latest", ["node"] = "20" }
            },
            FailFast = true,
            MaxParallel = 2
        };

        var json = MatrixGenerator.ToJson(result);

        // Should be valid JSON
        var doc = JsonDocument.Parse(json);
        Assert.NotNull(doc);
    }

    [Fact]
    public void ToJson_ContainsStrategySection()
    {
        var result = new MatrixResult
        {
            Combinations = new()
            {
                new() { ["os"] = "ubuntu-latest" }
            },
            FailFast = true
        };

        var json = MatrixGenerator.ToJson(result);
        var doc = JsonDocument.Parse(json);

        Assert.True(doc.RootElement.TryGetProperty("strategy", out var strategy));
        Assert.True(strategy.TryGetProperty("fail-fast", out var failFast));
        Assert.True(failFast.GetBoolean());
        Assert.True(strategy.TryGetProperty("matrix", out _));
    }

    [Fact]
    public void ToJson_IncludesMaxParallel_WhenSet()
    {
        var result = new MatrixResult
        {
            Combinations = new()
            {
                new() { ["os"] = "ubuntu-latest" }
            },
            MaxParallel = 3
        };

        var json = MatrixGenerator.ToJson(result);
        var doc = JsonDocument.Parse(json);

        var strategy = doc.RootElement.GetProperty("strategy");
        Assert.True(strategy.TryGetProperty("max-parallel", out var maxParallel));
        Assert.Equal(3, maxParallel.GetInt32());
    }

    [Fact]
    public void ToJson_OmitsMaxParallel_WhenNull()
    {
        var result = new MatrixResult
        {
            Combinations = new()
            {
                new() { ["os"] = "ubuntu-latest" }
            },
            MaxParallel = null
        };

        var json = MatrixGenerator.ToJson(result);
        var doc = JsonDocument.Parse(json);

        var strategy = doc.RootElement.GetProperty("strategy");
        Assert.False(strategy.TryGetProperty("max-parallel", out _));
    }

    [Fact]
    public void ToJson_MatrixContainsDimensionArrays()
    {
        var result = new MatrixResult
        {
            Combinations = new()
            {
                new() { ["os"] = "ubuntu-latest", ["node"] = "18" },
                new() { ["os"] = "ubuntu-latest", ["node"] = "20" },
                new() { ["os"] = "windows-latest", ["node"] = "18" },
                new() { ["os"] = "windows-latest", ["node"] = "20" }
            }
        };

        var json = MatrixGenerator.ToJson(result);
        var doc = JsonDocument.Parse(json);

        var matrix = doc.RootElement.GetProperty("strategy").GetProperty("matrix");
        Assert.True(matrix.TryGetProperty("os", out var osArray));
        Assert.Equal(JsonValueKind.Array, osArray.ValueKind);
        Assert.Equal(2, osArray.GetArrayLength());
    }

    [Fact]
    public void ToJson_EmptyMatrix_ProducesEmptyStrategyMatrix()
    {
        var result = new MatrixResult
        {
            Combinations = new()
        };

        var json = MatrixGenerator.ToJson(result);
        var doc = JsonDocument.Parse(json);

        var strategy = doc.RootElement.GetProperty("strategy");
        var matrix = strategy.GetProperty("matrix");
        Assert.Equal(0, matrix.EnumerateObject().Count());
    }

    [Fact]
    public void ToJson_IncludesAllCombinationsInIncludeArray()
    {
        var result = new MatrixResult
        {
            Combinations = new()
            {
                new() { ["os"] = "ubuntu-latest", ["node"] = "18" },
                new() { ["os"] = "windows-latest", ["node"] = "20" }
            }
        };

        var json = MatrixGenerator.ToJson(result);
        var doc = JsonDocument.Parse(json);

        var matrix = doc.RootElement.GetProperty("strategy").GetProperty("matrix");
        Assert.True(matrix.TryGetProperty("include", out var include));
        Assert.Equal(2, include.GetArrayLength());
    }
}
