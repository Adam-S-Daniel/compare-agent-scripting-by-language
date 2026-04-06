// Integration tests: exercise the full pipeline from manifest parsing
// through license checking to report generation, using mock data.

using LicenseChecker.Lib;
using Xunit;

namespace LicenseChecker.Tests;

public class IntegrationTests
{
    // Build a config and mock lookup that mirrors the demo fixtures
    private static (LicenseConfig config, MockLicenseLookup lookup) BuildDemoSetup(bool npm = true)
    {
        var config = new LicenseConfig(
            AllowList: ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"],
            DenyList:  ["GPL-2.0", "GPL-3.0", "AGPL-3.0"]
        );

        var npmLicenses = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["express"]    = "MIT",
            ["lodash"]     = "MIT",
            ["axios"]      = "MIT",
            ["gpl-module"] = "GPL-3.0",
            ["jest"]       = "MIT",
            ["typescript"] = "Apache-2.0",
            ["eslint"]     = "MIT",
        };

        var pypiLicenses = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["requests"] = "Apache-2.0",
            ["flask"]    = "BSD-3-Clause",
            ["numpy"]    = "BSD-3-Clause",
            ["pytest"]   = "MIT",
            ["click"]    = "BSD-3-Clause",
            ["django"]   = "BSD-3-Clause",
        };

        var lookup = new MockLicenseLookup(npm ? npmLicenses : pypiLicenses);
        return (config, lookup);
    }

    // Test 1: Full pipeline with a package.json — denied package makes report non-compliant
    [Fact]
    public async Task FullPipeline_PackageJson_DetectsGplModule()
    {
        var json = """
        {
            "name": "my-app",
            "dependencies": {
                "express": "^4.18.2",
                "gpl-module": "^1.0.0"
            },
            "devDependencies": {
                "jest": "^29.0.0"
            }
        }
        """;

        var parser = new ManifestParser();
        var deps   = parser.ParsePackageJson(json);

        var (config, lookup) = BuildDemoSetup(npm: true);
        var checker  = new ComplianceChecker(config, lookup);
        var results  = await checker.CheckAllAsync(deps);
        var report   = new ComplianceReport("package.json", DateTime.UtcNow, results);
        var formatter = new ReportFormatter();

        // Verify report integrity
        Assert.Equal(3, report.Results.Count);
        Assert.False(report.IsCompliant);
        Assert.Equal(1, report.DeniedCount);
        Assert.Equal(2, report.ApprovedCount);

        // Verify text output
        var text = formatter.FormatText(report);
        Assert.Contains("gpl-module", text);
        Assert.Contains("GPL-3.0",   text);
        Assert.Contains("DENIED",    text);
        Assert.Contains("COMPLIANT: NO", text);

        // Verify JSON output is valid
        var jsonOut = formatter.FormatJson(report);
        using var doc = System.Text.Json.JsonDocument.Parse(jsonOut);
        Assert.False(doc.RootElement.GetProperty("isCompliant").GetBoolean());
    }

    // Test 2: Full pipeline with requirements.txt — all packages approved
    [Fact]
    public async Task FullPipeline_RequirementsTxt_AllApproved()
    {
        var content = """
        requests==2.28.1
        flask>=2.0.0
        numpy~=1.24.0
        pytest==7.2.0
        """;

        var parser = new ManifestParser();
        var deps   = parser.ParseRequirementsTxt(content);

        var (config, lookup) = BuildDemoSetup(npm: false);
        var checker  = new ComplianceChecker(config, lookup);
        var results  = await checker.CheckAllAsync(deps);
        var report   = new ComplianceReport("requirements.txt", DateTime.UtcNow, results);

        Assert.Equal(4, report.Results.Count);
        Assert.True(report.IsCompliant);
        Assert.Equal(0, report.DeniedCount);
    }

    // Test 3: DetectAndParse with requirements.txt filename
    [Fact]
    public void DetectAndParse_RequirementsTxt_Works()
    {
        var content = """
        requests==2.28.1
        flask>=2.0.0
        """;

        var parser = new ManifestParser();
        var deps   = parser.DetectAndParse(content, "requirements.txt");

        Assert.Equal(2, deps.Count);
        Assert.Equal("requests", deps[0].Name);
    }

    // Test 4: Unsupported manifest format throws descriptive error
    [Fact]
    public void DetectAndParse_UnsupportedFormat_ThrowsDescriptiveError()
    {
        var parser = new ManifestParser();

        var ex = Assert.Throws<NotSupportedException>(
            () => parser.DetectAndParse("content", "composer.json")
        );

        Assert.Contains("composer.json", ex.Message);
        Assert.Contains("Unsupported", ex.Message);
    }

    // Test 5: JSON report round-trips correctly
    [Fact]
    public async Task JsonReport_RoundTrips_AllFields()
    {
        var dep  = new Dependency("lodash", "^4.17.21");
        var (config, lookup) = BuildDemoSetup(npm: true);
        var checker = new ComplianceChecker(config, lookup);
        var results = await checker.CheckAllAsync([dep]);
        var report  = new ComplianceReport("package.json", new DateTime(2026, 1, 15, 0, 0, 0, DateTimeKind.Utc), results);

        var json = new ReportFormatter().FormatJson(report);
        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("package.json", root.GetProperty("manifestFile").GetString());
        Assert.Equal(1, root.GetProperty("results").GetArrayLength());
        Assert.Equal(1, root.GetProperty("approvedCount").GetInt32());
        Assert.Equal(0, root.GetProperty("deniedCount").GetInt32());
        Assert.True(root.GetProperty("isCompliant").GetBoolean());

        var firstResult = root.GetProperty("results")[0];
        Assert.Equal("lodash",   firstResult.GetProperty("name").GetString());
        Assert.Equal("MIT",      firstResult.GetProperty("license").GetString());
        Assert.Equal("Approved", firstResult.GetProperty("status").GetString());
    }
}
