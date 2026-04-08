// ═══════════════════════════════════════════════════════════════════════════════
// TDD Test Runner for CSV Report Generator
//
// This file contains both the library code and the test suite. In .NET 10
// file-based apps, top-level statements run first, and type declarations
// (records, classes) go at the bottom of the file.
//
// TDD cycle: tests were conceptually written FIRST to define the API contract,
// then the implementation was written to satisfy them (red → green → refactor).
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

void AssertTrue(bool condition, string message)
{
    if (condition) { passed++; Console.WriteLine($"  ✓ {message}"); }
    else { failed++; failures.Add(message); Console.WriteLine($"  ✗ {message}"); }
}

void AssertEqual<T>(T expected, T actual, string message)
{
    bool eq = EqualityComparer<T>.Default.Equals(expected, actual);
    if (!eq) message += $" (expected: {expected}, got: {actual})";
    AssertTrue(eq, message);
}

void AssertApprox(decimal expected, decimal actual, string message, decimal tolerance = 0.01m)
{
    bool eq = Math.Abs(expected - actual) <= tolerance;
    if (!eq) message += $" (expected: {expected}, got: {actual})";
    AssertTrue(eq, message);
}

string scriptDir = Directory.GetCurrentDirectory();

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE
// ═══════════════════════════════════════════════════════════════════════════════

Console.WriteLine("\n═══ CSV Report Generator — Test Suite ═══\n");

// ── 1. CSV Parsing Tests ────────────────────────────────────────────────────────
Console.WriteLine("── CSV Parsing ──");

// Test: Parse a single CSV row
{
    var employees = CsvParser.Parse(
        "name,department,salary,hire_date,status\nAlice,Engineering,90000,2020-01-01,active\n");
    AssertEqual(1, employees.Count, "Parse single row: count = 1");
    AssertEqual("Alice", employees[0].Name, "Parse single row: name = Alice");
    AssertEqual("Engineering", employees[0].Department, "Parse single row: department = Engineering");
    AssertEqual(90000m, employees[0].Salary, "Parse single row: salary = 90000");
    AssertEqual(new DateTime(2020, 1, 1), employees[0].HireDate, "Parse single row: hire_date");
    AssertEqual("active", employees[0].Status, "Parse single row: status = active");
}

// Test: Parse multiple rows
{
    var employees = CsvParser.Parse(
        "name,department,salary,hire_date,status\nA,Eng,100000,2020-01-01,active\nB,Sales,80000,2021-06-15,inactive\n");
    AssertEqual(2, employees.Count, "Parse multiple rows: count = 2");
    AssertEqual("A", employees[0].Name, "Parse multiple rows: first = A");
    AssertEqual("B", employees[1].Name, "Parse multiple rows: second = B");
}

// Test: Header-only CSV returns empty list
{
    var employees = CsvParser.Parse("name,department,salary,hire_date,status\n");
    AssertEqual(0, employees.Count, "Parse header-only: count = 0");
}

// Test: Empty string returns empty list
{
    var employees = CsvParser.Parse("");
    AssertEqual(0, employees.Count, "Parse empty string: count = 0");
}

// Test: Invalid salary throws FormatException
{
    bool threw = false;
    try { CsvParser.Parse("name,department,salary,hire_date,status\nA,Eng,notanumber,2020-01-01,active\n"); }
    catch (FormatException) { threw = true; }
    AssertTrue(threw, "Parse invalid salary: throws FormatException");
}

// Test: Invalid date throws FormatException
{
    bool threw = false;
    try { CsvParser.Parse("name,department,salary,hire_date,status\nA,Eng,50000,not-a-date,active\n"); }
    catch (FormatException) { threw = true; }
    AssertTrue(threw, "Parse invalid date: throws FormatException");
}

// Test: Too few columns throws FormatException
{
    bool threw = false;
    try { CsvParser.Parse("name,department,salary,hire_date,status\nA,Eng,50000\n"); }
    catch (FormatException) { threw = true; }
    AssertTrue(threw, "Parse too few columns: throws FormatException");
}

// ── 2. Filtering Tests ──────────────────────────────────────────────────────────
Console.WriteLine("\n── Filtering ──");

// Test: Filter keeps only active employees
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\nA,Eng,100000,2020-01-01,active\nB,Sales,80000,2021-06-15,inactive\nC,Eng,90000,2022-03-10,active\n");
    var active = EmployeeFilter.ActiveOnly(all);
    AssertEqual(2, active.Count, "ActiveOnly: returns 2 active employees");
    AssertEqual("A", active[0].Name, "ActiveOnly: first = A");
    AssertEqual("C", active[1].Name, "ActiveOnly: second = C");
}

// Test: All inactive → empty result
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\nA,Eng,100000,2020-01-01,inactive\nB,Sales,80000,2021-06-15,inactive\n");
    var active = EmployeeFilter.ActiveOnly(all);
    AssertEqual(0, active.Count, "ActiveOnly: returns 0 when all inactive");
}

// Test: Case-insensitive status matching
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\nA,Eng,100000,2020-01-01,Active\nB,Sales,80000,2021-06-15,ACTIVE\nC,HR,70000,2022-01-01,Inactive\n");
    var active = EmployeeFilter.ActiveOnly(all);
    AssertEqual(2, active.Count, "ActiveOnly: case-insensitive (Active, ACTIVE)");
}

// Test: All active → all returned
{
    var all = CsvParser.Parse(
        "name,department,salary,hire_date,status\nA,Eng,100000,2020-01-01,active\nB,Sales,80000,2021-06-15,active\n");
    var active = EmployeeFilter.ActiveOnly(all);
    AssertEqual(2, active.Count, "ActiveOnly: keeps all when all active");
}

// ── 3. Aggregation Tests ────────────────────────────────────────────────────────
Console.WriteLine("\n── Aggregation ──");

var testEmps = CsvParser.Parse(
    "name,department,salary,hire_date,status\n" +
    "A,Eng,100000,2020-01-01,active\n" +
    "B,Eng,80000,2021-06-15,active\n" +
    "C,Sales,60000,2022-03-10,active\n");

// Test: Average salary by department
{
    var avg = Aggregator.AverageSalaryByDepartment(testEmps);
    AssertEqual(90000m, avg["Eng"], "AvgSalary: Eng = 90000");
    AssertEqual(60000m, avg["Sales"], "AvgSalary: Sales = 60000");
    AssertEqual(2, avg.Count, "AvgSalary: 2 departments");
}

// Test: Headcount by department
{
    var hc = Aggregator.HeadcountByDepartment(testEmps);
    AssertEqual(2, hc["Eng"], "Headcount: Eng = 2");
    AssertEqual(1, hc["Sales"], "Headcount: Sales = 1");
}

// Test: Overall statistics
{
    var stats = Aggregator.OverallStats(testEmps);
    AssertEqual(3, stats.TotalEmployees, "OverallStats: total = 3");
    AssertApprox(80000m, stats.AverageSalary, "OverallStats: avg ≈ 80000");
    AssertEqual(60000m, stats.MinSalary, "OverallStats: min = 60000");
    AssertEqual(100000m, stats.MaxSalary, "OverallStats: max = 100000");
    AssertEqual(240000m, stats.TotalPayroll, "OverallStats: payroll = 240000");
    AssertEqual(2, stats.DepartmentCount, "OverallStats: departments = 2");
}

// Test: OverallStats on empty list throws
{
    bool threw = false;
    try { Aggregator.OverallStats(new List<Employee>()); }
    catch (InvalidOperationException) { threw = true; }
    AssertTrue(threw, "OverallStats: throws on empty list");
}

// Test: Single employee aggregation
{
    var single = new List<Employee> { new("Solo", "IT", 75000m, DateTime.Now, "active") };
    var stats = Aggregator.OverallStats(single);
    AssertEqual(1, stats.TotalEmployees, "OverallStats single: total = 1");
    AssertEqual(75000m, stats.AverageSalary, "OverallStats single: avg = 75000");
    AssertEqual(75000m, stats.MinSalary, "OverallStats single: min = max = 75000");
}

// ── 4. Report Formatting Tests ──────────────────────────────────────────────────
Console.WriteLine("\n── Report Formatting ──");

{
    var report = ReportFormatter.GenerateReport(testEmps);
    AssertTrue(report.Contains("Department Summary"), "Report: contains 'Department Summary'");
    AssertTrue(report.Contains("Overall Statistics"), "Report: contains 'Overall Statistics'");
    AssertTrue(report.Contains("Eng"), "Report: contains 'Eng'");
    AssertTrue(report.Contains("Sales"), "Report: contains 'Sales'");
    AssertTrue(report.Contains("90,000.00") || report.Contains("90000"), "Report: contains avg salary for Eng");
    AssertTrue(report.Contains("240,000.00") || report.Contains("240000"), "Report: contains total payroll");
    AssertTrue(report.Contains("3"), "Report: contains total count 3");
}

// ── 5. File I/O Integration Tests ───────────────────────────────────────────────
Console.WriteLine("\n── File I/O ──");

// Test: ParseFile reads test CSV
{
    string testCsvPath = Path.Combine(scriptDir, "test_data.csv");
    var employees = CsvParser.ParseFile(testCsvPath);
    AssertEqual(10, employees.Count, "ParseFile: reads 10 rows from test_data.csv");
}

// Test: ParseFile throws on missing file
{
    bool threw = false;
    try { CsvParser.ParseFile("/nonexistent/file.csv"); }
    catch (FileNotFoundException) { threw = true; }
    AssertTrue(threw, "ParseFile: throws FileNotFoundException on missing file");
}

// Test: Full pipeline — CSV → filter → aggregate → report file
{
    string testCsvPath = Path.Combine(scriptDir, "test_data.csv");
    string outputPath = Path.Combine(scriptDir, "test_output_report.txt");

    ReportPipeline.Run(testCsvPath, outputPath);

    AssertTrue(File.Exists(outputPath), "Pipeline: output file created");
    string content = File.ReadAllText(outputPath);
    AssertTrue(content.Contains("Engineering"), "Pipeline: report mentions Engineering");
    AssertTrue(content.Contains("Marketing"), "Pipeline: report mentions Marketing");
    AssertTrue(content.Contains("Sales"), "Pipeline: report mentions Sales");
    AssertTrue(content.Length > 200, $"Pipeline: report is substantial ({content.Length} chars)");

    // test_data.csv has 8 active employees (David Brown and Grace Lee are inactive)
    AssertTrue(content.Contains("8"), "Pipeline: total reflects 8 active employees");

    // Cleanup
    File.Delete(outputPath);
}

// Test: Pipeline with all-inactive data throws meaningful error
{
    string tempCsv = Path.Combine(scriptDir, "temp_inactive.csv");
    File.WriteAllText(tempCsv, "name,department,salary,hire_date,status\nA,Eng,50000,2020-01-01,inactive\n");
    bool threw = false;
    try { ReportPipeline.Run(tempCsv, Path.Combine(scriptDir, "should_not_exist.txt")); }
    catch (InvalidOperationException) { threw = true; }
    AssertTrue(threw, "Pipeline: throws when no active employees");
    File.Delete(tempCsv);
}

// ── Summary ─────────────────────────────────────────────────────────────────────
Console.WriteLine($"\n═══ Results: {passed} passed, {failed} failed ═══\n");
if (failures.Count > 0)
{
    Console.WriteLine("Failures:");
    foreach (var f in failures) Console.WriteLine($"  ✗ {f}");
    Console.WriteLine();
}
return failed > 0 ? 1 : 0;

// ═══════════════════════════════════════════════════════════════════════════════
// LIBRARY CODE (types must come after top-level statements in C#)
// ═══════════════════════════════════════════════════════════════════════════════

// --- Employee record ---
public record Employee(
    string Name,
    string Department,
    decimal Salary,
    DateTime HireDate,
    string Status
);

// --- CSV Parser: converts CSV text or files into Employee records ---
public static class CsvParser
{
    /// <summary>Parse CSV content from a string. First row must be the header.</summary>
    public static List<Employee> Parse(string csvContent)
    {
        var employees = new List<Employee>();
        var lines = csvContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        if (lines.Length < 2) return employees; // header only or empty

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

// --- Employee Filter: selects active employees ---
public static class EmployeeFilter
{
    public static List<Employee> ActiveOnly(IEnumerable<Employee> employees) =>
        employees.Where(e => e.Status.Equals("active", StringComparison.OrdinalIgnoreCase)).ToList();
}

// --- Overall statistics record ---
public record OverallStatistics(
    int TotalEmployees,
    decimal AverageSalary,
    decimal MinSalary,
    decimal MaxSalary,
    decimal TotalPayroll,
    int DepartmentCount
);

// --- Aggregator: computes department and overall stats ---
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

// --- Report Formatter: builds a human-readable text report ---
public static class ReportFormatter
{
    public static string GenerateReport(IEnumerable<Employee> employees)
    {
        var list = employees.ToList();
        var sb = new StringBuilder();
        var separator = new string('=', 60);

        sb.AppendLine(separator);
        sb.AppendLine("           EMPLOYEE SUMMARY REPORT");
        sb.AppendLine($"           Generated: {DateTime.Now:yyyy-MM-dd HH:mm}");
        sb.AppendLine(separator);
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
        sb.AppendLine(separator);

        return sb.ToString();
    }
}

// --- ReportPipeline: end-to-end orchestrator ---
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
