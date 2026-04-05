// YamlOutputTests.cs
// TDD RED/GREEN cycle for YAML output conversion.

using ConfigMigratorLib;
using Xunit;

namespace ConfigMigrator.Tests;

public class YamlOutputTests
{
    private readonly IniParser _parser = new();
    private readonly YamlOutputConverter _converter = new();

    // RED 31 — Basic section is serialized to a YAML mapping
    [Fact]
    public void Convert_BasicSection_ProducesYamlMapping()
    {
        var doc = _parser.Parse("[server]\nhost=localhost");

        var yaml = _converter.Convert(doc);

        Assert.Contains("server:", yaml);
        Assert.Contains("host:", yaml);
        Assert.Contains("localhost", yaml);
    }

    // RED 32 — Auto-coercion: integer stays as YAML integer (no quotes)
    [Fact]
    public void Convert_IntegerValue_ProducesUnquotedNumber()
    {
        var doc = _parser.Parse("[server]\nport=8080");

        var yaml = _converter.Convert(doc);

        // YAML integer should appear without quotes
        Assert.Contains("port: 8080", yaml);
    }

    // RED 33 — Auto-coercion: boolean becomes YAML boolean
    [Fact]
    public void Convert_BooleanValue_ProducesYamlBool()
    {
        var doc = _parser.Parse("[server]\ndebug=true");

        var yaml = _converter.Convert(doc);

        Assert.Contains("debug: true", yaml);
    }

    // RED 34 — Global keys appear at YAML root level
    [Fact]
    public void Convert_GlobalKeys_AppearAtRoot()
    {
        var doc = _parser.Parse("app_name=MyApp\n[server]\nhost=localhost");

        var yaml = _converter.Convert(doc);

        // Global key should be at root level (not indented under a section)
        Assert.Matches(@"(?m)^app_name: MyApp", yaml);
    }

    // RED 35 — Schema-driven array produces YAML sequence
    [Fact]
    public void Convert_ArrayWithSchema_ProducesYamlSequence()
    {
        var doc = _parser.Parse("[server]\nhosts=a,b,c");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Keys = new()
                    {
                        ["hosts"] = new KeySchema { Name = "hosts", Type = IniValueType.Array }
                    }
                }
            }
        };

        var yaml = _converter.Convert(doc, schema);

        // YAML sequence indicator
        Assert.Contains("- a", yaml);
        Assert.Contains("- b", yaml);
        Assert.Contains("- c", yaml);
    }

    // RED 36 — Multiple sections produce nested YAML mappings
    [Fact]
    public void Convert_MultipleSections_ProduceNestedMappings()
    {
        var doc = _parser.Parse("[server]\nhost=localhost\n[database]\nname=mydb");

        var yaml = _converter.Convert(doc);

        Assert.Contains("server:", yaml);
        Assert.Contains("database:", yaml);
    }

    // RED 37 — YAML output ends with a newline
    [Fact]
    public void Convert_Output_EndsWithNewline()
    {
        var doc = _parser.Parse("[section]\nkey=value");

        var yaml = _converter.Convert(doc);

        Assert.EndsWith("\n", yaml);
    }
}
