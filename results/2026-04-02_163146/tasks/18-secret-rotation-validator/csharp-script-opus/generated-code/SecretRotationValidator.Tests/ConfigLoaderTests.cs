// TDD Cycle 4 - RED: Test configuration loading from JSON with error handling.
// Tests cover valid configs, missing fields, invalid dates, and empty configs.

using System;
using System.Collections.Generic;
using System.IO;
using SecretRotationValidator;
using Xunit;

namespace SecretRotationValidator.Tests;

public class ConfigLoaderTests
{
    [Fact]
    public void Load_ValidJson_ReturnsSecrets()
    {
        var json = """
        {
            "secrets": [
                {
                    "name": "db-password",
                    "lastRotated": "2026-01-01",
                    "rotationPolicyDays": 90,
                    "requiredByServices": ["api-server", "worker"]
                },
                {
                    "name": "api-key",
                    "lastRotated": "2026-03-15",
                    "rotationPolicyDays": 30,
                    "requiredByServices": ["frontend"]
                }
            ]
        }
        """;

        var secrets = ConfigLoader.LoadFromString(json);

        Assert.Equal(2, secrets.Count);
        Assert.Equal("db-password", secrets[0].Name);
        Assert.Equal(new DateTime(2026, 1, 1), secrets[0].LastRotated);
        Assert.Equal(90, secrets[0].RotationPolicyDays);
        Assert.Equal(2, secrets[0].RequiredByServices.Count);
    }

    [Fact]
    public void Load_EmptySecretsArray_ReturnsEmptyList()
    {
        var json = """{ "secrets": [] }""";
        var secrets = ConfigLoader.LoadFromString(json);
        Assert.Empty(secrets);
    }

    [Fact]
    public void Load_InvalidJson_ThrowsWithMessage()
    {
        var json = "not valid json {{{";
        var ex = Assert.Throws<ConfigLoadException>(() => ConfigLoader.LoadFromString(json));
        Assert.Contains("Invalid JSON", ex.Message);
    }

    [Fact]
    public void Load_MissingSecretsKey_ThrowsWithMessage()
    {
        var json = """{ "other": [] }""";
        var ex = Assert.Throws<ConfigLoadException>(() => ConfigLoader.LoadFromString(json));
        Assert.Contains("secrets", ex.Message);
    }

    [Fact]
    public void Load_MissingName_ThrowsWithMessage()
    {
        var json = """
        {
            "secrets": [
                {
                    "lastRotated": "2026-01-01",
                    "rotationPolicyDays": 90,
                    "requiredByServices": ["api"]
                }
            ]
        }
        """;

        var ex = Assert.Throws<ConfigLoadException>(() => ConfigLoader.LoadFromString(json));
        Assert.Contains("name", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Load_InvalidDate_ThrowsWithMessage()
    {
        var json = """
        {
            "secrets": [
                {
                    "name": "test",
                    "lastRotated": "not-a-date",
                    "rotationPolicyDays": 90,
                    "requiredByServices": ["api"]
                }
            ]
        }
        """;

        var ex = Assert.Throws<ConfigLoadException>(() => ConfigLoader.LoadFromString(json));
        Assert.Contains("test", ex.Message);
    }

    [Fact]
    public void Load_NegativeRotationDays_ThrowsWithMessage()
    {
        var json = """
        {
            "secrets": [
                {
                    "name": "test",
                    "lastRotated": "2026-01-01",
                    "rotationPolicyDays": -5,
                    "requiredByServices": ["api"]
                }
            ]
        }
        """;

        var ex = Assert.Throws<ConfigLoadException>(() => ConfigLoader.LoadFromString(json));
        Assert.Contains("test", ex.Message);
    }

    [Fact]
    public void LoadFromFile_ValidFile_ReturnsSecrets()
    {
        var tmpFile = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tmpFile, """
            {
                "secrets": [
                    {
                        "name": "file-test",
                        "lastRotated": "2026-02-01",
                        "rotationPolicyDays": 60,
                        "requiredByServices": ["svc"]
                    }
                ]
            }
            """);

            var secrets = ConfigLoader.LoadFromFile(tmpFile);
            Assert.Single(secrets);
            Assert.Equal("file-test", secrets[0].Name);
        }
        finally
        {
            File.Delete(tmpFile);
        }
    }

    [Fact]
    public void LoadFromFile_NonexistentFile_ThrowsWithMessage()
    {
        var ex = Assert.Throws<ConfigLoadException>(() =>
            ConfigLoader.LoadFromFile("/tmp/does-not-exist-12345.json"));
        Assert.Contains("not found", ex.Message, StringComparison.OrdinalIgnoreCase);
    }
}
