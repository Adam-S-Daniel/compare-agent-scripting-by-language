// TDD Wave 6: End-to-end integration tests
// Load all fixture files, aggregate, generate markdown, verify key properties.
// These should pass without any new implementation code if all prior tests are solid.

using TestAggregator.Aggregation;
using TestAggregator.Models;
using TestAggregator.Parsers;
using TestAggregator.Reporting;
using Xunit;

namespace TestAggregator.Tests;

public class IntegrationTests
{
    // Parser registry: selects the first parser whose CanParse() returns true
    private static ITestResultParser SelectParser(string filePath, IEnumerable<ITestResultParser> parsers) =>
        parsers.First(p => p.CanParse(filePath));

    [Fact]
    public void ParseAndAggregate_AllXmlFixtures_ProducesCorrectTotals()
    {
        var parsers = new ITestResultParser[] { new JUnitXmlParser(), new JsonTestResultParser() };
        var aggregator = new TestResultAggregator();

        var files = new[]
        {
            Path.Combine("Fixtures", "junit-pass.xml"),  // 5 passed
            Path.Combine("Fixtures", "junit-fail.xml"),  // 3 passed, 1 failed, 1 skipped
            Path.Combine("Fixtures", "junit-flaky.xml"), // 3 passed
        };

        var runs = files.Select(f => SelectParser(f, parsers).Parse(f)).ToList();
        var result = aggregator.Aggregate(runs);

        // junit-pass: 5 passed
        // junit-fail: 3 passed, 1 failed, 1 skipped
        // junit-flaky: 3 passed
        Assert.Equal(11, result.TotalPassed);
        Assert.Equal(1, result.TotalFailed);
        Assert.Equal(1, result.TotalSkipped);
        Assert.Equal(13, result.TotalTests);
    }

    [Fact]
    public void ParseAndAggregate_XmlFixtures_DetectsFlakyTest()
    {
        var parsers = new ITestResultParser[] { new JUnitXmlParser(), new JsonTestResultParser() };
        var aggregator = new TestResultAggregator();

        var files = new[]
        {
            Path.Combine("Fixtures", "junit-pass.xml"),
            Path.Combine("Fixtures", "junit-fail.xml"),
            Path.Combine("Fixtures", "junit-flaky.xml"),
        };

        var runs = files.Select(f => SelectParser(f, parsers).Parse(f)).ToList();
        var result = aggregator.Aggregate(runs);

        // Subtract_PositiveFromLarger_ReturnsDiff: passes in junit-pass + junit-flaky, fails in junit-fail
        Assert.Single(result.FlakyTests);
        Assert.Equal("Subtract_PositiveFromLarger_ReturnsDiff", result.FlakyTests[0].Name);
        Assert.Equal(2, result.FlakyTests[0].PassCount);
        Assert.Equal(1, result.FlakyTests[0].FailCount);
    }

    [Fact]
    public void ParseAndAggregate_JsonFixtures_ProducesCorrectTotals()
    {
        var parsers = new ITestResultParser[] { new JUnitXmlParser(), new JsonTestResultParser() };
        var aggregator = new TestResultAggregator();

        var files = new[]
        {
            Path.Combine("Fixtures", "results-pass.json"),  // 2 passed
            Path.Combine("Fixtures", "results-fail.json"),  // 1 failed, 1 passed, 1 skipped
        };

        var runs = files.Select(f => SelectParser(f, parsers).Parse(f)).ToList();
        var result = aggregator.Aggregate(runs);

        Assert.Equal(3, result.TotalPassed);
        Assert.Equal(1, result.TotalFailed);
        Assert.Equal(1, result.TotalSkipped);
    }

    [Fact]
    public void ParseAndAggregate_JsonFixtures_DetectsFlakyTest()
    {
        var parsers = new ITestResultParser[] { new JUnitXmlParser(), new JsonTestResultParser() };
        var aggregator = new TestResultAggregator();

        var files = new[]
        {
            Path.Combine("Fixtures", "results-pass.json"),
            Path.Combine("Fixtures", "results-fail.json"),
        };

        var runs = files.Select(f => SelectParser(f, parsers).Parse(f)).ToList();
        var result = aggregator.Aggregate(runs);

        // should_add_numbers: passes in results-pass.json, fails in results-fail.json
        var flaky = result.FlakyTests.Single(f => f.Name == "should_add_numbers");
        Assert.Equal(1, flaky.PassCount);
        Assert.Equal(1, flaky.FailCount);
    }

    [Fact]
    public void FullPipeline_AllFixtures_GeneratesValidMarkdown()
    {
        var parsers = new ITestResultParser[] { new JUnitXmlParser(), new JsonTestResultParser() };
        var aggregator = new TestResultAggregator();
        var reporter = new MarkdownReporter();

        var files = new[]
        {
            Path.Combine("Fixtures", "junit-pass.xml"),
            Path.Combine("Fixtures", "junit-fail.xml"),
            Path.Combine("Fixtures", "junit-flaky.xml"),
            Path.Combine("Fixtures", "results-pass.json"),
            Path.Combine("Fixtures", "results-fail.json"),
        };

        var runs = files.Select(f => SelectParser(f, parsers).Parse(f)).ToList();
        var result = aggregator.Aggregate(runs);
        var markdown = reporter.Generate(result);

        // Structural checks
        Assert.Contains("## Test Results Summary", markdown);
        Assert.Contains("Results by File", markdown);
        Assert.Contains("Flaky Tests", markdown);

        // Numeric checks — 5 source files
        Assert.Contains("5", markdown);

        // All fixture filenames appear in the per-file table
        foreach (var file in files)
            Assert.Contains(Path.GetFileName(file), markdown);
    }
}
