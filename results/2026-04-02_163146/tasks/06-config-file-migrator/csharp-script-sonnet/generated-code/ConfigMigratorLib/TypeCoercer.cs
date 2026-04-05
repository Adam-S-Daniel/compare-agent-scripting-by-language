// TypeCoercer.cs
// GREEN phase: implements type coercion used by both validation and output conversion.
//
// Supported coercions:
//   Boolean : "true"/"false", "yes"/"no", "1"/"0", "on"/"off", "enabled"/"disabled"
//   Integer : any valid int string (including negative)
//   Float   : any valid double string (invariant culture)
//   Array   : comma-separated list → string[]
//   String  : identity (no coercion)
//
// AutoCoerce tries Boolean → Integer → Float → String in that order.

namespace ConfigMigratorLib;

/// <summary>
/// Provides type coercion from raw INI string values to typed .NET objects.
/// All methods throw <see cref="FormatException"/> on bad input so callers can
/// produce meaningful validation errors.
/// </summary>
public static class TypeCoercer
{
    private static readonly HashSet<string> TrueValues =
        new HashSet<string>(
            new[] { "true", "yes", "1", "on", "enabled" },
            StringComparer.OrdinalIgnoreCase);

    private static readonly HashSet<string> FalseValues =
        new HashSet<string>(
            new[] { "false", "no", "0", "off", "disabled" },
            StringComparer.OrdinalIgnoreCase);

    /// <summary>Coerce a raw string to the requested <see cref="IniValueType"/>.</summary>
    public static object Coerce(string rawValue, IniValueType targetType) =>
        targetType switch
        {
            IniValueType.Boolean => CoerceBoolean(rawValue),
            IniValueType.Integer => CoerceInteger(rawValue),
            IniValueType.Float   => CoerceFloat(rawValue),
            IniValueType.Array   => CoerceArray(rawValue),
            _                    => rawValue  // IniValueType.String — identity
        };

    /// <summary>
    /// Parse "true/false/yes/no/1/0/on/off/enabled/disabled" (case-insensitive) to bool.
    /// </summary>
    public static bool CoerceBoolean(string value)
    {
        if (TrueValues.Contains(value))  return true;
        if (FalseValues.Contains(value)) return false;
        throw new FormatException(
            $"Cannot coerce '{value}' to Boolean. " +
            "Expected: true/false, yes/no, 1/0, on/off, enabled/disabled.");
    }

    /// <summary>Parse any valid integer string (e.g. "42", "-17") to int.</summary>
    public static int CoerceInteger(string value)
    {
        if (int.TryParse(value, out var result)) return result;
        throw new FormatException($"Cannot coerce '{value}' to Integer.");
    }

    /// <summary>Parse any valid floating-point string (invariant culture) to double.</summary>
    public static double CoerceFloat(string value)
    {
        if (double.TryParse(value,
                System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture,
                out var result))
            return result;

        throw new FormatException($"Cannot coerce '{value}' to Float.");
    }

    /// <summary>Split a comma-separated list, trimming each element.</summary>
    public static string[] CoerceArray(string value) =>
        value.Split(',').Select(v => v.Trim()).ToArray();

    /// <summary>
    /// Heuristically coerce a raw string to the most specific applicable type:
    /// Boolean → Integer → Float → String.
    /// Used when no schema type is provided (auto-detect mode).
    /// </summary>
    public static object AutoCoerce(string value)
    {
        // Check boolean before numbers so "1"/"0" stay as booleans only
        // when they look like explicit boolean tokens.
        if (TrueValues.Contains(value) && !int.TryParse(value, out _))
            return true;
        if (FalseValues.Contains(value) && !int.TryParse(value, out _))
            return false;

        if (int.TryParse(value, out var intVal))
            return intVal;

        if (double.TryParse(value,
                System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture,
                out var floatVal))
            return floatVal;

        // For explicit boolean words that are not numeric
        if (TrueValues.Contains(value))  return true;
        if (FalseValues.Contains(value)) return false;

        return value;
    }
}
