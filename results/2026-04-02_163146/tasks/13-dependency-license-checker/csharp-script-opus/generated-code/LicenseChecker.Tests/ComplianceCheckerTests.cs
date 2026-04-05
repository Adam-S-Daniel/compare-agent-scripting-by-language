// TDD Round 3: Tests for the compliance checker (allow-list / deny-list logic)
// The checker takes license lookup results and a config, then classifies each dependency.

using Xunit;
using LicenseChecker;

namespace LicenseChecker.Tests;

public class ComplianceCheckerTests
{
    // Helper to create a standard config for tests
    private static ComplianceConfig TestConfig() => new(
        AllowedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MIT", "Apache-2.0", "BSD-3-Clause" },
        DeniedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "GPL-3.0", "AGPL-3.0" }
    );

    // RED: Approved license is classified as Approved
    [Fact]
    public void Check_ApprovedLicense_ReturnsApproved()
    {
        var config = TestConfig();
        var result = ComplianceChecker.ClassifyLicense("MIT", config);

        Assert.Equal(LicenseStatus.Approved, result);
    }

    // RED: Denied license is classified as Denied
    [Fact]
    public void Check_DeniedLicense_ReturnsDenied()
    {
        var config = TestConfig();
        var result = ComplianceChecker.ClassifyLicense("GPL-3.0", config);

        Assert.Equal(LicenseStatus.Denied, result);
    }

    // RED: Unknown license (not in either list) is classified as Unknown
    [Fact]
    public void Check_UnknownLicense_ReturnsUnknown()
    {
        var config = TestConfig();
        var result = ComplianceChecker.ClassifyLicense("WTFPL", config);

        Assert.Equal(LicenseStatus.Unknown, result);
    }

    // RED: Null license (lookup failed) is classified as Unknown
    [Fact]
    public void Check_NullLicense_ReturnsUnknown()
    {
        var config = TestConfig();
        var result = ComplianceChecker.ClassifyLicense(null, config);

        Assert.Equal(LicenseStatus.Unknown, result);
    }

    // RED: License matching is case-insensitive
    [Fact]
    public void Check_CaseInsensitive_Matching()
    {
        var config = TestConfig();

        Assert.Equal(LicenseStatus.Approved, ComplianceChecker.ClassifyLicense("mit", config));
        Assert.Equal(LicenseStatus.Approved, ComplianceChecker.ClassifyLicense("MIT", config));
        Assert.Equal(LicenseStatus.Denied, ComplianceChecker.ClassifyLicense("gpl-3.0", config));
    }

    // RED: Deny-list takes precedence if a license appears in both lists
    [Fact]
    public void Check_DenyTakesPrecedence_OverAllow()
    {
        var config = new ComplianceConfig(
            AllowedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MIT", "GPL-3.0" },
            DeniedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "GPL-3.0" }
        );

        // Deny list should win when a license is in both
        Assert.Equal(LicenseStatus.Denied, ComplianceChecker.ClassifyLicense("GPL-3.0", config));
    }

    // RED: Full end-to-end check of multiple dependencies
    [Fact]
    public void CheckAll_ReturnsCorrectStatusForEachDep()
    {
        var config = TestConfig();
        var licenseMap = new Dictionary<string, string?>
        {
            ["express"] = "MIT",
            ["gpl-lib"] = "GPL-3.0",
            ["weird-lib"] = "WTFPL",
            ["no-license"] = null
        };

        var results = ComplianceChecker.CheckAll(licenseMap, config);

        Assert.Equal(4, results.Count);
        Assert.Equal(LicenseStatus.Approved, results.First(r => r.DependencyName == "express").Status);
        Assert.Equal(LicenseStatus.Denied, results.First(r => r.DependencyName == "gpl-lib").Status);
        Assert.Equal(LicenseStatus.Unknown, results.First(r => r.DependencyName == "weird-lib").Status);
        Assert.Equal(LicenseStatus.Unknown, results.First(r => r.DependencyName == "no-license").Status);
    }
}
