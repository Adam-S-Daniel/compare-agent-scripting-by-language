using System.Xml.Linq;
using TestAggregator.Models;

namespace TestAggregator.Parsers;

/// <summary>
/// Parses JUnit XML test result files.
/// Handles both &lt;testsuite&gt; and &lt;testsuites&gt; root elements.
/// Uses System.Xml.Linq (in-box, no NuGet required).
/// </summary>
public class JUnitXmlParser : ITestResultParser
{
    public bool CanParse(string filePath) =>
        Path.GetExtension(filePath).Equals(".xml", StringComparison.OrdinalIgnoreCase);

    public TestRun Parse(string filePath)
    {
        var doc = XDocument.Load(filePath);
        var root = doc.Root ?? throw new InvalidDataException($"Empty XML document: {filePath}");

        // Support both <testsuites> wrapper and bare <testsuite>
        IEnumerable<XElement> suiteElements = root.Name.LocalName == "testsuites"
            ? root.Elements("testsuite")
            : new[] { root };  // Single suite — wrap in a one-element array

        var suites = suiteElements
            .Select(el => ParseSuite(el, filePath))
            .ToList();

        return new TestRun(filePath, "junit-xml", suites);
    }

    private static TestSuite ParseSuite(XElement el, string sourceFile)
    {
        var suiteName = el.Attribute("name")?.Value ?? "Unknown";

        var cases = el.Elements("testcase")
            .Select(tc => ParseTestCase(tc, suiteName))
            .ToList();

        return new TestSuite(suiteName, cases, sourceFile);
    }

    private static TestCase ParseTestCase(XElement el, string suiteName)
    {
        var name = el.Attribute("name")?.Value ?? "Unknown";
        var className = el.Attribute("classname")?.Value ?? suiteName;
        var duration = double.TryParse(
            el.Attribute("time")?.Value,
            System.Globalization.NumberStyles.Any,
            System.Globalization.CultureInfo.InvariantCulture,
            out var d) ? d : 0.0;

        // Determine status by checking child elements
        if (el.Element("failure") is XElement failure)
        {
            return new TestCase(
                Name: name,
                ClassName: className,
                SuiteName: suiteName,
                Status: TestStatus.Failed,
                DurationSeconds: duration,
                ErrorMessage: failure.Attribute("message")?.Value ?? failure.Value.Trim(),
                ErrorType: failure.Attribute("type")?.Value
            );
        }

        if (el.Element("error") is XElement error)
        {
            return new TestCase(
                Name: name,
                ClassName: className,
                SuiteName: suiteName,
                Status: TestStatus.Error,
                DurationSeconds: duration,
                ErrorMessage: error.Attribute("message")?.Value ?? error.Value.Trim(),
                ErrorType: error.Attribute("type")?.Value
            );
        }

        if (el.Element("skipped") is not null)
        {
            return new TestCase(name, className, suiteName, TestStatus.Skipped, duration);
        }

        return new TestCase(name, className, suiteName, TestStatus.Passed, duration);
    }
}
