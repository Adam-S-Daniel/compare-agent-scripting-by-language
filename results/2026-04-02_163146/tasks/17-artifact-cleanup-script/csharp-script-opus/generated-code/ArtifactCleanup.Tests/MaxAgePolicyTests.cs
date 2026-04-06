using ArtifactCleanup;
using Xunit;

namespace ArtifactCleanup.Tests;

/// <summary>
/// TDD Cycle 1 & 2: Tests for artifact model creation and max-age retention policy.
/// Artifacts older than the configured max age should be marked for deletion.
/// </summary>
public class MaxAgePolicyTests
{
    [Fact]
    public void Artifact_Can_Be_Created_With_Required_Metadata()
    {
        var created = new DateTime(2026, 1, 15, 10, 0, 0, DateTimeKind.Utc);
        var artifact = new Artifact("build-output", sizeBytes: 1024 * 1024, created, workflowRunId: "run-100");

        Assert.Equal("build-output", artifact.Name);
        Assert.Equal(1024 * 1024, artifact.SizeBytes);
        Assert.Equal(created, artifact.CreatedAt);
        Assert.Equal("run-100", artifact.WorkflowRunId);
    }

    [Fact]
    public void MaxAge_Policy_Deletes_Artifacts_Older_Than_Threshold()
    {
        var now = new DateTime(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);
        var artifacts = new List<Artifact>
        {
            // 90 days old — should be deleted (older than 30-day max)
            new("old-artifact", 5000, now.AddDays(-90), "run-1"),
            // 10 days old — should be retained
            new("recent-artifact", 3000, now.AddDays(-10), "run-2"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Single(plan.ToDelete);
        Assert.Equal("old-artifact", plan.ToDelete[0].Name);
        Assert.Single(plan.ToRetain);
        Assert.Equal("recent-artifact", plan.ToRetain[0].Name);
    }

    [Fact]
    public void MaxAge_Policy_Retains_All_When_None_Expired()
    {
        var now = new DateTime(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);
        var artifacts = new List<Artifact>
        {
            new("a", 1000, now.AddDays(-5), "run-1"),
            new("b", 2000, now.AddDays(-10), "run-2"),
        };

        var policy = new RetentionPolicy { MaxAgeDays = 30 };
        var engine = new CleanupEngine(now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Empty(plan.ToDelete);
        Assert.Equal(2, plan.ToRetain.Count);
    }

    [Fact]
    public void MaxAge_Policy_Not_Applied_When_Not_Set()
    {
        var now = new DateTime(2026, 4, 1, 0, 0, 0, DateTimeKind.Utc);
        var artifacts = new List<Artifact>
        {
            new("ancient", 1000, now.AddDays(-365), "run-1"),
        };

        // No max age set — artifact should be retained
        var policy = new RetentionPolicy();
        var engine = new CleanupEngine(now);
        var plan = engine.BuildDeletionPlan(artifacts, policy);

        Assert.Empty(plan.ToDelete);
        Assert.Single(plan.ToRetain);
    }
}
