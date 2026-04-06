// TDD Step 2: Tests for aggregate calculations.
// These tests verify filtering and statistical computations.

using Xunit;

namespace EmployeeReport.Tests;

public class AggregateCalculatorTests
{
    // Sample data shared across tests
    private static List<Employee> MakeEmployees() =>
    [
        new("Alice",   "Engineering", 90000m, new DateOnly(2020, 1, 1),  "Active"),
        new("Bob",     "Engineering", 110000m, new DateOnly(2019, 6, 1), "Active"),
        new("Charlie", "Engineering", 80000m, new DateOnly(2021, 3, 1),  "Inactive"),
        new("Diana",   "Marketing",   60000m, new DateOnly(2018, 5, 1),  "Active"),
        new("Eve",     "Marketing",   70000m, new DateOnly(2022, 2, 1),  "Active"),
        new("Frank",   "HR",          55000m, new DateOnly(2017, 9, 1),  "Inactive"),
    ];

    // RED: Filter to active employees only
    [Fact]
    public void FilterActive_ReturnsOnlyActiveEmployees()
    {
        var all = MakeEmployees();
        var active = AggregateCalculator.FilterActive(all);

        Assert.Equal(4, active.Count);
        Assert.All(active, e => Assert.Equal("Active", e.Status));
    }

    [Fact]
    public void FilterActive_EmptyList_ReturnsEmptyList()
    {
        var active = AggregateCalculator.FilterActive([]);
        Assert.Empty(active);
    }

    // RED: Average salary by department
    [Fact]
    public void AverageSalaryByDepartment_ComputesCorrectly()
    {
        var active = AggregateCalculator.FilterActive(MakeEmployees());
        var averages = AggregateCalculator.AverageSalaryByDepartment(active);

        // Engineering active: Alice 90000 + Bob 110000 = avg 100000
        Assert.Equal(100000m, averages["Engineering"]);
        // Marketing active: Diana 60000 + Eve 70000 = avg 65000
        Assert.Equal(65000m, averages["Marketing"]);
        // HR: Frank is Inactive, so no HR entry
        Assert.False(averages.ContainsKey("HR"));
    }

    // RED: Headcount by department
    [Fact]
    public void HeadcountByDepartment_ComputesCorrectly()
    {
        var active = AggregateCalculator.FilterActive(MakeEmployees());
        var counts = AggregateCalculator.HeadcountByDepartment(active);

        Assert.Equal(2, counts["Engineering"]);
        Assert.Equal(2, counts["Marketing"]);
        Assert.False(counts.ContainsKey("HR"));
    }

    // RED: Overall statistics
    [Fact]
    public void ComputeOverallStats_ReturnsCorrectStats()
    {
        var active = AggregateCalculator.FilterActive(MakeEmployees());
        var stats = AggregateCalculator.ComputeOverallStats(active);

        Assert.Equal(4, stats.TotalActiveEmployees);
        // avg of 90000+110000+60000+70000 = 330000/4 = 82500
        Assert.Equal(82500m, stats.OverallAverageSalary);
        Assert.Equal(110000m, stats.MaxSalary);
        Assert.Equal(60000m, stats.MinSalary);
        // Total departments with active employees
        Assert.Equal(2, stats.DepartmentCount);
    }

    [Fact]
    public void ComputeOverallStats_EmptyList_ReturnsZeros()
    {
        var stats = AggregateCalculator.ComputeOverallStats([]);

        Assert.Equal(0, stats.TotalActiveEmployees);
        Assert.Equal(0m, stats.OverallAverageSalary);
        Assert.Equal(0m, stats.MaxSalary);
        Assert.Equal(0m, stats.MinSalary);
        Assert.Equal(0, stats.DepartmentCount);
    }
}
