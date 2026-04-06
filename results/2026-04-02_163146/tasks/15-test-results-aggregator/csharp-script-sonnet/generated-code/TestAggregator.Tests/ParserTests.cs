// TDD Wave 2 & 3: Parser tests
// Written BEFORE parser implementations exist — each fails at first compilation.
// After each failing test is confirmed, the minimum implementation is added.

using TestAggregator.Models;
using TestAggregator.Parsers;
using Xunit;

namespace TestAggregator.Tests;

public class JUnitXmlParserTests
{
    private static string FixturePath(string name) =>
        Path.Combine("Fixtures", name);

    // ── CanParse ─────────────────────────────────────────────────────────────

    [Fact]
    public void CanParse_XmlExtension_ReturnsTrue()
    {
        var parser = new JUnitXmlParser();
        Assert.True(parser.CanParse("results.xml"));
    }

    [Fact]
    public void CanParse_JsonExtension_ReturnsFalse()
    {
        var parser = new JUnitXmlParser();
        Assert.False(parser.CanParse("results.json"));
    }

    [Fact]
    public void CanParse_XmlExtensionUpperCase_ReturnsTrue()
    {
        var parser = new JUnitXmlParser();
        Assert.True(parser.CanParse("results.XML"));
    }

    // ── Parse: junit-pass.xml ───────────────────────────────────────────────

    [Fact]
    public void Parse_AllPass_ReturnsTwoSuites()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-pass.xml"));

        Assert.Equal("junit-xml", run.Format);
        Assert.Equal(2, run.Suites.Count);
    }

    [Fact]
    public void Parse_AllPass_FirstSuiteHasThreeTests()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-pass.xml"));

        Assert.Equal(3, run.Suites[0].TestCases.Count);
    }

    [Fact]
    public void Parse_AllPass_AllStatusesArePassed()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-pass.xml"));

        var allTests = run.Suites.SelectMany(s => s.TestCases).ToList();
        Assert.All(allTests, t => Assert.Equal(TestStatus.Passed, t.Status));
    }

    [Fact]
    public void Parse_AllPass_DurationsArePopulated()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-pass.xml"));

        var first = run.Suites[0].TestCases[0];
        Assert.Equal(0.1, first.DurationSeconds, precision: 5);
    }

    // ── Parse: junit-fail.xml ───────────────────────────────────────────────

    [Fact]
    public void Parse_WithFailure_FailedTestHasStatusFailed()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-fail.xml"));

        var failing = run.Suites[0].TestCases
            .Single(t => t.Name == "Subtract_PositiveFromLarger_ReturnsDiff");

        Assert.Equal(TestStatus.Failed, failing.Status);
    }

    [Fact]
    public void Parse_WithFailure_FailedTestHasErrorMessage()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-fail.xml"));

        var failing = run.Suites[0].TestCases
            .Single(t => t.Name == "Subtract_PositiveFromLarger_ReturnsDiff");

        Assert.NotNull(failing.ErrorMessage);
        Assert.Contains("Expected 5 but was 4", failing.ErrorMessage);
    }

    [Fact]
    public void Parse_WithFailure_FailedTestHasErrorType()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-fail.xml"));

        var failing = run.Suites[0].TestCases
            .Single(t => t.Name == "Subtract_PositiveFromLarger_ReturnsDiff");

        Assert.Equal("AssertionError", failing.ErrorType);
    }

    [Fact]
    public void Parse_WithSkipped_SkippedTestHasStatusSkipped()
    {
        var parser = new JUnitXmlParser();
        var run = parser.Parse(FixturePath("junit-fail.xml"));

        var skipped = run.Suites[0].TestCases
            .Single(t => t.Name == "Multiply_ByZero_ReturnsZero");

        Assert.Equal(TestStatus.Skipped, skipped.Status);
    }

    // ── Parse: edge cases ───────────────────────────────────────────────────

    [Fact]
    public void Parse_MissingTimeAttribute_DefaultsToZero()
    {
        // Inline XML — no time attribute on testcase
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuite name="EdgeCases" tests="1">
              <testcase classname="Foo" name="Bar"/>
            </testsuite>
            """;
        var path = Path.GetTempFileName() + ".xml";
        File.WriteAllText(path, xml);

        try
        {
            var parser = new JUnitXmlParser();
            var run = parser.Parse(path);
            Assert.Equal(0.0, run.Suites[0].TestCases[0].DurationSeconds);
        }
        finally { File.Delete(path); }
    }

    [Fact]
    public void Parse_SingleTestsuiteElement_StillProducesOneSuite()
    {
        // Some JUnit producers emit <testsuite> (not wrapped in <testsuites>)
        var xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuite name="Solo" tests="1" time="0.5">
              <testcase classname="A" name="B" time="0.5"/>
            </testsuite>
            """;
        var path = Path.GetTempFileName() + ".xml";
        File.WriteAllText(path, xml);

        try
        {
            var parser = new JUnitXmlParser();
            var run = parser.Parse(path);
            Assert.Single(run.Suites);
            Assert.Single(run.Suites[0].TestCases);
        }
        finally { File.Delete(path); }
    }
}

public class JsonTestResultParserTests
{
    private static string FixturePath(string name) =>
        Path.Combine("Fixtures", name);

    // ── CanParse ─────────────────────────────────────────────────────────────

    [Fact]
    public void CanParse_JsonExtension_ReturnsTrue()
    {
        var parser = new JsonTestResultParser();
        Assert.True(parser.CanParse("results.json"));
    }

    [Fact]
    public void CanParse_XmlExtension_ReturnsFalse()
    {
        var parser = new JsonTestResultParser();
        Assert.False(parser.CanParse("results.xml"));
    }

    // ── Parse: results-pass.json ─────────────────────────────────────────────

    [Fact]
    public void Parse_AllPass_ReturnsOneSuiteWithTwoTests()
    {
        var parser = new JsonTestResultParser();
        var run = parser.Parse(FixturePath("results-pass.json"));

        Assert.Equal("json", run.Format);
        Assert.Single(run.Suites);
        Assert.Equal(2, run.Suites[0].TestCases.Count);
    }

    [Fact]
    public void Parse_AllPass_AllStatusesArePassed()
    {
        var parser = new JsonTestResultParser();
        var run = parser.Parse(FixturePath("results-pass.json"));

        Assert.All(run.Suites[0].TestCases, t => Assert.Equal(TestStatus.Passed, t.Status));
    }

    // ── Parse: results-fail.json ─────────────────────────────────────────────

    [Fact]
    public void Parse_WithFailure_FailedTestHasStatusFailed()
    {
        var parser = new JsonTestResultParser();
        var run = parser.Parse(FixturePath("results-fail.json"));

        var failing = run.Suites[0].TestCases
            .Single(t => t.Name == "should_add_numbers");

        Assert.Equal(TestStatus.Failed, failing.Status);
    }

    [Fact]
    public void Parse_WithFailure_ErrorMessageIsPopulated()
    {
        var parser = new JsonTestResultParser();
        var run = parser.Parse(FixturePath("results-fail.json"));

        var failing = run.Suites[0].TestCases
            .Single(t => t.Name == "should_add_numbers");

        Assert.Equal("Expected 4 to equal 5", failing.ErrorMessage);
    }

    [Fact]
    public void Parse_WithSkipped_SkippedStatusMapped()
    {
        var parser = new JsonTestResultParser();
        var run = parser.Parse(FixturePath("results-fail.json"));

        var skipped = run.Suites[0].TestCases
            .Single(t => t.Name == "should_sort_descending");

        Assert.Equal(TestStatus.Skipped, skipped.Status);
    }
}
