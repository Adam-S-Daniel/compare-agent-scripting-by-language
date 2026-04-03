// TDD Step 1: Tests for CSV parsing.
// These tests FAIL until we implement Employee + CsvParser in EmployeeReport.cs.

using Xunit;

namespace EmployeeReport.Tests;

public class CsvParserTests
{
    // RED: Parse a single CSV data row into an Employee record
    [Fact]
    public void ParseRow_ValidLine_ReturnsEmployee()
    {
        var line = "Alice Smith,Engineering,95000.00,2020-03-15,Active";
        var employee = CsvParser.ParseRow(line, lineNumber: 2);

        Assert.Equal("Alice Smith", employee.Name);
        Assert.Equal("Engineering", employee.Department);
        Assert.Equal(95000.00m, employee.Salary);
        Assert.Equal(new DateOnly(2020, 3, 15), employee.HireDate);
        Assert.Equal("Active", employee.Status);
    }

    [Fact]
    public void ParseRow_InactiveEmployee_ParsesCorrectly()
    {
        var line = "Bob Jones,Marketing,72000.50,2018-07-01,Inactive";
        var employee = CsvParser.ParseRow(line, lineNumber: 3);

        Assert.Equal("Bob Jones", employee.Name);
        Assert.Equal("Inactive", employee.Status);
    }

    [Fact]
    public void ParseRow_InvalidSalary_ThrowsMeaningfulException()
    {
        var line = "Charlie,HR,not-a-number,2021-01-01,Active";
        var ex = Assert.Throws<CsvParseException>(() => CsvParser.ParseRow(line, lineNumber: 5));
        Assert.Contains("line 5", ex.Message);
        Assert.Contains("salary", ex.Message.ToLower());
    }

    [Fact]
    public void ParseRow_TooFewColumns_ThrowsMeaningfulException()
    {
        var line = "Alice,Engineering,95000";
        var ex = Assert.Throws<CsvParseException>(() => CsvParser.ParseRow(line, lineNumber: 2));
        Assert.Contains("line 2", ex.Message);
        Assert.Contains("5 columns", ex.Message);
    }

    [Fact]
    public void ParseCsv_ValidFile_ReturnsAllEmployees()
    {
        // Use the fixture CSV file
        var csvPath = Path.Combine(
            Path.GetDirectoryName(typeof(CsvParserTests).Assembly.Location)!,
            "Fixtures", "employees_sample.csv");

        var employees = CsvParser.ParseFile(csvPath);

        // Fixture has 10 employees (see employees_sample.csv)
        Assert.Equal(10, employees.Count);
    }

    [Fact]
    public void ParseCsv_SkipsHeaderRow()
    {
        var csvPath = Path.Combine(
            Path.GetDirectoryName(typeof(CsvParserTests).Assembly.Location)!,
            "Fixtures", "employees_sample.csv");

        var employees = CsvParser.ParseFile(csvPath);

        // No employee should be named "name" (header value)
        Assert.DoesNotContain(employees, e => e.Name.Equals("name", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void ParseCsv_FileNotFound_ThrowsMeaningfulException()
    {
        var ex = Assert.Throws<FileNotFoundException>(
            () => CsvParser.ParseFile("/nonexistent/path/employees.csv"));
        Assert.Contains("employees.csv", ex.Message);
    }
}
