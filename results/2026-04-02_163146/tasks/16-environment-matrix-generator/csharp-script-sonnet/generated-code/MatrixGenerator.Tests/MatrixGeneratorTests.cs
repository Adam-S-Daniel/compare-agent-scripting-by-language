// TDD tests for the Environment Matrix Generator
// We follow red/green/refactor: write a failing test, write minimum code to pass, refactor.

using Xunit;
using MatrixGeneratorLib;
using System.Text.Json;

public class MatrixGeneratorTests
{
    // ===== RED: Test 1 — Single OS dimension produces matrix with OS key =====
    [Fact]
    public void GenerateMatrix_SingleOsDimension_ReturnsDimensionInMatrix()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"]
            }
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        Assert.NotNull(result);
        Assert.True(result.Matrix.ContainsKey("os"));
        var osList = Assert.IsType<List<string>>(result.Matrix["os"]);
        Assert.Equal(2, osList.Count);
        Assert.Contains("ubuntu-latest", osList);
        Assert.Contains("windows-latest", osList);
    }

    // ===== Test 2 — Multiple dimensions are all present in output =====
    [Fact]
    public void GenerateMatrix_MultipleDimensions_AllDimensionsPresent()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],
                ["language-version"] = ["3.9", "3.10", "3.11"]
            }
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        Assert.True(result.Matrix.ContainsKey("os"));
        Assert.True(result.Matrix.ContainsKey("language-version"));
        var langList = Assert.IsType<List<string>>(result.Matrix["language-version"]);
        Assert.Equal(3, langList.Count);
    }

    // ===== Test 3 — Matrix size is calculated as Cartesian product =====
    [Fact]
    public void CalculateMatrixSize_TwoDimensions_ReturnsProduct()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],       // 2
                ["language-version"] = ["3.9", "3.10", "3.11"]     // 3
            }
        };

        var calculator = new MatrixSizeCalculator();
        var size = calculator.CalculateBaseSize(config.Dimensions);

        Assert.Equal(6, size); // 2 * 3 = 6
    }

    // ===== Test 4 — Matrix size with three dimensions =====
    [Fact]
    public void CalculateMatrixSize_ThreeDimensions_ReturnsProduct()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],       // 2
                ["language-version"] = ["3.9", "3.10", "3.11"],    // 3
                ["feature"] = ["a", "b"]                            // 2
            }
        };

        var calculator = new MatrixSizeCalculator();
        var size = calculator.CalculateBaseSize(config.Dimensions);

        Assert.Equal(12, size); // 2 * 3 * 2 = 12
    }

    // ===== Test 5 — Matrix validation fails when size exceeds max =====
    [Fact]
    public void ValidateMatrix_ExceedsMaxSize_ThrowsException()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest", "macos-latest"],  // 3
                ["version"] = Enumerable.Range(1, 10).Select(i => $"v{i}").ToList(), // 10
                ["flag"] = ["on", "off"]                                          // 2
            },
            MaxMatrixSize = 50 // 3*10*2 = 60 > 50
        };

        var generator = new MatrixGenerator();
        var ex = Assert.Throws<MatrixValidationException>(() => generator.Generate(config));
        Assert.Contains("60", ex.Message);
        Assert.Contains("50", ex.Message);
    }

    // ===== Test 6 — Matrix validation passes when size is within limit =====
    [Fact]
    public void ValidateMatrix_WithinMaxSize_DoesNotThrow()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],
                ["version"] = ["3.9", "3.10"]
            },
            MaxMatrixSize = 10 // 2*2 = 4 <= 10
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config); // should not throw
        Assert.NotNull(result);
    }

    // ===== Test 7 — Include rules are passed through to output =====
    [Fact]
    public void GenerateMatrix_WithIncludeRules_IncludesAreInOutput()
    {
        var includeEntry = new Dictionary<string, string>
        {
            ["os"] = "ubuntu-latest",
            ["extra-config"] = "special-value"
        };

        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"]
            },
            Include = [includeEntry]
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        Assert.True(result.Matrix.ContainsKey("include"));
        var includes = Assert.IsType<List<Dictionary<string, string>>>(result.Matrix["include"]);
        Assert.Single(includes);
        Assert.Equal("special-value", includes[0]["extra-config"]);
    }

    // ===== Test 8 — Exclude rules are passed through to output =====
    [Fact]
    public void GenerateMatrix_WithExcludeRules_ExcludesAreInOutput()
    {
        var excludeEntry = new Dictionary<string, string>
        {
            ["os"] = "windows-latest",
            ["language-version"] = "3.9"
        };

        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],
                ["language-version"] = ["3.9", "3.10"]
            },
            Exclude = [excludeEntry]
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        Assert.True(result.Matrix.ContainsKey("exclude"));
        var excludes = Assert.IsType<List<Dictionary<string, string>>>(result.Matrix["exclude"]);
        Assert.Single(excludes);
        Assert.Equal("windows-latest", excludes[0]["os"]);
    }

    // ===== Test 9 — Max-parallel is reflected in output =====
    [Fact]
    public void GenerateMatrix_WithMaxParallel_MaxParallelInOutput()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest"]
            },
            MaxParallel = 4
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        Assert.Equal(4, result.MaxParallel);
    }

    // ===== Test 10 — Fail-fast is reflected in output =====
    [Fact]
    public void GenerateMatrix_WithFailFastFalse_FailFastInOutput()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest"]
            },
            FailFast = false
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        Assert.False(result.FailFast);
    }

    // ===== Test 11 — JSON output has correct structure =====
    [Fact]
    public void ToJson_BasicMatrix_ProducesValidJson()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],
                ["language-version"] = ["3.9", "3.10"]
            },
            MaxParallel = 2,
            FailFast = true
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);
        var json = result.ToJson();

        // Should be valid JSON
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal(JsonValueKind.Object, root.ValueKind);
        Assert.True(root.TryGetProperty("strategy", out var strategy));
        Assert.True(strategy.TryGetProperty("matrix", out var matrix));
        Assert.True(strategy.TryGetProperty("max-parallel", out var maxParallel));
        Assert.Equal(2, maxParallel.GetInt32());
        Assert.True(strategy.TryGetProperty("fail-fast", out var failFast));
        Assert.True(failFast.GetBoolean());
        Assert.True(matrix.TryGetProperty("os", out _));
        Assert.True(matrix.TryGetProperty("language-version", out _));
    }

    // ===== Test 12 — Parsing a JSON config input =====
    [Fact]
    public void ParseConfig_ValidJson_ReturnsMatrixConfig()
    {
        var json = """
        {
          "dimensions": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python-version": ["3.9", "3.10", "3.11"]
          },
          "include": [
            { "os": "ubuntu-latest", "experimental": "true" }
          ],
          "exclude": [
            { "os": "windows-latest", "python-version": "3.9" }
          ],
          "max-parallel": 4,
          "fail-fast": false,
          "max-matrix-size": 100
        }
        """;

        var parser = new MatrixConfigParser();
        var config = parser.Parse(json);

        Assert.Equal(2, config.Dimensions["os"].Count);
        Assert.Equal(3, config.Dimensions["python-version"].Count);
        Assert.Single(config.Include);
        Assert.Single(config.Exclude);
        Assert.Equal(4, config.MaxParallel);
        Assert.False(config.FailFast);
        Assert.Equal(100, config.MaxMatrixSize);
    }

    // ===== Test 13 — Empty dimensions returns empty matrix =====
    [Fact]
    public void GenerateMatrix_NoDimensions_ReturnsEmptyMatrix()
    {
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>()
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config);

        // Matrix should not have any dimension keys (only possibly include/exclude)
        Assert.DoesNotContain(result.Matrix.Keys, k => k != "include" && k != "exclude");
    }

    // ===== Test 14 — Effective matrix size accounts for excludes =====
    [Fact]
    public void CalculateEffectiveSize_WithExcludes_ReducesCount()
    {
        // 2 * 2 = 4 combinations, exclude 1 = effective 3
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["ubuntu-latest", "windows-latest"],
                ["version"] = ["3.9", "3.10"]
            },
            Exclude =
            [
                new Dictionary<string, string>
                {
                    ["os"] = "windows-latest",
                    ["version"] = "3.9"
                }
            ]
        };

        var calculator = new MatrixSizeCalculator();
        var effectiveSize = calculator.CalculateEffectiveSize(config);

        Assert.Equal(3, effectiveSize);
    }

    // ===== Test 15 — Validation uses effective size (after excludes) =====
    [Fact]
    public void ValidateMatrix_BaseSizeExceedsMaxButEffectiveSizeDoesNot_DoesNotThrow()
    {
        // 3 * 3 = 9 base, but exclude 5 entries to get effective 4, max = 5
        var config = new MatrixConfig
        {
            Dimensions = new Dictionary<string, List<string>>
            {
                ["os"] = ["a", "b", "c"],
                ["version"] = ["1", "2", "3"]
            },
            Exclude =
            [
                new() { ["os"] = "a", ["version"] = "1" },
                new() { ["os"] = "a", ["version"] = "2" },
                new() { ["os"] = "b", ["version"] = "1" },
                new() { ["os"] = "b", ["version"] = "2" },
                new() { ["os"] = "c", ["version"] = "1" },
            ],
            MaxMatrixSize = 5 // effective = 9 - 5 = 4
        };

        var generator = new MatrixGenerator();
        var result = generator.Generate(config); // should not throw
        Assert.NotNull(result);
    }
}
