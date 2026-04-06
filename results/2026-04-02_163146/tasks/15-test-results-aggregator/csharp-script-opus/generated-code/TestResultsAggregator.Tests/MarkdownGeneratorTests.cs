// TDD Round 5 - RED: Tests for the Markdown summary generator.
// The generator produces a GitHub Actions job summary from aggregated results.

using Xunit;

namespace TestResultsAggregator.Tests;

public class MarkdownGeneratorTests
{
    private static AggregatedResults CreateSampleAggregation()
    {
        var runs = new List<TestRun>
        {
            new()
            {
                Label = "Run1-Ubuntu",
                Duration = TimeSpan.FromSeconds(12),
                TestCases =
                [
                    new TestCase { Name = "TestAdd", Suite = "Math", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(1) },
                    new TestCase { Name = "TestSub", Suite = "Math", Status = TestStatus.Failed, Duration = TimeSpan.FromSeconds(2), ErrorMessage = "bad" }
                ]
            },
            new()
            {
                Label = "Run2-Windows",
                Duration = TimeSpan.FromSeconds(10),
                TestCases =
                [
                    new TestCase { Name = "TestAdd", Suite = "Math", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(1.5) },
                    new TestCase { Name = "TestSub", Suite = "Math", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(2.5) }
                ]
            }
        };
        return ResultsAggregator.Aggregate(runs);
    }

    [Fact]
    public void Generate_ShouldContainTitle()
    {
        var md = MarkdownGenerator.Generate(CreateSampleAggregation());
        Assert.Contains("# Test Results Summary", md);
    }

    [Fact]
    public void Generate_ShouldContainOverviewSection()
    {
        var md = MarkdownGenerator.Generate(CreateSampleAggregation());
        // Should show run count, unique tests, and duration
        Assert.Contains("2 runs", md);
        Assert.Contains("2 unique tests", md);
    }

    [Fact]
    public void Generate_ShouldContainPerRunTable()
    {
        var md = MarkdownGenerator.Generate(CreateSampleAggregation());
        // Should list each run with pass/fail/skip counts
        Assert.Contains("Run1-Ubuntu", md);
        Assert.Contains("Run2-Windows", md);
    }

    [Fact]
    public void Generate_ShouldHighlightFlakyTests()
    {
        var md = MarkdownGenerator.Generate(CreateSampleAggregation());
        // TestSub is flaky (failed in run1, passed in run2)
        Assert.Contains("Flaky", md);
        Assert.Contains("Math.TestSub", md);
    }

    [Fact]
    public void Generate_WithNoFlaky_ShouldNotShowFlakySection()
    {
        var runs = new List<TestRun>
        {
            new()
            {
                Label = "R1",
                TestCases =
                [
                    new TestCase { Name = "A", Suite = "S", Status = TestStatus.Passed }
                ]
            }
        };
        var result = ResultsAggregator.Aggregate(runs);
        var md = MarkdownGenerator.Generate(result);
        Assert.DoesNotContain("Flaky", md);
    }

    [Fact]
    public void Generate_ShouldContainStatusEmoji()
    {
        var md = MarkdownGenerator.Generate(CreateSampleAggregation());
        // Should use emoji to make the summary visual
        Assert.True(md.Contains("✅") || md.Contains("❌") || md.Contains("⚠️"),
            "Markdown should contain status emoji");
    }

    [Fact]
    public void Generate_EmptyResults_ShouldShowNoTestsMessage()
    {
        var empty = ResultsAggregator.Aggregate([]);
        var md = MarkdownGenerator.Generate(empty);
        Assert.Contains("No test results", md);
    }
}
