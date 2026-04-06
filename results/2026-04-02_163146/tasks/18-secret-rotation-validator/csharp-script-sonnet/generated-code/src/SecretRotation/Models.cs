// Core domain models for the Secret Rotation Validator.
// All types are immutable records to make them easy to construct in tests.

namespace SecretRotation;

/// <summary>
/// Configuration for a single secret — the input data.
/// </summary>
/// <param name="Name">Unique identifier for this secret (e.g. "db-password").</param>
/// <param name="LastRotated">Date when the secret was last changed.</param>
/// <param name="RotationPolicyDays">How often this secret must be rotated.</param>
/// <param name="RequiredByServices">Services that depend on this secret.</param>
public record SecretConfig(
    string Name,
    DateOnly LastRotated,
    int RotationPolicyDays,
    string[] RequiredByServices);

/// <summary>
/// Urgency classification for a secret.
/// </summary>
public enum RotationStatus
{
    /// <summary>The rotation deadline has already passed.</summary>
    Expired,
    /// <summary>The deadline is within the configured warning window.</summary>
    Warning,
    /// <summary>The secret is within policy and not approaching expiry.</summary>
    Ok
}

/// <summary>
/// Analysis result for a single secret — pairs config with computed status.
/// </summary>
/// <param name="Secret">Original configuration.</param>
/// <param name="DaysUntilExpiry">
///   Days remaining before expiry. Negative means already expired.
///   E.g. -3 means expired 3 days ago; 10 means expires in 10 days.
/// </param>
/// <param name="Status">Urgency classification.</param>
/// <param name="Message">Human-readable explanation of the status.</param>
public record RotationResult(
    SecretConfig Secret,
    int DaysUntilExpiry,
    RotationStatus Status,
    string Message);

/// <summary>
/// Full rotation report — contains all results grouped by urgency.
/// </summary>
/// <param name="GeneratedAt">Timestamp the report was produced.</param>
/// <param name="Results">All analyzed secrets (unfiltered).</param>
/// <param name="WarningWindowDays">The configured warning threshold used for this report.</param>
public record RotationReport(
    DateTimeOffset GeneratedAt,
    IReadOnlyList<RotationResult> Results,
    int WarningWindowDays)
{
    // Convenience views grouped by urgency — derived from Results
    public IReadOnlyList<RotationResult> Expired => Results.Where(r => r.Status == RotationStatus.Expired).ToList();
    public IReadOnlyList<RotationResult> Warning => Results.Where(r => r.Status == RotationStatus.Warning).ToList();
    public IReadOnlyList<RotationResult> Ok      => Results.Where(r => r.Status == RotationStatus.Ok).ToList();
}
