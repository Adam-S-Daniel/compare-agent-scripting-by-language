using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace ConfigMigrator;

/// <summary>
/// Converts an IniDocument to JSON and YAML string representations.
/// Applies type coercion to produce typed output (numbers, booleans) rather than all-strings.
/// </summary>
public static class ConfigConverter
{
    /// <summary>
    /// Converts an IniDocument to a JSON string.
    /// Global (unnamed) section keys are placed at the root level.
    /// Named sections become nested objects.
    /// </summary>
    public static string ToJson(IniDocument doc, Schema? schema = null)
    {
        var root = new JsonObject();

        foreach (var (sectionName, keys) in doc.Sections)
        {
            if (string.IsNullOrEmpty(sectionName))
            {
                // Global keys go at root level
                foreach (var (key, value) in keys)
                {
                    root[key] = CoerceToJsonNode(sectionName, key, value, schema);
                }
            }
            else
            {
                // Named section becomes a nested object
                var sectionObj = new JsonObject();
                foreach (var (key, value) in keys)
                {
                    sectionObj[key] = CoerceToJsonNode(sectionName, key, value, schema);
                }
                root[sectionName] = sectionObj;
            }
        }

        var options = new JsonSerializerOptions
        {
            WriteIndented = true
        };
        return root.ToJsonString(options);
    }

    /// <summary>
    /// Converts an IniDocument to a YAML string.
    /// Global keys are at the top level; named sections are indented blocks.
    /// </summary>
    public static string ToYaml(IniDocument doc, Schema? schema = null)
    {
        var sb = new StringBuilder();

        // Write global keys first
        if (doc.Sections.TryGetValue("", out var globalSection))
        {
            foreach (var (key, value) in globalSection)
            {
                var coerced = CoerceValue(key, "", value, schema);
                sb.AppendLine($"{key}: {FormatYamlValue(coerced)}");
            }
        }

        // Write named sections
        foreach (var (sectionName, keys) in doc.Sections)
        {
            if (string.IsNullOrEmpty(sectionName))
                continue;

            // Add blank line before section if we already have content
            if (sb.Length > 0)
                sb.AppendLine();

            sb.AppendLine($"{sectionName}:");
            foreach (var (key, value) in keys)
            {
                var coerced = CoerceValue(key, sectionName, value, schema);
                sb.AppendLine($"  {key}: {FormatYamlValue(coerced)}");
            }
        }

        return sb.ToString().TrimEnd('\n', '\r') + "\n";
    }

    /// <summary>
    /// Coerces a value using schema type hints if available, otherwise auto-coerces.
    /// </summary>
    private static object CoerceValue(string key, string section, string value, Schema? schema)
    {
        if (schema != null)
        {
            var rule = schema.Rules.Find(r => r.Key == key && r.Section == section);
            if (rule != null)
                return TypeCoercer.CoerceWithType(value, rule.ValueType);
        }
        return TypeCoercer.Coerce(value);
    }

    /// <summary>
    /// Creates a JsonNode with proper typing from a coerced value.
    /// </summary>
    private static JsonNode? CoerceToJsonNode(string section, string key, string value, Schema? schema)
    {
        var coerced = CoerceValue(key, section, value, schema);
        return coerced switch
        {
            bool b => JsonValue.Create(b),
            int i => JsonValue.Create(i),
            long l => JsonValue.Create(l),
            double d => JsonValue.Create(d),
            string s => JsonValue.Create(s),
            _ => JsonValue.Create(value)
        };
    }

    /// <summary>
    /// Formats a value for YAML output.
    /// Strings that could be misinterpreted are quoted.
    /// Multi-line strings use YAML literal block scalar.
    /// </summary>
    private static string FormatYamlValue(object value)
    {
        return value switch
        {
            bool b => b ? "true" : "false",
            int i => i.ToString(),
            long l => l.ToString(),
            double d => d.ToString(System.Globalization.CultureInfo.InvariantCulture),
            string s => FormatYamlString(s),
            _ => $"\"{value}\""
        };
    }

    /// <summary>
    /// Formats a string for YAML, handling multi-line and special characters.
    /// </summary>
    private static string FormatYamlString(string s)
    {
        // Multi-line strings use literal block scalar
        if (s.Contains('\n'))
        {
            var lines = s.Split('\n');
            var sb = new StringBuilder("|\n");
            foreach (var line in lines)
            {
                sb.AppendLine($"    {line}");
            }
            return sb.ToString().TrimEnd('\n', '\r');
        }

        // Empty string
        if (string.IsNullOrEmpty(s))
            return "\"\"";

        // Strings that need quoting: contain special YAML chars, look like other types,
        // or start/end with whitespace
        if (NeedsQuoting(s))
            return $"\"{EscapeYamlString(s)}\"";

        return s;
    }

    /// <summary>
    /// Determines if a YAML string value needs quoting.
    /// </summary>
    private static bool NeedsQuoting(string s)
    {
        // Empty or whitespace
        if (string.IsNullOrWhiteSpace(s))
            return true;

        // Starts or ends with whitespace
        if (s != s.Trim())
            return true;

        // Contains characters that need quoting in YAML
        if (s.Contains(':') || s.Contains('#') || s.Contains('{') || s.Contains('}')
            || s.Contains('[') || s.Contains(']') || s.Contains(',') || s.Contains('&')
            || s.Contains('*') || s.Contains('?') || s.Contains('|') || s.Contains('>')
            || s.Contains('!') || s.Contains('%') || s.Contains('@') || s.Contains('`')
            || s.Contains('"') || s.Contains('\''))
            return true;

        // Could be misinterpreted as boolean or null
        var lower = s.ToLowerInvariant();
        if (lower is "true" or "false" or "yes" or "no" or "on" or "off"
            or "null" or "~")
            return true;

        return false;
    }

    /// <summary>
    /// Escapes special characters in a YAML double-quoted string.
    /// </summary>
    private static string EscapeYamlString(string s)
    {
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
