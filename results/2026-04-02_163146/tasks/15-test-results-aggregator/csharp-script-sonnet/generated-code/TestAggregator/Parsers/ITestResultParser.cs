using TestAggregator.Models;

namespace TestAggregator.Parsers;

/// <summary>
/// Common interface for all test result file parsers.
/// The parser registry iterates implementors calling CanParse() to select the right one.
/// </summary>
public interface ITestResultParser
{
    /// <summary>Returns true if this parser can handle the given file.</summary>
    bool CanParse(string filePath);

    /// <summary>Parses the file and returns a TestRun with all suites and cases.</summary>
    TestRun Parse(string filePath);
}
