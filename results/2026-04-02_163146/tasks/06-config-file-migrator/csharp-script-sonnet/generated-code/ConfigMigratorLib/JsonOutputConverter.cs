// JsonOutputConverter.cs
// GREEN phase: converts an IniDocument to indented JSON.
//
// Mapping rules:
//   • Global section keys → top-level JSON object properties
//   • Each [section] → nested JSON object at the same name
//   • Values are auto-coerced (String→Boolean/Integer/Double heuristic) unless
//     an IniSchema is supplied, in which case schema types take priority.
//   • Array type → JSON array of strings

using System.Text.Json;
using System.Text.Json.Nodes;

namespace ConfigMigratorLib;

/// <summary>
/// Converts an <see cref="IniDocument"/> to a JSON string.
/// </summary>
public class JsonOutputConverter(bool autoCoerce = true)
{
    private static readonly JsonSerializerOptions PrettyPrint = new() { WriteIndented = true };

    /// <summary>
    /// Converts the document to a pretty-printed JSON string.
    /// </summary>
    /// <param name="document">Parsed INI document.</param>
    /// <param name="schema">Optional schema for type-driven coercion.</param>
    public string Convert(IniDocument document, IniSchema? schema = null)
    {
        var root = new JsonObject();

        // Global keys → root level
        foreach (var (key, value) in document.GlobalSection.RawValues)
            root[key] = ToJsonNode(key, value, schema?.GlobalSchema);

        // Named sections → nested objects
        foreach (var (sectionName, section) in document.Sections)
        {
            var sectionSchema = schema?.Sections.GetValueOrDefault(sectionName);
            var sectionObj = new JsonObject();

            foreach (var (key, value) in section.RawValues)
                sectionObj[key] = ToJsonNode(key, value, sectionSchema);

            root[sectionName] = sectionObj;
        }

        return root.ToJsonString(PrettyPrint);
    }

    // -------------------------------------------------------------------------
    private JsonNode? ToJsonNode(string key, string rawValue, SectionSchema? schema)
    {
        // Schema-driven coercion takes priority
        if (schema?.Keys.TryGetValue(key, out var keySchema) == true)
        {
            var coerced = TypeCoercer.Coerce(rawValue, keySchema.Type);
            return coerced switch
            {
                bool b     => JsonValue.Create(b),
                int i      => JsonValue.Create(i),
                double d   => JsonValue.Create(d),
                string[] a => new JsonArray(a.Select(v => (JsonNode?)JsonValue.Create(v)).ToArray()),
                _          => JsonValue.Create(rawValue)
            };
        }

        // Auto-coercion heuristic when no schema
        if (autoCoerce)
        {
            var auto = TypeCoercer.AutoCoerce(rawValue);
            return auto switch
            {
                bool b   => JsonValue.Create(b),
                int i    => JsonValue.Create(i),
                double d => JsonValue.Create(d),
                _        => JsonValue.Create(rawValue)
            };
        }

        return JsonValue.Create(rawValue);
    }
}
