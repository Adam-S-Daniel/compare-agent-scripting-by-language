// TDD Wave 1: Model structure tests
// These tests fail first (compilation error) because TestCase, TestSuite etc. don't exist yet.
// Writing them first drives the creation of all model types.

using TestAggregator.Models;
using Xunit;

namespace TestAggregator.Tests;

public class ModelTests
{
    [Fact]
    public void TestCase_WithPassedStatus_HasCorrectProperties()
    {
        // Arrange & Act
        var tc = new TestCase(
            Name: "MyTest",
            ClassName: "MyClass",
            SuiteName: "MySuite",
            Status: TestStatus.Passed,
            DurationSeconds: 1.5
        );

        // Assert
        Assert.Equal("MyTest", tc.Name);
        Assert.Equal("MyClass", tc.ClassName);
        Assert.Equal("MySuite", tc.SuiteName);
        Assert.Equal(TestStatus.Passed, tc.Status);
        Assert.Equal(1.5, tc.DurationSeconds);
        Assert.Null(tc.ErrorMessage);
    }

    [Fact]
    public void TestCase_WithFailedStatus_HasErrorMessage()
    {
        var tc = new TestCase(
            Name: "FailingTest",
            ClassName: "MyClass",
            SuiteName: "MySuite",
            Status: TestStatus.Failed,
            DurationSeconds: 0.2,
            ErrorMessage: "Expected 1 but was 2"
        );

        Assert.Equal(TestStatus.Failed, tc.Status);
        Assert.Equal("Expected 1 but was 2", tc.ErrorMessage);
    }

    [Fact]
    public void AggregatedResult_TotalTests_SumsAllStatuses()
    {
        var result = new AggregatedResult(
            TotalPassed: 5,
            TotalFailed: 2,
            TotalSkipped: 1,
            TotalError: 0,
            TotalDurationSeconds: 3.14,
            FlakyTests: [],
            Runs: []
        );

        Assert.Equal(8, result.TotalTests);
    }
}
