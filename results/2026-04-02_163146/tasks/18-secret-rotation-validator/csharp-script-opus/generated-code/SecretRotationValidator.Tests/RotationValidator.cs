// RotationValidator: Groups secrets by urgency (expired, warning, ok).
// Pure function taking a list of secrets and returning a validated report.

using System;
using System.Collections.Generic;
using System.Linq;

namespace SecretRotationValidator;

/// <summary>Urgency level for a secret's rotation status.</summary>
public enum Urgency { Expired, Warning, Ok }

/// <summary>A single secret's validation result with computed metadata.</summary>
public record ValidationEntry(SecretConfig Secret, Urgency Urgency, int DaysUntilExpiry);

/// <summary>The full validation report, secrets grouped by urgency.</summary>
public record ValidationReport(
    List<ValidationEntry> Expired,
    List<ValidationEntry> Warning,
    List<ValidationEntry> Ok)
{
    /// <summary>All entries across all groups.</summary>
    public IEnumerable<ValidationEntry> All => Expired.Concat(Warning).Concat(Ok);
}

/// <summary>
/// Validates a list of secrets against their rotation policies
/// and groups them by urgency level.
/// </summary>
public static class RotationValidator
{
    public static ValidationReport Validate(
        List<SecretConfig> secrets, DateTime asOf, int warningDays)
    {
        if (warningDays < 0)
            throw new ArgumentException("Warning days must be non-negative.", nameof(warningDays));

        var expired = new List<ValidationEntry>();
        var warning = new List<ValidationEntry>();
        var ok = new List<ValidationEntry>();

        foreach (var secret in secrets)
        {
            var daysUntilExpiry = secret.DaysUntilExpiry(asOf);
            Urgency urgency;

            if (secret.IsExpired(asOf))
                urgency = Urgency.Expired;
            else if (secret.IsInWarningWindow(asOf, warningDays))
                urgency = Urgency.Warning;
            else
                urgency = Urgency.Ok;

            var entry = new ValidationEntry(secret, urgency, daysUntilExpiry);

            switch (urgency)
            {
                case Urgency.Expired: expired.Add(entry); break;
                case Urgency.Warning: warning.Add(entry); break;
                case Urgency.Ok:      ok.Add(entry); break;
            }
        }

        return new ValidationReport(expired, warning, ok);
    }
}
