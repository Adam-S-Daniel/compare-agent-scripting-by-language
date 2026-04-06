namespace TestAggregator.Models;

/// <summary>The outcome of a single test case execution.</summary>
public enum TestStatus { Passed, Failed, Skipped, Error }

/// <summary>A single test case result from one run.</summary>
public record TestCase(
    string Name,
    string ClassName,
    string SuiteName,
    TestStatus Status,
    double DurationSeconds,
    string? ErrorMessage = null,
    string? ErrorType = null
);
