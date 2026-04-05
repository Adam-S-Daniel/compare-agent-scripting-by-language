// Data transfer objects (records) representing rows to be inserted.
// Immutable records ensure consistency during generation and insertion.

namespace DatabaseSeeder.Library.Data;

/// <summary>Row to insert into the users table.</summary>
public record UserRecord(
    string Username,
    string Email,
    string FirstName,
    string LastName,
    string CreatedAt
);

/// <summary>Row to insert into the products table.</summary>
public record ProductRecord(
    string Name,
    string? Description,   // nullable — description column is optional in the schema
    decimal Price,
    int StockQuantity,
    string CreatedAt
);

/// <summary>
/// Row to insert into the orders table.
/// UserId is 1-based and must correspond to a user that has already been inserted.
/// </summary>
public record OrderRecord(
    int UserId,
    string Status,
    decimal TotalAmount,
    string CreatedAt
);

/// <summary>
/// Row to insert into the order_items table.
/// OrderId and ProductId are 1-based and must reference already-inserted rows.
/// </summary>
public record OrderItemRecord(
    int OrderId,
    int ProductId,
    int Quantity,
    decimal UnitPrice
);
