using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// TDD RED phase: Tests for INI file parsing.
/// These tests define the expected behavior of the IniParser class.
/// </summary>
public class IniParserTests
{
    // --- Basic key-value parsing ---

    [Fact]
    public void Parse_SimpleKeyValue_ReturnsSingleSection()
    {
        var ini = "key=value";
        var result = IniParser.Parse(ini);

        // Keys without a section header go into the global (empty-string) section
        Assert.True(result.Sections.ContainsKey(""));
        Assert.Equal("value", result.Sections[""]["key"]);
    }

    [Fact]
    public void Parse_KeyValueWithSpaces_TrimsCorrectly()
    {
        var ini = "  key  =  value  ";
        var result = IniParser.Parse(ini);
        Assert.Equal("value", result.Sections[""]["key"]);
    }

    // --- Section parsing ---

    [Fact]
    public void Parse_SingleSection_CreatesNamedSection()
    {
        var ini = "[database]\nhost=localhost\nport=5432";
        var result = IniParser.Parse(ini);

        Assert.True(result.Sections.ContainsKey("database"));
        Assert.Equal("localhost", result.Sections["database"]["host"]);
        Assert.Equal("5432", result.Sections["database"]["port"]);
    }

    [Fact]
    public void Parse_MultipleSections_CreatesAllSections()
    {
        var ini = "[database]\nhost=localhost\n\n[server]\nport=8080";
        var result = IniParser.Parse(ini);

        Assert.True(result.Sections.ContainsKey("database"));
        Assert.True(result.Sections.ContainsKey("server"));
        Assert.Equal("localhost", result.Sections["database"]["host"]);
        Assert.Equal("8080", result.Sections["server"]["port"]);
    }

    // --- Comments ---

    [Fact]
    public void Parse_SemicolonComments_AreIgnored()
    {
        var ini = "; this is a comment\nkey=value";
        var result = IniParser.Parse(ini);
        Assert.Equal("value", result.Sections[""]["key"]);
        Assert.Single(result.Sections[""]); // only one key, comment not included
    }

    [Fact]
    public void Parse_HashComments_AreIgnored()
    {
        var ini = "# this is a comment\nkey=value";
        var result = IniParser.Parse(ini);
        Assert.Equal("value", result.Sections[""]["key"]);
        Assert.Single(result.Sections[""]); // only one key
    }

    // --- Multi-line values (continuation lines start with whitespace) ---

    [Fact]
    public void Parse_MultiLineValue_ConcatenatesLines()
    {
        // Lines starting with whitespace are continuation of the previous value
        var ini = "[section]\ndescription=This is a long\n  multi-line value\n  that spans three lines";
        var result = IniParser.Parse(ini);
        Assert.Equal("This is a long\nmulti-line value\nthat spans three lines",
            result.Sections["section"]["description"]);
    }

    // --- Empty lines and blank values ---

    [Fact]
    public void Parse_EmptyLines_AreIgnored()
    {
        var ini = "[section]\n\nkey=value\n\n";
        var result = IniParser.Parse(ini);
        Assert.Equal("value", result.Sections["section"]["key"]);
    }

    [Fact]
    public void Parse_EmptyValue_IsAllowed()
    {
        var ini = "key=";
        var result = IniParser.Parse(ini);
        Assert.Equal("", result.Sections[""]["key"]);
    }

    // --- Quoted values ---

    [Fact]
    public void Parse_QuotedValue_RemovesQuotes()
    {
        var ini = "name=\"John Doe\"";
        var result = IniParser.Parse(ini);
        Assert.Equal("John Doe", result.Sections[""]["name"]);
    }

    [Fact]
    public void Parse_SingleQuotedValue_RemovesQuotes()
    {
        var ini = "name='John Doe'";
        var result = IniParser.Parse(ini);
        Assert.Equal("John Doe", result.Sections[""]["name"]);
    }

    // --- Values containing equals signs ---

    [Fact]
    public void Parse_ValueWithEqualsSign_PreservesEquals()
    {
        var ini = "connection=host=localhost;port=5432";
        var result = IniParser.Parse(ini);
        Assert.Equal("host=localhost;port=5432", result.Sections[""]["connection"]);
    }

    // --- Global and sectioned keys together ---

    [Fact]
    public void Parse_GlobalAndSectionedKeys_CoexistCorrectly()
    {
        var ini = "global_key=global_val\n[section]\nsection_key=section_val";
        var result = IniParser.Parse(ini);
        Assert.Equal("global_val", result.Sections[""]["global_key"]);
        Assert.Equal("section_val", result.Sections["section"]["section_key"]);
    }
}
