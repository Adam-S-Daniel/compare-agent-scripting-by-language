namespace TestAggregator.Models;

/// <summary>A named collection of test cases from one suite within a run.</summary>
public record TestSuite(
    string Name,
    IReadOnlyList<TestCase> TestCases,
    string SourceFile
);
