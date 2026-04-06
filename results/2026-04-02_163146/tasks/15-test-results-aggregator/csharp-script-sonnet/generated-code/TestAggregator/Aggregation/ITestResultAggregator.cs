using TestAggregator.Models;

namespace TestAggregator.Aggregation;

/// <summary>Aggregates multiple test runs into totals and detects flaky tests.</summary>
public interface ITestResultAggregator
{
    AggregatedResult Aggregate(IReadOnlyList<TestRun> runs);
}
