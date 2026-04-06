using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// Tests for YAML output generation from INI documents.
/// </summary>
public class YamlOutputTests
{
    [Fact]
    public void ToYaml_SimpleKeyValue_ProducesYaml()
    {
        var doc = IniParser.Parse("name=MyApp");
        var yaml = ConfigConverter.ToYaml(doc);
        Assert.Contains("name: MyApp", yaml);
    }

    [Fact]
    public void ToYaml_SectionedKeys_ProducesIndentedBlock()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost\nport=5432");
        var yaml = ConfigConverter.ToYaml(doc);

        Assert.Contains("database:", yaml);
        Assert.Contains("  host: localhost", yaml);
        Assert.Contains("  port: 5432", yaml);
    }

    [Fact]
    public void ToYaml_BooleanValues_AreCoerced()
    {
        var doc = IniParser.Parse("[features]\nenabled=true");
        var yaml = ConfigConverter.ToYaml(doc);
        Assert.Contains("  enabled: true", yaml);
    }

    [Fact]
    public void ToYaml_IntegerValues_AreCoerced()
    {
        var doc = IniParser.Parse("[server]\nport=8080");
        var yaml = ConfigConverter.ToYaml(doc);
        Assert.Contains("  port: 8080", yaml);
    }

    [Fact]
    public void ToYaml_EmptyValue_ProducesQuotedEmpty()
    {
        var doc = IniParser.Parse("empty=");
        var yaml = ConfigConverter.ToYaml(doc);
        Assert.Contains("empty: \"\"", yaml);
    }

    [Fact]
    public void ToYaml_MultiLineValue_UsesLiteralBlockScalar()
    {
        var doc = IniParser.Parse("[section]\ndesc=Line one\n  Line two\n  Line three");
        var yaml = ConfigConverter.ToYaml(doc);

        // Should contain the pipe character for literal block scalar
        Assert.Contains("|", yaml);
        Assert.Contains("Line one", yaml);
        Assert.Contains("Line two", yaml);
    }

    [Fact]
    public void ToYaml_SpecialCharacters_AreQuoted()
    {
        // Values containing colons, hash marks etc. should be quoted
        var doc = IniParser.Parse("[db]\nconnection=host:localhost");
        var yaml = ConfigConverter.ToYaml(doc);

        // The value should be quoted because it contains a colon
        Assert.Contains("\"host:localhost\"", yaml);
    }

    [Fact]
    public void ToYaml_GlobalAndSectionedKeys_BothPresent()
    {
        var doc = IniParser.Parse("app=MyApp\n[section]\nkey=value");
        var yaml = ConfigConverter.ToYaml(doc);

        Assert.Contains("app: MyApp", yaml);
        Assert.Contains("section:", yaml);
        Assert.Contains("  key: value", yaml);
    }

    [Fact]
    public void ToYaml_MultipleSections_AllPresent()
    {
        var doc = IniParser.Parse("[db]\nhost=localhost\n[server]\nport=8080");
        var yaml = ConfigConverter.ToYaml(doc);

        Assert.Contains("db:", yaml);
        Assert.Contains("  host: localhost", yaml);
        Assert.Contains("server:", yaml);
        Assert.Contains("  port: 8080", yaml);
    }
}
