// TDD Round 2 - RED: Tests for JUnit XML parser.
// We test parsing a JUnit XML string into our TestRun model.

using Xunit;

namespace TestResultsAggregator.Tests;

public class JUnitParserTests
{
    // Minimal JUnit XML with one passing and one failing test
    private const string MinimalJUnit = """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites name="MinRun" tests="2" failures="1" time="3.5">
          <testsuite name="Suite1" tests="2" failures="1" time="3.5">
            <testcase classname="Suite1" name="PassingTest" time="1.5" />
            <testcase classname="Suite1" name="FailingTest" time="2.0">
              <failure message="bad value">Expected 1 got 2</failure>
            </testcase>
          </testsuite>
        </testsuites>
        """;

    [Fact]
    public void Parse_ShouldReturnTestRunWithCorrectLabel()
    {
        var run = JUnitParser.Parse(MinimalJUnit, "build-1");
        Assert.Equal("build-1", run.Label);
    }

    [Fact]
    public void Parse_ShouldExtractAllTestCases()
    {
        var run = JUnitParser.Parse(MinimalJUnit, "build-1");
        Assert.Equal(2, run.TestCases.Count);
    }

    [Fact]
    public void Parse_ShouldIdentifyPassedAndFailed()
    {
        var run = JUnitParser.Parse(MinimalJUnit, "build-1");
        Assert.Equal(1, run.PassedCount);
        Assert.Equal(1, run.FailedCount);
    }

    [Fact]
    public void Parse_ShouldCaptureFailureMessage()
    {
        var run = JUnitParser.Parse(MinimalJUnit, "build-1");
        var failed = run.TestCases.First(tc => tc.Status == TestStatus.Failed);
        Assert.Equal("bad value", failed.ErrorMessage);
    }

    [Fact]
    public void Parse_ShouldCaptureDuration()
    {
        var run = JUnitParser.Parse(MinimalJUnit, "build-1");
        Assert.Equal(3.5, run.Duration.TotalSeconds, precision: 3);
    }

    [Fact]
    public void Parse_ShouldHandleSkippedTests()
    {
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuites name="SkipRun" tests="1" time="0">
              <testsuite name="S" tests="1">
                <testcase classname="S" name="SkippedOne" time="0">
                  <skipped message="todo" />
                </testcase>
              </testsuite>
            </testsuites>
            """;
        var run = JUnitParser.Parse(xml, "skip-run");
        Assert.Single(run.TestCases);
        Assert.Equal(TestStatus.Skipped, run.TestCases[0].Status);
        Assert.Equal("todo", run.TestCases[0].SkipReason);
    }

    [Fact]
    public void Parse_ShouldHandleEmptyTestSuites()
    {
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuites name="Empty" tests="0" time="0">
            </testsuites>
            """;
        var run = JUnitParser.Parse(xml, "empty");
        Assert.Empty(run.TestCases);
    }

    [Fact]
    public void Parse_InvalidXml_ShouldThrowWithMeaningfulMessage()
    {
        var ex = Assert.Throws<TestResultParseException>(
            () => JUnitParser.Parse("not xml at all", "bad"));
        Assert.Contains("JUnit XML", ex.Message);
    }

    // Test parsing the actual fixture file
    [Fact]
    public void Parse_FixtureRun1_ShouldParse5Tests()
    {
        var xml = File.ReadAllText(FixturePath("junit-run1.xml"));
        var run = JUnitParser.Parse(xml, "Run1-Ubuntu");

        Assert.Equal(5, run.TotalCount);
        Assert.Equal(3, run.PassedCount);
        Assert.Equal(1, run.FailedCount);
        Assert.Equal(1, run.SkippedCount);
    }

    private static string FixturePath(string name)
    {
        // Walk up from the test output directory to find the fixtures folder
        var dir = AppContext.BaseDirectory;
        var fixturesInOutput = Path.Combine(dir, "fixtures", name);
        if (File.Exists(fixturesInOutput)) return fixturesInOutput;

        // Fallback: look relative to the project directory
        var projectDir = Path.GetFullPath(Path.Combine(dir, "..", "..", "..", ".."));
        return Path.Combine(projectDir, "fixtures", name);
    }
}
