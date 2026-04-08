"""
Database seed script: creates a SQLite database with users, orders, and products
tables, populates them with deterministic mock data, and verifies consistency.
"""

import sqlite3
import random
import os
from datetime import datetime, timedelta

# Default database file path (overridable in tests via in-memory DB)
DB_PATH = "store.db"

# Seed for deterministic randomization — same data every run
RNG_SEED = 42


def create_schema(conn: sqlite3.Connection) -> None:
    """Create users, products, and orders tables with proper foreign keys."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            price REAL NOT NULL CHECK(price > 0),
            category TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            order_date TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        );
    """)


# --- Realistic mock data pools ---

FIRST_NAMES = [
    "Alice", "Bob", "Carol", "David", "Eve", "Frank", "Grace", "Hank",
    "Ivy", "Jack", "Karen", "Leo", "Mona", "Nick", "Olive", "Paul",
    "Quinn", "Rosa", "Sam", "Tina", "Uma", "Vince", "Wendy", "Xander",
    "Yara", "Zane",
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Wilson",
    "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee",
]

PRODUCT_TEMPLATES = {
    "Electronics": ["Wireless Headphones", "USB-C Hub", "Bluetooth Speaker",
                    "Webcam HD", "Mechanical Keyboard", "Portable Monitor",
                    "Smart Watch", "Power Bank"],
    "Books": ["Python Cookbook", "Data Science Handbook", "Clean Code",
              "Design Patterns", "Algorithms Guide", "SQL Mastery",
              "Machine Learning Intro", "Web Dev Bootcamp"],
    "Home": ["Desk Lamp", "Coffee Maker", "Air Purifier", "Throw Blanket",
             "Ceramic Mug Set", "Wall Clock", "Plant Pot", "Bookshelf"],
    "Clothing": ["Running Shoes", "Cotton T-Shirt", "Denim Jacket",
                 "Wool Scarf", "Canvas Backpack", "Leather Belt",
                 "Rain Jacket", "Snapback Cap"],
}

EMAIL_DOMAINS = ["example.com", "mail.test", "sample.org"]


def generate_users(rng: random.Random, count: int = 30) -> list[dict]:
    """Generate deterministic user records with unique emails."""
    users = []
    used_emails = set()
    base_date = datetime(2023, 1, 1)

    for i in range(count):
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        name = f"{first} {last}"

        # Ensure unique email by appending index
        domain = rng.choice(EMAIL_DOMAINS)
        email = f"{first.lower()}.{last.lower()}{i}@{domain}"
        used_emails.add(email)

        # Spread creation dates across ~2 years
        days_offset = rng.randint(0, 730)
        created_at = (base_date + timedelta(days=days_offset)).isoformat()

        users.append({"name": name, "email": email, "created_at": created_at})

    return users


def generate_products(rng: random.Random, count: int = 25) -> list[dict]:
    """Generate deterministic product records across categories."""
    products = []
    categories = list(PRODUCT_TEMPLATES.keys())

    total_templates = len(categories) * max(len(v) for v in PRODUCT_TEMPLATES.values())
    for i in range(count):
        category = categories[i % len(categories)]
        templates = PRODUCT_TEMPLATES[category]
        base_name = templates[i % len(templates)]
        # Append variant suffix when we've exhausted the template pool
        name = f"{base_name} v{i // total_templates + 2}" if i >= total_templates else base_name

        # Realistic price range: $4.99 – $299.99
        price = round(rng.uniform(4.99, 299.99), 2)
        products.append({"name": name, "price": price, "category": category})

    return products


def generate_orders(
    rng: random.Random,
    user_ids: list[int],
    product_ids: list[int],
    count: int = 100,
) -> list[dict]:
    """Generate deterministic orders referencing only valid user/product IDs."""
    orders = []
    base_date = datetime(2023, 6, 1)

    for _ in range(count):
        user_id = rng.choice(user_ids)
        product_id = rng.choice(product_ids)
        quantity = rng.randint(1, 10)
        days_offset = rng.randint(0, 500)
        order_date = (base_date + timedelta(days=days_offset)).isoformat()

        orders.append({
            "user_id": user_id,
            "product_id": product_id,
            "quantity": quantity,
            "order_date": order_date,
        })

    return orders


# --- Insertion functions (respect referential integrity via insert order) ---

def insert_users(conn: sqlite3.Connection, users: list[dict]) -> list[int]:
    """Insert user records and return their auto-generated IDs."""
    ids = []
    for u in users:
        cur = conn.execute(
            "INSERT INTO users (name, email, created_at) VALUES (?, ?, ?)",
            (u["name"], u["email"], u["created_at"]),
        )
        ids.append(cur.lastrowid)
    conn.commit()
    return ids


def insert_products(conn: sqlite3.Connection, products: list[dict]) -> list[int]:
    """Insert product records and return their auto-generated IDs."""
    ids = []
    for p in products:
        cur = conn.execute(
            "INSERT INTO products (name, price, category) VALUES (?, ?, ?)",
            (p["name"], p["price"], p["category"]),
        )
        ids.append(cur.lastrowid)
    conn.commit()
    return ids


def insert_orders(conn: sqlite3.Connection, orders: list[dict]) -> None:
    """Insert order records. Raises IntegrityError if FKs are violated."""
    for o in orders:
        conn.execute(
            "INSERT INTO orders (user_id, product_id, quantity, order_date) VALUES (?, ?, ?, ?)",
            (o["user_id"], o["product_id"], o["quantity"], o["order_date"]),
        )
    conn.commit()


def seed_database(conn: sqlite3.Connection, *, num_users: int = 30,
                  num_products: int = 25, num_orders: int = 100) -> None:
    """Full pipeline: schema + deterministic data, respecting referential integrity."""
    rng = random.Random(RNG_SEED)

    create_schema(conn)

    users = generate_users(rng, count=num_users)
    user_ids = insert_users(conn, users)

    products = generate_products(rng, count=num_products)
    product_ids = insert_products(conn, products)

    # Orders reference only IDs that actually exist in the DB
    orders = generate_orders(rng, user_ids=user_ids, product_ids=product_ids, count=num_orders)
    insert_orders(conn, orders)


# --- Verification queries to confirm data consistency ---

def run_verification_queries(conn: sqlite3.Connection) -> dict:
    """Run a suite of queries that verify the seeded data is consistent.

    Returns a dict with:
      - user_count, product_count, order_count: row counts
      - revenue_by_category: [(category, total_revenue), ...]
      - top_customers: [(name, order_count), ...] top 5
      - avg_orders_per_user: float
      - orphaned_orders: int (should be 0)
    """
    results = {}

    # Row counts
    results["user_count"] = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    results["product_count"] = conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
    results["order_count"] = conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]

    # Revenue by product category
    results["revenue_by_category"] = conn.execute("""
        SELECT p.category, ROUND(SUM(p.price * o.quantity), 2) AS revenue
        FROM orders o
        JOIN products p ON o.product_id = p.id
        GROUP BY p.category
        ORDER BY revenue DESC
    """).fetchall()

    # Top 5 customers by order count
    results["top_customers"] = conn.execute("""
        SELECT u.name, COUNT(o.id) AS order_count
        FROM orders o
        JOIN users u ON o.user_id = u.id
        GROUP BY o.user_id
        ORDER BY order_count DESC
        LIMIT 5
    """).fetchall()

    # Average orders per user
    results["avg_orders_per_user"] = conn.execute("""
        SELECT ROUND(CAST(COUNT(o.id) AS REAL) / COUNT(DISTINCT o.user_id), 2)
        FROM orders o
    """).fetchone()[0]

    # Orphan check: orders referencing non-existent users or products
    results["orphaned_orders"] = conn.execute("""
        SELECT COUNT(*) FROM orders o
        LEFT JOIN users u ON o.user_id = u.id
        LEFT JOIN products p ON o.product_id = p.id
        WHERE u.id IS NULL OR p.id IS NULL
    """).fetchone()[0]

    return results


# --- Main entry point ---

if __name__ == "__main__":
    # Remove existing DB to start fresh
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")

    try:
        seed_database(conn)
        print(f"Database seeded at {DB_PATH}")

        results = run_verification_queries(conn)
        print(f"\n--- Verification Results ---")
        print(f"Users:    {results['user_count']}")
        print(f"Products: {results['product_count']}")
        print(f"Orders:   {results['order_count']}")
        print(f"Avg orders/user: {results['avg_orders_per_user']}")
        print(f"Orphaned orders: {results['orphaned_orders']}")
        print(f"\nRevenue by category:")
        for category, revenue in results["revenue_by_category"]:
            print(f"  {category}: ${revenue:,.2f}")
        print(f"\nTop 5 customers:")
        for name, count in results["top_customers"]:
            print(f"  {name}: {count} orders")
    except Exception as e:
        print(f"Error: {e}", file=__import__("sys").stderr)
        raise
    finally:
        conn.close()
