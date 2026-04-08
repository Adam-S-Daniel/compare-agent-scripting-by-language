// ============================================================
// Employee CSV Report Generator
// Run with: dotnet run app.cs [input.csv] [output.txt]
//
// Reads a CSV file of employee records, filters to active employees,
// computes salary aggregates by department and overall, and writes
// a formatted summary report to a text file.
//
// Default input:  employees.csv (in current directory)
// Default output: report.txt   (in current directory)
// ============================================================

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

// ── Resolve input/output paths from CLI args or defaults ──────

var inputPath  = args.Length > 0 ? args[0] : "employees.csv";
var outputPath = args.Length > 1 ? args[1] : "report.txt";

Console.WriteLine("Employee CSV Report Generator");
Console.WriteLine(new string('=', 40));
Console.WriteLine($"Input:  {inputPath}");
Console.WriteLine($"Output: {outputPath}");
Console.WriteLine();

try
{
    // ── Step 1: Parse CSV ─────────────────────────────────────
    Console.WriteLine("Reading employee data...");
    var allEmployees = CsvParser.ParseFromFile(inputPath);
    Console.WriteLine($"  Loaded {allEmployees.Count} employee records.");

    // ── Step 2: Filter to active employees ────────────────────
    var activeEmployees = ReportGenerator.FilterActiveEmployees(allEmployees);
    Console.WriteLine($"  {activeEmployees.Count} active employees found.");

    // ── Step 3: Compute aggregates ────────────────────────────
    Console.WriteLine("Computing statistics...");
    var deptStats = ReportGenerator.ComputeDepartmentStats(activeEmployees);
    var overall   = ReportGenerator.ComputeOverallStats(allEmployees, activeEmployees);
    Console.WriteLine($"  {deptStats.Count} department(s) computed.");

    // ── Step 4: Format the report ─────────────────────────────
    var reportContent = ReportGenerator.FormatReport(deptStats, overall);

    // ── Step 5: Write to output file ──────────────────────────
    ReportGenerator.WriteReportToFile(reportContent, outputPath);
    Console.WriteLine($"Report written to: {outputPath}");
    Console.WriteLine();

    // Also print the report to stdout for convenience
    Console.WriteLine(reportContent);
}
catch (FileNotFoundException ex)
{
    Console.Error.WriteLine($"ERROR: {ex.Message}");
    Console.Error.WriteLine($"Usage: dotnet run app.cs [input.csv] [output.txt]");
    Environment.Exit(1);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: Unexpected failure — {ex.GetType().Name}: {ex.Message}");
    Environment.Exit(2);
}

// ============================================================
// DATA MODELS
// ============================================================

record Employee(
    string Name,
    string Department,
    decimal Salary,
    DateOnly HireDate,
    string Status
);

record DepartmentStats(
    string Department,
    int Headcount,
    decimal AverageSalary,
    decimal MinSalary,
    decimal MaxSalary
);

record OverallStats(
    int TotalEmployees,
    int ActiveEmployees,
    decimal AverageSalary,
    decimal MinSalary,
    decimal MaxSalary
);

// ============================================================
// CSV PARSER
// ============================================================

static class CsvParser
{
    /// <summary>Parse employee records from CSV-formatted string content.</summary>
    public static List<Employee> ParseFromString(string csvContent)
    {
        var employees = new List<Employee>();
        var lines = csvContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        // Row 0 is the header — skip it
        for (int i = 1; i < lines.Length; i++)
        {
            var line = lines[i].Trim();
            if (string.IsNullOrWhiteSpace(line)) continue;

            // Simple comma split — assumes no quoted commas in field values
            var parts = line.Split(',');
            if (parts.Length < 5)
            {
                Console.Error.WriteLine($"  [WARN] Skipping malformed row {i + 1}: '{line}'");
                continue;
            }

            var name       = parts[0].Trim();
            var department = parts[1].Trim();
            var salaryStr  = parts[2].Trim();
            var dateStr    = parts[3].Trim();
            var status     = parts[4].Trim();

            if (!decimal.TryParse(salaryStr, out decimal salary))
            {
                Console.Error.WriteLine($"  [WARN] Skipping row {i + 1}: invalid salary '{salaryStr}'");
                continue;
            }

            if (!DateOnly.TryParse(dateStr, out DateOnly hireDate))
            {
                Console.Error.WriteLine($"  [WARN] Skipping row {i + 1}: invalid date '{dateStr}'");
                continue;
            }

            employees.Add(new Employee(name, department, salary, hireDate, status));
        }

        return employees;
    }

    /// <summary>Read and parse employee records from a CSV file path.</summary>
    public static List<Employee> ParseFromFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException($"CSV file not found: {filePath}", filePath);

        return ParseFromString(File.ReadAllText(filePath));
    }
}

// ============================================================
// REPORT GENERATOR
// ============================================================

static class ReportGenerator
{
    /// <summary>Return only employees whose Status is "Active" (case-insensitive).</summary>
    public static List<Employee> FilterActiveEmployees(List<Employee> employees) =>
        employees
            .Where(e => e.Status.Equals("Active", StringComparison.OrdinalIgnoreCase))
            .ToList();

    /// <summary>Compute per-department headcount, average, min, and max salary.</summary>
    public static List<DepartmentStats> ComputeDepartmentStats(List<Employee> activeEmployees) =>
        activeEmployees
            .GroupBy(e => e.Department)
            .Select(g => new DepartmentStats(
                Department:    g.Key,
                Headcount:     g.Count(),
                AverageSalary: Math.Round(g.Average(e => e.Salary), 2),
                MinSalary:     g.Min(e => e.Salary),
                MaxSalary:     g.Max(e => e.Salary)
            ))
            .OrderBy(s => s.Department)
            .ToList();

    /// <summary>Compute totals and salary range across all vs active employees.</summary>
    public static OverallStats ComputeOverallStats(List<Employee> allEmployees, List<Employee> activeEmployees)
    {
        if (activeEmployees.Count == 0)
            return new OverallStats(allEmployees.Count, 0, 0m, 0m, 0m);

        return new OverallStats(
            TotalEmployees:  allEmployees.Count,
            ActiveEmployees: activeEmployees.Count,
            AverageSalary:   Math.Round(activeEmployees.Average(e => e.Salary), 2),
            MinSalary:       activeEmployees.Min(e => e.Salary),
            MaxSalary:       activeEmployees.Max(e => e.Salary)
        );
    }

    /// <summary>Build a human-readable report string from pre-computed stats.</summary>
    public static string FormatReport(List<DepartmentStats> deptStats, OverallStats overall)
    {
        var sb         = new StringBuilder();
        var divider    = new string('=', 60);
        var subDivider = new string('─', 60);

        sb.AppendLine(divider);
        sb.AppendLine("EMPLOYEE SALARY REPORT");
        sb.AppendLine($"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine(divider);
        sb.AppendLine();

        sb.AppendLine("OVERALL STATISTICS");
        sb.AppendLine(subDivider);
        sb.AppendLine($"  Total Employees:   {overall.TotalEmployees}");
        sb.AppendLine($"  Active Employees:  {overall.ActiveEmployees}");

        if (overall.ActiveEmployees > 0)
        {
            sb.AppendLine($"  Average Salary:    {overall.AverageSalary:C}");
            sb.AppendLine($"  Min Salary:        {overall.MinSalary:C}");
            sb.AppendLine($"  Max Salary:        {overall.MaxSalary:C}");
        }
        else
        {
            sb.AppendLine("  (No active employees — salary statistics unavailable)");
        }

        sb.AppendLine();
        sb.AppendLine("DEPARTMENT BREAKDOWN");
        sb.AppendLine(subDivider);

        foreach (var dept in deptStats)
        {
            sb.AppendLine();
            sb.AppendLine($"  Department:      {dept.Department}");
            sb.AppendLine($"  Headcount:       {dept.Headcount}");
            sb.AppendLine($"  Average Salary:  {dept.AverageSalary:C}");
            sb.AppendLine($"  Min Salary:      {dept.MinSalary:C}");
            sb.AppendLine($"  Max Salary:      {dept.MaxSalary:C}");
        }

        sb.AppendLine();
        sb.AppendLine(divider);
        return sb.ToString();
    }

    /// <summary>Write report content to a text file, creating any needed directories.</summary>
    public static void WriteReportToFile(string reportContent, string outputPath)
    {
        var dir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        File.WriteAllText(outputPath, reportContent);
    }
}
