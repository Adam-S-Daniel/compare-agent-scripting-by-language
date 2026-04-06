namespace ConfigMigrator;

/// <summary>
/// Represents a parsed INI configuration file with sections and key-value pairs.
/// </summary>
public class IniDocument
{
    /// <summary>
    /// Sections mapped by name. The global (unnamed) section uses an empty string key.
    /// </summary>
    public Dictionary<string, Dictionary<string, string>> Sections { get; } = new();

    /// <summary>
    /// Gets or creates a section by name.
    /// </summary>
    public Dictionary<string, string> GetOrCreateSection(string name)
    {
        if (!Sections.ContainsKey(name))
            Sections[name] = new Dictionary<string, string>();
        return Sections[name];
    }
}

/// <summary>
/// Parses INI format configuration files.
/// Supports: sections, comments (# and ;), multi-line values (continuation lines),
/// quoted values, empty values, and values containing equals signs.
/// </summary>
public static class IniParser
{
    public static IniDocument Parse(string content)
    {
        var doc = new IniDocument();
        var currentSection = ""; // global section
        string? lastKey = null;

        // Normalize line endings: handle \r\n (Windows) and \r (old Mac)
        var normalizedContent = content.Replace("\r\n", "\n").Replace("\r", "\n");
        var lines = normalizedContent.Split('\n');

        for (int i = 0; i < lines.Length; i++)
        {
            var rawLine = lines[i];

            // Multi-line continuation: line starts with whitespace and we have a previous key
            if (lastKey != null && rawLine.Length > 0 && (rawLine[0] == ' ' || rawLine[0] == '\t'))
            {
                var continuation = rawLine.Trim();
                if (continuation.Length > 0)
                {
                    var section = doc.GetOrCreateSection(currentSection);
                    section[lastKey] = section[lastKey] + "\n" + continuation;
                }
                continue;
            }

            var line = rawLine.Trim();

            // Skip empty lines
            if (string.IsNullOrEmpty(line))
            {
                lastKey = null; // reset continuation context on blank line
                continue;
            }

            // Skip comments (lines starting with ; or #)
            if (line[0] == ';' || line[0] == '#')
                continue;

            // Section header: [section_name]
            if (line[0] == '[' && line.Contains(']'))
            {
                var closeBracket = line.IndexOf(']');
                currentSection = line.Substring(1, closeBracket - 1).Trim();
                lastKey = null;
                continue;
            }

            // Key-value pair: key = value (split on first '=' only)
            var equalsIndex = line.IndexOf('=');
            if (equalsIndex > 0)
            {
                var key = line.Substring(0, equalsIndex).Trim();
                var value = line.Substring(equalsIndex + 1).Trim();

                // Remove surrounding quotes from value
                value = Unquote(value);

                var section = doc.GetOrCreateSection(currentSection);
                section[key] = value;
                lastKey = key;
            }
            else if (equalsIndex == 0)
            {
                // Line starts with '=' — skip as invalid
                lastKey = null;
            }
            else
            {
                // Line with no '=' — treat as key with empty value or skip
                lastKey = null;
            }
        }

        return doc;
    }

    /// <summary>
    /// Removes matching surrounding single or double quotes from a value.
    /// </summary>
    private static string Unquote(string value)
    {
        if (value.Length >= 2)
        {
            if ((value[0] == '"' && value[^1] == '"') ||
                (value[0] == '\'' && value[^1] == '\''))
            {
                return value[1..^1];
            }
        }
        return value;
    }
}
