// TestResultsAggregator.cs - Main entry point (.NET 10 file-based app).
// Run with: dotnet run TestResultsAggregator.cs [directory-or-files...]
//
// This script parses test result files (JUnit XML and JSON), aggregates results
// across multiple files (simulating a matrix build), computes totals and identifies
// flaky tests, then generates a Markdown summary for GitHub Actions job summaries.
//
// Usage:
//   dotnet run TestResultsAggregator.cs fixtures/
//   dotnet run TestResultsAggregator.cs file1.xml file2.json
//   dotnet run TestResultsAggregator.cs fixtures/ --output summary.md

#:package System.Xml.Linq@*

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Xml.Linq;

// --- Inline all source files for file-based app execution ---
// (The test project compiles these from src/ separately)

#region Models

/// <summary>Possible outcomes for a single test case.</summary>
enum TestStatus { Passed, Failed, Skipped }

/// <summary>Represents a single test case result from any format.</summary>
class TestCase
{
    public required string Name { get; set; }
    public required string Suite { get; set; }
    public TestStatus Status { get; set; }
    public TimeSpan Duration { get; set; }
    public string? ErrorMessage { get; set; }
    public string? SkipReason { get; set; }
    public string FullyQualifiedName => $"{Suite}.{Name}";
}

/// <summary>Represents one complete test run (e.g. one matrix leg).</summary>
class TestRun
{
    public string Label { get; set; } = "";
    public TimeSpan Duration { get; set; }
    public List<TestCase> TestCases { get; set; } = [];
    public int TotalCount => TestCases.Count;
    public int PassedCount => TestCases.Count(tc => tc.Status == TestStatus.Passed);
    public int FailedCount => TestCases.Count(tc => tc.Status == TestStatus.Failed);
    public int SkippedCount => TestCases.Count(tc => tc.Status == TestStatus.Skipped);
}

class TestResultParseException : Exception
{
    public TestResultParseException(string message) : base(message) { }
    public TestResultParseException(string message, Exception inner) : base(message, inner) { }
}

class FlakyTestInfo
{
    public required string FullyQualifiedName { get; set; }
    public required string Name { get; set; }
    public required string Suite { get; set; }
    public List<string> PassedInRuns { get; set; } = [];
    public List<string> FailedInRuns { get; set; } = [];
}

class TestIdentifier
{
    public required string Name { get; set; }
    public required string Suite { get; set; }
    public string FullyQualifiedName => $"{Suite}.{Name}";
}

class AggregatedResults
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

#endregion

#region JUnit Parser

static class JUnitParserInline
{
    public static TestRun Parse(string xml, string label)
    {
        XDocument doc;
        try { doc = XDocument.Parse(xml); }
        catch (Exception ex)
        {
            throw new TestResultParseException($"Failed to parse JUnit XML for '{label}': {ex.Message}", ex);
        }

        var root = doc.Root ?? throw new TestResultParseException($"JUnit XML for '{label}' has no root element.");
        var suites = root.Name.LocalName == "testsuites"
            ? root.Elements("testsuite")
            : root.Name.LocalName == "testsuite" ? [root]
            : throw new TestResultParseException($"JUnit XML for '{label}': expected <testsuites> or <testsuite> root.");

        var testCases = new List<TestCase>();
        foreach (var suite in suites)
        {
            var suiteName = suite.Attribute("name")?.Value ?? "UnknownSuite";
            foreach (var tc in suite.Elements("testcase"))
            {
                var name = tc.Attribute("name")?.Value ?? "UnknownTest";
                var className = tc.Attribute("classname")?.Value ?? suiteName;
                var duration = ParseSec(tc.Attribute("time")?.Value);
                var failure = tc.Element("failure");
                var error = tc.Element("error");
                var skipped = tc.Element("skipped");

                TestStatus status;
                string? errorMsg = null, skipReason = null;
                if (failure != null) { status = TestStatus.Failed; errorMsg = failure.Attribute("message")?.Value ?? failure.Value; }
                else if (error != null) { status = TestStatus.Failed; errorMsg = error.Attribute("message")?.Value ?? error.Value; }
                else if (skipped != null) { status = TestStatus.Skipped; skipReason = skipped.Attribute("message")?.Value; }
                else { status = TestStatus.Passed; }

                testCases.Add(new TestCase { Name = name, Suite = className, Status = status, Duration = duration, ErrorMessage = errorMsg, SkipReason = skipReason });
            }
        }

        return new TestRun { Label = label, Duration = ParseSec(root.Attribute("time")?.Value), TestCases = testCases };
    }

    static TimeSpan ParseSec(string? v) =>
        !string.IsNullOrWhiteSpace(v) && double.TryParse(v, CultureInfo.InvariantCulture, out var s)
            ? TimeSpan.FromSeconds(s) : TimeSpan.Zero;
}

#endregion

#region JSON Parser

static class JsonTestParserInline
{
    public static TestRun Parse(string json, string label)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(json); }
        catch (Exception ex)
        {
            throw new TestResultParseException($"Failed to parse JSON test results for '{label}': {ex.Message}", ex);
        }

        var root = doc.RootElement;
        var duration = root.TryGetProperty("duration", out var d) ? d.GetDouble() : 0.0;
        var testCases = new List<TestCase>();

        if (root.TryGetProperty("testCases", out var cases))
        {
            foreach (var tc in cases.EnumerateArray())
            {
                var status = (tc.GetProperty("status").GetString() ?? "passed").ToLowerInvariant() switch
                {
                    "failed" => TestStatus.Failed,
                    "skipped" => TestStatus.Skipped,
                    _ => TestStatus.Passed
                };
                string? errMsg = tc.TryGetProperty("error", out var err) && err.TryGetProperty("message", out var m) ? m.GetString() : null;
                string? skipR = tc.TryGetProperty("skipReason", out var sr) ? sr.GetString() : null;

                testCases.Add(new TestCase
                {
                    Name = tc.GetProperty("name").GetString() ?? "Unknown",
                    Suite = tc.GetProperty("suite").GetString() ?? "Unknown",
                    Status = status,
                    Duration = TimeSpan.FromSeconds(tc.TryGetProperty("duration", out var td) ? td.GetDouble() : 0),
                    ErrorMessage = errMsg,
                    SkipReason = skipR
                });
            }
        }

        return new TestRun { Label = label, Duration = TimeSpan.FromSeconds(duration), TestCases = testCases };
    }
}

#endregion

#region Aggregator

static class ResultsAggregatorInline
{
    public static AggregatedResults Aggregate(List<TestRun> runs)
    {
        if (runs.Count == 0) return new AggregatedResults();

        var history = new Dictionary<string, List<(string RunLabel, TestCase TC)>>();
        foreach (var run in runs)
            foreach (var tc in run.TestCases)
            {
                if (!history.TryGetValue(tc.FullyQualifiedName, out var list)) { list = []; history[tc.FullyQualifiedName] = list; }
                list.Add((run.Label, tc));
            }

        var flaky = new List<FlakyTestInfo>();
        var passing = new List<TestIdentifier>();
        var failing = new List<TestIdentifier>();
        var skipped = new List<TestIdentifier>();

        foreach (var (_, entries) in history)
        {
            var nonSkip = entries.Where(e => e.TC.Status != TestStatus.Skipped).ToList();
            var first = entries[0].TC;
            var id = new TestIdentifier { Name = first.Name, Suite = first.Suite };

            if (nonSkip.Count == 0) { skipped.Add(id); continue; }
            bool hp = nonSkip.Any(e => e.TC.Status == TestStatus.Passed), hf = nonSkip.Any(e => e.TC.Status == TestStatus.Failed);
            if (hp && hf) flaky.Add(new FlakyTestInfo
            {
                FullyQualifiedName = first.FullyQualifiedName, Name = first.Name, Suite = first.Suite,
                PassedInRuns = nonSkip.Where(e => e.TC.Status == TestStatus.Passed).Select(e => e.RunLabel).ToList(),
                FailedInRuns = nonSkip.Where(e => e.TC.Status == TestStatus.Failed).Select(e => e.RunLabel).ToList()
            });
            else if (hp) passing.Add(id);
            else if (hf) failing.Add(id);
        }

        return new AggregatedResults
        {
            RunCount = runs.Count, UniqueTestCount = history.Count,
            TotalDuration = TimeSpan.FromTicks(runs.Sum(r => r.Duration.Ticks)),
            FlakyTests = flaky, ConsistentlyPassing = passing,
            ConsistentlyFailing = failing, ConsistentlySkipped = skipped, Runs = runs
        };
    }
}

#endregion

#region Markdown Generator

static class MarkdownGeneratorInline
{
    public static string Generate(AggregatedResults results)
    {
        var sb = new StringBuilder();
        sb.AppendLine("# Test Results Summary");
        sb.AppendLine();

        if (results.RunCount == 0) { sb.AppendLine("⚠️ **No test results found.**"); return sb.ToString(); }

        var emoji = results.FlakyTests.Count > 0 ? "⚠️" : results.ConsistentlyFailing.Count > 0 ? "❌" : "✅";
        sb.AppendLine($"{emoji} **{results.RunCount} runs** | **{results.UniqueTestCount} unique tests** | **{Fmt(results.TotalDuration)} total duration**");
        sb.AppendLine();

        sb.AppendLine("## Per-Run Results");
        sb.AppendLine();
        sb.AppendLine("| Run | Total | ✅ Passed | ❌ Failed | ⏭️ Skipped | Duration |");
        sb.AppendLine("|-----|------:|----------:|----------:|-----------:|---------:|");
        foreach (var run in results.Runs)
            sb.AppendLine($"| {run.Label} | {run.TotalCount} | {run.PassedCount} | {run.FailedCount} | {run.SkippedCount} | {Fmt(run.Duration)} |");
        sb.AppendLine();

        if (results.FlakyTests.Count > 0)
        {
            sb.AppendLine("## ⚠️ Flaky Tests");
            sb.AppendLine();
            sb.AppendLine("These tests produced inconsistent results across runs:");
            sb.AppendLine();
            sb.AppendLine("| Test | Passed In | Failed In |");
            sb.AppendLine("|------|-----------|-----------|");
            foreach (var f in results.FlakyTests.OrderBy(f => f.FullyQualifiedName))
                sb.AppendLine($"| `{f.FullyQualifiedName}` | {string.Join(", ", f.PassedInRuns)} | {string.Join(", ", f.FailedInRuns)} |");
            sb.AppendLine();
        }

        if (results.ConsistentlyFailing.Count > 0)
        {
            sb.AppendLine("## ❌ Consistently Failing");
            sb.AppendLine();
            foreach (var t in results.ConsistentlyFailing.OrderBy(t => t.FullyQualifiedName))
                sb.AppendLine($"- `{t.FullyQualifiedName}`");
            sb.AppendLine();
        }

        if (results.ConsistentlySkipped.Count > 0)
        {
            sb.AppendLine("## ⏭️ Consistently Skipped");
            sb.AppendLine();
            foreach (var t in results.ConsistentlySkipped.OrderBy(t => t.FullyQualifiedName))
                sb.AppendLine($"- `{t.FullyQualifiedName}`");
            sb.AppendLine();
        }

        return sb.ToString();
    }

    static string Fmt(TimeSpan ts) => ts.TotalMinutes >= 1 ? $"{ts.TotalMinutes:F1}m" : $"{ts.TotalSeconds:F2}s";
}

#endregion

#region File Loader

enum TestFileFormat { JUnitXml, Json }

static class FileLoaderInline
{
    static readonly string[] Exts = [".xml", ".json"];

    public static TestFileFormat DetectFormat(string path) => Path.GetExtension(path).ToLowerInvariant() switch
    {
        ".xml" => TestFileFormat.JUnitXml,
        ".json" => TestFileFormat.Json,
        _ => throw new TestResultParseException($"Unsupported format for '{path}'")
    };

    public static TestRun LoadFile(string path)
    {
        if (!File.Exists(path)) throw new TestResultParseException($"File not found: {path}");
        var content = File.ReadAllText(path);
        var label = Path.GetFileNameWithoutExtension(path);
        return DetectFormat(path) switch
        {
            TestFileFormat.JUnitXml => JUnitParserInline.Parse(content, label),
            TestFileFormat.Json => JsonTestParserInline.Parse(content, label),
            _ => throw new TestResultParseException($"Unknown format")
        };
    }

    public static List<TestRun> LoadDirectory(string dir)
    {
        if (!Directory.Exists(dir)) throw new TestResultParseException($"Directory not found: {dir}");
        var files = Exts.SelectMany(ext => Directory.GetFiles(dir, $"*{ext}")).OrderBy(f => f).ToList();
        if (files.Count == 0) throw new TestResultParseException($"No supported files in '{dir}'");

        var runs = new List<TestRun>();
        foreach (var f in files)
            try { runs.Add(LoadFile(f)); }
            catch (TestResultParseException ex) { Console.Error.WriteLine($"Warning: {ex.Message}"); }
        return runs;
    }
}

#endregion

// --- Main entry point ---

if (args.Length == 0)
{
    Console.Error.WriteLine("Usage: dotnet run TestResultsAggregator.cs <directory-or-files...> [--output <file.md>]");
    Console.Error.WriteLine();
    Console.Error.WriteLine("Examples:");
    Console.Error.WriteLine("  dotnet run TestResultsAggregator.cs fixtures/");
    Console.Error.WriteLine("  dotnet run TestResultsAggregator.cs run1.xml run2.json");
    Console.Error.WriteLine("  dotnet run TestResultsAggregator.cs fixtures/ --output summary.md");
    return 1;
}

// Parse arguments
string? outputFile = null;
var inputs = new List<string>();

for (int i = 0; i < args.Length; i++)
{
    if (args[i] == "--output" && i + 1 < args.Length)
    {
        outputFile = args[++i];
    }
    else
    {
        inputs.Add(args[i]);
    }
}

try
{
    // Load all test result files
    var allRuns = new List<TestRun>();

    foreach (var input in inputs)
    {
        if (Directory.Exists(input))
        {
            allRuns.AddRange(FileLoaderInline.LoadDirectory(input));
        }
        else if (File.Exists(input))
        {
            allRuns.Add(FileLoaderInline.LoadFile(input));
        }
        else
        {
            Console.Error.WriteLine($"Error: '{input}' is not a file or directory.");
            return 1;
        }
    }

    if (allRuns.Count == 0)
    {
        Console.Error.WriteLine("Error: No test results loaded.");
        return 1;
    }

    // Aggregate results across all runs
    var aggregated = ResultsAggregatorInline.Aggregate(allRuns);

    // Generate markdown summary
    var markdown = MarkdownGeneratorInline.Generate(aggregated);

    // Output
    if (outputFile != null)
    {
        File.WriteAllText(outputFile, markdown);
        Console.WriteLine($"Summary written to {outputFile}");
    }
    else
    {
        Console.Write(markdown);
    }

    // Exit with non-zero if there are failures
    return aggregated.ConsistentlyFailing.Count > 0 ? 1 : 0;
}
catch (TestResultParseException ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    return 1;
}
