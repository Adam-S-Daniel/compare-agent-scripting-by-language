// TDD Cycle 1 - RED: Test that a SecretConfig can determine if it's expired
// We define the expected behavior before implementing any production code.

using System;
using System.Collections.Generic;
using SecretRotationValidator;
using Xunit;

namespace SecretRotationValidator.Tests;

public class SecretConfigTests
{
    // TDD RED: A secret rotated 100 days ago with a 90-day policy should be expired
    [Fact]
    public void IsExpired_WhenPastRotationPolicy_ReturnsTrue()
    {
        var secret = new SecretConfig(
            Name: "db-password",
            LastRotated: DateTime.Today.AddDays(-100),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "api-server", "worker" }
        );

        Assert.True(secret.IsExpired(DateTime.Today));
    }

    // TDD RED: A secret rotated 30 days ago with a 90-day policy should NOT be expired
    [Fact]
    public void IsExpired_WhenWithinRotationPolicy_ReturnsFalse()
    {
        var secret = new SecretConfig(
            Name: "api-key",
            LastRotated: DateTime.Today.AddDays(-30),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "frontend" }
        );

        Assert.False(secret.IsExpired(DateTime.Today));
    }

    // TDD RED: A secret expiring in 5 days with a 7-day warning window should be "warning"
    [Fact]
    public void IsInWarningWindow_WhenExpiringWithinWindow_ReturnsTrue()
    {
        var secret = new SecretConfig(
            Name: "tls-cert",
            LastRotated: DateTime.Today.AddDays(-85),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "nginx" }
        );

        // Expires in 5 days, warning window is 7 days => should be in warning
        Assert.True(secret.IsInWarningWindow(DateTime.Today, warningDays: 7));
    }

    // TDD RED: A secret expiring in 20 days with a 7-day warning window should NOT be warning
    [Fact]
    public void IsInWarningWindow_WhenNotExpiringWithinWindow_ReturnsFalse()
    {
        var secret = new SecretConfig(
            Name: "signing-key",
            LastRotated: DateTime.Today.AddDays(-70),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "auth-service" }
        );

        // Expires in 20 days, warning window is 7 => not in warning
        Assert.False(secret.IsInWarningWindow(DateTime.Today, warningDays: 7));
    }

    // TDD RED: An already-expired secret should NOT count as "warning" (it's beyond warning)
    [Fact]
    public void IsInWarningWindow_WhenAlreadyExpired_ReturnsFalse()
    {
        var secret = new SecretConfig(
            Name: "old-secret",
            LastRotated: DateTime.Today.AddDays(-100),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "legacy-app" }
        );

        Assert.False(secret.IsInWarningWindow(DateTime.Today, warningDays: 7));
    }

    // TDD RED: DaysUntilExpiry should return correct number
    [Fact]
    public void DaysUntilExpiry_ReturnsCorrectValue()
    {
        var secret = new SecretConfig(
            Name: "test-key",
            LastRotated: DateTime.Today.AddDays(-80),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "service-a" }
        );

        Assert.Equal(10, secret.DaysUntilExpiry(DateTime.Today));
    }

    // TDD RED: DaysUntilExpiry should be negative when expired
    [Fact]
    public void DaysUntilExpiry_WhenExpired_ReturnsNegative()
    {
        var secret = new SecretConfig(
            Name: "expired-key",
            LastRotated: DateTime.Today.AddDays(-95),
            RotationPolicyDays: 90,
            RequiredByServices: new List<string> { "service-b" }
        );

        Assert.Equal(-5, secret.DaysUntilExpiry(DateTime.Today));
    }
}
