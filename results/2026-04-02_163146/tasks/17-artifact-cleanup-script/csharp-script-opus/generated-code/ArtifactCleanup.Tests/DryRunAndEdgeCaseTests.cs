using ArtifactCleanup;
using Xunit;

namespace ArtifactCleanup.Tests;

/// <summary>
/// TDD Cycle 6 & 7: Tests for dry-run mode and edge cases.
/// </summary>
public class DryRunAndEdgeCaseTests
{
    private static readonly DateTime Now = new(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void DryRun_Flag_Is_Reflected_In_Plan()
    {
        var artifacts = new List<Artifact>
        {
            new("old", 1000, Now.AddDays(-60), "wf"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy, dryRun: true);

        Assert.True(plan.IsDryRun);
        Assert.Single(plan.ToDelete); // still identifies what would be deleted
    }

    [Fact]
    public void DryRun_Summary_Shows_DryRun_Label()
    {
        var artifacts = new List<Artifact>
        {
            new("old", 1000, Now.AddDays(-60), "wf"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy, dryRun: true);

        var summary = plan.GenerateSummary();
        Assert.Contains("[DRY RUN]", summary);
    }

    [Fact]
    public void NonDryRun_Summary_Does_Not_Show_DryRun_Label()
    {
        var artifacts = new List<Artifact>
        {
            new("old", 1000, Now.AddDays(-60), "wf"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy, dryRun: false);

        var summary = plan.GenerateSummary();
        Assert.DoesNotContain("[DRY RUN]", summary);
    }

    [Fact]
    public void Empty_Artifact_List_Returns_Empty_Plan()
    {
        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(new List<Artifact>(), policy);

        Assert.Empty(plan.ToDelete);
        Assert.Empty(plan.ToRetain);
        Assert.Equal(0, plan.SpaceReclaimedBytes);
    }

    [Fact]
    public void All_Artifacts_Deleted_When_All_Expired()
    {
        var artifacts = new List<Artifact>
        {
            new("a", 100, Now.AddDays(-60), "wf-1"),
            new("b", 200, Now.AddDays(-90), "wf-2"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Equal(2, plan.ToDelete.Count);
        Assert.Empty(plan.ToRetain);
    }

    [Fact]
    public void All_Artifacts_Retained_When_No_Policy_Matches()
    {
        var artifacts = new List<Artifact>
        {
            new("a", 100, Now.AddDays(-1), "wf-1"),
            new("b", 200, Now.AddDays(-2), "wf-2"),
        };

        // All policies set but nothing triggers
        var policy = new RetentionPolicy
        {
            MaxAgeDays = 365,
            KeepLatestNPerWorkflow = 10,
            MaxTotalSizeBytes = 999_999,
        };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Empty(plan.ToDelete);
        Assert.Equal(2, plan.ToRetain.Count);
    }

    [Fact]
    public void Null_Artifacts_Throws_ArgumentNullException()
    {
        var policy = new RetentionPolicy();
        var engine = new CleanupEngine(Now);

        Assert.Throws<ArgumentNullException>(() =>
            engine.BuildDeletionPlan(null!, policy));
    }

    [Fact]
    public void Null_Policy_Throws_ArgumentNullException()
    {
        var engine = new CleanupEngine(Now);

        Assert.Throws<ArgumentNullException>(() =>
            engine.BuildDeletionPlan(new List<Artifact>(), null!));
    }

    [Fact]
    public void No_Policies_Set_Retains_Everything()
    {
        var artifacts = new List<Artifact>
        {
            new("a", 500, Now.AddDays(-365), "wf"),
            new("b", 600, Now.AddDays(-730), "wf"),
        };

        var policy = new RetentionPolicy(); // all null = no filtering
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Empty(plan.ToDelete);
        Assert.Equal(2, plan.ToRetain.Count);
    }

    [Fact]
    public void Artifacts_At_Exact_Age_Boundary_Are_Retained()
    {
        // An artifact created exactly MaxAgeDays ago should be retained (not strictly older)
        var artifacts = new List<Artifact>
        {
            new("boundary", 100, Now.AddDays(-30), "wf"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(Now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        // Exactly 30 days old with max age of 30 → cutoff is Now - 30 days = same time → NOT older → retained
        Assert.Empty(plan.ToDelete);
        Assert.Single(plan.ToRetain);
    }
}
