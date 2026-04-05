// TDD Phase: GREEN — deterministic mock data generation using seeded RNG.
// The same seed always produces the same dataset, enabling reproducible tests.

namespace DatabaseSeeder.Library.Data;

/// <summary>
/// Generates realistic mock data using a seeded System.Random for full reproducibility.
/// Default seed is 42 to match standard benchmark conventions.
/// </summary>
public class DataGenerator
{
    private readonly Random _rng;

    // ── Source arrays for realistic-looking data ────────────────────────────

    private static readonly string[] FirstNames =
    {
        "Alice", "Bob", "Charlie", "Diana", "Eve",
        "Frank", "Grace", "Henry", "Iris", "Jack",
        "Karen", "Leo", "Mia", "Nathan", "Olivia"
    };

    private static readonly string[] LastNames =
    {
        "Smith", "Jones", "Brown", "Davis", "Miller",
        "Wilson", "Moore", "Taylor", "Anderson", "Thomas",
        "Jackson", "White", "Harris", "Martin", "Garcia"
    };

    private static readonly string[] ProductAdjectives =
    {
        "Premium", "Budget", "Professional", "Compact", "Wireless",
        "Portable", "Ergonomic", "Ultra-thin", "Gaming", "Smart"
    };

    private static readonly string[] ProductNouns =
    {
        "Laptop", "Phone", "Tablet", "Headphones", "Camera",
        "Watch", "Keyboard", "Mouse", "Monitor", "Speaker",
        "Charger", "Router", "Webcam", "Controller", "Dock"
    };

    private static readonly string[] OrderStatuses =
    {
        "pending", "processing", "shipped", "delivered", "cancelled"
    };

    private static readonly string[] EmailDomains =
    {
        "example.com", "mail.test", "demo.io", "sample.net"
    };

    /// <summary>
    /// Initializes the generator with a specific seed.
    /// The same seed always produces the same sequence of random data.
    /// </summary>
    public DataGenerator(int seed = 42)
    {
        _rng = new Random(seed);
    }

    // ── Public generation methods ───────────────────────────────────────────

    /// <summary>
    /// Generates the specified number of user records.
    /// Usernames and emails are guaranteed to be unique within the batch.
    /// </summary>
    public List<UserRecord> GenerateUsers(int count)
    {
        var users = new List<UserRecord>(count);
        var usedUsernames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        for (int i = 0; i < count; i++)
        {
            // Retry until we get a unique username
            string username, email, firstName, lastName;
            do
            {
                firstName = FirstNames[_rng.Next(FirstNames.Length)];
                lastName  = LastNames[_rng.Next(LastNames.Length)];
                int suffix = _rng.Next(1000);
                username = $"{firstName.ToLowerInvariant()}.{lastName.ToLowerInvariant()}{suffix}";
                string domain = EmailDomains[_rng.Next(EmailDomains.Length)];
                email = $"{username}@{domain}";
            }
            while (usedUsernames.Contains(username));

            usedUsernames.Add(username);

            string createdAt = RandomPastDate(daysBack: 730);
            users.Add(new UserRecord(username, email, firstName, lastName, createdAt));
        }

        return users;
    }

    /// <summary>Generates the specified number of product records.</summary>
    public List<ProductRecord> GenerateProducts(int count)
    {
        var products = new List<ProductRecord>(count);

        for (int i = 0; i < count; i++)
        {
            string adj  = ProductAdjectives[_rng.Next(ProductAdjectives.Length)];
            string noun = ProductNouns[_rng.Next(ProductNouns.Length)];
            string name = $"{adj} {noun}";
            string desc = $"A {name.ToLowerInvariant()} for everyday use.";

            // Price between $5.00 and $999.99
            decimal price = Math.Round((decimal)(_rng.NextDouble() * 994.99 + 5.00), 2);
            int stock = _rng.Next(0, 200);
            string createdAt = RandomPastDate(daysBack: 365);

            products.Add(new ProductRecord(name, desc, price, stock, createdAt));
        }

        return products;
    }

    /// <summary>
    /// Generates the specified number of order records.
    /// UserId values are randomly chosen in [1, userCount], matching inserted user IDs.
    /// </summary>
    public List<OrderRecord> GenerateOrders(int count, int userCount)
    {
        if (userCount <= 0)
            throw new ArgumentException("userCount must be > 0", nameof(userCount));

        var orders = new List<OrderRecord>(count);

        for (int i = 0; i < count; i++)
        {
            int userId = _rng.Next(1, userCount + 1); // 1-based
            string status = OrderStatuses[_rng.Next(OrderStatuses.Length)];
            decimal totalAmount = Math.Round((decimal)(_rng.NextDouble() * 490 + 10), 2);
            string createdAt = RandomPastDate(daysBack: 180);

            orders.Add(new OrderRecord(userId, status, totalAmount, createdAt));
        }

        return orders;
    }

    /// <summary>
    /// Generates order line items for each order [1..orderCount].
    /// Each order gets between minItemsPerOrder and maxItemsPerOrder unique products.
    /// ProductId values are in [1, productCount].
    /// </summary>
    public List<OrderItemRecord> GenerateOrderItems(
        int orderCount,
        int productCount,
        int minItemsPerOrder = 1,
        int maxItemsPerOrder = 5)
    {
        if (productCount <= 0)
            throw new ArgumentException("productCount must be > 0", nameof(productCount));

        // Cap max items so we don't exceed product count
        int effectiveMax = Math.Min(maxItemsPerOrder, productCount);

        var items = new List<OrderItemRecord>();

        for (int orderId = 1; orderId <= orderCount; orderId++)
        {
            int itemCount = _rng.Next(minItemsPerOrder, effectiveMax + 1);
            var usedProducts = new HashSet<int>();

            for (int j = 0; j < itemCount; j++)
            {
                // Pick a product not already in this order
                int productId;
                do
                {
                    productId = _rng.Next(1, productCount + 1);
                }
                while (usedProducts.Contains(productId));

                usedProducts.Add(productId);

                int quantity = _rng.Next(1, 10);
                decimal unitPrice = Math.Round((decimal)(_rng.NextDouble() * 495 + 5), 2);

                items.Add(new OrderItemRecord(orderId, productId, quantity, unitPrice));
            }
        }

        return items;
    }

    // ── Private helpers ─────────────────────────────────────────────────────

    /// <summary>Returns a random past UTC datetime string formatted for SQLite.</summary>
    private string RandomPastDate(int daysBack)
    {
        int daysAgo = _rng.Next(1, daysBack + 1);
        return DateTime.UtcNow.AddDays(-daysAgo).ToString("yyyy-MM-dd HH:mm:ss");
    }
}
