// IntegrationTests.cs
// End-to-end tests covering the full parse → validate → convert pipeline
// using real fixture files and combining all components together.

using System.Text.Json.Nodes;
using ConfigMigratorLib;
using Xunit;

namespace ConfigMigrator.Tests;

public class IntegrationTests
{
    private readonly IniParser _parser = new();
    private readonly SchemaValidator _validator = new();
    private readonly JsonOutputConverter _jsonConverter = new();
    private readonly YamlOutputConverter _yamlConverter = new();

    // ---- complex.ini fixture ------------------------------------------------

    [Fact]
    public void ComplexFixture_ParsedCorrectly()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "complex.ini"));

        // Global keys
        Assert.Equal("MyApp", doc.GlobalSection.RawValues["app_name"]);
        Assert.Equal("2.5.0", doc.GlobalSection.RawValues["version"]);

        // Sections present
        Assert.True(doc.HasSection("server"));
        Assert.True(doc.HasSection("database"));
        Assert.True(doc.HasSection("logging"));
        Assert.True(doc.HasSection("cache"));

        // Typed values
        Assert.Equal("8080", doc.Sections["server"].RawValues["port"]);
        Assert.Equal("host1, host2, host3", doc.Sections["server"].RawValues["allowed_hosts"]);
    }

    [Fact]
    public void ComplexFixture_MultiLineValue_ConcatenatedCorrectly()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "complex.ini"));

        var desc = doc.Sections["logging"].RawValues["description"];
        Assert.Contains("multiple lines", desc);
        Assert.DoesNotContain("\\", desc);  // Continuation backslash removed
    }

    [Fact]
    public void ComplexFixture_ValidatesAgainstSchema()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "complex.ini"));
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Required = true,
                    Keys = new()
                    {
                        ["host"]  = new KeySchema { Name = "host",  Required = true, Type = IniValueType.String  },
                        ["port"]  = new KeySchema { Name = "port",  Required = true, Type = IniValueType.Integer },
                        ["enable_ssl"] = new KeySchema { Name = "enable_ssl", Type = IniValueType.Boolean }
                    }
                },
                ["database"] = new SectionSchema
                {
                    Name = "database",
                    Required = true,
                    Keys = new()
                    {
                        ["host"] = new KeySchema { Name = "host", Required = true },
                        ["port"] = new KeySchema { Name = "port", Required = true, Type = IniValueType.Integer },
                        ["name"] = new KeySchema { Name = "name", Required = true }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.True(result.IsValid, string.Join("; ", result.Errors));
    }

    [Fact]
    public void ComplexFixture_JsonConversion_ProducesValidJson()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "complex.ini"));

        var json = _jsonConverter.Convert(doc);

        var root = JsonNode.Parse(json);
        Assert.NotNull(root);

        // Verify structure
        Assert.Equal("MyApp", root!["app_name"]!.GetValue<string>());
        Assert.Equal(8080, root["server"]!["port"]!.GetValue<int>());
        Assert.Equal(true, root["cache"]!["enabled"]!.GetValue<bool>());
    }

    [Fact]
    public void ComplexFixture_YamlConversion_ContainsExpectedKeys()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "complex.ini"));

        var yaml = _yamlConverter.Convert(doc);

        Assert.Contains("app_name:", yaml);
        Assert.Contains("server:", yaml);
        Assert.Contains("database:", yaml);
        Assert.Contains("logging:", yaml);
    }

    // ---- edge_cases.ini fixture ---------------------------------------------

    [Fact]
    public void EdgeCasesFixture_EmptyValues_ParsedAsEmptyStrings()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "edge_cases.ini"));

        Assert.Equal("", doc.Sections["empty_values"].RawValues["empty_key"]);
        Assert.Equal("", doc.Sections["empty_values"].RawValues["whitespace_value"]);
    }

    [Fact]
    public void EdgeCasesFixture_ConnectionStringWithEquals_Preserved()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "edge_cases.ini"));

        var conn = doc.Sections["special_chars"].RawValues["connection_string"];
        Assert.Contains("host=localhost", conn);
        Assert.Contains("port=5432", conn);
    }

    [Fact]
    public void EdgeCasesFixture_DuplicateKey_LastValueWins()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "edge_cases.ini"));

        Assert.Equal("second_value", doc.Sections["duplicates"].RawValues["key"]);
    }

    [Fact]
    public void EdgeCasesFixture_MultiLineValueInSql_Concatenated()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "edge_cases.ini"));

        var sql = doc.Sections["multiline"].RawValues["sql_query"];
        Assert.Contains("SELECT", sql);
        Assert.Contains("ORDER BY", sql);
        Assert.DoesNotContain("\\", sql);
    }

    [Fact]
    public void EdgeCasesFixture_AutoCoercionInJson_CorrectTypes()
    {
        var doc = _parser.ParseFile(Path.Combine("Fixtures", "edge_cases.ini"));

        var json = _jsonConverter.Convert(doc);
        var root = JsonNode.Parse(json)!;

        Assert.Equal(42,    root["types"]!["integer_pos"]!.GetValue<int>());
        Assert.Equal(-17,   root["types"]!["integer_neg"]!.GetValue<int>());
        Assert.Equal(true,  root["types"]!["bool_true_word"]!.GetValue<bool>());
        Assert.Equal(false, root["types"]!["bool_false_word"]!.GetValue<bool>());
        // Plain string stays as string
        Assert.IsType<string>(root["types"]!["plain_string"]!.GetValue<string>());
    }

    // ---- Schema validation failure path ------------------------------------

    [Fact]
    public void ValidationFailure_MissingRequiredSections_ReportsAllErrors()
    {
        var doc = _parser.Parse("[other]\nkey=value");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"]   = new SectionSchema { Name = "server",   Required = true, Keys = new() },
                ["database"] = new SectionSchema { Name = "database", Required = true, Keys = new() }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.False(result.IsValid);
        Assert.Equal(2, result.Errors.Count);
    }
}
