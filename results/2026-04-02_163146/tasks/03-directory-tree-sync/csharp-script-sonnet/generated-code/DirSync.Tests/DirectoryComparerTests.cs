// RED phase: Tests for DirectoryComparer
// Verifies that comparing two mock directory trees produces correct FileComparison results.

using DirSyncLib;
using Xunit;

namespace DirSync.Tests;

public class DirectoryComparerTests
{
    // Helpers to build a predictable mock filesystem
    private static MockFileSystem BuildFs(
        string srcRoot, string tgtRoot,
        (string rel, string? srcContent, string? tgtContent)[] files)
    {
        var fs = new MockFileSystem();
        foreach (var (rel, src, tgt) in files)
        {
            if (src != null) fs.AddFile($"{srcRoot}/{rel}", src);
            if (tgt != null) fs.AddFile($"{tgtRoot}/{rel}", tgt);
        }
        return fs;
    }

    // Test 1: Identical trees → all files reported as Identical
    [Fact]
    public void Compare_IdenticalTrees_ReturnsAllIdentical()
    {
        var fs = BuildFs("/src", "/tgt", [
            ("a.txt", "hello", "hello"),
            ("sub/b.txt", "world", "world"),
        ]);
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/src", "/tgt");

        Assert.Equal(2, results.Count);
        Assert.All(results, r => Assert.Equal(FileStatus.Identical, r.Status));
    }

    // Test 2: File exists only in source → SourceOnly
    [Fact]
    public void Compare_FileOnlyInSource_ReturnsSourceOnly()
    {
        var fs = BuildFs("/src", "/tgt", [
            ("only-src.txt", "data", null),
        ]);
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/src", "/tgt");

        Assert.Single(results);
        Assert.Equal("only-src.txt", results[0].RelativePath);
        Assert.Equal(FileStatus.SourceOnly, results[0].Status);
        Assert.NotNull(results[0].SourceHash);
        Assert.Null(results[0].TargetHash);
    }

    // Test 3: File exists only in target → TargetOnly
    [Fact]
    public void Compare_FileOnlyInTarget_ReturnsTargetOnly()
    {
        var fs = BuildFs("/src", "/tgt", [
            ("only-tgt.txt", null, "data"),
        ]);
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/src", "/tgt");

        Assert.Single(results);
        Assert.Equal("only-tgt.txt", results[0].RelativePath);
        Assert.Equal(FileStatus.TargetOnly, results[0].Status);
        Assert.Null(results[0].SourceHash);
        Assert.NotNull(results[0].TargetHash);
    }

    // Test 4: File exists in both but with different content → Modified
    [Fact]
    public void Compare_DifferentContent_ReturnsModified()
    {
        var fs = BuildFs("/src", "/tgt", [
            ("changed.txt", "version 1", "version 2"),
        ]);
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/src", "/tgt");

        Assert.Single(results);
        Assert.Equal(FileStatus.Modified, results[0].Status);
        Assert.NotNull(results[0].SourceHash);
        Assert.NotNull(results[0].TargetHash);
        Assert.NotEqual(results[0].SourceHash, results[0].TargetHash);
    }

    // Test 5: Mixed scenario — some identical, some modified, some only in each
    [Fact]
    public void Compare_MixedScenario_ReturnsCorrectStatuses()
    {
        var fs = BuildFs("/src", "/tgt", [
            ("same.txt",      "same content", "same content"),
            ("modified.txt",  "old version",  "new version"),
            ("src-only.txt",  "in src",       null),
            ("tgt-only.txt",  null,           "in tgt"),
        ]);
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/src", "/tgt").ToDictionary(r => r.RelativePath);

        Assert.Equal(FileStatus.Identical,  results["same.txt"].Status);
        Assert.Equal(FileStatus.Modified,   results["modified.txt"].Status);
        Assert.Equal(FileStatus.SourceOnly, results["src-only.txt"].Status);
        Assert.Equal(FileStatus.TargetOnly, results["tgt-only.txt"].Status);
    }

    // Test 6: Empty directories → no comparisons
    [Fact]
    public void Compare_EmptyDirectories_ReturnsEmptyList()
    {
        var fs = new MockFileSystem();
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/empty-src", "/empty-tgt");

        Assert.Empty(results);
    }

    // Test 7: Nested directories are handled correctly
    [Fact]
    public void Compare_NestedFiles_UsesRelativePaths()
    {
        var fs = BuildFs("/src", "/tgt", [
            ("dir1/dir2/deep.txt", "content", "content"),
        ]);
        var comparer = new DirectoryComparer(fs);

        var results = comparer.Compare("/src", "/tgt");

        Assert.Single(results);
        Assert.Equal("dir1/dir2/deep.txt", results[0].RelativePath);
    }
}
