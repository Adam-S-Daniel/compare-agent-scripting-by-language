// YamlOutputConverter.cs
// GREEN phase: converts an IniDocument to YAML using YamlDotNet.
//
// Mapping rules (same as JSON converter):
//   • Global section keys → top-level YAML mapping
//   • Each [section] → nested mapping at the section name
//   • Values are auto-coerced unless a schema is provided.
//   • Array type → YAML sequence

using YamlDotNet.Serialization;

namespace ConfigMigratorLib;

/// <summary>
/// Converts an <see cref="IniDocument"/> to a YAML string via YamlDotNet.
/// </summary>
public class YamlOutputConverter(bool autoCoerce = true)
{
    // Plain serializer — no naming-convention transformation so INI key names
    // are preserved verbatim in YAML output.
    private static readonly ISerializer Serializer =
        new SerializerBuilder().Build();

    /// <summary>
    /// Converts the document to a YAML string.
    /// </summary>
    /// <param name="document">Parsed INI document.</param>
    /// <param name="schema">Optional schema for type-driven coercion.</param>
    public string Convert(IniDocument document, IniSchema? schema = null)
    {
        var root = new Dictionary<string, object>();

        // Global keys → root level
        foreach (var (key, value) in document.GlobalSection.RawValues)
            root[key] = ToValue(key, value, schema?.GlobalSchema);

        // Named sections → nested dictionaries
        foreach (var (sectionName, section) in document.Sections)
        {
            var sectionSchema = schema?.Sections.GetValueOrDefault(sectionName);
            var sectionDict = new Dictionary<string, object>();

            foreach (var (key, value) in section.RawValues)
                sectionDict[key] = ToValue(key, value, sectionSchema);

            root[sectionName] = sectionDict;
        }

        return Serializer.Serialize(root);
    }

    // -------------------------------------------------------------------------
    private object ToValue(string key, string rawValue, SectionSchema? schema)
    {
        if (schema?.Keys.TryGetValue(key, out var keySchema) == true)
            return TypeCoercer.Coerce(rawValue, keySchema.Type);

        return autoCoerce ? TypeCoercer.AutoCoerce(rawValue) : rawValue;
    }
}
