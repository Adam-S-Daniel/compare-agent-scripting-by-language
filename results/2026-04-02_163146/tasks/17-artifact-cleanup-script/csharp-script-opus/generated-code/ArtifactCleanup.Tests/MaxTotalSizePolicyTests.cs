using ArtifactCleanup;
using Xunit;

namespace ArtifactCleanup.Tests;

/// <summary>
/// TDD Cycle 4: Tests for the max total size retention policy.
/// When total size of retained artifacts exceeds the limit, oldest artifacts
/// are deleted until the total fits within budget.
/// </summary>
public class MaxTotalSizePolicyTests
{
    private static readonly DateTime Now = new(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void MaxTotalSize_Deletes_Oldest_Until_Under_Budget()
    {
        var artifacts = new List<Artifact>
        {
            new("oldest",  500, Now.AddDays(-30), "wf-1"),
            new("middle",  500, Now.AddDays(-20), "wf-1"),
            new("newest",  500, Now.AddDays(-10), "wf-1"),
        };

        // Total is 1500, budget is 1000 — must delete oldest (500 bytes) to fit
        var policy = new RetentionPolicy { MaxTotalSizeBytes = 1000 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Single(plan.ToDelete);
        Assert.Equal("oldest", plan.ToDelete[0].Name);
        Assert.Equal(2, plan.ToRetain.Count);
    }

    [Fact]
    public void MaxTotalSize_Deletes_Multiple_Until_Under_Budget()
    {
        var artifacts = new List<Artifact>
        {
            new("a", 400, Now.AddDays(-40), "wf"),
            new("b", 400, Now.AddDays(-30), "wf"),
            new("c", 400, Now.AddDays(-20), "wf"),
            new("d", 400, Now.AddDays(-10), "wf"),
        };

        // Total is 1600, budget is 800 — need to delete the 2 oldest
        var policy = new RetentionPolicy { MaxTotalSizeBytes = 800 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Equal(2, plan.ToDelete.Count);
        Assert.Contains(plan.ToDelete, a => a.Name == "a");
        Assert.Contains(plan.ToDelete, a => a.Name == "b");
        Assert.Equal(2, plan.ToRetain.Count);
    }

    [Fact]
    public void MaxTotalSize_Retains_All_When_Under_Budget()
    {
        var artifacts = new List<Artifact>
        {
            new("small-a", 100, Now.AddDays(-10), "wf"),
            new("small-b", 100, Now.AddDays(-5), "wf"),
        };

        var policy = new RetentionPolicy { MaxTotalSizeBytes = 1000 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Empty(plan.ToDelete);
        Assert.Equal(2, plan.ToRetain.Count);
    }

    [Fact]
    public void MaxTotalSize_Not_Applied_When_Not_Set()
    {
        var artifacts = new List<Artifact>
        {
            new("huge", 999_999_999, Now.AddDays(-10), "wf"),
        };

        var policy = new RetentionPolicy(); // no MaxTotalSizeBytes
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Single(plan.ToRetain);
        Assert.Empty(plan.ToDelete);
    }
}
