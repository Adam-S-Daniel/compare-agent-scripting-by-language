// MarkdownGenerator.cs - Generates a GitHub Actions job summary in Markdown.
// TDD Round 5 GREEN: Implements markdown generation to satisfy MarkdownGeneratorTests.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

/// <summary>
/// Generates a Markdown summary suitable for GitHub Actions job summaries
/// ($GITHUB_STEP_SUMMARY) from aggregated test results.
/// </summary>
public static class MarkdownGenerator
{
    public static string Generate(AggregatedResults results)
    {
        var sb = new StringBuilder();

        sb.AppendLine("# Test Results Summary");
        sb.AppendLine();

        if (results.RunCount == 0)
        {
            sb.AppendLine("⚠️ **No test results found.**");
            return sb.ToString();
        }

        // Overall status emoji
        var overallStatus = results.FlakyTests.Count > 0 ? "⚠️"
            : results.ConsistentlyFailing.Count > 0 ? "❌"
            : "✅";

        // Overview section
        sb.AppendLine($"{overallStatus} **{results.RunCount} runs** | **{results.UniqueTestCount} unique tests** | **{FormatDuration(results.TotalDuration)} total duration**");
        sb.AppendLine();

        // Per-run results table
        sb.AppendLine("## Per-Run Results");
        sb.AppendLine();
        sb.AppendLine("| Run | Total | ✅ Passed | ❌ Failed | ⏭️ Skipped | Duration |");
        sb.AppendLine("|-----|------:|----------:|----------:|-----------:|---------:|");

        foreach (var run in results.Runs)
        {
            sb.AppendLine($"| {run.Label} | {run.TotalCount} | {run.PassedCount} | {run.FailedCount} | {run.SkippedCount} | {FormatDuration(run.Duration)} |");
        }
        sb.AppendLine();

        // Flaky tests section (only if there are any)
        if (results.FlakyTests.Count > 0)
        {
            sb.AppendLine("## ⚠️ Flaky Tests");
            sb.AppendLine();
            sb.AppendLine("These tests produced inconsistent results across runs:");
            sb.AppendLine();
            sb.AppendLine("| Test | Passed In | Failed In |");
            sb.AppendLine("|------|-----------|-----------|");

            foreach (var flaky in results.FlakyTests.OrderBy(f => f.FullyQualifiedName))
            {
                var passedRuns = string.Join(", ", flaky.PassedInRuns);
                var failedRuns = string.Join(", ", flaky.FailedInRuns);
                sb.AppendLine($"| `{flaky.FullyQualifiedName}` | {passedRuns} | {failedRuns} |");
            }
            sb.AppendLine();
        }

        // Consistently failing tests
        if (results.ConsistentlyFailing.Count > 0)
        {
            sb.AppendLine("## ❌ Consistently Failing");
            sb.AppendLine();
            sb.AppendLine("These tests failed in every run:");
            sb.AppendLine();
            foreach (var test in results.ConsistentlyFailing.OrderBy(t => t.FullyQualifiedName))
            {
                sb.AppendLine($"- `{test.FullyQualifiedName}`");
            }
            sb.AppendLine();
        }

        // Skipped tests
        if (results.ConsistentlySkipped.Count > 0)
        {
            sb.AppendLine("## ⏭️ Consistently Skipped");
            sb.AppendLine();
            foreach (var test in results.ConsistentlySkipped.OrderBy(t => t.FullyQualifiedName))
            {
                sb.AppendLine($"- `{test.FullyQualifiedName}`");
            }
            sb.AppendLine();
        }

        return sb.ToString();
    }

    private static string FormatDuration(TimeSpan ts)
    {
        if (ts.TotalMinutes >= 1)
            return $"{ts.TotalMinutes:F1}m";
        return $"{ts.TotalSeconds:F2}s";
    }
}
