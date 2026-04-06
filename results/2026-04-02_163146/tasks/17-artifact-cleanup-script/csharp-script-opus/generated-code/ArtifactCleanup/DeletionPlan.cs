namespace ArtifactCleanup;

/// <summary>
/// The result of applying retention policies: which artifacts to keep, which to delete,
/// and a human-readable summary.
/// </summary>
public class DeletionPlan
{
    public List<Artifact> ToDelete { get; init; } = [];
    public List<Artifact> ToRetain { get; init; } = [];
    public bool IsDryRun { get; init; }

    /// <summary>Total bytes that would be freed by deleting the marked artifacts.</summary>
    public long SpaceReclaimedBytes => ToDelete.Sum(a => a.SizeBytes);

    /// <summary>Total bytes of retained artifacts.</summary>
    public long SpaceRetainedBytes => ToRetain.Sum(a => a.SizeBytes);

    /// <summary>Generates a human-readable summary of the deletion plan.</summary>
    public string GenerateSummary()
    {
        var mode = IsDryRun ? "[DRY RUN] " : "";
        var lines = new List<string>
        {
            $"{mode}Artifact Cleanup Plan",
            $"  Artifacts to delete: {ToDelete.Count}",
            $"  Artifacts to retain: {ToRetain.Count}",
            $"  Space reclaimed:     {FormatBytes(SpaceReclaimedBytes)}",
            $"  Space retained:      {FormatBytes(SpaceRetainedBytes)}",
            ""
        };

        if (ToDelete.Count > 0)
        {
            lines.Add("Artifacts marked for deletion:");
            foreach (var a in ToDelete)
            {
                lines.Add($"  - {a.Name} ({FormatBytes(a.SizeBytes)}, age: {(DateTime.UtcNow - a.CreatedAt).Days}d, workflow: {a.WorkflowRunId})");
            }
            lines.Add("");
        }

        if (ToRetain.Count > 0)
        {
            lines.Add("Artifacts retained:");
            foreach (var a in ToRetain)
            {
                lines.Add($"  - {a.Name} ({FormatBytes(a.SizeBytes)}, workflow: {a.WorkflowRunId})");
            }
        }

        return string.Join(Environment.NewLine, lines);
    }

    private static string FormatBytes(long bytes) => bytes switch
    {
        >= 1_073_741_824 => $"{bytes / 1_073_741_824.0:F2} GB",
        >= 1_048_576 => $"{bytes / 1_048_576.0:F2} MB",
        >= 1024 => $"{bytes / 1024.0:F2} KB",
        _ => $"{bytes} B"
    };
}
