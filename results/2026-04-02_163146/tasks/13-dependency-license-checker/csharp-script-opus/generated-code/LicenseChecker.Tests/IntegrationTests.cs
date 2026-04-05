// TDD Round 5: Integration tests for the full pipeline
// Parse manifest -> lookup licenses -> check compliance -> generate report

using Xunit;
using LicenseChecker;

namespace LicenseChecker.Tests;

public class IntegrationTests
{
    // RED: Full pipeline with package.json
    [Fact]
    public void FullPipeline_PackageJson_ProducesCorrectReport()
    {
        // Arrange: a package.json with mixed license statuses
        var packageJson = """
        {
            "name": "test-app",
            "version": "1.0.0",
            "dependencies": {
                "express": "^4.18.2",
                "lodash": "~4.17.21",
                "gpl-library": "^1.0.0"
            },
            "devDependencies": {
                "jest": "^29.0.0"
            }
        }
        """;

        var licenseProvider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["express"] = "MIT",
            ["lodash"] = "MIT",
            ["gpl-library"] = "GPL-3.0",
            ["jest"] = "MIT"
        });

        var config = new ComplianceConfig(
            AllowedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MIT", "Apache-2.0" },
            DeniedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "GPL-3.0", "AGPL-3.0" }
        );

        // Act: run the full pipeline
        var deps = ManifestParser.Parse("package.json", packageJson);
        var licenses = LicenseLookup.LookupAll(deps, licenseProvider);
        var complianceResults = ComplianceChecker.CheckAll(licenses, config);
        var report = ReportGenerator.Generate(complianceResults);

        // Assert
        Assert.Equal(4, report.Summary.Total);
        Assert.Equal(3, report.Summary.Approved);  // express, lodash, jest
        Assert.Equal(1, report.Summary.Denied);      // gpl-library
        Assert.Equal(0, report.Summary.Unknown);
        Assert.False(report.Summary.Pass);            // denied dep means fail
    }

    // RED: Full pipeline with requirements.txt
    [Fact]
    public void FullPipeline_RequirementsTxt_ProducesCorrectReport()
    {
        var requirements = """
        flask==2.3.0
        requests>=2.28.0
        # Unknown package with no license info
        mystery-lib==0.1.0
        """;

        var licenseProvider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["flask"] = "BSD-3-Clause",
            ["requests"] = "Apache-2.0"
            // mystery-lib intentionally not in the provider
        });

        var config = new ComplianceConfig(
            AllowedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MIT", "Apache-2.0", "BSD-3-Clause" },
            DeniedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "GPL-3.0" }
        );

        var deps = ManifestParser.Parse("requirements.txt", requirements);
        var licenses = LicenseLookup.LookupAll(deps, licenseProvider);
        var complianceResults = ComplianceChecker.CheckAll(licenses, config);
        var report = ReportGenerator.Generate(complianceResults);

        Assert.Equal(3, report.Summary.Total);
        Assert.Equal(2, report.Summary.Approved);   // flask, requests
        Assert.Equal(0, report.Summary.Denied);
        Assert.Equal(1, report.Summary.Unknown);      // mystery-lib
        Assert.True(report.Summary.Pass);             // no denied = pass
    }

    // RED: Pipeline generates valid JSON output
    [Fact]
    public void FullPipeline_GeneratesValidJsonReport()
    {
        var packageJson = """
        {
            "dependencies": { "express": "^4.0.0" }
        }
        """;

        var provider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["express"] = "MIT"
        });

        var config = new ComplianceConfig(
            AllowedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MIT" },
            DeniedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        );

        var deps = ManifestParser.Parse("package.json", packageJson);
        var licenses = LicenseLookup.LookupAll(deps, provider);
        var complianceResults = ComplianceChecker.CheckAll(licenses, config);
        var report = ReportGenerator.Generate(complianceResults);
        var json = ReportGenerator.ToJson(report);

        // Verify JSON is valid by parsing it
        var parsed = System.Text.Json.JsonDocument.Parse(json);
        Assert.NotNull(parsed);
    }

    // RED: Pipeline generates valid text report
    [Fact]
    public void FullPipeline_GeneratesTextReport()
    {
        var packageJson = """
        {
            "dependencies": {
                "express": "^4.0.0",
                "bad-lib": "1.0.0"
            }
        }
        """;

        var provider = new MockLicenseProvider(new Dictionary<string, string>
        {
            ["express"] = "MIT",
            ["bad-lib"] = "AGPL-3.0"
        });

        var config = new ComplianceConfig(
            AllowedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "MIT" },
            DeniedLicenses: new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "AGPL-3.0" }
        );

        var deps = ManifestParser.Parse("package.json", packageJson);
        var licenses = LicenseLookup.LookupAll(deps, provider);
        var complianceResults = ComplianceChecker.CheckAll(licenses, config);
        var report = ReportGenerator.Generate(complianceResults);
        var text = ReportGenerator.ToText(report);

        Assert.Contains("express", text);
        Assert.Contains("bad-lib", text);
        Assert.Contains("FAIL", text.ToUpper());
    }
}
