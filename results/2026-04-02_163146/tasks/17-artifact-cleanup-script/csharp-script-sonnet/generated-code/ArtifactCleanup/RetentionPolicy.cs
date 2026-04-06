namespace ArtifactCleanup;

/// <summary>
/// Defines the retention rules applied when determining which artifacts to delete.
/// All constraints are optional (null = no limit for that dimension).
/// When multiple constraints are set, ALL are applied — the most restrictive wins.
/// </summary>
public class RetentionPolicy
{
    /// <summary>
    /// Maximum age of an artifact in days.
    /// Artifacts older than this are candidates for deletion.
    /// </summary>
    public int? MaxAgeDays { get; set; }

    /// <summary>
    /// Maximum combined size (bytes) of all retained artifacts.
    /// When exceeded, oldest artifacts are evicted first until the total fits.
    /// </summary>
    public long? MaxTotalSizeBytes { get; set; }

    /// <summary>
    /// Maximum number of artifacts to keep per unique WorkflowRunId.
    /// When exceeded, the oldest runs are evicted.
    /// </summary>
    public int? KeepLatestNPerWorkflow { get; set; }
}
