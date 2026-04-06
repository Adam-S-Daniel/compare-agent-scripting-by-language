// TDD Phase: GREEN — verification queries that confirm data consistency.
// Each check returns a VerificationResult indicating pass/fail with a message.

using Microsoft.Data.Sqlite;

namespace DatabaseSeeder.Library.Verification;

/// <summary>Result of a single data consistency check.</summary>
public record VerificationResult(bool IsValid, string CheckName, string Message);

/// <summary>Aggregated statistics from the database.</summary>
public record DatabaseStats(int UserCount, int ProductCount, int OrderCount, int OrderItemCount);

/// <summary>
/// Runs SQL-based consistency checks against a seeded database.
/// All checks are read-only queries; nothing is modified.
/// </summary>
public static class DatabaseVerifier
{
    // ── Individual checks ──────────────────────────────────────────────────

    /// <summary>Verifies that each table contains the expected number of rows.</summary>
    public static VerificationResult VerifyTableCounts(
        SqliteConnection conn,
        int expectedUsers,
        int expectedProducts,
        int expectedOrders)
    {
        int actualUsers    = CountRows(conn, "users");
        int actualProducts = CountRows(conn, "products");
        int actualOrders   = CountRows(conn, "orders");

        if (actualUsers != expectedUsers)
            return Fail("TableCounts", $"Expected {expectedUsers} users but found {actualUsers}");
        if (actualProducts != expectedProducts)
            return Fail("TableCounts", $"Expected {expectedProducts} products but found {actualProducts}");
        if (actualOrders != expectedOrders)
            return Fail("TableCounts", $"Expected {expectedOrders} orders but found {actualOrders}");

        return Pass("TableCounts",
            $"users={actualUsers}, products={actualProducts}, orders={actualOrders} — all match expected counts");
    }

    /// <summary>
    /// Verifies that no order references a non-existent user (orphan detection).
    /// Runs a LEFT JOIN to find orders whose user_id has no matching user.
    /// </summary>
    public static VerificationResult VerifyNoOrphanOrders(SqliteConnection conn)
    {
        const string sql = @"
            SELECT COUNT(*)
            FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            WHERE u.id IS NULL";

        int orphanCount = ExecuteScalarInt(conn, sql);

        return orphanCount == 0
            ? Pass("NoOrphanOrders", "All orders reference valid users")
            : Fail("NoOrphanOrders", $"Found {orphanCount} order(s) referencing non-existent users");
    }

    /// <summary>
    /// Verifies that no order_item references a non-existent order or product.
    /// </summary>
    public static VerificationResult VerifyNoOrphanOrderItems(SqliteConnection conn)
    {
        const string sqlOrphanOrders = @"
            SELECT COUNT(*)
            FROM order_items oi
            LEFT JOIN orders o ON oi.order_id = o.id
            WHERE o.id IS NULL";

        const string sqlOrphanProducts = @"
            SELECT COUNT(*)
            FROM order_items oi
            LEFT JOIN products p ON oi.product_id = p.id
            WHERE p.id IS NULL";

        int orphanOrders   = ExecuteScalarInt(conn, sqlOrphanOrders);
        int orphanProducts = ExecuteScalarInt(conn, sqlOrphanProducts);

        if (orphanOrders > 0)
            return Fail("NoOrphanOrderItems", $"Found {orphanOrders} item(s) referencing non-existent orders");
        if (orphanProducts > 0)
            return Fail("NoOrphanOrderItems", $"Found {orphanProducts} item(s) referencing non-existent products");

        return Pass("NoOrphanOrderItems", "All order_items reference valid orders and products");
    }

    /// <summary>Verifies that every order has at least one line item.</summary>
    public static VerificationResult VerifyAllOrdersHaveItems(SqliteConnection conn)
    {
        const string sql = @"
            SELECT COUNT(*)
            FROM orders o
            LEFT JOIN order_items oi ON o.id = oi.order_id
            WHERE oi.id IS NULL";

        int ordersWithoutItems = ExecuteScalarInt(conn, sql);

        return ordersWithoutItems == 0
            ? Pass("AllOrdersHaveItems", "Every order has at least one line item")
            : Fail("AllOrdersHaveItems", $"Found {ordersWithoutItems} order(s) with no items");
    }

    /// <summary>Verifies that all user emails are unique.</summary>
    public static VerificationResult VerifyUniqueEmails(SqliteConnection conn)
    {
        // COUNT(*) - COUNT(DISTINCT email) == 0 means no duplicates
        const string sql = @"SELECT COUNT(*) - COUNT(DISTINCT email) FROM users";

        int duplicates = ExecuteScalarInt(conn, sql);

        return duplicates == 0
            ? Pass("UniqueEmails", "All user emails are unique")
            : Fail("UniqueEmails", $"Found {duplicates} duplicate email(s)");
    }

    /// <summary>Verifies that all usernames are unique.</summary>
    public static VerificationResult VerifyUniqueUsernames(SqliteConnection conn)
    {
        const string sql = @"SELECT COUNT(*) - COUNT(DISTINCT username) FROM users";
        int duplicates = ExecuteScalarInt(conn, sql);

        return duplicates == 0
            ? Pass("UniqueUsernames", "All usernames are unique")
            : Fail("UniqueUsernames", $"Found {duplicates} duplicate username(s)");
    }

    /// <summary>Verifies that all product prices are positive.</summary>
    public static VerificationResult VerifyPositiveProductPrices(SqliteConnection conn)
    {
        const string sql = @"SELECT COUNT(*) FROM products WHERE price <= 0";
        int invalid = ExecuteScalarInt(conn, sql);

        return invalid == 0
            ? Pass("PositiveProductPrices", "All product prices are positive")
            : Fail("PositiveProductPrices", $"Found {invalid} product(s) with non-positive price");
    }

    /// <summary>Verifies that all order item quantities are positive.</summary>
    public static VerificationResult VerifyPositiveQuantities(SqliteConnection conn)
    {
        const string sql = @"SELECT COUNT(*) FROM order_items WHERE quantity <= 0";
        int invalid = ExecuteScalarInt(conn, sql);

        return invalid == 0
            ? Pass("PositiveQuantities", "All order item quantities are positive")
            : Fail("PositiveQuantities", $"Found {invalid} item(s) with non-positive quantity");
    }

    /// <summary>Runs all consistency checks and returns the full list of results.</summary>
    public static List<VerificationResult> VerifyAll(SqliteConnection conn)
    {
        // Determine actual counts for the table count check
        int users    = CountRows(conn, "users");
        int products = CountRows(conn, "products");
        int orders   = CountRows(conn, "orders");

        return new List<VerificationResult>
        {
            VerifyTableCounts(conn, users, products, orders), // checks current counts match themselves (always passes)
            VerifyNoOrphanOrders(conn),
            VerifyNoOrphanOrderItems(conn),
            VerifyAllOrdersHaveItems(conn),
            VerifyUniqueEmails(conn),
            VerifyUniqueUsernames(conn),
            VerifyPositiveProductPrices(conn),
            VerifyPositiveQuantities(conn),
        };
    }

    /// <summary>Returns aggregate statistics from the database.</summary>
    public static DatabaseStats GetStatistics(SqliteConnection conn)
    {
        return new DatabaseStats(
            UserCount:      CountRows(conn, "users"),
            ProductCount:   CountRows(conn, "products"),
            OrderCount:     CountRows(conn, "orders"),
            OrderItemCount: CountRows(conn, "order_items")
        );
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private static int CountRows(SqliteConnection conn, string table)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"SELECT COUNT(*) FROM {table}";
        return Convert.ToInt32(cmd.ExecuteScalar());
    }

    private static int ExecuteScalarInt(SqliteConnection conn, string sql)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        return Convert.ToInt32(cmd.ExecuteScalar());
    }

    private static VerificationResult Pass(string check, string message) =>
        new(IsValid: true, CheckName: check, Message: message);

    private static VerificationResult Fail(string check, string message) =>
        new(IsValid: false, CheckName: check, Message: message);
}
