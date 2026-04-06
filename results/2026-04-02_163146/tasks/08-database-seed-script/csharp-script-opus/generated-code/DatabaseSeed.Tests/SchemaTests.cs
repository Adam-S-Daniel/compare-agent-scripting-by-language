// SchemaTests.cs - TDD RED phase: Tests for database schema creation.
// These tests verify that the schema is created correctly with all expected
// tables, columns, and foreign key relationships.

using Microsoft.Data.Sqlite;
using Xunit;

namespace DatabaseSeed.Tests;

/// <summary>
/// Tests that verify the database schema is created correctly.
/// Each test uses an in-memory SQLite database for isolation.
/// </summary>
public class SchemaTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DatabaseSeeder _seeder;

    public SchemaTests()
    {
        // Each test gets a fresh in-memory database for isolation
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
        _seeder = new DatabaseSeeder(_connection);
    }

    public void Dispose()
    {
        _connection.Dispose();
    }

    [Fact]
    public void CreateSchema_CreatesUsersTable()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - verify users table exists with expected columns
        var columns = GetTableColumns("users");
        Assert.Contains(columns, c => c.Name == "id" && c.Type == "INTEGER");
        Assert.Contains(columns, c => c.Name == "name" && c.Type == "TEXT");
        Assert.Contains(columns, c => c.Name == "email" && c.Type == "TEXT");
        Assert.Contains(columns, c => c.Name == "created_at" && c.Type == "TEXT");
    }

    [Fact]
    public void CreateSchema_CreatesProductsTable()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - verify products table exists with expected columns
        var columns = GetTableColumns("products");
        Assert.Contains(columns, c => c.Name == "id" && c.Type == "INTEGER");
        Assert.Contains(columns, c => c.Name == "name" && c.Type == "TEXT");
        Assert.Contains(columns, c => c.Name == "price" && c.Type == "REAL");
        Assert.Contains(columns, c => c.Name == "category" && c.Type == "TEXT");
        Assert.Contains(columns, c => c.Name == "stock" && c.Type == "INTEGER");
    }

    [Fact]
    public void CreateSchema_CreatesOrdersTable()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - verify orders table exists with expected columns
        var columns = GetTableColumns("orders");
        Assert.Contains(columns, c => c.Name == "id" && c.Type == "INTEGER");
        Assert.Contains(columns, c => c.Name == "user_id" && c.Type == "INTEGER");
        Assert.Contains(columns, c => c.Name == "product_id" && c.Type == "INTEGER");
        Assert.Contains(columns, c => c.Name == "quantity" && c.Type == "INTEGER");
        Assert.Contains(columns, c => c.Name == "total_price" && c.Type == "REAL");
        Assert.Contains(columns, c => c.Name == "order_date" && c.Type == "TEXT");
    }

    [Fact]
    public void CreateSchema_OrdersTable_HasForeignKeyToUsers()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - verify foreign key from orders.user_id -> users.id
        var foreignKeys = GetForeignKeys("orders");
        Assert.Contains(foreignKeys, fk => fk.From == "user_id" && fk.Table == "users" && fk.To == "id");
    }

    [Fact]
    public void CreateSchema_OrdersTable_HasForeignKeyToProducts()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - verify foreign key from orders.product_id -> products.id
        var foreignKeys = GetForeignKeys("orders");
        Assert.Contains(foreignKeys, fk => fk.From == "product_id" && fk.Table == "products" && fk.To == "id");
    }

    [Fact]
    public void CreateSchema_UsersEmail_HasUniqueConstraint()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - inserting duplicate emails should fail
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "INSERT INTO users (name, email, created_at) VALUES ('A', 'dup@test.com', '2024-01-01')";
        cmd.ExecuteNonQuery();

        cmd.CommandText = "INSERT INTO users (name, email, created_at) VALUES ('B', 'dup@test.com', '2024-01-01')";
        Assert.Throws<SqliteException>(() => cmd.ExecuteNonQuery());
    }

    [Fact]
    public void CreateSchema_ForeignKeysAreEnforced()
    {
        // Arrange & Act
        _seeder.CreateSchema();

        // Assert - inserting an order with non-existent user_id should fail
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "INSERT INTO orders (user_id, product_id, quantity, total_price, order_date) VALUES (999, 1, 1, 10.0, '2024-01-01')";
        Assert.Throws<SqliteException>(() => cmd.ExecuteNonQuery());
    }

    // Helper: get column info for a table
    private List<(string Name, string Type)> GetTableColumns(string tableName)
    {
        var columns = new List<(string Name, string Type)>();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = $"PRAGMA table_info({tableName})";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            columns.Add((reader.GetString(1), reader.GetString(2)));
        }
        return columns;
    }

    // Helper: get foreign key info for a table
    private List<(string From, string Table, string To)> GetForeignKeys(string tableName)
    {
        var fks = new List<(string From, string Table, string To)>();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = $"PRAGMA foreign_key_list({tableName})";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            fks.Add((reader.GetString(3), reader.GetString(2), reader.GetString(4)));
        }
        return fks;
    }
}
