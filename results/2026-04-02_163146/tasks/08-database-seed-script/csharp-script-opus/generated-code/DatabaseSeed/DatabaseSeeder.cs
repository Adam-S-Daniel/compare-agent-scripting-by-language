// DatabaseSeeder.cs - Main class for creating and seeding a SQLite database
// with users, products, and orders tables using deterministic randomization.
// Built incrementally using TDD (red/green/refactor).

using Microsoft.Data.Sqlite;

namespace DatabaseSeed;

/// <summary>
/// Creates and seeds a SQLite database with realistic mock data.
/// Uses deterministic (seeded) randomization for reproducible results.
/// </summary>
public class DatabaseSeeder
{
    private readonly SqliteConnection _connection;
    private readonly int _seed;

    /// <summary>
    /// Creates a new DatabaseSeeder using the provided open connection
    /// and an optional RNG seed for deterministic data generation.
    /// </summary>
    public DatabaseSeeder(SqliteConnection connection, int seed = 42)
    {
        _connection = connection ?? throw new ArgumentNullException(nameof(connection));
        _seed = seed;

        // Enable foreign key enforcement (SQLite has them off by default)
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "PRAGMA foreign_keys = ON";
        cmd.ExecuteNonQuery();
    }

    /// <summary>
    /// Creates the database schema: users, products, and orders tables
    /// with appropriate constraints and foreign keys.
    /// </summary>
    public void CreateSchema()
    {
        using var cmd = _connection.CreateCommand();
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
            );
        ";
        cmd.ExecuteNonQuery();
    }

    /// <summary>
    /// Generates and inserts deterministic mock data into the database.
    /// Must be called after CreateSchema().
    /// </summary>
    public SeedResult SeedData(int userCount = 20, int productCount = 15, int orderCount = 50)
    {
        if (userCount <= 0) throw new ArgumentException("Must create at least one user", nameof(userCount));
        if (productCount <= 0) throw new ArgumentException("Must create at least one product", nameof(productCount));
        if (orderCount <= 0) throw new ArgumentException("Must create at least one order", nameof(orderCount));

        var rng = new Random(_seed);

        var users = GenerateUsers(rng, userCount);
        var products = GenerateProducts(rng, productCount);

        InsertUsers(users);
        InsertProducts(products);

        var orders = GenerateOrders(rng, orderCount, userCount, productCount, products);
        InsertOrders(orders);

        return new SeedResult(users.Count, products.Count, orders.Count);
    }

    /// <summary>
    /// Runs verification queries that confirm data consistency and returns results.
    /// </summary>
    public VerificationResult RunVerification()
    {
        var result = new VerificationResult();

        // Count records in each table
        result.UserCount = ExecuteScalarInt("SELECT COUNT(*) FROM users");
        result.ProductCount = ExecuteScalarInt("SELECT COUNT(*) FROM products");
        result.OrderCount = ExecuteScalarInt("SELECT COUNT(*) FROM orders");

        // Verify all orders reference valid users
        result.OrphanedOrdersByUser = ExecuteScalarInt(
            "SELECT COUNT(*) FROM orders WHERE user_id NOT IN (SELECT id FROM users)");

        // Verify all orders reference valid products
        result.OrphanedOrdersByProduct = ExecuteScalarInt(
            "SELECT COUNT(*) FROM orders WHERE product_id NOT IN (SELECT id FROM products)");

        // Total revenue
        result.TotalRevenue = ExecuteScalarDouble(
            "SELECT COALESCE(SUM(total_price), 0) FROM orders");

        // Average order value
        result.AverageOrderValue = ExecuteScalarDouble(
            "SELECT COALESCE(AVG(total_price), 0) FROM orders");

        // Orders per user (top 5)
        result.TopUsersByOrders = QueryTopUsers(5);

        // Revenue by product category
        result.RevenueByCategory = QueryRevenueByCategory();

        // Verify total_price = quantity * product.price for all orders
        result.InconsistentPriceCount = ExecuteScalarInt(@"
            SELECT COUNT(*) FROM orders o
            JOIN products p ON o.product_id = p.id
            WHERE ABS(o.total_price - (o.quantity * p.price)) > 0.01");

        return result;
    }

    // --- Data generation helpers ---

    private List<UserRecord> GenerateUsers(Random rng, int count)
    {
        var firstNames = new[] { "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank",
            "Grace", "Henry", "Ivy", "Jack", "Karen", "Leo", "Mia", "Noah",
            "Olivia", "Peter", "Quinn", "Rose", "Sam", "Tina" };
        var lastNames = new[] { "Smith", "Johnson", "Williams", "Brown", "Jones",
            "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Anderson",
            "Taylor", "Thomas", "Jackson", "White", "Harris", "Martin",
            "Thompson", "Moore", "Clark" };

        var users = new List<UserRecord>();
        var usedEmails = new HashSet<string>();

        for (int i = 0; i < count; i++)
        {
            var first = firstNames[rng.Next(firstNames.Length)];
            var last = lastNames[rng.Next(lastNames.Length)];
            var name = $"{first} {last}";

            // Ensure unique emails by appending a number if needed
            var baseEmail = $"{first.ToLowerInvariant()}.{last.ToLowerInvariant()}";
            var email = $"{baseEmail}@example.com";
            var suffix = 1;
            while (!usedEmails.Add(email))
            {
                email = $"{baseEmail}{suffix}@example.com";
                suffix++;
            }

            // Random date in 2023-2024
            var daysOffset = rng.Next(0, 730);
            var createdAt = new DateTime(2023, 1, 1).AddDays(daysOffset)
                .ToString("yyyy-MM-dd HH:mm:ss");

            users.Add(new UserRecord(name, email, createdAt));
        }

        return users;
    }

    private List<ProductRecord> GenerateProducts(Random rng, int count)
    {
        var categories = new[] { "Electronics", "Books", "Clothing", "Home & Garden", "Sports" };
        var productTemplates = new Dictionary<string, string[]>
        {
            ["Electronics"] = ["Wireless Mouse", "USB-C Hub", "Bluetooth Speaker", "Webcam", "Keyboard", "Monitor Stand", "HDMI Cable", "Power Bank"],
            ["Books"] = ["Design Patterns", "Clean Code", "The Pragmatic Programmer", "Refactoring", "Domain-Driven Design", "Algorithms", "Code Complete", "Mythical Man-Month"],
            ["Clothing"] = ["Cotton T-Shirt", "Denim Jacket", "Running Shoes", "Wool Sweater", "Baseball Cap", "Cargo Pants", "Hiking Boots", "Rain Jacket"],
            ["Home & Garden"] = ["Plant Pot", "LED Lamp", "Throw Pillow", "Wall Clock", "Door Mat", "Picture Frame", "Candle Set", "Bookshelf"],
            ["Sports"] = ["Yoga Mat", "Resistance Bands", "Jump Rope", "Water Bottle", "Tennis Ball Set", "Dumbbells", "Running Armband", "Gym Bag"]
        };

        var products = new List<ProductRecord>();
        var usedNames = new HashSet<string>();

        for (int i = 0; i < count; i++)
        {
            var category = categories[rng.Next(categories.Length)];
            var templates = productTemplates[category];
            var baseName = templates[rng.Next(templates.Length)];

            // Ensure unique product names
            var name = baseName;
            var suffix = 2;
            while (!usedNames.Add(name))
            {
                name = $"{baseName} v{suffix}";
                suffix++;
            }

            // Price between $5 and $200, rounded to 2 decimal places
            var price = Math.Round(5.0 + rng.NextDouble() * 195.0, 2);
            var stock = rng.Next(0, 500);

            products.Add(new ProductRecord(name, price, category, stock));
        }

        return products;
    }

    private List<OrderRecord> GenerateOrders(Random rng, int count,
        int userCount, int productCount, List<ProductRecord> products)
    {
        var orders = new List<OrderRecord>();

        for (int i = 0; i < count; i++)
        {
            // User and product IDs are 1-based (AUTOINCREMENT)
            var userId = rng.Next(1, userCount + 1);
            var productId = rng.Next(1, productCount + 1);
            var quantity = rng.Next(1, 11); // 1-10 items

            // Calculate total_price consistently: quantity * product price
            var productPrice = products[productId - 1].Price;
            var totalPrice = Math.Round(quantity * productPrice, 2);

            // Random date in 2024
            var daysOffset = rng.Next(0, 366);
            var orderDate = new DateTime(2024, 1, 1).AddDays(daysOffset)
                .ToString("yyyy-MM-dd HH:mm:ss");

            orders.Add(new OrderRecord(userId, productId, quantity, totalPrice, orderDate));
        }

        return orders;
    }

    // --- Insertion helpers ---

    private void InsertUsers(List<UserRecord> users)
    {
        using var transaction = _connection.BeginTransaction();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "INSERT INTO users (name, email, created_at) VALUES ($name, $email, $created_at)";

        var nameParam = cmd.Parameters.Add("$name", SqliteType.Text);
        var emailParam = cmd.Parameters.Add("$email", SqliteType.Text);
        var createdAtParam = cmd.Parameters.Add("$created_at", SqliteType.Text);

        foreach (var user in users)
        {
            nameParam.Value = user.Name;
            emailParam.Value = user.Email;
            createdAtParam.Value = user.CreatedAt;
            cmd.ExecuteNonQuery();
        }

        transaction.Commit();
    }

    private void InsertProducts(List<ProductRecord> products)
    {
        using var transaction = _connection.BeginTransaction();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "INSERT INTO products (name, price, category, stock) VALUES ($name, $price, $category, $stock)";

        var nameParam = cmd.Parameters.Add("$name", SqliteType.Text);
        var priceParam = cmd.Parameters.Add("$price", SqliteType.Real);
        var categoryParam = cmd.Parameters.Add("$category", SqliteType.Text);
        var stockParam = cmd.Parameters.Add("$stock", SqliteType.Integer);

        foreach (var product in products)
        {
            nameParam.Value = product.Name;
            priceParam.Value = product.Price;
            categoryParam.Value = product.Category;
            stockParam.Value = product.Stock;
            cmd.ExecuteNonQuery();
        }

        transaction.Commit();
    }

    private void InsertOrders(List<OrderRecord> orders)
    {
        using var transaction = _connection.BeginTransaction();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = @"INSERT INTO orders (user_id, product_id, quantity, total_price, order_date)
                            VALUES ($user_id, $product_id, $quantity, $total_price, $order_date)";

        var userIdParam = cmd.Parameters.Add("$user_id", SqliteType.Integer);
        var productIdParam = cmd.Parameters.Add("$product_id", SqliteType.Integer);
        var quantityParam = cmd.Parameters.Add("$quantity", SqliteType.Integer);
        var totalPriceParam = cmd.Parameters.Add("$total_price", SqliteType.Real);
        var orderDateParam = cmd.Parameters.Add("$order_date", SqliteType.Text);

        foreach (var order in orders)
        {
            userIdParam.Value = order.UserId;
            productIdParam.Value = order.ProductId;
            quantityParam.Value = order.Quantity;
            totalPriceParam.Value = order.TotalPrice;
            orderDateParam.Value = order.OrderDate;
            cmd.ExecuteNonQuery();
        }

        transaction.Commit();
    }

    // --- Query helpers ---

    private int ExecuteScalarInt(string sql)
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = sql;
        return Convert.ToInt32(cmd.ExecuteScalar());
    }

    private double ExecuteScalarDouble(string sql)
    {
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = sql;
        return Convert.ToDouble(cmd.ExecuteScalar());
    }

    private List<(string UserName, int OrderCount)> QueryTopUsers(int limit)
    {
        var results = new List<(string, int)>();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = $@"
            SELECT u.name, COUNT(o.id) as order_count
            FROM users u
            JOIN orders o ON u.id = o.user_id
            GROUP BY u.id
            ORDER BY order_count DESC
            LIMIT {limit}";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            results.Add((reader.GetString(0), reader.GetInt32(1)));
        }
        return results;
    }

    private Dictionary<string, double> QueryRevenueByCategory()
    {
        var results = new Dictionary<string, double>();
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = @"
            SELECT p.category, SUM(o.total_price) as revenue
            FROM orders o
            JOIN products p ON o.product_id = p.id
            GROUP BY p.category
            ORDER BY revenue DESC";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            results[reader.GetString(0)] = reader.GetDouble(1);
        }
        return results;
    }
}

// --- Record types for data transfer ---

public record UserRecord(string Name, string Email, string CreatedAt);
public record ProductRecord(string Name, double Price, string Category, int Stock);
public record OrderRecord(int UserId, int ProductId, int Quantity, double TotalPrice, string OrderDate);
public record SeedResult(int UsersInserted, int ProductsInserted, int OrdersInserted);

/// <summary>
/// Contains the results of verification queries that confirm data consistency.
/// </summary>
public class VerificationResult
{
    public int UserCount { get; set; }
    public int ProductCount { get; set; }
    public int OrderCount { get; set; }
    public int OrphanedOrdersByUser { get; set; }
    public int OrphanedOrdersByProduct { get; set; }
    public double TotalRevenue { get; set; }
    public double AverageOrderValue { get; set; }
    public List<(string UserName, int OrderCount)> TopUsersByOrders { get; set; } = [];
    public Dictionary<string, double> RevenueByCategory { get; set; } = [];
    public int InconsistentPriceCount { get; set; }
}
