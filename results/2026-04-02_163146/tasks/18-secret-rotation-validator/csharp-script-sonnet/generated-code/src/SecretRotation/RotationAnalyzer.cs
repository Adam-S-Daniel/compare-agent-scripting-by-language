// Core classification logic for the Secret Rotation Validator.
// Key design decision: `today` is injected as a parameter so tests can use
// a fixed date, avoiding flakiness from the real clock.

namespace SecretRotation;

public static class RotationAnalyzer
{
    /// <summary>
    /// Analyzes a collection of secrets and returns a full rotation report.
    /// </summary>
    /// <param name="secrets">Secrets to analyze.</param>
    /// <param name="warningWindowDays">
    ///   Secrets expiring within this many days are classified as Warning.
    ///   Defaults to 30 days.
    /// </param>
    /// <param name="today">
    ///   Reference date for calculations. Pass explicitly in tests for determinism;
    ///   omit in production to use today's UTC date.
    /// </param>
    /// <returns>A <see cref="RotationReport"/> with all secrets classified by urgency.</returns>
    public static RotationReport Analyze(
        IEnumerable<SecretConfig> secrets,
        int warningWindowDays = 30,
        DateOnly? today = null)
    {
        if (warningWindowDays < 0)
            throw new ArgumentOutOfRangeException(nameof(warningWindowDays), "Warning window cannot be negative.");

        var referenceDate = today ?? DateOnly.FromDateTime(DateTime.UtcNow);

        var results = secrets
            .Select(s => ClassifySecret(s, referenceDate, warningWindowDays))
            .ToList();

        return new RotationReport(
            GeneratedAt: DateTimeOffset.UtcNow,
            Results: results,
            WarningWindowDays: warningWindowDays);
    }

    // Classifies a single secret against the reference date and warning window.
    private static RotationResult ClassifySecret(
        SecretConfig secret,
        DateOnly today,
        int warningWindowDays)
    {
        // Compute expiry date and days remaining.
        // DateOnly.DayNumber gives an integer ordinal — clean integer subtraction.
        var expiryDate = secret.LastRotated.AddDays(secret.RotationPolicyDays);
        var daysUntilExpiry = expiryDate.DayNumber - today.DayNumber;

        // Classification rules:
        //   expired  → daysUntilExpiry < 0   (deadline already passed)
        //   warning  → 0 <= days <= window   (today or within warning window)
        //   ok       → days > window          (comfortably within policy)
        var (status, message) = daysUntilExpiry < 0
            ? (RotationStatus.Expired,
               $"Expired {Math.Abs(daysUntilExpiry)} day(s) ago — rotate immediately")
            : daysUntilExpiry <= warningWindowDays
            ? (RotationStatus.Warning,
               $"Expires in {daysUntilExpiry} day(s) — rotation due soon")
            : (RotationStatus.Ok,
               $"OK — expires in {daysUntilExpiry} day(s)");

        return new RotationResult(
            Secret: secret,
            DaysUntilExpiry: daysUntilExpiry,
            Status: status,
            Message: message);
    }
}
