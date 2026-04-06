namespace ArtifactCleanup;

/// <summary>
/// The result of applying retention policies to a set of artifacts.
/// Describes which artifacts to delete, which to retain, and provides a human-readable summary.
/// </summary>
public class DeletionPlan
{
    /// <summary>Artifacts that should be deleted according to the applied policies.</summary>
    public List<Artifact> ToDelete { get; }

    /// <summary>Artifacts that pass all retention policies and should be kept.</summary>
    public List<Artifact> Retained { get; }

    /// <summary>
    /// When true the plan was generated in dry-run mode:
    /// no actual deletions occurred or should occur.
    /// </summary>
    public bool IsDryRun { get; }

    public DeletionPlan(List<Artifact> toDelete, List<Artifact> retained, bool isDryRun = false)
    {
        ToDelete = toDelete;
        Retained = retained;
        IsDryRun = isDryRun;
    }

    /// <summary>Total bytes that would be freed by deleting all marked artifacts.</summary>
    public long SpaceReclaimedBytes => ToDelete.Sum(a => a.SizeBytes);

    /// <summary>Number of artifacts to be deleted.</summary>
    public int DeletedCount => ToDelete.Count;

    /// <summary>Number of artifacts that will be kept.</summary>
    public int RetainedCount => Retained.Count;

    /// <summary>
    /// Generates a human-readable summary of the deletion plan,
    /// including dry-run indicator, counts, and space reclaimed.
    /// </summary>
    public string GenerateSummary()
    {
        var sb = new System.Text.StringBuilder();

        if (IsDryRun)
            sb.AppendLine("=== DRY RUN — no artifacts will actually be deleted ===");
        else
            sb.AppendLine("=== Artifact Deletion Plan ===");

        sb.AppendLine();
        sb.AppendLine($"  Artifacts to delete : {DeletedCount}");
        sb.AppendLine($"  Artifacts retained  : {RetainedCount}");
        sb.AppendLine($"  Space reclaimed     : {SpaceReclaimedBytes / (1024.0 * 1024.0):F2} MB");
        sb.AppendLine();

        if (ToDelete.Count > 0)
        {
            sb.AppendLine("  To delete:");
            foreach (var a in ToDelete.OrderBy(a => a.CreatedAt))
                sb.AppendLine($"    - {a.Name,-40} {a.SizeMb,8:F2} MB  created {a.CreatedAt:yyyy-MM-dd}  run={a.WorkflowRunId}");
            sb.AppendLine();
        }

        if (Retained.Count > 0)
        {
            sb.AppendLine("  Retained:");
            foreach (var a in Retained.OrderBy(a => a.CreatedAt))
                sb.AppendLine($"    + {a.Name,-40} {a.SizeMb,8:F2} MB  created {a.CreatedAt:yyyy-MM-dd}  run={a.WorkflowRunId}");
        }

        return sb.ToString();
    }
}
