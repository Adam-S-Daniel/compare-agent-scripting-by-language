// TDD Round 4 - RED: Tests for the results aggregator.
// The aggregator combines multiple TestRuns and computes:
// - Total passed/failed/skipped across all runs
// - Total duration
// - Flaky tests (passed in some runs, failed in others)
// - Consistently failing tests

using Xunit;

namespace TestResultsAggregator.Tests;

public class AggregatorTests
{
    private static List<TestRun> CreateSampleRuns()
    {
        // Run 1: TestSubtraction fails, TestMultiplication passes
        var run1 = new TestRun
        {
            Label = "Run1-Ubuntu",
            Duration = TimeSpan.FromSeconds(12),
            TestCases =
            [
                new TestCase { Name = "TestAddition", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(1) },
                new TestCase { Name = "TestSubtraction", Suite = "MathTests", Status = TestStatus.Failed, Duration = TimeSpan.FromSeconds(2), ErrorMessage = "bad" },
                new TestCase { Name = "TestMultiplication", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(2) },
                new TestCase { Name = "TestConcat", Suite = "StringTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(3) },
                new TestCase { Name = "TestSplit", Suite = "StringTests", Status = TestStatus.Skipped, Duration = TimeSpan.Zero, SkipReason = "todo" }
            ]
        };

        // Run 2: TestSubtraction passes (flaky!), TestMultiplication passes
        var run2 = new TestRun
        {
            Label = "Run2-Windows",
            Duration = TimeSpan.FromSeconds(14),
            TestCases =
            [
                new TestCase { Name = "TestAddition", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(1.5) },
                new TestCase { Name = "TestSubtraction", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(2.8) },
                new TestCase { Name = "TestMultiplication", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(2) },
                new TestCase { Name = "TestConcat", Suite = "StringTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(4) },
                new TestCase { Name = "TestSplit", Suite = "StringTests", Status = TestStatus.Skipped, Duration = TimeSpan.Zero, SkipReason = "todo" }
            ]
        };

        // Run 3: TestSubtraction passes, TestMultiplication fails (flaky!)
        var run3 = new TestRun
        {
            Label = "Run3-MacOS",
            Duration = TimeSpan.FromSeconds(10.75),
            TestCases =
            [
                new TestCase { Name = "TestAddition", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(1.1) },
                new TestCase { Name = "TestSubtraction", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(2.3) },
                new TestCase { Name = "TestMultiplication", Suite = "MathTests", Status = TestStatus.Failed, Duration = TimeSpan.FromSeconds(1.8), ErrorMessage = "timeout" },
                new TestCase { Name = "TestConcat", Suite = "StringTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(3.2) },
                new TestCase { Name = "TestSplit", Suite = "StringTests", Status = TestStatus.Skipped, Duration = TimeSpan.Zero, SkipReason = "todo" }
            ]
        };

        return [run1, run2, run3];
    }

    [Fact]
    public void Aggregate_ShouldCountUniqueTests()
    {
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        // 5 unique tests across all runs
        Assert.Equal(5, result.UniqueTestCount);
    }

    [Fact]
    public void Aggregate_ShouldComputeTotalRunCount()
    {
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        Assert.Equal(3, result.RunCount);
    }

    [Fact]
    public void Aggregate_ShouldSumTotalDuration()
    {
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        Assert.Equal(36.75, result.TotalDuration.TotalSeconds, precision: 2);
    }

    [Fact]
    public void Aggregate_ShouldIdentifyFlakyTests()
    {
        // TestSubtraction: failed in run1, passed in run2 & run3 -> flaky
        // TestMultiplication: passed in run1 & run2, failed in run3 -> flaky
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        Assert.Equal(2, result.FlakyTests.Count);

        var flakyNames = result.FlakyTests.Select(f => f.FullyQualifiedName).OrderBy(n => n).ToList();
        Assert.Contains("MathTests.TestMultiplication", flakyNames);
        Assert.Contains("MathTests.TestSubtraction", flakyNames);
    }

    [Fact]
    public void Aggregate_ShouldIdentifyConsistentlyPassingTests()
    {
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        // TestAddition and TestConcat pass in all runs
        Assert.Equal(2, result.ConsistentlyPassing.Count);
    }

    [Fact]
    public void Aggregate_ShouldIdentifyConsistentlySkippedTests()
    {
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        // TestSplit is skipped in all runs
        Assert.Single(result.ConsistentlySkipped);
        Assert.Equal("StringTests.TestSplit", result.ConsistentlySkipped[0].FullyQualifiedName);
    }

    [Fact]
    public void Aggregate_ShouldHaveNoConsistentlyFailingInSample()
    {
        // No test fails in ALL runs in our sample
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        Assert.Empty(result.ConsistentlyFailing);
    }

    [Fact]
    public void Aggregate_ShouldIdentifyConsistentlyFailingTests()
    {
        var runs = new List<TestRun>
        {
            new()
            {
                Label = "R1",
                TestCases = [new TestCase { Name = "AlwaysBad", Suite = "S", Status = TestStatus.Failed, ErrorMessage = "err" }]
            },
            new()
            {
                Label = "R2",
                TestCases = [new TestCase { Name = "AlwaysBad", Suite = "S", Status = TestStatus.Failed, ErrorMessage = "err" }]
            }
        };
        var result = ResultsAggregator.Aggregate(runs);
        Assert.Single(result.ConsistentlyFailing);
    }

    [Fact]
    public void Aggregate_EmptyRuns_ShouldReturnZeros()
    {
        var result = ResultsAggregator.Aggregate([]);
        Assert.Equal(0, result.UniqueTestCount);
        Assert.Equal(0, result.RunCount);
        Assert.Empty(result.FlakyTests);
    }

    [Fact]
    public void Aggregate_FlakyTestShouldIncludeRunDetails()
    {
        var result = ResultsAggregator.Aggregate(CreateSampleRuns());
        var subtraction = result.FlakyTests.First(f => f.FullyQualifiedName == "MathTests.TestSubtraction");

        // Should know which runs passed and which failed
        Assert.Single(subtraction.FailedInRuns);
        Assert.Equal(2, subtraction.PassedInRuns.Count);
        Assert.Contains("Run1-Ubuntu", subtraction.FailedInRuns);
    }
}
