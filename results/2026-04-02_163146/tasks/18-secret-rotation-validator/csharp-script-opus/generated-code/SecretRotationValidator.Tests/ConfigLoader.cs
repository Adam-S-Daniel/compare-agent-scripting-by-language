// ConfigLoader: Parses secret configuration from JSON (string or file).
// Provides clear error messages for invalid or missing data.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text.Json;

namespace SecretRotationValidator;

/// <summary>Custom exception for configuration loading errors with clear messages.</summary>
public class ConfigLoadException : Exception
{
    public ConfigLoadException(string message) : base(message) { }
    public ConfigLoadException(string message, Exception inner) : base(message, inner) { }
}

public static class ConfigLoader
{
    /// <summary>
    /// Loads secrets configuration from a JSON file path.
    /// </summary>
    public static List<SecretConfig> LoadFromFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new ConfigLoadException($"Configuration file not found: {filePath}");

        var json = File.ReadAllText(filePath);
        return LoadFromString(json);
    }

    /// <summary>
    /// Loads secrets configuration from a JSON string.
    /// </summary>
    public static List<SecretConfig> LoadFromString(string json)
    {
        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (JsonException ex)
        {
            throw new ConfigLoadException($"Invalid JSON: {ex.Message}", ex);
        }

        if (!doc.RootElement.TryGetProperty("secrets", out var secretsArray))
            throw new ConfigLoadException("Configuration must contain a 'secrets' array.");

        var results = new List<SecretConfig>();

        for (int i = 0; i < secretsArray.GetArrayLength(); i++)
        {
            var element = secretsArray[i];
            results.Add(ParseSecret(element, i));
        }

        return results;
    }

    private static SecretConfig ParseSecret(JsonElement element, int index)
    {
        // Name is required
        if (!element.TryGetProperty("name", out var nameEl) ||
            nameEl.ValueKind != JsonValueKind.String ||
            string.IsNullOrWhiteSpace(nameEl.GetString()))
        {
            throw new ConfigLoadException(
                $"Secret at index {index}: 'name' is required and must be a non-empty string.");
        }
        var name = nameEl.GetString()!;

        // LastRotated is required and must be a valid date
        if (!element.TryGetProperty("lastRotated", out var dateEl) ||
            dateEl.ValueKind != JsonValueKind.String)
        {
            throw new ConfigLoadException(
                $"Secret '{name}': 'lastRotated' is required and must be a date string.");
        }

        if (!DateTime.TryParseExact(dateEl.GetString(), "yyyy-MM-dd",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var lastRotated))
        {
            throw new ConfigLoadException(
                $"Secret '{name}': 'lastRotated' value '{dateEl.GetString()}' is not a valid date (expected yyyy-MM-dd).");
        }

        // RotationPolicyDays is required and must be positive
        if (!element.TryGetProperty("rotationPolicyDays", out var policyEl) ||
            policyEl.ValueKind != JsonValueKind.Number)
        {
            throw new ConfigLoadException(
                $"Secret '{name}': 'rotationPolicyDays' is required and must be a number.");
        }
        var policyDays = policyEl.GetInt32();
        if (policyDays <= 0)
        {
            throw new ConfigLoadException(
                $"Secret '{name}': 'rotationPolicyDays' must be a positive number, got {policyDays}.");
        }

        // RequiredByServices defaults to empty list if not provided
        var services = new List<string>();
        if (element.TryGetProperty("requiredByServices", out var servicesEl) &&
            servicesEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var svc in servicesEl.EnumerateArray())
            {
                if (svc.ValueKind == JsonValueKind.String)
                    services.Add(svc.GetString()!);
            }
        }

        return new SecretConfig(name, lastRotated, policyDays, services);
    }
}
