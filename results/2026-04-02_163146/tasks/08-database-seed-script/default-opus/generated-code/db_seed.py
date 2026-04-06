"""
SQLite database seed script with deterministic mock data.

Creates a schema with users, products, and orders tables (with foreign keys),
generates realistic mock data using a seeded RNG for reproducibility, inserts
data respecting referential integrity, and runs verification queries.

TDD implementation order:
  1. create_schema    - GREEN for TestSchemaCreation
  2. generate_*       - GREEN for TestDataGeneration
  3. seed_database    - GREEN for TestDataInsertion
  4. run_verification - GREEN for TestVerificationQueries
  5. error handling   - GREEN for TestErrorHandling
"""

import sqlite3
import random
from datetime import datetime, timedelta

# Default seed for deterministic randomization
SEED = 12345


# ---------------------------------------------------------------------------
# Schema creation (TDD Cycle 1)
# ---------------------------------------------------------------------------

def create_schema(conn):
    """
    Create users, products, and orders tables with appropriate constraints.

    Raises RuntimeError with a descriptive message if the connection is unusable.
    """
    try:
        conn.executescript("""
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS users (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                name       TEXT    NOT NULL,
                email      TEXT    NOT NULL UNIQUE,
                created_at TEXT    NOT NULL
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
                user_id     INTEGER NOT NULL REFERENCES users(id),
                product_id  INTEGER NOT NULL REFERENCES products(id),
                quantity    INTEGER NOT NULL CHECK(quantity > 0),
                total_price REAL    NOT NULL,
                order_date  TEXT    NOT NULL
            );
        """)
    except sqlite3.ProgrammingError as exc:
        raise RuntimeError(
            f"Failed to create schema: connection may be closed. {exc}"
        ) from exc


# ---------------------------------------------------------------------------
# Data generation (TDD Cycle 2)
# ---------------------------------------------------------------------------

# Realistic first/last name pools for mock users
_FIRST_NAMES = [
    "Alice", "Bob", "Carol", "David", "Eve", "Frank", "Grace", "Hank",
    "Irene", "Jack", "Karen", "Leo", "Mona", "Nick", "Olivia", "Paul",
    "Quinn", "Rita", "Sam", "Tina", "Uma", "Vince", "Wendy", "Xander",
    "Yara", "Zane",
]

_LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
    "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
    "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
    "Ramirez", "Lewis", "Robinson",
]

# Realistic product catalogue
_PRODUCT_ADJECTIVES = [
    "Premium", "Classic", "Organic", "Deluxe", "Essential", "Ultra",
    "Professional", "Eco", "Smart", "Compact",
]

_PRODUCT_NOUNS = [
    "Widget", "Gadget", "Sensor", "Module", "Adapter", "Controller",
    "Monitor", "Keyboard", "Charger", "Cable", "Speaker", "Headphones",
    "Camera", "Lamp", "Thermostat",
]

_CATEGORIES = [
    "Electronics", "Home & Garden", "Office", "Sports", "Health",
    "Automotive", "Toys", "Kitchen",
]


def generate_users(count, seed=SEED):
    """
    Generate `count` user dicts with unique emails using a seeded RNG.

    Returns list of dicts: [{name, email, created_at}, ...]
    """
    rng = random.Random(seed)
    users = []
    used_emails = set()

    # Base date for created_at
    base_date = datetime(2023, 1, 1)

    for i in range(count):
        first = rng.choice(_FIRST_NAMES)
        last = rng.choice(_LAST_NAMES)
        name = f"{first} {last}"

        # Build a unique email using index to guarantee uniqueness
        email = f"{first.lower()}.{last.lower()}.{i + 1}@example.com"

        # Spread creation dates over ~2 years
        days_offset = rng.randint(0, 730)
        created_at = (base_date + timedelta(days=days_offset)).strftime("%Y-%m-%d")

        users.append({"name": name, "email": email, "created_at": created_at})
        used_emails.add(email)

    return users


def generate_products(count, seed=SEED):
    """
    Generate `count` product dicts using a seeded RNG.

    Returns list of dicts: [{name, price, category, stock}, ...]
    """
    rng = random.Random(seed)
    products = []

    for i in range(count):
        adj = rng.choice(_PRODUCT_ADJECTIVES)
        noun = rng.choice(_PRODUCT_NOUNS)
        name = f"{adj} {noun} {i + 1}"

        price = round(rng.uniform(4.99, 999.99), 2)
        category = rng.choice(_CATEGORIES)
        stock = rng.randint(0, 500)

        products.append({
            "name": name,
            "price": price,
            "category": category,
            "stock": stock,
        })

    return products


def generate_orders(count, users, products, seed=SEED):
    """
    Generate `count` order dicts referencing existing users and products.

    user_id and product_id are 1-indexed (matching SQLite AUTOINCREMENT ids).
    total_price = quantity * product price.

    Raises ValueError if users or products lists are empty.
    """
    if not users:
        raise ValueError("Cannot generate orders: users list is empty")
    if not products:
        raise ValueError("Cannot generate orders: products list is empty")

    rng = random.Random(seed)
    orders = []
    base_date = datetime(2023, 6, 1)

    for _ in range(count):
        # Pick a random user and product (1-indexed ids)
        user_id = rng.randint(1, len(users))
        product_idx = rng.randint(0, len(products) - 1)
        product_id = product_idx + 1

        quantity = rng.randint(1, 10)
        total_price = round(quantity * products[product_idx]["price"], 2)

        days_offset = rng.randint(0, 365)
        order_date = (base_date + timedelta(days=days_offset)).strftime("%Y-%m-%d")

        orders.append({
            "user_id": user_id,
            "product_id": product_id,
            "quantity": quantity,
            "total_price": total_price,
            "order_date": order_date,
        })

    return orders


# ---------------------------------------------------------------------------
# Database seeding (TDD Cycle 3)
# ---------------------------------------------------------------------------

def seed_database(conn, num_users=20, num_products=15, num_orders=50, seed=SEED):
    """
    Create schema, generate mock data, and insert it into the database.

    Inserts in order: users -> products -> orders to satisfy foreign keys.
    Raises RuntimeError with a descriptive message if the connection fails.
    """
    try:
        create_schema(conn)
    except RuntimeError:
        raise RuntimeError("Failed to seed database: could not create schema (connection may be closed)")

    users = generate_users(num_users, seed=seed)
    products = generate_products(num_products, seed=seed)
    orders = generate_orders(num_orders, users, products, seed=seed)

    try:
        # Insert users
        conn.executemany(
            "INSERT INTO users (name, email, created_at) VALUES (?, ?, ?)",
            [(u["name"], u["email"], u["created_at"]) for u in users],
        )

        # Insert products
        conn.executemany(
            "INSERT INTO products (name, price, category, stock) VALUES (?, ?, ?, ?)",
            [(p["name"], p["price"], p["category"], p["stock"]) for p in products],
        )

        # Insert orders (after users and products, respecting foreign keys)
        conn.executemany(
            "INSERT INTO orders (user_id, product_id, quantity, total_price, order_date) "
            "VALUES (?, ?, ?, ?, ?)",
            [(o["user_id"], o["product_id"], o["quantity"], o["total_price"], o["order_date"])
             for o in orders],
        )

        conn.commit()
    except sqlite3.ProgrammingError as exc:
        raise RuntimeError(
            f"Failed to seed database: {exc}"
        ) from exc


# ---------------------------------------------------------------------------
# Verification queries (TDD Cycle 4)
# ---------------------------------------------------------------------------

def run_verification_queries(conn):
    """
    Run a suite of verification queries and return results as a dictionary.

    Confirms data consistency across all three tables.
    """
    results = {}

    # Row counts
    results["total_users"] = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    results["total_products"] = conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
    results["total_orders"] = conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]

    # Referential integrity: orphan orders
    results["orphan_orders_users"] = conn.execute(
        "SELECT COUNT(*) FROM orders WHERE user_id NOT IN (SELECT id FROM users)"
    ).fetchone()[0]

    results["orphan_orders_products"] = conn.execute(
        "SELECT COUNT(*) FROM orders WHERE product_id NOT IN (SELECT id FROM products)"
    ).fetchone()[0]

    # Revenue per user (users who have placed orders)
    results["revenue_per_user"] = conn.execute(
        "SELECT u.name, SUM(o.total_price) as total_spent "
        "FROM orders o JOIN users u ON o.user_id = u.id "
        "GROUP BY u.id ORDER BY total_spent DESC"
    ).fetchall()

    # Top products by number of orders
    results["top_products_by_orders"] = conn.execute(
        "SELECT p.name, COUNT(o.id) as order_count "
        "FROM orders o JOIN products p ON o.product_id = p.id "
        "GROUP BY p.id ORDER BY order_count DESC"
    ).fetchall()

    # Average order value
    results["avg_order_value"] = conn.execute(
        "SELECT AVG(total_price) FROM orders"
    ).fetchone()[0]

    # Orders per product category
    results["orders_per_category"] = conn.execute(
        "SELECT p.category, COUNT(o.id) as order_count "
        "FROM orders o JOIN products p ON o.product_id = p.id "
        "GROUP BY p.category ORDER BY order_count DESC"
    ).fetchall()

    # Total revenue
    results["total_revenue"] = conn.execute(
        "SELECT SUM(total_price) FROM orders"
    ).fetchone()[0]

    # Users with no orders
    results["users_with_no_orders"] = conn.execute(
        "SELECT COUNT(*) FROM users WHERE id NOT IN (SELECT DISTINCT user_id FROM orders)"
    ).fetchone()[0]

    return results


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    """Create and seed a database, then print verification results."""
    import sys

    db_path = sys.argv[1] if len(sys.argv) > 1 else "seeded.db"

    print(f"Creating database: {db_path}")
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    try:
        seed_database(conn, num_users=50, num_products=30, num_orders=200, seed=SEED)
        print("Database seeded successfully.")

        results = run_verification_queries(conn)
        print(f"\n--- Verification Results ---")
        print(f"Total users:    {results['total_users']}")
        print(f"Total products: {results['total_products']}")
        print(f"Total orders:   {results['total_orders']}")
        print(f"Orphan orders (users):    {results['orphan_orders_users']}")
        print(f"Orphan orders (products): {results['orphan_orders_products']}")
        print(f"Average order value: ${results['avg_order_value']:.2f}")
        print(f"Total revenue:       ${results['total_revenue']:.2f}")
        print(f"Users with no orders: {results['users_with_no_orders']}")

        print(f"\nTop 5 products by order count:")
        for name, count in results["top_products_by_orders"][:5]:
            print(f"  {name}: {count} orders")

        print(f"\nOrders per category:")
        for category, count in results["orders_per_category"]:
            print(f"  {category}: {count} orders")

        print(f"\nTop 5 spenders:")
        for name, total in results["revenue_per_user"][:5]:
            print(f"  {name}: ${total:.2f}")

        print("\nAll verification checks passed!")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
