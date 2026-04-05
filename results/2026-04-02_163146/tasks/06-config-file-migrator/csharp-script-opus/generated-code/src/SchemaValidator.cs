namespace ConfigMigrator;

/// <summary>
/// Defines expected type for a configuration key.
/// </summary>
public enum SchemaValueType
{
    String,
    Integer,
    Float,
    Boolean
}

/// <summary>
/// Defines a schema rule for a single configuration key.
/// </summary>
public class SchemaRule
{
    public string Section { get; set; } = "";
    public string Key { get; set; } = "";
    public SchemaValueType ValueType { get; set; } = SchemaValueType.String;
    public bool Required { get; set; } = false;

    public SchemaRule() { }

    public SchemaRule(string section, string key, SchemaValueType valueType, bool required)
    {
        Section = section;
        Key = key;
        ValueType = valueType;
        Required = required;
    }
}

/// <summary>
/// Schema definition containing rules for validating an INI document.
/// </summary>
public class Schema
{
    public List<SchemaRule> Rules { get; set; } = new();
}

/// <summary>
/// Result of a schema validation pass.
/// </summary>
public class ValidationResult
{
    public bool IsValid => Errors.Count == 0;
    public List<string> Errors { get; } = new();
}

/// <summary>
/// Validates an IniDocument against a Schema.
/// Checks required keys and value types.
/// </summary>
public static class SchemaValidator
{
    public static ValidationResult Validate(IniDocument doc, Schema schema)
    {
        var result = new ValidationResult();

        foreach (var rule in schema.Rules)
        {
            var sectionExists = doc.Sections.ContainsKey(rule.Section);
            var keyExists = sectionExists && doc.Sections[rule.Section].ContainsKey(rule.Key);

            // Check required keys
            if (rule.Required && !keyExists)
            {
                var sectionLabel = string.IsNullOrEmpty(rule.Section) ? "global" : $"[{rule.Section}]";
                result.Errors.Add($"Missing required key '{rule.Key}' in section {sectionLabel}");
                continue;
            }

            // If key exists, validate its type
            if (keyExists)
            {
                var value = doc.Sections[rule.Section][rule.Key];
                if (!IsValidType(value, rule.ValueType))
                {
                    var sectionLabel = string.IsNullOrEmpty(rule.Section) ? "global" : $"[{rule.Section}]";
                    result.Errors.Add(
                        $"Key '{rule.Key}' in section {sectionLabel} has invalid type: " +
                        $"expected {rule.ValueType}, got value '{value}'");
                }
            }
        }

        return result;
    }

    /// <summary>
    /// Checks whether a string value can be interpreted as the given type.
    /// </summary>
    private static bool IsValidType(string value, SchemaValueType type)
    {
        return type switch
        {
            SchemaValueType.String => true, // everything is a valid string
            SchemaValueType.Integer => int.TryParse(value, out _) || long.TryParse(value, out _),
            SchemaValueType.Float => double.TryParse(value,
                System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture, out _),
            SchemaValueType.Boolean => IsBooleanString(value),
            _ => false
        };
    }

    /// <summary>
    /// Recognizes common boolean string representations.
    /// </summary>
    private static bool IsBooleanString(string value)
    {
        var lower = value.ToLowerInvariant();
        return lower is "true" or "false" or "yes" or "no" or "1" or "0"
            or "on" or "off";
    }
}
