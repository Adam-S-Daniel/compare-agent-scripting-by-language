using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// Tests for various edge cases and error handling.
/// </summary>
public class EdgeCaseTests
{
    // --- Parser edge cases ---

    [Fact]
    public void Parse_EmptyInput_ReturnsEmptyDocument()
    {
        var doc = IniParser.Parse("");
        Assert.Empty(doc.Sections);
    }

    [Fact]
    public void Parse_OnlyComments_ReturnsEmptyDocument()
    {
        var ini = "; comment 1\n# comment 2\n; comment 3";
        var doc = IniParser.Parse(ini);
        Assert.Empty(doc.Sections);
    }

    [Fact]
    public void Parse_OnlyBlankLines_ReturnsEmptyDocument()
    {
        var doc = IniParser.Parse("\n\n\n");
        Assert.Empty(doc.Sections);
    }

    [Fact]
    public void Parse_DuplicateKeys_LastValueWins()
    {
        var ini = "[section]\nkey=first\nkey=second";
        var doc = IniParser.Parse(ini);
        Assert.Equal("second", doc.Sections["section"]["key"]);
    }

    [Fact]
    public void Parse_DuplicateSections_MergesKeys()
    {
        // Two [section] headers — keys should merge into one section
        var ini = "[section]\nkey1=val1\n[section]\nkey2=val2";
        var doc = IniParser.Parse(ini);
        Assert.Equal("val1", doc.Sections["section"]["key1"]);
        Assert.Equal("val2", doc.Sections["section"]["key2"]);
    }

    [Fact]
    public void Parse_SectionWithSpaces_TrimsName()
    {
        var ini = "[  my section  ]\nkey=value";
        var doc = IniParser.Parse(ini);
        Assert.True(doc.Sections.ContainsKey("my section"));
    }

    [Fact]
    public void Parse_InlineComment_NotSupported_TreatedAsValue()
    {
        // INI inline comments are ambiguous; we treat entire right side as value
        var ini = "key=value ; this is not a comment";
        var doc = IniParser.Parse(ini);
        Assert.Equal("value ; this is not a comment", doc.Sections[""]["key"]);
    }

    [Fact]
    public void Parse_WindowsLineEndings_HandledCorrectly()
    {
        var ini = "[section]\r\nkey=value\r\n";
        var doc = IniParser.Parse(ini);
        Assert.Equal("value", doc.Sections["section"]["key"]);
    }

    [Fact]
    public void Parse_ValueWithEqualsInQuotes_PreservesCorrectly()
    {
        var ini = "conn=\"host=db;port=5432\"";
        var doc = IniParser.Parse(ini);
        Assert.Equal("host=db;port=5432", doc.Sections[""]["conn"]);
    }

    // --- Schema edge cases ---

    [Fact]
    public void Validate_EmptySchema_AlwaysValid()
    {
        var doc = IniParser.Parse("[section]\nkey=value");
        var schema = new Schema();
        var result = SchemaValidator.Validate(doc, schema);
        Assert.True(result.IsValid);
    }

    [Fact]
    public void Validate_EmptyDocument_WithRequiredKeys_ReturnsErrors()
    {
        var doc = IniParser.Parse("");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "host", SchemaValueType.String, required: true)
            }
        };
        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
    }

    // --- Complex fixture test ---

    [Fact]
    public void FullPipeline_ComplexIni_ProducesValidJsonAndYaml()
    {
        var ini = @"
; Application configuration
app_name=MyTestApp
version=2

[database]
host=localhost
port=5432
ssl=true
connection_timeout=30
max_pool_size=100

[logging]
level=debug
enabled=yes
file=/var/log/app.log

[features]
dark_mode=on
beta_features=false
max_retries=3
threshold=0.85
";
        var doc = IniParser.Parse(ini);

        // Validate with schema
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("", "app_name", SchemaValueType.String, required: true),
                new SchemaRule("database", "host", SchemaValueType.String, required: true),
                new SchemaRule("database", "port", SchemaValueType.Integer, required: true),
                new SchemaRule("database", "ssl", SchemaValueType.Boolean, required: true),
                new SchemaRule("logging", "level", SchemaValueType.String, required: true),
            }
        };
        var validation = SchemaValidator.Validate(doc, schema);
        Assert.True(validation.IsValid);

        // Generate JSON — should parse without errors
        var json = ConfigConverter.ToJson(doc, schema);
        var parsed = System.Text.Json.JsonDocument.Parse(json);
        Assert.NotNull(parsed);

        // Generate YAML — should contain expected sections
        var yaml = ConfigConverter.ToYaml(doc, schema);
        Assert.Contains("database:", yaml);
        Assert.Contains("logging:", yaml);
        Assert.Contains("features:", yaml);
    }

    // --- Multi-line edge cases ---

    [Fact]
    public void Parse_MultiLineFollowedByNewKey_SeparatesCorrectly()
    {
        var ini = "[section]\ndesc=Line one\n  Line two\nnext_key=value";
        var doc = IniParser.Parse(ini);
        Assert.Equal("Line one\nLine two", doc.Sections["section"]["desc"]);
        Assert.Equal("value", doc.Sections["section"]["next_key"]);
    }

    [Fact]
    public void Parse_MultiLineFollowedByBlankLine_StopsContinuation()
    {
        var ini = "[s1]\nkey=line1\n  line2\n\n[s2]\nother=val";
        var doc = IniParser.Parse(ini);
        Assert.Equal("line1\nline2", doc.Sections["s1"]["key"]);
        Assert.Equal("val", doc.Sections["s2"]["other"]);
    }
}
