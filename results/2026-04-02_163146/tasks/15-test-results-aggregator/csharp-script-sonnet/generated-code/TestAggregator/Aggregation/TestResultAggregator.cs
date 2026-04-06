using TestAggregator.Models;

namespace TestAggregator.Aggregation;

/// <summary>
/// Aggregates test runs across a matrix build.
///
/// Flakiness algorithm:
///   For each unique (ClassName, TestName) pair, track pass/fail counts across all runs.
///   A test is flaky when passCount > 0 AND failCount > 0.
///
/// The composite key uses '|' as separator — safe because JUnit class names use
/// dot-separated package notation which never contains pipes.
/// </summary>
public class TestResultAggregator : ITestResultAggregator
{
    public AggregatedResult Aggregate(IReadOnlyList<TestRun> runs)
    {
        int passed = 0, failed = 0, skipped = 0, error = 0;
        double duration = 0.0;

        // Key: "ClassName|TestName" → (passCount, failCount, failingFiles)
        var tracking = new Dictionary<string, (int pass, int fail, List<string> failFiles)>();

        foreach (var run in runs)
        {
            foreach (var suite in run.Suites)
            {
                foreach (var tc in suite.TestCases)
                {
                    duration += tc.DurationSeconds;

                    switch (tc.Status)
                    {
                        case TestStatus.Passed:  passed++;  break;
                        case TestStatus.Failed:  failed++;  break;
                        case TestStatus.Skipped: skipped++; break;
                        case TestStatus.Error:   error++;   break;
                    }

                    // Only track Passed/Failed for flakiness — Skipped/Error are excluded
                    if (tc.Status is not (TestStatus.Passed or TestStatus.Failed or TestStatus.Error))
                        continue;

                    var key = $"{tc.ClassName}|{tc.Name}";
                    if (!tracking.TryGetValue(key, out var entry))
                        entry = (0, 0, new List<string>());

                    if (tc.Status == TestStatus.Passed)
                    {
                        tracking[key] = (entry.pass + 1, entry.fail, entry.failFiles);
                    }
                    else // Failed or Error
                    {
                        entry.failFiles.Add(run.SourceFile);
                        tracking[key] = (entry.pass, entry.fail + 1, entry.failFiles);
                    }
                }
            }
        }

        var flakyTests = tracking
            .Where(kv => kv.Value.pass > 0 && kv.Value.fail > 0)
            .Select(kv =>
            {
                var parts = kv.Key.Split('|', 2);
                return new FlakyTest(
                    Name: parts[1],
                    ClassName: parts[0],
                    PassCount: kv.Value.pass,
                    FailCount: kv.Value.fail,
                    FailingFiles: kv.Value.failFiles.AsReadOnly()
                );
            })
            .OrderBy(f => f.ClassName)
            .ThenBy(f => f.Name)
            .ToList();

        return new AggregatedResult(passed, failed, skipped, error, duration, flakyTests, runs);
    }
}
