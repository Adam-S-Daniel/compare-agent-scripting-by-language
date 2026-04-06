// SecretConfig: Core model representing a secret with its rotation metadata.
// Implements expiration and warning window logic as pure functions.

using System;
using System.Collections.Generic;

namespace SecretRotationValidator;

/// <summary>
/// Represents a secret with rotation policy metadata.
/// </summary>
public record SecretConfig(
    string Name,
    DateTime LastRotated,
    int RotationPolicyDays,
    List<string> RequiredByServices)
{
    /// <summary>
    /// Returns the number of days until this secret expires.
    /// Negative values indicate the secret is already expired.
    /// </summary>
    public int DaysUntilExpiry(DateTime asOf)
    {
        var expiryDate = LastRotated.AddDays(RotationPolicyDays);
        return (int)(expiryDate - asOf).TotalDays;
    }

    /// <summary>
    /// Returns true if the secret has exceeded its rotation policy.
    /// </summary>
    public bool IsExpired(DateTime asOf) => DaysUntilExpiry(asOf) < 0;

    /// <summary>
    /// Returns true if the secret is not yet expired but will expire within the warning window.
    /// </summary>
    public bool IsInWarningWindow(DateTime asOf, int warningDays)
    {
        var days = DaysUntilExpiry(asOf);
        return days >= 0 && days <= warningDays;
    }
}
