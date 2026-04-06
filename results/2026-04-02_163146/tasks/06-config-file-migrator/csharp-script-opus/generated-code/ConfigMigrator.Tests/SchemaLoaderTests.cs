using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// Tests for loading schema definitions from JSON.
/// </summary>
public class SchemaLoaderTests
{
    [Fact]
    public void LoadFromJson_ValidSchema_ParsesCorrectly()
    {
        var json = @"{
            ""rules"": [
                { ""section"": ""database"", ""key"": ""host"", ""type"": ""string"", ""required"": true },
                { ""section"": ""database"", ""key"": ""port"", ""type"": ""integer"", ""required"": true },
                { ""section"": """", ""key"": ""debug"", ""type"": ""boolean"", ""required"": false }
            ]
        }";

        var schema = SchemaLoader.LoadFromJson(json);

        Assert.Equal(3, schema.Rules.Count);
        Assert.Equal("database", schema.Rules[0].Section);
        Assert.Equal("host", schema.Rules[0].Key);
        Assert.Equal(SchemaValueType.String, schema.Rules[0].ValueType);
        Assert.True(schema.Rules[0].Required);

        Assert.Equal(SchemaValueType.Integer, schema.Rules[1].ValueType);
        Assert.Equal(SchemaValueType.Boolean, schema.Rules[2].ValueType);
        Assert.False(schema.Rules[2].Required);
    }

    [Fact]
    public void LoadFromJson_EmptyRules_ReturnsEmptySchema()
    {
        var json = @"{ ""rules"": [] }";
        var schema = SchemaLoader.LoadFromJson(json);
        Assert.Empty(schema.Rules);
    }

    [Fact]
    public void LoadFromJson_TypeAliases_ParsedCorrectly()
    {
        var json = @"{
            ""rules"": [
                { ""section"": """", ""key"": ""a"", ""type"": ""int"", ""required"": false },
                { ""section"": """", ""key"": ""b"", ""type"": ""bool"", ""required"": false },
                { ""section"": """", ""key"": ""c"", ""type"": ""double"", ""required"": false },
                { ""section"": """", ""key"": ""d"", ""type"": ""number"", ""required"": false }
            ]
        }";

        var schema = SchemaLoader.LoadFromJson(json);
        Assert.Equal(SchemaValueType.Integer, schema.Rules[0].ValueType);
        Assert.Equal(SchemaValueType.Boolean, schema.Rules[1].ValueType);
        Assert.Equal(SchemaValueType.Float, schema.Rules[2].ValueType);
        Assert.Equal(SchemaValueType.Float, schema.Rules[3].ValueType);
    }
}
