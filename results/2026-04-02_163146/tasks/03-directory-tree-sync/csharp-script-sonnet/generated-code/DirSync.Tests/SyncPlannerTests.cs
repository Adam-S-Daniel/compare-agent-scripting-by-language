// RED phase: Tests for SyncPlanner
// Verifies that the planner converts FileComparisons into the correct SyncOperations.

using DirSyncLib;
using Xunit;

namespace DirSync.Tests;

public class SyncPlannerTests
{
    private const string Src = "/src";
    private const string Tgt = "/tgt";

    // Test 1: SourceOnly file → Copy operation
    [Fact]
    public void CreatePlan_SourceOnlyFile_GeneratesCopyOperation()
    {
        var comparisons = new[]
        {
            new FileComparison("new.txt", FileStatus.SourceOnly, "abc123", null)
        };
        var planner = new SyncPlanner();

        var plan = planner.CreatePlan(comparisons, Src, Tgt);

        Assert.Single(plan.Operations);
        var op = plan.Operations[0];
        Assert.Equal(SyncAction.Copy, op.Action);
        Assert.Equal("new.txt", op.RelativePath);
        Assert.Equal("/src/new.txt", op.SourcePath);
        Assert.Equal("/tgt/new.txt", op.TargetPath);
    }

    // Test 2: Modified file → Update operation
    [Fact]
    public void CreatePlan_ModifiedFile_GeneratesUpdateOperation()
    {
        var comparisons = new[]
        {
            new FileComparison("changed.txt", FileStatus.Modified, "hash1", "hash2")
        };
        var planner = new SyncPlanner();

        var plan = planner.CreatePlan(comparisons, Src, Tgt);

        Assert.Single(plan.Operations);
        Assert.Equal(SyncAction.Update, plan.Operations[0].Action);
    }

    // Test 3: Identical file → no operation generated
    [Fact]
    public void CreatePlan_IdenticalFile_GeneratesNoOperation()
    {
        var comparisons = new[]
        {
            new FileComparison("same.txt", FileStatus.Identical, "hash1", "hash1")
        };
        var planner = new SyncPlanner();

        var plan = planner.CreatePlan(comparisons, Src, Tgt);

        Assert.Empty(plan.Operations);
    }

    // Test 4: TargetOnly file → Delete operation
    [Fact]
    public void CreatePlan_TargetOnlyFile_GeneratesDeleteOperation()
    {
        var comparisons = new[]
        {
            new FileComparison("orphan.txt", FileStatus.TargetOnly, null, "oldhash")
        };
        var planner = new SyncPlanner();

        var plan = planner.CreatePlan(comparisons, Src, Tgt);

        Assert.Single(plan.Operations);
        var op = plan.Operations[0];
        Assert.Equal(SyncAction.Delete, op.Action);
        Assert.Equal("/tgt/orphan.txt", op.TargetPath);
    }

    // Test 5: Mixed comparisons → correct mix of operations
    [Fact]
    public void CreatePlan_MixedComparisons_GeneratesCorrectOperations()
    {
        var comparisons = new[]
        {
            new FileComparison("same.txt",    FileStatus.Identical,   "h1", "h1"),
            new FileComparison("new.txt",     FileStatus.SourceOnly,  "h2", null),
            new FileComparison("changed.txt", FileStatus.Modified,    "h3", "h4"),
            new FileComparison("old.txt",     FileStatus.TargetOnly,  null, "h5"),
        };
        var planner = new SyncPlanner();

        var plan = planner.CreatePlan(comparisons, Src, Tgt);

        Assert.Equal(3, plan.Operations.Count);

        var byPath = plan.Operations.ToDictionary(o => o.RelativePath);
        Assert.Equal(SyncAction.Copy,   byPath["new.txt"].Action);
        Assert.Equal(SyncAction.Update, byPath["changed.txt"].Action);
        Assert.Equal(SyncAction.Delete, byPath["old.txt"].Action);
        Assert.False(byPath.ContainsKey("same.txt"));
    }

    // Test 6: Plan stores source and target roots
    [Fact]
    public void CreatePlan_StoresSrcAndTgtRoots()
    {
        var planner = new SyncPlanner();
        var plan = planner.CreatePlan([], Src, Tgt);

        Assert.Equal(Src, plan.SourceRoot);
        Assert.Equal(Tgt, plan.TargetRoot);
    }
}
