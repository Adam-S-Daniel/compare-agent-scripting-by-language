// generate-matrix.cs — .NET 10 file-based app (run with: dotnet run generate-matrix.cs)
//
// Generates a GitHub Actions strategy.matrix JSON from a configuration file or stdin.
//
// Usage:
//   dotnet run generate-matrix.cs [config.json]
//   echo '{"dimensions":{"os":["ubuntu-latest"]}}' | dotnet run generate-matrix.cs
//
// The configuration JSON format:
// {
//   "dimensions": {
//     "os": ["ubuntu-latest", "windows-latest"],
//     "python-version": ["3.9", "3.10", "3.11"]
//   },
//   "include": [{ "os": "ubuntu-latest", "experimental": "true" }],
//   "exclude": [{ "os": "windows-latest", "python-version": "3.9" }],
//   "max-parallel": 4,
//   "fail-fast": false,
//   "max-matrix-size": 256
// }

using System.Text.Json;
using System.Text.Json.Serialization;

// ─────────────────────────────────────────────────────────────────────────────
// Domain exceptions
// ─────────────────────────────────────────────────────────────────────────────

class MatrixValidationException(string message) : Exception(message);

// ─────────────────────────────────────────────────────────────────────────────
// Input model
// ─────────────────────────────────────────────────────────────────────────────

class MatrixConfig
{
    public Dictionary<string, List<string>> Dimensions { get; set; } = new();
    public List<Dictionary<string, string>> Include { get; set; } = new();
    public List<Dictionary<string, string>> Exclude { get; set; } = new();
    public int? MaxParallel { get; set; }
    public bool FailFast { get; set; } = true;
    public int MaxMatrixSize { get; set; } = 256;
}

// ─────────────────────────────────────────────────────────────────────────────
// Output model
// ─────────────────────────────────────────────────────────────────────────────

class MatrixResult
{
    public Dictionary<string, object> Matrix { get; set; } = new();
    public int? MaxParallel { get; set; }
    public bool FailFast { get; set; } = true;

    public string ToJson()
    {
        var strategy = new Dictionary<string, object>
        {
            ["matrix"] = Matrix,
            ["fail-fast"] = FailFast
        };

        if (MaxParallel.HasValue)
            strategy["max-parallel"] = MaxParallel.Value;

        var root = new Dictionary<string, object>
        {
            ["strategy"] = strategy
        };

        return JsonSerializer.Serialize(root, new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = null
        });
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Matrix size calculator
// ─────────────────────────────────────────────────────────────────────────────

class MatrixSizeCalculator
{
    public int CalculateBaseSize(Dictionary<string, List<string>> dimensions)
    {
        if (dimensions.Count == 0) return 0;
        return dimensions.Values.Aggregate(1, (acc, v) => acc * v.Count);
    }

    public int CalculateEffectiveSize(MatrixConfig config)
    {
        var all = GenerateCombinations(config.Dimensions);
        return all.Count(combo => !IsExcluded(combo, config.Exclude));
    }

    static List<Dictionary<string, string>> GenerateCombinations(Dictionary<string, List<string>> dims)
    {
        if (dims.Count == 0) return [];
        List<Dictionary<string, string>> result = [new()];
        foreach (var (key, values) in dims)
        {
            var expanded = new List<Dictionary<string, string>>();
            foreach (var existing in result)
                foreach (var value in values)
                    expanded.Add(new Dictionary<string, string>(existing) { [key] = value });
            result = expanded;
        }
        return result;
    }

    static bool IsExcluded(Dictionary<string, string> combo, List<Dictionary<string, string>> rules)
        => rules.Any(rule => rule.All(kv => combo.TryGetValue(kv.Key, out var v) && v == kv.Value));
}

// ─────────────────────────────────────────────────────────────────────────────
// Matrix generator
// ─────────────────────────────────────────────────────────────────────────────

class MatrixGenerator(MatrixSizeCalculator? calculator = null)
{
    private readonly MatrixSizeCalculator _calc = calculator ?? new MatrixSizeCalculator();

    public MatrixResult Generate(MatrixConfig config)
    {
        // Validate effective size against max
        if (config.Dimensions.Count > 0)
        {
            int effective = _calc.CalculateEffectiveSize(config);
            if (effective > config.MaxMatrixSize)
            {
                int baseSize = _calc.CalculateBaseSize(config.Dimensions);
                throw new MatrixValidationException(
                    $"Matrix effective size ({effective}) exceeds maximum ({config.MaxMatrixSize}). " +
                    $"Base (Cartesian) size is {baseSize}. " +
                    "Reduce dimensions, add exclude rules, or increase max-matrix-size.");
            }
        }

        var matrix = new Dictionary<string, object>();

        foreach (var (key, values) in config.Dimensions)
            matrix[key] = new List<string>(values);

        if (config.Include.Count > 0)
            matrix["include"] = config.Include.Select(d => new Dictionary<string, string>(d)).ToList();

        if (config.Exclude.Count > 0)
            matrix["exclude"] = config.Exclude.Select(d => new Dictionary<string, string>(d)).ToList();

        return new MatrixResult
        {
            Matrix = matrix,
            MaxParallel = config.MaxParallel,
            FailFast = config.FailFast
        };
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config parser
// ─────────────────────────────────────────────────────────────────────────────

class MatrixConfigParser
{
    class ConfigDto
    {
        [JsonPropertyName("dimensions")]
        public Dictionary<string, List<string>>? Dimensions { get; set; }

        [JsonPropertyName("include")]
        public List<Dictionary<string, string>>? Include { get; set; }

        [JsonPropertyName("exclude")]
        public List<Dictionary<string, string>>? Exclude { get; set; }

        [JsonPropertyName("max-parallel")]
        public int? MaxParallel { get; set; }

        [JsonPropertyName("fail-fast")]
        public bool? FailFast { get; set; }

        [JsonPropertyName("max-matrix-size")]
        public int? MaxMatrixSize { get; set; }
    }

    public MatrixConfig Parse(string json)
    {
        var dto = JsonSerializer.Deserialize<ConfigDto>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new JsonException("Input JSON is null.");

        var config = new MatrixConfig
        {
            Dimensions = dto.Dimensions ?? new(),
            Include = dto.Include ?? new(),
            Exclude = dto.Exclude ?? new()
        };

        if (dto.MaxParallel.HasValue) config.MaxParallel = dto.MaxParallel;
        if (dto.FailFast.HasValue)    config.FailFast    = dto.FailFast.Value;
        if (dto.MaxMatrixSize.HasValue) config.MaxMatrixSize = dto.MaxMatrixSize.Value;

        return config;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point (top-level statements)
// ─────────────────────────────────────────────────────────────────────────────

string inputJson;

if (args.Length > 0)
{
    // Read from file path argument
    var filePath = args[0];
    if (!File.Exists(filePath))
    {
        Console.Error.WriteLine($"Error: file not found: {filePath}");
        Environment.Exit(1);
    }
    inputJson = await File.ReadAllTextAsync(filePath);
}
else if (!Console.IsInputRedirected)
{
    // No argument and no stdin: show usage and a demo
    Console.Error.WriteLine("Usage: dotnet run generate-matrix.cs [config.json]");
    Console.Error.WriteLine("       echo '{...}' | dotnet run generate-matrix.cs");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Running demo matrix...");

    inputJson = """
    {
      "dimensions": {
        "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
        "python-version": ["3.9", "3.10", "3.11"],
        "feature-flags": ["enabled", "disabled"]
      },
      "include": [
        { "os": "ubuntu-latest", "experimental": "true" }
      ],
      "exclude": [
        { "os": "windows-latest", "python-version": "3.9" },
        { "os": "macos-latest",   "python-version": "3.9" }
      ],
      "max-parallel": 6,
      "fail-fast": false,
      "max-matrix-size": 256
    }
    """;
}
else
{
    inputJson = await new StreamReader(Console.OpenStandardInput()).ReadToEndAsync();
}

try
{
    var parser = new MatrixConfigParser();
    var config = parser.Parse(inputJson);

    var calculator = new MatrixSizeCalculator();
    int baseSize = calculator.CalculateBaseSize(config.Dimensions);
    int effectiveSize = calculator.CalculateEffectiveSize(config);

    var generator = new MatrixGenerator(calculator);
    var result = generator.Generate(config);

    Console.Error.WriteLine($"Base matrix size (Cartesian product): {baseSize}");
    Console.Error.WriteLine($"Effective matrix size (after excludes): {effectiveSize}");
    Console.Error.WriteLine($"Maximum allowed size: {config.MaxMatrixSize}");
    Console.Error.WriteLine();

    // Output the matrix JSON to stdout
    Console.WriteLine(result.ToJson());
}
catch (MatrixValidationException ex)
{
    Console.Error.WriteLine($"Validation error: {ex.Message}");
    Environment.Exit(2);
}
catch (JsonException ex)
{
    Console.Error.WriteLine($"JSON parse error: {ex.Message}");
    Environment.Exit(3);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    Environment.Exit(1);
}
