// TDD: RED — Tests written first. CsvParser does not exist yet, so these will fail to compile.

using CsvReportGenerator;

namespace CsvReportGenerator.Tests;

public class CsvParserTests
{
    private readonly string _testDataDir;

    public CsvParserTests()
    {
        // Locate the TestData directory relative to the test assembly
        _testDataDir = Path.Combine(AppContext.BaseDirectory, "TestData");
    }

    // --- Parsing tests ---

    [Fact]
    public void ParseLine_ValidLine_ReturnsEmployeeRecord()
    {
        var line = "Alice Johnson,Engineering,95000,2020-01-15,active";
        var record = CsvParser.ParseLine(line);

        Assert.Equal("Alice Johnson", record.Name);
        Assert.Equal("Engineering", record.Department);
        Assert.Equal(95000m, record.Salary);
        Assert.Equal(new DateTime(2020, 1, 15), record.HireDate);
        Assert.Equal("active", record.Status);
    }

    [Fact]
    public void ParseLine_InvalidSalary_ThrowsMeaningfulError()
    {
        var line = "Bob,Engineering,notanumber,2020-01-15,active";
        var ex = Assert.Throws<FormatException>(() => CsvParser.ParseLine(line));
        Assert.Contains("salary", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ParseLine_InvalidDate_ThrowsMeaningfulError()
    {
        var line = "Bob,Engineering,95000,not-a-date,active";
        var ex = Assert.Throws<FormatException>(() => CsvParser.ParseLine(line));
        Assert.Contains("hire_date", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ParseLine_WrongColumnCount_ThrowsMeaningfulError()
    {
        var line = "Bob,Engineering,95000";
        var ex = Assert.Throws<FormatException>(() => CsvParser.ParseLine(line));
        Assert.Contains("column", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ParseFile_ReadsAllRows()
    {
        var filePath = Path.Combine(_testDataDir, "employees.csv");
        var records = CsvParser.ParseFile(filePath);

        // The fixture has 10 data rows (excluding header)
        Assert.Equal(10, records.Count);
    }

    [Fact]
    public void ParseFile_NonExistentFile_ThrowsFileNotFoundException()
    {
        Assert.Throws<FileNotFoundException>(() => CsvParser.ParseFile("/nonexistent/path.csv"));
    }

    [Fact]
    public void ParseCsv_FromString_ReadsAllRows()
    {
        var csv = """
            name,department,salary,hire_date,status
            Alice,Engineering,95000,2020-01-15,active
            Bob,Sales,80000,2021-03-01,inactive
            """;

        var records = CsvParser.ParseCsv(csv);
        Assert.Equal(2, records.Count);
    }

    // --- Filtering tests ---

    [Fact]
    public void FilterActive_ReturnsOnlyActiveEmployees()
    {
        var csv = """
            name,department,salary,hire_date,status
            Alice,Engineering,95000,2020-01-15,active
            Bob,Sales,80000,2021-03-01,inactive
            Carol,Marketing,78000,2021-06-01,Active
            """;

        var records = CsvParser.ParseCsv(csv);
        var active = CsvParser.FilterActive(records);

        Assert.Equal(2, active.Count);
        Assert.All(active, r => Assert.True(r.IsActive));
    }

    [Fact]
    public void FilterActive_FromFixture_Returns8Active()
    {
        // The fixture has 8 active and 2 inactive employees
        var filePath = Path.Combine(_testDataDir, "employees.csv");
        var records = CsvParser.ParseFile(filePath);
        var active = CsvParser.FilterActive(records);

        Assert.Equal(8, active.Count);
    }
}
