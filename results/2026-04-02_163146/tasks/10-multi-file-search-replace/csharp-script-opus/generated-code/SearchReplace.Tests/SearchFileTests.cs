// TDD RED → GREEN: Tests for regex search within a single file.
// Verifies that SearchFile finds all regex matches and reports correct
// line numbers, matched text, and positions.

using Xunit;

public class SearchFileTests : IDisposable
{
    private readonly string _tempDir;

    public SearchFileTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "sr_search_" + Guid.NewGuid().ToString("N"));
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
    public void SearchFile_FindsSimplePattern_ReturnsCorrectMatches()
    {
        // Arrange
        var path = CreateFile("test.txt", "hello world\nfoo bar\nhello again\n");

        // Act
        var matches = SearchReplaceTool.SearchFile(path, "hello");

        // Assert
        Assert.Equal(2, matches.Count);
        Assert.Equal(1, matches[0].LineNumber);
        Assert.Equal(3, matches[1].LineNumber);
        Assert.Equal("hello", matches[0].MatchedText);
    }

    [Fact]
    public void SearchFile_RegexGroupCapture_MatchesCorrectly()
    {
        var path = CreateFile("data.csv", "name=Alice\nage=30\nname=Bob\n");

        var matches = SearchReplaceTool.SearchFile(path, @"name=(\w+)");

        Assert.Equal(2, matches.Count);
        Assert.Equal("name=Alice", matches[0].MatchedText);
        Assert.Equal("name=Bob", matches[1].MatchedText);
    }

    [Fact]
    public void SearchFile_NoMatch_ReturnsEmptyList()
    {
        var path = CreateFile("empty.txt", "nothing here\n");

        var matches = SearchReplaceTool.SearchFile(path, "missing");

        Assert.Empty(matches);
    }

    [Fact]
    public void SearchFile_MultipleMatchesOnSameLine_ReportsEach()
    {
        var path = CreateFile("multi.txt", "aaa bbb aaa\n");

        var matches = SearchReplaceTool.SearchFile(path, "aaa");

        Assert.Equal(2, matches.Count);
        Assert.All(matches, m => Assert.Equal(1, m.LineNumber));
        // Verify different positions
        Assert.NotEqual(matches[0].MatchStart, matches[1].MatchStart);
    }

    [Fact]
    public void SearchFile_ReportsCorrectFilePath()
    {
        var path = CreateFile("check.txt", "find me\n");

        var matches = SearchReplaceTool.SearchFile(path, "find");

        Assert.Single(matches);
        Assert.Equal(path, matches[0].FilePath);
    }

    [Fact]
    public void SearchFile_CaseSensitiveByDefault()
    {
        var path = CreateFile("case.txt", "Hello HELLO hello\n");

        var matches = SearchReplaceTool.SearchFile(path, "hello");

        // Only lowercase "hello" should match
        Assert.Single(matches);
    }

    [Fact]
    public void SearchFile_RegexCaseInsensitiveFlag()
    {
        var path = CreateFile("case2.txt", "Hello HELLO hello\n");

        var matches = SearchReplaceTool.SearchFile(path, "(?i)hello");

        Assert.Equal(3, matches.Count);
    }
}
