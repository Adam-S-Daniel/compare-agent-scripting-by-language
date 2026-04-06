// TDD RED: Tests for glob-based file finding.
// These tests create temporary directory structures and verify that
// FindFiles correctly matches files using glob patterns.

using Xunit;

public class FindFilesTests : IDisposable
{
    private readonly string _tempDir;

    public FindFilesTests()
    {
        // Create a unique temp directory for each test run
        _tempDir = Path.Combine(Path.GetTempPath(), "sr_test_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, recursive: true);
    }

    private void CreateFile(string relativePath, string content = "")
    {
        var fullPath = Path.Combine(_tempDir, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        File.WriteAllText(fullPath, content);
    }

    [Fact]
    public void FindFiles_MatchesTxtGlob_ReturnsOnlyTxtFiles()
    {
        // Arrange: create a mix of .txt and .cs files
        CreateFile("a.txt", "hello");
        CreateFile("b.cs", "world");
        CreateFile("sub/c.txt", "nested");

        // Act
        var result = SearchReplaceTool.FindFiles(_tempDir, "**/*.txt");

        // Assert: should find only .txt files
        Assert.Equal(2, result.Count);
        Assert.All(result, f => Assert.EndsWith(".txt", f));
    }

    [Fact]
    public void FindFiles_NoMatches_ReturnsEmptyList()
    {
        CreateFile("a.txt");

        var result = SearchReplaceTool.FindFiles(_tempDir, "**/*.json");

        Assert.Empty(result);
    }

    [Fact]
    public void FindFiles_NestedDirectories_FindsFilesRecursively()
    {
        CreateFile("level1/level2/level3/deep.log");
        CreateFile("level1/shallow.log");

        var result = SearchReplaceTool.FindFiles(_tempDir, "**/*.log");

        Assert.Equal(2, result.Count);
    }

    [Fact]
    public void FindFiles_SpecificSubdirectory_RestrictsSearch()
    {
        CreateFile("src/app.cs");
        CreateFile("test/app.cs");

        var result = SearchReplaceTool.FindFiles(_tempDir, "src/**/*.cs");

        Assert.Single(result);
        Assert.Contains("src", result[0]);
    }

    [Fact]
    public void FindFiles_ReturnsAbsolutePaths()
    {
        CreateFile("file.txt", "data");

        var result = SearchReplaceTool.FindFiles(_tempDir, "**/*.txt");

        Assert.Single(result);
        Assert.True(Path.IsPathRooted(result[0]), "Returned paths should be absolute");
    }
}
