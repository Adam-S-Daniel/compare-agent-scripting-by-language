namespace ArtifactCleanup;

/// <summary>
/// Core service that applies retention policies to a collection of artifacts
/// and produces a <see cref="DeletionPlan"/> describing what to delete.
///
/// Policy application order (most permissive to most restrictive):
///   1. MaxAgeDays          — hard age cutoff, always applied first
///   2. KeepLatestNPerWorkflow — per-workflow cap, applied to age-survivors
///   3. MaxTotalSizeBytes   — global size cap, oldest evicted last
///
/// This order ensures that old artifacts are removed before size trimming,
/// so size eviction preferentially removes the oldest of the "still valid" artifacts.
/// </summary>
public class ArtifactCleanupService
{
    /// <summary>
    /// Applies the retention <paramref name="policy"/> to <paramref name="artifacts"/>
    /// and returns a <see cref="DeletionPlan"/>.
    /// </summary>
    /// <param name="artifacts">All artifacts to evaluate.</param>
    /// <param name="policy">The retention rules to apply.</param>
    /// <param name="referenceTime">
    ///   The "now" used for age calculations.
    ///   Pass a fixed value in tests to ensure determinism.
    /// </param>
    /// <param name="dryRun">
    ///   When <c>true</c> the plan is computed but no real actions occur.
    ///   The <see cref="DeletionPlan.IsDryRun"/> flag is set accordingly.
    /// </param>
    public DeletionPlan ApplyPolicies(
        IEnumerable<Artifact> artifacts,
        RetentionPolicy policy,
        DateTimeOffset? referenceTime = null,
        bool dryRun = false)
    {
        var now = referenceTime ?? DateTimeOffset.UtcNow;
        var toDelete = new HashSet<Artifact>();
        var candidates = artifacts.ToList();

        // --- Step 1: MaxAgeDays ---
        // Artifacts older than MaxAgeDays days are unconditionally deleted.
        if (policy.MaxAgeDays.HasValue)
        {
            var cutoff = now.AddDays(-policy.MaxAgeDays.Value);
            foreach (var a in candidates.Where(a => a.CreatedAt < cutoff))
                toDelete.Add(a);
        }

        // Work with survivors after age filter
        var survivors = candidates.Where(a => !toDelete.Contains(a)).ToList();

        // --- Step 2: KeepLatestNPerWorkflow ---
        // Within each workflow run ID, keep only the N most-recently-created artifacts.
        // Older ones beyond the cap are evicted.
        if (policy.KeepLatestNPerWorkflow.HasValue)
        {
            var n = policy.KeepLatestNPerWorkflow.Value;
            // Group survivors by WorkflowRunId, then within each group sort by CreatedAt desc,
            // mark everything past position N for deletion.
            foreach (var group in survivors.GroupBy(a => a.WorkflowRunId))
            {
                var ordered = group.OrderByDescending(a => a.CreatedAt).ToList();
                foreach (var a in ordered.Skip(n))
                    toDelete.Add(a);
            }
        }

        // Recompute survivors after the per-workflow cap
        survivors = candidates.Where(a => !toDelete.Contains(a)).ToList();

        // --- Step 3: MaxTotalSizeBytes ---
        // Evict oldest artifacts until total retained size fits within the limit.
        if (policy.MaxTotalSizeBytes.HasValue)
        {
            var limit = policy.MaxTotalSizeBytes.Value;
            // Sort survivors oldest-first so we evict old ones preferentially
            var byAge = survivors.OrderBy(a => a.CreatedAt).ToList();
            long totalSize = byAge.Sum(a => a.SizeBytes);

            foreach (var a in byAge)
            {
                if (totalSize <= limit) break;
                toDelete.Add(a);
                totalSize -= a.SizeBytes;
            }
        }

        var finalRetained = candidates.Where(a => !toDelete.Contains(a)).ToList();
        return new DeletionPlan(toDelete.ToList(), finalRetained, isDryRun: dryRun);
    }
}
