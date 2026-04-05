// DataGenerationTests.cs - TDD tests for deterministic data generation.
// Verifies that the seeded RNG produces the same data on every run.

using Microsoft.Data.Sqlite;
using Xunit;

namespace DatabaseSeed.Tests;

/// <summary>
/// Tests that verify deterministic data generation with seeded RNG.
/// Running the same seed should always produce the same output.
/// </summary>
public class DataGenerationTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DatabaseSeeder _seeder;

    public DataGenerationTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
        // Use a known seed for deterministic output
        _seeder = new DatabaseSeeder(_connection, seed: 42);
    }

    public void Dispose()
    {
        _connection.Dispose();
    }

    [Fact]
    public void SeedData_ProducesDeterministicUsers()
    {
        // Arrange
        _seeder.CreateSchema();

        // Act - seed twice with different connections but same seed
        _seeder.SeedData(userCount: 10, productCount: 5, orderCount: 10);

        // Get all user emails from first run
        var emails1 = GetColumnValues("SELECT email FROM users ORDER BY id");

        // Create second seeder with same seed
        using var conn2 = new SqliteConnection("Data Source=:memory:");
        conn2.Open();
        var seeder2 = new DatabaseSeeder(conn2, seed: 42);
        seeder2.CreateSchema();
        seeder2.SeedData(userCount: 10, productCount: 5, orderCount: 10);
        var emails2 = GetColumnValues(conn2, "SELECT email FROM users ORDER BY id");

        // Assert - same seed produces same data
        Assert.Equal(emails1, emails2);
    }

    [Fact]
    public void SeedData_DifferentSeedsProduceDifferentData()
    {
        // Arrange
        _seeder.CreateSchema();
        _seeder.SeedData(userCount: 10, productCount: 5, orderCount: 10);
        var emails1 = GetColumnValues("SELECT email FROM users ORDER BY id");

        // Act - create seeder with different seed
        using var conn2 = new SqliteConnection("Data Source=:memory:");
        conn2.Open();
        var seeder2 = new DatabaseSeeder(conn2, seed: 99);
        seeder2.CreateSchema();
        seeder2.SeedData(userCount: 10, productCount: 5, orderCount: 10);
        var emails2 = GetColumnValues(conn2, "SELECT email FROM users ORDER BY id");

        // Assert - different seeds produce different data
        Assert.NotEqual(emails1, emails2);
    }

    [Fact]
    public void SeedData_ReturnsCorrectCounts()
    {
        // Arrange
        _seeder.CreateSchema();

        // Act
        var result = _seeder.SeedData(userCount: 15, productCount: 10, orderCount: 30);

        // Assert
        Assert.Equal(15, result.UsersInserted);
        Assert.Equal(10, result.ProductsInserted);
        Assert.Equal(30, result.OrdersInserted);
    }

    [Fact]
    public void SeedData_GeneratesUniqueEmails()
    {
        // Arrange
        _seeder.CreateSchema();

        // Act - generate enough users that name collisions are likely
        _seeder.SeedData(userCount: 20, productCount: 5, orderCount: 10);

        // Assert - all emails are unique
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(DISTINCT email) FROM users";
        var distinctCount = Convert.ToInt32(cmd.ExecuteScalar());

        cmd.CommandText = "SELECT COUNT(*) FROM users";
        var totalCount = Convert.ToInt32(cmd.ExecuteScalar());

        Assert.Equal(totalCount, distinctCount);
    }

    [Fact]
    public void SeedData_GeneratesUniqueProductNames()
    {
        // Arrange
        _seeder.CreateSchema();

        // Act
        _seeder.SeedData(userCount: 5, productCount: 15, orderCount: 10);

        // Assert - all product names are unique
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(DISTINCT name) FROM products";
        var distinctCount = Convert.ToInt32(cmd.ExecuteScalar());

        cmd.CommandText = "SELECT COUNT(*) FROM products";
        var totalCount = Convert.ToInt32(cmd.ExecuteScalar());

        Assert.Equal(totalCount, distinctCount);
    }

    [Fact]
    public void SeedData_ProductPricesArePositive()
    {
        // Arrange
        _seeder.CreateSchema();

        // Act
        _seeder.SeedData(userCount: 5, productCount: 15, orderCount: 10);

        // Assert
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT MIN(price) FROM products";
        var minPrice = Convert.ToDouble(cmd.ExecuteScalar());
        Assert.True(minPrice > 0, $"Minimum price should be positive, got {minPrice}");
    }

    [Fact]
    public void SeedData_RejectsInvalidCounts()
    {
        _seeder.CreateSchema();

        Assert.Throws<ArgumentException>(() => _seeder.SeedData(userCount: 0, productCount: 5, orderCount: 10));
        Assert.Throws<ArgumentException>(() => _seeder.SeedData(userCount: 5, productCount: 0, orderCount: 10));
        Assert.Throws<ArgumentException>(() => _seeder.SeedData(userCount: 5, productCount: 5, orderCount: 0));
    }

    // Helper: query a single column and return values as a list
    private List<string> GetColumnValues(string sql)
    {
        return GetColumnValues(_connection, sql);
    }

    private static List<string> GetColumnValues(SqliteConnection conn, string sql)
    {
        var values = new List<string>();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            values.Add(reader.GetString(0));
        }
        return values;
    }
}
