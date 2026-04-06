// TDD: Red/Green cycle for Artifact Cleanup Script
// Design: each test was written first (RED), then the minimum implementation
//         was added to make it pass (GREEN), then refactored if needed.
//
// KeepLatestNPerWorkflow semantics:
//   Artifacts are grouped by WorkflowRunId. Within each group, only the N
//   most recently created artifacts are kept; older ones are marked for deletion.
//   Rationale: a single CI run can produce multiple artifacts (e.g. build outputs
//   for multiple platforms). This cap limits how many you keep per run.

using ArtifactCleanup;
using Xunit;

namespace ArtifactCleanup.Tests;

// ============================================================
// PHASE 1: Artifact model (RED: fails until Artifact.cs exists)
// ============================================================

public class ArtifactModelTests
{
    [Fact]
    public void Artifact_CanBeCreated_WithAllRequiredProperties()
    {
        var created = new DateTimeOffset(2025, 1, 15, 10, 0, 0, TimeSpan.Zero);
        var artifact = new Artifact(
            Name: "build-output",
            SizeBytes: 1024 * 1024,   // 1 MB
            CreatedAt: created,
            WorkflowRunId: "run-42"
        );

        Assert.Equal("build-output", artifact.Name);
        Assert.Equal(1024 * 1024, artifact.SizeBytes);
        Assert.Equal(created, artifact.CreatedAt);
        Assert.Equal("run-42", artifact.WorkflowRunId);
    }

    [Fact]
    public void Artifact_SizeMb_ReturnsCorrectMegabytes()
    {
        var artifact = new Artifact("x", 5 * 1024 * 1024, DateTimeOffset.UtcNow, "r1");
        Assert.Equal(5.0, artifact.SizeMb, precision: 2);
    }
}

// ============================================================
// PHASE 2: RetentionPolicy model (RED: fails until type exists)
// ============================================================

public class RetentionPolicyTests
{
    [Fact]
    public void RetentionPolicy_DefaultValues_AreUnbounded()
    {
        var policy = new RetentionPolicy();
        Assert.Null(policy.MaxAgeDays);
        Assert.Null(policy.MaxTotalSizeBytes);
        Assert.Null(policy.KeepLatestNPerWorkflow);
    }

    [Fact]
    public void RetentionPolicy_CanSetAllConstraints()
    {
        var policy = new RetentionPolicy
        {
            MaxAgeDays = 30,
            MaxTotalSizeBytes = 10L * 1024 * 1024 * 1024, // 10 GB
            KeepLatestNPerWorkflow = 5
        };

        Assert.Equal(30, policy.MaxAgeDays);
        Assert.Equal(10L * 1024 * 1024 * 1024, policy.MaxTotalSizeBytes);
        Assert.Equal(5, policy.KeepLatestNPerWorkflow);
    }
}

// ============================================================
// PHASE 3: ArtifactCleanupService — max-age filter
// ============================================================

public class ArtifactCleanupServiceMaxAgeTests
{
    private static readonly DateTimeOffset Now = new DateTimeOffset(2025, 3, 1, 0, 0, 0, TimeSpan.Zero);

    private static Artifact MakeArtifact(string name, int daysOld, string runId = "r1") =>
        new(name, 1024, Now.AddDays(-daysOld), runId);

    [Fact]
    public void ApplyPolicies_NoPolicy_RetainsAll()
    {
        var artifacts = new[]
        {
            MakeArtifact("a1", 5),
            MakeArtifact("a2", 60),
        };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, new RetentionPolicy(), referenceTime: Now);

        Assert.Equal(2, plan.Retained.Count);
        Assert.Empty(plan.ToDelete);
    }

    [Fact]
    public void ApplyPolicies_MaxAge_DeletesOlderArtifacts()
    {
        var artifacts = new[]
        {
            MakeArtifact("fresh",   10),
            MakeArtifact("old",     40),
            MakeArtifact("ancient", 100),
        };
        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        Assert.Single(plan.Retained);
        Assert.Equal("fresh", plan.Retained[0].Name);
        Assert.Equal(2, plan.ToDelete.Count);
        Assert.Contains(plan.ToDelete, a => a.Name == "old");
        Assert.Contains(plan.ToDelete, a => a.Name == "ancient");
    }

    [Fact]
    public void ApplyPolicies_MaxAge_ExactBoundaryArtifactIsRetained()
    {
        // An artifact created exactly MaxAgeDays ago is at the boundary:
        // age == MaxAgeDays means NOT older-than, so it should be retained.
        var artifacts = new[]
        {
            MakeArtifact("exact-boundary", 30),
        };
        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        Assert.Single(plan.Retained);
    }
}

// ============================================================
// PHASE 4: ArtifactCleanupService — max-total-size filter
// ============================================================

public class ArtifactCleanupServiceMaxSizeTests
{
    private static readonly DateTimeOffset Now = new DateTimeOffset(2025, 3, 1, 0, 0, 0, TimeSpan.Zero);

    private static Artifact MakeArtifact(string name, long sizeBytes, int daysOld = 1, string runId = "r1") =>
        new(name, sizeBytes, Now.AddDays(-daysOld), runId);

    [Fact]
    public void ApplyPolicies_MaxTotalSize_DeletesOldestWhenOverLimit()
    {
        // 3 artifacts of equal size; limit fits 2 → oldest must be evicted
        var artifacts = new[]
        {
            MakeArtifact("newest", 4 * 1024 * 1024, daysOld: 1),
            MakeArtifact("middle", 4 * 1024 * 1024, daysOld: 5),
            MakeArtifact("oldest", 4 * 1024 * 1024, daysOld: 10),
        };
        var policy = new RetentionPolicy { MaxTotalSizeBytes = 8 * 1024 * 1024 };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        Assert.Equal(2, plan.Retained.Count);
        Assert.Single(plan.ToDelete);
        Assert.Equal("oldest", plan.ToDelete[0].Name);
    }

    [Fact]
    public void ApplyPolicies_MaxTotalSize_NoEvictionWhenUnderLimit()
    {
        var artifacts = new[]
        {
            MakeArtifact("a", 1 * 1024 * 1024, daysOld: 1),
            MakeArtifact("b", 1 * 1024 * 1024, daysOld: 2),
        };
        var policy = new RetentionPolicy { MaxTotalSizeBytes = 10 * 1024 * 1024 };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        Assert.Equal(2, plan.Retained.Count);
        Assert.Empty(plan.ToDelete);
    }
}

// ============================================================
// PHASE 5: ArtifactCleanupService — keep-latest-N per workflow
//
// KeepLatestNPerWorkflow groups artifacts by WorkflowRunId.
// Within each group, only the N most-recently-created are kept.
// This covers the case where one CI run produces multiple artifacts
// (e.g. platform-specific builds) and you want to cap how many you store.
// ============================================================

public class ArtifactCleanupServiceKeepLatestNTests
{
    private static readonly DateTimeOffset Now = new DateTimeOffset(2025, 3, 1, 0, 0, 0, TimeSpan.Zero);

    // Helper — name and runId are separate so we can assert on both
    private static Artifact MakeArtifact(string name, string runId, int daysOld) =>
        new(name, 1024, Now.AddDays(-daysOld), runId);

    [Fact]
    public void ApplyPolicies_KeepLatestN_DeletesOldArtifactsWithinSameRun()
    {
        // "wf-a" run produced 4 artifacts at different times; keep only newest 2
        // "wf-b" run produced 1 artifact; already under limit, keep it
        var artifacts = new[]
        {
            MakeArtifact("wf-a-v1", "wf-a", daysOld: 10),
            MakeArtifact("wf-a-v2", "wf-a", daysOld: 8),
            MakeArtifact("wf-a-v3", "wf-a", daysOld: 5),
            MakeArtifact("wf-a-v4", "wf-a", daysOld: 2),
            MakeArtifact("wf-b-v1", "wf-b", daysOld: 3),
        };
        var policy = new RetentionPolicy { KeepLatestNPerWorkflow = 2 };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        // wf-a keeps wf-a-v3 (5d) and wf-a-v4 (2d); deletes wf-a-v1, wf-a-v2
        // wf-b keeps wf-b-v1 (only artifact)
        Assert.Equal(3, plan.Retained.Count);
        Assert.Equal(2, plan.ToDelete.Count);
        Assert.Contains(plan.ToDelete, a => a.Name == "wf-a-v1");
        Assert.Contains(plan.ToDelete, a => a.Name == "wf-a-v2");
        Assert.Contains(plan.Retained, a => a.Name == "wf-a-v3");
        Assert.Contains(plan.Retained, a => a.Name == "wf-a-v4");
        Assert.Contains(plan.Retained, a => a.Name == "wf-b-v1");
    }

    [Fact]
    public void ApplyPolicies_KeepLatestN_NoEvictionWhenUnderLimit()
    {
        var artifacts = new[]
        {
            MakeArtifact("a1", "run-1", daysOld: 5),
            MakeArtifact("a2", "run-2", daysOld: 3),
        };
        var policy = new RetentionPolicy { KeepLatestNPerWorkflow = 3 };
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        Assert.Equal(2, plan.Retained.Count);
        Assert.Empty(plan.ToDelete);
    }
}

// ============================================================
// PHASE 6: DeletionPlan summary
// ============================================================

public class DeletionPlanTests
{
    private static Artifact MakeArtifact(string name, long sizeBytes) =>
        new(name, sizeBytes, DateTimeOffset.UtcNow, "r1");

    [Fact]
    public void DeletionPlan_SpaceReclaimed_IsCorrect()
    {
        var toDelete = new List<Artifact>
        {
            MakeArtifact("a", 2 * 1024 * 1024),
            MakeArtifact("b", 3 * 1024 * 1024),
        };
        var retained = new List<Artifact>
        {
            MakeArtifact("c", 1 * 1024 * 1024),
        };

        var plan = new DeletionPlan(toDelete, retained);
        Assert.Equal(5 * 1024 * 1024, plan.SpaceReclaimedBytes);
        Assert.Equal(2, plan.DeletedCount);
        Assert.Equal(1, plan.RetainedCount);
    }

    [Fact]
    public void DeletionPlan_Summary_ContainsKeyInfo()
    {
        var toDelete = new List<Artifact>
        {
            MakeArtifact("del-1", 1024 * 1024),
        };
        var retained = new List<Artifact>
        {
            MakeArtifact("keep-1", 512 * 1024),
            MakeArtifact("keep-2", 512 * 1024),
        };
        var plan = new DeletionPlan(toDelete, retained);
        var summary = plan.GenerateSummary();

        Assert.Contains("1", summary);      // 1 deleted
        Assert.Contains("2", summary);      // 2 retained
        Assert.Contains("MB", summary);     // space reclaimed in MB
    }
}

// ============================================================
// PHASE 7: Dry-run mode
// ============================================================

public class DryRunTests
{
    private static readonly DateTimeOffset Now = new DateTimeOffset(2025, 3, 1, 0, 0, 0, TimeSpan.Zero);

    [Fact]
    public void DryRun_ReturnsCorrectPlan_WithoutActualDeletion()
    {
        var artifacts = new[]
        {
            new Artifact("stale", 1024, Now.AddDays(-60), "r1"),
            new Artifact("fresh", 1024, Now.AddDays(-5),  "r2"),
        };
        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var service = new ArtifactCleanupService();

        // dryRun: plan is computed correctly, IsDryRun flag is true
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now, dryRun: true);

        Assert.True(plan.IsDryRun);
        Assert.Single(plan.ToDelete);
        Assert.Equal("stale", plan.ToDelete[0].Name);
        Assert.Single(plan.Retained);
        Assert.Equal("fresh", plan.Retained[0].Name);
    }

    [Fact]
    public void DryRun_Summary_IndicatesDryRunMode()
    {
        var artifacts = Array.Empty<Artifact>();
        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, new RetentionPolicy(), referenceTime: Now, dryRun: true);
        var summary = plan.GenerateSummary();

        Assert.Contains("dry", summary, StringComparison.OrdinalIgnoreCase);
    }
}

// ============================================================
// PHASE 8: Combined policy application (integration-style)
//
// Validates that all three policies interact correctly when applied together.
// Policy application order: MaxAge → KeepLatestN → MaxTotalSize
// ============================================================

public class CombinedPolicyTests
{
    private static readonly DateTimeOffset Now = new DateTimeOffset(2025, 3, 1, 0, 0, 0, TimeSpan.Zero);

    [Fact]
    public void ApplyPolicies_CombinedRules_AppliesAllConstraintsInOrder()
    {
        var artifacts = new[]
        {
            // wf-1 run: ancient (>60d) deleted by MaxAge; large-old (20d old) deleted by
            // MaxTotalSize because it's the oldest survivor that tips the budget
            new Artifact("ancient",       100 * 1024, Now.AddDays(-100), "wf-1"),  // age eviction
            new Artifact("large-old",   5 * 1024 * 1024, Now.AddDays(-20),  "wf-1"),  // size eviction
            new Artifact("large-new",   5 * 1024 * 1024, Now.AddDays(-2),   "wf-1"),  // kept

            // wf-2 run: 3 artifacts, KeepLatestN=2 → wf2-v1 (50d, oldest) deleted
            new Artifact("wf2-v1",        100 * 1024, Now.AddDays(-50), "wf-2"),  // keep-latest-N eviction
            new Artifact("wf2-v2",        100 * 1024, Now.AddDays(-15), "wf-2"),  // kept
            new Artifact("wf2-v3",        100 * 1024, Now.AddDays(-5),  "wf-2"),  // kept
        };

        // Policy:
        //   MaxAge=60d       → ancient (100d old) is evicted
        //   KeepLatestN=2    → wf2-v1 evicted (3 artifacts in wf-2, keep newest 2)
        //   MaxTotalSize=8MB → survivors: large-old (20d,5MB) + large-new (2d,5MB)
        //                                + wf2-v2 (15d,100KB) + wf2-v3 (5d,100KB) ≈ 10.2MB
        //                      Evict oldest survivor (large-old) → ~5.2MB ≤ 8MB ✓
        var policy = new RetentionPolicy
        {
            MaxAgeDays             = 60,
            MaxTotalSizeBytes      = 8 * 1024 * 1024,  // 8 MB
            KeepLatestNPerWorkflow = 2,
        };

        var service = new ArtifactCleanupService();
        var plan = service.ApplyPolicies(artifacts, policy, referenceTime: Now);

        // Deleted
        Assert.DoesNotContain(plan.Retained, a => a.Name == "ancient");   // age
        Assert.DoesNotContain(plan.Retained, a => a.Name == "large-old"); // size
        Assert.DoesNotContain(plan.Retained, a => a.Name == "wf2-v1");   // keep-latest-N

        // Retained
        Assert.Contains(plan.Retained, a => a.Name == "large-new");
        Assert.Contains(plan.Retained, a => a.Name == "wf2-v2");
        Assert.Contains(plan.Retained, a => a.Name == "wf2-v3");

        // Summary: 3 deleted, 3 retained
        Assert.Equal(3, plan.ToDelete.Count);
        Assert.Equal(3, plan.Retained.Count);
    }
}
