// JsonTestParser.cs - Parses JSON test result format into our TestRun model.
// TDD Round 3 GREEN: Implements parsing to satisfy JsonParserTests.

using System;
using System.Collections.Generic;
using System.Text.Json;

/// <summary>Parses a JSON test results file into a <see cref="TestRun"/>.</summary>
public static class JsonTestParser
{
    public static TestRun Parse(string json, string label)
    {
        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (Exception ex)
        {
            throw new TestResultParseException(
                $"Failed to parse JSON test results for '{label}': {ex.Message}", ex);
        }

        var root = doc.RootElement;

        var duration = root.TryGetProperty("duration", out var durProp)
            ? durProp.GetDouble()
            : 0.0;

        var testCases = new List<TestCase>();

        if (root.TryGetProperty("testCases", out var casesArray))
        {
            foreach (var tc in casesArray.EnumerateArray())
            {
                var name = tc.GetProperty("name").GetString() ?? "Unknown";
                var suite = tc.GetProperty("suite").GetString() ?? "Unknown";
                var statusStr = tc.GetProperty("status").GetString() ?? "passed";
                var tcDuration = tc.TryGetProperty("duration", out var d) ? d.GetDouble() : 0.0;

                var status = statusStr.ToLowerInvariant() switch
                {
                    "passed" => TestStatus.Passed,
                    "failed" => TestStatus.Failed,
                    "skipped" => TestStatus.Skipped,
                    _ => TestStatus.Passed
                };

                string? errorMessage = null;
                if (tc.TryGetProperty("error", out var errorObj))
                {
                    errorMessage = errorObj.TryGetProperty("message", out var msg)
                        ? msg.GetString()
                        : null;
                }

                string? skipReason = null;
                if (tc.TryGetProperty("skipReason", out var skip))
                {
                    skipReason = skip.GetString();
                }

                testCases.Add(new TestCase
                {
                    Name = name,
                    Suite = suite,
                    Status = status,
                    Duration = TimeSpan.FromSeconds(tcDuration),
                    ErrorMessage = errorMessage,
                    SkipReason = skipReason
                });
            }
        }

        return new TestRun
        {
            Label = label,
            Duration = TimeSpan.FromSeconds(duration),
            TestCases = testCases
        };
    }
}
