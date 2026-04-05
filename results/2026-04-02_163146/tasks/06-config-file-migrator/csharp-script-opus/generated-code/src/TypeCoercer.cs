using System.Globalization;

namespace ConfigMigrator;

/// <summary>
/// Coerces string values from INI files to appropriate .NET types (bool, int, double, string).
/// Used when generating typed output formats like JSON.
/// </summary>
public static class TypeCoercer
{
    /// <summary>
    /// Attempts to coerce a string value to the most specific type possible.
    /// Priority: boolean > integer > float > string.
    /// </summary>
    public static object Coerce(string value)
    {
        // Try boolean first
        if (TryParseBoolean(value, out var boolVal))
            return boolVal;

        // Try integer (long for large numbers)
        if (long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var longVal))
        {
            // Return int if it fits, otherwise long
            if (longVal >= int.MinValue && longVal <= int.MaxValue)
                return (int)longVal;
            return longVal;
        }

        // Try floating point
        if (double.TryParse(value, NumberStyles.Float | NumberStyles.AllowThousands,
            CultureInfo.InvariantCulture, out var doubleVal))
        {
            // Only coerce if it contains a decimal point or scientific notation
            // to avoid converting "42" to 42.0
            if (value.Contains('.') || value.Contains('e') || value.Contains('E'))
                return doubleVal;
        }

        // Default: return as string
        return value;
    }

    /// <summary>
    /// Coerces a value using a specific schema type hint.
    /// </summary>
    public static object CoerceWithType(string value, SchemaValueType type)
    {
        return type switch
        {
            SchemaValueType.Boolean => TryParseBoolean(value, out var b) ? b : value,
            SchemaValueType.Integer => long.TryParse(value, NumberStyles.Integer,
                CultureInfo.InvariantCulture, out var l)
                ? (l >= int.MinValue && l <= int.MaxValue ? (int)l : l)
                : (object)value,
            SchemaValueType.Float => double.TryParse(value, NumberStyles.Float,
                CultureInfo.InvariantCulture, out var d) ? d : value,
            SchemaValueType.String => value,
            _ => value
        };
    }

    /// <summary>
    /// Parses common boolean representations: true/false, yes/no, on/off, 1/0.
    /// </summary>
    private static bool TryParseBoolean(string value, out bool result)
    {
        switch (value.ToLowerInvariant())
        {
            case "true":
            case "yes":
            case "on":
            case "1":
                result = true;
                return true;
            case "false":
            case "no":
            case "off":
            case "0":
                result = false;
                return true;
            default:
                result = false;
                return false;
        }
    }
}
