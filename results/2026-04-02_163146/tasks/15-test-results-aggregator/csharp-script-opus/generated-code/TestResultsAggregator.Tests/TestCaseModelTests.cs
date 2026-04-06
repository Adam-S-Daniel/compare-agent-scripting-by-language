// TDD Round 1 - RED: Tests for the TestCase and TestRun model classes.
// These tests define the expected shape of our domain model before we write it.

using Xunit;

namespace TestResultsAggregator.Tests;

public class TestCaseModelTests
{
    // RED: TestCase should hold name, suite, status, duration, and optional error info
    [Fact]
    public void TestCase_ShouldStoreBasicProperties()
    {
        var tc = new TestCase
        {
            Name = "TestAddition",
            Suite = "MathTests",
            Status = TestStatus.Passed,
            Duration = TimeSpan.FromSeconds(1.2)
        };

        Assert.Equal("TestAddition", tc.Name);
        Assert.Equal("MathTests", tc.Suite);
        Assert.Equal(TestStatus.Passed, tc.Status);
        Assert.Equal(1.2, tc.Duration.TotalSeconds, precision: 3);
    }

    [Fact]
    public void TestCase_FailedShouldHaveErrorMessage()
    {
        var tc = new TestCase
        {
            Name = "TestSubtraction",
            Suite = "MathTests",
            Status = TestStatus.Failed,
            Duration = TimeSpan.FromSeconds(2.0),
            ErrorMessage = "Expected 5 but got 4"
        };

        Assert.Equal(TestStatus.Failed, tc.Status);
        Assert.Equal("Expected 5 but got 4", tc.ErrorMessage);
    }

    [Fact]
    public void TestCase_SkippedShouldHaveSkipReason()
    {
        var tc = new TestCase
        {
            Name = "TestSplit",
            Suite = "StringTests",
            Status = TestStatus.Skipped,
            Duration = TimeSpan.Zero,
            SkipReason = "Not implemented yet"
        };

        Assert.Equal(TestStatus.Skipped, tc.Status);
        Assert.Equal("Not implemented yet", tc.SkipReason);
    }

    [Fact]
    public void TestCase_FullyQualifiedNameCombinesSuiteAndName()
    {
        var tc = new TestCase { Name = "TestAddition", Suite = "MathTests" };
        Assert.Equal("MathTests.TestAddition", tc.FullyQualifiedName);
    }
}

public class TestRunModelTests
{
    // RED: TestRun should hold a label, list of test cases, and a total duration
    [Fact]
    public void TestRun_ShouldStoreRunLabelAndCases()
    {
        var run = new TestRun
        {
            Label = "Run1-Ubuntu",
            Duration = TimeSpan.FromSeconds(12.345),
            TestCases =
            [
                new TestCase { Name = "TestAddition", Suite = "MathTests", Status = TestStatus.Passed, Duration = TimeSpan.FromSeconds(1.2) },
                new TestCase { Name = "TestSubtraction", Suite = "MathTests", Status = TestStatus.Failed, Duration = TimeSpan.FromSeconds(2.0), ErrorMessage = "Expected 5 but got 4" }
            ]
        };

        Assert.Equal("Run1-Ubuntu", run.Label);
        Assert.Equal(2, run.TestCases.Count);
        Assert.Equal(12.345, run.Duration.TotalSeconds, precision: 3);
    }

    [Fact]
    public void TestRun_CountsShouldReflectStatuses()
    {
        var run = new TestRun
        {
            Label = "Test",
            TestCases =
            [
                new TestCase { Name = "A", Suite = "S", Status = TestStatus.Passed },
                new TestCase { Name = "B", Suite = "S", Status = TestStatus.Failed },
                new TestCase { Name = "C", Suite = "S", Status = TestStatus.Skipped },
                new TestCase { Name = "D", Suite = "S", Status = TestStatus.Passed }
            ]
        };

        Assert.Equal(2, run.PassedCount);
        Assert.Equal(1, run.FailedCount);
        Assert.Equal(1, run.SkippedCount);
        Assert.Equal(4, run.TotalCount);
    }
}
