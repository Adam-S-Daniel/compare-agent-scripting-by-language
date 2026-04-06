namespace ArtifactCleanup;

/// <summary>
/// Core engine that applies retention policies to a list of artifacts
/// and produces a deletion plan. Accepts a reference time for testability.
/// </summary>
public class CleanupEngine
{
    private readonly DateTime _now;

    public CleanupEngine(DateTime now)
    {
        _now = now;
    }

    /// <summary>
    /// Applies the given retention policy to the artifacts and returns a deletion plan.
    /// Policies are applied in order: max age, keep-latest-N per workflow, then max total size.
    /// An artifact marked for deletion by any policy stays deleted.
    /// </summary>
    public DeletionPlan BuildDeletionPlan(List<Artifact> artifacts, RetentionPolicy policy, bool dryRun = false)
    {
        if (artifacts == null) throw new ArgumentNullException(nameof(artifacts));
        if (policy == null) throw new ArgumentNullException(nameof(policy));

        // Track which artifacts are marked for deletion
        var toDelete = new HashSet<Artifact>();

        // 1. Apply max age policy
        if (policy.MaxAgeDays.HasValue)
        {
            var cutoff = _now.AddDays(-policy.MaxAgeDays.Value);
            foreach (var artifact in artifacts)
            {
                if (artifact.CreatedAt < cutoff)
                {
                    toDelete.Add(artifact);
                }
            }
        }

        // 2. Apply keep-latest-N per workflow policy
        if (policy.KeepLatestNPerWorkflow.HasValue)
        {
            var n = policy.KeepLatestNPerWorkflow.Value;
            var grouped = artifacts
                .GroupBy(a => a.WorkflowRunId)
                .ToList();

            foreach (var group in grouped)
            {
                // Sort by creation date descending, keep only the first N
                var sorted = group.OrderByDescending(a => a.CreatedAt).ToList();
                foreach (var artifact in sorted.Skip(n))
                {
                    toDelete.Add(artifact);
                }
            }
        }

        // 3. Apply max total size policy on the surviving artifacts.
        //    Walk newest-first, accumulating size. Once the budget is exceeded,
        //    mark the artifact for deletion (don't count its size toward retained total).
        if (policy.MaxTotalSizeBytes.HasValue)
        {
            var survivors = artifacts
                .Where(a => !toDelete.Contains(a))
                .OrderByDescending(a => a.CreatedAt) // newest first = keep newest
                .ToList();

            long retainedTotal = 0;
            foreach (var artifact in survivors)
            {
                if (retainedTotal + artifact.SizeBytes > policy.MaxTotalSizeBytes.Value)
                {
                    toDelete.Add(artifact);
                }
                else
                {
                    retainedTotal += artifact.SizeBytes;
                }
            }
        }

        // Build the final plan preserving original order
        var retained = artifacts.Where(a => !toDelete.Contains(a)).ToList();
        var deleted = artifacts.Where(a => toDelete.Contains(a)).ToList();

        return new DeletionPlan
        {
            ToDelete = deleted,
            ToRetain = retained,
            IsDryRun = dryRun
        };
    }
}
