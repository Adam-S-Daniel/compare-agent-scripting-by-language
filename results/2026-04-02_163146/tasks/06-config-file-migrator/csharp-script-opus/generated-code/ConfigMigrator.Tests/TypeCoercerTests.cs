using Xunit;
using ConfigMigrator;

namespace ConfigMigrator.Tests;

/// <summary>
/// Tests for type coercion: converting INI string values to appropriate .NET types.
/// </summary>
public class TypeCoercerTests
{
    // --- Boolean coercion ---

    [Theory]
    [InlineData("true", true)]
    [InlineData("True", true)]
    [InlineData("TRUE", true)]
    [InlineData("yes", true)]
    [InlineData("Yes", true)]
    [InlineData("on", true)]
    [InlineData("1", true)]
    [InlineData("false", false)]
    [InlineData("False", false)]
    [InlineData("no", false)]
    [InlineData("off", false)]
    [InlineData("0", false)]
    public void Coerce_BooleanStrings_ReturnsBool(string input, bool expected)
    {
        var result = TypeCoercer.Coerce(input);
        Assert.IsType<bool>(result);
        Assert.Equal(expected, (bool)result);
    }

    // --- Integer coercion ---
    // Note: "0" and "1" are coerced as booleans (tested above), not integers.

    [Theory]
    [InlineData("42", 42)]
    [InlineData("-7", -7)]
    [InlineData("100", 100)]
    [InlineData("999", 999)]
    public void Coerce_IntegerStrings_ReturnsInt(string input, int expected)
    {
        var result = TypeCoercer.Coerce(input);
        Assert.IsType<int>(result);
        Assert.Equal(expected, (int)result);
    }

    [Fact]
    public void Coerce_LargeInteger_ReturnsLong()
    {
        var result = TypeCoercer.Coerce("9999999999");
        Assert.IsType<long>(result);
        Assert.Equal(9999999999L, (long)result);
    }

    // --- Float coercion ---

    [Fact]
    public void Coerce_FloatString_ReturnsDouble()
    {
        var result = TypeCoercer.Coerce("3.14");
        Assert.IsType<double>(result);
        Assert.Equal(3.14, (double)result, 2);
    }

    [Fact]
    public void Coerce_ScientificNotation_ReturnsDouble()
    {
        var result = TypeCoercer.Coerce("1.5e10");
        Assert.IsType<double>(result);
        Assert.Equal(1.5e10, (double)result);
    }

    [Fact]
    public void Coerce_NegativeFloat_ReturnsDouble()
    {
        var result = TypeCoercer.Coerce("-0.5");
        Assert.IsType<double>(result);
        Assert.Equal(-0.5, (double)result);
    }

    // --- String fallback ---

    [Theory]
    [InlineData("hello")]
    [InlineData("some random text")]
    [InlineData("localhost")]
    [InlineData("")]
    public void Coerce_RegularStrings_ReturnsString(string input)
    {
        var result = TypeCoercer.Coerce(input);
        Assert.IsType<string>(result);
        Assert.Equal(input, (string)result);
    }

    // --- Schema-directed coercion ---

    [Fact]
    public void CoerceWithType_IntegerType_CoercesToInt()
    {
        var result = TypeCoercer.CoerceWithType("42", SchemaValueType.Integer);
        Assert.IsType<int>(result);
        Assert.Equal(42, (int)result);
    }

    [Fact]
    public void CoerceWithType_BooleanType_CoercesToBool()
    {
        var result = TypeCoercer.CoerceWithType("yes", SchemaValueType.Boolean);
        Assert.IsType<bool>(result);
        Assert.True((bool)result);
    }

    [Fact]
    public void CoerceWithType_FloatType_CoercesToDouble()
    {
        var result = TypeCoercer.CoerceWithType("3.14", SchemaValueType.Float);
        Assert.IsType<double>(result);
        Assert.Equal(3.14, (double)result, 2);
    }

    [Fact]
    public void CoerceWithType_StringType_RemainsString()
    {
        var result = TypeCoercer.CoerceWithType("hello", SchemaValueType.String);
        Assert.IsType<string>(result);
        Assert.Equal("hello", (string)result);
    }

    [Fact]
    public void CoerceWithType_InvalidValue_FallsBackToString()
    {
        // "abc" can't be coerced to integer — should fall back to string
        var result = TypeCoercer.CoerceWithType("abc", SchemaValueType.Integer);
        Assert.IsType<string>(result);
        Assert.Equal("abc", (string)result);
    }
}
