// TDD Phase: GREEN — minimum implementation to make SchemaTests pass.

using Microsoft.Data.Sqlite;

namespace DatabaseSeeder.Library.Schema;

/// <summary>
/// Creates the SQLite database schema with users, products, orders, and order_items tables.
/// Foreign key relationships:
///   orders.user_id       → users.id
///   order_items.order_id → orders.id
///   order_items.product_id → products.id
/// </summary>
public static class SchemaCreator
{
    /// <summary>
    /// Creates all tables in the database. Uses IF NOT EXISTS for idempotency.
    /// Foreign key enforcement is enabled for the connection.
    /// </summary>
    public static void Create(SqliteConnection connection)
    {
        // SQLite requires PRAGMA foreign_keys per connection
        Execute(connection, "PRAGMA foreign_keys = ON");

        // users — the root entity; no FK dependencies
        Execute(connection, @"
            CREATE TABLE IF NOT EXISTS users (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                username   TEXT NOT NULL UNIQUE,
                email      TEXT NOT NULL UNIQUE,
                first_name TEXT NOT NULL,
                last_name  TEXT NOT NULL,
                created_at TEXT NOT NULL
            )");

        // products — independent; ordered before orders so order_items FK is satisfied
        Execute(connection, @"
            CREATE TABLE IF NOT EXISTS products (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                name           TEXT    NOT NULL,
                description    TEXT,
                price          REAL    NOT NULL CHECK(price > 0),
                stock_quantity INTEGER NOT NULL DEFAULT 0,
                created_at     TEXT    NOT NULL
            )");

        // orders — depends on users
        Execute(connection, @"
            CREATE TABLE IF NOT EXISTS orders (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id      INTEGER NOT NULL,
                status       TEXT    NOT NULL,
                total_amount REAL    NOT NULL,
                created_at   TEXT    NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )");

        // order_items — junction table linking orders ↔ products
        Execute(connection, @"
            CREATE TABLE IF NOT EXISTS order_items (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id   INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                quantity   INTEGER NOT NULL CHECK(quantity > 0),
                unit_price REAL    NOT NULL CHECK(unit_price > 0),
                FOREIGN KEY (order_id)   REFERENCES orders(id),
                FOREIGN KEY (product_id) REFERENCES products(id)
            )");
    }

    private static void Execute(SqliteConnection connection, string sql)
    {
        using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        cmd.ExecuteNonQuery();
    }
}
