// Test Results Aggregator — file-based app entry point
// Usage: dotnet run aggregate.cs [directory] [--output <file>]
//
// Parses all .xml and .json test result files in the given directory,
// aggregates results across the matrix, detects flaky tests, and outputs
// a Markdown summary suitable for $GITHUB_STEP_SUMMARY.
//
// Examples:
//   dotnet run aggregate.cs fixtures/
//   dotnet run aggregate.cs fixtures/ --output summary.md

using TestAggregator.Aggregation;
using TestAggregator.Parsers;
using TestAggregator.Reporting;

// ── Parse CLI arguments ──────────────────────────────────────────────────────

string directory = ".";
string? outputFile = null;

for (int i = 0; i < args.Length; i++)
{
    if (args[i] == "--output" && i + 1 < args.Length)
    {
        outputFile = args[++i];
    }
    else if (!args[i].StartsWith("--"))
    {
        directory = args[i];
    }
}

if (!Directory.Exists(directory))
{
    Console.Error.WriteLine($"Error: Directory not found: {directory}");
    Environment.Exit(1);
}

// ── Discover and parse all test result files ─────────────────────────────────

var parsers = new ITestResultParser[] { new JUnitXmlParser(), new JsonTestResultParser() };

var files = Directory.GetFiles(directory, "*.*", SearchOption.TopDirectoryOnly)
    .Where(f => parsers.Any(p => p.CanParse(f)))
    .OrderBy(f => f)
    .ToList();

if (files.Count == 0)
{
    Console.Error.WriteLine($"Warning: No test result files found in: {directory}");
    Console.Error.WriteLine("  Supported formats: .xml (JUnit), .json");
}

var runs = new List<TestAggregator.Models.TestRun>();

foreach (var file in files)
{
    var parser = parsers.First(p => p.CanParse(file));
    try
    {
        var run = parser.Parse(file);
        runs.Add(run);
        Console.WriteLine($"  Parsed: {Path.GetFileName(file)} ({run.Suites.Sum(s => s.TestCases.Count)} tests)");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  Error parsing {file}: {ex.Message}");
    }
}

// ── Aggregate and report ──────────────────────────────────────────────────────

var aggregator = new TestResultAggregator();
var result = aggregator.Aggregate(runs);

var reporter = new MarkdownReporter();
var markdown = reporter.Generate(result);

// Output to stdout and optionally to a file
Console.WriteLine();
Console.WriteLine(markdown);

if (outputFile is not null)
{
    File.WriteAllText(outputFile, markdown);
    Console.WriteLine($"Summary written to: {outputFile}");
}

// Print a compact CLI summary
Console.WriteLine($"Results: {result.TotalPassed} passed, {result.TotalFailed} failed, " +
    $"{result.TotalSkipped} skipped across {runs.Count} file(s).");

if (result.FlakyTests.Count > 0)
{
    Console.WriteLine($"Flaky tests detected: {result.FlakyTests.Count}");
    foreach (var f in result.FlakyTests)
        Console.WriteLine($"  - {f.ClassName}.{f.Name} ({f.PassCount}P/{f.FailCount}F)");
}

// Exit non-zero if any tests failed (useful for CI)
Environment.Exit(result.TotalFailed > 0 || result.TotalError > 0 ? 1 : 0);
