// RED PHASE: Tests for the compliance checker — the heart of the tool.
// Verifies that allow/deny lists are applied correctly and that each
// dependency receives the right LicenseStatus.

using LicenseChecker.Lib;
using Xunit;

namespace LicenseChecker.Tests;

public class ComplianceCheckerTests
{
    private static LicenseConfig DefaultConfig() => new LicenseConfig(
        AllowList: ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
        DenyList:  ["GPL-3.0", "AGPL-3.0", "GPL-2.0"]
    );

    private static MockLicenseLookup BuildLookup(params (string pkg, string license)[] entries)
    {
        var dict = entries.ToDictionary(e => e.pkg, e => e.license);
        return new MockLicenseLookup(dict);
    }

    // Test 1: Package with allowed license → Approved
    [Fact]
    public async Task CheckAsync_ApprovedLicense_ReturnsApproved()
    {
        var checker = new ComplianceChecker(DefaultConfig(), BuildLookup(("express", "MIT")));
        var dep = new Dependency("express", "^4.18.2");

        var result = await checker.CheckAsync(dep);

        Assert.Equal(LicenseStatus.Approved, result.Status);
        Assert.Equal("MIT", result.License);
    }

    // Test 2: Package with denied license → Denied
    [Fact]
    public async Task CheckAsync_DeniedLicense_ReturnsDenied()
    {
        var checker = new ComplianceChecker(DefaultConfig(), BuildLookup(("gpl-lib", "GPL-3.0")));
        var dep = new Dependency("gpl-lib", "1.0.0");

        var result = await checker.CheckAsync(dep);

        Assert.Equal(LicenseStatus.Denied, result.Status);
        Assert.Equal("GPL-3.0", result.License);
    }

    // Test 3: Package whose license is not on either list → Unknown
    [Fact]
    public async Task CheckAsync_UnlistedLicense_ReturnsUnknown()
    {
        var checker = new ComplianceChecker(DefaultConfig(), BuildLookup(("weird-pkg", "WTFPL")));
        var dep = new Dependency("weird-pkg", "2.0.0");

        var result = await checker.CheckAsync(dep);

        Assert.Equal(LicenseStatus.Unknown, result.Status);
    }

    // Test 4: Package with no license info at all → Unknown
    [Fact]
    public async Task CheckAsync_NoLicenseFound_ReturnsUnknown()
    {
        var checker = new ComplianceChecker(DefaultConfig(), BuildLookup(/* empty */));
        var dep = new Dependency("mystery-pkg", "3.0.0");

        var result = await checker.CheckAsync(dep);

        Assert.Equal(LicenseStatus.Unknown, result.Status);
        Assert.Null(result.License);
    }

    // Test 5: Check multiple dependencies at once
    [Fact]
    public async Task CheckAllAsync_MixedLicenses_ReturnsCorrectStatuses()
    {
        var lookup = BuildLookup(
            ("express",  "MIT"),
            ("gpl-lib",  "GPL-3.0"),
            ("unknown-lib", "WTFPL")
        );
        var checker = new ComplianceChecker(DefaultConfig(), lookup);
        var deps = new[]
        {
            new Dependency("express",  "^4.18.2"),
            new Dependency("gpl-lib",  "1.0.0"),
            new Dependency("unknown-lib", "2.0.0"),
            new Dependency("not-found", "1.0.0")
        };

        var results = await checker.CheckAllAsync(deps);

        Assert.Equal(4, results.Count);
        Assert.Equal(LicenseStatus.Approved, results.First(r => r.Name == "express").Status);
        Assert.Equal(LicenseStatus.Denied,   results.First(r => r.Name == "gpl-lib").Status);
        Assert.Equal(LicenseStatus.Unknown,  results.First(r => r.Name == "unknown-lib").Status);
        Assert.Equal(LicenseStatus.Unknown,  results.First(r => r.Name == "not-found").Status);
    }

    // Test 6: License comparison is case-insensitive
    [Fact]
    public async Task CheckAsync_CaseInsensitiveLicenseMatch_Approved()
    {
        var checker = new ComplianceChecker(DefaultConfig(), BuildLookup(("pkg", "mit")));
        var dep = new Dependency("pkg", "1.0.0");

        var result = await checker.CheckAsync(dep);

        Assert.Equal(LicenseStatus.Approved, result.Status);
    }
}
