// TDD Cycle 2 - RED: Test the RotationValidator which groups secrets by urgency.
// We test that secrets are correctly classified as expired, warning, or ok.

using System;
using System.Collections.Generic;
using System.Linq;
using SecretRotationValidator;
using Xunit;

namespace SecretRotationValidator.Tests;

public class RotationValidatorTests
{
    private readonly DateTime _today = new DateTime(2026, 4, 6);

    // Helper to build test fixtures
    private List<SecretConfig> CreateTestSecrets() => new()
    {
        // Expired: rotated 100 days ago, 90-day policy => expired 10 days ago
        new SecretConfig("db-password", _today.AddDays(-100), 90, new List<string> { "api-server", "worker" }),
        // Warning: rotated 85 days ago, 90-day policy => expires in 5 days
        new SecretConfig("tls-cert", _today.AddDays(-85), 90, new List<string> { "nginx" }),
        // OK: rotated 30 days ago, 90-day policy => expires in 60 days
        new SecretConfig("api-key", _today.AddDays(-30), 90, new List<string> { "frontend" }),
        // Expired: rotated 40 days ago, 30-day policy => expired 10 days ago
        new SecretConfig("jwt-signing-key", _today.AddDays(-40), 30, new List<string> { "auth-service", "gateway" }),
        // OK: rotated 10 days ago, 365-day policy => expires in 355 days
        new SecretConfig("encryption-key", _today.AddDays(-10), 365, new List<string> { "storage-service" }),
    };

    [Fact]
    public void Validate_GroupsExpiredSecrets()
    {
        var secrets = CreateTestSecrets();
        var result = RotationValidator.Validate(secrets, _today, warningDays: 7);

        Assert.Equal(2, result.Expired.Count);
        Assert.Contains(result.Expired, s => s.Secret.Name == "db-password");
        Assert.Contains(result.Expired, s => s.Secret.Name == "jwt-signing-key");
    }

    [Fact]
    public void Validate_GroupsWarningSecrets()
    {
        var secrets = CreateTestSecrets();
        var result = RotationValidator.Validate(secrets, _today, warningDays: 7);

        Assert.Single(result.Warning);
        Assert.Equal("tls-cert", result.Warning[0].Secret.Name);
    }

    [Fact]
    public void Validate_GroupsOkSecrets()
    {
        var secrets = CreateTestSecrets();
        var result = RotationValidator.Validate(secrets, _today, warningDays: 7);

        Assert.Equal(2, result.Ok.Count);
        Assert.Contains(result.Ok, s => s.Secret.Name == "api-key");
        Assert.Contains(result.Ok, s => s.Secret.Name == "encryption-key");
    }

    [Fact]
    public void Validate_IncludesDaysUntilExpiry()
    {
        var secrets = CreateTestSecrets();
        var result = RotationValidator.Validate(secrets, _today, warningDays: 7);

        var dbPassword = result.Expired.First(s => s.Secret.Name == "db-password");
        Assert.Equal(-10, dbPassword.DaysUntilExpiry);

        var tlsCert = result.Warning.First(s => s.Secret.Name == "tls-cert");
        Assert.Equal(5, tlsCert.DaysUntilExpiry);
    }

    [Fact]
    public void Validate_WithCustomWarningWindow_AffectsGrouping()
    {
        var secrets = CreateTestSecrets();
        // With a 60-day warning window, api-key (60 days to expiry) should be in warning
        var result = RotationValidator.Validate(secrets, _today, warningDays: 60);

        Assert.Equal(2, result.Warning.Count);
        Assert.Contains(result.Warning, s => s.Secret.Name == "tls-cert");
        Assert.Contains(result.Warning, s => s.Secret.Name == "api-key");
    }

    [Fact]
    public void Validate_WithEmptyList_ReturnsEmptyGroups()
    {
        var result = RotationValidator.Validate(new List<SecretConfig>(), _today, warningDays: 7);

        Assert.Empty(result.Expired);
        Assert.Empty(result.Warning);
        Assert.Empty(result.Ok);
    }

    [Fact]
    public void Validate_AssignsCorrectUrgency()
    {
        var secrets = CreateTestSecrets();
        var result = RotationValidator.Validate(secrets, _today, warningDays: 7);

        Assert.All(result.Expired, r => Assert.Equal(Urgency.Expired, r.Urgency));
        Assert.All(result.Warning, r => Assert.Equal(Urgency.Warning, r.Urgency));
        Assert.All(result.Ok, r => Assert.Equal(Urgency.Ok, r.Urgency));
    }
}
