// TDD Cycle 3 - RED: Test report formatting in markdown and JSON.
// Each format is tested for structure, correctness, and edge cases.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using SecretRotationValidator;
using Xunit;

namespace SecretRotationValidator.Tests;

public class ReportFormatterTests
{
    private readonly DateTime _today = new DateTime(2026, 4, 6);

    private ValidationReport CreateSampleReport()
    {
        var secrets = new List<SecretConfig>
        {
            new("db-password", _today.AddDays(-100), 90, new List<string> { "api-server", "worker" }),
            new("tls-cert", _today.AddDays(-85), 90, new List<string> { "nginx" }),
            new("api-key", _today.AddDays(-30), 90, new List<string> { "frontend" }),
        };
        return RotationValidator.Validate(secrets, _today, warningDays: 7);
    }

    // --- Markdown tests ---

    [Fact]
    public void FormatMarkdown_ContainsExpiredSection()
    {
        var report = CreateSampleReport();
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("## Expired", md);
        Assert.Contains("db-password", md);
    }

    [Fact]
    public void FormatMarkdown_ContainsWarningSection()
    {
        var report = CreateSampleReport();
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("## Warning", md);
        Assert.Contains("tls-cert", md);
    }

    [Fact]
    public void FormatMarkdown_ContainsOkSection()
    {
        var report = CreateSampleReport();
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("## Ok", md);
        Assert.Contains("api-key", md);
    }

    [Fact]
    public void FormatMarkdown_ContainsTableHeaders()
    {
        var report = CreateSampleReport();
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("| Name |", md);
        Assert.Contains("| Last Rotated |", md);
        Assert.Contains("| Days Until Expiry |", md);
        Assert.Contains("| Required By |", md);
    }

    [Fact]
    public void FormatMarkdown_ShowsServices()
    {
        var report = CreateSampleReport();
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("api-server, worker", md);
    }

    [Fact]
    public void FormatMarkdown_EmptyReport_ShowsNoSecrets()
    {
        var report = new ValidationReport(new(), new(), new());
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("No secrets", md);
    }

    [Fact]
    public void FormatMarkdown_ContainsSummary()
    {
        var report = CreateSampleReport();
        var md = ReportFormatter.FormatMarkdown(report, _today);

        Assert.Contains("# Secret Rotation Report", md);
        Assert.Contains("1 expired", md);
        Assert.Contains("1 warning", md);
        Assert.Contains("1 ok", md);
    }

    // --- JSON tests ---

    [Fact]
    public void FormatJson_IsValidJson()
    {
        var report = CreateSampleReport();
        var json = ReportFormatter.FormatJson(report, _today);

        // Should not throw
        var doc = JsonDocument.Parse(json);
        Assert.NotNull(doc);
    }

    [Fact]
    public void FormatJson_ContainsAllGroups()
    {
        var report = CreateSampleReport();
        var json = ReportFormatter.FormatJson(report, _today);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.TryGetProperty("expired", out var expired));
        Assert.True(root.TryGetProperty("warning", out var warning));
        Assert.True(root.TryGetProperty("ok", out var ok));

        Assert.Equal(1, expired.GetArrayLength());
        Assert.Equal(1, warning.GetArrayLength());
        Assert.Equal(1, ok.GetArrayLength());
    }

    [Fact]
    public void FormatJson_ContainsSecretFields()
    {
        var report = CreateSampleReport();
        var json = ReportFormatter.FormatJson(report, _today);
        var doc = JsonDocument.Parse(json);
        var expiredEntry = doc.RootElement.GetProperty("expired")[0];

        Assert.Equal("db-password", expiredEntry.GetProperty("name").GetString());
        Assert.Equal(90, expiredEntry.GetProperty("rotationPolicyDays").GetInt32());
        Assert.Equal(-10, expiredEntry.GetProperty("daysUntilExpiry").GetInt32());
        Assert.Equal("expired", expiredEntry.GetProperty("urgency").GetString());

        var services = expiredEntry.GetProperty("requiredByServices");
        Assert.Equal(2, services.GetArrayLength());
    }

    [Fact]
    public void FormatJson_ContainsSummary()
    {
        var report = CreateSampleReport();
        var json = ReportFormatter.FormatJson(report, _today);
        var doc = JsonDocument.Parse(json);
        var summary = doc.RootElement.GetProperty("summary");

        Assert.Equal(3, summary.GetProperty("total").GetInt32());
        Assert.Equal(1, summary.GetProperty("expired").GetInt32());
        Assert.Equal(1, summary.GetProperty("warning").GetInt32());
        Assert.Equal(1, summary.GetProperty("ok").GetInt32());
    }

    [Fact]
    public void FormatJson_ContainsReportDate()
    {
        var report = CreateSampleReport();
        var json = ReportFormatter.FormatJson(report, _today);
        var doc = JsonDocument.Parse(json);

        Assert.Equal("2026-04-06", doc.RootElement.GetProperty("reportDate").GetString());
    }

    [Fact]
    public void FormatJson_EmptyReport_HasEmptyArrays()
    {
        var report = new ValidationReport(new(), new(), new());
        var json = ReportFormatter.FormatJson(report, _today);
        var doc = JsonDocument.Parse(json);

        Assert.Equal(0, doc.RootElement.GetProperty("expired").GetArrayLength());
        Assert.Equal(0, doc.RootElement.GetProperty("warning").GetArrayLength());
        Assert.Equal(0, doc.RootElement.GetProperty("ok").GetArrayLength());
    }
}
