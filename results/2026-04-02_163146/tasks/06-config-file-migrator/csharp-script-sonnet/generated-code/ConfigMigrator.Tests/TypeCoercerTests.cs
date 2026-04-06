// TypeCoercerTests.cs
// TDD RED/GREEN cycle for type coercion.
// TypeCoercer is already implemented; these tests lock in expected behaviour.

using ConfigMigratorLib;
using Xunit;

namespace ConfigMigrator.Tests;

public class TypeCoercerTests
{
    // ---- Boolean coercion ---------------------------------------------------

    [Theory]
    [InlineData("true",     true)]
    [InlineData("True",     true)]
    [InlineData("TRUE",     true)]
    [InlineData("yes",      true)]
    [InlineData("on",       true)]
    [InlineData("enabled",  true)]
    [InlineData("false",    false)]
    [InlineData("False",    false)]
    [InlineData("no",       false)]
    [InlineData("off",      false)]
    [InlineData("disabled", false)]
    public void CoerceBoolean_ValidValues_ReturnsExpected(string input, bool expected)
    {
        Assert.Equal(expected, TypeCoercer.CoerceBoolean(input));
    }

    [Fact]
    public void CoerceBoolean_InvalidValue_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => TypeCoercer.CoerceBoolean("maybe"));
    }

    // ---- Integer coercion ---------------------------------------------------

    [Theory]
    [InlineData("42",   42)]
    [InlineData("-17", -17)]
    [InlineData("0",    0)]
    public void CoerceInteger_ValidValues_ReturnsExpected(string input, int expected)
    {
        Assert.Equal(expected, TypeCoercer.CoerceInteger(input));
    }

    [Fact]
    public void CoerceInteger_InvalidValue_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => TypeCoercer.CoerceInteger("3.14"));
    }

    // ---- Float coercion -----------------------------------------------------

    [Theory]
    [InlineData("3.14",  3.14)]
    [InlineData("-1.5", -1.5)]
    [InlineData("0",    0.0)]
    [InlineData("100",  100.0)]
    public void CoerceFloat_ValidValues_ReturnsExpected(string input, double expected)
    {
        var result = TypeCoercer.CoerceFloat(input);
        Assert.Equal(expected, result, precision: 10);
    }

    [Fact]
    public void CoerceFloat_InvalidValue_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => TypeCoercer.CoerceFloat("not_a_number"));
    }

    // ---- Array coercion -----------------------------------------------------

    [Fact]
    public void CoerceArray_CommaSeparated_ReturnsTrimmedElements()
    {
        var result = TypeCoercer.CoerceArray("host1, host2 , host3");
        Assert.Equal(["host1", "host2", "host3"], result);
    }

    [Fact]
    public void CoerceArray_SingleElement_ReturnsOneElementArray()
    {
        var result = TypeCoercer.CoerceArray("onlyone");
        Assert.Single(result);
        Assert.Equal("onlyone", result[0]);
    }

    // ---- AutoCoerce heuristic -----------------------------------------------

    [Fact]
    public void AutoCoerce_BooleanWord_ReturnsBool()
    {
        Assert.Equal(true,  TypeCoercer.AutoCoerce("true"));
        Assert.Equal(false, TypeCoercer.AutoCoerce("false"));
        Assert.Equal(true,  TypeCoercer.AutoCoerce("yes"));
        Assert.Equal(false, TypeCoercer.AutoCoerce("no"));
    }

    [Fact]
    public void AutoCoerce_IntegerString_ReturnsInt()
    {
        Assert.Equal(42,  TypeCoercer.AutoCoerce("42"));
        Assert.Equal(-5,  TypeCoercer.AutoCoerce("-5"));
    }

    [Fact]
    public void AutoCoerce_FloatString_ReturnsDouble()
    {
        var result = TypeCoercer.AutoCoerce("3.14");
        Assert.IsType<double>(result);
        Assert.Equal(3.14, (double)result, precision: 10);
    }

    [Fact]
    public void AutoCoerce_PlainString_ReturnsString()
    {
        Assert.Equal("hello", TypeCoercer.AutoCoerce("hello"));
    }

    // ---- Dispatch via Coerce ------------------------------------------------

    [Fact]
    public void Coerce_StringType_ReturnsRawString()
    {
        var result = TypeCoercer.Coerce("anything", IniValueType.String);
        Assert.Equal("anything", result);
    }

    [Fact]
    public void Coerce_BooleanType_ReturnsBool()
    {
        Assert.Equal(true, TypeCoercer.Coerce("yes", IniValueType.Boolean));
    }
}
