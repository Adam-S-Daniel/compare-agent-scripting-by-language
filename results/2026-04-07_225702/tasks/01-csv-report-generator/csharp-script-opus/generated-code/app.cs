// ═══════════════════════════════════════════════════════════════════════════════
// CSV Report Generator — Main Application
//
// Reads a CSV file of employee records, filters to active employees,
// computes department-level and overall aggregates, and writes a formatted
// summary report to a text file.
//
// Usage:  dotnet run app.cs <input.csv> [output.txt]
//         Defaults to "report.txt" if output path is omitted.
//
// .NET 10 file-based app — no .csproj needed.
// ═══════════════════════════════════════════════════════════════════════════════

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

// ─── CLI entry point ────────────────────────────────────────────────────────────

try
{
    if (args.Length < 1)
    {
        Console.Error.WriteLine("Usage: dotnet run app.cs <input.csv> [output.txt]");
        Console.Error.WriteLine("  input.csv   Path to employee CSV file (required)");
        Console.Error.WriteLine("  output.txt  Path for the report output (default: report.txt)");
        return 1;
    }

    string inputPath = args[0];
    string outputPath = args.Length >= 2 ? args[1] : "report.txt";

    Console.WriteLine($"Reading employees from: {inputPath}");
    ReportPipeline.Run(inputPath, outputPath);
    Console.WriteLine($"Report written to: {outputPath}");
    return 0;
}
catch (FileNotFoundException ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}
catch (FormatException ex)
{
    Console.Error.WriteLine($"Error: Invalid data in CSV — {ex.Message}");
    return 1;
}
catch (InvalidOperationException ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    return 2;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Types must follow top-level statements in C# file-based apps
// ═══════════════════════════════════════════════════════════════════════════════

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

/// <summary>Parses CSV text or files into Employee records.</summary>
public static class CsvParser
{
    public static List<Employee> Parse(string csvContent)
    {
        var employees = new List<Employee>();
        var lines = csvContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        if (lines.Length < 2) return employees;

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

    public static List<Employee> ParseFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"CSV file not found: {filePath}", filePath);
        return Parse(File.ReadAllText(filePath));
    }
}

/// <summary>Filters employees by status.</summary>
public static class EmployeeFilter
{
    public static List<Employee> ActiveOnly(IEnumerable<Employee> employees) =>
        employees.Where(e => e.Status.Equals("active", StringComparison.OrdinalIgnoreCase)).ToList();
}

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
