// JUnitParser.cs - Parses JUnit XML format into our TestRun model.
// TDD Round 2 GREEN: Implements parsing to satisfy JUnitParserTests.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Xml.Linq;

/// <summary>Parses JUnit XML test result format into a <see cref="TestRun"/>.</summary>
public static class JUnitParser
{
    public static TestRun Parse(string xml, string label)
    {
        XDocument doc;
        try
        {
            doc = XDocument.Parse(xml);
        }
        catch (Exception ex)
        {
            throw new TestResultParseException(
                $"Failed to parse JUnit XML for '{label}': {ex.Message}", ex);
        }

        var root = doc.Root
            ?? throw new TestResultParseException(
                $"JUnit XML for '{label}' has no root element.");

        // Support both <testsuites> (wrapping multiple suites) and bare <testsuite>
        var suites = root.Name.LocalName == "testsuites"
            ? root.Elements("testsuite")
            : root.Name.LocalName == "testsuite"
                ? [root]
                : throw new TestResultParseException(
                    $"JUnit XML for '{label}': expected <testsuites> or <testsuite> root, got <{root.Name.LocalName}>.");

        var testCases = new List<TestCase>();

        foreach (var suite in suites)
        {
            var suiteName = suite.Attribute("name")?.Value ?? "UnknownSuite";

            foreach (var tc in suite.Elements("testcase"))
            {
                var name = tc.Attribute("name")?.Value ?? "UnknownTest";
                var className = tc.Attribute("classname")?.Value ?? suiteName;
                var duration = ParseSeconds(tc.Attribute("time")?.Value);

                // Determine status from child elements
                var failure = tc.Element("failure");
                var error = tc.Element("error");
                var skipped = tc.Element("skipped");

                TestStatus status;
                string? errorMessage = null;
                string? skipReason = null;

                if (failure != null)
                {
                    status = TestStatus.Failed;
                    errorMessage = failure.Attribute("message")?.Value ?? failure.Value;
                }
                else if (error != null)
                {
                    status = TestStatus.Failed;
                    errorMessage = error.Attribute("message")?.Value ?? error.Value;
                }
                else if (skipped != null)
                {
                    status = TestStatus.Skipped;
                    skipReason = skipped.Attribute("message")?.Value;
                }
                else
                {
                    status = TestStatus.Passed;
                }

                testCases.Add(new TestCase
                {
                    Name = name,
                    Suite = className,
                    Status = status,
                    Duration = duration,
                    ErrorMessage = errorMessage,
                    SkipReason = skipReason
                });
            }
        }

        // Total duration from root attribute, falling back to sum of suites
        var totalDuration = ParseSeconds(root.Attribute("time")?.Value);

        return new TestRun
        {
            Label = label,
            Duration = totalDuration,
            TestCases = testCases
        };
    }

    private static TimeSpan ParseSeconds(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return TimeSpan.Zero;
        if (double.TryParse(value, CultureInfo.InvariantCulture, out var seconds))
            return TimeSpan.FromSeconds(seconds);
        return TimeSpan.Zero;
    }
}
