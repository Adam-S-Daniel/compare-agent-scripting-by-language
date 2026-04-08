// ============================================================
// TDD RED PHASE: Tests written FIRST, stubs throw NotImplementedException
// Run with: dotnet run tests.cs
//
// TDD Cycle:
//   RED   → tests written first, stubs throw → all fail
//   GREEN → implement to make tests pass
//   REFACTOR → clean up while keeping tests green
//
// NOTE: In C# file-based apps, top-level statements must come first.
// Type/class declarations appear at the bottom of this file.
// ============================================================

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

// ===== SIMPLE TEST RUNNER (top-level code, must come first) =====

int passed = 0, failed = 0;
var failures = new List<string>();

void Check(string name, bool condition, string? details = null)
{
    if (condition)
    {
        Console.WriteLine($"  [PASS] {name}");
        passed++;
    }
    else
    {
        var msg = details != null ? $"{name} — {details}" : name;
        Console.WriteLine($"  [FAIL] {msg}");
        failures.Add(msg);
        failed++;
    }
}

void Suite(string title, Action body)
{
    Console.WriteLine($"\n{title}");
    Console.WriteLine(new string('─', title.Length));
    try { body(); }
    catch (NotImplementedException ex)
    {
        Console.WriteLine($"  [FAIL] Not implemented: {ex.Message}");
        failures.Add($"{title}: {ex.Message}");
        failed++;
    }
    catch (Exception ex)
    {
        Console.WriteLine($"  [ERROR] Unexpected: {ex.GetType().Name}: {ex.Message}");
        failures.Add($"{title}: {ex.Message}");
        failed++;
    }
}

// ===== TEST SUITES =====

Console.WriteLine("CSV Report Generator — Test Suite");
Console.WriteLine(new string('═', 40));

// ── Test 1: CSV Parsing from string ─────────────────────────
Suite("Test 1: CSV Parsing from string", () =>
{
    const string csv = """
        name,department,salary,hire_date,status
        Alice Johnson,Engineering,95000,2020-03-15,Active
        Bob Smith,Marketing,72000,2019-07-22,Inactive
        Carol White,Engineering,88000,2021-01-10,Active
        """;

    var employees = CsvParser.ParseFromString(csv);

    Check("Parses 3 rows", employees.Count == 3, $"got {employees.Count}");
    Check("Name parsed correctly", employees[0].Name == "Alice Johnson");
    Check("Department parsed correctly", employees[0].Department == "Engineering");
    Check("Salary parsed as decimal", employees[0].Salary == 95000m);
    Check("HireDate parsed correctly", employees[0].HireDate == new DateOnly(2020, 3, 15));
    Check("Status Active parsed", employees[0].Status == "Active");
    Check("Status Inactive parsed", employees[1].Status == "Inactive");
    Check("Second employee name", employees[1].Name == "Bob Smith");
});

// ── Test 2: CSV Parsing from file ───────────────────────────
Suite("Test 2: CSV Parsing from file", () =>
{
    var tmpFile = Path.ChangeExtension(Path.GetTempFileName(), ".csv");
    try
    {
        File.WriteAllText(tmpFile,
            "name,department,salary,hire_date,status\n" +
            "Test User,QA,55000,2023-06-01,Active\n"
        );

        var employees = CsvParser.ParseFromFile(tmpFile);
        Check("Parsed 1 employee from file", employees.Count == 1, $"got {employees.Count}");
        Check("Name from file", employees[0].Name == "Test User");
        Check("Department from file", employees[0].Department == "QA");
        Check("Salary from file", employees[0].Salary == 55000m);
    }
    finally
    {
        if (File.Exists(tmpFile)) File.Delete(tmpFile);
    }
});

// ── Test 3: Missing file throws FileNotFoundException ────────
Suite("Test 3: Missing file throws FileNotFoundException", () =>
{
    try
    {
        CsvParser.ParseFromFile("/nonexistent/path/does-not-exist.csv");
        Check("Should have thrown FileNotFoundException", false, "no exception raised");
    }
    catch (FileNotFoundException)
    {
        Check("FileNotFoundException thrown", true);
    }
    catch (NotImplementedException)
    {
        throw; // re-raise so Suite handler records it as RED
    }
});

// ── Test 4: Filter active employees ─────────────────────────
Suite("Test 4: Filter active employees", () =>
{
    var employees = new List<Employee>
    {
        new("Alice", "Engineering", 90000m, new DateOnly(2020, 1, 1), "Active"),
        new("Bob",   "Marketing",   70000m, new DateOnly(2019, 6, 15), "Inactive"),
        new("Carol", "Engineering", 80000m, new DateOnly(2021, 3, 10), "Active"),
        new("Dave",  "HR",          65000m, new DateOnly(2018, 9, 1),  "Inactive"),
    };

    var active = ReportGenerator.FilterActiveEmployees(employees);
    Check("Returns 2 active employees", active.Count == 2, $"got {active.Count}");
    Check("All returned are Active", active.All(e => e.Status == "Active"));
    Check("Alice included", active.Any(e => e.Name == "Alice"));
    Check("Bob excluded", active.All(e => e.Name != "Bob"));
    Check("Dave excluded", active.All(e => e.Name != "Dave"));
});

// ── Test 5: Department statistics ───────────────────────────
Suite("Test 5: Department statistics", () =>
{
    var active = new List<Employee>
    {
        new("Alice", "Engineering", 90000m, new DateOnly(2020, 1, 1), "Active"),
        new("Carol", "Engineering", 80000m, new DateOnly(2021, 3, 10), "Active"),
        new("Dave",  "Marketing",   70000m, new DateOnly(2022, 5, 1),  "Active"),
    };

    var stats = ReportGenerator.ComputeDepartmentStats(active);
    Check("Two departments returned", stats.Count == 2, $"got {stats.Count}");

    var eng = stats.FirstOrDefault(s => s.Department == "Engineering");
    Check("Engineering found", eng != null);
    Check("Engineering headcount = 2", eng!.Headcount == 2, $"got {eng.Headcount}");
    Check("Engineering avg salary = 85000", eng.AverageSalary == 85000m, $"got {eng.AverageSalary}");
    Check("Engineering min salary = 80000", eng.MinSalary == 80000m, $"got {eng.MinSalary}");
    Check("Engineering max salary = 90000", eng.MaxSalary == 90000m, $"got {eng.MaxSalary}");

    var mkt = stats.FirstOrDefault(s => s.Department == "Marketing");
    Check("Marketing found", mkt != null);
    Check("Marketing headcount = 1", mkt!.Headcount == 1, $"got {mkt.Headcount}");
    Check("Marketing avg salary = 70000", mkt.AverageSalary == 70000m, $"got {mkt.AverageSalary}");
});

// ── Test 6: Overall statistics ──────────────────────────────
Suite("Test 6: Overall statistics", () =>
{
    var all = new List<Employee>
    {
        new("Alice", "Engineering", 90000m, new DateOnly(2020, 1, 1), "Active"),
        new("Bob",   "Marketing",   70000m, new DateOnly(2019, 6, 15), "Inactive"),
        new("Carol", "Engineering", 80000m, new DateOnly(2021, 3, 10), "Active"),
    };
    var active = all.Where(e => e.Status == "Active").ToList();

    var stats = ReportGenerator.ComputeOverallStats(all, active);
    Check("TotalEmployees = 3", stats.TotalEmployees == 3, $"got {stats.TotalEmployees}");
    Check("ActiveEmployees = 2", stats.ActiveEmployees == 2, $"got {stats.ActiveEmployees}");
    Check("AverageSalary = 85000", stats.AverageSalary == 85000m, $"got {stats.AverageSalary}");
    Check("MinSalary = 80000", stats.MinSalary == 80000m, $"got {stats.MinSalary}");
    Check("MaxSalary = 90000", stats.MaxSalary == 90000m, $"got {stats.MaxSalary}");
});

// ── Test 7: Report formatting ────────────────────────────────
Suite("Test 7: Report formatting", () =>
{
    var deptStats = new List<DepartmentStats>
    {
        new("Engineering", 2, 85000m, 80000m, 90000m),
        new("Marketing",   1, 70000m, 70000m, 70000m),
    };
    var overall = new OverallStats(3, 2, 80000m, 70000m, 90000m);

    var report = ReportGenerator.FormatReport(deptStats, overall);
    Check("Contains title header", report.Contains("EMPLOYEE SALARY REPORT"));
    Check("Contains overall section", report.Contains("OVERALL STATISTICS"));
    Check("Contains department section", report.Contains("DEPARTMENT BREAKDOWN"));
    Check("Contains Engineering", report.Contains("Engineering"));
    Check("Contains Marketing", report.Contains("Marketing"));
    Check("Contains Headcount label", report.Contains("Headcount"));
    Check("Contains Total Employees label", report.Contains("Total Employees"));
    Check("Contains Active Employees label", report.Contains("Active Employees"));
    Check("Contains Average Salary label", report.Contains("Average Salary"));
});

// ── Test 8: Write report to file ─────────────────────────────
Suite("Test 8: Write report to file", () =>
{
    var tmpFile = Path.ChangeExtension(Path.GetTempFileName(), ".txt");
    try
    {
        ReportGenerator.WriteReportToFile("Hello report content", tmpFile);
        Check("File was created", File.Exists(tmpFile));
        var content = File.ReadAllText(tmpFile);
        Check("File contains expected content", content.Contains("Hello report content"));
    }
    finally
    {
        if (File.Exists(tmpFile)) File.Delete(tmpFile);
    }
});

// ── Test 9: Edge case — empty CSV (header only) ──────────────
Suite("Test 9: Edge case — empty CSV (header only)", () =>
{
    var employees = CsvParser.ParseFromString("name,department,salary,hire_date,status\n");
    Check("Returns empty list", employees.Count == 0, $"got {employees.Count}");
});

// ── Test 10: Edge case — no active employees ─────────────────
Suite("Test 10: Edge case — no active employees", () =>
{
    var all = new List<Employee>
    {
        new("X", "IT", 50000m, new DateOnly(2020, 1, 1), "Inactive"),
    };
    var active = ReportGenerator.FilterActiveEmployees(all);
    Check("Active list is empty", active.Count == 0);

    var overall = ReportGenerator.ComputeOverallStats(all, active);
    Check("TotalEmployees still counted", overall.TotalEmployees == 1);
    Check("ActiveEmployees = 0", overall.ActiveEmployees == 0);
    Check("AverageSalary = 0 when no active", overall.AverageSalary == 0m);
});

// ===== RESULTS =====

Console.WriteLine();
Console.WriteLine(new string('═', 40));
Console.WriteLine($"Results: {passed} passed, {failed} failed");

if (failures.Count > 0)
{
    Console.WriteLine("\nFailed:");
    foreach (var f in failures)
        Console.WriteLine($"  ✗ {f}");
    Environment.Exit(1);
}
else
{
    Console.WriteLine("All tests passed!");
}

// ============================================================
// DATA MODELS — declared after top-level statements (required by C#)
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
// IMPLEMENTATION — GREEN phase: real code to make all tests pass
// ============================================================

static class CsvParser
{
    /// <summary>Parse employee records from CSV-formatted string content.</summary>
    public static List<Employee> ParseFromString(string csvContent)
    {
        var employees = new List<Employee>();

        // Split on newlines; trim to handle \r\n on Windows
        var lines = csvContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        // Skip the header row (index 0)
        for (int i = 1; i < lines.Length; i++)
        {
            var line = lines[i].Trim();
            if (string.IsNullOrWhiteSpace(line)) continue;

            // Split on commas — assumes no quoted commas in fields
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
        // Guard: avoid divide-by-zero when there are no active employees
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
        var sb = new StringBuilder();
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
        sb.AppendLine($"  Average Salary:    {overall.AverageSalary:C}");
        sb.AppendLine($"  Min Salary:        {overall.MinSalary:C}");
        sb.AppendLine($"  Max Salary:        {overall.MaxSalary:C}");
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

    /// <summary>Write report content to a text file, creating it if needed.</summary>
    public static void WriteReportToFile(string reportContent, string outputPath)
    {
        // Ensure the output directory exists
        var dir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        File.WriteAllText(outputPath, reportContent);
    }
}
