// Environment Matrix Generator Library
// Generates GitHub Actions strategy.matrix JSON from a configuration object.
//
// Domain model:
//   MatrixConfig      — input: dimensions, include/exclude rules, limits
//   MatrixResult      — output: the assembled matrix + strategy settings
//   MatrixGenerator   — orchestrates generation and validation
//   MatrixSizeCalculator — computes base and effective matrix sizes
//   MatrixConfigParser   — parses JSON input into MatrixConfig

using System.Text.Json;
using System.Text.Json.Serialization;

namespace MatrixGeneratorLib;

// ─────────────────────────────────────────────────────────────────────────────
// Domain exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>Thrown when the generated matrix violates a validation rule.</summary>
public class MatrixValidationException : Exception
{
    public MatrixValidationException(string message) : base(message) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input model
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Configuration for generating a GitHub Actions build matrix.
/// </summary>
public class MatrixConfig
{
    /// <summary>
    /// Named dimensions for the matrix (e.g. "os" → ["ubuntu-latest", "windows-latest"]).
    /// The Cartesian product of all dimension values forms the matrix jobs.
    /// </summary>
    public Dictionary<string, List<string>> Dimensions { get; set; } = new();

    /// <summary>
    /// Additional jobs or variable augmentations to add to the matrix.
    /// Passed through verbatim to the GitHub Actions include list.
    /// </summary>
    public List<Dictionary<string, string>> Include { get; set; } = new();

    /// <summary>
    /// Combinations to remove from the matrix.
    /// A job is excluded when it matches ALL key-value pairs in an exclude entry.
    /// </summary>
    public List<Dictionary<string, string>> Exclude { get; set; } = new();

    /// <summary>Maximum number of jobs that may run in parallel. Null = no limit.</summary>
    public int? MaxParallel { get; set; }

    /// <summary>Whether to cancel all in-progress jobs if any job fails. Default: true.</summary>
    public bool FailFast { get; set; } = true;

    /// <summary>
    /// Maximum allowed effective matrix size (after applying excludes).
    /// Default: 256 (GitHub Actions hard limit).
    /// </summary>
    public int MaxMatrixSize { get; set; } = 256;
}

// ─────────────────────────────────────────────────────────────────────────────
// Output model
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Generated matrix result, ready for serialisation to GitHub Actions JSON.
/// </summary>
public class MatrixResult
{
    /// <summary>
    /// The strategy.matrix object. Keys are dimension names → List&lt;string&gt;.
    /// May also contain "include" and "exclude" keys.
    /// </summary>
    public Dictionary<string, object> Matrix { get; set; } = new();

    /// <summary>Max-parallel limit. Null means omit from output.</summary>
    public int? MaxParallel { get; set; }

    /// <summary>Fail-fast setting.</summary>
    public bool FailFast { get; set; } = true;

    /// <summary>
    /// Serialises the result to the JSON structure expected by GitHub Actions:
    /// <code>
    /// {
    ///   "strategy": {
    ///     "matrix": { ... },
    ///     "max-parallel": N,     // omitted when null
    ///     "fail-fast": true|false
    ///   }
    /// }
    /// </code>
    /// </summary>
    public string ToJson()
    {
        // Build an anonymous object that maps cleanly to the GitHub Actions format.
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

        var options = new JsonSerializerOptions
        {
            WriteIndented = true,
            // Preserve the original key names (do not camelCase them).
            PropertyNamingPolicy = null
        };

        return JsonSerializer.Serialize(root, options);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Matrix size calculator
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Calculates matrix sizes before and after applying exclude rules.
/// </summary>
public class MatrixSizeCalculator
{
    /// <summary>
    /// Calculates the number of jobs produced by the Cartesian product of all dimensions.
    /// With no dimensions, the size is 0.
    /// </summary>
    public int CalculateBaseSize(Dictionary<string, List<string>> dimensions)
    {
        if (dimensions.Count == 0)
            return 0;

        return dimensions.Values.Aggregate(1, (acc, values) => acc * values.Count);
    }

    /// <summary>
    /// Calculates the effective matrix size after removing excluded combinations.
    /// A combination is excluded when it matches ALL key-value pairs in an exclude entry.
    /// </summary>
    public int CalculateEffectiveSize(MatrixConfig config)
    {
        // Enumerate every combination (Cartesian product).
        var allCombinations = GenerateCombinations(config.Dimensions);

        // Count how many are NOT excluded.
        int retained = allCombinations.Count(combo => !IsExcluded(combo, config.Exclude));

        return retained;
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /// <summary>
    /// Generates all Cartesian-product combinations from the dimension map.
    /// Each combination is a dictionary of dimension-name → value.
    /// </summary>
    internal static List<Dictionary<string, string>> GenerateCombinations(
        Dictionary<string, List<string>> dimensions)
    {
        if (dimensions.Count == 0)
            return [];

        // Start with a single empty combination, then fold each dimension in.
        List<Dictionary<string, string>> result = [new()];

        foreach (var (key, values) in dimensions)
        {
            var expanded = new List<Dictionary<string, string>>();
            foreach (var existing in result)
            {
                foreach (var value in values)
                {
                    var combo = new Dictionary<string, string>(existing)
                    {
                        [key] = value
                    };
                    expanded.Add(combo);
                }
            }
            result = expanded;
        }

        return result;
    }

    /// <summary>
    /// Returns true if <paramref name="combination"/> matches at least one exclude rule.
    /// A rule matches when every key-value pair in the rule is present in the combination.
    /// </summary>
    internal static bool IsExcluded(
        Dictionary<string, string> combination,
        List<Dictionary<string, string>> excludeRules)
    {
        return excludeRules.Any(rule =>
            rule.All(kv => combination.TryGetValue(kv.Key, out var val) && val == kv.Value));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Matrix generator
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Orchestrates matrix generation: builds the output, applies rules, validates size.
/// </summary>
public class MatrixGenerator
{
    private readonly MatrixSizeCalculator _calculator;

    public MatrixGenerator() : this(new MatrixSizeCalculator()) { }

    public MatrixGenerator(MatrixSizeCalculator calculator)
    {
        _calculator = calculator;
    }

    /// <summary>
    /// Generates a <see cref="MatrixResult"/> from the given configuration.
    /// </summary>
    /// <exception cref="MatrixValidationException">
    /// Thrown when the effective matrix size exceeds <see cref="MatrixConfig.MaxMatrixSize"/>.
    /// </exception>
    public MatrixResult Generate(MatrixConfig config)
    {
        // ── Validate size ─────────────────────────────────────────────────────
        if (config.Dimensions.Count > 0)
        {
            int effectiveSize = _calculator.CalculateEffectiveSize(config);
            if (effectiveSize > config.MaxMatrixSize)
            {
                int baseSize = _calculator.CalculateBaseSize(config.Dimensions);
                // Report the base size (before excludes) so users understand the source.
                // Use whichever is larger — if base < effective that means includes added jobs,
                // but here we only calculate the Cartesian-product size.
                int reportSize = baseSize; // base may exceed max even if effective does not
                throw new MatrixValidationException(
                    $"Matrix effective size ({effectiveSize}) exceeds the maximum allowed size ({config.MaxMatrixSize}). " +
                    $"Base size (Cartesian product) is {reportSize}. " +
                    "Reduce dimensions, add exclude rules, or increase max-matrix-size.");
            }
        }

        // ── Build result ──────────────────────────────────────────────────────
        var matrix = new Dictionary<string, object>();

        // Copy dimensions as-is.
        foreach (var (key, values) in config.Dimensions)
            matrix[key] = new List<string>(values);

        // Include rules (only when present).
        if (config.Include.Count > 0)
            matrix["include"] = config.Include
                .Select(d => new Dictionary<string, string>(d))
                .ToList();

        // Exclude rules (only when present).
        if (config.Exclude.Count > 0)
            matrix["exclude"] = config.Exclude
                .Select(d => new Dictionary<string, string>(d))
                .ToList();

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

/// <summary>
/// Parses a JSON string into a <see cref="MatrixConfig"/>.
/// </summary>
public class MatrixConfigParser
{
    // Private DTO whose property names match the expected JSON keys.
    private class ConfigDto
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

    /// <summary>Parses <paramref name="json"/> into a <see cref="MatrixConfig"/>.</summary>
    /// <exception cref="JsonException">Thrown when the JSON is malformed.</exception>
    public MatrixConfig Parse(string json)
    {
        var dto = JsonSerializer.Deserialize<ConfigDto>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new JsonException("Input JSON deserialised to null.");

        var config = new MatrixConfig
        {
            Dimensions = dto.Dimensions ?? new Dictionary<string, List<string>>(),
            Include = dto.Include ?? new List<Dictionary<string, string>>(),
            Exclude = dto.Exclude ?? new List<Dictionary<string, string>>()
        };

        if (dto.MaxParallel.HasValue)
            config.MaxParallel = dto.MaxParallel.Value;

        if (dto.FailFast.HasValue)
            config.FailFast = dto.FailFast.Value;

        if (dto.MaxMatrixSize.HasValue)
            config.MaxMatrixSize = dto.MaxMatrixSize.Value;

        return config;
    }
}
