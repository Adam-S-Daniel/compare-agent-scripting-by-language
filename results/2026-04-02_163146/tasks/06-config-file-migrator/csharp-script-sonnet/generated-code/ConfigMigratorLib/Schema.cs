// Schema.cs
// Defines the schema structures used to validate an IniDocument.
// A schema describes which sections and keys are required, and what
// types their values must be coercible to.

namespace ConfigMigratorLib;

/// <summary>Supported value types for schema-driven validation and coercion.</summary>
public enum IniValueType
{
    String,
    Integer,
    Float,
    Boolean,
    /// <summary>Comma-separated list of string values.</summary>
    Array
}

/// <summary>Schema definition for a single key inside a section.</summary>
public class KeySchema
{
    public required string Name { get; init; }
    public bool Required { get; init; } = false;
    public IniValueType Type { get; init; } = IniValueType.String;
    public object? DefaultValue { get; init; } = null;
    public string? Description { get; init; } = null;
}

/// <summary>Schema definition for one INI section.</summary>
public class SectionSchema
{
    public required string Name { get; init; }
    public bool Required { get; init; } = false;
    public Dictionary<string, KeySchema> Keys { get; init; } = new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>
/// Top-level schema for an entire INI document.
/// <see cref="GlobalSchema"/> applies to keys that appear before any section header.
/// </summary>
public class IniSchema
{
    public SectionSchema? GlobalSchema { get; init; } = null;
    public Dictionary<string, SectionSchema> Sections { get; init; } = new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>Aggregated result of schema validation.</summary>
public class ValidationResult
{
    public bool IsValid => Errors.Count == 0;
    public List<string> Errors { get; } = [];
    public List<string> Warnings { get; } = [];
}
