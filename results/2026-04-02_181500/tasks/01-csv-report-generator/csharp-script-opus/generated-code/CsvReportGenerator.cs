// CSV Report Generator — .NET 10 file-based app
// Usage: dotnet run CsvReportGenerator.cs <input.csv> [output.txt]
//
// Reads employee records from a CSV file, filters to active employees,
// computes department and overall aggregates, and writes a formatted
// summary report to a text file.

// ─── Data Models ───────────────────────────────────────────────────
record Employee(string Name, string Department, decimal Salary, DateTime HireDate, string Status);
record DepartmentStats(string Department, int Headcount, decimal AverageSalary, decimal MinSalary, decimal MaxSalary, decimal TotalSalary);
record ReportSummary(List<DepartmentStats> DepartmentStatsList, int TotalActiveEmployees, decimal OverallAverageSalary, decimal OverallMinSalary, decimal OverallMaxSalary);

// ─── CSV Parsing ───────────────────────────────────────────────────
static List<Employee> ParseCsv(string csvContent)
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
    var expectedFields = new[] { "name", "department", "salary", "hire_date", "status" };
    var headerFields = lines[0].ToLowerInvariant().Split(',').Select(f => f.Trim()).ToArray();

    if (headerFields.Length != 5 || !expectedFields.SequenceEqual(headerFields))
        throw new ArgumentException(
            $"Invalid CSV header. Expected: {string.Join(",", expectedFields)}. Got: {lines[0]}");

    var employees = new List<Employee>();
    for (int i = 1; i < lines.Count; i++)
    {
        var fields = lines[i].Split(',').Select(f => f.Trim()).ToArray();
        if (fields.Length != 5)
            throw new FormatException(
                $"Line {i + 1}: Expected 5 fields but got {fields.Length}. Content: '{lines[i]}'");

        if (!decimal.TryParse(fields[2], out var salary))
            throw new FormatException($"Line {i + 1}: Invalid salary value '{fields[2]}'.");

        if (!DateTime.TryParse(fields[3], out var hireDate))
            throw new FormatException($"Line {i + 1}: Invalid hire_date value '{fields[3]}'.");

        employees.Add(new Employee(fields[0], fields[1], salary, hireDate, fields[4]));
    }
    return employees;
}

// ─── Filtering ─────────────────────────────────────────────────────
static List<Employee> FilterActive(List<Employee> employees) =>
    employees.Where(e => e.Status.Equals("Active", StringComparison.OrdinalIgnoreCase)).ToList();

// ─── Aggregation ───────────────────────────────────────────────────
static ReportSummary Summarize(List<Employee> activeEmployees)
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
            TotalSalary: g.Sum(e => e.Salary)))
        .ToList();

    return new ReportSummary(
        DepartmentStatsList: deptStats,
        TotalActiveEmployees: activeEmployees.Count,
        OverallAverageSalary: Math.Round(activeEmployees.Average(e => e.Salary), 2),
        OverallMinSalary: activeEmployees.Min(e => e.Salary),
        OverallMaxSalary: activeEmployees.Max(e => e.Salary));
}

// ─── Report Formatting ────────────────────────────────────────────
static string FormatReport(ReportSummary summary)
{
    var sb = new System.Text.StringBuilder();

    sb.AppendLine("========================================");
    sb.AppendLine("       EMPLOYEE SUMMARY REPORT          ");
    sb.AppendLine("========================================");
    sb.AppendLine();

    sb.AppendLine("OVERALL STATISTICS");
    sb.AppendLine("------------------");
    sb.AppendLine($"  Total Active Employees : {summary.TotalActiveEmployees}");
    sb.AppendLine($"  Average Salary         : {summary.OverallAverageSalary:C}");
    sb.AppendLine($"  Minimum Salary         : {summary.OverallMinSalary:C}");
    sb.AppendLine($"  Maximum Salary         : {summary.OverallMaxSalary:C}");
    sb.AppendLine();

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

// ─── Main Entry Point ──────────────────────────────────────────────
if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: dotnet run CsvReportGenerator.cs <input.csv> [output.txt]");
    Console.Error.WriteLine("  <input.csv>   Path to the CSV file with employee records");
    Console.Error.WriteLine("  [output.txt]  Optional output path (default: report.txt)");
    return 1;
}

var inputPath = args[0];
var outputPath = args.Length > 1 ? args[1] : "report.txt";

if (!File.Exists(inputPath))
{
    Console.Error.WriteLine($"Error: Input file '{inputPath}' not found.");
    return 1;
}

try
{
    // Read and parse CSV
    var csvContent = File.ReadAllText(inputPath);
    var allEmployees = ParseCsv(csvContent);
    Console.WriteLine($"Parsed {allEmployees.Count} employee records.");

    // Filter to active only
    var activeEmployees = FilterActive(allEmployees);
    Console.WriteLine($"Found {activeEmployees.Count} active employees (filtered out {allEmployees.Count - activeEmployees.Count} inactive).");

    // Compute aggregates and format report
    var summary = Summarize(activeEmployees);
    var report = FormatReport(summary);

    // Write output
    File.WriteAllText(outputPath, report);
    Console.WriteLine($"Report written to '{outputPath}'.");
    Console.WriteLine();
    Console.Write(report);

    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    return 1;
}
