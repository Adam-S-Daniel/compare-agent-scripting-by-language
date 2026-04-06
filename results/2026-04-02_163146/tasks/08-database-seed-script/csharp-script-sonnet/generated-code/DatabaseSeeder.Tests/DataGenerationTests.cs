// TDD Phase: RED — tests for deterministic data generation.
// DataGenerator uses a seeded RNG to produce reproducible mock data.

using Xunit;
using DatabaseSeeder.Library.Data;

namespace DatabaseSeeder.Tests;

/// <summary>
/// Tests for deterministic mock data generation.
/// All data must be reproducible given the same seed.
/// </summary>
public class DataGenerationTests
{
    [Fact]
    public void GenerateUsers_ShouldReturnRequestedCount()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(10);
        Assert.Equal(10, users.Count);
    }

    [Fact]
    public void GenerateUsers_ShouldProduceDeterministicOutput()
    {
        // Same seed → same output
        var gen1 = new DataGenerator(seed: 42);
        var gen2 = new DataGenerator(seed: 42);

        var users1 = gen1.GenerateUsers(5);
        var users2 = gen2.GenerateUsers(5);

        Assert.Equal(users1.Count, users2.Count);
        for (int i = 0; i < users1.Count; i++)
        {
            Assert.Equal(users1[i].Username, users2[i].Username);
            Assert.Equal(users1[i].Email, users2[i].Email);
        }
    }

    [Fact]
    public void GenerateUsers_DifferentSeeds_ShouldProduceDifferentOutput()
    {
        var gen1 = new DataGenerator(seed: 42);
        var gen2 = new DataGenerator(seed: 99);

        var users1 = gen1.GenerateUsers(5);
        var users2 = gen2.GenerateUsers(5);

        // At least one username should differ
        Assert.False(users1.Select(u => u.Username).SequenceEqual(users2.Select(u => u.Username)),
            "Different seeds should produce different data");
    }

    [Fact]
    public void GenerateUsers_ShouldHaveUniqueUsernames()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(20);
        var usernames = users.Select(u => u.Username).ToList();
        Assert.Equal(usernames.Count, usernames.Distinct().Count());
    }

    [Fact]
    public void GenerateUsers_ShouldHaveUniqueEmails()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(20);
        var emails = users.Select(u => u.Email).ToList();
        Assert.Equal(emails.Count, emails.Distinct().Count());
    }

    [Fact]
    public void GenerateUsers_ShouldHaveValidEmailFormat()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(10);
        foreach (var user in users)
        {
            Assert.Contains("@", user.Email);
            Assert.DoesNotContain(" ", user.Email);
        }
    }

    [Fact]
    public void GenerateUsers_ShouldHaveNonEmptyFields()
    {
        var generator = new DataGenerator(seed: 42);
        var users = generator.GenerateUsers(10);
        foreach (var user in users)
        {
            Assert.False(string.IsNullOrWhiteSpace(user.Username));
            Assert.False(string.IsNullOrWhiteSpace(user.Email));
            Assert.False(string.IsNullOrWhiteSpace(user.FirstName));
            Assert.False(string.IsNullOrWhiteSpace(user.LastName));
            Assert.False(string.IsNullOrWhiteSpace(user.CreatedAt));
        }
    }

    [Fact]
    public void GenerateProducts_ShouldReturnRequestedCount()
    {
        var generator = new DataGenerator(seed: 42);
        var products = generator.GenerateProducts(15);
        Assert.Equal(15, products.Count);
    }

    [Fact]
    public void GenerateProducts_ShouldHavePositivePrices()
    {
        var generator = new DataGenerator(seed: 42);
        var products = generator.GenerateProducts(20);
        Assert.All(products, p => Assert.True(p.Price > 0, $"Product '{p.Name}' has invalid price {p.Price}"));
    }

    [Fact]
    public void GenerateProducts_ShouldHaveNonNegativeStock()
    {
        var generator = new DataGenerator(seed: 42);
        var products = generator.GenerateProducts(20);
        Assert.All(products, p => Assert.True(p.StockQuantity >= 0));
    }

    [Fact]
    public void GenerateProducts_ShouldBeReproducible()
    {
        var gen1 = new DataGenerator(seed: 42);
        var gen2 = new DataGenerator(seed: 42);

        var products1 = gen1.GenerateProducts(5);
        var products2 = gen2.GenerateProducts(5);

        for (int i = 0; i < products1.Count; i++)
        {
            Assert.Equal(products1[i].Name, products2[i].Name);
            Assert.Equal(products1[i].Price, products2[i].Price);
        }
    }

    [Fact]
    public void GenerateOrders_ShouldReturnRequestedCount()
    {
        var generator = new DataGenerator(seed: 42);
        var orders = generator.GenerateOrders(count: 30, userCount: 10);
        Assert.Equal(30, orders.Count);
    }

    [Fact]
    public void GenerateOrders_ShouldReferenceValidUserIds()
    {
        var generator = new DataGenerator(seed: 42);
        int userCount = 10;
        var orders = generator.GenerateOrders(count: 30, userCount: userCount);
        // user_id must be in range [1, userCount]
        Assert.All(orders, o => Assert.InRange(o.UserId, 1, userCount));
    }

    [Fact]
    public void GenerateOrders_ShouldHaveValidStatuses()
    {
        var validStatuses = new[] { "pending", "processing", "shipped", "delivered", "cancelled" };
        var generator = new DataGenerator(seed: 42);
        var orders = generator.GenerateOrders(count: 30, userCount: 10);
        Assert.All(orders, o => Assert.Contains(o.Status, validStatuses));
    }

    [Fact]
    public void GenerateOrderItems_ShouldProduceItemsForEachOrder()
    {
        var generator = new DataGenerator(seed: 42);
        int orderCount = 10;
        int productCount = 20;
        var items = generator.GenerateOrderItems(orderCount, productCount);
        // Every order should have at least one item
        var orderIds = items.Select(i => i.OrderId).Distinct().OrderBy(x => x).ToList();
        Assert.Equal(orderCount, orderIds.Count);
    }

    [Fact]
    public void GenerateOrderItems_ShouldReferenceValidOrderIds()
    {
        var generator = new DataGenerator(seed: 42);
        int orderCount = 10;
        var items = generator.GenerateOrderItems(orderCount, productCount: 20);
        Assert.All(items, i => Assert.InRange(i.OrderId, 1, orderCount));
    }

    [Fact]
    public void GenerateOrderItems_ShouldReferenceValidProductIds()
    {
        var generator = new DataGenerator(seed: 42);
        int productCount = 20;
        var items = generator.GenerateOrderItems(orderCount: 10, productCount: productCount);
        Assert.All(items, i => Assert.InRange(i.ProductId, 1, productCount));
    }

    [Fact]
    public void GenerateOrderItems_ShouldHavePositiveQuantities()
    {
        var generator = new DataGenerator(seed: 42);
        var items = generator.GenerateOrderItems(orderCount: 10, productCount: 20);
        Assert.All(items, i => Assert.True(i.Quantity > 0));
    }

    [Fact]
    public void GenerateOrderItems_ShouldHavePositiveUnitPrices()
    {
        var generator = new DataGenerator(seed: 42);
        var items = generator.GenerateOrderItems(orderCount: 10, productCount: 20);
        Assert.All(items, i => Assert.True(i.UnitPrice > 0));
    }
}
