// RED phase: Tests for SyncExecutor
// Verifies dry-run (no changes) and execute (real changes) using MockFileSystem.

using DirSyncLib;
using Xunit;

namespace DirSync.Tests;

public class SyncExecutorTests
{
    // ---- Dry-run tests -------------------------------------------------------

    // Test 1: Dry-run reports the operations but does NOT change the filesystem
    [Fact]
    public void DryRun_ReportsOperations_DoesNotModifyFilesystem()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/new.txt", "new content");
        // /tgt/new.txt does NOT exist — plan says copy it

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Copy, "new.txt", "/src/new.txt", "/tgt/new.txt")
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.DryRun(plan);

        // Result metadata
        Assert.True(result.IsDryRun);
        Assert.Equal(1, result.Copied);
        Assert.Equal(0, result.Errors.Count);

        // Filesystem NOT changed
        Assert.False(fs.FileExists("/tgt/new.txt"));
    }

    // Test 2: Dry-run counts all operation types correctly
    [Fact]
    public void DryRun_CountsAllOperationTypes()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/copy-me.txt",   "data");
        fs.AddFile("/src/update-me.txt", "new data");
        fs.AddFile("/tgt/delete-me.txt", "old data");

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Copy,   "copy-me.txt",   "/src/copy-me.txt",   "/tgt/copy-me.txt"),
            new SyncOperation(SyncAction.Update, "update-me.txt", "/src/update-me.txt", "/tgt/update-me.txt"),
            new SyncOperation(SyncAction.Delete, "delete-me.txt", "/src/delete-me.txt", "/tgt/delete-me.txt"),
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.DryRun(plan);

        Assert.Equal(1, result.Copied);
        Assert.Equal(1, result.Updated);
        Assert.Equal(1, result.Deleted);
        Assert.Equal(0, result.Errors.Count);

        // No actual changes
        Assert.False(fs.FileExists("/tgt/copy-me.txt"));
        Assert.False(fs.FileExists("/tgt/update-me.txt"));
        Assert.True(fs.FileExists("/tgt/delete-me.txt")); // still there
    }

    // ---- Execute tests -------------------------------------------------------

    // Test 3: Execute copies a new file from source to target
    [Fact]
    public void Execute_CopyOperation_CopiesFileToTarget()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/new.txt", "new content");

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Copy, "new.txt", "/src/new.txt", "/tgt/new.txt")
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.Execute(plan);

        Assert.False(result.IsDryRun);
        Assert.Equal(1, result.Copied);
        Assert.True(fs.FileExists("/tgt/new.txt"));
        Assert.Equal("new content", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/new.txt")));
    }

    // Test 4: Execute updates (overwrites) a modified file in target
    [Fact]
    public void Execute_UpdateOperation_OverwritesTargetFile()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/file.txt", "updated content");
        fs.AddFile("/tgt/file.txt", "old content");

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Update, "file.txt", "/src/file.txt", "/tgt/file.txt")
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.Execute(plan);

        Assert.Equal(1, result.Updated);
        Assert.Equal("updated content", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/file.txt")));
    }

    // Test 5: Execute deletes a target-only file
    [Fact]
    public void Execute_DeleteOperation_RemovesFileFromTarget()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/tgt/orphan.txt", "should be gone");

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Delete, "orphan.txt", "/src/orphan.txt", "/tgt/orphan.txt")
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.Execute(plan);

        Assert.Equal(1, result.Deleted);
        Assert.False(fs.FileExists("/tgt/orphan.txt"));
    }

    // Test 6: Execute handles a missing source file gracefully (error, not crash)
    [Fact]
    public void Execute_MissingSourceFile_RecordsErrorContinues()
    {
        var fs = new MockFileSystem();
        // Source file deliberately absent

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Copy, "missing.txt", "/src/missing.txt", "/tgt/missing.txt")
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.Execute(plan);

        Assert.Equal(1, result.Errors.Count);
        Assert.Contains("missing.txt", result.Errors[0]);
    }

    // Test 7: Execute full sync scenario end-to-end
    [Fact]
    public void Execute_FullSync_AllOperationsApplied()
    {
        var fs = new MockFileSystem();
        fs.AddFile("/src/copy-me.txt",   "fresh file");
        fs.AddFile("/src/update-me.txt", "updated version");
        fs.AddFile("/tgt/update-me.txt", "old version");
        fs.AddFile("/tgt/delete-me.txt", "stale file");

        var plan = new SyncPlan("/src", "/tgt", [
            new SyncOperation(SyncAction.Copy,   "copy-me.txt",   "/src/copy-me.txt",   "/tgt/copy-me.txt"),
            new SyncOperation(SyncAction.Update, "update-me.txt", "/src/update-me.txt", "/tgt/update-me.txt"),
            new SyncOperation(SyncAction.Delete, "delete-me.txt", "/src/delete-me.txt", "/tgt/delete-me.txt"),
        ]);

        var executor = new SyncExecutor(fs);
        var result = executor.Execute(plan);

        Assert.Equal(1, result.Copied);
        Assert.Equal(1, result.Updated);
        Assert.Equal(1, result.Deleted);
        Assert.Empty(result.Errors);

        Assert.True(fs.FileExists("/tgt/copy-me.txt"));
        Assert.Equal("updated version", System.Text.Encoding.UTF8.GetString(fs.ReadAllBytes("/tgt/update-me.txt")));
        Assert.False(fs.FileExists("/tgt/delete-me.txt"));
    }
}
