namespace TestAggregator.Models;

/// <summary>Aggregated totals and flaky tests across all matrix runs.</summary>
public record AggregatedResult(
    int TotalPassed,
    int TotalFailed,
    int TotalSkipped,
    int TotalError,
    double TotalDurationSeconds,
    IReadOnlyList<FlakyTest> FlakyTests,
    IReadOnlyList<TestRun> Runs
)
{
    /// <summary>Sum of all test outcomes.</summary>
    public int TotalTests => TotalPassed + TotalFailed + TotalSkipped + TotalError;
}
