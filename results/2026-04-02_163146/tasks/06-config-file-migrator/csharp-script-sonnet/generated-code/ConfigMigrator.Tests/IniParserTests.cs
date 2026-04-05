// IniParserTests.cs
// TDD RED/GREEN cycle for INI parsing functionality.
// Tests are written FIRST — the build will fail until the library is created (RED phase).
// Each test documents which RED/GREEN cycle it belongs to.

using ConfigMigratorLib;
using Xunit;

namespace ConfigMigrator.Tests;

// =============================================================================
// RED 1: Basic key=value inside a section
// =============================================================================
public class IniParserTests
{
    private readonly IniParser _parser = new();

    // RED 1 — Fails: IniParser doesn't exist yet
    [Fact]
    public void Parse_BasicKeyValueInSection_ReturnsExpectedValue()
    {
        const string content = "[server]\nhost=localhost";

        var doc = _parser.Parse(content);

        Assert.Equal("localhost", doc.Sections["server"].RawValues["host"]);
    }

    // RED 2 — Fails after GREEN 1: multi-key sections
    [Fact]
    public void Parse_MultipleKeysInSection_ReturnsAllKeys()
    {
        const string content = "[server]\nhost=localhost\nport=8080";

        var doc = _parser.Parse(content);

        Assert.Equal("localhost", doc.Sections["server"].RawValues["host"]);
        Assert.Equal("8080", doc.Sections["server"].RawValues["port"]);
    }

    // RED 3 — Section comment lines (;) must be skipped
    [Fact]
    public void Parse_SemicolonComments_AreSkipped()
    {
        const string content = "[server]\n; This is a comment\nhost=localhost";

        var doc = _parser.Parse(content);

        Assert.Single(doc.Sections["server"].RawValues);
        Assert.Equal("localhost", doc.Sections["server"].RawValues["host"]);
    }

    // RED 4 — Hash comments (#) must be skipped
    [Fact]
    public void Parse_HashComments_AreSkipped()
    {
        const string content = "[server]\n# This is a hash comment\nhost=localhost";

        var doc = _parser.Parse(content);

        Assert.Single(doc.Sections["server"].RawValues);
    }

    // RED 5 — Multiple sections
    [Fact]
    public void Parse_MultipleSections_ReturnsAllSections()
    {
        const string content = "[server]\nhost=localhost\n[database]\nname=mydb";

        var doc = _parser.Parse(content);

        Assert.Equal(2, doc.Sections.Count);
        Assert.Equal("localhost", doc.Sections["server"].RawValues["host"]);
        Assert.Equal("mydb", doc.Sections["database"].RawValues["name"]);
    }

    // RED 6 — Global (no-section) keys appear in GlobalSection
    [Fact]
    public void Parse_GlobalKeys_AppearInGlobalSection()
    {
        const string content = "app_name=MyApp\nversion=1.0\n[server]\nhost=localhost";

        var doc = _parser.Parse(content);

        Assert.Equal("MyApp", doc.GlobalSection.RawValues["app_name"]);
        Assert.Equal("1.0", doc.GlobalSection.RawValues["version"]);
        Assert.Equal("localhost", doc.Sections["server"].RawValues["host"]);
    }

    // RED 7 — Multi-line values via backslash continuation
    [Fact]
    public void Parse_MultiLineValue_ConcatenatesLines()
    {
        const string content = "[desc]\ntext=Hello \\\n      World";

        var doc = _parser.Parse(content);

        Assert.Equal("Hello World", doc.Sections["desc"].RawValues["text"]);
    }

    // RED 8 — Values with = sign inside them (only split on first =)
    [Fact]
    public void Parse_ValueContainsEquals_PreservesFullValue()
    {
        const string content = "[db]\nconnection=host=localhost;port=5432";

        var doc = _parser.Parse(content);

        Assert.Equal("host=localhost;port=5432", doc.Sections["db"].RawValues["connection"]);
    }

    // RED 9 — Empty values are preserved as empty string
    [Fact]
    public void Parse_EmptyValue_ReturnsEmptyString()
    {
        const string content = "[section]\nempty_key=";

        var doc = _parser.Parse(content);

        Assert.Equal("", doc.Sections["section"].RawValues["empty_key"]);
    }

    // RED 10 — Whitespace around key and value is trimmed
    [Fact]
    public void Parse_WhitespaceAroundKeyValue_IsTrimmed()
    {
        const string content = "[section]\n  key  =  value  ";

        var doc = _parser.Parse(content);

        Assert.Equal("value", doc.Sections["section"].RawValues["key"]);
    }

    // RED 11 — Parse from file path
    [Fact]
    public void ParseFile_BasicFixture_ReturnsDocument()
    {
        var path = Path.Combine("Fixtures", "basic.ini");

        var doc = _parser.ParseFile(path);

        Assert.True(doc.Sections.ContainsKey("server"));
        Assert.Equal("localhost", doc.Sections["server"].RawValues["host"]);
    }

    // RED 12 — ParseFile throws on missing file
    [Fact]
    public void ParseFile_NonexistentFile_ThrowsFileNotFoundException()
    {
        Assert.Throws<FileNotFoundException>(() => _parser.ParseFile("nonexistent.ini"));
    }

    // RED 13 — CRLF line endings are handled
    [Fact]
    public void Parse_CrlfLineEndings_ParsedCorrectly()
    {
        const string content = "[section]\r\nkey=value\r\n";

        var doc = _parser.Parse(content);

        Assert.Equal("value", doc.Sections["section"].RawValues["key"]);
    }
}
