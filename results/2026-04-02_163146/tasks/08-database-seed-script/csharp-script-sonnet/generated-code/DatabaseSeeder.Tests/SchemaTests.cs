// TDD Phase: RED — these tests are written FIRST, before any implementation exists.
// They verify that SchemaCreator correctly creates the expected database schema.

using Xunit;
using Microsoft.Data.Sqlite;
using DatabaseSeeder.Library.Schema;

namespace DatabaseSeeder.Tests;

/// <summary>
/// Tests for schema creation: verifies that all required tables, columns,
/// and foreign key relationships are created correctly.
/// </summary>
public class SchemaTests : IDisposable
{
    private readonly SqliteConnection _connection;

    public SchemaTests()
    {
        // Use in-memory SQLite for fast, isolated tests
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();
    }

    public void Dispose()
    {
        _connection.Close();
        _connection.Dispose();
    }

    [Fact]
    public void CreateSchema_ShouldCreateUsersTable()
    {
        SchemaCreator.Create(_connection);
        Assert.Contains("users", GetTableNames(_connection));
    }

    [Fact]
    public void CreateSchema_ShouldCreateProductsTable()
    {
        SchemaCreator.Create(_connection);
        Assert.Contains("products", GetTableNames(_connection));
    }

    [Fact]
    public void CreateSchema_ShouldCreateOrdersTable()
    {
        SchemaCreator.Create(_connection);
        Assert.Contains("orders", GetTableNames(_connection));
    }

    [Fact]
    public void CreateSchema_ShouldCreateOrderItemsTable()
    {
        SchemaCreator.Create(_connection);
        Assert.Contains("order_items", GetTableNames(_connection));
    }

    [Fact]
    public void CreateSchema_UsersTable_ShouldHaveRequiredColumns()
    {
        SchemaCreator.Create(_connection);
        var columns = GetColumnNames(_connection, "users");
        Assert.Contains("id", columns);
        Assert.Contains("username", columns);
        Assert.Contains("email", columns);
        Assert.Contains("first_name", columns);
        Assert.Contains("last_name", columns);
        Assert.Contains("created_at", columns);
    }

    [Fact]
    public void CreateSchema_ProductsTable_ShouldHaveRequiredColumns()
    {
        SchemaCreator.Create(_connection);
        var columns = GetColumnNames(_connection, "products");
        Assert.Contains("id", columns);
        Assert.Contains("name", columns);
        Assert.Contains("description", columns);
        Assert.Contains("price", columns);
        Assert.Contains("stock_quantity", columns);
        Assert.Contains("created_at", columns);
    }

    [Fact]
    public void CreateSchema_OrdersTable_ShouldHaveRequiredColumns()
    {
        SchemaCreator.Create(_connection);
        var columns = GetColumnNames(_connection, "orders");
        Assert.Contains("id", columns);
        Assert.Contains("user_id", columns);
        Assert.Contains("status", columns);
        Assert.Contains("total_amount", columns);
        Assert.Contains("created_at", columns);
    }

    [Fact]
    public void CreateSchema_OrderItemsTable_ShouldHaveRequiredColumns()
    {
        SchemaCreator.Create(_connection);
        var columns = GetColumnNames(_connection, "order_items");
        Assert.Contains("id", columns);
        Assert.Contains("order_id", columns);
        Assert.Contains("product_id", columns);
        Assert.Contains("quantity", columns);
        Assert.Contains("unit_price", columns);
    }

    [Fact]
    public void CreateSchema_OrdersTable_ShouldHaveForeignKeyToUsers()
    {
        SchemaCreator.Create(_connection);
        var foreignKeys = GetForeignKeys(_connection, "orders");
        Assert.True(
            foreignKeys.Any(fk => fk.ReferencedTable == "users" && fk.FromColumn == "user_id"),
            "orders.user_id should reference users table"
        );
    }

    [Fact]
    public void CreateSchema_OrderItemsTable_ShouldHaveForeignKeyToOrders()
    {
        SchemaCreator.Create(_connection);
        var foreignKeys = GetForeignKeys(_connection, "order_items");
        Assert.True(
            foreignKeys.Any(fk => fk.ReferencedTable == "orders" && fk.FromColumn == "order_id"),
            "order_items.order_id should reference orders table"
        );
    }

    [Fact]
    public void CreateSchema_OrderItemsTable_ShouldHaveForeignKeyToProducts()
    {
        SchemaCreator.Create(_connection);
        var foreignKeys = GetForeignKeys(_connection, "order_items");
        Assert.True(
            foreignKeys.Any(fk => fk.ReferencedTable == "products" && fk.FromColumn == "product_id"),
            "order_items.product_id should reference products table"
        );
    }

    [Fact]
    public void CreateSchema_ShouldBeIdempotent()
    {
        // Creating the schema twice should not throw an error
        SchemaCreator.Create(_connection);
        SchemaCreator.Create(_connection); // Should not throw
        Assert.Contains("users", GetTableNames(_connection));
    }

    // ── Helper methods ──────────────────────────────────────────────────────

    private static List<string> GetTableNames(SqliteConnection conn)
    {
        var tables = new List<string>();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";
        using var reader = cmd.ExecuteReader();
        while (reader.Read()) tables.Add(reader.GetString(0));
        return tables;
    }

    private static List<string> GetColumnNames(SqliteConnection conn, string tableName)
    {
        var columns = new List<string>();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"PRAGMA table_info({tableName})";
        using var reader = cmd.ExecuteReader();
        while (reader.Read()) columns.Add(reader.GetString(1)); // index 1 = column name
        return columns;
    }

    private record ForeignKey(string FromColumn, string ReferencedTable, string ReferencedColumn);

    private static List<ForeignKey> GetForeignKeys(SqliteConnection conn, string tableName)
    {
        var fks = new List<ForeignKey>();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"PRAGMA foreign_key_list({tableName})";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            fks.Add(new ForeignKey(
                reader.GetString(3),  // from column
                reader.GetString(2),  // referenced table
                reader.GetString(4)   // referenced column
            ));
        }
        return fks;
    }
}
