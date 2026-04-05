"""
SQLite database seed script.

Design:
  - DatabaseSeeder wraps a sqlite3.Connection
  - create_schema()   → creates users / products / orders with FK constraints
  - generate_*()      → pure functions, deterministic via seeded random.Random
  - insert_*()        → persist data, return row count
  - seed_all()        → convenience: generate + insert everything
  - verify_all()      → analytical queries returning a structured result dict

TDD cycles completed:
  1. Schema creation  (tables + FK enforcement)
  2. Mock data generation (deterministic, field validation, referential integrity)
  3. Data insertion   (row counts, FK error propagation)
  4. Verification queries (orphan checks, revenue, price accuracy)
"""

import random
import sqlite3
from datetime import datetime, timedelta


# ─────────────────────────────────────────────────────────────────────────────
# Fixture data used by generators
# ─────────────────────────────────────────────────────────────────────────────

_FIRST_NAMES = [
    "Alice", "Bob", "Carol", "David", "Eva", "Frank", "Grace", "Hank",
    "Iris", "Jack", "Karen", "Leo", "Maria", "Nate", "Olivia", "Paul",
    "Quinn", "Rose", "Sam", "Tina", "Uma", "Victor", "Wendy", "Xander",
    "Yara", "Zack",
]

_LAST_NAMES = [
    "Smith", "Jones", "Williams", "Brown", "Davis", "Miller", "Wilson",
    "Moore", "Taylor", "Anderson", "Thomas", "Jackson", "White", "Harris",
    "Martin", "Thompson", "Garcia", "Martinez", "Robinson", "Clark",
]

_EMAIL_DOMAINS = ["example.com", "mail.net", "inbox.io", "test.org", "demo.dev"]

_PRODUCT_ADJECTIVES = [
    "Pro", "Ultra", "Classic", "Smart", "Eco", "Mini", "Max", "Lite",
    "Plus", "Prime",
]

_PRODUCT_NOUNS = [
    "Gadget", "Widget", "Doohickey", "Thingamajig", "Contraption",
    "Device", "Tool", "Instrument", "Apparatus", "Component",
    "Module", "Unit", "System", "Kit", "Pack",
]

# ISO8601 date helpers
_EPOCH = datetime(2022, 1, 1)


def _random_date(rng: random.Random, days_range: int = 730) -> str:
    """Return a random ISO date string within *days_range* days of _EPOCH."""
    delta = timedelta(days=rng.randint(0, days_range))
    return (_EPOCH + delta).strftime("%Y-%m-%d")


# ─────────────────────────────────────────────────────────────────────────────
# DatabaseSeeder
# ─────────────────────────────────────────────────────────────────────────────

class DatabaseSeeder:
    """
    Manages schema creation, deterministic data generation, insertion, and
    verification for a SQLite database.

    Parameters
    ----------
    conn : sqlite3.Connection
        An open SQLite connection.  Caller is responsible for closing it.
    seed : int, optional
        RNG seed for fully deterministic data generation (default: 42).
    """

    def __init__(self, conn: sqlite3.Connection, seed: int = 42):
        self.conn = conn
        # Use an isolated Random instance so we never affect global state
        self.rng = random.Random(seed)

    # ── Cycle 1: Schema ───────────────────────────────────────────────────────

    def create_schema(self) -> None:
        """
        Create the users, products, and orders tables.

        orders.user_id    → users.id    (FK)
        orders.product_id → products.id (FK)

        Idempotent: uses IF NOT EXISTS so it can be called multiple times.
        """
        self.conn.executescript("""
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS users (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                name       TEXT    NOT NULL,
                email      TEXT    NOT NULL UNIQUE,
                created_at TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS products (
                id    INTEGER PRIMARY KEY AUTOINCREMENT,
                name  TEXT    NOT NULL,
                price REAL    NOT NULL CHECK(price > 0),
                stock INTEGER NOT NULL CHECK(stock >= 0)
            );

            CREATE TABLE IF NOT EXISTS orders (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id     INTEGER NOT NULL REFERENCES users(id),
                product_id  INTEGER NOT NULL REFERENCES products(id),
                quantity    INTEGER NOT NULL CHECK(quantity > 0),
                total_price REAL    NOT NULL,
                ordered_at  TEXT    NOT NULL
            );
        """)

    # ── Cycle 2: Data generation ──────────────────────────────────────────────

    def generate_users(self, count: int) -> list[dict]:
        """
        Return *count* user dicts with unique emails.

        Each dict: {name, email, created_at}
        """
        users = []
        used_emails: set[str] = set()
        attempts = 0
        while len(users) < count:
            attempts += 1
            if attempts > count * 10:
                raise RuntimeError("Could not generate enough unique emails")
            first = self.rng.choice(_FIRST_NAMES)
            last  = self.rng.choice(_LAST_NAMES)
            domain = self.rng.choice(_EMAIL_DOMAINS)
            # Make emails unique by appending a counter suffix when needed
            base_email = f"{first.lower()}.{last.lower()}@{domain}"
            email = base_email
            n = 1
            while email in used_emails:
                email = f"{first.lower()}.{last.lower()}{n}@{domain}"
                n += 1
            used_emails.add(email)
            users.append({
                "name":       f"{first} {last}",
                "email":      email,
                "created_at": _random_date(self.rng),
            })
        return users

    def generate_products(self, count: int) -> list[dict]:
        """
        Return *count* product dicts.

        Each dict: {name, price, stock}
        price rounded to 2 decimal places; stock between 0 and 500.
        """
        products = []
        for _ in range(count):
            adj  = self.rng.choice(_PRODUCT_ADJECTIVES)
            noun = self.rng.choice(_PRODUCT_NOUNS)
            products.append({
                "name":  f"{adj} {noun}",
                "price": round(self.rng.uniform(1.99, 299.99), 2),
                "stock": self.rng.randint(0, 500),
            })
        return products

    def generate_orders(
        self,
        count: int,
        user_ids: list[int],
        product_ids: list[int],
    ) -> list[dict]:
        """
        Return *count* order dicts that reference existing user_ids and product_ids.

        total_price = quantity × product.price (fetched from DB for accuracy).

        Each dict: {user_id, product_id, quantity, total_price, ordered_at}
        """
        if not user_ids or not product_ids:
            raise ValueError("user_ids and product_ids must not be empty")

        # Build a local price lookup to compute total_price deterministically
        # without extra DB round-trips inside a loop.
        placeholders = ",".join("?" * len(product_ids))
        price_map: dict[int, float] = {
            row[0]: row[1]
            for row in self.conn.execute(
                f"SELECT id, price FROM products WHERE id IN ({placeholders})",
                product_ids,
            ).fetchall()
        }

        orders = []
        for _ in range(count):
            uid = self.rng.choice(user_ids)
            pid = self.rng.choice(product_ids)
            qty = self.rng.randint(1, 10)
            price = price_map[pid]
            orders.append({
                "user_id":     uid,
                "product_id":  pid,
                "quantity":    qty,
                "total_price": round(qty * price, 2),
                "ordered_at":  _random_date(self.rng),
            })
        return orders

    # ── Cycle 3: Data insertion ───────────────────────────────────────────────

    def insert_users(self, users: list[dict]) -> int:
        """Insert users and return the number of rows inserted."""
        self.conn.executemany(
            "INSERT INTO users(name, email, created_at) VALUES(:name, :email, :created_at)",
            users,
        )
        self.conn.commit()
        return len(users)

    def insert_products(self, products: list[dict]) -> int:
        """Insert products and return the number of rows inserted."""
        self.conn.executemany(
            "INSERT INTO products(name, price, stock) VALUES(:name, :price, :stock)",
            products,
        )
        self.conn.commit()
        return len(products)

    def insert_orders(self, orders: list[dict]) -> int:
        """
        Insert orders and return the number of rows inserted.

        Raises sqlite3.IntegrityError if any FK constraint is violated.
        Note: executemany is used inside a transaction; a single bad row
        rolls back the whole batch, letting the exception propagate cleanly.
        """
        self.conn.executemany(
            "INSERT INTO orders(user_id, product_id, quantity, total_price, ordered_at) "
            "VALUES(:user_id, :product_id, :quantity, :total_price, :ordered_at)",
            orders,
        )
        self.conn.commit()
        return len(orders)

    def seed_all(
        self,
        num_users: int = 20,
        num_products: int = 30,
        num_orders: int = 100,
    ) -> dict:
        """
        Generate and insert all data in dependency order
        (users → products → orders).

        Returns a dict of {table: row_count} for easy assertion.
        """
        users    = self.generate_users(num_users)
        products = self.generate_products(num_products)

        u_count = self.insert_users(users)
        p_count = self.insert_products(products)

        user_ids    = [r[0] for r in self.conn.execute("SELECT id FROM users").fetchall()]
        product_ids = [r[0] for r in self.conn.execute("SELECT id FROM products").fetchall()]

        orders  = self.generate_orders(num_orders, user_ids, product_ids)
        o_count = self.insert_orders(orders)

        return {"users": u_count, "products": p_count, "orders": o_count}

    # ── Cycle 4: Verification queries ─────────────────────────────────────────

    def verify_all(self) -> dict:
        """
        Run a suite of data-consistency checks.

        Returns:
          {
            "all_passed": bool,
            "checks": [
              {"name": str, "passed": bool, "detail": str},
              ...
            ]
          }
        """
        checks = []

        # Check 1: No orders reference a missing user
        orphaned_users = self.conn.execute(
            "SELECT COUNT(*) FROM orders o "
            "LEFT JOIN users u ON o.user_id = u.id WHERE u.id IS NULL"
        ).fetchone()[0]
        checks.append({
            "name":   "no_orphaned_orders",
            "passed": orphaned_users == 0,
            "detail": f"{orphaned_users} orphaned order(s) found (missing user)",
        })

        # Check 2: No orders reference a missing product
        orphaned_products = self.conn.execute(
            "SELECT COUNT(*) FROM orders o "
            "LEFT JOIN products p ON o.product_id = p.id WHERE p.id IS NULL"
        ).fetchone()[0]
        checks.append({
            "name":   "no_orphaned_product_refs",
            "passed": orphaned_products == 0,
            "detail": f"{orphaned_products} orphaned order(s) found (missing product)",
        })

        # Check 3: Total revenue must be positive
        revenue = self.conn.execute("SELECT COALESCE(SUM(total_price), 0) FROM orders").fetchone()[0]
        checks.append({
            "name":   "positive_total_revenue",
            "passed": revenue > 0,
            "detail": f"Total revenue: {revenue:.2f}",
        })

        # Check 4: total_price ≈ quantity × product.price (within ±0.01 float rounding)
        mismatches = self.conn.execute(
            "SELECT COUNT(*) FROM orders o "
            "JOIN products p ON o.product_id = p.id "
            "WHERE ABS(o.total_price - ROUND(o.quantity * p.price, 2)) > 0.01"
        ).fetchone()[0]
        checks.append({
            "name":   "total_price_accuracy",
            "passed": mismatches == 0,
            "detail": f"{mismatches} order(s) with inaccurate total_price",
        })

        # Check 5: All quantities are positive
        bad_qty = self.conn.execute(
            "SELECT COUNT(*) FROM orders WHERE quantity <= 0"
        ).fetchone()[0]
        checks.append({
            "name":   "positive_quantities",
            "passed": bad_qty == 0,
            "detail": f"{bad_qty} order(s) with non-positive quantity",
        })

        # Check 6: All product prices are positive
        bad_prices = self.conn.execute(
            "SELECT COUNT(*) FROM products WHERE price <= 0"
        ).fetchone()[0]
        checks.append({
            "name":   "positive_product_prices",
            "passed": bad_prices == 0,
            "detail": f"{bad_prices} product(s) with non-positive price",
        })

        all_passed = all(c["passed"] for c in checks)
        return {"all_passed": all_passed, "checks": checks}


# ─────────────────────────────────────────────────────────────────────────────
# CLI entry-point: run from command line with `python database_seed.py`
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys

    db_path = sys.argv[1] if len(sys.argv) > 1 else "seed.db"

    print(f"Seeding database: {db_path}")
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    seeder = DatabaseSeeder(conn, seed=42)
    seeder.create_schema()

    counts = seeder.seed_all(num_users=20, num_products=30, num_orders=100)
    print(f"Inserted: {counts}")

    result = seeder.verify_all()
    print(f"\nVerification {'PASSED' if result['all_passed'] else 'FAILED'}:")
    for check in result["checks"]:
        status = "PASS" if check["passed"] else "FAIL"
        print(f"  [{status}] {check['name']}: {check['detail']}")

    conn.close()
    sys.exit(0 if result["all_passed"] else 1)
