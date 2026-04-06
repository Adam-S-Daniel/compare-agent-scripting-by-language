using System.Text.Json;
using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// Tests for JSON output generation from INI documents.
/// </summary>
public class JsonOutputTests
{
    [Fact]
    public void ToJson_SimpleKeyValue_ProducesValidJson()
    {
        var doc = IniParser.Parse("name=MyApp");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        Assert.Equal("MyApp", parsed.RootElement.GetProperty("name").GetString());
    }

    [Fact]
    public void ToJson_SectionedKeys_ProducesNestedObject()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost\nport=5432");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        var dbSection = parsed.RootElement.GetProperty("database");
        Assert.Equal("localhost", dbSection.GetProperty("host").GetString());
        Assert.Equal(5432, dbSection.GetProperty("port").GetInt32());
    }

    [Fact]
    public void ToJson_BooleanValues_AreCoerced()
    {
        var doc = IniParser.Parse("[features]\nenabled=true\nverbose=false");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        var features = parsed.RootElement.GetProperty("features");
        Assert.True(features.GetProperty("enabled").GetBoolean());
        Assert.False(features.GetProperty("verbose").GetBoolean());
    }

    [Fact]
    public void ToJson_IntegerValues_AreCoerced()
    {
        var doc = IniParser.Parse("[server]\nport=8080\ntimeout=30");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        var server = parsed.RootElement.GetProperty("server");
        Assert.Equal(8080, server.GetProperty("port").GetInt32());
        Assert.Equal(30, server.GetProperty("timeout").GetInt32());
    }

    [Fact]
    public void ToJson_FloatValues_AreCoerced()
    {
        var doc = IniParser.Parse("[metrics]\nthreshold=0.95\nrate=1.5e2");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        var metrics = parsed.RootElement.GetProperty("metrics");
        Assert.Equal(0.95, metrics.GetProperty("threshold").GetDouble(), 2);
        Assert.Equal(150.0, metrics.GetProperty("rate").GetDouble(), 1);
    }

    [Fact]
    public void ToJson_StringValues_RemainStrings()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost\nname=mydb");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        var db = parsed.RootElement.GetProperty("database");
        Assert.Equal(JsonValueKind.String, db.GetProperty("host").ValueKind);
        Assert.Equal("localhost", db.GetProperty("host").GetString());
    }

    [Fact]
    public void ToJson_GlobalAndSectionedKeys_CoexistInOutput()
    {
        var doc = IniParser.Parse("app=MyApp\n[database]\nhost=localhost");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        Assert.Equal("MyApp", parsed.RootElement.GetProperty("app").GetString());
        Assert.Equal("localhost",
            parsed.RootElement.GetProperty("database").GetProperty("host").GetString());
    }

    [Fact]
    public void ToJson_WithSchema_UsesSchemaTypes()
    {
        var doc = IniParser.Parse("[server]\nport=8080");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("server", "port", SchemaValueType.Integer, required: true)
            }
        };
        var json = ConfigConverter.ToJson(doc, schema);
        var parsed = JsonDocument.Parse(json);

        Assert.Equal(8080, parsed.RootElement.GetProperty("server").GetProperty("port").GetInt32());
    }

    [Fact]
    public void ToJson_EmptyDocument_ProducesEmptyObject()
    {
        var doc = IniParser.Parse("");
        var json = ConfigConverter.ToJson(doc);
        var parsed = JsonDocument.Parse(json);

        Assert.Equal(JsonValueKind.Object, parsed.RootElement.ValueKind);
    }

    [Fact]
    public void ToJson_OutputIsValidJson()
    {
        // Complex document should produce valid JSON
        var ini = @"
app_name=TestApp
version=2

[database]
host=localhost
port=5432
ssl=true
timeout=30.5

[logging]
level=debug
enabled=yes
";
        var doc = IniParser.Parse(ini);
        var json = ConfigConverter.ToJson(doc);

        // Should not throw
        var parsed = JsonDocument.Parse(json);
        Assert.NotNull(parsed);
    }
}
