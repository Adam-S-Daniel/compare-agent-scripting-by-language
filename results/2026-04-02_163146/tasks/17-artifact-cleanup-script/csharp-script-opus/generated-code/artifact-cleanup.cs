// Artifact Cleanup Script — .NET 10 file-based app
// Run with: dotnet run artifact-cleanup.cs [--dry-run] [--max-age DAYS] [--max-size BYTES] [--keep-latest N]
//
// Applies retention policies to a list of mock CI/CD artifacts and generates
// a deletion plan showing which artifacts to remove and how much space is reclaimed.
// Supports dry-run mode (--dry-run) to preview without executing deletions.

// --- Parse command-line arguments ---
var dryRun = args.Contains("--dry-run");
int? maxAgeDays = ParseIntArg(args, "--max-age");
long? maxTotalSize = ParseLongArg(args, "--max-size");
int? keepLatestN = ParseIntArg(args, "--keep-latest");

// If no policies specified, use sensible defaults
if (maxAgeDays is null && maxTotalSize is null && keepLatestN is null)
{
    maxAgeDays = 30;
    maxTotalSize = 500 * 1024 * 1024; // 500 MB
    keepLatestN = 3;
    Console.WriteLine("No policies specified — using defaults: --max-age 30 --max-size 524288000 --keep-latest 3");
    Console.WriteLine();
}

// --- Build mock artifact data ---
var now = DateTime.UtcNow;
var artifacts = GenerateMockArtifacts(now);

Console.WriteLine($"Loaded {artifacts.Count} artifacts from mock data.");
Console.WriteLine();

// --- Configure retention policy ---
var policy = new RetentionPolicy
{
    MaxAgeDays = maxAgeDays,
    MaxTotalSizeBytes = maxTotalSize,
    KeepLatestNPerWorkflow = keepLatestN,
};

// --- Build and display the deletion plan ---
var engine = new CleanupEngine(now);
var plan = engine.BuildDeletionPlan(artifacts, policy, dryRun);

Console.WriteLine(plan.GenerateSummary());

if (!dryRun && plan.ToDelete.Count > 0)
{
    Console.WriteLine();
    Console.WriteLine("Deletion would be executed here (simulated — no actual artifacts to delete).");
}

return 0;

// ============================================================================
// Helper methods
// ============================================================================

static int? ParseIntArg(string[] args, string flag)
{
    var idx = Array.IndexOf(args, flag);
    if (idx >= 0 && idx + 1 < args.Length && int.TryParse(args[idx + 1], out var value))
        return value;
    return null;
}

static long? ParseLongArg(string[] args, string flag)
{
    var idx = Array.IndexOf(args, flag);
    if (idx >= 0 && idx + 1 < args.Length && long.TryParse(args[idx + 1], out var value))
        return value;
    return null;
}

// --- Generate realistic mock artifact data ---
static List<Artifact> GenerateMockArtifacts(DateTime now) =>
[
    // workflow "ci-build" — frequent, multiple runs
    new("ci-build-output-1422",  15_728_640,  now.AddDays(-45), "ci-build"),
    new("ci-build-output-1455",  16_252_928,  now.AddDays(-38), "ci-build"),
    new("ci-build-output-1501",  14_680_064,  now.AddDays(-30), "ci-build"),
    new("ci-build-output-1534",  17_301_504,  now.AddDays(-22), "ci-build"),
    new("ci-build-output-1567",  15_204_352,  now.AddDays(-15), "ci-build"),
    new("ci-build-output-1590",  16_777_216,  now.AddDays(-7),  "ci-build"),
    new("ci-build-output-1612",  18_350_080,  now.AddDays(-2),  "ci-build"),

    // workflow "deploy-staging" — moderate frequency
    new("staging-deploy-logs-88",  2_097_152,  now.AddDays(-60), "deploy-staging"),
    new("staging-deploy-logs-91",  1_572_864,  now.AddDays(-40), "deploy-staging"),
    new("staging-deploy-logs-95",  2_621_440,  now.AddDays(-20), "deploy-staging"),
    new("staging-deploy-logs-98",  1_048_576,  now.AddDays(-5),  "deploy-staging"),

    // workflow "release" — infrequent, large artifacts
    new("release-v2.0.0-artifacts", 157_286_400, now.AddDays(-90), "release"),
    new("release-v2.1.0-artifacts", 167_772_160, now.AddDays(-60), "release"),
    new("release-v2.2.0-artifacts", 178_257_920, now.AddDays(-30), "release"),
    new("release-v2.3.0-artifacts", 188_743_680, now.AddDays(-7),  "release"),

    // workflow "nightly-tests" — daily, small
    new("nightly-test-report-apr01",  524_288, now.AddDays(-5), "nightly-tests"),
    new("nightly-test-report-mar30",  524_288, now.AddDays(-7), "nightly-tests"),
    new("nightly-test-report-mar25",  524_288, now.AddDays(-12), "nightly-tests"),
    new("nightly-test-report-mar15",  524_288, now.AddDays(-22), "nightly-tests"),
    new("nightly-test-report-mar01",  524_288, now.AddDays(-36), "nightly-tests"),
    new("nightly-test-report-feb15",  524_288, now.AddDays(-50), "nightly-tests"),
];

// ============================================================================
// Domain types — self-contained for file-based app execution.
// The same types exist in the ArtifactCleanup class library (used by tests).
// ============================================================================

/// <summary>Represents a build/CI artifact with metadata.</summary>
record Artifact(string Name, long SizeBytes, DateTime CreatedAt, string WorkflowRunId);

/// <summary>Configures retention rules. Only set policies are enforced.</summary>
class RetentionPolicy
{
    public int? MaxAgeDays { get; set; }
    public long? MaxTotalSizeBytes { get; set; }
    public int? KeepLatestNPerWorkflow { get; set; }
}

/// <summary>Result of applying retention policies.</summary>
class DeletionPlan
{
    public List<Artifact> ToDelete { get; init; } = [];
    public List<Artifact> ToRetain { get; init; } = [];
    public bool IsDryRun { get; init; }

    public long SpaceReclaimedBytes => ToDelete.Sum(a => a.SizeBytes);
    public long SpaceRetainedBytes => ToRetain.Sum(a => a.SizeBytes);

    public string GenerateSummary()
    {
        var mode = IsDryRun ? "[DRY RUN] " : "";
        var now = DateTime.UtcNow;
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
                lines.Add($"  - {a.Name} ({FormatBytes(a.SizeBytes)}, age: {(now - a.CreatedAt).Days}d, workflow: {a.WorkflowRunId})");
            lines.Add("");
        }

        if (ToRetain.Count > 0)
        {
            lines.Add("Artifacts retained:");
            foreach (var a in ToRetain)
                lines.Add($"  - {a.Name} ({FormatBytes(a.SizeBytes)}, workflow: {a.WorkflowRunId})");
        }

        return string.Join(Environment.NewLine, lines);
    }

    static string FormatBytes(long bytes) => bytes switch
    {
        >= 1_073_741_824 => $"{bytes / 1_073_741_824.0:F2} GB",
        >= 1_048_576 => $"{bytes / 1_048_576.0:F2} MB",
        >= 1024 => $"{bytes / 1024.0:F2} KB",
        _ => $"{bytes} B"
    };
}

/// <summary>
/// Core engine: applies retention policies to artifacts and produces a deletion plan.
/// Policy application order: max age → keep-latest-N per workflow → max total size.
/// </summary>
class CleanupEngine
{
    private readonly DateTime _now;

    public CleanupEngine(DateTime now) => _now = now;

    public DeletionPlan BuildDeletionPlan(List<Artifact> artifacts, RetentionPolicy policy, bool dryRun = false)
    {
        if (artifacts is null) throw new ArgumentNullException(nameof(artifacts));
        if (policy is null) throw new ArgumentNullException(nameof(policy));

        var toDelete = new HashSet<Artifact>();

        // 1. Max age: delete artifacts older than the cutoff
        if (policy.MaxAgeDays.HasValue)
        {
            var cutoff = _now.AddDays(-policy.MaxAgeDays.Value);
            foreach (var a in artifacts.Where(a => a.CreatedAt < cutoff))
                toDelete.Add(a);
        }

        // 2. Keep-latest-N: for each workflow, keep only the N newest
        if (policy.KeepLatestNPerWorkflow.HasValue)
        {
            var n = policy.KeepLatestNPerWorkflow.Value;
            foreach (var group in artifacts.GroupBy(a => a.WorkflowRunId))
                foreach (var a in group.OrderByDescending(a => a.CreatedAt).Skip(n))
                    toDelete.Add(a);
        }

        // 3. Max total size: among survivors (newest first), delete once budget exceeded
        if (policy.MaxTotalSizeBytes.HasValue)
        {
            var survivors = artifacts
                .Where(a => !toDelete.Contains(a))
                .OrderByDescending(a => a.CreatedAt)
                .ToList();

            long retainedTotal = 0;
            foreach (var a in survivors)
            {
                if (retainedTotal + a.SizeBytes > policy.MaxTotalSizeBytes.Value)
                    toDelete.Add(a);
                else
                    retainedTotal += a.SizeBytes;
            }
        }

        return new DeletionPlan
        {
            ToDelete = artifacts.Where(a => toDelete.Contains(a)).ToList(),
            ToRetain = artifacts.Where(a => !toDelete.Contains(a)).ToList(),
            IsDryRun = dryRun
        };
    }
}
