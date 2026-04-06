using System.Text.Json;

/// <summary>
/// Generates GitHub Actions strategy.matrix configurations from a MatrixConfig.
/// Supports Cartesian product generation, include/exclude rules, and validation.
/// </summary>
public static class MatrixGenerator
{
    /// <summary>
    /// Generate the full matrix from configuration, applying all rules.
    /// </summary>
    public static MatrixResult Generate(MatrixConfig config)
    {
        if (config == null)
            throw new ArgumentNullException(nameof(config), "Matrix configuration cannot be null.");

        // Step 1: Generate the Cartesian product of all dimensions
        var combinations = GenerateCartesianProduct(config.Matrix);

        // Step 2: Apply exclude rules - remove matching combinations
        combinations = ApplyExclusions(combinations, config.Exclude);

        // Step 3: Apply include rules - add extra combinations
        combinations = ApplyInclusions(combinations, config.Include);

        // Step 4: Validate matrix size
        ValidateMatrixSize(combinations.Count, config.MaxMatrixSize);

        return new MatrixResult
        {
            Combinations = combinations,
            MaxParallel = config.MaxParallel,
            FailFast = config.FailFast
        };
    }

    /// <summary>
    /// Generates the Cartesian product of all matrix dimensions.
    /// For example, {os: [a,b], node: [1,2]} produces [{os:a,node:1},{os:a,node:2},{os:b,node:1},{os:b,node:2}]
    /// </summary>
    private static List<Dictionary<string, string>> GenerateCartesianProduct(
        Dictionary<string, List<string>> matrix)
    {
        if (matrix.Count == 0)
            return new List<Dictionary<string, string>>();

        // Start with a single empty combination
        var result = new List<Dictionary<string, string>> { new() };

        // For each dimension, expand all current combos with each value in that dimension
        foreach (var (key, values) in matrix)
        {
            if (values == null || values.Count == 0)
                throw new ArgumentException($"Matrix dimension '{key}' has no values.");

            var expanded = new List<Dictionary<string, string>>();
            foreach (var combo in result)
            {
                foreach (var value in values)
                {
                    var newCombo = new Dictionary<string, string>(combo)
                    {
                        [key] = value
                    };
                    expanded.Add(newCombo);
                }
            }
            result = expanded;
        }

        return result;
    }

    /// <summary>
    /// Remove combinations that match any exclusion rule.
    /// A combination matches an exclude rule if ALL specified dimensions match.
    /// </summary>
    private static List<Dictionary<string, string>> ApplyExclusions(
        List<Dictionary<string, string>> combinations,
        List<Dictionary<string, string>> excludeRules)
    {
        if (excludeRules == null || excludeRules.Count == 0)
            return combinations;

        return combinations
            .Where(combo => !excludeRules.Any(rule => MatchesRule(combo, rule)))
            .ToList();
    }

    /// <summary>
    /// Add include combinations. If an include matches an existing combination on
    /// overlapping keys (keys present in both), it merges extra keys into that combination.
    /// If it doesn't match any existing combination, it's added as a new one.
    /// This mirrors GitHub Actions include behavior.
    /// </summary>
    private static List<Dictionary<string, string>> ApplyInclusions(
        List<Dictionary<string, string>> combinations,
        List<Dictionary<string, string>> includeRules)
    {
        if (includeRules == null || includeRules.Count == 0)
            return combinations;

        var result = combinations.Select(c => new Dictionary<string, string>(c)).ToList();

        foreach (var include in includeRules)
        {
            bool merged = false;
            for (int i = 0; i < result.Count; i++)
            {
                if (IncludeMatchesCombo(result[i], include))
                {
                    // Merge all keys from the include into the existing combination
                    foreach (var (key, value) in include)
                    {
                        result[i][key] = value;
                    }
                    merged = true;
                }
            }

            // If no existing combination matched, add this as a brand new combination
            if (!merged)
            {
                result.Add(new Dictionary<string, string>(include));
            }
        }

        return result;
    }

    /// <summary>
    /// Check if an include rule matches a combination for merging purposes.
    /// A match means: all overlapping keys (present in both) have the same values,
    /// AND there is at least one overlapping key.
    /// </summary>
    private static bool IncludeMatchesCombo(Dictionary<string, string> combination, Dictionary<string, string> include)
    {
        var overlappingKeys = include.Keys.Where(k => combination.ContainsKey(k)).ToList();
        if (overlappingKeys.Count == 0)
            return false;
        return overlappingKeys.All(k => combination[k] == include[k]);
    }

    /// <summary>
    /// Check if a combination matches an exclude rule. A match means ALL keys in the rule
    /// are present in the combination with the same values.
    /// </summary>
    private static bool MatchesRule(Dictionary<string, string> combination, Dictionary<string, string> rule)
    {
        return rule.All(kv =>
            combination.TryGetValue(kv.Key, out var value) && value == kv.Value);
    }

    /// <summary>
    /// Validate that the matrix doesn't exceed the maximum allowed size.
    /// GitHub Actions limits matrices to 256 combinations.
    /// </summary>
    private static void ValidateMatrixSize(int size, int maxSize)
    {
        if (size > maxSize)
        {
            throw new InvalidOperationException(
                $"Matrix size ({size}) exceeds maximum allowed size ({maxSize}). " +
                $"GitHub Actions limits matrices to {maxSize} combinations. " +
                "Consider using exclude rules or reducing dimensions to bring the size under the limit.");
        }
    }

    /// <summary>
    /// Serialize the matrix result to GitHub Actions compatible JSON format.
    /// </summary>
    public static string ToJson(MatrixResult result)
    {
        var output = new Dictionary<string, object>
        {
            ["strategy"] = BuildStrategyObject(result)
        };

        return JsonSerializer.Serialize(output, new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.KebabCaseLower
        });
    }

    /// <summary>
    /// Build the strategy object matching GitHub Actions format.
    /// </summary>
    private static Dictionary<string, object> BuildStrategyObject(MatrixResult result)
    {
        var strategy = new Dictionary<string, object>
        {
            ["fail-fast"] = result.FailFast,
            ["matrix"] = BuildMatrixObject(result.Combinations)
        };

        if (result.MaxParallel.HasValue && result.MaxParallel.Value > 0)
        {
            strategy["max-parallel"] = result.MaxParallel.Value;
        }

        return strategy;
    }

    /// <summary>
    /// Build the matrix object: group combinations back into dimension arrays.
    /// Also outputs an "include" array with each full combination for clarity.
    /// </summary>
    private static Dictionary<string, object> BuildMatrixObject(
        List<Dictionary<string, string>> combinations)
    {
        if (combinations.Count == 0)
            return new Dictionary<string, object>();

        // Collect all unique keys and their unique values
        var dimensions = new Dictionary<string, HashSet<string>>();
        foreach (var combo in combinations)
        {
            foreach (var (key, value) in combo)
            {
                if (!dimensions.ContainsKey(key))
                    dimensions[key] = new HashSet<string>();
                dimensions[key].Add(value);
            }
        }

        var matrixObj = new Dictionary<string, object>();
        foreach (var (key, values) in dimensions)
        {
            matrixObj[key] = values.OrderBy(v => v).ToList();
        }

        // Add include array for the explicit combinations
        matrixObj["include"] = combinations;

        return matrixObj;
    }
}
