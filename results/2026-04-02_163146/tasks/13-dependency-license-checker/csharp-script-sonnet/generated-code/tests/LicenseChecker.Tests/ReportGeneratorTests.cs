// RED PHASE: Tests for the report generator.
// The report should list every dependency with its status and
// include a summary with counts and a pass/fail flag.

using LicenseChecker.Lib;
using Xunit;

namespace LicenseChecker.Tests;

public class ReportGeneratorTests
{
    private static IReadOnlyList<LicenseCheckResult> SampleResults() =>
    [
        new("express",  "^4.18.2", "MIT",     LicenseStatus.Approved, "License 'MIT' is on the allow list."),
        new("lodash",   "^4.17.21","MIT",     LicenseStatus.Approved, "License 'MIT' is on the allow list."),
        new("gpl-lib",  "1.0.0",  "GPL-3.0", LicenseStatus.Denied,   "License 'GPL-3.0' is on the deny list."),
        new("mystery",  "2.0.0",  null,      LicenseStatus.Unknown,  "License information could not be found."),
    ];

    // Test 1: ComplianceReport aggregates counts correctly
    [Fact]
    public void ComplianceReport_CountsAreCorrect()
    {
        var report = new ComplianceReport("package.json", DateTime.UtcNow, SampleResults());

        Assert.Equal(2, report.ApprovedCount);
        Assert.Equal(1, report.DeniedCount);
        Assert.Equal(1, report.UnknownCount);
    }

    // Test 2: Report is NOT compliant when there are denied packages
    [Fact]
    public void ComplianceReport_WithDenied_IsNotCompliant()
    {
        var report = new ComplianceReport("package.json", DateTime.UtcNow, SampleResults());

        Assert.False(report.IsCompliant);
    }

    // Test 3: Report IS compliant when no packages are denied
    [Fact]
    public void ComplianceReport_NoDenied_IsCompliant()
    {
        var results = new LicenseCheckResult[]
        {
            new("express", "^4.18.2", "MIT", LicenseStatus.Approved, "OK"),
            new("mystery", "2.0.0",   null,  LicenseStatus.Unknown,  "Not found"),
        };
        var report = new ComplianceReport("package.json", DateTime.UtcNow, results);

        Assert.True(report.IsCompliant);
    }

    // Test 4: Text report contains expected sections
    [Fact]
    public void ReportFormatter_TextReport_ContainsSections()
    {
        var report = new ComplianceReport("package.json", DateTime.UtcNow, SampleResults());
        var formatter = new ReportFormatter();

        var text = formatter.FormatText(report);

        Assert.Contains("APPROVED", text);
        Assert.Contains("DENIED",   text);
        Assert.Contains("UNKNOWN",  text);
        Assert.Contains("express",  text);
        Assert.Contains("gpl-lib",  text);
        Assert.Contains("GPL-3.0",  text);
        Assert.Contains("COMPLIANT: NO", text);
    }

    // Test 5: JSON report is valid and contains all dependencies
    [Fact]
    public void ReportFormatter_JsonReport_IsValidJson()
    {
        var report = new ComplianceReport("package.json", DateTime.UtcNow, SampleResults());
        var formatter = new ReportFormatter();

        var json = formatter.FormatJson(report);

        // Should parse without exception
        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("package.json", root.GetProperty("manifestFile").GetString());
        Assert.Equal(4, root.GetProperty("results").GetArrayLength());
        Assert.Equal(2, root.GetProperty("approvedCount").GetInt32());
        Assert.Equal(1, root.GetProperty("deniedCount").GetInt32());
        Assert.Equal(1, root.GetProperty("unknownCount").GetInt32());
        Assert.False(root.GetProperty("isCompliant").GetBoolean());
    }

    // Test 6: Text report compliant message when no denies
    [Fact]
    public void ReportFormatter_AllApproved_ShowsCompliant()
    {
        var results = new LicenseCheckResult[]
        {
            new("express", "^4.18.2", "MIT", LicenseStatus.Approved, "OK"),
        };
        var report = new ComplianceReport("package.json", DateTime.UtcNow, results);
        var formatter = new ReportFormatter();

        var text = formatter.FormatText(report);

        Assert.Contains("COMPLIANT: YES", text);
    }
}
