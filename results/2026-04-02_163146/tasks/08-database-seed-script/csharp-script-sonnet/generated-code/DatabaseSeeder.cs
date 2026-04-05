// DatabaseSeeder.cs — .NET 10 file-based app (top-level statements)
// Run with: dotnet run   (from this directory, uses DatabaseSeeder.csproj)
//       or: dotnet run DatabaseSeeder.cs   (if SDK supports direct file execution)
//
// This standalone script:
//   1. Creates a SQLite database with users, products, orders, order_items tables
//   2. Generates realistic mock data using a seeded RNG (default seed=42)
//   3. Inserts data respecting referential integrity (users→products→orders→items)
//   4. Runs verification queries to confirm data consistency
//
// Package: Microsoft.Data.Sqlite (provided by DatabaseSeeder.csproj)

using Microsoft.Data.Sqlite;

// ── Configuration ──────────────────────────────────────────────────────────

int seed        = args.Length > 0 && int.TryParse(args[0], out int s) ? s : 42;
string dbPath   = args.Length > 1 ? args[1] : "seed.db";
int userCount   = 10;
int productCount = 20;
int orderCount  = 30;

Console.WriteLine($"=== Database Seeder ===");
Console.WriteLine($"Database : {dbPath}");
Console.WriteLine($"RNG seed : {seed}");
Console.WriteLine();

// ── Database connection ────────────────────────────────────────────────────

using var conn = new SqliteConnection($"Data Source={dbPath}");
conn.Open();

// Enable foreign key enforcement for this connection
Execute(conn, "PRAGMA foreign_keys = ON");

// ── Step 1: Create schema ──────────────────────────────────────────────────

Console.WriteLine("→ Creating schema...");
CreateSchema(conn);
Console.WriteLine("  users, products, orders, order_items tables created.");

// ── Step 2: Generate data ──────────────────────────────────────────────────

Console.WriteLine($"→ Generating data (seed={seed})...");
var rng      = new Random(seed);
var users    = GenerateUsers(rng, userCount);
var products = GenerateProducts(rng, productCount);
var orders   = GenerateOrders(rng, orderCount, userCount);
var items    = GenerateOrderItems(rng, orderCount, productCount);
Console.WriteLine($"  {users.Count} users, {products.Count} products, {orders.Count} orders, {items.Count} order items generated.");

// ── Step 3: Insert data ────────────────────────────────────────────────────

Console.WriteLine("→ Inserting data...");
InsertUsers(conn, users);
InsertProducts(conn, products);
InsertOrders(conn, orders);
InsertOrderItems(conn, items);
Console.WriteLine("  All data inserted successfully.");

// ── Step 4: Run verification queries ──────────────────────────────────────

Console.WriteLine("→ Running verification queries...");
var allPassed = true;

allPassed &= Check(conn, "Table counts",
    () => CountRows(conn, "users") == userCount &&
          CountRows(conn, "products") == productCount &&
          CountRows(conn, "orders") == orderCount,
    $"users={userCount}, products={productCount}, orders={orderCount}");

allPassed &= Check(conn, "No orphan orders",
    () => ExecuteScalarInt(conn, @"
        SELECT COUNT(*) FROM orders o
        LEFT JOIN users u ON o.user_id = u.id
        WHERE u.id IS NULL") == 0,
    "Every order references a valid user");

allPassed &= Check(conn, "No orphan order items (order FK)",
    () => ExecuteScalarInt(conn, @"
        SELECT COUNT(*) FROM order_items oi
        LEFT JOIN orders o ON oi.order_id = o.id
        WHERE o.id IS NULL") == 0,
    "Every item references a valid order");

allPassed &= Check(conn, "No orphan order items (product FK)",
    () => ExecuteScalarInt(conn, @"
        SELECT COUNT(*) FROM order_items oi
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE p.id IS NULL") == 0,
    "Every item references a valid product");

allPassed &= Check(conn, "All orders have items",
    () => ExecuteScalarInt(conn, @"
        SELECT COUNT(*) FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        WHERE oi.id IS NULL") == 0,
    "No orders are empty");

allPassed &= Check(conn, "Unique user emails",
    () => ExecuteScalarInt(conn, "SELECT COUNT(*) - COUNT(DISTINCT email) FROM users") == 0,
    "All emails are unique");

allPassed &= Check(conn, "Positive product prices",
    () => ExecuteScalarInt(conn, "SELECT COUNT(*) FROM products WHERE price <= 0") == 0,
    "All prices > 0");

allPassed &= Check(conn, "Positive item quantities",
    () => ExecuteScalarInt(conn, "SELECT COUNT(*) FROM order_items WHERE quantity <= 0") == 0,
    "All quantities > 0");

Console.WriteLine();

// ── Summary ────────────────────────────────────────────────────────────────

if (allPassed)
{
    Console.WriteLine("✓ All verification checks passed. Database is consistent.");
    Console.WriteLine($"  Total order items: {CountRows(conn, "order_items")}");

    // Print a sample of the data
    Console.WriteLine();
    Console.WriteLine("Sample users:");
    PrintQuery(conn, "SELECT id, username, email FROM users LIMIT 3");

    Console.WriteLine();
    Console.WriteLine("Sample products:");
    PrintQuery(conn, "SELECT id, name, price, stock_quantity FROM products LIMIT 3");

    Console.WriteLine();
    Console.WriteLine("Order status distribution:");
    PrintQuery(conn, "SELECT status, COUNT(*) as count FROM orders GROUP BY status ORDER BY count DESC");
}
else
{
    Console.Error.WriteLine("✗ One or more verification checks FAILED. See above.");
    Environment.Exit(1);
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper functions (all logic is self-contained in this file-based app)
// ═══════════════════════════════════════════════════════════════════════════

void CreateSchema(SqliteConnection c)
{
    Execute(c, @"CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        created_at TEXT NOT NULL)");

    Execute(c, @"CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL CHECK(price > 0),
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL)");

    Execute(c, @"CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        total_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id))");

    Execute(c, @"CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL CHECK(unit_price > 0),
        FOREIGN KEY (order_id) REFERENCES orders(id),
        FOREIGN KEY (product_id) REFERENCES products(id))");
}

// ── Data generation ────────────────────────────────────────────────────────

record UserRow(string Username, string Email, string FirstName, string LastName, string CreatedAt);
record ProductRow(string Name, string Description, decimal Price, int Stock, string CreatedAt);
record OrderRow(int UserId, string Status, decimal Total, string CreatedAt);
record ItemRow(int OrderId, int ProductId, int Qty, decimal UnitPrice);

string[] _firstNames = { "Alice","Bob","Charlie","Diana","Eve","Frank","Grace","Henry","Iris","Jack","Karen","Leo","Mia","Nathan","Olivia" };
string[] _lastNames  = { "Smith","Jones","Brown","Davis","Miller","Wilson","Moore","Taylor","Anderson","Thomas","Jackson","White","Harris","Martin","Garcia" };
string[] _adjectives = { "Premium","Budget","Professional","Compact","Wireless","Portable","Ergonomic","Ultra-thin","Gaming","Smart" };
string[] _nouns      = { "Laptop","Phone","Tablet","Headphones","Camera","Watch","Keyboard","Mouse","Monitor","Speaker","Charger","Router","Webcam" };
string[] _statuses   = { "pending","processing","shipped","delivered","cancelled" };

List<UserRow> GenerateUsers(Random r, int count)
{
    var list = new List<UserRow>(count);
    var seen = new HashSet<string>();
    for (int i = 0; i < count; i++)
    {
        string first, last, uname;
        do
        {
            first = _firstNames[r.Next(_firstNames.Length)];
            last  = _lastNames[r.Next(_lastNames.Length)];
            uname = $"{first.ToLower()}.{last.ToLower()}{r.Next(1000)}";
        } while (seen.Contains(uname));
        seen.Add(uname);
        list.Add(new UserRow(uname, $"{uname}@example.com", first, last, PastDate(r, 730)));
    }
    return list;
}

List<ProductRow> GenerateProducts(Random r, int count)
{
    var list = new List<ProductRow>(count);
    for (int i = 0; i < count; i++)
    {
        string name = $"{_adjectives[r.Next(_adjectives.Length)]} {_nouns[r.Next(_nouns.Length)]}";
        decimal price = Math.Round((decimal)(r.NextDouble() * 994.99 + 5), 2);
        list.Add(new ProductRow(name, $"A {name.ToLower()} for everyday use.", price, r.Next(0, 200), PastDate(r, 365)));
    }
    return list;
}

List<OrderRow> GenerateOrders(Random r, int count, int numUsers)
{
    var list = new List<OrderRow>(count);
    for (int i = 0; i < count; i++)
    {
        list.Add(new OrderRow(
            UserId: r.Next(1, numUsers + 1),
            Status: _statuses[r.Next(_statuses.Length)],
            Total: Math.Round((decimal)(r.NextDouble() * 490 + 10), 2),
            CreatedAt: PastDate(r, 180)));
    }
    return list;
}

List<ItemRow> GenerateOrderItems(Random r, int numOrders, int numProducts)
{
    var list = new List<ItemRow>();
    int maxPerOrder = Math.Min(5, numProducts);
    for (int oid = 1; oid <= numOrders; oid++)
    {
        int cnt = r.Next(1, maxPerOrder + 1);
        var used = new HashSet<int>();
        for (int j = 0; j < cnt; j++)
        {
            int pid;
            do { pid = r.Next(1, numProducts + 1); } while (used.Contains(pid));
            used.Add(pid);
            list.Add(new ItemRow(oid, pid, r.Next(1, 10), Math.Round((decimal)(r.NextDouble() * 495 + 5), 2)));
        }
    }
    return list;
}

string PastDate(Random r, int maxDays) =>
    DateTime.UtcNow.AddDays(-r.Next(1, maxDays + 1)).ToString("yyyy-MM-dd HH:mm:ss");

// ── Insertion ──────────────────────────────────────────────────────────────

void InsertUsers(SqliteConnection c, List<UserRow> rows)
{
    using var tx = c.BeginTransaction();
    using var cmd = c.CreateCommand();
    cmd.Transaction = tx;
    cmd.CommandText = "INSERT INTO users(username,email,first_name,last_name,created_at) VALUES(@u,@e,@f,@l,@d)";
    var pu = cmd.Parameters.Add("@u", SqliteType.Text);
    var pe = cmd.Parameters.Add("@e", SqliteType.Text);
    var pf = cmd.Parameters.Add("@f", SqliteType.Text);
    var pl = cmd.Parameters.Add("@l", SqliteType.Text);
    var pd = cmd.Parameters.Add("@d", SqliteType.Text);
    foreach (var r in rows)
    {
        pu.Value = r.Username; pe.Value = r.Email;
        pf.Value = r.FirstName; pl.Value = r.LastName; pd.Value = r.CreatedAt;
        cmd.ExecuteNonQuery();
    }
    tx.Commit();
}

void InsertProducts(SqliteConnection c, List<ProductRow> rows)
{
    using var tx = c.BeginTransaction();
    using var cmd = c.CreateCommand();
    cmd.Transaction = tx;
    cmd.CommandText = "INSERT INTO products(name,description,price,stock_quantity,created_at) VALUES(@n,@d,@p,@s,@c)";
    var pn = cmd.Parameters.Add("@n", SqliteType.Text);
    var pd = cmd.Parameters.Add("@d", SqliteType.Text);
    var pp = cmd.Parameters.Add("@p", SqliteType.Real);
    var ps = cmd.Parameters.Add("@s", SqliteType.Integer);
    var pc = cmd.Parameters.Add("@c", SqliteType.Text);
    foreach (var r in rows)
    {
        pn.Value = r.Name; pd.Value = r.Description ?? (object)DBNull.Value;
        pp.Value = (double)r.Price; ps.Value = r.Stock; pc.Value = r.CreatedAt;
        cmd.ExecuteNonQuery();
    }
    tx.Commit();
}

void InsertOrders(SqliteConnection c, List<OrderRow> rows)
{
    using var tx = c.BeginTransaction();
    using var cmd = c.CreateCommand();
    cmd.Transaction = tx;
    cmd.CommandText = "INSERT INTO orders(user_id,status,total_amount,created_at) VALUES(@u,@s,@t,@d)";
    var pu = cmd.Parameters.Add("@u", SqliteType.Integer);
    var ps = cmd.Parameters.Add("@s", SqliteType.Text);
    var pt = cmd.Parameters.Add("@t", SqliteType.Real);
    var pd = cmd.Parameters.Add("@d", SqliteType.Text);
    foreach (var r in rows)
    {
        pu.Value = r.UserId; ps.Value = r.Status;
        pt.Value = (double)r.Total; pd.Value = r.CreatedAt;
        cmd.ExecuteNonQuery();
    }
    tx.Commit();
}

void InsertOrderItems(SqliteConnection c, List<ItemRow> rows)
{
    using var tx = c.BeginTransaction();
    using var cmd = c.CreateCommand();
    cmd.Transaction = tx;
    cmd.CommandText = "INSERT INTO order_items(order_id,product_id,quantity,unit_price) VALUES(@o,@p,@q,@u)";
    var po = cmd.Parameters.Add("@o", SqliteType.Integer);
    var pp = cmd.Parameters.Add("@p", SqliteType.Integer);
    var pq = cmd.Parameters.Add("@q", SqliteType.Integer);
    var pu = cmd.Parameters.Add("@u", SqliteType.Real);
    foreach (var r in rows)
    {
        po.Value = r.OrderId; pp.Value = r.ProductId;
        pq.Value = r.Qty; pu.Value = (double)r.UnitPrice;
        cmd.ExecuteNonQuery();
    }
    tx.Commit();
}

// ── Utility ────────────────────────────────────────────────────────────────

void Execute(SqliteConnection c, string sql)
{
    using var cmd = c.CreateCommand();
    cmd.CommandText = sql;
    cmd.ExecuteNonQuery();
}

int CountRows(SqliteConnection c, string table)
{
    using var cmd = c.CreateCommand();
    cmd.CommandText = $"SELECT COUNT(*) FROM {table}";
    return Convert.ToInt32(cmd.ExecuteScalar());
}

int ExecuteScalarInt(SqliteConnection c, string sql)
{
    using var cmd = c.CreateCommand();
    cmd.CommandText = sql;
    return Convert.ToInt32(cmd.ExecuteScalar());
}

bool Check(SqliteConnection c, string name, Func<bool> assertion, string description)
{
    bool passed = assertion();
    string icon = passed ? "✓" : "✗";
    Console.WriteLine($"  {icon} {name}: {description}");
    return passed;
}

void PrintQuery(SqliteConnection c, string sql)
{
    using var cmd = c.CreateCommand();
    cmd.CommandText = sql;
    using var reader = cmd.ExecuteReader();
    var cols = Enumerable.Range(0, reader.FieldCount).Select(i => reader.GetName(i)).ToArray();
    Console.WriteLine("  " + string.Join(" | ", cols.Select(col => col.PadRight(20))));
    Console.WriteLine("  " + new string('-', cols.Length * 22));
    while (reader.Read())
    {
        var values = Enumerable.Range(0, reader.FieldCount)
            .Select(i => reader.IsDBNull(i) ? "NULL" : reader.GetValue(i).ToString() ?? "")
            .Select(v => v.PadRight(20));
        Console.WriteLine("  " + string.Join(" | ", values));
    }
}
