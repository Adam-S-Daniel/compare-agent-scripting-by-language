// TDD Round 4: Tests for the compliance report generator
// The report generator takes compliance results and produces a structured report.

using Xunit;
using LicenseChecker;

namespace LicenseChecker.Tests;

public class ComplianceReportTests
{
    // RED: Report includes all dependencies
    [Fact]
    public void GenerateReport_IncludesAllDependencies()
    {
        var results = new List<ComplianceResult>
        {
            new("express", "^4.18.2", "MIT", LicenseStatus.Approved),
            new("gpl-lib", "1.0.0", "GPL-3.0", LicenseStatus.Denied),
            new("mystery", "0.1.0", null, LicenseStatus.Unknown)
        };

        var report = ReportGenerator.Generate(results);

        Assert.Equal(3, report.Entries.Count);
        Assert.Equal("express", report.Entries[0].DependencyName);
    }

    // RED: Report has summary counts
    [Fact]
    public void GenerateReport_HasCorrectSummaryCounts()
    {
        var results = new List<ComplianceResult>
        {
            new("a", "1.0", "MIT", LicenseStatus.Approved),
            new("b", "2.0", "MIT", LicenseStatus.Approved),
            new("c", "3.0", "GPL-3.0", LicenseStatus.Denied),
            new("d", "4.0", null, LicenseStatus.Unknown)
        };

        var report = ReportGenerator.Generate(results);

        Assert.Equal(2, report.Summary.Approved);
        Assert.Equal(1, report.Summary.Denied);
        Assert.Equal(1, report.Summary.Unknown);
        Assert.Equal(4, report.Summary.Total);
    }

    // RED: Report can be serialized to JSON
    [Fact]
    public void GenerateReport_SerializesToJson()
    {
        var results = new List<ComplianceResult>
        {
            new("express", "^4.18.2", "MIT", LicenseStatus.Approved)
        };

        var report = ReportGenerator.Generate(results);
        var json = ReportGenerator.ToJson(report);

        Assert.Contains("express", json);
        Assert.Contains("Approved", json);
        Assert.Contains("MIT", json);
    }

    // RED: Report can be rendered as a human-readable text table
    [Fact]
    public void GenerateReport_RendersTextTable()
    {
        var results = new List<ComplianceResult>
        {
            new("express", "^4.18.2", "MIT", LicenseStatus.Approved),
            new("gpl-lib", "1.0.0", "GPL-3.0", LicenseStatus.Denied),
            new("mystery", "0.1.0", null, LicenseStatus.Unknown)
        };

        var report = ReportGenerator.Generate(results);
        var text = ReportGenerator.ToText(report);

        // Should contain a header and each dependency
        Assert.Contains("express", text);
        Assert.Contains("gpl-lib", text);
        Assert.Contains("mystery", text);
        Assert.Contains("APPROVED", text.ToUpper());
        Assert.Contains("DENIED", text.ToUpper());
        Assert.Contains("UNKNOWN", text.ToUpper());
        // Should contain summary
        Assert.Contains("Total: 3", text);
    }

    // RED: Empty results produce valid report with zero counts
    [Fact]
    public void GenerateReport_EmptyResults_ProducesValidReport()
    {
        var results = new List<ComplianceResult>();
        var report = ReportGenerator.Generate(results);

        Assert.Empty(report.Entries);
        Assert.Equal(0, report.Summary.Total);
        Assert.Equal(0, report.Summary.Approved);
        Assert.Equal(0, report.Summary.Denied);
        Assert.Equal(0, report.Summary.Unknown);
    }

    // RED: Report overall pass/fail - fails if any denied
    [Fact]
    public void GenerateReport_WithDenied_FailsOverall()
    {
        var results = new List<ComplianceResult>
        {
            new("a", "1.0", "MIT", LicenseStatus.Approved),
            new("b", "2.0", "GPL-3.0", LicenseStatus.Denied)
        };

        var report = ReportGenerator.Generate(results);

        Assert.False(report.Summary.Pass);
    }

    [Fact]
    public void GenerateReport_AllApproved_PassesOverall()
    {
        var results = new List<ComplianceResult>
        {
            new("a", "1.0", "MIT", LicenseStatus.Approved),
            new("b", "2.0", "Apache-2.0", LicenseStatus.Approved)
        };

        var report = ReportGenerator.Generate(results);

        Assert.True(report.Summary.Pass);
    }

    // Unknown licenses don't cause a fail (they're warnings, not blockers)
    [Fact]
    public void GenerateReport_UnknownOnly_PassesOverall()
    {
        var results = new List<ComplianceResult>
        {
            new("a", "1.0", "WTFPL", LicenseStatus.Unknown)
        };

        var report = ReportGenerator.Generate(results);

        Assert.True(report.Summary.Pass);
    }
}
