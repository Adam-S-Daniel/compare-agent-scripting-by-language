// TDD RED → GREEN: Tests for search-and-replace with summary report.
// Verifies that ReplaceInFile modifies content correctly and that
// the full Run pipeline produces an accurate summary report.

using Xunit;

public class ReplaceTests : IDisposable
{
    private readonly string _tempDir;

    public ReplaceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "sr_replace_" + Guid.NewGuid().ToString("N"));
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
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
        return path;
    }

    [Fact]
    public void ReplaceInFile_SimpleReplacement_ModifiesFile()
    {
        var path = CreateFile("test.txt", "hello world\n");

        SearchReplaceTool.ReplaceInFile(path, "hello", "goodbye");

        Assert.Equal("goodbye world\n", File.ReadAllText(path));
    }

    [Fact]
    public void ReplaceInFile_ReturnsReplacementRecords()
    {
        var path = CreateFile("test.txt", "foo bar foo\n");

        var records = SearchReplaceTool.ReplaceInFile(path, "foo", "baz");

        Assert.Equal(2, records.Count);
        Assert.All(records, r => Assert.Equal("foo", r.OldText));
        Assert.All(records, r => Assert.Equal("baz", r.NewText));
        Assert.All(records, r => Assert.Equal(path, r.FilePath));
    }

    [Fact]
    public void ReplaceInFile_RegexReplacement_Works()
    {
        var path = CreateFile("data.txt", "date: 2024-01-15\ndate: 2024-02-20\n");

        var records = SearchReplaceTool.ReplaceInFile(path, @"(\d{4})-(\d{2})-(\d{2})", "$2/$3/$1");

        Assert.Equal(2, records.Count);
        var content = File.ReadAllText(path);
        Assert.Contains("01/15/2024", content);
        Assert.Contains("02/20/2024", content);
    }

    [Fact]
    public void ReplaceInFile_NoMatch_DoesNotModifyFile()
    {
        var original = "nothing to see here\n";
        var path = CreateFile("safe.txt", original);

        var records = SearchReplaceTool.ReplaceInFile(path, "missing", "replaced");

        Assert.Empty(records);
        Assert.Equal(original, File.ReadAllText(path));
    }

    [Fact]
    public void ReplaceInFile_MultiLine_ReportsCorrectLineNumbers()
    {
        var path = CreateFile("multi.txt", "line1\nfoo\nline3\nfoo\nline5\n");

        var records = SearchReplaceTool.ReplaceInFile(path, "foo", "bar");

        Assert.Equal(2, records.Count);
        Assert.Equal(2, records[0].LineNumber);
        Assert.Equal(4, records[1].LineNumber);
    }

    [Fact]
    public void Run_FullPipeline_ProducesSummaryReport()
    {
        CreateFile("src/a.txt", "old_val = 1;\n");
        CreateFile("src/b.txt", "old_val = 2;\nold_val = 3;\n");
        CreateFile("src/c.log", "old_val = skip;\n"); // won't match glob

        var options = new SearchReplaceOptions
        {
            RootDirectory = _tempDir,
            GlobPattern = "**/*.txt",
            SearchPattern = "old_val",
            Replacement = "new_val",
            PreviewOnly = false,
            CreateBackups = false
        };

        var report = SearchReplaceTool.Run(options);

        Assert.Equal(2, report.FilesSearched);   // only .txt files
        Assert.Equal(2, report.FilesMatched);
        Assert.Equal(3, report.TotalMatches);
        Assert.Equal(3, report.TotalReplacements);
        Assert.Equal(3, report.Replacements.Count);
        Assert.All(report.Replacements, r => Assert.Equal("old_val", r.OldText));
        Assert.All(report.Replacements, r => Assert.Equal("new_val", r.NewText));
    }

    [Fact]
    public void Run_SummaryReport_IncludesFileAndLineInfo()
    {
        CreateFile("info.txt", "alpha\nbeta\nalpha\n");

        var options = new SearchReplaceOptions
        {
            RootDirectory = _tempDir,
            GlobPattern = "**/*.txt",
            SearchPattern = "alpha",
            Replacement = "omega",
            PreviewOnly = false,
            CreateBackups = false
        };

        var report = SearchReplaceTool.Run(options);

        Assert.Equal(2, report.Replacements.Count);
        Assert.Equal(1, report.Replacements[0].LineNumber);
        Assert.Equal(3, report.Replacements[1].LineNumber);
        Assert.All(report.Replacements, r => Assert.Contains("info.txt", r.FilePath));
    }

    [Fact]
    public void Run_NoReplacementProvided_SearchOnly()
    {
        CreateFile("search.txt", "find this\n");

        var options = new SearchReplaceOptions
        {
            RootDirectory = _tempDir,
            GlobPattern = "**/*.txt",
            SearchPattern = "find",
            Replacement = null, // no replacement
            PreviewOnly = true,
            CreateBackups = false
        };

        var report = SearchReplaceTool.Run(options);

        Assert.Equal(1, report.TotalMatches);
        Assert.Equal(0, report.TotalReplacements);
    }
}
