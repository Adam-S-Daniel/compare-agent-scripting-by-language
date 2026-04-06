// TDD Cycle 5 - Integration tests: end-to-end from JSON config to formatted output.
// Tests that the full pipeline works correctly together.

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using SecretRotationValidator;
using Xunit;

namespace SecretRotationValidator.Tests;

public class IntegrationTests
{
    private const string SampleConfig = """
    {
        "secrets": [
            {
                "name": "DATABASE_PASSWORD",
                "lastRotated": "2026-01-01",
                "rotationPolicyDays": 90,
                "requiredByServices": ["api-server", "worker"]
            },
            {
                "name": "TLS_CERT",
                "lastRotated": "2026-03-30",
                "rotationPolicyDays": 14,
                "requiredByServices": ["nginx"]
            },
            {
                "name": "MASTER_KEY",
                "lastRotated": "2026-04-01",
                "rotationPolicyDays": 365,
                "requiredByServices": ["vault"]
            }
        ]
    }
    """;

    private readonly DateTime _asOf = new DateTime(2026, 4, 6);

    [Fact]
    public void EndToEnd_LoadValidateFormatMarkdown()
    {
        var secrets = ConfigLoader.LoadFromString(SampleConfig);
        var report = RotationValidator.Validate(secrets, _asOf, warningDays: 7);
        var md = ReportFormatter.FormatMarkdown(report, _asOf);

        // DATABASE_PASSWORD: rotated 2026-01-01, 90-day policy -> expired on 2026-04-01 => expired
        Assert.Contains("DATABASE_PASSWORD", md);
        Assert.Contains("## Expired", md);

        // TLS_CERT: rotated 2026-03-30, 14-day policy -> expires 2026-04-13 => 7 days out => warning
        Assert.Contains("TLS_CERT", md);
        Assert.Contains("## Warning", md);

        // MASTER_KEY: rotated 2026-04-01, 365-day policy -> expires 2027-04-01 => ok
        Assert.Contains("MASTER_KEY", md);
        Assert.Contains("## Ok", md);
    }

    [Fact]
    public void EndToEnd_LoadValidateFormatJson()
    {
        var secrets = ConfigLoader.LoadFromString(SampleConfig);
        var report = RotationValidator.Validate(secrets, _asOf, warningDays: 7);
        var json = ReportFormatter.FormatJson(report, _asOf);

        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal(1, root.GetProperty("expired").GetArrayLength());
        Assert.Equal(1, root.GetProperty("warning").GetArrayLength());
        Assert.Equal(1, root.GetProperty("ok").GetArrayLength());

        Assert.Equal("DATABASE_PASSWORD", root.GetProperty("expired")[0].GetProperty("name").GetString());
        Assert.Equal("TLS_CERT", root.GetProperty("warning")[0].GetProperty("name").GetString());
        Assert.Equal("MASTER_KEY", root.GetProperty("ok")[0].GetProperty("name").GetString());
    }

    [Fact]
    public void EndToEnd_FromFile()
    {
        var tmpFile = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tmpFile, SampleConfig);
            var secrets = ConfigLoader.LoadFromFile(tmpFile);
            var report = RotationValidator.Validate(secrets, _asOf, warningDays: 7);

            Assert.Equal(1, report.Expired.Count);
            Assert.Equal(1, report.Warning.Count);
            Assert.Equal(1, report.Ok.Count);
        }
        finally
        {
            File.Delete(tmpFile);
        }
    }

    [Fact]
    public void EndToEnd_AllExpired()
    {
        var config = """
        {
            "secrets": [
                { "name": "A", "lastRotated": "2020-01-01", "rotationPolicyDays": 1, "requiredByServices": ["svc1"] },
                { "name": "B", "lastRotated": "2020-01-01", "rotationPolicyDays": 1, "requiredByServices": ["svc2"] }
            ]
        }
        """;

        var secrets = ConfigLoader.LoadFromString(config);
        var report = RotationValidator.Validate(secrets, _asOf, warningDays: 7);

        Assert.Equal(2, report.Expired.Count);
        Assert.Empty(report.Warning);
        Assert.Empty(report.Ok);
    }

    [Fact]
    public void EndToEnd_AllOk()
    {
        var config = """
        {
            "secrets": [
                { "name": "A", "lastRotated": "2026-04-05", "rotationPolicyDays": 365, "requiredByServices": ["svc1"] },
                { "name": "B", "lastRotated": "2026-04-06", "rotationPolicyDays": 365, "requiredByServices": ["svc2"] }
            ]
        }
        """;

        var secrets = ConfigLoader.LoadFromString(config);
        var report = RotationValidator.Validate(secrets, _asOf, warningDays: 7);

        Assert.Empty(report.Expired);
        Assert.Empty(report.Warning);
        Assert.Equal(2, report.Ok.Count);
    }

    [Fact]
    public void EndToEnd_LargeWarningWindow_MovesOkToWarning()
    {
        var config = """
        {
            "secrets": [
                { "name": "A", "lastRotated": "2026-04-01", "rotationPolicyDays": 90, "requiredByServices": ["svc"] }
            ]
        }
        """;

        var secrets = ConfigLoader.LoadFromString(config);

        // With 7-day warning: expires in 85 days => ok
        var small = RotationValidator.Validate(secrets, _asOf, warningDays: 7);
        Assert.Single(small.Ok);
        Assert.Empty(small.Warning);

        // With 90-day warning: expires in 85 days => warning
        var large = RotationValidator.Validate(secrets, _asOf, warningDays: 90);
        Assert.Single(large.Warning);
        Assert.Empty(large.Ok);
    }
}
