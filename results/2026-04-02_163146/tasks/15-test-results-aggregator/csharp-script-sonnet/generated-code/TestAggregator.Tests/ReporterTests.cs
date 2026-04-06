// TDD Wave 5: Markdown reporter tests
// Written before MarkdownReporter exists.
// The reporter must produce GitHub Actions-compatible markdown for $GITHUB_STEP_SUMMARY.

using TestAggregator.Aggregation;
using TestAggregator.Models;
using TestAggregator.Reporting;
using Xunit;

namespace TestAggregator.Tests;

public class ReporterTests
{
    private static AggregatedResult EmptyResult() =>
        new(0, 0, 0, 0, 0.0, [], []);

    private static AggregatedResult ResultWith(
        int passed = 0, int failed = 0, int skipped = 0, int error = 0,
        double duration = 0.0, List<FlakyTest>? flaky = null, List<TestRun>? runs = null)
        => new(passed, failed, skipped, error, duration, flaky ?? [], runs ?? []);

    // ── Basic structure ───────────────────────────────────────────────────────

    [Fact]
    public void Generate_Always_ContainsSummaryHeader()
    {
        var reporter = new MarkdownReporter();
        var md = reporter.Generate(EmptyResult());

        Assert.Contains("## Test Results Summary", md);
    }

    [Fact]
    public void Generate_WithTotals_ContainsTotalTestCount()
    {
        var reporter = new MarkdownReporter();
        var md = reporter.Generate(ResultWith(passed: 7, failed: 2, skipped: 1));

        Assert.Contains("10", md);  // total = 7+2+1
    }

    [Fact]
    public void Generate_WithPassedCount_ShowsPassedCount()
    {
        var reporter = new MarkdownReporter();
        var md = reporter.Generate(ResultWith(passed: 5));

        Assert.Contains("5", md);
    }

    [Fact]
    public void Generate_WithFailedCount_ShowsFailedCount()
    {
        var reporter = new MarkdownReporter();
        var md = reporter.Generate(ResultWith(failed: 3));

        Assert.Contains("3", md);
    }

    [Fact]
    public void Generate_WithDuration_ShowsDurationFormatted()
    {
        var reporter = new MarkdownReporter();
        var md = reporter.Generate(ResultWith(duration: 12.345));

        Assert.Contains("12.35", md);  // rounded to 2 decimal places
    }

    // ── Flaky tests section ──────────────────────────────────────────────────

    [Fact]
    public void Generate_WithFlakyTests_ContainsFlakySection()
    {
        var reporter = new MarkdownReporter();
        var flaky = new List<FlakyTest>
        {
            new("MyFlakeyTest", "com.example.Tests", 2, 1, ["b.xml"])
        };
        var md = reporter.Generate(ResultWith(flaky: flaky));

        Assert.Contains("Flaky Tests", md);
    }

    [Fact]
    public void Generate_WithFlakyTests_ListsFlakyTestName()
    {
        var reporter = new MarkdownReporter();
        var flaky = new List<FlakyTest>
        {
            new("MyFlakeyTest", "com.example.Tests", 2, 1, ["b.xml"])
        };
        var md = reporter.Generate(ResultWith(flaky: flaky));

        Assert.Contains("MyFlakeyTest", md);
    }

    [Fact]
    public void Generate_NoFlakyTests_OmitsFlakySection()
    {
        var reporter = new MarkdownReporter();
        var md = reporter.Generate(EmptyResult());

        Assert.DoesNotContain("Flaky Tests", md);
    }

    // ── Per-file breakdown ────────────────────────────────────────────────────

    [Fact]
    public void Generate_WithRuns_ContainsPerFileSection()
    {
        var reporter = new MarkdownReporter();
        var suite = new TestSuite("S", [], "results.xml");
        var run = new TestRun("results.xml", "junit-xml", [suite]);
        var md = reporter.Generate(ResultWith(runs: [run]));

        Assert.Contains("Results by File", md);
    }

    [Fact]
    public void Generate_WithRuns_ContainsFileName()
    {
        var reporter = new MarkdownReporter();
        var suite = new TestSuite("S", [], "junit-pass.xml");
        var run = new TestRun("junit-pass.xml", "junit-xml", [suite]);
        var md = reporter.Generate(ResultWith(runs: [run]));

        Assert.Contains("junit-pass.xml", md);
    }

    [Fact]
    public void Generate_WithRuns_ContainsMarkdownTable()
    {
        var reporter = new MarkdownReporter();
        var suite = new TestSuite("S", [], "a.xml");
        var run = new TestRun("a.xml", "junit-xml", [suite]);
        var md = reporter.Generate(ResultWith(runs: [run]));

        // Markdown tables use pipe characters
        Assert.Contains("|", md);
        // Table header separator row
        Assert.Contains("---", md);
    }

    // ── Integration: verify complete output structure ─────────────────────────

    [Fact]
    public void Generate_CompleteResult_OutputIsNonEmpty()
    {
        var reporter = new MarkdownReporter();
        var aggregator = new TestResultAggregator();
        var parser = new TestAggregator.Parsers.JUnitXmlParser();

        var run1 = parser.Parse(Path.Combine("Fixtures", "junit-pass.xml"));
        var run2 = parser.Parse(Path.Combine("Fixtures", "junit-fail.xml"));
        var result = aggregator.Aggregate([run1, run2]);

        var md = reporter.Generate(result);

        Assert.NotEmpty(md);
        Assert.Contains("## Test Results Summary", md);
        Assert.Contains("Flaky Tests", md);  // Subtract_ test is flaky across the two files
    }
}
