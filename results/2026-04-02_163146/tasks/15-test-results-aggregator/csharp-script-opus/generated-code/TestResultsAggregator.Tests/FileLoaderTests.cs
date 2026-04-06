// TDD Round 6 - RED: Tests for the file loader that auto-detects format.
// The FileLoader reads a file, detects its format (JUnit XML or JSON),
// and delegates to the appropriate parser.

using Xunit;

namespace TestResultsAggregator.Tests;

public class FileLoaderTests
{
    [Fact]
    public void DetectFormat_XmlExtension_ShouldReturnJUnit()
    {
        Assert.Equal(TestFileFormat.JUnitXml, FileLoader.DetectFormat("results.xml"));
    }

    [Fact]
    public void DetectFormat_JsonExtension_ShouldReturnJson()
    {
        Assert.Equal(TestFileFormat.Json, FileLoader.DetectFormat("results.json"));
    }

    [Fact]
    public void DetectFormat_UnknownExtension_ShouldThrow()
    {
        Assert.Throws<TestResultParseException>(() => FileLoader.DetectFormat("results.csv"));
    }

    [Fact]
    public void LoadFile_JUnitFixture_ShouldParseCorrectly()
    {
        var path = FixturePath("junit-run1.xml");
        var run = FileLoader.LoadFile(path);

        Assert.Equal("junit-run1", run.Label);
        Assert.Equal(5, run.TotalCount);
    }

    [Fact]
    public void LoadFile_JsonFixture_ShouldParseCorrectly()
    {
        var path = FixturePath("results-run3.json");
        var run = FileLoader.LoadFile(path);

        Assert.Equal("results-run3", run.Label);
        Assert.Equal(5, run.TotalCount);
    }

    [Fact]
    public void LoadFile_NonExistentFile_ShouldThrowMeaningful()
    {
        var ex = Assert.Throws<TestResultParseException>(
            () => FileLoader.LoadFile("/no/such/file.xml"));
        Assert.Contains("not found", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void LoadDirectory_ShouldLoadAllSupportedFiles()
    {
        var fixturesDir = FixturesDirectory();
        var runs = FileLoader.LoadDirectory(fixturesDir);

        // Should load all 3 fixture files (2 xml + 1 json)
        Assert.Equal(3, runs.Count);
    }

    private static string FixturePath(string name)
    {
        var dir = AppContext.BaseDirectory;
        var fixturesInOutput = Path.Combine(dir, "fixtures", name);
        if (File.Exists(fixturesInOutput)) return fixturesInOutput;
        var projectDir = Path.GetFullPath(Path.Combine(dir, "..", "..", "..", ".."));
        return Path.Combine(projectDir, "fixtures", name);
    }

    private static string FixturesDirectory()
    {
        var dir = AppContext.BaseDirectory;
        var fixturesInOutput = Path.Combine(dir, "fixtures");
        if (Directory.Exists(fixturesInOutput)) return fixturesInOutput;
        var projectDir = Path.GetFullPath(Path.Combine(dir, "..", "..", "..", ".."));
        return Path.Combine(projectDir, "fixtures");
    }
}
