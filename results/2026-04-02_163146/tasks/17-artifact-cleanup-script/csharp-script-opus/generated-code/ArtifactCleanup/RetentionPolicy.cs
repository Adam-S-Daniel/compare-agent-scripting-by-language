namespace ArtifactCleanup;

/// <summary>
/// Configures retention rules for artifact cleanup.
/// All properties are optional — only set policies are enforced.
/// </summary>
public class RetentionPolicy
{
    /// <summary>Maximum age in days. Artifacts older than this are deleted.</summary>
    public int? MaxAgeDays { get; set; }

    /// <summary>Maximum total size in bytes across all retained artifacts.</summary>
    public long? MaxTotalSizeBytes { get; set; }

    /// <summary>Keep only the N most recent artifacts per workflow run ID.</summary>
    public int? KeepLatestNPerWorkflow { get; set; }
}
