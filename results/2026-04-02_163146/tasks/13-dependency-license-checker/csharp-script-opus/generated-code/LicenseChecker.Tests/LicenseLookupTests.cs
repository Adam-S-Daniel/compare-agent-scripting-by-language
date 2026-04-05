// TDD Round 2: Tests for the license lookup service (mocked)
// The license lookup is abstracted behind an interface so we can inject a mock.

using Xunit;
using LicenseChecker;

namespace LicenseChecker.Tests;

public class LicenseLookupTests
{
    // RED: Mock license provider returns known licenses
    [Fact]
    public void MockLicenseProvider_ReturnsConfiguredLicense()
    {
        var provider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["express"] = "MIT",
            ["lodash"] = "MIT",
            ["react"] = "MIT"
        });

        Assert.Equal("MIT", provider.GetLicense("express", "^4.18.2"));
        Assert.Equal("MIT", provider.GetLicense("lodash", "~4.17.21"));
    }

    // RED: Mock returns null for unknown packages
    [Fact]
    public void MockLicenseProvider_UnknownPackage_ReturnsNull()
    {
        var provider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["express"] = "MIT"
        });

        Assert.Null(provider.GetLicense("unknown-pkg", "1.0.0"));
    }

    // RED: Can look up multiple dependencies at once
    [Fact]
    public void LookupAll_ReturnsLicenseForEachDep()
    {
        var provider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["express"] = "MIT",
            ["left-pad"] = "WTFPL"
        });

        var deps = new List<Dependency>
        {
            new("express", "^4.18.2"),
            new("left-pad", "1.0.0"),
            new("mystery-pkg", "0.1.0")
        };

        var results = LicenseLookup.LookupAll(deps, provider);

        Assert.Equal(3, results.Count);
        Assert.Equal("MIT", results["express"]);
        Assert.Equal("WTFPL", results["left-pad"]);
        Assert.Null(results["mystery-pkg"]);
    }
}
