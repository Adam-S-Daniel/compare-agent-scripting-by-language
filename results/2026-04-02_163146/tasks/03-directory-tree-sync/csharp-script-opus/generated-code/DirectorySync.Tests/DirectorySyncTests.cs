// TDD Step 1: Write failing tests for directory tree comparison and sync.
// We test each piece of functionality independently using temp directories as mocks.

using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Xunit;

namespace DirectorySync.Tests;

/// <summary>
/// Helper to create temporary directory structures for testing.
/// Each test gets isolated source/target directories that are cleaned up automatically.
/// </summary>
public class TempDirFixture : IDisposable
{
    public string Source { get; }
    public string Target { get; }

    public TempDirFixture()
    {
        var basePath = Path.Combine(Path.GetTempPath(), "dirsync-test-" + Guid.NewGuid().ToString("N")[..8]);
        Source = Path.Combine(basePath, "source");
        Target = Path.Combine(basePath, "target");
        Directory.CreateDirectory(Source);
        Directory.CreateDirectory(Target);
    }

    /// <summary>Create a file with given content relative to source directory.</summary>
    public void CreateSourceFile(string relativePath, string content)
    {
        var fullPath = Path.Combine(Source, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        File.WriteAllText(fullPath, content);
    }

    /// <summary>Create a file with given content relative to target directory.</summary>
    public void CreateTargetFile(string relativePath, string content)
    {
        var fullPath = Path.Combine(Target, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        File.WriteAllText(fullPath, content);
    }

    public void Dispose()
    {
        var basePath = Path.GetDirectoryName(Source)!;
        if (Directory.Exists(basePath))
            Directory.Delete(basePath, recursive: true);
    }
}

#region Comparison Tests

public class DirectoryComparisonTests : IDisposable
{
    private readonly TempDirFixture _fixture = new();

    public void Dispose() => _fixture.Dispose();

    [Fact]
    public void IdentifiesFilesOnlyInSource()
    {
        // Arrange: file exists only in source
        _fixture.CreateSourceFile("unique.txt", "hello");

        // Act
        var result = DirectoryComparer.Compare(_fixture.Source, _fixture.Target);

        // Assert: file should appear in SourceOnly list
        Assert.Single(result.SourceOnly);
        Assert.Equal("unique.txt", result.SourceOnly[0]);
    }

    [Fact]
    public void IdentifiesFilesOnlyInTarget()
    {
        // Arrange: file exists only in target
        _fixture.CreateTargetFile("orphan.txt", "world");

        // Act
        var result = DirectoryComparer.Compare(_fixture.Source, _fixture.Target);

        // Assert
        Assert.Single(result.TargetOnly);
        Assert.Equal("orphan.txt", result.TargetOnly[0]);
    }

    [Fact]
    public void IdentifiesIdenticalFiles()
    {
        // Arrange: same file with same content in both trees
        _fixture.CreateSourceFile("same.txt", "identical content");
        _fixture.CreateTargetFile("same.txt", "identical content");

        // Act
        var result = DirectoryComparer.Compare(_fixture.Source, _fixture.Target);

        // Assert
        Assert.Single(result.Identical);
        Assert.Equal("same.txt", result.Identical[0]);
        Assert.Empty(result.Different);
    }

    [Fact]
    public void IdentifiesModifiedFiles_BySHA256Hash()
    {
        // Arrange: same filename, different content → different SHA-256 hash
        _fixture.CreateSourceFile("changed.txt", "version 1");
        _fixture.CreateTargetFile("changed.txt", "version 2");

        // Act
        var result = DirectoryComparer.Compare(_fixture.Source, _fixture.Target);

        // Assert
        Assert.Single(result.Different);
        Assert.Equal("changed.txt", result.Different[0]);
        Assert.Empty(result.Identical);
    }

    [Fact]
    public void HandlesNestedDirectories()
    {
        // Arrange: files in subdirectories
        _fixture.CreateSourceFile("sub/dir/file.txt", "nested");
        _fixture.CreateTargetFile("sub/dir/file.txt", "nested changed");
        _fixture.CreateSourceFile("sub/only-src.txt", "src");
        _fixture.CreateTargetFile("other/only-tgt.txt", "tgt");

        // Act
        var result = DirectoryComparer.Compare(_fixture.Source, _fixture.Target);

        // Assert
        Assert.Contains(Path.Combine("sub", "dir", "file.txt"), result.Different);
        Assert.Contains(Path.Combine("sub", "only-src.txt"), result.SourceOnly);
        Assert.Contains(Path.Combine("other", "only-tgt.txt"), result.TargetOnly);
    }

    [Fact]
    public void HandlesEmptyDirectories()
    {
        // Both directories are empty — no files to compare
        var result = DirectoryComparer.Compare(_fixture.Source, _fixture.Target);

        Assert.Empty(result.SourceOnly);
        Assert.Empty(result.TargetOnly);
        Assert.Empty(result.Different);
        Assert.Empty(result.Identical);
    }
}

#endregion

#region Sync Plan Tests

public class SyncPlanTests : IDisposable
{
    private readonly TempDirFixture _fixture = new();

    public void Dispose() => _fixture.Dispose();

    [Fact]
    public void DryRun_GeneratesReport_WithoutModifyingFiles()
    {
        // Arrange
        _fixture.CreateSourceFile("new.txt", "new content");
        _fixture.CreateSourceFile("modified.txt", "source version");
        _fixture.CreateTargetFile("modified.txt", "target version");
        _fixture.CreateTargetFile("extra.txt", "to delete");

        // Act: dry-run should produce a plan but NOT change any files
        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);
        var report = plan.GenerateReport();

        // Assert: report should list all planned actions
        Assert.Contains("new.txt", report);
        Assert.Contains("modified.txt", report);
        Assert.Contains("extra.txt", report);

        // Files should NOT have been modified
        Assert.False(File.Exists(Path.Combine(_fixture.Target, "new.txt")));
        Assert.Equal("target version", File.ReadAllText(Path.Combine(_fixture.Target, "modified.txt")));
        Assert.True(File.Exists(Path.Combine(_fixture.Target, "extra.txt")));
    }

    [Fact]
    public void Plan_ContainsCopyActions_ForSourceOnlyFiles()
    {
        _fixture.CreateSourceFile("new-file.txt", "content");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);

        Assert.Single(plan.Actions.Where(a => a.Type == SyncActionType.Copy));
        Assert.Equal("new-file.txt", plan.Actions.First(a => a.Type == SyncActionType.Copy).RelativePath);
    }

    [Fact]
    public void Plan_ContainsUpdateActions_ForDifferentFiles()
    {
        _fixture.CreateSourceFile("changed.txt", "new");
        _fixture.CreateTargetFile("changed.txt", "old");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);

        Assert.Single(plan.Actions.Where(a => a.Type == SyncActionType.Update));
    }

    [Fact]
    public void Plan_ContainsDeleteActions_ForTargetOnlyFiles()
    {
        _fixture.CreateTargetFile("orphan.txt", "will be removed");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);

        Assert.Single(plan.Actions.Where(a => a.Type == SyncActionType.Delete));
    }
}

#endregion

#region Sync Execution Tests

public class SyncExecutionTests : IDisposable
{
    private readonly TempDirFixture _fixture = new();

    public void Dispose() => _fixture.Dispose();

    [Fact]
    public void Execute_CopiesNewFilesToTarget()
    {
        _fixture.CreateSourceFile("brand-new.txt", "fresh content");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);
        SyncExecutor.Execute(plan, _fixture.Source, _fixture.Target);

        // File should now exist in target with same content
        var targetFile = Path.Combine(_fixture.Target, "brand-new.txt");
        Assert.True(File.Exists(targetFile));
        Assert.Equal("fresh content", File.ReadAllText(targetFile));
    }

    [Fact]
    public void Execute_UpdatesModifiedFiles()
    {
        _fixture.CreateSourceFile("file.txt", "updated content");
        _fixture.CreateTargetFile("file.txt", "old content");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);
        SyncExecutor.Execute(plan, _fixture.Source, _fixture.Target);

        Assert.Equal("updated content", File.ReadAllText(Path.Combine(_fixture.Target, "file.txt")));
    }

    [Fact]
    public void Execute_DeletesTargetOnlyFiles()
    {
        _fixture.CreateTargetFile("stale.txt", "remove me");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);
        SyncExecutor.Execute(plan, _fixture.Source, _fixture.Target);

        Assert.False(File.Exists(Path.Combine(_fixture.Target, "stale.txt")));
    }

    [Fact]
    public void Execute_HandlesNestedDirectoryCreation()
    {
        _fixture.CreateSourceFile("a/b/c/deep.txt", "deep content");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);
        SyncExecutor.Execute(plan, _fixture.Source, _fixture.Target);

        var targetFile = Path.Combine(_fixture.Target, "a", "b", "c", "deep.txt");
        Assert.True(File.Exists(targetFile));
        Assert.Equal("deep content", File.ReadAllText(targetFile));
    }

    [Fact]
    public void Execute_FullSync_MakesTargetMatchSource()
    {
        // Complex scenario: multiple files, some shared, some unique to each side
        _fixture.CreateSourceFile("keep.txt", "same");
        _fixture.CreateTargetFile("keep.txt", "same");
        _fixture.CreateSourceFile("add.txt", "new");
        _fixture.CreateSourceFile("update.txt", "v2");
        _fixture.CreateTargetFile("update.txt", "v1");
        _fixture.CreateTargetFile("remove.txt", "gone");

        var plan = SyncPlanner.CreatePlan(_fixture.Source, _fixture.Target);
        SyncExecutor.Execute(plan, _fixture.Source, _fixture.Target);

        // After sync, target should mirror source exactly
        Assert.True(File.Exists(Path.Combine(_fixture.Target, "keep.txt")));
        Assert.True(File.Exists(Path.Combine(_fixture.Target, "add.txt")));
        Assert.Equal("v2", File.ReadAllText(Path.Combine(_fixture.Target, "update.txt")));
        Assert.False(File.Exists(Path.Combine(_fixture.Target, "remove.txt")));
    }
}

#endregion

#region Error Handling Tests

public class ErrorHandlingTests : IDisposable
{
    private readonly TempDirFixture _fixture = new();

    public void Dispose() => _fixture.Dispose();

    [Fact]
    public void Compare_ThrowsForNonexistentSourceDirectory()
    {
        var ex = Assert.Throws<DirectoryNotFoundException>(
            () => DirectoryComparer.Compare("/nonexistent/path", _fixture.Target));
        Assert.Contains("Source directory", ex.Message);
    }

    [Fact]
    public void Compare_ThrowsForNonexistentTargetDirectory()
    {
        var ex = Assert.Throws<DirectoryNotFoundException>(
            () => DirectoryComparer.Compare(_fixture.Source, "/nonexistent/path"));
        Assert.Contains("Target directory", ex.Message);
    }
}

#endregion
