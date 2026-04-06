// TDD RED → GREEN: Tests for preview mode.
// Preview mode shows matches with surrounding context lines
// without modifying any files.

using Xunit;

public class PreviewTests : IDisposable
{
    private readonly string _tempDir;

    public PreviewTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "sr_preview_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, recursive: true);
    }

    private string CreateFile(string name, string content)
    {
        var path = Path.Combine(_tempDir, name);
        File.WriteAllText(path, content);
        return path;
    }

    [Fact]
    public void BuildPreview_ShowsMatchingLines()
    {
        var path = CreateFile("preview.txt", "line1\nTARGET\nline3\n");

        var preview = SearchReplaceTool.BuildPreview(path, "TARGET", contextLines: 0);

        Assert.Contains("TARGET", preview);
        Assert.Contains("2:", preview); // line number
    }

    [Fact]
    public void BuildPreview_IncludesContextLines()
    {
        var content = "line1\nline2\nTARGET\nline4\nline5\n";
        var path = CreateFile("ctx.txt", content);

        var preview = SearchReplaceTool.BuildPreview(path, "TARGET", contextLines: 1);

        // Should include 1 line before and after
        Assert.Contains("line2", preview);
        Assert.Contains("TARGET", preview);
        Assert.Contains("line4", preview);
    }

    [Fact]
    public void BuildPreview_NoMatch_ReturnsEmptyOrNoMatchMessage()
    {
        var path = CreateFile("none.txt", "nothing relevant\n");

        var preview = SearchReplaceTool.BuildPreview(path, "MISSING", contextLines: 0);

        // Should either be empty or indicate no matches
        Assert.True(
            string.IsNullOrWhiteSpace(preview) || preview.Contains("No matches"),
            "Preview should indicate no matches were found");
    }

    [Fact]
    public void BuildPreview_DoesNotModifyFile()
    {
        var content = "original content\nfind me here\nmore content\n";
        var path = CreateFile("nomod.txt", content);

        _ = SearchReplaceTool.BuildPreview(path, "find me", contextLines: 1);

        // Verify file is unchanged
        Assert.Equal(content, File.ReadAllText(path));
    }

    [Fact]
    public void BuildPreview_ContextAtFileStart_DoesNotCrash()
    {
        var path = CreateFile("start.txt", "TARGET\nline2\nline3\n");

        // Requesting context when match is at the start — no lines before
        var preview = SearchReplaceTool.BuildPreview(path, "TARGET", contextLines: 2);

        Assert.Contains("TARGET", preview);
    }

    [Fact]
    public void BuildPreview_ContextAtFileEnd_DoesNotCrash()
    {
        var path = CreateFile("end.txt", "line1\nline2\nTARGET\n");

        // Requesting context when match is at the end — no lines after
        var preview = SearchReplaceTool.BuildPreview(path, "TARGET", contextLines: 2);

        Assert.Contains("TARGET", preview);
    }

    [Fact]
    public void PreviewMode_FullPipeline_DoesNotModifyFiles()
    {
        // End-to-end test: running with PreviewOnly should not change any file
        var subDir = Path.Combine(_tempDir, "src");
        Directory.CreateDirectory(subDir);
        var content = "old_value = 42;\n";
        File.WriteAllText(Path.Combine(subDir, "config.txt"), content);

        var options = new SearchReplaceOptions
        {
            RootDirectory = _tempDir,
            GlobPattern = "**/*.txt",
            SearchPattern = "old_value",
            Replacement = "new_value",
            PreviewOnly = true,
            CreateBackups = false
        };

        var report = SearchReplaceTool.Run(options);

        // Report should show matches found
        Assert.True(report.TotalMatches > 0);
        // But no replacements made
        Assert.Equal(0, report.TotalReplacements);
        // File content unchanged
        Assert.Equal(content, File.ReadAllText(Path.Combine(subDir, "config.txt")));
    }
}
