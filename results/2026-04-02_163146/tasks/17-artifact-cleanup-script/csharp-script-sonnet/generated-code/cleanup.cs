// Artifact Cleanup Script — .NET 10 file-based app (top-level statements)
// Run with: dotnet run cleanup.cs [--dry-run]
//
// Applies configurable retention policies to a list of artifacts and produces
// a deletion plan showing what would be removed and how much space is freed.

// ─── Inline model types ───────────────────────────────────────────────────────

// NOTE: In a file-based app the library project is not automatically referenced,
//       so we include the types inline here for standalone execution.
//       The ArtifactCleanup library project contains the same types with the same
//       logic; the test project references that library.

/// <summary>Represents a CI/CD artifact with metadata.</summary>
record Artifact(string Name, long SizeBytes, DateTimeOffset CreatedAt, string WorkflowRunId)
{
    public double SizeMb => SizeBytes / (1024.0 * 1024.0);
}

/// <summary>Retention rules (all constraints optional; null = no limit).</summary>
class RetentionPolicy
{
    public int?  MaxAgeDays               { get; set; }
    public long? MaxTotalSizeBytes        { get; set; }
    public int?  KeepLatestNPerWorkflow   { get; set; }
}

/// <summary>Result of applying policies: what to delete and what to keep.</summary>
class DeletionPlan(List<Artifact> toDelete, List<Artifact> retained, bool isDryRun = false)
{
    public List<Artifact> ToDelete  { get; } = toDelete;
    public List<Artifact> Retained  { get; } = retained;
    public bool           IsDryRun  { get; } = isDryRun;

    public long SpaceReclaimedBytes => ToDelete.Sum(a => a.SizeBytes);
    public int  DeletedCount        => ToDelete.Count;
    public int  RetainedCount       => Retained.Count;

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

/// <summary>
/// Applies retention policies in order: MaxAge → KeepLatestN → MaxTotalSize.
/// </summary>
class ArtifactCleanupService
{
    public DeletionPlan ApplyPolicies(
        IEnumerable<Artifact> artifacts,
        RetentionPolicy policy,
        DateTimeOffset? referenceTime = null,
        bool dryRun = false)
    {
        var now      = referenceTime ?? DateTimeOffset.UtcNow;
        var toDelete = new HashSet<Artifact>();
        var all      = artifacts.ToList();

        // 1. MaxAgeDays — hard cutoff
        if (policy.MaxAgeDays.HasValue)
        {
            var cutoff = now.AddDays(-policy.MaxAgeDays.Value);
            foreach (var a in all.Where(a => a.CreatedAt < cutoff))
                toDelete.Add(a);
        }

        // 2. KeepLatestNPerWorkflow — per-workflow run cap
        if (policy.KeepLatestNPerWorkflow.HasValue)
        {
            var n = policy.KeepLatestNPerWorkflow.Value;
            var survivors = all.Where(a => !toDelete.Contains(a));
            foreach (var group in survivors.GroupBy(a => a.WorkflowRunId))
            {
                var ordered = group.OrderByDescending(a => a.CreatedAt).ToList();
                foreach (var a in ordered.Skip(n))
                    toDelete.Add(a);
            }
        }

        // 3. MaxTotalSizeBytes — global size cap (evict oldest survivors first)
        if (policy.MaxTotalSizeBytes.HasValue)
        {
            var limit    = policy.MaxTotalSizeBytes.Value;
            var survivors = all.Where(a => !toDelete.Contains(a))
                               .OrderBy(a => a.CreatedAt)
                               .ToList();
            long total = survivors.Sum(a => a.SizeBytes);
            foreach (var a in survivors)
            {
                if (total <= limit) break;
                toDelete.Add(a);
                total -= a.SizeBytes;
            }
        }

        var retained = all.Where(a => !toDelete.Contains(a)).ToList();
        return new DeletionPlan(toDelete.ToList(), retained, dryRun);
    }
}

// ─── Entry point ─────────────────────────────────────────────────────────────

bool dryRun = args.Contains("--dry-run", StringComparer.OrdinalIgnoreCase);
var now     = DateTimeOffset.UtcNow;

// Mock artifact data — simulating a real CI system's artifact store.
// In production you'd fetch these via the GitHub Actions / CI API.
var artifacts = new List<Artifact>
{
    new("build-output-pr-101",        150 * 1024 * 1024, now.AddDays(-65),  "wf-build-101"),
    new("build-output-pr-102",        200 * 1024 * 1024, now.AddDays(-45),  "wf-build-102"),
    new("build-output-pr-103",        180 * 1024 * 1024, now.AddDays(-32),  "wf-build-103"),
    new("build-output-pr-104",        220 * 1024 * 1024, now.AddDays(-25),  "wf-build-104"),
    new("build-output-pr-105",        175 * 1024 * 1024, now.AddDays(-10),  "wf-build-105"),
    new("test-results-main-run-10",    20 * 1024 * 1024, now.AddDays(-90),  "wf-test-main"),
    new("test-results-main-run-11",    22 * 1024 * 1024, now.AddDays(-60),  "wf-test-main"),
    new("test-results-main-run-12",    18 * 1024 * 1024, now.AddDays(-30),  "wf-test-main"),
    new("test-results-main-run-13",    21 * 1024 * 1024, now.AddDays(-14),  "wf-test-main"),
    new("test-results-main-run-14",    19 * 1024 * 1024, now.AddDays(-3),   "wf-test-main"),
    new("coverage-report-nightly",     50 * 1024 * 1024, now.AddDays(-120), "wf-nightly"),
    new("coverage-report-weekly",      55 * 1024 * 1024, now.AddDays(-7),   "wf-weekly"),
    new("docker-image-cache",         800 * 1024 * 1024, now.AddDays(-8),   "wf-docker"),
    new("perf-baseline-archive",      300 * 1024 * 1024, now.AddDays(-200), "wf-perf"),
};

// Retention policy: keep artifacts ≤30 days old, ≤2 per workflow run, total ≤600 MB
var policy = new RetentionPolicy
{
    MaxAgeDays             = 30,
    MaxTotalSizeBytes      = 600L * 1024 * 1024,  // 600 MB
    KeepLatestNPerWorkflow = 2,
};

Console.WriteLine($"Evaluating {artifacts.Count} artifacts...");
Console.WriteLine($"Policy: MaxAge={policy.MaxAgeDays}d  MaxTotal={policy.MaxTotalSizeBytes / (1024.0 * 1024.0):F0}MB  KeepLatestN={policy.KeepLatestNPerWorkflow}");
Console.WriteLine();

var service = new ArtifactCleanupService();
DeletionPlan plan;

try
{
    plan = service.ApplyPolicies(artifacts, policy, dryRun: dryRun);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: Failed to apply retention policies — {ex.Message}");
    return 1;
}

Console.WriteLine(plan.GenerateSummary());

if (dryRun)
    Console.WriteLine("Dry-run complete. No artifacts were deleted.");
else
    Console.WriteLine($"Done. {plan.DeletedCount} artifact(s) marked for deletion, {plan.SpaceReclaimedBytes / (1024.0 * 1024.0):F2} MB reclaimed.");

return 0;
