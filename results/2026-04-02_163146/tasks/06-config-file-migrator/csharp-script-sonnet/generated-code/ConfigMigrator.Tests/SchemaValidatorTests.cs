// SchemaValidatorTests.cs
// TDD RED/GREEN cycle for schema validation.
// Tests are written before SchemaValidator exists.

using ConfigMigratorLib;
using Xunit;

namespace ConfigMigrator.Tests;

public class SchemaValidatorTests
{
    private readonly IniParser _parser = new();
    private readonly SchemaValidator _validator = new();

    // RED 14 — Valid document against empty schema passes
    [Fact]
    public void Validate_EmptySchema_IsAlwaysValid()
    {
        var doc = _parser.Parse("[section]\nkey=value");
        var schema = new IniSchema();

        var result = _validator.Validate(doc, schema);

        Assert.True(result.IsValid);
    }

    // RED 15 — Missing required section produces an error
    [Fact]
    public void Validate_MissingRequiredSection_AddsError()
    {
        var doc = _parser.Parse("[other]\nkey=value");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Required = true,
                    Keys = new()
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.Contains("server") && e.Contains("missing"));
    }

    // RED 16 — Missing required key within present section produces an error
    [Fact]
    public void Validate_MissingRequiredKey_AddsError()
    {
        var doc = _parser.Parse("[server]\nport=8080");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Keys = new()
                    {
                        ["host"] = new KeySchema { Name = "host", Required = true }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.Contains("host") && e.Contains("missing"));
    }

    // RED 17 — Present required key passes validation
    [Fact]
    public void Validate_PresentRequiredKey_IsValid()
    {
        var doc = _parser.Parse("[server]\nhost=localhost");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Keys = new()
                    {
                        ["host"] = new KeySchema { Name = "host", Required = true, Type = IniValueType.String }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.True(result.IsValid);
    }

    // RED 18 — Integer key with non-numeric value produces type error
    [Fact]
    public void Validate_IntegerKeyWithStringValue_AddsTypeError()
    {
        var doc = _parser.Parse("[server]\nport=notanumber");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Keys = new()
                    {
                        ["port"] = new KeySchema { Name = "port", Required = true, Type = IniValueType.Integer }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.Contains("port"));
    }

    // RED 19 — Boolean key with valid boolean string passes
    [Fact]
    public void Validate_BooleanKeyWithValidValue_IsValid()
    {
        var doc = _parser.Parse("[server]\ndebug=true");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["server"] = new SectionSchema
                {
                    Name = "server",
                    Keys = new()
                    {
                        ["debug"] = new KeySchema { Name = "debug", Type = IniValueType.Boolean }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.True(result.IsValid);
    }

    // RED 20 — Float key with valid float string passes
    [Fact]
    public void Validate_FloatKeyWithValidValue_IsValid()
    {
        var doc = _parser.Parse("[metrics]\nrate=3.14");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["metrics"] = new SectionSchema
                {
                    Name = "metrics",
                    Keys = new()
                    {
                        ["rate"] = new KeySchema { Name = "rate", Type = IniValueType.Float }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.True(result.IsValid);
    }

    // RED 21 — Global section required key is validated
    [Fact]
    public void Validate_GlobalRequiredKey_Missing_AddsError()
    {
        var doc = _parser.Parse("[server]\nhost=localhost");
        var schema = new IniSchema
        {
            GlobalSchema = new SectionSchema
            {
                Name = "",
                Keys = new()
                {
                    ["app_name"] = new KeySchema { Name = "app_name", Required = true }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.Contains("app_name"));
    }

    // RED 22 — Optional section present with wrong type still errors
    [Fact]
    public void Validate_OptionalSectionPresent_TypeStillValidated()
    {
        var doc = _parser.Parse("[logging]\nlevel=123abc");
        var schema = new IniSchema
        {
            Sections = new()
            {
                ["logging"] = new SectionSchema
                {
                    Name = "logging",
                    Required = false,
                    Keys = new()
                    {
                        ["level"] = new KeySchema { Name = "level", Type = IniValueType.Integer }
                    }
                }
            }
        };

        var result = _validator.Validate(doc, schema);

        Assert.False(result.IsValid);
    }
}
