// VerificationQueryTests.cs - TDD tests for verification queries.
// Verifies that RunVerification() returns correct, consistent results
// that confirm data integrity across the seeded database.

using Microsoft.Data.Sqlite;
using Xunit;

namespace DatabaseSeed.Tests;

/// <summary>
/// Tests that verify the verification queries return correct results
/// and that those results confirm overall data consistency.
/// </summary>
public class VerificationQueryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DatabaseSeeder _seeder;
    private readonly VerificationResult _result;

    public VerificationQueryTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
        _seeder = new DatabaseSeeder(_connection, seed: 42);
        _seeder.CreateSchema();
        _seeder.SeedData(userCount: 20, productCount: 15, orderCount: 50);
        // Run verification once for all tests in this class
        _result = _seeder.RunVerification();
    }

    public void Dispose()
    {
        _connection.Dispose();
    }

    [Fact]
    public void Verification_ReportsCorrectUserCount()
    {
        Assert.Equal(20, _result.UserCount);
    }

    [Fact]
    public void Verification_ReportsCorrectProductCount()
    {
        Assert.Equal(15, _result.ProductCount);
    }

    [Fact]
    public void Verification_ReportsCorrectOrderCount()
    {
        Assert.Equal(50, _result.OrderCount);
    }

    [Fact]
    public void Verification_NoOrphanedOrdersByUser()
    {
        // All orders must reference existing users
        Assert.Equal(0, _result.OrphanedOrdersByUser);
    }

    [Fact]
    public void Verification_NoOrphanedOrdersByProduct()
    {
        // All orders must reference existing products
        Assert.Equal(0, _result.OrphanedOrdersByProduct);
    }

    [Fact]
    public void Verification_TotalRevenueIsPositive()
    {
        Assert.True(_result.TotalRevenue > 0,
            $"Total revenue should be positive, got {_result.TotalRevenue}");
    }

    [Fact]
    public void Verification_AverageOrderValueIsPositive()
    {
        Assert.True(_result.AverageOrderValue > 0,
            $"Average order value should be positive, got {_result.AverageOrderValue}");
    }

    [Fact]
    public void Verification_AverageOrderValue_EqualsRevenueOverOrders()
    {
        // Avg = Total / Count, within floating-point tolerance
        var expected = _result.TotalRevenue / _result.OrderCount;
        Assert.Equal(expected, _result.AverageOrderValue, precision: 2);
    }

    [Fact]
    public void Verification_TopUsersByOrders_ReturnsAtMost5()
    {
        Assert.True(_result.TopUsersByOrders.Count <= 5);
        Assert.True(_result.TopUsersByOrders.Count > 0);
    }

    [Fact]
    public void Verification_TopUsersByOrders_IsSortedDescending()
    {
        var counts = _result.TopUsersByOrders.Select(x => x.OrderCount).ToList();
        for (int i = 1; i < counts.Count; i++)
        {
            Assert.True(counts[i - 1] >= counts[i],
                $"Top users not sorted: {counts[i - 1]} < {counts[i]}");
        }
    }

    [Fact]
    public void Verification_RevenueByCategory_HasEntries()
    {
        Assert.True(_result.RevenueByCategory.Count > 0,
            "Revenue by category should have at least one entry");
    }

    [Fact]
    public void Verification_RevenueByCategory_SumsToTotalRevenue()
    {
        var categoryTotal = _result.RevenueByCategory.Values.Sum();
        // Allow small floating-point tolerance
        Assert.Equal(_result.TotalRevenue, categoryTotal, precision: 2);
    }

    [Fact]
    public void Verification_NoPriceInconsistencies()
    {
        // total_price must equal quantity * product.price for all orders
        Assert.Equal(0, _result.InconsistentPriceCount);
    }

    [Fact]
    public void Verification_IsDeterministic()
    {
        // Running verification on a second identically-seeded database
        // should produce the exact same results
        using var conn2 = new SqliteConnection("Data Source=:memory:");
        conn2.Open();
        var seeder2 = new DatabaseSeeder(conn2, seed: 42);
        seeder2.CreateSchema();
        seeder2.SeedData(userCount: 20, productCount: 15, orderCount: 50);
        var result2 = seeder2.RunVerification();

        Assert.Equal(_result.UserCount, result2.UserCount);
        Assert.Equal(_result.ProductCount, result2.ProductCount);
        Assert.Equal(_result.OrderCount, result2.OrderCount);
        Assert.Equal(_result.TotalRevenue, result2.TotalRevenue);
        Assert.Equal(_result.AverageOrderValue, result2.AverageOrderValue);
        Assert.Equal(_result.InconsistentPriceCount, result2.InconsistentPriceCount);
    }
}
