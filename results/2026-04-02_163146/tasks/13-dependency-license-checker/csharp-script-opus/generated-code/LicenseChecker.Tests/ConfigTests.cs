// TDD Round 6: Tests for loading compliance configuration from JSON
// Config specifies allowed and denied license lists.

using Xunit;
using LicenseChecker;

namespace LicenseChecker.Tests;

public class ConfigTests
{
    // RED: Parse config from JSON string
    [Fact]
    public void LoadConfig_ParsesAllowAndDenyLists()
    {
        var json = """
        {
            "allowedLicenses": ["MIT", "Apache-2.0", "BSD-3-Clause"],
            "deniedLicenses": ["GPL-3.0", "AGPL-3.0"]
        }
        """;

        var config = ComplianceConfig.FromJson(json);

        Assert.Equal(3, config.AllowedLicenses.Count);
        Assert.Contains("MIT", config.AllowedLicenses);
        Assert.Contains("Apache-2.0", config.AllowedLicenses);
        Assert.Equal(2, config.DeniedLicenses.Count);
        Assert.Contains("GPL-3.0", config.DeniedLicenses);
    }

    // RED: Config with empty lists
    [Fact]
    public void LoadConfig_EmptyLists_Succeeds()
    {
        var json = """
        {
            "allowedLicenses": [],
            "deniedLicenses": []
        }
        """;

        var config = ComplianceConfig.FromJson(json);

        Assert.Empty(config.AllowedLicenses);
        Assert.Empty(config.DeniedLicenses);
    }

    // RED: Invalid config JSON throws
    [Fact]
    public void LoadConfig_InvalidJson_Throws()
    {
        var ex = Assert.Throws<ConfigException>(
            () => ComplianceConfig.FromJson("not json"));

        Assert.Contains("config", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // RED: Missing required fields throws
    [Fact]
    public void LoadConfig_MissingFields_Throws()
    {
        var json = """{ "allowedLicenses": ["MIT"] }""";

        var ex = Assert.Throws<ConfigException>(
            () => ComplianceConfig.FromJson(json));

        Assert.Contains("deniedLicenses", ex.Message, StringComparison.OrdinalIgnoreCase);
    }
}
