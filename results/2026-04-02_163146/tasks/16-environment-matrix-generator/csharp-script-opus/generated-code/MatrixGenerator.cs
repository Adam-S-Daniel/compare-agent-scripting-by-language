// Environment Matrix Generator for GitHub Actions
// .NET 10 file-based app — run with: dotnet run MatrixGenerator.cs [config.json]
//
// Generates a build matrix (as JSON) suitable for GitHub Actions strategy.matrix.
// Supports:
//   - Cartesian product of OS options, language versions, and feature flags
//   - Include rules (add specific combinations)
//   - Exclude rules (remove specific combinations)
//   - Max-parallel limits
//   - Fail-fast configuration
//   - Matrix size validation (default max: 256, matching GitHub Actions limit)
//
// Usage:
//   dotnet run MatrixGenerator.cs config.json         # Read config from file
//   echo '{"matrix":...}' | dotnet run MatrixGenerator.cs  # Read from stdin
//   dotnet run MatrixGenerator.cs --help              # Show usage

#nullable enable

using System.Text.Json;

// --- Entry Point ---

if (args.Length > 0 && args[0] is "--help" or "-h")
{
    PrintUsage();
    return;
}

try
{
    string json = ReadInput(args);
    var config = ParseConfig(json);
    var result = GenerateMatrix(config);
    var output = ToOutputJson(result);
    Console.WriteLine(output);
}
catch (ArgumentException ex)
{
    Console.Error.WriteLine($"Configuration error: {ex.Message}");
    Environment.Exit(1);
}
catch (InvalidOperationException ex)
{
    Console.Error.WriteLine($"Matrix generation error: {ex.Message}");
    Environment.Exit(1);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    Environment.Exit(2);
}

// --- Input Handling ---

static string ReadInput(string[] args)
{
    if (args.Length > 0 && args[0] is not "--help" and not "-h")
    {
        var filePath = args[0];
        if (!File.Exists(filePath))
            throw new ArgumentException($"Configuration file not found: {filePath}");
        return File.ReadAllText(filePath);
    }

    // Read from stdin if no file argument
    if (Console.IsInputRedirected)
    {
        return Console.In.ReadToEnd();
    }

    throw new ArgumentException(
        "No input provided. Pass a config file path as argument or pipe JSON to stdin. Use --help for usage.");
}

static void PrintUsage()
{
    Console.WriteLine("""
    Environment Matrix Generator for GitHub Actions

    Generates a build matrix (JSON) suitable for GitHub Actions strategy.matrix.

    Usage:
      dotnet run MatrixGenerator.cs <config.json>
      cat config.json | dotnet run MatrixGenerator.cs

    Config format (JSON):
    {
      "matrix": {
        "os": ["ubuntu-latest", "windows-latest"],
        "node": ["18", "20"]
      },
      "include": [
        { "os": "ubuntu-latest", "node": "21", "experimental": "true" }
      ],
      "exclude": [
        { "os": "windows-latest", "node": "18" }
      ],
      "fail-fast": false,
      "max-parallel": 4,
      "max-matrix-size": 256
    }

    Output: Complete strategy.matrix JSON to stdout.
    Errors are written to stderr with non-zero exit code.
    """);
}

// --- Config Parsing ---

static MatrixConfig ParseConfig(string json)
{
    if (string.IsNullOrWhiteSpace(json))
        throw new ArgumentException("Configuration JSON cannot be empty.");

    JsonDocument doc;
    try
    {
        doc = JsonDocument.Parse(json);
    }
    catch (JsonException ex)
    {
        throw new ArgumentException($"Invalid JSON configuration: {ex.Message}", ex);
    }

    var root = doc.RootElement;

    if (!root.TryGetProperty("matrix", out var matrixElement))
        throw new ArgumentException("Configuration must contain a 'matrix' property.");

    return new MatrixConfig
    {
        Matrix = ParseDimensions(matrixElement),
        Include = ParseRules(root, "include"),
        Exclude = ParseRules(root, "exclude"),
        FailFast = GetBool(root, "fail-fast", true),
        MaxParallel = GetNullableInt(root, "max-parallel"),
        MaxMatrixSize = GetInt(root, "max-matrix-size", 256)
    };
}

static Dictionary<string, List<string>> ParseDimensions(JsonElement element)
{
    var dims = new Dictionary<string, List<string>>();
    foreach (var prop in element.EnumerateObject())
    {
        if (prop.Value.ValueKind != JsonValueKind.Array) continue;
        dims[prop.Name] = prop.Value.EnumerateArray().Select(ToStr).ToList();
    }
    return dims;
}

static List<Dictionary<string, string>> ParseRules(JsonElement root, string name)
{
    if (!root.TryGetProperty(name, out var arr) || arr.ValueKind != JsonValueKind.Array)
        return new();
    return arr.EnumerateArray()
        .Select(item => item.EnumerateObject().ToDictionary(p => p.Name, p => ToStr(p.Value)))
        .ToList();
}

static string ToStr(JsonElement e) => e.ValueKind switch
{
    JsonValueKind.String => e.GetString() ?? "",
    JsonValueKind.Number => e.GetRawText(),
    JsonValueKind.True => "true",
    JsonValueKind.False => "false",
    _ => e.GetRawText()
};

static bool GetBool(JsonElement root, string name, bool def)
{
    if (root.TryGetProperty(name, out var p))
        return p.ValueKind == JsonValueKind.True;
    return def;
}

static int? GetNullableInt(JsonElement root, string name)
{
    if (root.TryGetProperty(name, out var p) && p.ValueKind == JsonValueKind.Number)
        return p.GetInt32();
    return null;
}

static int GetInt(JsonElement root, string name, int def)
{
    if (root.TryGetProperty(name, out var p) && p.ValueKind == JsonValueKind.Number)
        return p.GetInt32();
    return def;
}

// --- Matrix Generation ---

static MatrixResult GenerateMatrix(MatrixConfig config)
{
    var combos = CartesianProduct(config.Matrix);
    combos = ApplyExcludes(combos, config.Exclude);
    combos = ApplyIncludes(combos, config.Include);
    ValidateSize(combos.Count, config.MaxMatrixSize);

    return new MatrixResult
    {
        Combinations = combos,
        MaxParallel = config.MaxParallel,
        FailFast = config.FailFast
    };
}

static List<Dictionary<string, string>> CartesianProduct(Dictionary<string, List<string>> matrix)
{
    if (matrix.Count == 0) return new();

    var result = new List<Dictionary<string, string>> { new() };
    foreach (var (key, values) in matrix)
    {
        if (values.Count == 0)
            throw new ArgumentException($"Matrix dimension '{key}' has no values.");

        var expanded = new List<Dictionary<string, string>>();
        foreach (var combo in result)
            foreach (var val in values)
            {
                var newCombo = new Dictionary<string, string>(combo) { [key] = val };
                expanded.Add(newCombo);
            }
        result = expanded;
    }
    return result;
}

static List<Dictionary<string, string>> ApplyExcludes(
    List<Dictionary<string, string>> combos, List<Dictionary<string, string>> rules)
{
    if (rules.Count == 0) return combos;
    return combos.Where(c => !rules.Any(r => Matches(c, r))).ToList();
}

static List<Dictionary<string, string>> ApplyIncludes(
    List<Dictionary<string, string>> combos, List<Dictionary<string, string>> rules)
{
    if (rules.Count == 0) return combos;

    var result = combos.Select(c => new Dictionary<string, string>(c)).ToList();
    foreach (var inc in rules)
    {
        bool merged = false;
        for (int i = 0; i < result.Count; i++)
        {
            if (IncludeMatches(result[i], inc))
            {
                foreach (var (k, v) in inc) result[i][k] = v;
                merged = true;
            }
        }
        if (!merged) result.Add(new Dictionary<string, string>(inc));
    }
    return result;
}

// For exclude rules: ALL keys in the rule must be present in the combo with same values
static bool Matches(Dictionary<string, string> combo, Dictionary<string, string> rule) =>
    rule.All(kv => combo.TryGetValue(kv.Key, out var v) && v == kv.Value);

// For include rules: all OVERLAPPING keys must match, and there must be at least one overlap
static bool IncludeMatches(Dictionary<string, string> combo, Dictionary<string, string> include)
{
    var overlapping = include.Keys.Where(k => combo.ContainsKey(k)).ToList();
    if (overlapping.Count == 0) return false;
    return overlapping.All(k => combo[k] == include[k]);
}

static void ValidateSize(int size, int max)
{
    if (size > max)
        throw new InvalidOperationException(
            $"Matrix size ({size}) exceeds maximum allowed size ({max}). " +
            $"GitHub Actions limits matrices to {max} combinations. " +
            "Consider using exclude rules or reducing dimensions.");
}

// --- JSON Output ---

static string ToOutputJson(MatrixResult result)
{
    var strategy = new Dictionary<string, object>
    {
        ["fail-fast"] = result.FailFast,
        ["matrix"] = BuildMatrix(result.Combinations)
    };
    if (result.MaxParallel is > 0)
        strategy["max-parallel"] = result.MaxParallel.Value;

    var output = new Dictionary<string, object> { ["strategy"] = strategy };
    return JsonSerializer.Serialize(output, new JsonSerializerOptions
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.KebabCaseLower
    });
}

static Dictionary<string, object> BuildMatrix(List<Dictionary<string, string>> combos)
{
    if (combos.Count == 0) return new();

    // Collect unique values per dimension
    var dims = new Dictionary<string, HashSet<string>>();
    foreach (var c in combos)
        foreach (var (k, v) in c)
        {
            if (!dims.ContainsKey(k)) dims[k] = new();
            dims[k].Add(v);
        }

    var obj = new Dictionary<string, object>();
    foreach (var (k, vals) in dims)
        obj[k] = vals.OrderBy(v => v).ToList();

    obj["include"] = combos;
    return obj;
}

// --- Types ---

record MatrixConfig
{
    public Dictionary<string, List<string>> Matrix { get; init; } = new();
    public List<Dictionary<string, string>> Include { get; init; } = new();
    public List<Dictionary<string, string>> Exclude { get; init; } = new();
    public int? MaxParallel { get; init; }
    public bool FailFast { get; init; } = true;
    public int MaxMatrixSize { get; init; } = 256;
}

record MatrixResult
{
    public List<Dictionary<string, string>> Combinations { get; init; } = new();
    public int? MaxParallel { get; init; }
    public bool FailFast { get; init; } = true;
}
