using System.Text;
using TestAggregator.Models;

namespace TestAggregator.Reporting;

/// <summary>
/// Generates a GitHub Actions-compatible Markdown summary from an AggregatedResult.
/// Output is suitable for writing to $GITHUB_STEP_SUMMARY.
///
/// Sections:
///   ## Test Results Summary   — overall totals table
///   ### Results by File       — per-run breakdown table
///   ### Flaky Tests           — only present when flaky tests are detected
/// </summary>
public class MarkdownReporter
{
    public string Generate(AggregatedResult result)
    {
        var sb = new StringBuilder();

        AppendSummarySection(sb, result);
        AppendResultsByFileSection(sb, result);

        if (result.FlakyTests.Count > 0)
            AppendFlakyTestsSection(sb, result);

        return sb.ToString();
    }

    private static void AppendSummarySection(StringBuilder sb, AggregatedResult r)
    {
        sb.AppendLine("## Test Results Summary");
        sb.AppendLine();

        // Status badge line
        var status = r.TotalFailed > 0 || r.TotalError > 0 ? "FAILED" : "PASSED";
        sb.AppendLine($"> **Status: {status}**");
        sb.AppendLine();

        sb.AppendLine("| Metric | Value |");
        sb.AppendLine("|--------|-------|");
        sb.AppendLine($"| Total Tests | {r.TotalTests} |");
        sb.AppendLine($"| Passed | {r.TotalPassed} |");
        sb.AppendLine($"| Failed | {r.TotalFailed} |");
        sb.AppendLine($"| Skipped | {r.TotalSkipped} |");
        sb.AppendLine($"| Errors | {r.TotalError} |");
        sb.AppendLine($"| Total Duration | {r.TotalDurationSeconds:F2}s |");
        sb.AppendLine($"| Source Files | {r.Runs.Count} |");
        sb.AppendLine($"| Flaky Tests | {r.FlakyTests.Count} |");
        sb.AppendLine();
    }

    private static void AppendResultsByFileSection(StringBuilder sb, AggregatedResult r)
    {
        if (r.Runs.Count == 0) return;

        sb.AppendLine("### Results by File");
        sb.AppendLine();
        sb.AppendLine("| File | Format | Tests | Passed | Failed | Skipped | Duration |");
        sb.AppendLine("|------|--------|-------|--------|--------|---------|----------|");

        foreach (var run in r.Runs)
        {
            var allCases = run.Suites.SelectMany(s => s.TestCases).ToList();
            var runPassed = allCases.Count(t => t.Status == TestStatus.Passed);
            var runFailed = allCases.Count(t => t.Status is TestStatus.Failed or TestStatus.Error);
            var runSkipped = allCases.Count(t => t.Status == TestStatus.Skipped);
            var runDuration = allCases.Sum(t => t.DurationSeconds);
            var fileName = Path.GetFileName(run.SourceFile);

            sb.AppendLine($"| {fileName} | {run.Format} | {allCases.Count} | {runPassed} | {runFailed} | {runSkipped} | {runDuration:F2}s |");
        }

        sb.AppendLine();
    }

    private static void AppendFlakyTestsSection(StringBuilder sb, AggregatedResult r)
    {
        sb.AppendLine("### Flaky Tests");
        sb.AppendLine();
        sb.AppendLine("> Tests that passed in some runs and failed in others.");
        sb.AppendLine();
        sb.AppendLine("| Test | Class | Passes | Failures | Failed In |");
        sb.AppendLine("|------|-------|--------|----------|-----------|");

        foreach (var f in r.FlakyTests)
        {
            var failingFiles = string.Join(", ", f.FailingFiles.Select(Path.GetFileName));
            sb.AppendLine($"| {f.Name} | {f.ClassName} | {f.PassCount} | {f.FailCount} | {failingFiles} |");
        }

        sb.AppendLine();
    }
}
