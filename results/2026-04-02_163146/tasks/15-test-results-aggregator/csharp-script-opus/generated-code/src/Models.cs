// Models.cs - Domain model for test results aggregation.
// TDD Round 1 GREEN: Minimum model to satisfy TestCaseModelTests and TestRunModelTests.

using System;
using System.Collections.Generic;
using System.Linq;

/// <summary>Possible outcomes for a single test case.</summary>
public enum TestStatus
{
    Passed,
    Failed,
    Skipped
}

/// <summary>Represents a single test case result from any format.</summary>
public class TestCase
{
    public required string Name { get; set; }
    public required string Suite { get; set; }
    public TestStatus Status { get; set; }
    public TimeSpan Duration { get; set; }
    public string? ErrorMessage { get; set; }
    public string? SkipReason { get; set; }

    /// <summary>Unique identifier combining suite and test name (e.g. "MathTests.TestAddition").</summary>
    public string FullyQualifiedName => $"{Suite}.{Name}";
}

/// <summary>Represents one complete test run (e.g. one matrix leg).</summary>
public class TestRun
{
    public string Label { get; set; } = "";
    public TimeSpan Duration { get; set; }
    public List<TestCase> TestCases { get; set; } = [];

    // Convenience counts derived from the test case list
    public int TotalCount => TestCases.Count;
    public int PassedCount => TestCases.Count(tc => tc.Status == TestStatus.Passed);
    public int FailedCount => TestCases.Count(tc => tc.Status == TestStatus.Failed);
    public int SkippedCount => TestCases.Count(tc => tc.Status == TestStatus.Skipped);
}
