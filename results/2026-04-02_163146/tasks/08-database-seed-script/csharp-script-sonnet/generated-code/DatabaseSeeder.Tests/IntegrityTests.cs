// TDD Phase: RED — tests for referential integrity during data insertion.
// Verifies that data is inserted in the correct order and FK constraints are respected.

using Xunit;
using Microsoft.Data.Sqlite;
using DatabaseSeeder.Library.Schema;
using DatabaseSeeder.Library.Data;

namespace DatabaseSeeder.Tests;

/// <summary>
/// Tests for data insertion respecting referential integrity.
/// All inserts must succeed without FK violations.
/// </summary>
public class IntegrityTests : IDisposable
{
    private readonly SqliteConnection _connection;

    public IntegrityTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
        // Create schema before each test
        SchemaCreator.Create(_connection);
    }

    public void Dispose()
    {
        _connection.Close();
        _connection.Dispose();
    }

    [Fact]
    public void InsertUsers_ShouldInsertCorrectCount()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(10);
        var ids = DataInserter.InsertUsers(_connection, users);

        Assert.Equal(10, ids.Count);
        Assert.Equal(10, CountRows(_connection, "users"));
    }

    [Fact]
    public void InsertUsers_ShouldReturnSequentialIds()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(5);
        var ids = DataInserter.InsertUsers(_connection, users);

        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, ids);
    }

    [Fact]
    public void InsertProducts_ShouldInsertCorrectCount()
    {
        var generator = new DataGenerator(seed: 42);
        var products = generator.GenerateProducts(15);
        var ids = DataInserter.InsertProducts(_connection, products);

        Assert.Equal(15, ids.Count);
        Assert.Equal(15, CountRows(_connection, "products"));
    }

    [Fact]
    public void InsertOrders_ShouldInsertCorrectCount()
    {
        // First insert users so FKs are satisfied
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(5);
        DataInserter.InsertUsers(_connection, users);

        var orders = generator.GenerateOrders(count: 20, userCount: 5);
        var ids = DataInserter.InsertOrders(_connection, orders);

        Assert.Equal(20, ids.Count);
        Assert.Equal(20, CountRows(_connection, "orders"));
    }

    [Fact]
    public void InsertOrders_WithForeignKeysEnabled_ShouldRespectReferentialIntegrity()
    {
        // Enable foreign key enforcement
        ExecuteNonQuery(_connection, "PRAGMA foreign_keys = ON");

        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(5);
        DataInserter.InsertUsers(_connection, users);

        // Orders referencing valid user IDs should succeed
        var orders = generator.GenerateOrders(count: 10, userCount: 5);
        var ids = DataInserter.InsertOrders(_connection, orders);
        Assert.Equal(10, ids.Count);
    }

    [Fact]
    public void InsertOrderItems_ShouldInsertCorrectCount()
    {
        var generator = new DataGenerator(seed: 42);

        // Insert users, products, and orders first
        DataInserter.InsertUsers(_connection, generator.GenerateUsers(5));
        DataInserter.InsertProducts(_connection, generator.GenerateProducts(10));
        DataInserter.InsertOrders(_connection, generator.GenerateOrders(count: 8, userCount: 5));

        var items = generator.GenerateOrderItems(orderCount: 8, productCount: 10);
        var ids = DataInserter.InsertOrderItems(_connection, items);

        Assert.True(ids.Count > 0);
        Assert.Equal(ids.Count, CountRows(_connection, "order_items"));
    }

    [Fact]
    public void InsertAll_FullPipeline_ShouldSucceed()
    {
        // Full seeding pipeline: users → products → orders → order_items
        var generator = new DataGenerator(seed: 42);

        var users = generator.GenerateUsers(10);
        var products = generator.GenerateProducts(20);
        var orders = generator.GenerateOrders(count: 30, userCount: 10);
        var items = generator.GenerateOrderItems(orderCount: 30, productCount: 20);

        DataInserter.InsertUsers(_connection, users);
        DataInserter.InsertProducts(_connection, products);
        DataInserter.InsertOrders(_connection, orders);
        DataInserter.InsertOrderItems(_connection, items);

        Assert.Equal(10, CountRows(_connection, "users"));
        Assert.Equal(20, CountRows(_connection, "products"));
        Assert.Equal(30, CountRows(_connection, "orders"));
        Assert.True(CountRows(_connection, "order_items") >= 30); // at least 1 item per order
    }

    [Fact]
    public void InsertUsers_ShouldPreserveData()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(3);
        DataInserter.InsertUsers(_connection, users);

        // Verify the first user's data is stored correctly
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT username, email, first_name, last_name FROM users WHERE id = 1";
        using var reader = cmd.ExecuteReader();
        Assert.True(reader.Read());
        Assert.Equal(users[0].Username, reader.GetString(0));
        Assert.Equal(users[0].Email, reader.GetString(1));
        Assert.Equal(users[0].FirstName, reader.GetString(2));
        Assert.Equal(users[0].LastName, reader.GetString(3));
    }

    [Fact]
    public void InsertProducts_ShouldPreserveData()
    {
        var generator = new DataGenerator(seed: 42);
        var products = generator.GenerateProducts(3);
        DataInserter.InsertProducts(_connection, products);

        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "SELECT name, price, stock_quantity FROM products WHERE id = 1";
        using var reader = cmd.ExecuteReader();
        Assert.True(reader.Read());
        Assert.Equal(products[0].Name, reader.GetString(0));
        Assert.Equal((double)products[0].Price, reader.GetDouble(1), precision: 2);
        Assert.Equal(products[0].StockQuantity, reader.GetInt32(2));
    }

    // ── Helper methods ──────────────────────────────────────────────────────

    private static int CountRows(SqliteConnection conn, string tableName)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"SELECT COUNT(*) FROM {tableName}";
        return Convert.ToInt32(cmd.ExecuteScalar());
    }

    private static void ExecuteNonQuery(SqliteConnection conn, string sql)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.ExecuteNonQuery();
    }
}
