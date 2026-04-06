// JsonOutputTests.cs
// TDD RED/GREEN cycle for JSON output conversion.

using System.Text.Json;
using System.Text.Json.Nodes;
using ConfigMigratorLib;
using Xunit;

namespace ConfigMigrator.Tests;

public class JsonOutputTests
{
    private readonly IniParser _parser = new();
    private readonly JsonOutputConverter _converter = new();

    // RED 23 — Basic section is serialized to a JSON object
    [Fact]
    public void Convert_BasicSection_ProducesJsonObject()
    {
        var doc = _parser.Parse("[server]\nhost=localhost\nport=8080");

        var json = _converter.Convert(doc);
        var root = JsonNode.Parse(json)!.AsObject();

        Assert.NotNull(root["server"]);
        var server = root["server"]!.AsObject();
        Assert.Equal("localhost", server["host"]!.GetValue<string>());
    }

    // RED 24 — Auto-coercion: numeric string becomes JSON number
    [Fact]
    public void Convert_NumericValue_BecomesJsonNumber()
    {
        var doc = _parser.Parse("[server]\nport=8080");

        var json = _converter.Convert(doc);
        var root = JsonNode.Parse(json)!.AsObject();
        var port = root["server"]!["port"];

        Assert.NotNull(port);
        Assert.Equal(8080, port!.GetValue<int>());
    }

    // RED 25 — Auto-coercion: boolean string becomes JSON boolean
    [Fact]
    public void Convert_BooleanValue_BecomesJsonBool()
    {
        var doc = _parser.Parse("[server]\ndebug=true");

        var json = _converter.Convert(doc);
        var root = JsonNode.Parse(json)!.AsObject();
        var debug = root["server"]!["debug"];

        Assert.Equal(true, debug!.GetValue<bool>());
    }

    // RED 26 — Global keys appear at JSON root level
    [Fact]
    public void Convert_GlobalKeys_AppearAtRoot()
    {
        var doc = _parser.Parse("app_name=MyApp\n[server]\nhost=localhost");

        var json = _converter.Convert(doc);
        var root = JsonNode.Parse(json)!.AsObject();

        Assert.Equal("MyApp", root["app_name"]!.GetValue<string>());
    }

    // RED 27 — Schema-driven type coercion overrides auto-detection
    [Fact]
    public void Convert_WithSchema_UsesSchemaTypes()
    {
        var doc = _parser.Parse("[server]\nport=8080\nenabled=yes");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Keys = new()
                    {
                        ["port"]    = new KeySchema { Name = "port",    Type = IniValueType.Integer },
                        ["enabled"] = new KeySchema { Name = "enabled", Type = IniValueType.Boolean }
                    }
                }
            }
        };

        var json = _converter.Convert(doc, schema);
        var root = JsonNode.Parse(json)!.AsObject();

        Assert.Equal(8080, root["server"]!["port"]!.GetValue<int>());
        Assert.Equal(true,  root["server"]!["enabled"]!.GetValue<bool>());
    }

    // RED 28 — Array value becomes JSON array
    [Fact]
    public void Convert_ArrayValue_BecomesJsonArray()
    {
        var doc = _parser.Parse("[server]\nhosts=host1,host2,host3");
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

        var json = _converter.Convert(doc, schema);
        var root = JsonNode.Parse(json)!.AsObject();
        var hosts = root["server"]!["hosts"]!.AsArray();

        Assert.Equal(3, hosts.Count);
        Assert.Equal("host1", hosts[0]!.GetValue<string>());
    }

    // RED 29 — Output is pretty-printed (indented)
    [Fact]
    public void Convert_Output_IsPrettyPrinted()
    {
        var doc = _parser.Parse("[section]\nkey=value");

        var json = _converter.Convert(doc);

        Assert.Contains('\n', json);  // Pretty-printed has newlines
    }

    // RED 30 — Multiple sections produce independent JSON objects
    [Fact]
    public void Convert_MultipleSections_ProduceIndependentObjects()
    {
        var doc = _parser.Parse("[server]\nhost=localhost\n[database]\nname=mydb");

        var json = _converter.Convert(doc);
        var root = JsonNode.Parse(json)!.AsObject();

        Assert.Equal("localhost", root["server"]!["host"]!.GetValue<string>());
        Assert.Equal("mydb", root["database"]!["name"]!.GetValue<string>());
    }
}
