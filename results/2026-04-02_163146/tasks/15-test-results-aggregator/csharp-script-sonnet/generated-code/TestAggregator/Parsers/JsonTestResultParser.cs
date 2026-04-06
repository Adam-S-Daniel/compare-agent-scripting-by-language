using System.Text.Json;
using TestAggregator.Models;

namespace TestAggregator.Parsers;

/// <summary>
/// Parses JSON test result files in our custom schema:
/// { "suiteName": "...", "testCases": [ { "name", "className", "status", "duration", "errorMessage?" } ] }
/// Uses System.Text.Json (in-box, no NuGet required).
/// </summary>
public class JsonTestResultParser : ITestResultParser
{
    public bool CanParse(string filePath) =>
        Path.GetExtension(filePath).Equals(".json", StringComparison.OrdinalIgnoreCase);

    public TestRun Parse(string filePath)
    {
        var json = File.ReadAllText(filePath);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var suiteName = root.TryGetProperty("suiteName", out var snProp)
            ? snProp.GetString() ?? "Unknown"
            : Path.GetFileNameWithoutExtension(filePath);

        var cases = new List<TestCase>();

        if (root.TryGetProperty("testCases", out var tcArray))
        {
            foreach (var tc in tcArray.EnumerateArray())
            {
                cases.Add(ParseTestCase(tc, suiteName));
            }
        }

        var suite = new TestSuite(suiteName, cases, filePath);
        return new TestRun(filePath, "json", [suite]);
    }

    private static TestCase ParseTestCase(JsonElement el, string suiteName)
    {
        var name = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown";
        var className = el.TryGetProperty("className", out var cn) ? cn.GetString() ?? suiteName : suiteName;
        var duration = el.TryGetProperty("duration", out var d) ? d.GetDouble() : 0.0;
        var errorMessage = el.TryGetProperty("errorMessage", out var em) ? em.GetString() : null;

        var statusStr = el.TryGetProperty("status", out var s) ? s.GetString() ?? "passed" : "passed";
        var status = statusStr.ToLowerInvariant() switch
        {
            "passed" or "pass" or "ok" => TestStatus.Passed,
            "failed" or "fail" or "failure" => TestStatus.Failed,
            "skipped" or "skip" or "pending" or "ignored" => TestStatus.Skipped,
            "error" => TestStatus.Error,
            _ => throw new InvalidDataException($"Unknown test status '{statusStr}'")
        };

        return new TestCase(name, className, suiteName, status, duration, errorMessage);
    }
}
