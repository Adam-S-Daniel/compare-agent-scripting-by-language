using ArtifactCleanup;
using Xunit;

namespace ArtifactCleanup.Tests;

/// <summary>
/// TDD Cycle 5: Tests for combined retention policies and deletion plan summary.
/// Multiple policies are applied in sequence: max age → keep-latest-N → max total size.
/// </summary>
public class CombinedPolicyTests
{
    private static readonly DateTime Now = new(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Combined_Policies_Apply_All_Rules()
    {
        var artifacts = new List<Artifact>
        {
            // workflow-A: 4 artifacts, one very old
            new("a-ancient", 200, Now.AddDays(-100), "workflow-A"),  // killed by max age
            new("a-old",     200, Now.AddDays(-20),  "workflow-A"),  // killed by keep-latest-2
            new("a-mid",     200, Now.AddDays(-10),  "workflow-A"),  // retained
            new("a-new",     200, Now.AddDays(-2),   "workflow-A"),  // retained

            // workflow-B: 2 artifacts
            new("b-old",     300, Now.AddDays(-15),  "workflow-B"),  // retained
            new("b-new",     300, Now.AddDays(-3),   "workflow-B"),  // retained
        };

        var policy = new RetentionPolicy
        {
            MaxAgeDays = 30,
            KeepLatestNPerWorkflow = 2,
        };

        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        // a-ancient deleted by age, a-old deleted by keep-latest-2
        Assert.Equal(2, plan.ToDelete.Count);
        Assert.Contains(plan.ToDelete, a => a.Name == "a-ancient");
        Assert.Contains(plan.ToDelete, a => a.Name == "a-old");

        // 4 retained
        Assert.Equal(4, plan.ToRetain.Count);
    }

    [Fact]
    public void Combined_All_Three_Policies()
    {
        var artifacts = new List<Artifact>
        {
            new("expired", 100, Now.AddDays(-60), "wf-1"),   // killed by age (>30d)
            new("wf1-old", 500, Now.AddDays(-25), "wf-1"),   // killed by keep-latest-1
            new("wf1-new", 500, Now.AddDays(-5),  "wf-1"),   // survives age + keep-N
            new("wf2-only", 600, Now.AddDays(-10), "wf-2"),  // survives age + keep-N
        };

        // After age+keep-N: survivors are wf1-new(500) + wf2-only(600) = 1100
        // Max total size 800 → must drop the oldest survivor (wf2-only is older? No, wf2-only is 10d, wf1-new is 5d)
        // Sorted newest first: wf1-new(500), wf2-only(600). Running total: 500, 1100 → wf2-only exceeds budget
        var policy = new RetentionPolicy
        {
            MaxAgeDays = 30,
            KeepLatestNPerWorkflow = 1,
            MaxTotalSizeBytes = 800,
        };

        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        // expired: killed by age, wf1-old: killed by keep-1, wf2-only: killed by size
        Assert.Equal(3, plan.ToDelete.Count);
        Assert.Contains(plan.ToDelete, a => a.Name == "expired");
        Assert.Contains(plan.ToDelete, a => a.Name == "wf1-old");
        Assert.Contains(plan.ToDelete, a => a.Name == "wf2-only");

        Assert.Single(plan.ToRetain);
        Assert.Equal("wf1-new", plan.ToRetain[0].Name);
    }

    [Fact]
    public void DeletionPlan_Summary_Contains_Key_Metrics()
    {
        var artifacts = new List<Artifact>
        {
            new("delete-me", 5000, Now.AddDays(-60), "wf"),
            new("keep-me",   3000, Now.AddDays(-5),  "wf"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        var summary = plan.GenerateSummary();
        Assert.Contains("Artifacts to delete: 1", summary);
        Assert.Contains("Artifacts to retain: 1", summary);
        Assert.Contains("delete-me", summary);
        Assert.Contains("keep-me", summary);
    }

    [Fact]
    public void SpaceReclaimed_Calculation_Is_Correct()
    {
        var artifacts = new List<Artifact>
        {
            new("big",   10_000, Now.AddDays(-60), "wf"),
            new("small", 1_000,  Now.AddDays(-60), "wf"),
            new("keep",  500,    Now.AddDays(-1),  "wf"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Equal(11_000, plan.SpaceReclaimedBytes);
        Assert.Equal(500, plan.SpaceRetainedBytes);
    }
}
