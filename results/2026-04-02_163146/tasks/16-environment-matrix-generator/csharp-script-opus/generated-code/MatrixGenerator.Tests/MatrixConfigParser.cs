using System.Text.Json;

/// <summary>
/// Parses JSON configuration input into a MatrixConfig object.
/// Handles the GitHub Actions strategy format with kebab-case property names
/// and mixed value types (strings, numbers, booleans in matrix arrays).
/// </summary>
public static class MatrixConfigParser
{
    /// <summary>
    /// Parse a JSON string into a MatrixConfig.
    /// Supports kebab-case property names and mixed value types in arrays.
    /// </summary>
    public static MatrixConfig Parse(string json)
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

        // Parse the matrix dimensions (required)
        if (!root.TryGetProperty("matrix", out var matrixElement))
            throw new ArgumentException("Configuration must contain a 'matrix' property with dimension definitions.");

        var config = new MatrixConfig
        {
            Matrix = ParseMatrixDimensions(matrixElement),
            Include = ParseRuleList(root, "include"),
            Exclude = ParseRuleList(root, "exclude"),
            FailFast = GetBoolProperty(root, "fail-fast", true),
            MaxParallel = GetNullableIntProperty(root, "max-parallel"),
            MaxMatrixSize = GetIntProperty(root, "max-matrix-size", 256)
        };

        return config;
    }

    /// <summary>
    /// Parse matrix dimensions: { "os": ["ubuntu", "windows"], "node": [18, 20] }
    /// Values can be strings, numbers, or booleans — all converted to strings.
    /// </summary>
    private static Dictionary<string, List<string>> ParseMatrixDimensions(JsonElement matrixElement)
    {
        var dimensions = new Dictionary<string, List<string>>();

        foreach (var prop in matrixElement.EnumerateObject())
        {
            if (prop.Value.ValueKind != JsonValueKind.Array)
                continue; // Skip non-array properties (like nested include/exclude)

            var values = new List<string>();
            foreach (var item in prop.Value.EnumerateArray())
            {
                values.Add(JsonValueToString(item));
            }
            dimensions[prop.Name] = values;
        }

        return dimensions;
    }

    /// <summary>
    /// Parse include or exclude rule lists from the config.
    /// </summary>
    private static List<Dictionary<string, string>> ParseRuleList(JsonElement root, string propertyName)
    {
        var rules = new List<Dictionary<string, string>>();

        if (!root.TryGetProperty(propertyName, out var arrayElement))
            return rules;

        if (arrayElement.ValueKind != JsonValueKind.Array)
            return rules;

        foreach (var item in arrayElement.EnumerateArray())
        {
            var rule = new Dictionary<string, string>();
            foreach (var prop in item.EnumerateObject())
            {
                rule[prop.Name] = JsonValueToString(prop.Value);
            }
            rules.Add(rule);
        }

        return rules;
    }

    /// <summary>
    /// Convert any JSON value to its string representation.
    /// Numbers, booleans, and strings are all converted to lowercase strings.
    /// </summary>
    private static string JsonValueToString(JsonElement element)
    {
        return element.ValueKind switch
        {
            JsonValueKind.String => element.GetString() ?? "",
            JsonValueKind.Number => element.GetRawText(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            _ => element.GetRawText()
        };
    }

    private static bool GetBoolProperty(JsonElement root, string name, bool defaultValue)
    {
        if (root.TryGetProperty(name, out var prop) && prop.ValueKind == JsonValueKind.True)
            return true;
        if (root.TryGetProperty(name, out prop) && prop.ValueKind == JsonValueKind.False)
            return false;
        return defaultValue;
    }

    private static int? GetNullableIntProperty(JsonElement root, string name)
    {
        if (root.TryGetProperty(name, out var prop) && prop.ValueKind == JsonValueKind.Number)
            return prop.GetInt32();
        return null;
    }

    private static int GetIntProperty(JsonElement root, string name, int defaultValue)
    {
        if (root.TryGetProperty(name, out var prop) && prop.ValueKind == JsonValueKind.Number)
            return prop.GetInt32();
        return defaultValue;
    }
}
