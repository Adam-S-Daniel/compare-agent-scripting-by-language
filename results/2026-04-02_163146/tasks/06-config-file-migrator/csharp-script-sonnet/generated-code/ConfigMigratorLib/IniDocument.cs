// IniDocument.cs
// Domain model for a parsed INI document.
// An INI document has a global (no-section) area plus named sections,
// each of which holds a dictionary of raw string key/value pairs.

namespace ConfigMigratorLib;

/// <summary>
/// Represents a fully parsed INI configuration document.
/// Keys are case-insensitive within each section (matches common INI convention).
/// </summary>
public class IniDocument
{
    /// <summary>Keys that appear before any [section] header.</summary>
    public IniSection GlobalSection { get; } = new IniSection(string.Empty);

    /// <summary>Named sections, keyed by section name (case-insensitive).</summary>
    public Dictionary<string, IniSection> Sections { get; } =
        new(StringComparer.OrdinalIgnoreCase);

    public bool HasSection(string name) => Sections.ContainsKey(name);

    public IniSection? GetSection(string name) =>
        Sections.TryGetValue(name, out var s) ? s : null;
}

/// <summary>
/// One [section] inside an INI document.
/// Raw values are always stored as strings; type coercion happens at conversion time.
/// </summary>
public class IniSection(string name)
{
    public string Name { get; } = name;

    /// <summary>Raw string values, case-insensitive on key name.</summary>
    public Dictionary<string, string> RawValues { get; } =
        new(StringComparer.OrdinalIgnoreCase);

    public bool HasKey(string key) => RawValues.ContainsKey(key);

    public string? GetValue(string key) =>
        RawValues.TryGetValue(key, out var v) ? v : null;
}
