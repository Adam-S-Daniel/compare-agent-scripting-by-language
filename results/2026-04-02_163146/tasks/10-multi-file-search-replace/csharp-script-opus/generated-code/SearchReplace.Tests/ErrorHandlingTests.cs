// TDD RED → GREEN: Tests for error handling.
// Verifies graceful handling of invalid inputs, missing files, and bad patterns.

using Xunit;

public class ErrorHandlingTests : IDisposable
{
    private readonly string _tempDir;

    public ErrorHandlingTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "sr_error_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, recursive: true);
    }

    [Fact]
    public void FindFiles_NonExistentDirectory_ThrowsWithMessage()
    {
        var ex = Assert.Throws<DirectoryNotFoundException>(
            () => SearchReplaceTool.FindFiles("/nonexistent/path/xyz", "**/*.txt"));

        Assert.Contains("does not exist", ex.Message);
    }

    [Fact]
    public void SearchFile_NonExistentFile_ThrowsWithMessage()
    {
        var ex = Assert.Throws<FileNotFoundException>(
            () => SearchReplaceTool.SearchFile("/no/such/file.txt", "pattern"));

        Assert.Contains("not found", ex.Message);
    }

    [Fact]
    public void SearchFile_InvalidRegex_ThrowsWithMessage()
    {
        var path = Path.Combine(_tempDir, "valid.txt");
        File.WriteAllText(path, "content");

        var ex = Assert.Throws<ArgumentException>(
            () => SearchReplaceTool.SearchFile(path, "[invalid(regex"));

        Assert.Contains("regex", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void CreateBackup_NonExistentFile_ThrowsWithMessage()
    {
        var ex = Assert.Throws<FileNotFoundException>(
            () => SearchReplaceTool.CreateBackup("/no/such/file.txt"));

        Assert.Contains("not found", ex.Message);
    }

    [Fact]
    public void Run_EmptyDirectory_ReturnsEmptyReport()
    {
        var options = new SearchReplaceOptions
        {
            RootDirectory = _tempDir,
            GlobPattern = "**/*.txt",
            SearchPattern = "anything",
            Replacement = "nothing",
            PreviewOnly = false,
            CreateBackups = false
        };

        var report = SearchReplaceTool.Run(options);

        Assert.Equal(0, report.FilesSearched);
        Assert.Equal(0, report.TotalMatches);
        Assert.Equal(0, report.TotalReplacements);
    }
}
