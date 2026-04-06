// TDD Wave 4: Aggregator tests
// Written before TestResultAggregator exists — drives implementation of totals and flaky detection.

using TestAggregator.Aggregation;
using TestAggregator.Models;
using Xunit;

namespace TestAggregator.Tests;

public class AggregatorTests
{
    private static TestRun MakeRun(string file, params TestCase[] cases)
    {
        var suite = new TestSuite("Suite", cases, file);
        return new TestRun(file, "junit-xml", [suite]);
    }

    private static TestCase Passed(string name, string cls = "Cls") =>
        new(name, cls, "Suite", TestStatus.Passed, 0.1);

    private static TestCase Failed(string name, string cls = "Cls") =>
        new(name, cls, "Suite", TestStatus.Failed, 0.1, "Assert failed");

    private static TestCase Skipped(string name, string cls = "Cls") =>
        new(name, cls, "Suite", TestStatus.Skipped, 0.0);

    // ── Totals ────────────────────────────────────────────────────────────────

    [Fact]
    public void Aggregate_EmptyRunList_ReturnsAllZeros()
    {
        var aggregator = new TestResultAggregator();
        var result = aggregator.Aggregate([]);

        Assert.Equal(0, result.TotalPassed);
        Assert.Equal(0, result.TotalFailed);
        Assert.Equal(0, result.TotalSkipped);
        Assert.Equal(0, result.TotalError);
        Assert.Equal(0.0, result.TotalDurationSeconds);
        Assert.Empty(result.FlakyTests);
    }

    [Fact]
    public void Aggregate_SingleRunAllPassed_ReturnsTotalPassed()
    {
        var aggregator = new TestResultAggregator();
        var run = MakeRun("a.xml", Passed("T1"), Passed("T2"), Passed("T3"));

        var result = aggregator.Aggregate([run]);

        Assert.Equal(3, result.TotalPassed);
        Assert.Equal(0, result.TotalFailed);
    }

    [Fact]
    public void Aggregate_MultipleRuns_SumsTotalsAcrossRuns()
    {
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("a.xml", Passed("T1"), Failed("T2"));
        var run2 = MakeRun("b.xml", Passed("T3"), Passed("T4"), Skipped("T5"));

        var result = aggregator.Aggregate([run1, run2]);

        Assert.Equal(3, result.TotalPassed);
        Assert.Equal(1, result.TotalFailed);
        Assert.Equal(1, result.TotalSkipped);
        Assert.Equal(5, result.TotalTests);
    }

    [Fact]
    public void Aggregate_DurationsSummedAcrossAllRuns()
    {
        var aggregator = new TestResultAggregator();
        // Create suites with known durations via TestCase durations
        var cases1 = new[] { new TestCase("T1", "C", "S", TestStatus.Passed, 1.0) };
        var cases2 = new[] { new TestCase("T2", "C", "S", TestStatus.Passed, 2.5) };
        var suite1 = new TestSuite("S1", cases1, "a.xml");
        var suite2 = new TestSuite("S2", cases2, "b.xml");
        var run1 = new TestRun("a.xml", "junit-xml", [suite1]);
        var run2 = new TestRun("b.xml", "junit-xml", [suite2]);

        var result = aggregator.Aggregate([run1, run2]);

        Assert.Equal(3.5, result.TotalDurationSeconds, precision: 5);
    }

    // ── Flaky detection ───────────────────────────────────────────────────────

    [Fact]
    public void Aggregate_TestPassesInOneRunFailsInAnother_IsFlaky()
    {
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("a.xml", Passed("FlakeyTest", "MyClass"));
        var run2 = MakeRun("b.xml", Failed("FlakeyTest", "MyClass"));

        var result = aggregator.Aggregate([run1, run2]);

        var flaky = Assert.Single(result.FlakyTests);
        Assert.Equal("FlakeyTest", flaky.Name);
        Assert.Equal("MyClass", flaky.ClassName);
    }

    [Fact]
    public void Aggregate_FlakyTest_HasCorrectPassAndFailCounts()
    {
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("a.xml", Passed("FlakyTest", "Cls"));
        var run2 = MakeRun("b.xml", Failed("FlakyTest", "Cls"));
        var run3 = MakeRun("c.xml", Passed("FlakyTest", "Cls"));

        var result = aggregator.Aggregate([run1, run2, run3]);

        var flaky = Assert.Single(result.FlakyTests);
        Assert.Equal(2, flaky.PassCount);
        Assert.Equal(1, flaky.FailCount);
    }

    [Fact]
    public void Aggregate_FlakyTest_RecordsWhichFilesItFailedIn()
    {
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("pass.xml", Passed("FlakyTest", "Cls"));
        var run2 = MakeRun("fail.xml", Failed("FlakyTest", "Cls"));

        var result = aggregator.Aggregate([run1, run2]);

        var flaky = Assert.Single(result.FlakyTests);
        Assert.Contains("fail.xml", flaky.FailingFiles);
        Assert.DoesNotContain("pass.xml", flaky.FailingFiles);
    }

    [Fact]
    public void Aggregate_TestFailsInAllRuns_IsNotFlaky()
    {
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("a.xml", Failed("AlwaysFails", "Cls"));
        var run2 = MakeRun("b.xml", Failed("AlwaysFails", "Cls"));

        var result = aggregator.Aggregate([run1, run2]);

        Assert.Empty(result.FlakyTests);
    }

    [Fact]
    public void Aggregate_TestPassesInAllRuns_IsNotFlaky()
    {
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("a.xml", Passed("AlwaysPasses", "Cls"));
        var run2 = MakeRun("b.xml", Passed("AlwaysPasses", "Cls"));

        var result = aggregator.Aggregate([run1, run2]);

        Assert.Empty(result.FlakyTests);
    }

    [Fact]
    public void Aggregate_DifferentClassSameName_NotConsideredSameTest()
    {
        // Tests with the same name in different classes should not be conflated
        var aggregator = new TestResultAggregator();
        var run1 = MakeRun("a.xml", Passed("Test", "ClassA"));
        var run2 = MakeRun("b.xml", Failed("Test", "ClassB"));

        var result = aggregator.Aggregate([run1, run2]);

        // No flaky tests because they are different (ClassA vs ClassB)
        Assert.Empty(result.FlakyTests);
    }
}
