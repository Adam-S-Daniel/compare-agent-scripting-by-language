// ═══════════════════════════════════════════════════════════════════════════════
// TDD Test Runner for CSV Report Generator
//
// Built using red/green/refactor TDD methodology:
//   1. Write a failing test (RED)
//   2. Write minimum code to make it pass (GREEN)
//   3. Refactor while keeping tests green
//
// .NET 10 file-based app — self-contained, no .csproj needed.
// ═══════════════════════════════════════════════════════════════════════════════

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

// ─── Minimal test framework ────────────────────────────────────────────────────

int passed = 0, failed = 0;
var failures = new List<string>();

void AssertTrue(bool condition, string label)
{
    if (condition) { passed++; Console.WriteLine($"  ✓ {label}"); }
    else { failed++; failures.Add(label); Console.WriteLine($"  ✗ {label}"); }
}

void AssertEqual<T>(T expected, T actual, string label)
{
    bool eq = EqualityComparer<T>.Default.Equals(expected, actual);
    if (!eq) label += $" (expected: {expected}, got: {actual})";
    AssertTrue(eq, label);
}

void AssertApprox(decimal expected, decimal actual, string label, decimal tol = 0.01m)
{
    bool eq = Math.Abs(expected - actual) <= tol;
    if (!eq) label += $" (expected: {expected}, got: {actual})";
    AssertTrue(eq, label);
}

void AssertThrows<TEx>(Action action, string label) where TEx : Exception
{
    bool threw = false;
    try { action(); } catch (TEx) { threw = true; }
    AssertTrue(threw, label);
}

Console.WriteLine("\n═══ CSV Report Generator — TDD Test Suite ═══\n");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST GROUP 1: CSV Parsing (RED → GREEN)
// ═══════════════════════════════════════════════════════════════════════════════
Console.WriteLine("── 1. CSV Parsing ──");

// Test: Parse a single CSV row into an Employee record
{
    var csv = "name,department,salary,hire_date,status\nAlice,Engineering,90000,2020-01-15,active\n";
    var employees = CsvParser.Parse(csv);
    AssertEqual(1, employees.Count, "Parse single row: count = 1");
    AssertEqual("Alice", employees[0].Name, "Parse single row: name");
    AssertEqual("Engineering", employees[0].Department, "Parse single row: department");
    AssertEqual(90000m, employees[0].Salary, "Parse single row: salary");
    AssertEqual(new DateTime(2020, 1, 15), employees[0].HireDate, "Parse single row: hire_date");
    AssertEqual("active", employees[0].Status, "Parse single row: status");
}

// Test: Parse multiple rows
{
    var csv = "name,department,salary,hire_date,status\n" +
              "A,Eng,100000,2020-01-01,active\n" +
              "B,Sales,80000,2021-06-15,inactive\n";
    var employees = CsvParser.Parse(csv);
    AssertEqual(2, employees.Count, "Parse multiple rows: count = 2");
    AssertEqual("A", employees[0].Name, "Parse multiple rows: first name");
    AssertEqual("B", employees[1].Name, "Parse multiple rows: second name");
}

// Test: Header-only CSV returns empty
{
    AssertEqual(0, CsvParser.Parse("name,department,salary,hire_date,status\n").Count,
        "Parse header-only: count = 0");
}

// Test: Empty string returns empty
{
    AssertEqual(0, CsvParser.Parse("").Count, "Parse empty string: count = 0");
}

// Test: Invalid salary throws FormatException
{
    AssertThrows<FormatException>(
        () => CsvParser.Parse("name,department,salary,hire_date,status\nA,Eng,notanum,2020-01-01,active\n"),
        "Parse invalid salary: throws FormatException");
}

// Test: Invalid date throws FormatException
{
    AssertThrows<FormatException>(
        () => CsvParser.Parse("name,department,salary,hire_date,status\nA,Eng,50000,bad-date,active\n"),
        "Parse invalid date: throws FormatException");
}

// Test: Too few columns throws FormatException
{
    AssertThrows<FormatException>(
        () => CsvParser.Parse("name,department,salary,hire_date,status\nA,Eng,50000\n"),
        "Parse too few columns: throws FormatException");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST GROUP 2: Employee Filtering (RED → GREEN)
// ═══════════════════════════════════════════════════════════════════════════════
Console.WriteLine("\n── 2. Employee Filtering ──");

// Test: Keeps only active employees
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\n" +
        "A,Eng,100000,2020-01-01,active\n" +
        "B,Sales,80000,2021-06-15,inactive\n" +
        "C,Eng,90000,2022-03-10,active\n");
    var active = EmployeeFilter.ActiveOnly(all);
    AssertEqual(2, active.Count, "ActiveOnly: keeps 2 active employees");
    AssertEqual("A", active[0].Name, "ActiveOnly: first = A");
    AssertEqual("C", active[1].Name, "ActiveOnly: second = C");
}

// Test: All inactive → empty result
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\n" +
        "A,Eng,100000,2020-01-01,inactive\n" +
        "B,Sales,80000,2021-06-15,inactive\n");
    AssertEqual(0, EmployeeFilter.ActiveOnly(all).Count, "ActiveOnly: 0 when all inactive");
}

// Test: Case-insensitive status matching (Active, ACTIVE)
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\n" +
        "A,Eng,100000,2020-01-01,Active\n" +
        "B,Sales,80000,2021-06-15,ACTIVE\n" +
        "C,HR,70000,2022-01-01,Inactive\n");
    AssertEqual(2, EmployeeFilter.ActiveOnly(all).Count, "ActiveOnly: case-insensitive matching");
}

// Test: All active → all returned
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\n" +
        "A,Eng,100000,2020-01-01,active\n" +
        "B,Sales,80000,2021-06-15,active\n");
    AssertEqual(2, EmployeeFilter.ActiveOnly(all).Count, "ActiveOnly: keeps all when all active");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST GROUP 3: Aggregation (RED → GREEN)
// ═══════════════════════════════════════════════════════════════════════════════
Console.WriteLine("\n── 3. Aggregation ──");

// Shared fixture for aggregation tests
var aggFixture = CsvParser.Parse(
    "name,department,salary,hire_date,status\n" +
    "A,Eng,100000,2020-01-01,active\n" +
    "B,Eng,80000,2021-06-15,active\n" +
    "C,Sales,60000,2022-03-10,active\n");

// Test: Average salary by department
{
    var avg = Aggregator.AverageSalaryByDepartment(aggFixture);
    AssertEqual(90000m, avg["Eng"], "AvgSalary: Eng = 90000");
    AssertEqual(60000m, avg["Sales"], "AvgSalary: Sales = 60000");
    AssertEqual(2, avg.Count, "AvgSalary: 2 departments");
}

// Test: Headcount by department
{
    var hc = Aggregator.HeadcountByDepartment(aggFixture);
    AssertEqual(2, hc["Eng"], "Headcount: Eng = 2");
    AssertEqual(1, hc["Sales"], "Headcount: Sales = 1");
}

// Test: Overall statistics
{
    var stats = Aggregator.OverallStats(aggFixture);
    AssertEqual(3, stats.TotalEmployees, "OverallStats: total = 3");
    AssertApprox(80000m, stats.AverageSalary, "OverallStats: avg ≈ 80000");
    AssertEqual(60000m, stats.MinSalary, "OverallStats: min = 60000");
    AssertEqual(100000m, stats.MaxSalary, "OverallStats: max = 100000");
    AssertEqual(240000m, stats.TotalPayroll, "OverallStats: payroll = 240000");
    AssertEqual(2, stats.DepartmentCount, "OverallStats: depts = 2");
}

// Test: OverallStats throws on empty collection
{
    AssertThrows<InvalidOperationException>(
        () => Aggregator.OverallStats(new List<Employee>()),
        "OverallStats: throws on empty list");
}

// Test: Single employee aggregation
{
    var single = new List<Employee> { new("Solo", "IT", 75000m, DateTime.Now, "active") };
    var stats = Aggregator.OverallStats(single);
    AssertEqual(1, stats.TotalEmployees, "OverallStats single: total = 1");
    AssertEqual(75000m, stats.AverageSalary, "OverallStats single: avg = salary");
    AssertEqual(75000m, stats.MinSalary, "OverallStats single: min = max");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST GROUP 4: Report Formatting (RED → GREEN)
// ═══════════════════════════════════════════════════════════════════════════════
Console.WriteLine("\n── 4. Report Formatting ──");

{
    var report = ReportFormatter.GenerateReport(aggFixture);
    AssertTrue(report.Contains("EMPLOYEE SUMMARY REPORT"), "Report: contains title");
    AssertTrue(report.Contains("Department Summary"), "Report: contains dept section");
    AssertTrue(report.Contains("Overall Statistics"), "Report: contains stats section");
    AssertTrue(report.Contains("Eng"), "Report: mentions Eng department");
    AssertTrue(report.Contains("Sales"), "Report: mentions Sales department");
    // Check that salary figures appear in the report (formatted with commas or raw)
    AssertTrue(report.Contains("90,000.00") || report.Contains("90000"), "Report: avg salary for Eng");
    AssertTrue(report.Contains("240,000.00") || report.Contains("240000"), "Report: total payroll");
    AssertTrue(report.Contains("3"), "Report: total employee count");
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST GROUP 5: File I/O & Pipeline Integration (RED → GREEN)
// ═══════════════════════════════════════════════════════════════════════════════
Console.WriteLine("\n── 5. File I/O & Pipeline ──");

string workDir = Directory.GetCurrentDirectory();

// Test: ParseFile reads sample CSV from disk
{
    string csvPath = Path.Combine(workDir, "test_data.csv");
    var employees = CsvParser.ParseFile(csvPath);
    AssertEqual(10, employees.Count, "ParseFile: reads 10 rows from test_data.csv");
}

// Test: ParseFile throws FileNotFoundException for missing file
{
    AssertThrows<FileNotFoundException>(
        () => CsvParser.ParseFile("/nonexistent/path/missing.csv"),
        "ParseFile: throws on missing file");
}

// Test: Full pipeline — CSV → filter → aggregate → report file
{
    string csvPath = Path.Combine(workDir, "test_data.csv");
    string outPath = Path.Combine(workDir, "test_pipeline_output.txt");

    ReportPipeline.Run(csvPath, outPath);

    AssertTrue(File.Exists(outPath), "Pipeline: output file created");
    string content = File.ReadAllText(outPath);
    AssertTrue(content.Contains("Engineering"), "Pipeline: report has Engineering");
    AssertTrue(content.Contains("Marketing"), "Pipeline: report has Marketing");
    AssertTrue(content.Contains("Sales"), "Pipeline: report has Sales");
    AssertTrue(content.Length > 200, $"Pipeline: report is substantial ({content.Length} chars)");
    // test_data.csv has 8 active employees (David Brown & Grace Lee are inactive)
    AssertTrue(content.Contains("8"), "Pipeline: shows 8 active employees");

    File.Delete(outPath); // cleanup
}

// Test: Pipeline with all-inactive data throws
{
    string tmpCsv = Path.Combine(workDir, "tmp_all_inactive.csv");
    File.WriteAllText(tmpCsv, "name,department,salary,hire_date,status\nX,Eng,50000,2020-01-01,inactive\n");
    AssertThrows<InvalidOperationException>(
        () => ReportPipeline.Run(tmpCsv, Path.Combine(workDir, "should_not_exist.txt")),
        "Pipeline: throws when no active employees");
    File.Delete(tmpCsv);
}

// ─── Summary ────────────────────────────────────────────────────────────────────
Console.WriteLine($"\n═══ Results: {passed} passed, {failed} failed ═══\n");
if (failures.Count > 0)
{
    Console.WriteLine("Failures:");
    foreach (var f in failures) Console.WriteLine($"  ✗ {f}");
    Console.WriteLine();
}
return failed > 0 ? 1 : 0;

// ═══════════════════════════════════════════════════════════════════════════════
// IMPLEMENTATION — types must follow top-level statements in C# file-based apps
// ═══════════════════════════════════════════════════════════════════════════════

// --- Data model ---

/// <summary>A single employee row from the CSV.</summary>
public record Employee(
    string Name,
    string Department,
    decimal Salary,
    DateTime HireDate,
    string Status
);

/// <summary>Aggregate stats across all active employees.</summary>
public record OverallStatistics(
    int TotalEmployees,
    decimal AverageSalary,
    decimal MinSalary,
    decimal MaxSalary,
    decimal TotalPayroll,
    int DepartmentCount
);

// --- CSV Parsing ---

/// <summary>Parses CSV text or files into Employee records.</summary>
public static class CsvParser
{
    /// <summary>Parse CSV from a string. First line must be the header row.</summary>
    public static List<Employee> Parse(string csvContent)
    {
        var employees = new List<Employee>();
        var lines = csvContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        if (lines.Length < 2) return employees;

        // Validate header
        var header = lines[0].Trim().ToLowerInvariant();
        if (!header.StartsWith("name,"))
            throw new FormatException($"Unexpected CSV header: {lines[0]}");

        for (int i = 1; i < lines.Length; i++)
        {
            var line = lines[i].Trim();
            if (string.IsNullOrEmpty(line)) continue;

            var parts = line.Split(',');
            if (parts.Length < 5)
                throw new FormatException($"Row {i} has {parts.Length} columns, expected 5: {line}");

            if (!decimal.TryParse(parts[2].Trim(), NumberStyles.Any, CultureInfo.InvariantCulture, out var salary))
                throw new FormatException($"Row {i}: invalid salary '{parts[2].Trim()}'");

            if (!DateTime.TryParse(parts[3].Trim(), CultureInfo.InvariantCulture, DateTimeStyles.None, out var hireDate))
                throw new FormatException($"Row {i}: invalid date '{parts[3].Trim()}'");

            employees.Add(new Employee(
                Name: parts[0].Trim(),
                Department: parts[1].Trim(),
                Salary: salary,
                HireDate: hireDate,
                Status: parts[4].Trim()
            ));
        }
        return employees;
    }

    /// <summary>Parse a CSV file from disk.</summary>
    public static List<Employee> ParseFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"CSV file not found: {filePath}", filePath);
        return Parse(File.ReadAllText(filePath));
    }
}

// --- Filtering ---

/// <summary>Filters employees by status.</summary>
public static class EmployeeFilter
{
    public static List<Employee> ActiveOnly(IEnumerable<Employee> employees) =>
        employees.Where(e => e.Status.Equals("active", StringComparison.OrdinalIgnoreCase)).ToList();
}

// --- Aggregation ---

/// <summary>Computes department-level and overall aggregate statistics.</summary>
public static class Aggregator
{
    public static Dictionary<string, decimal> AverageSalaryByDepartment(IEnumerable<Employee> employees) =>
        employees.GroupBy(e => e.Department)
                 .ToDictionary(g => g.Key, g => Math.Round(g.Average(e => e.Salary), 2));

    public static Dictionary<string, int> HeadcountByDepartment(IEnumerable<Employee> employees) =>
        employees.GroupBy(e => e.Department)
                 .ToDictionary(g => g.Key, g => g.Count());

    public static OverallStatistics OverallStats(IEnumerable<Employee> employees)
    {
        var list = employees.ToList();
        if (list.Count == 0)
            throw new InvalidOperationException("Cannot compute statistics on an empty collection.");
        return new OverallStatistics(
            TotalEmployees: list.Count,
            AverageSalary: Math.Round(list.Average(e => e.Salary), 2),
            MinSalary: list.Min(e => e.Salary),
            MaxSalary: list.Max(e => e.Salary),
            TotalPayroll: list.Sum(e => e.Salary),
            DepartmentCount: list.Select(e => e.Department).Distinct().Count()
        );
    }
}

// --- Report Formatting ---

/// <summary>Formats employee data into a human-readable text report.</summary>
public static class ReportFormatter
{
    public static string GenerateReport(IEnumerable<Employee> employees)
    {
        var list = employees.ToList();
        var sb = new StringBuilder();
        var sep = new string('=', 60);

        sb.AppendLine(sep);
        sb.AppendLine("           EMPLOYEE SUMMARY REPORT");
        sb.AppendLine($"           Generated: {DateTime.Now:yyyy-MM-dd HH:mm}");
        sb.AppendLine(sep);
        sb.AppendLine();

        // Department Summary
        var avgSalary = Aggregator.AverageSalaryByDepartment(list);
        var headcount = Aggregator.HeadcountByDepartment(list);

        sb.AppendLine("-- Department Summary ------------------------------------------");
        sb.AppendLine();
        sb.AppendLine($"  {"Department",-20} {"Headcount",10} {"Avg Salary",15}");
        sb.AppendLine($"  {new string('-', 20)} {new string('-', 10)} {new string('-', 15)}");

        foreach (var dept in headcount.Keys.OrderBy(k => k))
        {
            sb.AppendLine($"  {dept,-20} {headcount[dept],10} {avgSalary[dept],15:N2}");
        }
        sb.AppendLine();

        // Overall Statistics
        var stats = Aggregator.OverallStats(list);
        sb.AppendLine("-- Overall Statistics ------------------------------------------");
        sb.AppendLine();
        sb.AppendLine($"  Total Active Employees:  {stats.TotalEmployees}");
        sb.AppendLine($"  Number of Departments:   {stats.DepartmentCount}");
        sb.AppendLine($"  Average Salary:          {stats.AverageSalary:N2}");
        sb.AppendLine($"  Minimum Salary:          {stats.MinSalary:N2}");
        sb.AppendLine($"  Maximum Salary:          {stats.MaxSalary:N2}");
        sb.AppendLine($"  Total Payroll:           {stats.TotalPayroll:N2}");
        sb.AppendLine();
        sb.AppendLine(sep);

        return sb.ToString();
    }
}

// --- Pipeline ---

/// <summary>Orchestrates: read CSV → filter active → aggregate → write report.</summary>
public static class ReportPipeline
{
    public static void Run(string inputCsvPath, string outputReportPath)
    {
        var allEmployees = CsvParser.ParseFile(inputCsvPath);
        var active = EmployeeFilter.ActiveOnly(allEmployees);

        if (active.Count == 0)
            throw new InvalidOperationException("No active employees found in the data.");

        var report = ReportFormatter.GenerateReport(active);
        File.WriteAllText(outputReportPath, report);
    }
}
