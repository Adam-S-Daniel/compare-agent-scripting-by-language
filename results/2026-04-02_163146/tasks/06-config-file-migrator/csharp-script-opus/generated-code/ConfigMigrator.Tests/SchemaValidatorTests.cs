using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// Tests for schema validation: required keys and value type checking.
/// </summary>
public class SchemaValidatorTests
{
    [Fact]
    public void Validate_AllRequiredKeysPresent_IsValid()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost\nport=5432");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "host", SchemaValueType.String, required: true),
                new SchemaRule("database", "port", SchemaValueType.Integer, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.True(result.IsValid);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void Validate_MissingRequiredKey_ReturnsError()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "host", SchemaValueType.String, required: true),
                new SchemaRule("database", "port", SchemaValueType.Integer, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
        Assert.Single(result.Errors);
        Assert.Contains("port", result.Errors[0]);
    }

    [Fact]
    public void Validate_MissingRequiredSection_ReturnsError()
    {
        var doc = IniParser.Parse("[server]\nport=8080");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "host", SchemaValueType.String, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
        Assert.Contains("host", result.Errors[0]);
    }

    [Fact]
    public void Validate_InvalidIntegerType_ReturnsError()
    {
        var doc = IniParser.Parse("[database]\nport=not_a_number");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "port", SchemaValueType.Integer, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
        Assert.Contains("invalid type", result.Errors[0]);
    }

    [Fact]
    public void Validate_InvalidBooleanType_ReturnsError()
    {
        var doc = IniParser.Parse("[features]\nenabled=maybe");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("features", "enabled", SchemaValueType.Boolean, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
        Assert.Contains("invalid type", result.Errors[0]);
    }

    [Fact]
    public void Validate_ValidBooleanValues_AreAccepted()
    {
        // Test all accepted boolean strings
        var boolValues = new[] { "true", "false", "yes", "no", "on", "off", "1", "0" };
        foreach (var bv in boolValues)
        {
            var doc = IniParser.Parse($"[features]\nenabled={bv}");
            var schema = new Schema
            {
                Rules = new()
                {
                    new SchemaRule("features", "enabled", SchemaValueType.Boolean, required: true)
                }
            };

            var result = SchemaValidator.Validate(doc, schema);
            Assert.True(result.IsValid, $"Boolean value '{bv}' should be valid");
        }
    }

    [Fact]
    public void Validate_InvalidFloatType_ReturnsError()
    {
        var doc = IniParser.Parse("[metrics]\nthreshold=abc");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("metrics", "threshold", SchemaValueType.Float, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
    }

    [Fact]
    public void Validate_ValidFloatValue_IsAccepted()
    {
        var doc = IniParser.Parse("[metrics]\nthreshold=3.14");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("metrics", "threshold", SchemaValueType.Float, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.True(result.IsValid);
    }

    [Fact]
    public void Validate_OptionalKeyMissing_IsValid()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "host", SchemaValueType.String, required: true),
                new SchemaRule("database", "timeout", SchemaValueType.Integer, required: false)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.True(result.IsValid);
    }

    [Fact]
    public void Validate_GlobalSectionKeys_WorkCorrectly()
    {
        var doc = IniParser.Parse("app_name=MyApp\nversion=1");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("", "app_name", SchemaValueType.String, required: true),
                new SchemaRule("", "version", SchemaValueType.Integer, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.True(result.IsValid);
    }

    [Fact]
    public void Validate_MultipleErrors_ReportsAll()
    {
        var doc = IniParser.Parse("[database]\nhost=localhost");
        var schema = new Schema
        {
            Rules = new()
            {
                new SchemaRule("database", "port", SchemaValueType.Integer, required: true),
                new SchemaRule("database", "password", SchemaValueType.String, required: true)
            }
        };

        var result = SchemaValidator.Validate(doc, schema);
        Assert.False(result.IsValid);
        Assert.Equal(2, result.Errors.Count);
    }
}
