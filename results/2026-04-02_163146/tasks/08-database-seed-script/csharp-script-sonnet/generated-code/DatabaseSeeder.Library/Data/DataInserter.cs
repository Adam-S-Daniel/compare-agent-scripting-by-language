// TDD Phase: GREEN — inserts generated records into the database.
// All inserts use transactions for performance and atomicity.
// Insertion order respects referential integrity: users → products → orders → order_items.
// Uses SQLite's RETURNING clause (3.35+) for reliable ID retrieval in a single statement.

using Microsoft.Data.Sqlite;

namespace DatabaseSeeder.Library.Data;

/// <summary>
/// Inserts generated mock data into the database.
/// All methods accept an open SqliteConnection and return the auto-assigned IDs.
/// Insertion order must be: InsertUsers → InsertProducts → InsertOrders → InsertOrderItems.
/// </summary>
public static class DataInserter
{
    /// <summary>
    /// Inserts users in a single transaction. Returns the list of auto-assigned row IDs.
    /// </summary>
    public static List<int> InsertUsers(SqliteConnection conn, List<UserRecord> users)
    {
        var ids = new List<int>(users.Count);

        using var transaction = conn.BeginTransaction();
        try
        {
            using var cmd = conn.CreateCommand();
            cmd.Transaction = transaction;
            // RETURNING id retrieves the auto-assigned primary key in a single round trip
            cmd.CommandText = @"
                INSERT INTO users (username, email, first_name, last_name, created_at)
                VALUES (@username, @email, @firstName, @lastName, @createdAt)
                RETURNING id";

            // Add parameters once and reuse the prepared statement for each row
            var pUsername  = cmd.Parameters.Add("@username",  SqliteType.Text);
            var pEmail     = cmd.Parameters.Add("@email",     SqliteType.Text);
            var pFirstName = cmd.Parameters.Add("@firstName", SqliteType.Text);
            var pLastName  = cmd.Parameters.Add("@lastName",  SqliteType.Text);
            var pCreatedAt = cmd.Parameters.Add("@createdAt", SqliteType.Text);

            foreach (var user in users)
            {
                pUsername.Value  = user.Username;
                pEmail.Value     = user.Email;
                pFirstName.Value = user.FirstName;
                pLastName.Value  = user.LastName;
                pCreatedAt.Value = user.CreatedAt;

                ids.Add(Convert.ToInt32(cmd.ExecuteScalar()));
            }

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }

        return ids;
    }

    /// <summary>
    /// Inserts products in a single transaction. Returns the list of auto-assigned row IDs.
    /// </summary>
    public static List<int> InsertProducts(SqliteConnection conn, List<ProductRecord> products)
    {
        var ids = new List<int>(products.Count);

        using var transaction = conn.BeginTransaction();
        try
        {
            using var cmd = conn.CreateCommand();
            cmd.Transaction = transaction;
            cmd.CommandText = @"
                INSERT INTO products (name, description, price, stock_quantity, created_at)
                VALUES (@name, @description, @price, @stock, @createdAt)
                RETURNING id";

            var pName        = cmd.Parameters.Add("@name",        SqliteType.Text);
            var pDescription = cmd.Parameters.Add("@description", SqliteType.Text);
            var pPrice       = cmd.Parameters.Add("@price",       SqliteType.Real);
            var pStock       = cmd.Parameters.Add("@stock",       SqliteType.Integer);
            var pCreatedAt   = cmd.Parameters.Add("@createdAt",   SqliteType.Text);

            foreach (var product in products)
            {
                pName.Value        = product.Name;
                pDescription.Value = product.Description ?? (object)DBNull.Value;
                pPrice.Value       = (double)product.Price;
                pStock.Value       = product.StockQuantity;
                pCreatedAt.Value   = product.CreatedAt;

                ids.Add(Convert.ToInt32(cmd.ExecuteScalar()));
            }

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }

        return ids;
    }

    /// <summary>
    /// Inserts orders in a single transaction.
    /// Precondition: all user_id values must reference already-inserted users.
    /// Returns the list of auto-assigned row IDs.
    /// </summary>
    public static List<int> InsertOrders(SqliteConnection conn, List<OrderRecord> orders)
    {
        var ids = new List<int>(orders.Count);

        using var transaction = conn.BeginTransaction();
        try
        {
            using var cmd = conn.CreateCommand();
            cmd.Transaction = transaction;
            cmd.CommandText = @"
                INSERT INTO orders (user_id, status, total_amount, created_at)
                VALUES (@userId, @status, @totalAmount, @createdAt)
                RETURNING id";

            var pUserId      = cmd.Parameters.Add("@userId",      SqliteType.Integer);
            var pStatus      = cmd.Parameters.Add("@status",      SqliteType.Text);
            var pTotalAmount = cmd.Parameters.Add("@totalAmount", SqliteType.Real);
            var pCreatedAt   = cmd.Parameters.Add("@createdAt",   SqliteType.Text);

            foreach (var order in orders)
            {
                pUserId.Value      = order.UserId;
                pStatus.Value      = order.Status;
                pTotalAmount.Value = (double)order.TotalAmount;
                pCreatedAt.Value   = order.CreatedAt;

                ids.Add(Convert.ToInt32(cmd.ExecuteScalar()));
            }

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }

        return ids;
    }

    /// <summary>
    /// Inserts order line items in a single transaction.
    /// Precondition: all order_id and product_id values must reference already-inserted rows.
    /// Returns the list of auto-assigned row IDs.
    /// </summary>
    public static List<int> InsertOrderItems(SqliteConnection conn, List<OrderItemRecord> items)
    {
        var ids = new List<int>(items.Count);

        using var transaction = conn.BeginTransaction();
        try
        {
            using var cmd = conn.CreateCommand();
            cmd.Transaction = transaction;
            cmd.CommandText = @"
                INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                VALUES (@orderId, @productId, @quantity, @unitPrice)
                RETURNING id";

            var pOrderId   = cmd.Parameters.Add("@orderId",   SqliteType.Integer);
            var pProductId = cmd.Parameters.Add("@productId", SqliteType.Integer);
            var pQuantity  = cmd.Parameters.Add("@quantity",  SqliteType.Integer);
            var pUnitPrice = cmd.Parameters.Add("@unitPrice", SqliteType.Real);

            foreach (var item in items)
            {
                pOrderId.Value   = item.OrderId;
                pProductId.Value = item.ProductId;
                pQuantity.Value  = item.Quantity;
                pUnitPrice.Value = (double)item.UnitPrice;

                ids.Add(Convert.ToInt32(cmd.ExecuteScalar()));
            }

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }

        return ids;
    }
}
