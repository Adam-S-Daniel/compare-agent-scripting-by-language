// IniParser.cs
// GREEN phase: minimum implementation to pass all IniParserTests.
//
// INI format rules handled here:
//   • Lines starting with ; or # (after optional whitespace) are comments — skipped.
//   • [SectionName] lines start a new section.
//   • key = value lines belong to the current section (or GlobalSection if none yet).
//   • Values are split on the FIRST '=' only, so values containing '=' are preserved.
//   • Leading/trailing whitespace around both key and value is trimmed.
//   • A value ending with a single backslash \ is continued on the next line
//     (the backslash and leading whitespace of the continuation are removed).
//   • Both LF and CRLF line endings are supported.

namespace ConfigMigratorLib;

/// <summary>
/// Parses text content in INI format into an <see cref="IniDocument"/>.
/// </summary>
public class IniParser
{
    /// <summary>Parses INI content from a string.</summary>
    public IniDocument Parse(string content)
    {
        var doc = new IniDocument();
        var currentSection = doc.GlobalSection;

        // Normalize CRLF → LF before splitting
        var lines = content.Replace("\r\n", "\n").Split('\n');

        for (int i = 0; i < lines.Length; i++)
        {
            var line = lines[i];
            var trimmed = line.Trim();

            // Skip blank lines and comment lines
            if (trimmed.Length == 0 || trimmed[0] == ';' || trimmed[0] == '#')
                continue;

            // Section header: [name]
            if (trimmed.StartsWith('[') && trimmed.EndsWith(']'))
            {
                var sectionName = trimmed[1..^1].Trim();
                if (!doc.Sections.ContainsKey(sectionName))
                    doc.Sections[sectionName] = new IniSection(sectionName);
                currentSection = doc.Sections[sectionName];
                continue;
            }

            // Key=Value: split on FIRST '=' only
            var eqIndex = line.IndexOf('=');
            if (eqIndex < 0)
                continue; // Ignore malformed lines

            var key = line[..eqIndex].Trim();
            var value = line[(eqIndex + 1)..].Trim();

            // Multi-line continuation: value ends with exactly one backslash
            while (value.EndsWith('\\') && i + 1 < lines.Length)
            {
                value = value[..^1]; // Remove trailing backslash
                i++;
                value += lines[i].Trim();
            }

            if (key.Length > 0)
                currentSection.RawValues[key] = value;
        }

        return doc;
    }

    /// <summary>Parses an INI file from disk.</summary>
    /// <exception cref="FileNotFoundException">When the file does not exist.</exception>
    public IniDocument ParseFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException(
                $"Configuration file not found: '{filePath}'", filePath);

        return Parse(File.ReadAllText(filePath));
    }
}
