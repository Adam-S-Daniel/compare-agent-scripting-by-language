// TDD: Tests written FIRST before any implementation exists.
// These tests define the contract for RotationAnalyzer.
// Run `dotnet test` now → all tests fail (red). Then implement the library to make them pass (green).

using SecretRotation;
using Xunit;

namespace SecretRotation.Tests;

public class RotationAnalyzerTests
{
    // --- Test fixtures ---

    // A reference date used consistently across all tests for determinism.
    // Injecting today as a parameter prevents flakiness from the real clock.
    private static readonly DateOnly Today = new DateOnly(2024, 6, 15);

    private static SecretConfig MakeSecret(
        string name,
        DateOnly lastRotated,
        int policyDays,
        string[]? requiredBy = null) =>
        new SecretConfig(
            Name: name,
            LastRotated: lastRotated,
            RotationPolicyDays: policyDays,
            RequiredByServices: requiredBy ?? ["service-a"]);

    // --- Iteration 1: Expired detection ---
    // A secret is expired when today > (lastRotated + policyDays)

    [Fact]
    public void Analyze_SecretExpiredYesterday_ReturnsExpiredStatus()
    {
        // lastRotated = 91 days ago, policy = 90 days → expired 1 day ago
        var secret = MakeSecret("db-password", Today.AddDays(-91), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Single(report.Results);
        Assert.Equal(RotationStatus.Expired, report.Results[0].Status);
        Assert.Equal(-1, report.Results[0].DaysUntilExpiry); // negative = already expired
    }

    [Fact]
    public void Analyze_SecretExpiredLongAgo_DaysUntilExpiryIsNegative()
    {
        // lastRotated = 200 days ago, policy = 90 days → expired 110 days ago
        var secret = MakeSecret("api-key", Today.AddDays(-200), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal(-110, report.Results[0].DaysUntilExpiry);
        Assert.Equal(RotationStatus.Expired, report.Results[0].Status);
    }

    // --- Iteration 2: Warning window ---
    // A secret is in warning when 0 <= daysUntilExpiry <= warningWindowDays

    [Fact]
    public void Analyze_SecretExpiresInWarningWindow_ReturnsWarningStatus()
    {
        // lastRotated = 85 days ago, policy = 90 days → expires in 5 days, warning window = 30
        var secret = MakeSecret("jwt-secret", Today.AddDays(-85), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal(RotationStatus.Warning, report.Results[0].Status);
        Assert.Equal(5, report.Results[0].DaysUntilExpiry);
    }

    [Fact]
    public void Analyze_SecretExpiresExactlyAtWarningBoundary_ReturnsWarningStatus()
    {
        // Expires in exactly 30 days (boundary of warning window)
        var secret = MakeSecret("smtp-pass", Today.AddDays(-60), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal(RotationStatus.Warning, report.Results[0].Status);
        Assert.Equal(30, report.Results[0].DaysUntilExpiry);
    }

    [Fact]
    public void Analyze_SecretExpiresToday_ReturnsWarningStatus()
    {
        // Expires today (0 days remaining) → warning (not yet expired)
        var secret = MakeSecret("db-readonly", Today.AddDays(-90), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal(RotationStatus.Warning, report.Results[0].Status);
        Assert.Equal(0, report.Results[0].DaysUntilExpiry);
    }

    // --- Iteration 3: Ok status ---
    // A secret is Ok when daysUntilExpiry > warningWindowDays

    [Fact]
    public void Analyze_SecretRotatedYesterday_ReturnsOkStatus()
    {
        // lastRotated = yesterday, policy = 90 days → expires in 89 days, far from warning
        var secret = MakeSecret("oauth-token", Today.AddDays(-1), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal(RotationStatus.Ok, report.Results[0].Status);
        Assert.Equal(89, report.Results[0].DaysUntilExpiry);
    }

    [Fact]
    public void Analyze_SecretJustOutsideWarningWindow_ReturnsOkStatus()
    {
        // Expires in 31 days, warning window = 30 → just outside warning
        var secret = MakeSecret("s3-key", Today.AddDays(-59), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal(RotationStatus.Ok, report.Results[0].Status);
        Assert.Equal(31, report.Results[0].DaysUntilExpiry);
    }

    // --- Iteration 4: Multiple secrets and metadata preservation ---

    [Fact]
    public void Analyze_MultipleSecrets_ClassifiesEachCorrectly()
    {
        var secrets = new[]
        {
            MakeSecret("expired-secret",  Today.AddDays(-100), policyDays: 90),   // expired
            MakeSecret("warning-secret",  Today.AddDays(-80),  policyDays: 90),   // warning (10 days left)
            MakeSecret("ok-secret",       Today.AddDays(-10),  policyDays: 90),   // ok (80 days left)
        };

        var report = RotationAnalyzer.Analyze(secrets, warningWindowDays: 30, today: Today);

        Assert.Equal(3, report.Results.Count);
        Assert.Equal(RotationStatus.Expired, report.Results.First(r => r.Secret.Name == "expired-secret").Status);
        Assert.Equal(RotationStatus.Warning, report.Results.First(r => r.Secret.Name == "warning-secret").Status);
        Assert.Equal(RotationStatus.Ok,      report.Results.First(r => r.Secret.Name == "ok-secret").Status);
    }

    [Fact]
    public void Analyze_GroupedViews_MatchTotalResults()
    {
        // RotationReport exposes Expired/Warning/Ok as filtered views of Results
        var secrets = new[]
        {
            MakeSecret("e1", Today.AddDays(-100), policyDays: 90),
            MakeSecret("e2", Today.AddDays(-95),  policyDays: 90),
            MakeSecret("w1", Today.AddDays(-80),  policyDays: 90),
            MakeSecret("o1", Today.AddDays(-10),  policyDays: 90),
        };

        var report = RotationAnalyzer.Analyze(secrets, warningWindowDays: 30, today: Today);

        Assert.Equal(2, report.Expired.Count);
        Assert.Equal(1, report.Warning.Count);
        Assert.Equal(1, report.Ok.Count);
        Assert.Equal(4, report.Results.Count);
    }

    [Fact]
    public void Analyze_PreservesSecretMetadata()
    {
        // The result should carry all original secret data (name, services, policy)
        var services = new[] { "auth-service", "payment-service" };
        var secret = MakeSecret("payment-key", Today.AddDays(-5), policyDays: 90, requiredBy: services);

        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 30, today: Today);

        Assert.Equal("payment-key", report.Results[0].Secret.Name);
        Assert.Equal(services, report.Results[0].Secret.RequiredByServices);
        Assert.Equal(90, report.Results[0].Secret.RotationPolicyDays);
    }

    [Fact]
    public void Analyze_CustomWarningWindow_AffectsClassification()
    {
        // With a 5-day warning window, a secret expiring in 10 days should be Ok
        var secret = MakeSecret("narrow-window-secret", Today.AddDays(-80), policyDays: 90);
        var report = RotationAnalyzer.Analyze([secret], warningWindowDays: 5, today: Today);

        // Expires in 10 days, window = 5 → Ok
        Assert.Equal(RotationStatus.Ok, report.Results[0].Status);
    }

    [Fact]
    public void Analyze_ReportCarriesWarningWindowAndTimestamp()
    {
        var report = RotationAnalyzer.Analyze([], warningWindowDays: 14, today: Today);

        Assert.Equal(14, report.WarningWindowDays);
        Assert.NotEqual(default, report.GeneratedAt);
    }

    [Fact]
    public void Analyze_EmptySecretList_ReturnsEmptyResults()
    {
        var report = RotationAnalyzer.Analyze([], warningWindowDays: 30, today: Today);
        Assert.Empty(report.Results);
    }

    [Fact]
    public void Analyze_ResultsContainDescriptiveMessages()
    {
        var expired = MakeSecret("old-key",   Today.AddDays(-100), policyDays: 90); // -10 days
        var warning = MakeSecret("warn-key",  Today.AddDays(-85),  policyDays: 90); // 5 days left
        var ok      = MakeSecret("fresh-key", Today.AddDays(-1),   policyDays: 90); // 89 days left

        var report = RotationAnalyzer.Analyze([expired, warning, ok], warningWindowDays: 30, today: Today);

        // Messages should be non-empty for all results
        foreach (var r in report.Results)
            Assert.False(string.IsNullOrWhiteSpace(r.Message));

        // Expired message should mention "expired" (case-insensitive)
        var expiredResult = report.Results.First(r => r.Secret.Name == "old-key");
        Assert.Contains("expired", expiredResult.Message, StringComparison.OrdinalIgnoreCase);
    }
}
