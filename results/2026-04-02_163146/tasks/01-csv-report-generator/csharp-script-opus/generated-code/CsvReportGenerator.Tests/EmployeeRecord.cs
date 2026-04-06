// EmployeeRecord — data model for a single employee row from the CSV.

namespace CsvReportGenerator;

/// <summary>
/// Represents one employee row parsed from the CSV file.
/// </summary>
public record EmployeeRecord(
    string Name,
    string Department,
    decimal Salary,
    DateTime HireDate,
    string Status
)
{
    /// <summary>Whether this employee is currently active.</summary>
    public bool IsActive => Status.Equals("active", StringComparison.OrdinalIgnoreCase);
}
