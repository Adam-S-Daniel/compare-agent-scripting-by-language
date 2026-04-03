// TDD Step 3: Tests for report generation.
// Verifies that the formatted text output contains the right content.

using Xunit;

namespace EmployeeReport.Tests;

public class ReportGeneratorTests
{
    private static List<Employee> ActiveEmployees() =>
    [
        new("Alice",  "Engineering", 90000m,  new DateOnly(2020, 1, 1), "Active"),
        new("Bob",    "Engineering", 110000m, new DateOnly(2019, 6, 1), "Active"),
        new("Diana",  "Marketing",   60000m,  new DateOnly(2018, 5, 1), "Active"),
        new("Eve",    "Marketing",   70000m,  new DateOnly(2022, 2, 1), "Active"),
    ];

    // RED: Report contains a header section
    [Fact]
    public void GenerateReport_ContainsTitle()
    {
        var report = ReportGenerator.Generate(ActiveEmployees());
        Assert.Contains("Employee Summary Report", report);
    }

    // RED: Report shows per-department stats
    [Fact]
    public void GenerateReport_ContainsDepartmentSection()
    {
        var report = ReportGenerator.Generate(ActiveEmployees());
        Assert.Contains("Engineering", report);
        Assert.Contains("Marketing", report);
    }

    [Fact]
    public void GenerateReport_ShowsAverageSalaryPerDepartment()
    {
        var report = ReportGenerator.Generate(ActiveEmployees());
        // Engineering avg = 100,000
        Assert.Contains("100,000", report);
        // Marketing avg = 65,000
        Assert.Contains("65,000", report);
    }

    [Fact]
    public void GenerateReport_ShowsHeadcountPerDepartment()
    {
        var report = ReportGenerator.Generate(ActiveEmployees());
        // Both departments have 2 employees
        Assert.Matches(@"Engineering.*2", report);
        Assert.Matches(@"Marketing.*2", report);
    }

    // RED: Report shows overall stats section
    [Fact]
    public void GenerateReport_ContainsOverallStatsSection()
    {
        var report = ReportGenerator.Generate(ActiveEmployees());
        Assert.Contains("Overall", report);
        Assert.Contains("4", report);   // total active employees
        Assert.Contains("82,500", report); // overall average salary
    }

    // RED: Write report to file
    [Fact]
    public void WriteReportToFile_CreatesFile()
    {
        var tmpFile = Path.GetTempFileName();
        try
        {
            ReportGenerator.WriteToFile(ActiveEmployees(), tmpFile);
            Assert.True(File.Exists(tmpFile));
            var content = File.ReadAllText(tmpFile);
            Assert.Contains("Employee Summary Report", content);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public void WriteReportToFile_CreatesParentDirectoriesIfNeeded()
    {
        var tmpDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        var tmpFile = Path.Combine(tmpDir, "sub", "report.txt");
        try
        {
            ReportGenerator.WriteToFile(ActiveEmployees(), tmpFile);
            Assert.True(File.Exists(tmpFile));
        }
        finally
        {
            if (Directory.Exists(tmpDir)) Directory.Delete(tmpDir, recursive: true);
        }
    }
}
