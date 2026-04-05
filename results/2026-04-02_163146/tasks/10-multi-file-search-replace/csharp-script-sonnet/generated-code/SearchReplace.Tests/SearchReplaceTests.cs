// TDD approach: write failing tests first, then implement minimum code to pass.
// Each test is labeled with the "RED -> GREEN -> REFACTOR" cycle.

using System.Text.RegularExpressions;
using SearchReplace;
using Xunit;

namespace SearchReplace.Tests;

/// <summary>
/// Tests for the multi-file search and replace engine.
/// We use a temp directory as our mock file system.
/// </summary>
public class SearchReplaceEngineTests : IDisposable
{
    private readonly string _testRoot;

    public SearchReplaceEngineTests()
    {
        // Create a fresh temp directory for each test class instance
        _testRoot = Path.Combine(Path.GetTempPath(), "SearchReplaceTests_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testRoot);
    }

    public void Dispose()
    {
        // Clean up after each test
        if (Directory.Exists(_testRoot))
            Directory.Delete(_testRoot, recursive: true);
    }

    // Helper: create a file with given content under _testRoot
    private string CreateFile(string relativePath, string content)
    {
        var fullPath = Path.Combine(_testRoot, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        File.WriteAllText(fullPath, content);
        return fullPath;
    }

    // ===================================================================
    // RED: Test 1 — FindFiles returns files matching a glob pattern
    // ===================================================================
    [Fact]
    public void FindFiles_ReturnsMatchingFiles()
    {
        // Arrange: create a mock directory structure
        CreateFile("src/foo.cs", "// foo");
        CreateFile("src/bar.cs", "// bar");
        CreateFile("src/readme.txt", "readme");
        CreateFile("src/sub/deep.cs", "// deep");

        // Act: find all *.cs files recursively
        var engine = new SearchReplaceEngine();
        var files = engine.FindFiles(_testRoot, "**/*.cs").ToList();

        // Assert: should find 3 .cs files, not the .txt
        Assert.Equal(3, files.Count);
        Assert.All(files, f => Assert.EndsWith(".cs", f));
        Assert.DoesNotContain(files, f => f.EndsWith("readme.txt"));
    }

    // ===================================================================
    // RED: Test 2 — FindMatches returns match info per line
    // ===================================================================
    [Fact]
    public void FindMatches_ReturnsMatchesWithLineInfo()
    {
        // Arrange
        var filePath = CreateFile("example.txt", "Hello World\nFoo bar\nHello again\n");
        var engine = new SearchReplaceEngine();

        // Act: search for "Hello"
        var matches = engine.FindMatches(filePath, new Regex("Hello")).ToList();

        // Assert: two matches, on lines 1 and 3
        Assert.Equal(2, matches.Count);
        Assert.Equal(1, matches[0].LineNumber);
        Assert.Contains("Hello World", matches[0].LineText);
        Assert.Equal(3, matches[1].LineNumber);
        Assert.Contains("Hello again", matches[1].LineText);
    }

    // ===================================================================
    // RED: Test 3 — PreviewMode returns matches without modifying file
    // ===================================================================
    [Fact]
    public void PreviewReplace_ShowsChangesWithoutModifyingFile()
    {
        // Arrange
        var originalContent = "Hello World\nFoo bar\nHello again\n";
        var filePath = CreateFile("example.txt", originalContent);
        var engine = new SearchReplaceEngine();

        // Act: preview replace "Hello" -> "Hi"
        var report = engine.PreviewReplace(filePath, new Regex("Hello"), "Hi");

        // Assert: report contains changes but file is unchanged
        Assert.Equal(2, report.Changes.Count);
        Assert.Equal("Hello World", report.Changes[0].OldText);
        Assert.Equal("Hi World", report.Changes[0].NewText);
        Assert.Equal(1, report.Changes[0].LineNumber);

        // File must NOT be modified
        Assert.Equal(originalContent, File.ReadAllText(filePath));
    }

    // ===================================================================
    // RED: Test 4 — PerformReplace creates backup and modifies file
    // ===================================================================
    [Fact]
    public void PerformReplace_CreatesBackupAndModifiesFile()
    {
        // Arrange
        var originalContent = "Hello World\nFoo bar\n";
        var filePath = CreateFile("example.txt", originalContent);
        var engine = new SearchReplaceEngine();

        // Act: perform replace "Hello" -> "Hi" with backup
        var report = engine.PerformReplace(filePath, new Regex("Hello"), "Hi", createBackup: true);

        // Assert: file is modified
        var newContent = File.ReadAllText(filePath);
        Assert.Contains("Hi World", newContent);
        Assert.DoesNotContain("Hello World", newContent);

        // Backup exists with original content
        Assert.NotNull(report.BackupPath);
        Assert.True(File.Exists(report.BackupPath));
        Assert.Equal(originalContent, File.ReadAllText(report.BackupPath));

        // Report has correct change info
        Assert.Single(report.Changes);
        Assert.Equal(1, report.Changes[0].LineNumber);
        Assert.Equal("Hello World", report.Changes[0].OldText);
        Assert.Equal("Hi World", report.Changes[0].NewText);
    }

    // ===================================================================
    // RED: Test 5 — PerformReplace without backup does not create backup file
    // ===================================================================
    [Fact]
    public void PerformReplace_WithoutBackup_DoesNotCreateBackupFile()
    {
        // Arrange
        var filePath = CreateFile("example.txt", "Hello World\n");
        var engine = new SearchReplaceEngine();

        // Act
        var report = engine.PerformReplace(filePath, new Regex("Hello"), "Hi", createBackup: false);

        // Assert: no backup
        Assert.Null(report.BackupPath);
    }

    // ===================================================================
    // RED: Test 6 — RunOnDirectory processes multiple files and returns summary
    // ===================================================================
    [Fact]
    public void RunOnDirectory_ProcessesMultipleFilesAndReturnsSummary()
    {
        // Arrange: create mock structure
        CreateFile("a.txt", "foo bar\nfoo baz\n");
        CreateFile("b.txt", "no match here\n");
        CreateFile("sub/c.txt", "foo qux\n");

        var engine = new SearchReplaceEngine();

        // Act: replace "foo" with "qux" in all *.txt files
        var summary = engine.RunOnDirectory(
            _testRoot,
            globPattern: "**/*.txt",
            searchPattern: new Regex("foo"),
            replacement: "qux",
            preview: false,
            createBackup: true
        );

        // Assert: only files with matches appear in summary
        Assert.Equal(2, summary.FileReports.Count);
        Assert.Equal(3, summary.TotalChanges);

        // b.txt had no matches, so it shouldn't appear
        Assert.DoesNotContain(summary.FileReports, r => r.FilePath.EndsWith("b.txt"));

        // All matched files should have backups
        Assert.All(summary.FileReports, r => Assert.NotNull(r.BackupPath));
    }

    // ===================================================================
    // RED: Test 7 — Preview mode in RunOnDirectory does not modify files
    // ===================================================================
    [Fact]
    public void RunOnDirectory_PreviewMode_DoesNotModifyFiles()
    {
        // Arrange
        var content = "Hello World\n";
        CreateFile("test.txt", content);
        var engine = new SearchReplaceEngine();

        // Act: preview run
        var summary = engine.RunOnDirectory(
            _testRoot,
            globPattern: "**/*.txt",
            searchPattern: new Regex("Hello"),
            replacement: "Hi",
            preview: true,
            createBackup: false
        );

        // Assert: summary shows changes but file is unchanged
        Assert.Equal(1, summary.TotalChanges);
        Assert.Equal(content, File.ReadAllText(Path.Combine(_testRoot, "test.txt")));

        // No backups in preview mode
        Assert.All(summary.FileReports, r => Assert.Null(r.BackupPath));
    }

    // ===================================================================
    // RED: Test 8 — FindMatches with context lines
    // ===================================================================
    [Fact]
    public void FindMatches_IncludesContextLines()
    {
        // Arrange
        var filePath = CreateFile("ctx.txt", "line1\nline2\nHello\nline4\nline5\n");
        var engine = new SearchReplaceEngine();

        // Act: search with 1 line of context
        var matches = engine.FindMatches(filePath, new Regex("Hello"), contextLines: 1).ToList();

        // Assert: match has context before and after
        Assert.Single(matches);
        Assert.Contains("line2", matches[0].ContextBefore);
        Assert.Contains("line4", matches[0].ContextAfter);
    }

    // ===================================================================
    // RED: Test 9 — Regex with capture groups in replacement
    // ===================================================================
    [Fact]
    public void PerformReplace_SupportsRegexCaptureGroups()
    {
        // Arrange
        var filePath = CreateFile("caps.txt", "John Smith\nJane Doe\n");
        var engine = new SearchReplaceEngine();

        // Act: swap first/last name using capture groups
        var report = engine.PerformReplace(
            filePath,
            new Regex(@"(\w+) (\w+)"),
            replacement: "$2, $1",
            createBackup: false
        );

        // Assert
        var newContent = File.ReadAllText(filePath);
        Assert.Contains("Smith, John", newContent);
        Assert.Contains("Doe, Jane", newContent);
    }

    // ===================================================================
    // RED: Test 10 — Files with no matches produce no changes
    // ===================================================================
    [Fact]
    public void PerformReplace_NoMatches_ReturnsEmptyReport()
    {
        // Arrange
        var filePath = CreateFile("nomatch.txt", "nothing to replace here\n");
        var engine = new SearchReplaceEngine();

        // Act
        var report = engine.PerformReplace(filePath, new Regex("XYZ"), "ABC", createBackup: false);

        // Assert: no changes, no backup
        Assert.Empty(report.Changes);
        Assert.Null(report.BackupPath);
    }
}
