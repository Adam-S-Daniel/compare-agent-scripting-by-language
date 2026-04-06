// RED PHASE: Tests for license lookup (including mock/stub)
// These tests verify that we can look up licenses for dependencies
// and that the mock implementation works correctly for testing.

using LicenseChecker.Lib;
using Xunit;

namespace LicenseChecker.Tests;

public class LicenseLookupTests
{
    // Test 1: Mock lookup returns expected license for known package
    [Fact]
    public async Task MockLicenseLookup_KnownPackage_ReturnsLicense()
    {
        var lookup = new MockLicenseLookup(new Dictionary<string, string>
        {
            ["express"] = "MIT",
            ["lodash"]  = "MIT",
            ["gpl-lib"] = "GPL-3.0"
        });

        var license = await lookup.GetLicenseAsync("express", "4.18.2");

        Assert.Equal("MIT", license);
    }

    // Test 2: Mock lookup returns null for unknown package
    [Fact]
    public async Task MockLicenseLookup_UnknownPackage_ReturnsNull()
    {
        var lookup = new MockLicenseLookup(new Dictionary<string, string>
        {
            ["express"] = "MIT"
        });

        var license = await lookup.GetLicenseAsync("unknown-pkg", "1.0.0");

        Assert.Null(license);
    }

    // Test 3: ILicenseLookup interface is implemented by the mock
    [Fact]
    public void MockLicenseLookup_ImplementsInterface()
    {
        ILicenseLookup lookup = new MockLicenseLookup(new Dictionary<string, string>());

        Assert.NotNull(lookup);
    }
}
