// ResultsAggregator.cs - Aggregates multiple test runs and detects flaky tests.
// TDD Round 4 GREEN: Implements aggregation to satisfy AggregatorTests.

using System;
using System.Collections.Generic;
using System.Linq;

/// <summary>Information about a flaky test (passed in some runs, failed in others).</summary>
public class FlakyTestInfo
{
    public required string FullyQualifiedName { get; set; }
    public required string Name { get; set; }
    public required string Suite { get; set; }
    public List<string> PassedInRuns { get; set; } = [];
    public List<string> FailedInRuns { get; set; } = [];
}

/// <summary>Aggregated results across all test runs.</summary>
public class AggregatedResults
{
    public int RunCount { get; set; }
    public int UniqueTestCount { get; set; }
    public TimeSpan TotalDuration { get; set; }
    public List<FlakyTestInfo> FlakyTests { get; set; } = [];
    public List<TestIdentifier> ConsistentlyPassing { get; set; } = [];
    public List<TestIdentifier> ConsistentlyFailing { get; set; } = [];
    public List<TestIdentifier> ConsistentlySkipped { get; set; } = [];
    public List<TestRun> Runs { get; set; } = [];
}

/// <summary>Lightweight test identifier (no per-run data).</summary>
public class TestIdentifier
{
    public required string Name { get; set; }
    public required string Suite { get; set; }
    public string FullyQualifiedName => $"{Suite}.{Name}";
}

/// <summary>
/// Aggregates test results from multiple runs, computes totals,
/// and identifies flaky/consistent tests.
/// </summary>
public static class ResultsAggregator
{
    public static AggregatedResults Aggregate(List<TestRun> runs)
    {
        if (runs.Count == 0)
        {
            return new AggregatedResults();
        }

        // Group all test case occurrences by their fully-qualified name
        var testHistory = new Dictionary<string, List<(string RunLabel, TestCase TestCase)>>();

        foreach (var run in runs)
        {
            foreach (var tc in run.TestCases)
            {
                var key = tc.FullyQualifiedName;
                if (!testHistory.TryGetValue(key, out var list))
                {
                    list = [];
                    testHistory[key] = list;
                }
                list.Add((run.Label, tc));
            }
        }

        var flaky = new List<FlakyTestInfo>();
        var consistentlyPassing = new List<TestIdentifier>();
        var consistentlyFailing = new List<TestIdentifier>();
        var consistentlySkipped = new List<TestIdentifier>();

        foreach (var (fqn, entries) in testHistory)
        {
            // Only consider non-skipped results for flaky detection
            var nonSkipped = entries.Where(e => e.TestCase.Status != TestStatus.Skipped).ToList();
            var skippedEntries = entries.Where(e => e.TestCase.Status == TestStatus.Skipped).ToList();

            var first = entries[0].TestCase;
            var id = new TestIdentifier { Name = first.Name, Suite = first.Suite };

            if (nonSkipped.Count == 0)
            {
                // All entries are skipped
                consistentlySkipped.Add(id);
            }
            else
            {
                var hasPassed = nonSkipped.Any(e => e.TestCase.Status == TestStatus.Passed);
                var hasFailed = nonSkipped.Any(e => e.TestCase.Status == TestStatus.Failed);

                if (hasPassed && hasFailed)
                {
                    // Flaky: both passed and failed across runs
                    flaky.Add(new FlakyTestInfo
                    {
                        FullyQualifiedName = fqn,
                        Name = first.Name,
                        Suite = first.Suite,
                        PassedInRuns = nonSkipped
                            .Where(e => e.TestCase.Status == TestStatus.Passed)
                            .Select(e => e.RunLabel)
                            .ToList(),
                        FailedInRuns = nonSkipped
                            .Where(e => e.TestCase.Status == TestStatus.Failed)
                            .Select(e => e.RunLabel)
                            .ToList()
                    });
                }
                else if (hasPassed)
                {
                    consistentlyPassing.Add(id);
                }
                else if (hasFailed)
                {
                    consistentlyFailing.Add(id);
                }
            }
        }

        return new AggregatedResults
        {
            RunCount = runs.Count,
            UniqueTestCount = testHistory.Count,
            TotalDuration = TimeSpan.FromTicks(runs.Sum(r => r.Duration.Ticks)),
            FlakyTests = flaky,
            ConsistentlyPassing = consistentlyPassing,
            ConsistentlyFailing = consistentlyFailing,
            ConsistentlySkipped = consistentlySkipped,
            Runs = runs
        };
    }
}
