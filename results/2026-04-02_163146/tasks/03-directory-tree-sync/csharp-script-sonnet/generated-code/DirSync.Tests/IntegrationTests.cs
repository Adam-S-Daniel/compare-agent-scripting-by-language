// Integration tests: wire up Compare → Plan → Execute/DryRun end-to-end.
// All I/O is through MockFileSystem so no disk access occurs.

using DirSyncLib;
using Xunit;

namespace DirSync.Tests;

public class IntegrationTests
{
    private static MockFileSystem BuildMixedScenario()
    {
        var fs = new MockFileSystem();

        // identical in both trees
        fs.AddFile("/src/config.json",   """{"version":1}""");
        fs.AddFile("/tgt/config.json",   """{"version":1}""");

        // modified: different content
        fs.AddFile("/src/data.csv",      "id,name\n1,Alice");
        fs.AddFile("/tgt/data.csv",      "id,name\n1,Bob");

        // source-only: needs to be copied
        fs.AddFile("/src/new-feature.txt", "feature content");

        // target-only: should be deleted
        fs.AddFile("/tgt/deprecated.txt", "old stuff");

        // nested modified file
        fs.AddFile("/src/sub/report.txt", "report v2");
        fs.AddFile("/tgt/sub/report.txt", "report v1");

        return fs;
    }

    [Fact]
    public void FullPipeline_DryRun_ReportsCorrectly_NoChanges()
    {
        var fs = BuildMixedScenario();
        var comparer = new DirectoryComparer(fs);
        var planner  = new SyncPlanner();
        var executor = new SyncExecutor(fs);

        var comparisons = comparer.Compare("/src", "/tgt");
        var plan        = planner.CreatePlan(comparisons, "/src", "/tgt");
        var result      = executor.DryRun(plan);

        // 1 copy, 2 updates (data.csv + sub/report.txt), 1 delete
        Assert.Equal(1, result.Copied);
        Assert.Equal(2, result.Updated);
        Assert.Equal(1, result.Deleted);
        Assert.True(result.IsDryRun);

        // Filesystem unchanged
        Assert.False(fs.FileExists("/tgt/new-feature.txt"));
        Assert.True(fs.FileExists("/tgt/deprecated.txt"));
        Assert.Equal("report v1", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/sub/report.txt")));
    }

    [Fact]
    public void FullPipeline_Execute_SyncsAllFiles()
    {
        var fs = BuildMixedScenario();
        var comparer = new DirectoryComparer(fs);
        var planner  = new SyncPlanner();
        var executor = new SyncExecutor(fs);

        var comparisons = comparer.Compare("/src", "/tgt");
        var plan        = planner.CreatePlan(comparisons, "/src", "/tgt");
        var result      = executor.Execute(plan);

        Assert.False(result.IsDryRun);
        Assert.Empty(result.Errors);

        // new-feature.txt was copied
        Assert.True(fs.FileExists("/tgt/new-feature.txt"));

        // data.csv updated to source version
        Assert.Equal("id,name\n1,Alice", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/data.csv")));

        // deprecated.txt deleted
        Assert.False(fs.FileExists("/tgt/deprecated.txt"));

        // sub/report.txt updated
        Assert.Equal("report v2", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/sub/report.txt")));

        // config.json unchanged
        Assert.Equal("""{"version":1}""", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/config.json")));
    }

    [Fact]
    public void FullPipeline_AfterExecute_RetreeShowsNoChangesNeeded()
    {
        var fs = BuildMixedScenario();
        var comparer = new DirectoryComparer(fs);
        var planner  = new SyncPlanner();
        var executor = new SyncExecutor(fs);

        // First sync
        var comparisons = comparer.Compare("/src", "/tgt");
        var plan = planner.CreatePlan(comparisons, "/src", "/tgt");
        executor.Execute(plan);

        // Second comparison should show all files as Identical (no target-only or source-only)
        var comparisons2 = comparer.Compare("/src", "/tgt");
        Assert.All(comparisons2, c => Assert.Equal(FileStatus.Identical, c.Status));

        var plan2 = planner.CreatePlan(comparisons2, "/src", "/tgt");
        Assert.Empty(plan2.Operations);
    }
}
