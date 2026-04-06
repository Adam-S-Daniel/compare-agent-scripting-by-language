// TDD Round 3 - RED: Tests for JSON test result parser.
// Tests parsing our JSON format into the TestRun model.

using Xunit;

namespace TestResultsAggregator.Tests;

public class JsonParserTests
{
    private const string MinimalJson = """
        {
          "testRun": "json-run",
          "duration": 5.0,
          "summary": { "total": 2, "passed": 1, "failed": 1, "skipped": 0 },
          "testCases": [
            { "suite": "S1", "name": "GoodTest", "status": "passed", "duration": 2.0 },
            { "suite": "S1", "name": "BadTest", "status": "failed", "duration": 3.0,
              "error": { "message": "assertion failed", "type": "AssertionError" } }
          ]
        }
        """;

    [Fact]
    public void Parse_ShouldReturnTestRunWithLabel()
    {
        var run = JsonTestParser.Parse(MinimalJson, "override-label");
        Assert.Equal("override-label", run.Label);
    }

    [Fact]
    public void Parse_ShouldExtractTestCases()
    {
        var run = JsonTestParser.Parse(MinimalJson, "r");
        Assert.Equal(2, run.TestCases.Count);
    }

    [Fact]
    public void Parse_ShouldMapStatusCorrectly()
    {
        var run = JsonTestParser.Parse(MinimalJson, "r");
        Assert.Equal(1, run.PassedCount);
        Assert.Equal(1, run.FailedCount);
    }

    [Fact]
    public void Parse_ShouldExtractErrorMessage()
    {
        var run = JsonTestParser.Parse(MinimalJson, "r");
        var failed = run.TestCases.First(tc => tc.Status == TestStatus.Failed);
        Assert.Equal("assertion failed", failed.ErrorMessage);
    }

    [Fact]
    public void Parse_ShouldCaptureDuration()
    {
        var run = JsonTestParser.Parse(MinimalJson, "r");
        Assert.Equal(5.0, run.Duration.TotalSeconds, precision: 3);
    }

    [Fact]
    public void Parse_ShouldHandleSkippedTests()
    {
        var json = """
            {
              "testRun": "skip",
              "duration": 0,
              "summary": { "total": 1, "passed": 0, "failed": 0, "skipped": 1 },
              "testCases": [
                { "suite": "S", "name": "T", "status": "skipped", "duration": 0,
                  "skipReason": "disabled" }
              ]
            }
            """;
        var run = JsonTestParser.Parse(json, "skip");
        Assert.Equal(TestStatus.Skipped, run.TestCases[0].Status);
        Assert.Equal("disabled", run.TestCases[0].SkipReason);
    }

    [Fact]
    public void Parse_InvalidJson_ShouldThrowWithMeaningfulMessage()
    {
        var ex = Assert.Throws<TestResultParseException>(
            () => JsonTestParser.Parse("{bad json", "oops"));
        Assert.Contains("JSON", ex.Message);
    }

    [Fact]
    public void Parse_FixtureRun3_ShouldParse5Tests()
    {
        var json = File.ReadAllText(FixturePath("results-run3.json"));
        var run = JsonTestParser.Parse(json, "Run3-MacOS");

        Assert.Equal(5, run.TotalCount);
        Assert.Equal(3, run.PassedCount);
        Assert.Equal(1, run.FailedCount);
        Assert.Equal(1, run.SkippedCount);
    }

    private static string FixturePath(string name)
    {
        var dir = AppContext.BaseDirectory;
        var fixturesInOutput = Path.Combine(dir, "fixtures", name);
        if (File.Exists(fixturesInOutput)) return fixturesInOutput;
        var projectDir = Path.GetFullPath(Path.Combine(dir, "..", "..", "..", ".."));
        return Path.Combine(projectDir, "fixtures", name);
    }
}
