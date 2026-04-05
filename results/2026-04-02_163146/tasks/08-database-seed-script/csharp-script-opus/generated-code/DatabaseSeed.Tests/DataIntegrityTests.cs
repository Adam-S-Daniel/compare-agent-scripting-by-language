// DataIntegrityTests.cs - TDD tests for data insertion with referential integrity.
// Verifies that all foreign key relationships are respected and data is consistent.

using Microsoft.Data.Sqlite;
using Xunit;

namespace DatabaseSeed.Tests;

/// <summary>
/// Tests that verify data insertion respects referential integrity
/// and that all relationships between tables are valid.
/// </summary>
public class DataIntegrityTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DatabaseSeeder _seeder;

    public DataIntegrityTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
        _seeder = new DatabaseSeeder(_connection, seed: 42);
        // Set up schema and seed data for all integrity tests
        _seeder.CreateSchema();
        _seeder.SeedData(userCount: 20, productCount: 15, orderCount: 50);
    }

    public void Dispose()
    {
        _connection.Dispose();
    }

    [Fact]
    public void AllOrders_ReferenceExistingUsers()
    {
        // Assert - no orders reference non-existent users
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = @"
            SELECT COUNT(*) FROM orders
            WHERE user_id NOT IN (SELECT id FROM users)";
        var orphaned = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, orphaned);
    }

    [Fact]
    public void AllOrders_ReferenceExistingProducts()
    {
        // Assert - no orders reference non-existent products
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = @"
            SELECT COUNT(*) FROM orders
            WHERE product_id NOT IN (SELECT id FROM products)";
        var orphaned = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, orphaned);
    }

    [Fact]
    public void OrderTotalPrice_MatchesQuantityTimesProductPrice()
    {
        // Assert - every order's total_price should equal quantity * product.price
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = @"
            SELECT COUNT(*) FROM orders o
            JOIN products p ON o.product_id = p.id
            WHERE ABS(o.total_price - (o.quantity * p.price)) > 0.01";
        var inconsistent = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, inconsistent);
    }

    [Fact]
    public void AllOrders_HavePositiveQuantity()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM orders WHERE quantity <= 0";
        var invalid = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, invalid);
    }

    [Fact]
    public void AllOrders_HavePositiveTotalPrice()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM orders WHERE total_price <= 0";
        var invalid = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, invalid);
    }

    [Fact]
    public void AllUsers_HaveValidEmailFormat()
    {
        // Simple check: all emails contain @ and end with @example.com
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM users WHERE email NOT LIKE '%@example.com'";
        var invalid = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, invalid);
    }

    [Fact]
    public void AllUsers_HaveNonEmptyNames()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM users WHERE name IS NULL OR name = ''";
        var invalid = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, invalid);
    }

    [Fact]
    public void AllProducts_HaveValidCategories()
    {
        // Categories should be from the known set
        var validCategories = new[] { "Electronics", "Books", "Clothing", "Home & Garden", "Sports" };
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT DISTINCT category FROM products";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            var category = reader.GetString(0);
            Assert.Contains(category, validCategories);
        }
    }

    [Fact]
    public void AllProducts_HaveNonNegativeStock()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM products WHERE stock < 0";
        var invalid = Convert.ToInt32(cmd.ExecuteScalar());
        Assert.Equal(0, invalid);
    }

    [Fact]
    public void InsertedCounts_MatchExpected()
    {
        // Verify the exact counts we requested were inserted
        using var cmd = _connection.CreateCommand();

        cmd.CommandText = "SELECT COUNT(*) FROM users";
        Assert.Equal(20, Convert.ToInt32(cmd.ExecuteScalar()));

        cmd.CommandText = "SELECT COUNT(*) FROM products";
        Assert.Equal(15, Convert.ToInt32(cmd.ExecuteScalar()));

        cmd.CommandText = "SELECT COUNT(*) FROM orders";
        Assert.Equal(50, Convert.ToInt32(cmd.ExecuteScalar()));
    }
}
