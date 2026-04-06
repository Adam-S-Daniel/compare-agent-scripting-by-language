namespace TestAggregator.Models;

/// <summary>All test results parsed from a single file (one matrix job output).</summary>
public record TestRun(
    string SourceFile,
    string Format,  // "junit-xml" or "json"
    IReadOnlyList<TestSuite> Suites
);
