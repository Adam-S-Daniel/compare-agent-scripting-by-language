// EmployeeReport.cs - .NET 10 file-based app (top-level statements)
//
// Usage: dotnet run EmployeeReport.cs <input.csv> <output.txt>
//
// The #if !TESTING guard prevents the entry-point top-level statements from
// being compiled into the test project (which defines TESTING in its .csproj).
// The business logic classes below are shared between the app and the tests.

// ─────────────────────────────────────────────────────────────────────────────
// Domain model
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>Immutable record representing one employee row from the CSV.</summary>
public record Employee(
    string Name,
    string Department,
    decimal Salary,
    DateOnly HireDate,
    string Status);

/// <summary>Pre-computed overall statistics across all active employees.</summary>
public record OverallStats(
    int TotalActiveEmployees,
    decimal OverallAverageSalary,
    decimal MaxSalary,
    decimal MinSalary,
    int DepartmentCount);

// ─────────────────────────────────────────────────────────────────────────────
// Custom exception
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>Thrown when a CSV row cannot be parsed into an Employee.</summary>
public class CsvParseException : Exception
{
    public CsvParseException(string message) : base(message) { }
    public CsvParseException(string message, Exception inner) : base(message, inner) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// CSV Parser
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Reads and parses employee CSV files.
/// Expected header: name,department,salary,hire_date,status
/// </summary>
public static class CsvParser
{
    /// <summary>
    /// Parse a single data line (not the header) into an Employee.
    /// lineNumber is used only for error messages (1-based, header = line 1).
    /// </summary>
    public static Employee ParseRow(string line, int lineNumber)
    {
        var parts = line.Split(',');

        if (parts.Length != 5)
            throw new CsvParseException(
                $"Parse error at line {lineNumber}: expected 5 columns but found {parts.Length}. " +
                $"Line content: \"{line}\"");

        var name       = parts[0].Trim();
        var department = parts[1].Trim();
        var salaryRaw  = parts[2].Trim();
        var dateRaw    = parts[3].Trim();
        var status     = parts[4].Trim();

        if (!decimal.TryParse(salaryRaw, System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out var salary))
            throw new CsvParseException(
                $"Parse error at line {lineNumber}: invalid salary value \"{salaryRaw}\". " +
                $"Salary must be a numeric value.");

        if (!DateOnly.TryParseExact(dateRaw, "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out var hireDate))
            throw new CsvParseException(
                $"Parse error at line {lineNumber}: invalid hire_date \"{dateRaw}\". " +
                $"Expected format: yyyy-MM-dd.");

        return new Employee(name, department, salary, hireDate, status);
    }

    /// <summary>
    /// Parse an entire CSV file. Skips the header row.
    /// Throws FileNotFoundException with a meaningful message if the file is missing.
    /// Throws CsvParseException for any malformed data rows.
    /// </summary>
    public static List<Employee> ParseFile(string filePath)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException(
                $"CSV file not found: \"{filePath}\". " +
                $"Please check the path and try again.", filePath);

        var employees = new List<Employee>();
        var lines = File.ReadAllLines(filePath);

        // lineNumber tracks the 1-based position for error messages; start at 1 (header).
        for (int i = 1; i < lines.Length; i++)
        {
            var line = lines[i].Trim();
            if (string.IsNullOrEmpty(line)) continue; // skip blank lines

            employees.Add(ParseRow(line, lineNumber: i + 1));
        }

        return employees;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aggregate Calculator
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Computes filtering and aggregate statistics on a collection of employees.
/// All methods operate on in-memory lists and have no I/O side-effects.
/// </summary>
public static class AggregateCalculator
{
    /// <summary>Filter to employees whose status is exactly "Active" (case-sensitive).</summary>
    public static List<Employee> FilterActive(IEnumerable<Employee> employees) =>
        employees.Where(e => e.Status == "Active").ToList();

    /// <summary>
    /// Returns a dictionary mapping department name → average salary.
    /// Only considers the provided list (call FilterActive first to restrict to active employees).
    /// </summary>
    public static Dictionary<string, decimal> AverageSalaryByDepartment(
        IEnumerable<Employee> employees) =>
        employees
            .GroupBy(e => e.Department)
            .ToDictionary(
                g => g.Key,
                g => g.Average(e => e.Salary));

    /// <summary>Returns a dictionary mapping department name → headcount.</summary>
    public static Dictionary<string, int> HeadcountByDepartment(
        IEnumerable<Employee> employees) =>
        employees
            .GroupBy(e => e.Department)
            .ToDictionary(g => g.Key, g => g.Count());

    /// <summary>Computes overall aggregate statistics across the provided employee list.</summary>
    public static OverallStats ComputeOverallStats(IEnumerable<Employee> employees)
    {
        var list = employees.ToList();

        if (list.Count == 0)
            return new OverallStats(0, 0m, 0m, 0m, 0);

        return new OverallStats(
            TotalActiveEmployees: list.Count,
            OverallAverageSalary: list.Average(e => e.Salary),
            MaxSalary:            list.Max(e => e.Salary),
            MinSalary:            list.Min(e => e.Salary),
            DepartmentCount:      list.Select(e => e.Department).Distinct().Count());
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Generator
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Builds a human-readable text report from a list of active employees.
/// </summary>
public static class ReportGenerator
{
    private const string Separator = "────────────────────────────────────────────────";

    /// <summary>Build the full report string.</summary>
    public static string Generate(IEnumerable<Employee> activeEmployees)
    {
        var employees = activeEmployees.ToList();
        var averages  = AggregateCalculator.AverageSalaryByDepartment(employees);
        var counts    = AggregateCalculator.HeadcountByDepartment(employees);
        var stats     = AggregateCalculator.ComputeOverallStats(employees);

        var sb = new System.Text.StringBuilder();

        // ── Header ──────────────────────────────────────────────────────────
        sb.AppendLine(Separator);
        sb.AppendLine("         Employee Summary Report");
        sb.AppendLine($"         Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine(Separator);
        sb.AppendLine();

        // ── Per-Department Stats ─────────────────────────────────────────────
        sb.AppendLine("DEPARTMENT BREAKDOWN (Active Employees)");
        sb.AppendLine(Separator);
        sb.AppendLine($"{"Department",-20} {"Headcount",10} {"Avg Salary",15}");
        sb.AppendLine(new string('-', 48));

        foreach (var dept in averages.Keys.OrderBy(k => k))
        {
            sb.AppendLine($"{dept,-20} {counts[dept],10} {averages[dept],15:N0}");
        }

        sb.AppendLine();

        // ── Overall Stats ────────────────────────────────────────────────────
        sb.AppendLine("Overall Statistics");
        sb.AppendLine(Separator);
        sb.AppendLine($"  Total active employees : {stats.TotalActiveEmployees}");
        sb.AppendLine($"  Departments represented: {stats.DepartmentCount}");
        sb.AppendLine($"  Average salary         : {stats.OverallAverageSalary:N0}");
        sb.AppendLine($"  Highest salary         : {stats.MaxSalary:N0}");
        sb.AppendLine($"  Lowest salary          : {stats.MinSalary:N0}");
        sb.AppendLine(Separator);

        return sb.ToString();
    }

    /// <summary>
    /// Write the report to the given output file path.
    /// Creates parent directories if they don't exist.
    /// </summary>
    public static void WriteToFile(IEnumerable<Employee> activeEmployees, string outputPath)
    {
        var dir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        File.WriteAllText(outputPath, Generate(activeEmployees));
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — only compiled when NOT running in the test project
// ─────────────────────────────────────────────────────────────────────────────

#if !TESTING

// Top-level statements: parse args, run the pipeline, write output.
if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: dotnet run EmployeeReport.cs <input.csv> <output.txt>");
    Console.Error.WriteLine("  input.csv  — CSV file with columns: name,department,salary,hire_date,status");
    Console.Error.WriteLine("  output.txt — Path where the summary report will be written");
    Environment.Exit(1);
}

var csvPath    = args[0];
var outputPath = args[1];

try
{
    Console.WriteLine($"Reading employees from: {csvPath}");
    var allEmployees    = CsvParser.ParseFile(csvPath);
    var activeEmployees = AggregateCalculator.FilterActive(allEmployees);

    Console.WriteLine($"Parsed {allEmployees.Count} total employees, " +
                      $"{activeEmployees.Count} active.");

    ReportGenerator.WriteToFile(activeEmployees, outputPath);

    Console.WriteLine($"Report written to: {outputPath}");
}
catch (FileNotFoundException ex)
{
    Console.Error.WriteLine($"Error: {ex.Message}");
    Environment.Exit(2);
}
catch (CsvParseException ex)
{
    Console.Error.WriteLine($"CSV parse error: {ex.Message}");
    Environment.Exit(3);
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
    Environment.Exit(99);
}

#endif
