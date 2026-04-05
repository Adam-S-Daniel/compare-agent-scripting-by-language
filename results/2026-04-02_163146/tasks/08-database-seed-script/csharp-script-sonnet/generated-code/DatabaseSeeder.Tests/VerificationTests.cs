// TDD Phase: RED — tests for data consistency verification queries.
// Verifier runs assertions against the database to confirm data integrity.

using Xunit;
using Microsoft.Data.Sqlite;
using DatabaseSeeder.Library.Schema;
using DatabaseSeeder.Library.Data;
using DatabaseSeeder.Library.Verification;

namespace DatabaseSeeder.Tests;

/// <summary>
/// Tests for verification queries that confirm data consistency after seeding.
/// </summary>
public class VerificationTests : IDisposable
{
    private readonly SqliteConnection _connection;

    public VerificationTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
        SchemaCreator.Create(_connection);
        SeedTestData();
    }

    public void Dispose()
    {
        _connection.Close();
        _connection.Dispose();
    }

    /// <summary>Seeds a consistent dataset for verification testing.</summary>
    private void SeedTestData()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(10);
        var products = generator.GenerateProducts(20);
        var orders = generator.GenerateOrders(count: 30, userCount: 10);
        var items = generator.GenerateOrderItems(orderCount: 30, productCount: 20);

        DataInserter.InsertUsers(_connection, users);
        DataInserter.InsertProducts(_connection, products);
        DataInserter.InsertOrders(_connection, orders);
        DataInserter.InsertOrderItems(_connection, items);
    }

    [Fact]
    public void Verify_TableCountsAreCorrect()
    {
        var result = DatabaseVerifier.VerifyTableCounts(_connection, expectedUsers: 10, expectedProducts: 20, expectedOrders: 30);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_NoOrphanOrders()
    {
        // Every order must reference a valid user
        var result = DatabaseVerifier.VerifyNoOrphanOrders(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_NoOrphanOrderItems()
    {
        // Every order_item must reference a valid order and a valid product
        var result = DatabaseVerifier.VerifyNoOrphanOrderItems(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_AllOrdersHaveAtLeastOneItem()
    {
        var result = DatabaseVerifier.VerifyAllOrdersHaveItems(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_EmailsAreUnique()
    {
        var result = DatabaseVerifier.VerifyUniqueEmails(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_UsernamesAreUnique()
    {
        var result = DatabaseVerifier.VerifyUniqueUsernames(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_ProductPricesArePositive()
    {
        var result = DatabaseVerifier.VerifyPositiveProductPrices(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_OrderItemQuantitiesArePositive()
    {
        var result = DatabaseVerifier.VerifyPositiveQuantities(_connection);
        Assert.True(result.IsValid, result.Message);
    }

    [Fact]
    public void Verify_FullCheck_AllPassAfterSeeding()
    {
        // Running all checks together should all pass
        var results = DatabaseVerifier.VerifyAll(_connection);
        var failures = results.Where(r => !r.IsValid).ToList();
        Assert.Empty(failures);
    }

    [Fact]
    public void Verify_QueryStatistics_ReturnsExpectedCounts()
    {
        // Query the database for summary statistics
        var stats = DatabaseVerifier.GetStatistics(_connection);
        Assert.Equal(10, stats.UserCount);
        Assert.Equal(20, stats.ProductCount);
        Assert.Equal(30, stats.OrderCount);
        Assert.True(stats.OrderItemCount >= 30);
    }

    [Fact]
    public void Verify_OrphanDetection_DetectsInvalidData()
    {
        // Temporarily disable FK enforcement to insert an orphan order (user_id 9999 doesn't exist).
        // FK enforcement was enabled by SchemaCreator, so we must disable it for this deliberate bad insert.
        DisableForeignKeys();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "INSERT INTO orders (user_id, status, total_amount, created_at) VALUES (9999, 'pending', 99.99, '2024-01-01')";
        cmd.ExecuteNonQuery();
        EnableForeignKeys(); // restore

        var result = DatabaseVerifier.VerifyNoOrphanOrders(_connection);
        Assert.False(result.IsValid, "Should detect orphan order referencing non-existent user");
    }

    private void DisableForeignKeys()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "PRAGMA foreign_keys = OFF";
        cmd.ExecuteNonQuery();
    }

    private void EnableForeignKeys()
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "PRAGMA foreign_keys = ON";
        cmd.ExecuteNonQuery();
    }
}
