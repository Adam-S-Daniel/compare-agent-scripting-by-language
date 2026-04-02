// TDD tests for the CSV Report Generator.
// We follow red/green/refactor: each test is written to fail first,
// then we implement just enough code to make it pass.

using Xunit;

namespace CsvReportTests;

#region Data Models

/// <summary>Represents a single employee record from the CSV.</summary>
public record Employee(
    string Name,
    string Department,
    decimal Salary,
    DateTime HireDate,
    string Status
);

/// <summary>Per-department aggregate statistics.</summary>
public record DepartmentStats(
    string Department,
    int Headcount,
    decimal AverageSalary,
    decimal MinSalary,
    decimal MaxSalary,
    decimal TotalSalary
);

/// <summary>Overall report summary.</summary>
public record ReportSummary(
    List<DepartmentStats> DepartmentStatsList,
    int TotalActiveEmployees,
    decimal OverallAverageSalary,
    decimal OverallMinSalary,
    decimal OverallMaxSalary
);

#endregion

#region CSV Parser

/// <summary>Parses CSV text into Employee records with error handling.</summary>
public static class CsvParser
{
    /// <summary>Parse CSV content string into a list of Employee records.</summary>
    public static List<Employee> Parse(string csvContent)
    {
        if (string.IsNullOrWhiteSpace(csvContent))
            throw new ArgumentException("CSV content is empty or null.");

        var lines = csvContent
            .Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(l => l.Trim())
            .Where(l => !string.IsNullOrEmpty(l))
            .ToList();

        if (lines.Count < 2)
            throw new ArgumentException("CSV must contain a header row and at least one data row.");

        // Validate header
        var header = lines[0].ToLowerInvariant();
        var expectedFields = new[] { "name", "department", "salary", "hire_date", "status" };
        var headerFields = header.Split(',').Select(f => f.Trim()).ToArray();

        if (headerFields.Length != 5 || !expectedFields.SequenceEqual(headerFields))
            throw new ArgumentException(
                $"Invalid CSV header. Expected: {string.Join(",", expectedFields)}. Got: {header}");

        var employees = new List<Employee>();
        for (int i = 1; i < lines.Count; i++)
        {
            var fields = lines[i].Split(',').Select(f => f.Trim()).ToArray();
            if (fields.Length != 5)
                throw new FormatException(
                    $"Line {i + 1}: Expected 5 fields but got {fields.Length}. Content: '{lines[i]}'");

            if (!decimal.TryParse(fields[2], out var salary))
                throw new FormatException(
                    $"Line {i + 1}: Invalid salary value '{fields[2]}'.");

            if (!DateTime.TryParse(fields[3], out var hireDate))
                throw new FormatException(
                    $"Line {i + 1}: Invalid hire_date value '{fields[3]}'.");

            employees.Add(new Employee(fields[0], fields[1], salary, hireDate, fields[4]));
        }

        return employees;
    }
}

#endregion

#region Employee Filter

/// <summary>Filters employees by status.</summary>
public static class EmployeeFilter
{
    /// <summary>Return only employees whose Status equals "Active" (case-insensitive).</summary>
    public static List<Employee> ActiveOnly(List<Employee> employees)
    {
        return employees
            .Where(e => e.Status.Equals("Active", StringComparison.OrdinalIgnoreCase))
            .ToList();
    }
}

#endregion

#region Aggregator

/// <summary>Computes aggregate statistics from a list of active employees.</summary>
public static class Aggregator
{
    /// <summary>Compute a full report summary from active employees.</summary>
    public static ReportSummary Summarize(List<Employee> activeEmployees)
    {
        if (activeEmployees == null || activeEmployees.Count == 0)
            throw new ArgumentException("No active employees to summarize.");

        var deptStats = activeEmployees
            .GroupBy(e => e.Department)
            .OrderBy(g => g.Key)
            .Select(g => new DepartmentStats(
                Department: g.Key,
                Headcount: g.Count(),
                AverageSalary: Math.Round(g.Average(e => e.Salary), 2),
                MinSalary: g.Min(e => e.Salary),
                MaxSalary: g.Max(e => e.Salary),
                TotalSalary: g.Sum(e => e.Salary)
            ))
            .ToList();

        return new ReportSummary(
            DepartmentStatsList: deptStats,
            TotalActiveEmployees: activeEmployees.Count,
            OverallAverageSalary: Math.Round(activeEmployees.Average(e => e.Salary), 2),
            OverallMinSalary: activeEmployees.Min(e => e.Salary),
            OverallMaxSalary: activeEmployees.Max(e => e.Salary)
        );
    }
}

#endregion

#region Report Formatter

/// <summary>Formats a ReportSummary into a human-readable text report.</summary>
public static class ReportFormatter
{
    public static string Format(ReportSummary summary)
    {
        var sb = new System.Text.StringBuilder();

        sb.AppendLine("========================================");
        sb.AppendLine("       EMPLOYEE SUMMARY REPORT          ");
        sb.AppendLine("========================================");
        sb.AppendLine();

        // Overall statistics
        sb.AppendLine("OVERALL STATISTICS");
        sb.AppendLine("------------------");
        sb.AppendLine($"  Total Active Employees : {summary.TotalActiveEmployees}");
        sb.AppendLine($"  Average Salary         : {summary.OverallAverageSalary:C}");
        sb.AppendLine($"  Minimum Salary         : {summary.OverallMinSalary:C}");
        sb.AppendLine($"  Maximum Salary         : {summary.OverallMaxSalary:C}");
        sb.AppendLine();

        // Department breakdown
        sb.AppendLine("DEPARTMENT BREAKDOWN");
        sb.AppendLine("--------------------");
        sb.AppendLine($"  {"Department",-20} {"Count",6} {"Avg Salary",14} {"Min",14} {"Max",14}");
        sb.AppendLine($"  {new string('-', 20)} {new string('-', 6)} {new string('-', 14)} {new string('-', 14)} {new string('-', 14)}");

        foreach (var dept in summary.DepartmentStatsList)
        {
            sb.AppendLine($"  {dept.Department,-20} {dept.Headcount,6} {dept.AverageSalary,14:C} {dept.MinSalary,14:C} {dept.MaxSalary,14:C}");
        }

        sb.AppendLine();
        sb.AppendLine("========================================");
        sb.AppendLine("            END OF REPORT               ");
        sb.AppendLine("========================================");

        return sb.ToString();
    }
}

#endregion

#region Test Fixtures

/// <summary>Shared test data for all tests.</summary>
public static class TestFixtures
{
    public const string SampleCsv = @"name,department,salary,hire_date,status
Alice Johnson,Engineering,95000,2020-03-15,Active
Bob Smith,Marketing,72000,2019-07-01,Active
Carol White,Engineering,105000,2018-01-10,Active
David Brown,HR,68000,2021-06-20,Inactive
Eve Davis,Marketing,78000,2020-11-05,Active
Frank Miller,HR,71000,2017-09-12,Active
Grace Lee,Engineering,88000,2022-02-28,Active
Hank Wilson,Sales,82000,2019-04-18,Inactive
Ivy Chen,Sales,91000,2021-01-30,Active
Jack Taylor,HR,65000,2023-03-01,Active";

    public const string CsvHeaderOnly = @"name,department,salary,hire_date,status";

    public const string CsvBadHeader = @"name,dept,pay,date,stat
Alice,Eng,90000,2020-01-01,Active";

    public const string CsvBadSalary = @"name,department,salary,hire_date,status
Alice,Engineering,not_a_number,2020-01-01,Active";

    public const string CsvBadDate = @"name,department,salary,hire_date,status
Alice,Engineering,90000,not-a-date,Active";

    public const string CsvWrongFieldCount = @"name,department,salary,hire_date,status
Alice,Engineering,90000";
}

#endregion

// ============================================================
// TESTS — organized by TDD cycle
// ============================================================

#region Cycle 1: CSV Parsing Tests

public class CsvParserTests
{
    [Fact]
    public void Parse_ValidCsv_ReturnsCorrectNumberOfRecords()
    {
        // The sample CSV has 10 data rows
        var result = CsvParser.Parse(TestFixtures.SampleCsv);
        Assert.Equal(10, result.Count);
    }

    [Fact]
    public void Parse_ValidCsv_ParsesFirstRecordCorrectly()
    {
        var result = CsvParser.Parse(TestFixtures.SampleCsv);
        var first = result[0];

        Assert.Equal("Alice Johnson", first.Name);
        Assert.Equal("Engineering", first.Department);
        Assert.Equal(95000m, first.Salary);
        Assert.Equal(new DateTime(2020, 3, 15), first.HireDate);
        Assert.Equal("Active", first.Status);
    }

    [Fact]
    public void Parse_EmptyContent_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CsvParser.Parse(""));
    }

    [Fact]
    public void Parse_NullContent_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CsvParser.Parse(null!));
    }

    [Fact]
    public void Parse_HeaderOnly_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CsvParser.Parse(TestFixtures.CsvHeaderOnly));
    }

    [Fact]
    public void Parse_BadHeader_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => CsvParser.Parse(TestFixtures.CsvBadHeader));
    }

    [Fact]
    public void Parse_BadSalary_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => CsvParser.Parse(TestFixtures.CsvBadSalary));
    }

    [Fact]
    public void Parse_BadDate_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => CsvParser.Parse(TestFixtures.CsvBadDate));
    }

    [Fact]
    public void Parse_WrongFieldCount_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => CsvParser.Parse(TestFixtures.CsvWrongFieldCount));
    }
}

#endregion

#region Cycle 2: Filtering Tests

public class EmployeeFilterTests
{
    [Fact]
    public void ActiveOnly_FiltersOutInactiveEmployees()
    {
        var employees = CsvParser.Parse(TestFixtures.SampleCsv);
        var active = EmployeeFilter.ActiveOnly(employees);

        // 10 total, 2 inactive (David Brown, Hank Wilson) → 8 active
        Assert.Equal(8, active.Count);
        Assert.All(active, e => Assert.Equal("Active", e.Status));
    }

    [Fact]
    public void ActiveOnly_CaseInsensitive()
    {
        var employees = new List<Employee>
        {
            new("A", "Dept", 50000, DateTime.Now, "active"),
            new("B", "Dept", 60000, DateTime.Now, "ACTIVE"),
            new("C", "Dept", 70000, DateTime.Now, "Inactive"),
        };

        var active = EmployeeFilter.ActiveOnly(employees);
        Assert.Equal(2, active.Count);
    }

    [Fact]
    public void ActiveOnly_EmptyList_ReturnsEmpty()
    {
        var active = EmployeeFilter.ActiveOnly(new List<Employee>());
        Assert.Empty(active);
    }
}

#endregion

#region Cycle 3: Aggregation Tests

public class AggregatorTests
{
    private List<Employee> GetActiveEmployees()
    {
        var all = CsvParser.Parse(TestFixtures.SampleCsv);
        return EmployeeFilter.ActiveOnly(all);
    }

    [Fact]
    public void Summarize_CorrectTotalActiveCount()
    {
        var summary = Aggregator.Summarize(GetActiveEmployees());
        Assert.Equal(8, summary.TotalActiveEmployees);
    }

    [Fact]
    public void Summarize_CorrectDepartmentCount()
    {
        var summary = Aggregator.Summarize(GetActiveEmployees());
        // Active employees span 4 departments: Engineering(3), HR(2), Marketing(2), Sales(1)
        Assert.Equal(4, summary.DepartmentStatsList.Count);
    }

    [Fact]
    public void Summarize_EngineeringDeptStats()
    {
        var summary = Aggregator.Summarize(GetActiveEmployees());
        var eng = summary.DepartmentStatsList.First(d => d.Department == "Engineering");

        Assert.Equal(3, eng.Headcount);
        Assert.Equal(96000m, eng.AverageSalary); // (95000+105000+88000)/3 = 96000
        Assert.Equal(88000m, eng.MinSalary);
        Assert.Equal(105000m, eng.MaxSalary);
        Assert.Equal(288000m, eng.TotalSalary);
    }

    [Fact]
    public void Summarize_OverallAverageSalary()
    {
        var summary = Aggregator.Summarize(GetActiveEmployees());
        // Active salaries: 95000+72000+105000+78000+71000+88000+91000+65000 = 665000
        // 665000/8 = 83125
        Assert.Equal(83125m, summary.OverallAverageSalary);
    }

    [Fact]
    public void Summarize_OverallMinMax()
    {
        var summary = Aggregator.Summarize(GetActiveEmployees());
        Assert.Equal(65000m, summary.OverallMinSalary);
        Assert.Equal(105000m, summary.OverallMaxSalary);
    }

    [Fact]
    public void Summarize_EmptyList_ThrowsArgumentException()
    {
        Assert.Throws<ArgumentException>(() => Aggregator.Summarize(new List<Employee>()));
    }

    [Fact]
    public void Summarize_DepartmentsSortedAlphabetically()
    {
        var summary = Aggregator.Summarize(GetActiveEmployees());
        var names = summary.DepartmentStatsList.Select(d => d.Department).ToList();
        Assert.Equal(new[] { "Engineering", "HR", "Marketing", "Sales" }, names);
    }
}

#endregion

#region Cycle 4: Report Formatting Tests

public class ReportFormatterTests
{
    [Fact]
    public void Format_ContainsReportTitle()
    {
        var summary = Aggregator.Summarize(EmployeeFilter.ActiveOnly(CsvParser.Parse(TestFixtures.SampleCsv)));
        var report = ReportFormatter.Format(summary);

        Assert.Contains("EMPLOYEE SUMMARY REPORT", report);
    }

    [Fact]
    public void Format_ContainsOverallStatistics()
    {
        var summary = Aggregator.Summarize(EmployeeFilter.ActiveOnly(CsvParser.Parse(TestFixtures.SampleCsv)));
        var report = ReportFormatter.Format(summary);

        Assert.Contains("OVERALL STATISTICS", report);
        Assert.Contains("Total Active Employees", report);
        Assert.Contains("8", report);
    }

    [Fact]
    public void Format_ContainsDepartmentBreakdown()
    {
        var summary = Aggregator.Summarize(EmployeeFilter.ActiveOnly(CsvParser.Parse(TestFixtures.SampleCsv)));
        var report = ReportFormatter.Format(summary);

        Assert.Contains("DEPARTMENT BREAKDOWN", report);
        Assert.Contains("Engineering", report);
        Assert.Contains("Marketing", report);
        Assert.Contains("HR", report);
        Assert.Contains("Sales", report);
    }

    [Fact]
    public void Format_ContainsEndMarker()
    {
        var summary = Aggregator.Summarize(EmployeeFilter.ActiveOnly(CsvParser.Parse(TestFixtures.SampleCsv)));
        var report = ReportFormatter.Format(summary);

        Assert.Contains("END OF REPORT", report);
    }
}

#endregion
