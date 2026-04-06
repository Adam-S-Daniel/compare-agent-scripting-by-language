using ArtifactCleanup;
using Xunit;

namespace ArtifactCleanup.Tests;

/// <summary>
/// TDD Cycle 3: Tests for the keep-latest-N per workflow retention policy.
/// Only the N most recent artifacts per workflow run ID should be retained.
/// </summary>
public class KeepLatestNPolicyTests
{
    private static readonly DateTime Now = new(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void KeepLatestN_Retains_Only_N_Newest_Per_Workflow()
    {
        var artifacts = new List<Artifact>
        {
            new("build-1", 1000, Now.AddDays(-30), "workflow-A"),
            new("build-2", 1000, Now.AddDays(-20), "workflow-A"),
            new("build-3", 1000, Now.AddDays(-10), "workflow-A"),
            new("build-4", 1000, Now.AddDays(-5),  "workflow-A"),
        };

        var policy = new RetentionPolicy { KeepLatestNPerWorkflow = 2 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        // Should keep the 2 newest: build-4 (5d old), build-3 (10d old)
        Assert.Equal(2, plan.ToRetain.Count);
        Assert.Contains(plan.ToRetain, a => a.Name == "build-4");
        Assert.Contains(plan.ToRetain, a => a.Name == "build-3");

        // Should delete the 2 oldest: build-1 (30d old), build-2 (20d old)
        Assert.Equal(2, plan.ToDelete.Count);
        Assert.Contains(plan.ToDelete, a => a.Name == "build-1");
        Assert.Contains(plan.ToDelete, a => a.Name == "build-2");
    }

    [Fact]
    public void KeepLatestN_Works_Independently_Per_Workflow()
    {
        var artifacts = new List<Artifact>
        {
            new("a-old",    1000, Now.AddDays(-30), "workflow-A"),
            new("a-new",    1000, Now.AddDays(-5),  "workflow-A"),
            new("b-old",    1000, Now.AddDays(-25), "workflow-B"),
            new("b-new",    1000, Now.AddDays(-3),  "workflow-B"),
            new("b-newest", 1000, Now.AddDays(-1),  "workflow-B"),
        };

        // Keep 1 per workflow
        var policy = new RetentionPolicy { KeepLatestNPerWorkflow = 1 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        // workflow-A: keep a-new, delete a-old
        Assert.Contains(plan.ToRetain, a => a.Name == "a-new");
        Assert.Contains(plan.ToDelete, a => a.Name == "a-old");

        // workflow-B: keep b-newest, delete b-old and b-new
        Assert.Contains(plan.ToRetain, a => a.Name == "b-newest");
        Assert.Contains(plan.ToDelete, a => a.Name == "b-old");
        Assert.Contains(plan.ToDelete, a => a.Name == "b-new");

        Assert.Equal(2, plan.ToRetain.Count);
        Assert.Equal(3, plan.ToDelete.Count);
    }

    [Fact]
    public void KeepLatestN_Retains_All_When_Count_Under_Limit()
    {
        var artifacts = new List<Artifact>
        {
            new("only-one", 1000, Now.AddDays(-5), "workflow-X"),
        };

        var policy = new RetentionPolicy { KeepLatestNPerWorkflow = 5 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Single(plan.ToRetain);
        Assert.Empty(plan.ToDelete);
    }

    [Fact]
    public void KeepLatestN_Not_Applied_When_Not_Set()
    {
        var artifacts = new List<Artifact>
        {
            new("a", 1000, Now.AddDays(-100), "wf"),
            new("b", 1000, Now.AddDays(-200), "wf"),
            new("c", 1000, Now.AddDays(-300), "wf"),
        };

        var policy = new RetentionPolicy(); // no KeepLatestNPerWorkflow
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Equal(3, plan.ToRetain.Count);
        Assert.Empty(plan.ToDelete);
    }
}
