// TDD: Tests for ReportFormatter written BEFORE the formatter is implemented.
// These define the expected output contract for markdown and JSON formats.

using System.Text.Json;
using SecretRotation;
using Xunit;

namespace SecretRotation.Tests;

public class ReportFormatterTests
{
    private static readonly DateOnly Today = new DateOnly(2024, 6, 15);

    // Helper: build a RotationResult directly for formatter tests
    private static RotationResult MakeResult(
        string name,
        int daysUntilExpiry,
        RotationStatus status,
        string[] services,
        int policyDays = 90) =>
        new RotationResult(
            Secret: new SecretConfig(name, Today.AddDays(-10), policyDays, services),
            DaysUntilExpiry: daysUntilExpiry,
            Status: status,
            Message: status switch
            {
                RotationStatus.Expired => $"Expired {Math.Abs(daysUntilExpiry)} days ago",
                RotationStatus.Warning => $"Expires in {daysUntilExpiry} days",
                _ => $"OK - expires in {daysUntilExpiry} days"
            });

    // --- Iteration 5: Markdown table format ---

    [Fact]
    public void ToMarkdown_EmptyResults_ReturnsHeaderAndSections()
    {
        var report = new RotationReport(
            GeneratedAt: DateTimeOffset.UtcNow,
            Results: [],
            WarningWindowDays: 30);

        var md = ReportFormatter.ToMarkdown(report);

        // Should contain a header/title
        Assert.Contains("# Secret Rotation Report", md);
        // Should label each urgency group
        Assert.Contains("Expired", md);
        Assert.Contains("Warning", md);
        Assert.Contains("OK", md, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ToMarkdown_ExpiredSecret_AppearsInExpiredSection()
    {
        var results = new[]
        {
            MakeResult("db-password", -10, RotationStatus.Expired, ["payments"])
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var md = ReportFormatter.ToMarkdown(report);

        Assert.Contains("db-password", md);
        // Expired section should appear before the warning section
        var expiredIdx = md.IndexOf("Expired", StringComparison.OrdinalIgnoreCase);
        var nameIdx = md.IndexOf("db-password");
        Assert.True(expiredIdx < nameIdx, "Secret name should appear after the Expired section heading");
    }

    [Fact]
    public void ToMarkdown_AllStatuses_ContainsTableStructure()
    {
        var results = new[]
        {
            MakeResult("exp-key",  -5,  RotationStatus.Expired, ["svc-a"]),
            MakeResult("warn-key",  10, RotationStatus.Warning, ["svc-b"]),
            MakeResult("ok-key",   80,  RotationStatus.Ok,      ["svc-c"]),
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var md = ReportFormatter.ToMarkdown(report);

        // Markdown table uses | delimiters
        Assert.Contains("|", md);
        // All secret names should appear
        Assert.Contains("exp-key", md);
        Assert.Contains("warn-key", md);
        Assert.Contains("ok-key", md);
    }

    [Fact]
    public void ToMarkdown_IncludesRequiredByServices()
    {
        var results = new[]
        {
            MakeResult("shared-key", 5, RotationStatus.Warning, ["auth", "billing", "reports"])
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var md = ReportFormatter.ToMarkdown(report);

        // Required-by services should be visible somewhere in the output
        Assert.Contains("auth", md);
        Assert.Contains("billing", md);
    }

    [Fact]
    public void ToMarkdown_IncludesWarningWindowDays()
    {
        var report = new RotationReport(DateTimeOffset.UtcNow, [], warningWindowDays: 14);

        var md = ReportFormatter.ToMarkdown(report);

        // The configured warning window should be mentioned
        Assert.Contains("14", md);
    }

    // --- Iteration 6: JSON output format ---

    [Fact]
    public void ToJson_ValidJson_CanBeDeserialized()
    {
        var results = new[]
        {
            MakeResult("api-key", -3, RotationStatus.Expired, ["gateway"])
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var json = ReportFormatter.ToJson(report);

        // Must be valid JSON - deserialization should not throw
        var doc = JsonDocument.Parse(json);
        Assert.NotNull(doc);
    }

    [Fact]
    public void ToJson_ContainsExpectedTopLevelFields()
    {
        var report = new RotationReport(DateTimeOffset.UtcNow, [], 30);

        var json = ReportFormatter.ToJson(report);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        // Report should have generatedAt, warningWindowDays, and grouped results
        Assert.True(root.TryGetProperty("generatedAt", out _), "Missing 'generatedAt'");
        Assert.True(root.TryGetProperty("warningWindowDays", out _), "Missing 'warningWindowDays'");
        Assert.True(root.TryGetProperty("expired", out _), "Missing 'expired' group");
        Assert.True(root.TryGetProperty("warning", out _), "Missing 'warning' group");
        Assert.True(root.TryGetProperty("ok", out _), "Missing 'ok' group");
    }

    [Fact]
    public void ToJson_GroupsSecretsByStatus()
    {
        var results = new[]
        {
            MakeResult("exp1", -5,  RotationStatus.Expired, ["a"]),
            MakeResult("exp2", -10, RotationStatus.Expired, ["b"]),
            MakeResult("warn1", 7,  RotationStatus.Warning, ["c"]),
            MakeResult("ok1",  50,  RotationStatus.Ok,      ["d"]),
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var json = ReportFormatter.ToJson(report);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        // 2 expired, 1 warning, 1 ok
        Assert.Equal(2, root.GetProperty("expired").GetArrayLength());
        Assert.Equal(1, root.GetProperty("warning").GetArrayLength());
        Assert.Equal(1, root.GetProperty("ok").GetArrayLength());
    }

    [Fact]
    public void ToJson_SecretEntryHasExpectedFields()
    {
        var results = new[]
        {
            MakeResult("my-secret", -2, RotationStatus.Expired, ["svc-x"])
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var json = ReportFormatter.ToJson(report);
        var doc = JsonDocument.Parse(json);
        var entry = doc.RootElement.GetProperty("expired")[0];

        Assert.True(entry.TryGetProperty("name", out _), "Missing 'name'");
        Assert.True(entry.TryGetProperty("lastRotated", out _), "Missing 'lastRotated'");
        Assert.True(entry.TryGetProperty("rotationPolicyDays", out _), "Missing 'rotationPolicyDays'");
        Assert.True(entry.TryGetProperty("daysUntilExpiry", out _), "Missing 'daysUntilExpiry'");
        Assert.True(entry.TryGetProperty("status", out _), "Missing 'status'");
        Assert.True(entry.TryGetProperty("message", out _), "Missing 'message'");
        Assert.True(entry.TryGetProperty("requiredByServices", out _), "Missing 'requiredByServices'");
    }

    [Fact]
    public void ToJson_StatusIsStringNotInteger()
    {
        var results = new[]
        {
            MakeResult("key", -1, RotationStatus.Expired, ["svc"])
        };
        var report = new RotationReport(DateTimeOffset.UtcNow, results, 30);

        var json = ReportFormatter.ToJson(report);
        var doc = JsonDocument.Parse(json);
        var statusEl = doc.RootElement.GetProperty("expired")[0].GetProperty("status");

        // Status should serialize as a string ("Expired"), not as an integer (0)
        Assert.Equal(JsonValueKind.String, statusEl.ValueKind);
        Assert.Equal("Expired", statusEl.GetString());
    }
}
