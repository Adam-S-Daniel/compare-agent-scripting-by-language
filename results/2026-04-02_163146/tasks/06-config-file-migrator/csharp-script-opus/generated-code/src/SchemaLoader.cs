using System.Text.Json;

namespace ConfigMigrator;

/// <summary>
/// Loads schema definitions from JSON files.
/// Schema format: { "rules": [ { "section": "", "key": "name", "type": "string", "required": true } ] }
/// </summary>
public static class SchemaLoader
{
    public static Schema LoadFromJson(string json)
    {
        var schema = new Schema();
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        if (root.TryGetProperty("rules", out var rulesArray))
        {
            foreach (var ruleElement in rulesArray.EnumerateArray())
            {
                var rule = new SchemaRule
                {
                    Section = ruleElement.GetProperty("section").GetString() ?? "",
                    Key = ruleElement.GetProperty("key").GetString() ?? "",
                    ValueType = ParseValueType(ruleElement.GetProperty("type").GetString() ?? "string"),
                    Required = ruleElement.TryGetProperty("required", out var req) && req.GetBoolean()
                };
                schema.Rules.Add(rule);
            }
        }

        return schema;
    }

    public static Schema LoadFromFile(string path)
    {
        var json = File.ReadAllText(path);
        return LoadFromJson(json);
    }

    private static SchemaValueType ParseValueType(string type)
    {
        return type.ToLowerInvariant() switch
        {
            "string" => SchemaValueType.String,
            "integer" or "int" => SchemaValueType.Integer,
            "float" or "double" or "number" => SchemaValueType.Float,
            "boolean" or "bool" => SchemaValueType.Boolean,
            _ => SchemaValueType.String
        };
    }
}
