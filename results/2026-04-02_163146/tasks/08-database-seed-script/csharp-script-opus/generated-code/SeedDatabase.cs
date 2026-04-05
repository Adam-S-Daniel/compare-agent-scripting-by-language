#!/usr/bin/env dotnet run
// SeedDatabase.cs - Main entry point for the database seed script.
// Creates a SQLite database, seeds it with deterministic mock data,
// and runs verification queries to confirm data consistency.
//
// Usage: dotnet run SeedDatabase.cs
// Or via the console project: dotnet run --project DatabaseSeed.Console

#:package Microsoft.Data.Sqlite@9.0.3

using Microsoft.Data.Sqlite;

// --- Configuration ---
const int Seed = 42;
const int UserCount = 20;
const int ProductCount = 15;
const int OrderCount = 50;
const string DbFile = "seed_database.db";

Console.WriteLine("=== SQLite Database Seed Script ===");
Console.WriteLine($"Seed: {Seed} | Users: {UserCount} | Products: {ProductCount} | Orders: {OrderCount}");
Console.WriteLine();

// Delete existing database file to start fresh
if (File.Exists(DbFile))
{
    File.Delete(DbFile);
    Console.WriteLine($"Removed existing database: {DbFile}");
}

// Create and seed the database
using var connection = new SqliteConnection($"Data Source={DbFile}");
connection.Open();

// Enable foreign keys
using (var pragma = connection.CreateCommand())
{
    pragma.CommandText = "PRAGMA foreign_keys = ON";
    pragma.ExecuteNonQuery();
}

Console.WriteLine("Creating schema...");
CreateSchema(connection);
Console.WriteLine("  Created tables: users, products, orders");

Console.WriteLine("Seeding data...");
var rng = new Random(Seed);
var (users, products, orders) = GenerateAndInsertData(connection, rng, UserCount, ProductCount, OrderCount);
Console.WriteLine($"  Inserted {users} users, {products} products, {orders} orders");

Console.WriteLine();
Console.WriteLine("=== Verification Queries ===");
RunVerification(connection);

Console.WriteLine();
Console.WriteLine($"Database saved to: {Path.GetFullPath(DbFile)}");
Console.WriteLine("Done!");

// --- Schema creation ---
static void CreateSchema(SqliteConnection conn)
{
    using var cmd = conn.CreateCommand();
    cmd.CommandText = @"
        CREATE TABLE IF NOT EXISTS users (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            email       TEXT    NOT NULL UNIQUE,
            created_at  TEXT    NOT NULL
        );
        CREATE TABLE IF NOT EXISTS products (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT    NOT NULL,
            price    REAL    NOT NULL CHECK(price > 0),
            category TEXT    NOT NULL,
            stock    INTEGER NOT NULL CHECK(stock >= 0)
        );
        CREATE TABLE IF NOT EXISTS orders (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL,
            product_id  INTEGER NOT NULL,
            quantity    INTEGER NOT NULL CHECK(quantity > 0),
            total_price REAL    NOT NULL CHECK(total_price > 0),
            order_date  TEXT    NOT NULL,
            FOREIGN KEY (user_id)    REFERENCES users(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        );";
    cmd.ExecuteNonQuery();
}

// --- Data generation and insertion ---
static (int users, int products, int orders) GenerateAndInsertData(
    SqliteConnection conn, Random rng, int userCount, int productCount, int orderCount)
{
    var firstNames = new[] { "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank",
        "Grace", "Henry", "Ivy", "Jack", "Karen", "Leo", "Mia", "Noah",
        "Olivia", "Peter", "Quinn", "Rose", "Sam", "Tina" };
    var lastNames = new[] { "Smith", "Johnson", "Williams", "Brown", "Jones",
        "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Anderson",
        "Taylor", "Thomas", "Jackson", "White", "Harris", "Martin",
        "Thompson", "Moore", "Clark" };
    var categories = new[] { "Electronics", "Books", "Clothing", "Home & Garden", "Sports" };
    var productTemplates = new Dictionary<string, string[]>
    {
        ["Electronics"] = ["Wireless Mouse", "USB-C Hub", "Bluetooth Speaker", "Webcam", "Keyboard", "Monitor Stand", "HDMI Cable", "Power Bank"],
        ["Books"] = ["Design Patterns", "Clean Code", "The Pragmatic Programmer", "Refactoring", "Domain-Driven Design", "Algorithms", "Code Complete", "Mythical Man-Month"],
        ["Clothing"] = ["Cotton T-Shirt", "Denim Jacket", "Running Shoes", "Wool Sweater", "Baseball Cap", "Cargo Pants", "Hiking Boots", "Rain Jacket"],
        ["Home & Garden"] = ["Plant Pot", "LED Lamp", "Throw Pillow", "Wall Clock", "Door Mat", "Picture Frame", "Candle Set", "Bookshelf"],
        ["Sports"] = ["Yoga Mat", "Resistance Bands", "Jump Rope", "Water Bottle", "Tennis Ball Set", "Dumbbells", "Running Armband", "Gym Bag"]
    };

    // Generate and insert users
    var usedEmails = new HashSet<string>();
    using (var tx = conn.BeginTransaction())
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = "INSERT INTO users (name, email, created_at) VALUES ($name, $email, $created_at)";
        var nameP = cmd.Parameters.Add("$name", SqliteType.Text);
        var emailP = cmd.Parameters.Add("$email", SqliteType.Text);
        var dateP = cmd.Parameters.Add("$created_at", SqliteType.Text);

        for (int i = 0; i < userCount; i++)
        {
            var first = firstNames[rng.Next(firstNames.Length)];
            var last = lastNames[rng.Next(lastNames.Length)];
            nameP.Value = $"{first} {last}";
            var baseEmail = $"{first.ToLowerInvariant()}.{last.ToLowerInvariant()}";
            var email = $"{baseEmail}@example.com";
            var suffix = 1;
            while (!usedEmails.Add(email)) { email = $"{baseEmail}{suffix}@example.com"; suffix++; }
            emailP.Value = email;
            dateP.Value = new DateTime(2023, 1, 1).AddDays(rng.Next(0, 730)).ToString("yyyy-MM-dd HH:mm:ss");
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    // Generate and insert products
    var productPrices = new List<double>();
    var usedProductNames = new HashSet<string>();
    using (var tx = conn.BeginTransaction())
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = "INSERT INTO products (name, price, category, stock) VALUES ($name, $price, $category, $stock)";
        var nameP = cmd.Parameters.Add("$name", SqliteType.Text);
        var priceP = cmd.Parameters.Add("$price", SqliteType.Real);
        var catP = cmd.Parameters.Add("$category", SqliteType.Text);
        var stockP = cmd.Parameters.Add("$stock", SqliteType.Integer);

        for (int i = 0; i < productCount; i++)
        {
            var cat = categories[rng.Next(categories.Length)];
            catP.Value = cat;
            var baseName = productTemplates[cat][rng.Next(productTemplates[cat].Length)];
            var name = baseName;
            var suf = 2;
            while (!usedProductNames.Add(name)) { name = $"{baseName} v{suf}"; suf++; }
            nameP.Value = name;
            var price = Math.Round(5.0 + rng.NextDouble() * 195.0, 2);
            priceP.Value = price;
            productPrices.Add(price);
            stockP.Value = rng.Next(0, 500);
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    // Generate and insert orders
    using (var tx = conn.BeginTransaction())
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = "INSERT INTO orders (user_id, product_id, quantity, total_price, order_date) VALUES ($uid, $pid, $qty, $total, $date)";
        var uidP = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var pidP = cmd.Parameters.Add("$pid", SqliteType.Integer);
        var qtyP = cmd.Parameters.Add("$qty", SqliteType.Integer);
        var totalP = cmd.Parameters.Add("$total", SqliteType.Real);
        var dateP = cmd.Parameters.Add("$date", SqliteType.Text);

        for (int i = 0; i < orderCount; i++)
        {
            var uid = rng.Next(1, userCount + 1);
            var pid = rng.Next(1, productCount + 1);
            var qty = rng.Next(1, 11);
            uidP.Value = uid;
            pidP.Value = pid;
            qtyP.Value = qty;
            totalP.Value = Math.Round(qty * productPrices[pid - 1], 2);
            dateP.Value = new DateTime(2024, 1, 1).AddDays(rng.Next(0, 366)).ToString("yyyy-MM-dd HH:mm:ss");
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    return (userCount, productCount, orderCount);
}

// --- Verification ---
static void RunVerification(SqliteConnection conn)
{
    int Scalar(string sql) { using var c = conn.CreateCommand(); c.CommandText = sql; return Convert.ToInt32(c.ExecuteScalar()); }
    double ScalarD(string sql) { using var c = conn.CreateCommand(); c.CommandText = sql; return Convert.ToDouble(c.ExecuteScalar()); }

    var userCount = Scalar("SELECT COUNT(*) FROM users");
    var productCount = Scalar("SELECT COUNT(*) FROM products");
    var orderCount = Scalar("SELECT COUNT(*) FROM orders");
    Console.WriteLine($"Record counts: {userCount} users, {productCount} products, {orderCount} orders");

    var orphanUsers = Scalar("SELECT COUNT(*) FROM orders WHERE user_id NOT IN (SELECT id FROM users)");
    var orphanProducts = Scalar("SELECT COUNT(*) FROM orders WHERE product_id NOT IN (SELECT id FROM products)");
    Console.WriteLine($"Orphaned orders (bad user_id): {orphanUsers}");
    Console.WriteLine($"Orphaned orders (bad product_id): {orphanProducts}");

    var inconsistent = Scalar(@"SELECT COUNT(*) FROM orders o JOIN products p ON o.product_id = p.id
        WHERE ABS(o.total_price - (o.quantity * p.price)) > 0.01");
    Console.WriteLine($"Price inconsistencies: {inconsistent}");

    var totalRevenue = ScalarD("SELECT COALESCE(SUM(total_price), 0) FROM orders");
    var avgOrder = ScalarD("SELECT COALESCE(AVG(total_price), 0) FROM orders");
    Console.WriteLine($"Total revenue: ${totalRevenue:F2}");
    Console.WriteLine($"Average order value: ${avgOrder:F2}");

    Console.WriteLine();
    Console.WriteLine("Top 5 users by order count:");
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = @"SELECT u.name, COUNT(o.id) as cnt FROM users u
            JOIN orders o ON u.id = o.user_id GROUP BY u.id ORDER BY cnt DESC LIMIT 5";
        using var r = cmd.ExecuteReader();
        while (r.Read()) Console.WriteLine($"  {r.GetString(0)}: {r.GetInt32(1)} orders");
    }

    Console.WriteLine();
    Console.WriteLine("Revenue by category:");
    using (var cmd = conn.CreateCommand())
    {
        cmd.CommandText = @"SELECT p.category, SUM(o.total_price) as rev FROM orders o
            JOIN products p ON o.product_id = p.id GROUP BY p.category ORDER BY rev DESC";
        using var r = cmd.ExecuteReader();
        while (r.Read()) Console.WriteLine($"  {r.GetString(0)}: ${r.GetDouble(1):F2}");
    }

    // Final integrity check
    if (orphanUsers == 0 && orphanProducts == 0 && inconsistent == 0)
        Console.WriteLine("\n✓ All integrity checks passed!");
    else
        Console.WriteLine("\n✗ Integrity issues detected!");
}
